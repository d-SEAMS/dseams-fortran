! Copyright (c) d-SEAMS developers
!
! Regression test for the symlink-planting attack the once-guard used
! to be exposed to. An earlier revision of has_chemfiles/has_readcon's
! fix serialised the probe behind flock(2) on a fixed name,
! "dseams-probe.lock", in the first writable directory of TMPDIR,
! TEMP, TMP or the working directory, opened with creat(2). creat(2)
! follows a symlink and truncates its target (O_TRUNC); the lock file
! was never unlinked, so the name was predictable and reusable run to
! run. In a shared, world-writable temp directory, another user could
! plant a symlink at that exact name ahead of time, pointing at a file
! they want truncated, and this process would do it for them the next
! time it ran.
!
! The once-guard this project ships now (src/dseams_once.c) has no
! filesystem footprint at all: it is a plain in-process compare-and-
! swap on an integer, nothing a symlink could intercept. This test
! proves that directly: plant a symlink at the exact old name, in the
! exact directory the probe itself reports, pointing at a "victim"
! file with known content, then run the real probe through
! has_chemfiles and has_readcon and check the victim is untouched.
!
! Two preconditions make that plant-and-check possible: a writable
! probe directory, and ln(1) to create the symlink. Neither failing
! is ever reported as "ok": that would print a pass for a check that
! never ran. Under CI (the CI environment variable, set by every
! common CI system including GitHub Actions), both preconditions
! always hold on this project's own runner, so a precondition failure
! there means the runner itself is broken, not a legitimate skip, and
! this program fails hard (STOP with a nonzero, non-77 status).
! Outside CI, a missing precondition is a real, reportable skip: STOP
! 77, the GNU/automake convention meson's test harness hardcodes as
! SKIP (mesonbuild/mtest.py: GNU_SKIP_RETURNCODE; there is no per-test
! kwarg to set it, since it is not configurable); fpm has no skip
! concept, so the same STOP 77 is simply a failure there, which is the
! honest fallback when the test runner cannot represent "skipped".
program test_no_lock_symlink
  use, intrinsic :: iso_fortran_env, only: int64
  use seams, only: has_chemfiles, has_readcon, probe_directory
  implicit none
  character(len=:), allocatable :: dir, victim, old_lock_name
  character(len=*), parameter :: payload = "do not truncate me"
  character(len=len(payload)) :: read_back
  integer :: unit, iostat, cmdstat, exitstat
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

  ! A stale symlink or victim from a previous, killed run must not
  ! make this run's planting step (or its cleanup) fail.
  call delete_if_exists(old_lock_name)
  call delete_if_exists(victim)

  open(newunit=unit, file=victim, status="new", action="write", iostat=iostat)
  if (iostat /= 0) error stop "could not create the victim file"
  write(unit, "(a)", advance="no") payload
  close(unit)

  call execute_command_line("ln -s " // victim // " " // old_lock_name, &
    wait=.true., exitstat=exitstat, cmdstat=cmdstat)
  if (cmdstat /= 0 .or. exitstat /= 0) then
    call delete_if_exists(victim)
    call skip_or_fail(ci, "no ln(1) available to plant the symlink")
  end if

  inquire(file=old_lock_name, exist=ex)
  if (.not. ex) error stop "the planted symlink did not appear"

  ! The real probe mechanism: has_chemfiles and has_readcon each run
  ! their once-guarded probe exactly as a real caller would. Neither
  ! one knows or cares that dseams-probe.lock exists in this
  ! directory; nothing in src/seams_methods.f90 opens that name any
  ! more.
  chem = has_chemfiles()
  rcon = has_readcon()

  open(newunit=unit, file=victim, status="old", action="read", iostat=iostat)
  if (iostat /= 0) error stop "the victim file disappeared"
  read_back = ""
  read(unit, "(a)", iostat=iostat) read_back
  close(unit)

  if (iostat /= 0 .and. iostat /= -1) error stop "could not read the victim file back"
  if (read_back /= payload) then
    print "(a,a,a,a,a)", "victim file read back as '", trim(read_back), &
      "', expected '", payload, "'"
    error stop "the victim file was modified: the old lock path was followed"
  end if

  call delete_if_exists(old_lock_name)
  call delete_if_exists(victim)

  print "(a,l1,a,l1)", "no lock symlink has_chemfiles ", chem, " has_readcon ", rcon
  print "(a)", "fortran no lock symlink ok"
contains
  ! CI is the one variable every common CI system sets (GitHub Actions,
  ! GitLab CI, Travis, CircleCI); a short VALUE buffer is fine, since
  ! get_environment_variable reports stat=-1 (not 1, "does not exist")
  ! when the real value just does not fit, so both stat values below
  ! mean "the variable is set", regardless of what it is set to.
  function running_in_ci() result(yes)
    logical :: yes
    character(len=8) :: value
    integer :: length, stat
    call get_environment_variable("CI", value, length, stat)
    yes = (stat == 0 .or. stat == -1) .and. length > 0
  end function running_in_ci

  ! Never prints "ok": that would report a pass for a check that did
  ! not run. Under CI, a missing precondition is this runner's own
  ! fault, so it is a hard failure. Elsewhere, it is a real skip:
  ! STOP 77, meson's hardcoded skip convention, reported SKIP there;
  ! fpm has no skip concept, so the same exit code is just a failure
  ! under fpm, the most honest thing fpm can report.
  subroutine skip_or_fail(ci, reason)
    logical, intent(in) :: ci
    character(len=*), intent(in) :: reason
    if (ci) then
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
    integer :: lu, ios
    logical :: present_here
    inquire(file=path, exist=present_here)
    if (.not. present_here) return
    open(newunit=lu, file=path, status="old", iostat=ios)
    if (ios == 0) close(lu, status="delete")
  end subroutine delete_if_exists
end program test_no_lock_symlink
