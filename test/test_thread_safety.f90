! Copyright (c) d-SEAMS developers
! has_chemfiles and has_readcon each run their probe behind a
! pthread_once (see src/seams_methods.f90 and
! docs/orgmode/contributing/developer/faq.org). This spawns real POSIX
! threads through iso_c_binding, calls both queries from every one of
! them at once, and checks that every thread saw the same answer as a
! single-threaded baseline call made before any thread started. Each
! thread writes only into the one result slot its caller gave it, so
! the check itself adds no shared mutable state for the functions
! under test to race on.
module dseams_thread_probe
  use, intrinsic :: iso_c_binding, only: c_ptr, c_int, c_null_ptr, c_f_pointer
  use seams, only: has_chemfiles, has_readcon
  implicit none
  private
  public :: probe_slot, probe_worker

  type, bind(c) :: probe_slot
    integer(c_int) :: chemfiles
    integer(c_int) :: readcon
  end type probe_slot

contains

  function probe_worker(arg) result(ret) bind(c)
    type(c_ptr), value :: arg
    type(c_ptr) :: ret
    type(probe_slot), pointer :: slot

    call c_f_pointer(arg, slot)
    slot%chemfiles = merge(1_c_int, 0_c_int, has_chemfiles())
    slot%readcon = merge(1_c_int, 0_c_int, has_readcon())
    ret = c_null_ptr
  end function probe_worker

end module dseams_thread_probe

program test_thread_safety
  use, intrinsic :: iso_c_binding
  use seams, only: has_chemfiles, has_readcon
  use dseams_thread_probe, only: probe_slot, probe_worker
  implicit none

  interface
    function pthread_create(thread, attr, start_routine, arg) bind(c, name="pthread_create")
      import :: c_long, c_ptr, c_funptr, c_int
      integer(c_long) :: thread
      type(c_ptr), value :: attr
      type(c_funptr), value :: start_routine
      type(c_ptr), value :: arg
      integer(c_int) :: pthread_create
    end function pthread_create
    function pthread_join(thread, retval) bind(c, name="pthread_join")
      import :: c_long, c_ptr, c_int
      integer(c_long), value :: thread
      type(c_ptr) :: retval
      integer(c_int) :: pthread_join
    end function pthread_join
  end interface

  integer, parameter :: n_threads = 16
  integer(c_long) :: tid(n_threads)
  type(probe_slot), target :: slots(n_threads)
  type(c_ptr) :: retval
  integer :: i, stat
  logical :: baseline_chem, baseline_rcon
  integer(c_int) :: want_chem, want_rcon

  baseline_chem = has_chemfiles()
  baseline_rcon = has_readcon()
  want_chem = merge(1_c_int, 0_c_int, baseline_chem)
  want_rcon = merge(1_c_int, 0_c_int, baseline_rcon)

  do i = 1, n_threads
    slots(i)%chemfiles = -1_c_int
    slots(i)%readcon = -1_c_int
    stat = pthread_create(tid(i), c_null_ptr, c_funloc(probe_worker), c_loc(slots(i)))
    if (stat /= 0) error stop "pthread_create failed"
  end do

  do i = 1, n_threads
    stat = pthread_join(tid(i), retval)
    if (stat /= 0) error stop "pthread_join failed"
  end do

  do i = 1, n_threads
    if (slots(i)%chemfiles /= want_chem) stop 2
    if (slots(i)%readcon /= want_rcon) stop 3
  end do

  print "(a,i0,a)", "thread safety ", n_threads, " callers agree"
  print "(a)", "fortran thread safety ok"
end program test_thread_safety
