! Copyright (c) d-SEAMS developers
! has_chemfiles and has_readcon share one C-owned once-guard
! (see src/seams_methods.f90, src/dseams_once.c and
! docs/orgmode/contributing/developer/faq.org). This spawns real POSIX
! threads through iso_c_binding with no warm-up call before thread
! creation, synchronizes all workers at a pthread mutex/cond barrier so
! they start at once from cold state, alternates call order across
! threads so both entry points are entered concurrently, and checks
! that every thread saw the same answer as a post-join call.
module dseams_thread_probe
  use, intrinsic :: iso_c_binding, only: c_ptr, c_int, c_long, c_null_ptr, c_loc, c_f_pointer
  use seams, only: has_chemfiles, has_readcon
  implicit none
  private
  public :: barrier_box, probe_slot, barrier_init, barrier_destroy, probe_worker

  type, bind(c) :: barrier_box
    integer(c_long) :: mutex(16)
    integer(c_long) :: cond(16)
    integer(c_int) :: arrived
    integer(c_int) :: target_count
  end type barrier_box

  type, bind(c) :: probe_slot
    type(c_ptr) :: barrier
    integer(c_int) :: thread_id
    integer(c_int) :: chemfiles
    integer(c_int) :: readcon
  end type probe_slot

  interface
    function pthread_mutex_init(mutex, attr) bind(c, name="pthread_mutex_init")
      import :: c_ptr, c_int
      type(c_ptr), value :: mutex, attr
      integer(c_int) :: pthread_mutex_init
    end function pthread_mutex_init
    function pthread_mutex_destroy(mutex) bind(c, name="pthread_mutex_destroy")
      import :: c_ptr, c_int
      type(c_ptr), value :: mutex
      integer(c_int) :: pthread_mutex_destroy
    end function pthread_mutex_destroy
    function pthread_mutex_lock(mutex) bind(c, name="pthread_mutex_lock")
      import :: c_ptr, c_int
      type(c_ptr), value :: mutex
      integer(c_int) :: pthread_mutex_lock
    end function pthread_mutex_lock
    function pthread_mutex_unlock(mutex) bind(c, name="pthread_mutex_unlock")
      import :: c_ptr, c_int
      type(c_ptr), value :: mutex
      integer(c_int) :: pthread_mutex_unlock
    end function pthread_mutex_unlock
    function pthread_cond_init(cond, attr) bind(c, name="pthread_cond_init")
      import :: c_ptr, c_int
      type(c_ptr), value :: cond, attr
      integer(c_int) :: pthread_cond_init
    end function pthread_cond_init
    function pthread_cond_destroy(cond) bind(c, name="pthread_cond_destroy")
      import :: c_ptr, c_int
      type(c_ptr), value :: cond
      integer(c_int) :: pthread_cond_destroy
    end function pthread_cond_destroy
    function pthread_cond_wait(cond, mutex) bind(c, name="pthread_cond_wait")
      import :: c_ptr, c_int
      type(c_ptr), value :: cond, mutex
      integer(c_int) :: pthread_cond_wait
    end function pthread_cond_wait
    function pthread_cond_broadcast(cond) bind(c, name="pthread_cond_broadcast")
      import :: c_ptr, c_int
      type(c_ptr), value :: cond
      integer(c_int) :: pthread_cond_broadcast
    end function pthread_cond_broadcast
  end interface

