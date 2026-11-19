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
