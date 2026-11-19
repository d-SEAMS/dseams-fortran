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

  function stamp_requested() result(yes)
    logical :: yes
    character(len=16) :: value
    integer :: length, stat
    call get_environment_variable("DSEAMS_PROBE_STAMP", value, length, stat)
    yes = stat == 0 .and. length > 0 .and. value(1:1) == "1"
  end function stamp_requested

  function join_dir(dir, name) result(path)
    character(len=*), intent(in) :: dir, name
    character(len=:), allocatable :: path
    character(len=1) :: sep
    if (len(dir) == 0) then
      path = name
      return
    end if
    if (dir(len(dir):len(dir)) == "/" .or. dir(len(dir):len(dir)) == "\") then
      path = dir // name
      return
    end if
    sep = "/"
    if (index(dir, "\") > 0 .and. index(dir, "/") == 0) sep = "\"
    path = dir // sep // name
  end function join_dir

  function normalize_dir(raw) result(dir)
    character(len=*), intent(in) :: raw
    character(len=:), allocatable :: dir
    dir = trim(raw)
    do while (len(dir) > 1)
      if (dir(len(dir):len(dir)) /= "/" .and. dir(len(dir):len(dir)) /= "\") exit
      dir = dir(1:len(dir) - 1)
    end do
  end function normalize_dir

  function env_raw(name) result(value)
    character(len=*), intent(in) :: name
    character(len=:), allocatable :: value
    integer :: length, stat
    call get_environment_variable(name, length=length, status=stat)
    if (stat /= 0 .or. length <= 0) then
      value = ""
      return
    end if
    allocate(character(len=length) :: value)
    call get_environment_variable(name, value)
  end function env_raw

  ! The stamp is one line, the probe path. It has to sit in the
  ! directory probe_directory() returns. A present, writable TMPDIR
  ! is that directory. A TMPDIR that does not exist is not. With
  ! TMPDIR, TEMP and TMP all unset, the directory is the working
  ! directory.
  subroutine require_stamp()
    character(len=:), allocatable :: dir, line, stamp, tmp
    character(len=1024) :: buf
    integer :: unit, iostat
    logical :: ex
    dir = probe_directory()
    if (len(dir) == 0) stop 6
    tmp = env_raw("TMPDIR")
    if (len(tmp) > 0) then
      inquire(file=tmp, exist=ex)
      if (ex) then
        if (normalize_dir(dir) /= normalize_dir(tmp)) stop 8
      else if (normalize_dir(dir) == normalize_dir(tmp)) then
        stop 8
      end if
    else if (len(env_raw("TEMP")) == 0 .and. len(env_raw("TMP")) == 0) then
      if (dir /= ".") stop 8
    end if
    stamp = join_dir(dir, "dseams-probe-stamp")
    inquire(file=stamp, exist=ex)
    if (.not. ex) stop 6
    open(newunit=unit, file=stamp, status="old", action="read", iostat=iostat)
    if (iostat /= 0) stop 6
    read(unit, "(a)", iostat=iostat) buf
    close(unit, status="delete")
    if (iostat /= 0) stop 6
    line = trim(buf)
    if (index(line, trim(dir)) /= 1) stop 7
  end subroutine require_stamp

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
