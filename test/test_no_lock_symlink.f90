! Copyright (c) d-SEAMS developers
!
! Regression test for symlink-planting attacks on probe/lock paths.
! An earlier revision of has_chemfiles/has_readcon serialised the probe
! behind flock(2) on a fixed name, "dseams-probe.lock", opened with
! creat(2), which follows symlinks and truncates the target (O_TRUNC).
!
! The current implementation uses a C-owned static atomic_int once-guard
! (src/dseams_once.c) and writes each probe file inside a private 0700
! directory through one O_CREAT|O_EXCL|O_NOFOLLOW descriptor
! (dseams_probe_write). This test checks both:
!   1. A symlink planted at the retired "dseams-probe.lock" name
!      pointing at a victim file is untouched by has_chemfiles() and
!      has_readcon().
!   2. A symlink planted directly at a probe candidate path and passed
!      to dseams_probe_write is refused without truncating the victim.
!
! Symlinks are created via POSIX symlink(2) through iso_c_binding (no
! shell invocation, safe with spaces or metacharacters in paths).
! Missing preconditions exit 77 outside CI (Meson SKIP) and fail hard
! under CI.
program test_no_lock_symlink
  use, intrinsic :: iso_fortran_env, only: int64
  use, intrinsic :: iso_c_binding, only: c_char, c_int, c_size_t, c_null_char
  use seams, only: has_chemfiles, has_readcon, probe_directory
  implicit none

  interface
    function c_symlink(target, linkpath) result(rc) bind(c, name="symlink")
      import :: c_char, c_int
      character(kind=c_char), intent(in) :: target(*), linkpath(*)
      integer(c_int) :: rc
    end function c_symlink
    function c_unlink(pathname) result(rc) bind(c, name="unlink")
      import :: c_char, c_int
      character(kind=c_char), intent(in) :: pathname(*)
      integer(c_int) :: rc
    end function c_unlink
    function dseams_probe_write(path, buf, length) result(rc) bind(c, name="dseams_probe_write")
      import :: c_char, c_size_t, c_int
      character(kind=c_char), intent(in) :: path(*), buf(*)
      integer(c_size_t), value :: length
      integer(c_int) :: rc
    end function dseams_probe_write
  end interface

  character(len=:), allocatable :: dir, victim, old_lock_name, probe_symlink
  character(len=*), parameter :: payload = "do not truncate me"
  character(len=len(payload)) :: read_back
  character(kind=c_char) :: overwrite_buf(4)
  integer :: unit, iostat
  integer(c_int) :: rc
  logical :: chem, rcon, ex, ci
  character(len=32) :: suffix

  ci = running_in_ci()

  call probe_directory(dir)
  if (len(dir) == 0) then
    call skip_or_fail(ci, "no writable probe directory for the symlink check")
  end if

  call pid_suffix(suffix)
  victim = trim(dir) // "/dseams-symlink-victim-" // trim(suffix)
  old_lock_name = trim(dir) // "/dseams-probe.lock"
  probe_symlink = trim(dir) // "/dseams-symlink-probe-" // trim(suffix) // ".pdb"

  call delete_if_exists(old_lock_name)
  call delete_if_exists(probe_symlink)
  call delete_if_exists(victim)

  open(newunit=unit, file=victim, status="new", action="write", iostat=iostat)
  if (iostat /= 0) error stop "could not create the victim file"
  write(unit, "(a)", advance="no") payload
  close(unit)

  rc = c_symlink(c_str(victim), c_str(old_lock_name))
  if (rc /= 0_c_int) then
    call delete_if_exists(victim)
    call skip_or_fail(ci, "symlink(2) unavailable to plant the symlink")
  end if

  inquire(file=old_lock_name, exist=ex)
  if (.not. ex) error stop "the planted lock symlink did not appear"

  rc = c_symlink(c_str(victim), c_str(probe_symlink))
  if (rc /= 0_c_int) then
    call delete_if_exists(old_lock_name)
    call delete_if_exists(victim)
    call skip_or_fail(ci, "symlink(2) unavailable to plant the probe symlink")
  end if

  overwrite_buf = ["E", "V", "I", "L"]
  rc = dseams_probe_write(c_str(probe_symlink), overwrite_buf, 4_c_size_t)
  if (rc == 0_c_int) then
    call delete_if_exists(probe_symlink)
    call delete_if_exists(old_lock_name)
    call delete_if_exists(victim)
    error stop "dseams_probe_write followed a symlink instead of refusing it"
  end if

  chem = has_chemfiles()
  rcon = has_readcon()

  call check_victim_intact(victim, payload, read_back)

  call delete_if_exists(probe_symlink)
  call delete_if_exists(old_lock_name)
  call delete_if_exists(victim)

  print "(a,l1,a,l1)", "no lock symlink has_chemfiles ", chem, " has_readcon ", rcon
  print "(a)", "fortran no lock symlink ok"
contains
  function c_str(text) result(buf)
    character(len=*), intent(in) :: text
    character(kind=c_char), allocatable :: buf(:)
    integer :: i, n
    n = len_trim(text)
    allocate(buf(n + 1))
    do i = 1, n
      buf(i) = text(i:i)
    end do
    buf(n + 1) = c_null_char
  end function c_str

  subroutine check_victim_intact(path, expected, actual)
    character(len=*), intent(in) :: path, expected
    character(len=*), intent(out) :: actual
    integer :: lu, ios
    open(newunit=lu, file=path, status="old", action="read", iostat=ios)
    if (ios /= 0) error stop "the victim file disappeared"
    actual = ""
    read(lu, "(a)", iostat=ios) actual
    close(lu)
    if (ios /= 0 .and. ios /= -1) error stop "could not read the victim file back"
    if (actual /= expected) then
      print "(a,a,a,a,a)", "victim file read back as '", trim(actual), &
        "', expected '", expected, "'"
      error stop "the victim file was modified: a symlink was followed"
    end if
  end subroutine check_victim_intact

  function running_in_ci() result(yes)
    logical :: yes
    character(len=8) :: value
    integer :: length, stat
    call get_environment_variable("CI", value, length, stat)
    yes = (stat == 0 .or. stat == -1) .and. length > 0
  end function running_in_ci

  subroutine skip_or_fail(in_ci, reason)
    logical, intent(in) :: in_ci
    character(len=*), intent(in) :: reason
    if (in_ci) then
      print "(a)", "FAIL: " // reason // &
        " (CI must provide this; the symlink regression check did not run)"
      error stop "symlink regression check did not run under CI"
    end if
    print "(a)", "SKIP: " // reason // &
      "; the symlink regression check did not run"
    stop 77
  end subroutine skip_or_fail

  subroutine pid_suffix(text)
    character(len=*), intent(out) :: text
    integer(int64) :: ticks
    call system_clock(ticks)
    write(text, "(i0)") ticks
  end subroutine pid_suffix

  subroutine delete_if_exists(path)
    character(len=*), intent(in) :: path
    integer(c_int) :: unused
    unused = c_unlink(c_str(path))
  end subroutine delete_if_exists
end program test_no_lock_symlink
