/* Copyright (c) d-SEAMS developers
 *
 * A once-guard with no filesystem footprint at all: no lock file, no
 * creat(2), no flock(2), nothing a local attacker sharing /tmp could
 * plant a symlink at. Three states live in one C-owned static
 * atomic_int, shared by every thread in this process only: 0 untouched,
 * 1 one thread is running the guarded section, 2 done.
 * dseams_once_enter is a compare-and-swap from 0 to 1; the thread that
 * wins it runs the section (both the chemfiles and readcon probes
 * sequentially) and reports back with dseams_once_done. Every other
 * caller, whether it arrived before or after that one call returns,
 * spins until the state reaches 2. Fortran never aliases the atomic_int
 * directly; it calls dseams_once_enter, dseams_once_done, and the
 * dseams_once_state accessor.
 *
 * <stdatomic.h> is a C11 feature, not an OS primitive: no vendor
 * static initializer to get wrong (contrast PTHREAD_ONCE_INIT, which
 * is all-zero on Linux glibc but a non-zero signature word on Darwin
 * on purpose), and no OS header to link against (contrast flock(2),
 * unavailable on a native Windows ABI). GCC, Clang (including Apple
 * Clang) and MSVC (from VS 2022) all implement it. <threads.h>'s
 * call_once was deliberately not used instead: Apple's libc has never
 * implemented C11 <threads.h>, and MSVC's support for it is recent and
 * inconsistent, where <stdatomic.h> support is not.
 *
 * The wait is a spin, not a platform mutex or futex: the guarded
 * section is a one-time file probe, expected to take microseconds to
 * milliseconds, and every state transition this file makes is one
 * one-time use per process. Each spin iteration still yields the CPU
 * rather than busy-looping flat out, so a loser thread does not hold
 * a core at 100% for however long the one winner's probe takes.
 *
 * This file also provides the atomic probe file and directory helpers
 * (O_CREAT | O_EXCL | O_NOFOLLOW write through a single descriptor,
 * plus 0700 private directory creation), avoiding any create-close-
 * reopen TOCTOU window in shared temp directories.
 */
#if !defined(_WIN32) && !defined(_POSIX_C_SOURCE)
#  define _POSIX_C_SOURCE 200809L
#endif

#include <errno.h>
#include <fcntl.h>
#include <stdatomic.h>
#include <stddef.h>
#include <sys/stat.h>

#if defined(_WIN32)
#  include <direct.h>
#  include <io.h>
#else
#  include <unistd.h>
#endif

#if defined(__has_include)
#  if __has_include(<threads.h>) && !defined(__STDC_NO_THREADS__)
#    include <threads.h>
#    define DSEAMS_YIELD() thrd_yield()
#  endif
#endif

#if !defined(DSEAMS_YIELD)
#  if defined(_WIN32)
#    include <windows.h>
#    define DSEAMS_YIELD() SwitchToThread()
#  elif defined(__unix__) || defined(__APPLE__)
#    include <sched.h>
#    define DSEAMS_YIELD() ((void)sched_yield())
#  else
#    define DSEAMS_YIELD() ((void)0)
#  endif
#endif

static atomic_int readers_once_state = 0;

int dseams_once_enter(void) {
  int expected = 0;
  if (atomic_compare_exchange_strong_explicit(
          &readers_once_state, &expected, 1,
          memory_order_acq_rel, memory_order_acquire)) {
    return 1;
  }
  while (atomic_load_explicit(&readers_once_state, memory_order_acquire) != 2) {
    DSEAMS_YIELD();
  }
  return 0;
}

void dseams_once_done(void) {
  atomic_store_explicit(&readers_once_state, 2, memory_order_release);
}

int dseams_once_state(void) {
  return atomic_load_explicit(&readers_once_state, memory_order_acquire);
}

int dseams_probe_mkdir(const char *path) {
  int rc;
#if defined(_WIN32)
  rc = _mkdir(path);
#else
  rc = mkdir(path, S_IRWXU);
#endif
  if (rc == 0) {
    return 0;
  }
  return (errno == EEXIST) ? 1 : -1;
}

int dseams_probe_write(const char *path, const char *data, size_t len) {
#if defined(_WIN32)
  int fd = _open(path, _O_WRONLY | _O_CREAT | _O_EXCL | _O_BINARY,
                 _S_IREAD | _S_IWRITE);
#else
  int flags = O_WRONLY | O_CREAT | O_EXCL;
#  ifdef O_NOFOLLOW
  flags |= O_NOFOLLOW;
#  endif
  int fd = open(path, flags, S_IRUSR | S_IWUSR);
#endif
  if (fd < 0) {
    return (errno == EEXIST) ? 1 : -1;
  }

  size_t off = 0;
  while (off < len) {
#if defined(_WIN32)
    int n = _write(fd, data + off, (unsigned int)(len - off));
    if (n <= 0) {
      _close(fd);
      _unlink(path);
      return -1;
    }
#else
    ssize_t n = write(fd, data + off, len - off);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      close(fd);
      unlink(path);
      return -1;
    }
#endif
    off += (size_t)n;
  }

#if defined(_WIN32)
  if (_close(fd) != 0) {
    _unlink(path);
    return -1;
  }
#else
  if (close(fd) != 0) {
    unlink(path);
    return -1;
  }
#endif
  return 0;
}

int dseams_probe_write_stamp(const char *path, const char *data, size_t len) {
#if defined(_WIN32)
  _unlink(path);
#else
  unlink(path);
#endif
  return dseams_probe_write(path, data, len);
}

void dseams_probe_unlink(const char *path) {
#if defined(_WIN32)
  _unlink(path);
#else
  unlink(path);
#endif
}

void dseams_probe_rmdir(const char *path) {
#if defined(_WIN32)
  _rmdir(path);
#else
  rmdir(path);
#endif
}
