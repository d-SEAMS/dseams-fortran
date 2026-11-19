/* Copyright (c) d-SEAMS developers
 *
 * A once-guard with no filesystem footprint at all: no lock file, no
 * creat(2), no flock(2), nothing a local attacker sharing /tmp could
 * plant a symlink at. Three states live in one int, shared by every
 * thread in this process only: 0 untouched, 1 one thread is running
 * the guarded section, 2 done. dseams_once_enter is a compare-and-swap
 * from 0 to 1; the thread that wins it runs the section and reports
 * back with dseams_once_done. Every other caller, whether it arrived
 * before or after that CAS, spins until the state reaches 2.
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
 * one-time use per feature per process. Each spin iteration still
 * yields the CPU rather than busy-looping flat out, so a loser thread
 * does not hold a core at 100% for however long the one winner's
 * probe takes. DSEAMS_YIELD prefers C11's thrd_yield (<threads.h>),
 * detected with __has_include rather than __STDC_NO_THREADS__, since
 * Apple's libc has never implemented <threads.h> without reliably
 * defining that macro either; sched_yield (POSIX) and
 * SwitchToThread (Win32) are the portable fallbacks where
 * <threads.h> is absent, and a plain no-op (the prior behavior) is
 * the last resort if none of the three is available. No OS lock file
 * is involved in any of this: it is purely a hint to the scheduler
 * about this one thread, not a lock on anything.
 */
#include <stdatomic.h>

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

int dseams_once_enter(atomic_int *state) {
  int expected = 0;
  if (atomic_compare_exchange_strong_explicit(
          state, &expected, 1, memory_order_acq_rel, memory_order_acquire)) {
    return 1;
  }
  while (atomic_load_explicit(state, memory_order_acquire) != 2) {
    DSEAMS_YIELD();
  }
  return 0;
}

void dseams_once_done(atomic_int *state) {
  atomic_store_explicit(state, 2, memory_order_release);
}
