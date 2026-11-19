! Copyright (c) d-SEAMS developers
! A standalone consumer of the feature-query API, separate from
! test_readers.f90. has_chemfiles, has_readcon and probe_directory are
! Fortran-only: nothing changed in include/seams.h or libseams_lang to
! add them, so this program is the thing that fails to build against
! a seams.mod from before they existed and builds clean once they are
! there. It does not read a trajectory; test_readers.f90 already does.
program test_feature_query
  use seams, only: seams_int, has_chemfiles, has_readcon, probe_directory
  implicit none
  logical :: chem, rcon
  character(len=:), allocatable :: dir
  character(len=1) :: mark

  chem = has_chemfiles()
  rcon = has_readcon()
  call probe_directory(dir)

  mark = "F"
  if (chem) mark = "T"
  print "(a)", "feature query has_chemfiles " // mark
  mark = "F"
  if (rcon) mark = "T"
  print "(a)", "feature query has_readcon " // mark
  print "(a,a,a)", "feature query probe_directory '", dir, "'"

  ! chem and rcon are independent facts about the loaded libseams; a
  ! probe_directory that reports no writable candidate (an empty
  ! string) makes both false, since neither query can write its file.
  if (len(dir) == 0 .and. (chem .or. rcon)) stop 2

  print "(a)", "fortran feature query ok"
end program test_feature_query