contains

  subroutine barrier_init(bar, count)
    type(barrier_box), target, intent(out) :: bar
    integer, intent(in) :: count
    integer(c_int) :: rc
    bar%mutex = 0_c_long
    bar%cond = 0_c_long
    bar%arrived = 0_c_int
    bar%target_count = int(count, c_int)
    rc = pthread_mutex_init(c_loc(bar%mutex), c_null_ptr)
    if (rc /= 0_c_int) error stop "pthread_mutex_init failed"
    rc = pthread_cond_init(c_loc(bar%cond), c_null_ptr)
    if (rc /= 0_c_int) error stop "pthread_cond_init failed"
  end subroutine barrier_init

  subroutine barrier_destroy(bar)
    type(barrier_box), target, intent(inout) :: bar
    integer(c_int) :: rc
    rc = pthread_cond_destroy(c_loc(bar%cond))
    if (rc /= 0_c_int) error stop "pthread_cond_destroy failed"
    rc = pthread_mutex_destroy(c_loc(bar%mutex))
    if (rc /= 0_c_int) error stop "pthread_mutex_destroy failed"
  end subroutine barrier_destroy

  subroutine barrier_wait(bar)
    type(barrier_box), target, intent(inout) :: bar
    integer(c_int) :: rc
    rc = pthread_mutex_lock(c_loc(bar%mutex))
    if (rc /= 0_c_int) error stop "pthread_mutex_lock failed"
    bar%arrived = bar%arrived + 1_c_int
    if (bar%arrived >= bar%target_count) then
      rc = pthread_cond_broadcast(c_loc(bar%cond))
      if (rc /= 0_c_int) error stop "pthread_cond_broadcast failed"
    else
      do while (bar%arrived < bar%target_count)
        rc = pthread_cond_wait(c_loc(bar%cond), c_loc(bar%mutex))
        if (rc /= 0_c_int) error stop "pthread_cond_wait failed"
      end do
    end if
    rc = pthread_mutex_unlock(c_loc(bar%mutex))
    if (rc /= 0_c_int) error stop "pthread_mutex_unlock failed"
  end subroutine barrier_wait

  function probe_worker(arg) result(ret) bind(c)
    type(c_ptr), value :: arg
    type(c_ptr) :: ret
    type(probe_slot), pointer :: slot
    type(barrier_box), pointer :: bar

    call c_f_pointer(arg, slot)
    call c_f_pointer(slot%barrier, bar)
    call barrier_wait(bar)
    if (mod(slot%thread_id, 2_c_int) == 0_c_int) then
      slot%chemfiles = merge(1_c_int, 0_c_int, has_chemfiles())
      slot%readcon = merge(1_c_int, 0_c_int, has_readcon())
    else
      slot%readcon = merge(1_c_int, 0_c_int, has_readcon())
      slot%chemfiles = merge(1_c_int, 0_c_int, has_chemfiles())
    end if
    ret = c_null_ptr
  end function probe_worker

end module dseams_thread_probe

program test_thread_safety
  use, intrinsic :: iso_c_binding
  use seams, only: has_chemfiles, has_readcon
  use dseams_thread_probe, only: barrier_box, probe_slot, barrier_init, &
    barrier_destroy, probe_worker
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
    function dseams_once_state() result(state) bind(c, name="dseams_once_state")
      import :: c_int
      integer(c_int) :: state
    end function dseams_once_state
  end interface

  integer, parameter :: n_threads = 16
  integer(c_long) :: tid(n_threads)
  type(barrier_box), target :: bar
  type(probe_slot), target :: slots(n_threads)
  type(c_ptr) :: retval
  integer :: i, stat
  logical :: post_chem, post_rcon
  integer(c_int) :: want_chem, want_rcon

  call barrier_init(bar, n_threads)

  do i = 1, n_threads
    slots(i)%barrier = c_loc(bar)
    slots(i)%thread_id = int(i, c_int)
    slots(i)%chemfiles = -1_c_int
    slots(i)%readcon = -1_c_int
    stat = pthread_create(tid(i), c_null_ptr, c_funloc(probe_worker), c_loc(slots(i)))
    if (stat /= 0) error stop "pthread_create failed"
  end do

  do i = 1, n_threads
    stat = pthread_join(tid(i), retval)
    if (stat /= 0) error stop "pthread_join failed"
  end do

  call barrier_destroy(bar)

  if (dseams_once_state() /= 2_c_int) stop 4

  post_chem = has_chemfiles()
  post_rcon = has_readcon()
  want_chem = merge(1_c_int, 0_c_int, post_chem)
  want_rcon = merge(1_c_int, 0_c_int, post_rcon)

  do i = 1, n_threads
    if (slots(i)%chemfiles /= want_chem) stop 2
    if (slots(i)%readcon /= want_rcon) stop 3
  end do

  print "(a,i0,a)", "thread safety ", n_threads, " callers agree"
  print "(a)", "fortran thread safety ok"
end program test_thread_safety
