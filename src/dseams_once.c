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
 * The busy-spin wait is deliberate: the guarded section is a one-time
 * file probe, expected to take microseconds to milliseconds, not long
 * enough to be worth a platform mutex or futex here, and every state
 * transition this file makes is one one-time use per feature per
 * process.
 */
#include <stdatomic.h>

int dseams_once_enter(atomic_int *state) {
  int expected = 0;
  if (atomic_compare_exchange_strong_explicit(
          state, &expected, 1, memory_order_acq_rel, memory_order_acquire)) {
    return 1;
  }
  while (atomic_load_explicit(state, memory_order_acquire) != 2) {
    /* spin */
  }
  return 0;
}

void dseams_once_done(atomic_int *state) {
  atomic_store_explicit(state, 2, memory_order_release);
}
