! Copyright (c) d-SEAMS developers
! CON, PDB and GRO. Each read is gated on the feature query and on
! nothing else. DSEAMS_REQUIRE_READERS=1 fails the program when either
! query is false, so a CI job that built the readers in cannot skip.
program test_readers
  use seams
  implicit none
  character(len=512) :: root
  integer :: nroot
  character(len=1), parameter :: roots(1) = ["."]
  logical :: found, chem, rcon
  integer :: up
  integer(seams_int), parameter :: n_con = 4_seams_int
  integer(seams_int), parameter :: n_pdb = 1_seams_int
  integer(seams_int), parameter :: n_gro = 1_seams_int

  ! TMPDIR set to a directory that is not there: the probe must fail
  ! closed, rather than write somewhere else. Both queries are then
  ! false and every read is skipped.
  if (tmpdir_missing()) then
    chem = has_chemfiles()
    rcon = has_readcon()
    call print_flag("has_chemfiles", chem)
    call print_flag("has_readcon", rcon)
    if (chem .or. rcon) stop 6
    print "(a)", "skip con"
    print "(a)", "skip pdb"
    print "(a)", "skip gro"
    print "(a)", "fortran readers ok"
    stop
  end if

  chem = has_chemfiles()
  rcon = has_readcon()
  call print_flag("has_chemfiles", chem)
  call print_flag("has_readcon", rcon)
  if (stamp_requested()) call require_stamp()
  if (readers_required()) then
    if (.not. chem) stop 2
    if (.not. rcon) stop 3
  end if

  if (command_argument_count() >= 1) then
    call get_command_argument(1, root, nroot)
  else
    found = .false.
    do up = 1, size(roots)
      inquire(file=trim(roots(up)) // "/input/traj/ice1h.lammpstrj", exist=found)
      if (found) exit
    end do
    if (.not. found) stop 30
    root = roots(up)
  end if

  if (rcon) then
    call expect_read(trim(root) // "/input/eon/tiny_multi_cuh2.con", n_con, "con")
  else
    print "(a)", "skip con"
  end if
  if (chem) then
    call expect_read(trim(root) // "/input/pdb/one_oxygen.pdb", n_pdb, "pdb")
    call expect_read(trim(root) // "/input/gro/one_oxygen.gro", n_gro, "gro")
  else
    print "(a)", "skip pdb"
    print "(a)", "skip gro"
  end if
  print "(a)", "fortran readers ok"
contains
  subroutine print_flag(name, value)
    character(len=*), intent(in) :: name
    logical, intent(in) :: value
    character(len=1) :: mark
    mark = "F"
    if (value) mark = "T"
    print "(a)", trim(name) // " " // mark
  end subroutine print_flag

  function tmpdir_missing() result(yes)
    logical :: yes
    character(len=:), allocatable :: dir
    integer :: length, stat
    logical :: ex
    yes = .false.
    call get_environment_variable("TMPDIR", length=length, status=stat)
    if (stat /= 0 .or. length <= 0) return
    allocate(character(len=length) :: dir)
    call get_environment_variable("TMPDIR", dir)
    inquire(file=dir, exist=ex)
    yes = .not. ex
  end function tmpdir_missing

  function stamp_requested() result(yes)
    logical :: yes
    character(len=16) :: value
    integer :: length, stat
    call get_environment_variable("DSEAMS_PROBE_STAMP", value, length, stat)
    yes = stat == 0 .and. length > 0 .and. value(1:1) == "1"
  end function stamp_requested

  ! The stamp is one line, the probe path. It has to sit in TMPDIR
  ! (or TEMP, or TMP, or the working directory, in that order).
  subroutine require_stamp()
    character(len=:), allocatable :: dir, line
    character(len=1024) :: buf
    integer :: unit, iostat, length, stat
    logical :: ex
    call get_environment_variable("TMPDIR", length=length, status=stat)
    if (stat /= 0 .or. length <= 0) then
      call get_environment_variable("TEMP", length=length, status=stat)
    end if
    if (stat /= 0 .or. length <= 0) then
      call get_environment_variable("TMP", length=length, status=stat)
    end if
    if (stat /= 0 .or. length <= 0) then
      dir = "."
    else
      allocate(character(len=length) :: dir)
      if (env_is("TMPDIR")) then
        call get_environment_variable("TMPDIR", dir)
      else if (env_is("TEMP")) then
        call get_environment_variable("TEMP", dir)
      else
        call get_environment_variable("TMP", dir)
      end if
    end if
    inquire(file=trim(dir) // "/dseams-probe-stamp", exist=ex)
    if (.not. ex) inquire(file=trim(dir) // "\dseams-probe-stamp", exist=ex)
    if (.not. ex) stop 6
    open(newunit=unit, file=trim(dir) // "/dseams-probe-stamp", status="old", &
      action="read", iostat=iostat)
    if (iostat /= 0) then
      open(newunit=unit, file=trim(dir) // "\dseams-probe-stamp", status="old", &
        action="read", iostat=iostat)
    end if
    if (iostat /= 0) stop 6
    read(unit, "(a)", iostat=iostat) buf
    close(unit, status="delete")
    if (iostat /= 0) stop 6
    line = trim(buf)
    if (index(line, trim(dir)) /= 1) stop 7
  end subroutine require_stamp

  function env_is(name) result(yes)
    character(len=*), intent(in) :: name
    logical :: yes
    integer :: length, stat
    call get_environment_variable(name, length=length, status=stat)
    yes = stat == 0 .and. length > 0
  end function env_is

  function readers_required() result(yes)
    logical :: yes
    character(len=32) :: value
    integer :: length, stat
    call get_environment_variable("DSEAMS_REQUIRE_READERS", value, length, stat)
    yes = stat == 0 .and. length > 0 .and. value(1:1) /= "0"
  end function readers_required

  subroutine expect_read(path, expect, label)
    character(len=*), intent(in) :: path
    integer(seams_int), intent(in) :: expect
    character(len=*), intent(in) :: label
    type(seams_frame) :: frame
    integer(seams_int) :: stat, n
    character(len=:), allocatable :: err
    frame = new_frame(stat, err)
    if (stat /= SEAMS_OK) stop 4
    call frame%read(path, stat=stat, errmsg=err)
    if (stat /= SEAMS_OK) then
      print "(a)", "read " // trim(label) // " failed"
      stop 4
    end if
    n = frame%count()
    print "(a,i0)", "read " // trim(label) // " ", n
    if (n /= expect) stop 5
    call frame%close()
  end subroutine expect_read
end program test_readers
