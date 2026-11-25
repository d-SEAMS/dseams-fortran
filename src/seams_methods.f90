! Copyright (c) d-SEAMS developers
submodule (seams) seams_methods
  use, intrinsic :: iso_fortran_env, only: int64, error_unit
  use seams_kinds, only: c_ptr, c_null_ptr, c_associated, c_loc, c_int, c_double, c_size_t, c_char, c_null_char
  use seams_c, only: seams_version_string, seams_label_name, seams_status_string, &
    seams_set_num_threads, seams_get_num_threads, seams_system_create, &
    seams_system_set_ortho, seams_system_set_frame, seams_system_read, seams_system_count, &
    seams_chill, seams_chill_plus, seams_q4q6, seams_ql, seams_steinhardt, seams_q6bar, &
    seams_neighbours_build, seams_neighbours_knn, seams_neighbours_count, seams_neighbours_copy, &
    seams_rings_find, seams_rings_count, seams_rings_histogram, seams_rings_fraction, &
    seams_rings_labels, seams_rings_vertices, c_seams_cages => seams_cages, seams_cages_counts, seams_cages_labels, &
    seams_signature_cages, seams_rdf, seams_running_cn, seams_coordination, seams_hbonds, &
    seams_density_axis, seams_fingerprint, seams_fingerprint_key, seams_fingerprint_atom, &
    seams_fingerprint_rings, seams_contact_pairs, seams_domains, seams_prisms, seams_monolayer, &
    seams_site_table, seams_system_symmetry, seams_brine_analyse, seams_brine_fronts, &
    seams_brine_rejection, seams_brine_profile, seams_brine_pockets, seams_path_nframes
  use seams_support, only: handle_acquire, handle_release, handle_share, handle_get, &
    c_to_f, f_to_c, check_status, copy_key, kind_system, kind_neighbours, kind_rings, &
    kind_cages, kind_topo, kind_brine
  implicit none

  ! has_chemfiles and has_readcon used to cache their answer in a
  ! logical/logical pair ("known"/"value"), set by whichever caller ran
  ! the probe first. Two threads racing that first call could
  ! interleave the writes to "known" and "value" with no ordering
  ! guarantee between them, so a second caller could read a "known"
  ! that is true and a "value" that is still its unset default.
  !
  ! Computing the answer fresh on every call, with no shared state at
  ! all, does not fix this on its own: has_chemfiles and has_readcon
  ! both end by calling frame%read, which this package does not control
  ! and does not know to be safe to call from more than one thread at
  ! once. Sixteen threads probing at the same time, with no caching,
  ! reproduced exactly that: one caller's probe reported false while
  ! every other caller, running at the same moment, reported true.
  !
  ! Both queries share one C-owned static atomic_int once-guard
  ! (dseams_once_enter/dseams_once_done/dseams_once_state, in
  ! src/dseams_once.c) and one shared initialization (probe_readers).
  ! That guarantees at most one thread ever runs the probes, and runs
  ! the chemfiles and readcon frame%read probes sequentially rather than
  ! concurrently. Every other caller blocks until that single run
  ! finishes, then reads chem_cached or con_cached.
  !
  ! An earlier version of this fix used pthread_once instead. That only
  ! works where a zero-initialised pthread_once_t equals
  ! PTHREAD_ONCE_INIT: true on the glibc this project's CI links
  ! against, not guaranteed by POSIX, and false on macOS on purpose
  ! (Darwin's PTHREAD_ONCE_INIT is a non-zero signature word, so a
  ! never-set-up instance is invalid rather than silently working). A
  ! later revision of that fix serialised the probe behind an exclusive
  ! flock(2) on a file from creat(2) instead, to dodge the
  ! PTHREAD_ONCE_INIT problem; creat(2) follows a symlink and truncates
  ! its target (O_TRUNC), and the chosen path, a fixed name in TMPDIR
  ! or the working directory, is predictable and never unlinked. In a
  ! shared, world-writable /tmp, another user can plant a symlink at
  ! that name ahead of time and have the next run of this process
  ! truncate whatever the symlink points at; see
  ! test/test_no_lock_symlink.f90.
  !
  ! Neither of those OS-level primitives was ever load-bearing: the
  ! cached answers (chem_cached/con_cached below) are plain Fortran
  ! module variables, private to this process's address space, and the
  ! probe creates a private 0700 subdirectory via mkdir and writes each
  ! trial file inside it through a single O_CREAT|O_EXCL|O_NOFOLLOW
  ! descriptor (dseams_probe_write), with no create-close-reopen TOCTOU
  ! window. The once-state lives inside src/dseams_once.c as a static
  ! atomic_int so Fortran never aliases an atomic_int with a plain
  ! integer(c_int).
  logical, save :: chem_cached = .false.
  logical, save :: con_cached = .false.

  interface
    function dseams_once_enter() result(enter) bind(c, name="dseams_once_enter")
      import :: c_int
      integer(c_int) :: enter
    end function dseams_once_enter
    subroutine dseams_once_done() bind(c, name="dseams_once_done")
    end subroutine dseams_once_done
    function dseams_once_state() result(state) bind(c, name="dseams_once_state")
      import :: c_int
      integer(c_int) :: state
    end function dseams_once_state
    function dseams_probe_mkdir(path) result(rc) bind(c, name="dseams_probe_mkdir")
      import :: c_char, c_int
      character(kind=c_char), intent(in) :: path(*)
      integer(c_int) :: rc
    end function dseams_probe_mkdir
    function dseams_probe_write(path, buf, length) result(rc) bind(c, name="dseams_probe_write")
      import :: c_char, c_size_t, c_int
      character(kind=c_char), intent(in) :: path(*), buf(*)
      integer(c_size_t), value :: length
      integer(c_int) :: rc
    end function dseams_probe_write
    function dseams_probe_write_stamp(path, buf, length) result(rc) bind(c, name="dseams_probe_write_stamp")
      import :: c_char, c_size_t, c_int
      character(kind=c_char), intent(in) :: path(*), buf(*)
      integer(c_size_t), value :: length
      integer(c_int) :: rc
    end function dseams_probe_write_stamp
    subroutine dseams_probe_unlink(path) bind(c, name="dseams_probe_unlink")
      import :: c_char
      character(kind=c_char), intent(in) :: path(*)
    end subroutine dseams_probe_unlink
    subroutine dseams_probe_rmdir(path) bind(c, name="dseams_probe_rmdir")
      import :: c_char
      character(kind=c_char), intent(in) :: path(*)
    end subroutine dseams_probe_rmdir
  end interface
contains

  function opt_real(value, fallback) result(out)
    real(seams_real), intent(in), optional :: value
    real(seams_real), intent(in) :: fallback
    real(seams_real) :: out
    if (present(value)) then
      out = value
    else
      out = fallback
    end if
  end function opt_real

  function opt_int(value, fallback) result(out)
    integer(seams_int), intent(in), optional :: value
    integer(seams_int), intent(in) :: fallback
    integer(c_int) :: out
    if (present(value)) then
      out = int(value, c_int)
    else
      out = int(fallback, c_int)
    end if
  end function opt_int

  function opt_flag(value, fallback) result(out)
    logical, intent(in), optional :: value
    logical, intent(in) :: fallback
    integer(c_int) :: out
    logical :: chosen
    if (present(value)) then
      chosen = value
    else
      chosen = fallback
    end if
    if (chosen) then
      out = 1_c_int
    else
      out = 0_c_int
    end if
  end function opt_flag

  function open_raw(box, stat, errmsg, what) result(raw)
    type(handle_box), pointer, intent(in) :: box
    integer(seams_int), intent(out), optional :: stat
    character(len=:), allocatable, intent(out), optional :: errmsg
    character(len=*), intent(in) :: what
    type(c_ptr) :: raw
    raw = handle_get(box)
    if (.not. c_associated(raw)) then
      call check_status(int(SEAMS_ERR_NULL, c_int), c_null_ptr, stat, errmsg, trim(what)//" is closed")
    end if
  end function open_raw

  function pack_optional(n, values, buf, ptr, stat, errmsg, what) result(ok)
    integer, intent(in) :: n
    integer(seams_int), intent(in), optional :: values(:)
    integer(c_int), allocatable, target, intent(out) :: buf(:)
    type(c_ptr), intent(out) :: ptr
    integer(seams_int), intent(out), optional :: stat
    character(len=:), allocatable, intent(out), optional :: errmsg
    character(len=*), intent(in) :: what
    logical :: ok
    ok = .true.
    ptr = c_null_ptr
    if (.not. present(values)) return
    if (size(values) /= n) then
      ok = .false.
      call check_status(int(SEAMS_ERR_ARG, c_int), c_null_ptr, stat, errmsg, trim(what)//" length is not the atom count")
      return
    end if
    allocate(buf(n))
    buf = int(values, c_int)
    ptr = c_loc(buf)
  end function pack_optional

  function shape_ok(xyz, stat, errmsg) result(ok)
    real(seams_real), intent(in) :: xyz(:, :)
    integer(seams_int), intent(out), optional :: stat
    character(len=:), allocatable, intent(out), optional :: errmsg
    logical :: ok
    ok = size(xyz, 1) == 3
    if (.not. ok) then
      call check_status(int(SEAMS_ERR_ARG, c_int), c_null_ptr, stat, errmsg, "xyz must have shape (3, n)")
    end if
  end function shape_ok

  subroutine take_key(raw, index, key, stat, errmsg)
    type(c_ptr), intent(in) :: raw
    integer(c_int), intent(in) :: index
    character(len=:), allocatable, intent(out) :: key
    integer(seams_int), intent(out), optional :: stat
    character(len=:), allocatable, intent(out), optional :: errmsg
    integer(c_size_t) :: n, cap
    integer(c_int) :: code
    character(kind=c_char), allocatable, target :: buf(:)
    if (index < 0_c_int) then
      code = seams_fingerprint_key(raw, c_null_ptr, 0_c_size_t, n)
    else
      code = seams_fingerprint_atom(raw, index, c_null_ptr, 0_c_size_t, n)
    end if
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      key = ""
      return
    end if
    allocate(buf(int(n) + 1))
    cap = n + 1_c_size_t
    if (index < 0_c_int) then
      code = seams_fingerprint_key(raw, c_loc(buf), cap, n)
    else
      code = seams_fingerprint_atom(raw, index, c_loc(buf), cap, n)
    end if
    if (code /= SEAMS_OK) then
      deallocate(buf)
      call check_status(code, raw, stat, errmsg)
      key = ""
      return
    end if
    call copy_key(buf, int(n), key)
    ! c_loc on this buffer keeps gfortran from freeing it on return.
    deallocate(buf)
    call check_status(code, raw, stat, errmsg)
  end subroutine take_key

  module procedure new_frame
    type(c_ptr) :: raw
    raw = seams_system_create()
    if (.not. c_associated(raw)) then
      call check_status(int(SEAMS_ERR_NOMEM, c_int), c_null_ptr, stat, errmsg, "out of memory")
      return
    end if
    call handle_acquire(self%box, raw, kind_system)
    call check_status(0_c_int, raw, stat, errmsg)
  end procedure new_frame

  module procedure version_text
    call c_to_f(seams_version_string(), text)
  end procedure version_text

  module procedure set_num_threads
    integer(c_int) :: code
    code = seams_set_num_threads(int(n, c_int))
    call check_status(code, c_null_ptr, stat, errmsg)
  end procedure set_num_threads

  module procedure num_threads
    n = int(seams_get_num_threads(), seams_int)
  end procedure num_threads

  module procedure label_name
    call c_to_f(seams_label_name(int(code, c_int)), text)
  end procedure label_name

  module procedure status_text
    call c_to_f(seams_status_string(int(code, c_int)), text)
  end procedure status_text

  module procedure path_nframes
    character(kind=c_char), allocatable, target :: text(:)
    integer(c_size_t) :: count
    integer(c_int) :: code
    nframes = 0_seams_int
    text = f_to_c(path)
    code = seams_path_nframes(text, count)
    if (code /= SEAMS_OK) then
      call check_status(code, c_null_ptr, stat, errmsg)
      return
    end if
    nframes = int(count, seams_int)
    call check_status(code, c_null_ptr, stat, errmsg)
  end procedure path_nframes




  module procedure frame_set_ortho
    type(c_ptr) :: raw, types_ptr, ids_ptr
    integer(c_int), allocatable, target :: types_buf(:), ids_buf(:)
    integer(c_int) :: code, n
    real(seams_real), allocatable :: flat(:)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    if (.not. shape_ok(xyz, stat, errmsg)) return
    n = int(size(xyz, 2), c_int)
    flat = reshape(xyz, [3 * size(xyz, 2)])
    if (.not. pack_optional(size(xyz, 2), types, types_buf, types_ptr, stat, errmsg, "types")) return
    if (.not. pack_optional(size(xyz, 2), ids, ids_buf, ids_ptr, stat, errmsg, "ids")) return
    code = seams_system_set_ortho(raw, flat, n, opt_real(ox, 0.0_seams_real), &
      opt_real(oy, 0.0_seams_real), opt_real(oz, 0.0_seams_real), lx, ly, lz, types_ptr, ids_ptr)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_set_ortho

  module procedure frame_set_frame
    type(c_ptr) :: raw, types_ptr, ids_ptr
    integer(c_int), allocatable, target :: types_buf(:), ids_buf(:)
    integer(c_int) :: code, n
    real(seams_real), allocatable :: flat(:)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    if (.not. shape_ok(xyz, stat, errmsg)) return
    n = int(size(xyz, 2), c_int)
    flat = reshape(xyz, [3 * size(xyz, 2)])
    if (.not. pack_optional(size(xyz, 2), types, types_buf, types_ptr, stat, errmsg, "types")) return
    if (.not. pack_optional(size(xyz, 2), ids, ids_buf, ids_ptr, stat, errmsg, "ids")) return
    code = seams_system_set_frame(raw, flat, n, box, types_ptr, ids_ptr)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_set_frame

  module procedure frame_read
    type(c_ptr) :: raw
    character(kind=c_char), allocatable, target :: text(:)
    integer(c_int) :: code
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    text = f_to_c(path)
    code = seams_system_read(raw, text, opt_int(frame, 1_seams_int), opt_int(type_filter, -1_seams_int))
    call check_status(code, raw, stat, errmsg)
  end procedure frame_read

  module procedure frame_count
    type(c_ptr) :: raw
    raw = handle_get(self%box)
    if (.not. c_associated(raw)) then
      n = 0_seams_int
    else
      n = int(seams_system_count(raw), seams_int)
    end if
  end procedure frame_count

  subroutine chill_common(self, labels, counts, cutoff, typ, graph, rule, which, stat, errmsg)
    class(seams_frame), intent(inout) :: self
    integer(seams_int), allocatable, intent(out) :: labels(:)
    integer(seams_int), allocatable, intent(out), optional :: counts(:)
    real(seams_real), intent(in), optional :: cutoff
    integer(seams_int), intent(in), optional :: typ, graph, rule
    integer, intent(in) :: which
    integer(seams_int), intent(out), optional :: stat
    character(len=:), allocatable, intent(out), optional :: errmsg
    type(c_ptr) :: raw
    integer(c_int) :: code, n
    integer(seams_int), allocatable, target :: tally(:)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    n = seams_system_count(raw)
    if (n <= 0_c_int) then
      call check_status(int(SEAMS_ERR_STATE, c_int), raw, stat, errmsg, "frame has no atoms")
      return
    end if
    allocate(labels(n), tally(9))
    if (which == 0) then
      code = seams_chill(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
        opt_int(graph, SEAMS_GRAPH_CUTOFF), opt_int(rule, SEAMS_CHILL_PUBLISHED), labels, &
        int(n, c_size_t), tally)
    else
      code = seams_chill_plus(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
        opt_int(graph, SEAMS_GRAPH_CUTOFF), opt_int(rule, SEAMS_CHILL_PUBLISHED), labels, tally)
    end if
    if (code /= SEAMS_OK) then
      deallocate(labels)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    if (present(counts)) counts = tally
    call check_status(code, raw, stat, errmsg)
  end subroutine chill_common

  module procedure frame_chill
    call chill_common(self, labels, counts, cutoff, typ, graph, rule, 0, stat, errmsg)
  end procedure frame_chill

  module procedure frame_chill_plus
    call chill_common(self, labels, counts, cutoff, typ, graph, rule, 1, stat, errmsg)
  end procedure frame_chill_plus

  module procedure frame_q4q6
    type(c_ptr) :: raw
    integer(c_int) :: code, n
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    n = seams_system_count(raw)
    allocate(q4(n), q6(n))
    code = seams_q4q6(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), q4, q6)
    if (code /= SEAMS_OK) then
      deallocate(q4, q6)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    call check_status(code, raw, stat, errmsg)
  end procedure frame_q4q6

  module procedure frame_ql
    type(c_ptr) :: raw, bar_ptr
    integer(c_int) :: code, n
    integer(c_size_t) :: bar_len
    real(seams_real), allocatable, target :: qbuf(:), barbuf(:)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    n = seams_system_count(raw)
    allocate(qbuf(n))
    bar_ptr = c_null_ptr
    bar_len = 0_c_size_t
    if (present(qlbar)) then
      allocate(barbuf(n))
      bar_ptr = c_loc(barbuf)
      bar_len = int(n, c_size_t)
    end if
    code = seams_ql(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
      int(order_l, c_int), opt_int(graph, SEAMS_GRAPH_CUTOFF), c_loc(qbuf), int(n, c_size_t), &
      bar_ptr, bar_len)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    ql = qbuf
    if (present(qlbar)) qlbar = barbuf
    call check_status(code, raw, stat, errmsg)
  end procedure frame_ql

  module procedure frame_steinhardt
    type(c_ptr) :: raw
    integer(c_int) :: code, n
    real(seams_real), allocatable :: bar(:)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    n = seams_system_count(raw)
    allocate(ql(n), bar(n))
    code = seams_steinhardt(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
      int(order_l, c_int), ql, int(n, c_size_t), bar, int(n, c_size_t))
    if (code /= SEAMS_OK) then
      deallocate(ql)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    if (present(qlbar)) qlbar = bar
    call check_status(code, raw, stat, errmsg)
  end procedure frame_steinhardt

  module procedure frame_q6bar
    type(c_ptr) :: raw, qptr, mean_ptr, median_ptr, ice_ptr
    integer(c_int) :: code, n
    integer(c_size_t) :: qlen
    real(seams_real), allocatable, target :: qbuf(:)
    real(seams_real), target :: mean_b, median_b
    integer(c_int), target :: ice_b
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    if (.not. (present(q6bar) .or. present(mean) .or. present(median) .or. present(n_ice))) then
      call check_status(int(SEAMS_ERR_ARG, c_int), raw, stat, errmsg, "q6bar needs one output")
      return
    end if
    n = seams_system_count(raw)
    qptr = c_null_ptr
    mean_ptr = c_null_ptr
    median_ptr = c_null_ptr
    ice_ptr = c_null_ptr
    qlen = 0_c_size_t
    if (present(q6bar)) then
      allocate(qbuf(n))
      qptr = c_loc(qbuf)
      qlen = int(n, c_size_t)
    end if
    if (present(mean)) mean_ptr = c_loc(mean_b)
    if (present(median)) median_ptr = c_loc(median_b)
    if (present(n_ice)) ice_ptr = c_loc(ice_b)
    code = seams_q6bar(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
      opt_real(ice_cut, 0.36_seams_real), qptr, qlen, mean_ptr, median_ptr, ice_ptr)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    if (present(q6bar)) call move_alloc(qbuf, q6bar)
    if (present(mean)) mean = mean_b
    if (present(median)) median = median_b
    if (present(n_ice)) n_ice = int(ice_b, seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_q6bar

  module procedure frame_neighbours
    type(c_ptr) :: raw, out
    integer(c_int) :: code
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    code = seams_neighbours_build(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
      opt_int(graph, SEAMS_GRAPH_CUTOFF), out)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    call handle_acquire(list%box, out, kind_neighbours)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_neighbours

  module procedure frame_knn
    type(c_ptr) :: raw, out
    integer(c_int) :: code
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    code = seams_neighbours_knn(raw, int(k, c_int), opt_real(cutoff, 3.5_seams_real), &
      opt_int(typ, 0_seams_int), opt_flag(mutual, .true.), out)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    call handle_acquire(list%box, out, kind_neighbours)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_knn

  module procedure frame_rings
    type(c_ptr) :: raw, out
    integer(c_int) :: code, depth
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    depth = opt_int(max_depth, 6_seams_int)
    code = seams_rings_find(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
      opt_int(graph, SEAMS_GRAPH_CUTOFF), depth, out)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    call handle_acquire(rings%box, out, kind_rings)
    rings%max_depth = int(depth, seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_rings

  module procedure frame_cages
    type(c_ptr) :: raw, out
    integer(c_int) :: code
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    code = c_seams_cages(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
      opt_int(graph, SEAMS_GRAPH_SEEDED), opt_int(k, 4_seams_int), opt_flag(complete, .false.), out)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    call handle_acquire(cages%box, out, kind_cages)
    cages%natoms = int(seams_system_count(raw), seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_cages

  module procedure frame_signature
    type(c_ptr) :: raw
    character(kind=c_char), allocatable, target :: text(:)
    integer(c_size_t) :: cages_n, atoms_n
    integer(c_int) :: code
    n_cages = 0_seams_int
    n_atoms = 0_seams_int
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    text = f_to_c(spec)
    code = seams_signature_cages(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
      opt_int(graph, SEAMS_GRAPH_CUTOFF), text, cages_n, atoms_n)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    n_cages = int(cages_n, seams_int)
    n_atoms = int(atoms_n, seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_signature

  module procedure frame_rdf
    type(c_ptr) :: raw, count_ptr, volume_ptr
    integer(c_size_t) :: n, cap
    integer(c_int) :: code
    real(seams_real), allocatable, target :: rbuf(:), gbuf(:)
    integer(seams_int), allocatable, target :: cbuf(:)
    real(seams_real), target :: volume_b
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    code = seams_rdf(raw, opt_real(rmax, 6.0_seams_real), opt_int(bins, 0_seams_int), &
      opt_int(type_i, 0_seams_int), opt_int(type_j, 0_seams_int), c_null_ptr, c_null_ptr, &
      c_null_ptr, 0_c_size_t, n, c_null_ptr)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    allocate(rbuf(n), gbuf(n))
    count_ptr = c_null_ptr
    if (present(count)) then
      allocate(cbuf(n))
      count_ptr = c_loc(cbuf)
    end if
    volume_ptr = c_null_ptr
    if (present(volume)) volume_ptr = c_loc(volume_b)
    cap = n
    code = seams_rdf(raw, opt_real(rmax, 6.0_seams_real), opt_int(bins, 0_seams_int), &
      opt_int(type_i, 0_seams_int), opt_int(type_j, 0_seams_int), c_loc(rbuf), c_loc(gbuf), &
      count_ptr, cap, n, volume_ptr)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    r = rbuf
    g = gbuf
    if (present(count)) count = cbuf
    if (present(volume)) volume = volume_b
    call check_status(code, raw, stat, errmsg)
  end procedure frame_rdf

  module procedure frame_running_cn
    type(c_ptr) :: raw
    integer(c_size_t) :: n, cap
    integer(c_int) :: code
    real(seams_real), allocatable, target :: rbuf(:), cbuf(:)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    code = seams_running_cn(raw, opt_real(rmax, 6.0_seams_real), opt_int(bins, 0_seams_int), &
      opt_int(type_i, 0_seams_int), opt_int(type_j, 0_seams_int), c_null_ptr, c_null_ptr, &
      0_c_size_t, n)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    allocate(rbuf(n), cbuf(n))
    cap = n
    code = seams_running_cn(raw, opt_real(rmax, 6.0_seams_real), opt_int(bins, 0_seams_int), &
      opt_int(type_i, 0_seams_int), opt_int(type_j, 0_seams_int), c_loc(rbuf), c_loc(cbuf), cap, n)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    r = rbuf
    cn = cbuf
    call check_status(code, raw, stat, errmsg)
  end procedure frame_running_cn

  module procedure frame_coordination
    type(c_ptr) :: raw
    integer(c_int) :: code
    real(c_double), target :: value
    cn = 0.0_seams_real
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    code = seams_coordination(raw, opt_real(rmax, 3.5_seams_real), opt_int(bins, 0_seams_int), &
      opt_int(type_i, 0_seams_int), opt_int(type_j, 0_seams_int), value)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    cn = value
    call check_status(code, raw, stat, errmsg)
  end procedure frame_coordination

  module procedure frame_hbonds
    type(c_ptr) :: raw
    integer(c_int) :: code, bonds
    n_bonds = 0_seams_int
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    code = seams_hbonds(raw, opt_real(cutoff, 3.5_seams_real), opt_int(oxygen_type, 1_seams_int), &
      opt_int(hydrogen_type, 2_seams_int), opt_real(dist, 2.42_seams_real), &
      opt_real(angle, 30.0_seams_real), bonds)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    n_bonds = int(bonds, seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_hbonds

  module procedure frame_density
    type(c_ptr) :: raw
    integer(c_size_t) :: n, cap
    integer(c_int) :: code
    real(seams_real), allocatable, target :: zbuf(:), rbuf(:)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    code = seams_density_axis(raw, opt_int(typ, 0_seams_int), opt_int(bins, 0_seams_int), &
      opt_int(axis, 2_seams_int), c_null_ptr, c_null_ptr, 0_c_size_t, n)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    allocate(zbuf(n), rbuf(n))
    cap = n
    code = seams_density_axis(raw, opt_int(typ, 0_seams_int), opt_int(bins, 0_seams_int), &
      opt_int(axis, 2_seams_int), c_loc(zbuf), c_loc(rbuf), cap, n)
    if (code /= SEAMS_OK) then
      deallocate(zbuf, rbuf)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    z = zbuf
    rho = rbuf
    deallocate(zbuf, rbuf)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_density

  module procedure frame_fingerprint
    type(c_ptr) :: raw, out
    integer(c_int) :: code, color_flag
    logical :: colored
    if (present(colors) .and. present(colours)) then
      if (colors .neqv. colours) then
        call check_status(int(SEAMS_ERR_ARG, c_int), c_null_ptr, stat, errmsg, &
          "colors and colours disagree")
        return
      end if
    end if
    colored = .false.
    if (present(colors)) colored = colors
    if (present(colours)) colored = colours
    color_flag = merge(1_c_int, 0_c_int, colored)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    code = seams_fingerprint(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
      opt_int(k, 4_seams_int), opt_int(graph, SEAMS_GRAPH_CUTOFF), opt_int(hops, 2_seams_int), &
      color_flag, out)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    call handle_acquire(fp%box, out, kind_topo)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_fingerprint

  module procedure frame_contact_pairs
    type(c_ptr) :: raw
    character(kind=c_char), allocatable, target :: text(:)
    integer(c_size_t) :: pairs
    integer(c_int) :: code, cations, anions
    n_pairs = 0_seams_int
    n_cation = 0_seams_int
    n_anion = 0_seams_int
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    text = f_to_c(spec)
    code = seams_contact_pairs(raw, text, pairs, cations, anions)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    n_pairs = int(pairs, seams_int)
    n_cation = int(cations, seams_int)
    n_anion = int(anions, seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_contact_pairs

  module procedure frame_domains
    type(c_ptr) :: raw
    character(kind=c_char), allocatable, target :: text(:)
    integer(c_int) :: code, subset_n, largest_n
    real(c_double), target :: perc
    n_subset = 0_seams_int
    largest = 0_seams_int
    percolation = 0.0_seams_real
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    text = f_to_c(spec)
    code = seams_domains(raw, opt_real(cutoff, 3.5_seams_real), text, opt_flag(polar, .false.), &
      subset_n, largest_n, perc)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    n_subset = int(subset_n, seams_int)
    largest = int(largest_n, seams_int)
    percolation = perc
    call check_status(code, raw, stat, errmsg)
  end procedure frame_domains

  module procedure frame_prisms
    type(c_ptr) :: raw
    integer(c_int) :: code
    integer(seams_int), allocatable, target :: perfect_b(:), imperfect_b(:)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    allocate(perfect_b(0:6), imperfect_b(0:6))
    code = seams_prisms(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
      perfect_b, imperfect_b, 7_c_size_t)
    if (code /= SEAMS_OK) then
      deallocate(perfect_b, imperfect_b)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    perfect = perfect_b
    imperfect = imperfect_b
    deallocate(perfect_b, imperfect_b)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_prisms

  module procedure frame_monolayer
    type(c_ptr) :: raw
    integer(c_int) :: code, depth
    integer(seams_int), allocatable, target :: buf(:)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    depth = opt_int(max_depth, 6_seams_int)
    allocate(buf(0:depth))
    buf = 0_seams_int
    code = seams_monolayer(raw, opt_real(cutoff, 3.5_seams_real), opt_int(typ, 0_seams_int), &
      depth, sheet_area, buf, int(size(buf), c_size_t))
    if (code /= SEAMS_OK) then
      deallocate(buf)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    counts = buf
    deallocate(buf)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_monolayer

  module procedure frame_site_kinds
    type(c_ptr) :: raw
    character(kind=c_char), allocatable, target :: text(:)
    integer(c_int) :: code, n
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    n = seams_system_count(raw)
    allocate(kinds(n))
    text = f_to_c(spec)
    code = seams_site_table(raw, text, kinds, int(n, c_size_t))
    if (code /= SEAMS_OK) then
      deallocate(kinds)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    call check_status(code, raw, stat, errmsg)
  end procedure frame_site_kinds

  module procedure frame_symmetry
    type(c_ptr) :: raw
    integer(c_int) :: code, n
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    n = seams_system_count(raw)
    allocate(labels(n))
    code = seams_system_symmetry(raw, opt_real(shell_rmsd, 0.0_seams_real), labels, int(n, c_size_t))
    if (code /= SEAMS_OK) then
      deallocate(labels)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    call check_status(code, raw, stat, errmsg)
  end procedure frame_symmetry

  module procedure frame_brine
    type(c_ptr) :: raw, out
    integer(c_int) :: code
    integer(c_int), allocatable, target :: flags(:)
    raw = open_raw(self%box, stat, errmsg, "frame")
    if (.not. c_associated(raw)) return
    if (size(ice) /= seams_system_count(raw)) then
      call check_status(int(SEAMS_ERR_ARG, c_int), raw, stat, errmsg, "ice length is not the atom count")
      return
    end if
    flags = int(ice, c_int)
    code = seams_brine_analyse(raw, flags, int(size(flags), c_size_t), opt_int(water_type, 0_seams_int), &
      opt_int(ion_type, 0_seams_int), opt_int(n_bins, 0_seams_int), opt_int(axis, 2_seams_int), out)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    call handle_acquire(front%box, out, kind_brine)
    call check_status(code, raw, stat, errmsg)
  end procedure frame_brine

  module procedure neighbour_count
    type(c_ptr) :: raw
    raw = handle_get(self%box)
    if (.not. c_associated(raw)) then
      n = 0_seams_int
    else
      n = int(seams_neighbours_count(raw), seams_int)
    end if
  end procedure neighbour_count

  subroutine neighbour_column(self, which, values, stat, errmsg)
    class(seams_neighbours), intent(in) :: self
    integer, intent(in) :: which
    integer(seams_int), allocatable, intent(out) :: values(:)
    integer(seams_int), intent(out), optional :: stat
    character(len=:), allocatable, intent(out), optional :: errmsg
    type(c_ptr) :: raw, off_ptr, col_ptr
    integer(c_size_t) :: n_off, nnz, off_cap, col_cap
    integer(c_int) :: code
    integer(c_int), allocatable, target :: off_buf(:), col_buf(:)
    integer :: i
    raw = open_raw(self%box, stat, errmsg, "neighbours")
    if (.not. c_associated(raw)) return
    code = seams_neighbours_copy(raw, c_null_ptr, 0_c_size_t, n_off, c_null_ptr, 0_c_size_t, nnz)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    off_ptr = c_null_ptr
    col_ptr = c_null_ptr
    if (which == 0) then
      allocate(off_buf(n_off))
      off_ptr = c_loc(off_buf)
    else
      allocate(col_buf(nnz))
      col_ptr = c_loc(col_buf)
    end if
    off_cap = n_off
    col_cap = nnz
    code = seams_neighbours_copy(raw, off_ptr, off_cap, n_off, col_ptr, col_cap, nnz)
    if (code /= SEAMS_OK) then
      if (allocated(off_buf)) deallocate(off_buf)
      if (allocated(col_buf)) deallocate(col_buf)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    ! int() on the whole array builds a temporary that LeakSanitizer
    ! still sees after the assignment. Copy one element at a time.
    if (which == 0) then
      allocate(values(size(off_buf)))
      do i = 1, size(off_buf)
        values(i) = int(off_buf(i), seams_int)
      end do
    else
      allocate(values(size(col_buf)))
      do i = 1, size(col_buf)
        values(i) = int(col_buf(i), seams_int)
      end do
    end if
    if (allocated(off_buf)) deallocate(off_buf)
    if (allocated(col_buf)) deallocate(col_buf)
    call check_status(code, raw, stat, errmsg)
  end subroutine neighbour_column

  module procedure neighbour_offsets
    call neighbour_column(self, 0, offsets, stat, errmsg)
  end procedure neighbour_offsets
  module procedure neighbour_columns
    call neighbour_column(self, 1, columns, stat, errmsg)
  end procedure neighbour_columns

  module procedure ring_count
    type(c_ptr) :: raw
    raw = handle_get(self%box)
    if (.not. c_associated(raw)) then
      n = 0_seams_int
    else
      n = int(seams_rings_count(raw), seams_int)
    end if
  end procedure ring_count
  module procedure ring_histogram
    type(c_ptr) :: raw
    integer(c_int) :: code
    integer(seams_int), allocatable, target :: buf(:)
    raw = open_raw(self%box, stat, errmsg, "rings")
    if (.not. c_associated(raw)) return
    allocate(buf(0:self%max_depth))
    buf = 0_seams_int
    code = seams_rings_histogram(raw, buf, int(size(buf), c_int))
    if (code /= SEAMS_OK) then
      deallocate(buf)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    counts = buf
    deallocate(buf)
    call check_status(code, raw, stat, errmsg)
  end procedure ring_histogram
  module procedure ring_fraction
    type(c_ptr) :: raw
    integer(c_int) :: code
    real(c_double), target :: value
    fraction = 0.0_seams_real
    raw = open_raw(self%box, stat, errmsg, "rings")
    if (.not. c_associated(raw)) return
    code = seams_rings_fraction(raw, int(size, c_int), value)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    fraction = value
    call check_status(code, raw, stat, errmsg)
  end procedure ring_fraction
  subroutine ring_one(self, which, values, stat, errmsg)
    class(seams_rings), intent(in) :: self
    integer, intent(in) :: which
    integer(seams_int), allocatable, intent(out) :: values(:)
    integer(seams_int), intent(out), optional :: stat
    character(len=:), allocatable, intent(out), optional :: errmsg
    type(c_ptr) :: raw, size_ptr, sym_ptr
    integer(c_int) :: code, n
    integer(c_int), allocatable, target :: size_buf(:), sym_buf(:)
    raw = open_raw(self%box, stat, errmsg, "rings")
    if (.not. c_associated(raw)) return
    n = seams_rings_count(raw)
    size_ptr = c_null_ptr
    sym_ptr = c_null_ptr
    if (which == 0) then
      allocate(size_buf(n))
      size_ptr = c_loc(size_buf)
    else
      allocate(sym_buf(n))
      sym_ptr = c_loc(sym_buf)
    end if
    code = seams_rings_labels(raw, size_ptr, sym_ptr)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    if (which == 0) then
      values = int(size_buf, seams_int)
    else
      values = int(sym_buf, seams_int)
    end if
    call check_status(code, raw, stat, errmsg)
  end subroutine ring_one
  module procedure ring_sizes
    call ring_one(self, 0, sizes, stat, errmsg)
  end procedure ring_sizes
  module procedure ring_symmetry
    call ring_one(self, 1, codes, stat, errmsg)
  end procedure ring_symmetry
  module procedure ring_vertices
    type(c_ptr) :: raw
    integer(c_int) :: code
    integer(c_size_t) :: n
    integer(c_int), allocatable, target :: buf(:)
    raw = open_raw(self%box, stat, errmsg, "rings")
    if (.not. c_associated(raw)) return
    allocate(buf(12))
    code = seams_rings_vertices(raw, int(index - 1, c_int), buf, 12_c_size_t, n)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    atoms = int(buf(1:int(n)), seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure ring_vertices

  module procedure cage_counts
    type(c_ptr) :: raw
    integer(c_int) :: code, hex, cubic, water, both
    n_hex = 0_seams_int
    n_cubic = 0_seams_int
    n_water = 0_seams_int
    n_both = 0_seams_int
    raw = open_raw(self%box, stat, errmsg, "cages")
    if (.not. c_associated(raw)) return
    code = seams_cages_counts(raw, hex, cubic, water, both)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    n_hex = int(hex, seams_int)
    n_cubic = int(cubic, seams_int)
    n_water = int(water, seams_int)
    n_both = int(both, seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure cage_counts
  module procedure cage_labels
    type(c_ptr) :: raw
    integer(c_int) :: code
    raw = open_raw(self%box, stat, errmsg, "cages")
    if (.not. c_associated(raw)) return
    allocate(labels(self%natoms))
    code = seams_cages_labels(raw, labels, int(self%natoms, c_size_t))
    if (code /= SEAMS_OK) then
      deallocate(labels)
      call check_status(code, raw, stat, errmsg)
      return
    end if
    call check_status(code, raw, stat, errmsg)
  end procedure cage_labels

  module procedure topo_key
    type(c_ptr) :: raw
    raw = open_raw(self%box, stat, errmsg, "fingerprint")
    if (.not. c_associated(raw)) return
    call take_key(raw, -1_c_int, key, stat, errmsg)
  end procedure topo_key
  module procedure topo_atom_key
    type(c_ptr) :: raw
    raw = open_raw(self%box, stat, errmsg, "fingerprint")
    if (.not. c_associated(raw)) return
    call take_key(raw, int(index - 1, c_int), key, stat, errmsg)
  end procedure topo_atom_key
  module procedure topo_rings
    type(c_ptr) :: raw
    integer(c_int) :: code
    integer(seams_int), allocatable, target :: buf(:)
    raw = open_raw(self%box, stat, errmsg, "fingerprint")
    if (.not. c_associated(raw)) return
    allocate(buf(0:12))
    buf = 0_seams_int
    code = seams_fingerprint_rings(raw, buf, int(size(buf), c_size_t))
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    counts = buf
    call check_status(code, raw, stat, errmsg)
  end procedure topo_rings

  module procedure brine_fronts
    type(c_ptr) :: raw, enter_ptr, exit_ptr, thick_ptr, found_ptr
    integer(c_int) :: code
    real(c_double), target :: enter_b, exit_b, thick_b
    integer(c_int), target :: found_b
    raw = open_raw(self%box, stat, errmsg, "brine")
    if (.not. c_associated(raw)) return
    if (.not. (present(z_enter) .or. present(z_exit) .or. present(thickness) .or. present(found))) then
      call check_status(int(SEAMS_ERR_ARG, c_int), raw, stat, errmsg, "fronts needs one output")
      return
    end if
    enter_ptr = c_null_ptr
    exit_ptr = c_null_ptr
    thick_ptr = c_null_ptr
    found_ptr = c_null_ptr
    if (present(z_enter)) enter_ptr = c_loc(enter_b)
    if (present(z_exit)) exit_ptr = c_loc(exit_b)
    if (present(thickness)) thick_ptr = c_loc(thick_b)
    if (present(found)) found_ptr = c_loc(found_b)
    code = seams_brine_fronts(raw, enter_ptr, exit_ptr, thick_ptr, found_ptr)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    if (present(z_enter)) z_enter = enter_b
    if (present(z_exit)) z_exit = exit_b
    if (present(thickness)) thickness = thick_b
    if (present(found)) found = int(found_b, seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure brine_fronts
  module procedure brine_rejection
    type(c_ptr) :: raw, ice_ptr, liquid_ptr, k_ptr, defined_ptr
    integer(c_int) :: code
    real(c_double), target :: ice_b, liquid_b, k_b
    integer(c_int), target :: defined_b
    raw = open_raw(self%box, stat, errmsg, "brine")
    if (.not. c_associated(raw)) return
    if (.not. (present(c_ice) .or. present(c_liquid) .or. present(k) .or. present(defined))) then
      call check_status(int(SEAMS_ERR_ARG, c_int), raw, stat, errmsg, "rejection needs one output")
      return
    end if
    ice_ptr = c_null_ptr
    liquid_ptr = c_null_ptr
    k_ptr = c_null_ptr
    defined_ptr = c_null_ptr
    if (present(c_ice)) ice_ptr = c_loc(ice_b)
    if (present(c_liquid)) liquid_ptr = c_loc(liquid_b)
    if (present(k)) k_ptr = c_loc(k_b)
    if (present(defined)) defined_ptr = c_loc(defined_b)
    code = seams_brine_rejection(raw, ice_ptr, liquid_ptr, k_ptr, defined_ptr)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    if (present(c_ice)) c_ice = ice_b
    if (present(c_liquid)) c_liquid = liquid_b
    if (present(k)) k = k_b
    if (present(defined)) defined = int(defined_b, seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure brine_rejection
  module procedure brine_profile
    type(c_ptr) :: raw
    integer(c_size_t) :: n, cap
    integer(c_int) :: code
    real(seams_real), allocatable, target :: zbuf(:), mbuf(:), fbuf(:)
    raw = open_raw(self%box, stat, errmsg, "brine")
    if (.not. c_associated(raw)) return
    code = seams_brine_profile(raw, c_null_ptr, c_null_ptr, c_null_ptr, 0_c_size_t, n)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    allocate(zbuf(n), mbuf(n), fbuf(n))
    cap = n
    code = seams_brine_profile(raw, c_loc(zbuf), c_loc(mbuf), c_loc(fbuf), cap, n)
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    z_mid = zbuf
    molality = mbuf
    ice_fraction = fbuf
    call check_status(code, raw, stat, errmsg)
  end procedure brine_profile
  module procedure brine_pockets
    type(c_ptr) :: raw
    integer(c_int), target :: code, pockets, waters
    n_pockets = 0_seams_int
    reservoir_waters = 0_seams_int
    raw = open_raw(self%box, stat, errmsg, "brine")
    if (.not. c_associated(raw)) return
    code = seams_brine_pockets(raw, c_loc(pockets), c_loc(waters))
    if (code /= SEAMS_OK) then
      call check_status(code, raw, stat, errmsg)
      return
    end if
    n_pockets = int(pockets, seams_int)
    reservoir_waters = int(waters, seams_int)
    call check_status(code, raw, stat, errmsg)
  end procedure brine_pockets

  subroutine ensure_readers_probed()
    if (dseams_once_state() == 2_c_int) return
    if (dseams_once_enter() /= 0_c_int) then
      call probe_readers(chem_cached, con_cached)
      call dseams_once_done()
    end if
  end subroutine ensure_readers_probed

  module procedure has_chemfiles
    call ensure_readers_probed()
    yes = chem_cached
  end procedure has_chemfiles

  module procedure has_readcon
    call ensure_readers_probed()
    yes = con_cached
  end procedure has_readcon

  ! Runs at most once per process, from one thread, probing chemfiles
  ! and readcon sequentially so two frame%read calls never run at once.
  subroutine probe_readers(chem_ok, con_ok)
    logical, intent(out) :: chem_ok, con_ok
    character(len=:), allocatable :: base_dir, priv_dir, pdb_path, con_path
    logical :: wrote
    chem_ok = .false.
    con_ok = .false.
    call temp_directory(base_dir)
    if (len(base_dir) == 0) then
      call warn_probe_directory()
      return
    end if
    call create_probe_dir(base_dir, priv_dir)
    if (len(priv_dir) == 0) then
      call warn_probe_directory()
      return
    end if
    call join_dir(priv_dir, "probe.pdb", pdb_path)
    call write_probe_pdb(pdb_path, wrote)
    if (wrote) then
      call write_stamp(base_dir, pdb_path)
      chem_ok = reader_accepts(pdb_path)
      call dseams_probe_unlink(f_to_c(pdb_path))
    end if
    call join_dir(priv_dir, "probe.con", con_path)
    call write_probe_con(con_path, wrote)
    if (wrote) then
      call write_stamp(base_dir, con_path)
      con_ok = reader_accepts(con_path)
      call dseams_probe_unlink(f_to_c(con_path))
    end if
    call dseams_probe_rmdir(f_to_c(priv_dir))
  end subroutine probe_readers

  module procedure probe_directory
    call temp_directory(dir)
  end procedure probe_directory

  ! First directory that can take a file. A set but missing or
  ! unwritable TMPDIR falls through to TEMP, then TMP, then the
  ! working directory. Empty means every candidate failed. This never
  ! assumes a Unix temp path and never calls getpid.
  !
  ! This, and every other character(len=:), allocatable helper below
  ! it (usable_env, normalize_dir, join_dir, env_string, probe_path),
  ! is a SUBROUTINE with an allocatable intent(out) argument, not a
  ! FUNCTION with an allocatable result, on purpose: see
  ! docs/orgmode/contributing/developer/faq.org and logs/f3/ for the
  ! reproducer. gfortran 13.3.0 (this project's own CI compiler)
  ! reliably corrupts a character(len=:), allocatable FUNCTION result
  ! returned to a caller running concurrently with any other call,
  ! anywhere in the process, that also returns such a result; up to
  ! and including glibc's allocator itself aborting with "free():
  ! invalid next size". The identical computation expressed as a
  ! SUBROUTINE with an allocatable intent(out) argument, called the
  ! same way under the same load, is not affected; neither is a
  ! deferred-length allocatable CHARACTER ARRAY function result (see
  ! f_to_c in seams_support.f90, left as a function since it does not
  ! have this problem). This is not a defect in this package's logic:
  ! the reproducer needs no SAVE variable, no missing "recursive", and
  ! no shared state of any kind, only two ordinary calls to two
  ! ordinary character(len=:), allocatable functions running on
  ! different threads at the same moment.
  subroutine temp_directory(dir)
    character(len=:), allocatable, intent(out) :: dir
    call usable_env("TMPDIR", dir)
    if (len(dir) > 0) return
    call usable_env("TEMP", dir)
    if (len(dir) > 0) return
    call usable_env("TMP", dir)
    if (len(dir) > 0) return
    if (can_write(".")) then
      dir = "."
      return
    end if
    dir = ""
  end subroutine temp_directory

  subroutine usable_env(name, dir)
    character(len=*), intent(in) :: name
    character(len=:), allocatable, intent(out) :: dir
    character(len=:), allocatable :: raw
    call env_string(name, raw)
    call normalize_dir(raw, dir)
    if (len(dir) == 0) return
    if (.not. can_write(dir)) dir = ""
  end subroutine usable_env

  subroutine normalize_dir(raw, dir)
    character(len=*), intent(in) :: raw
    character(len=:), allocatable, intent(out) :: dir
    dir = trim(raw)
    do while (len(dir) > 1)
      if (dir(len(dir):len(dir)) /= "/" .and. dir(len(dir):len(dir)) /= "\") exit
      dir = dir(1:len(dir) - 1)
    end do
  end subroutine normalize_dir

  ! True when a new file can be created exclusively in dir and then removed.
  ! Uses dseams_probe_write (O_CREAT|O_EXCL|O_NOFOLLOW) so symlinks are
  ! never followed or truncated.
  function can_write(dir) result(yes)
    character(len=*), intent(in) :: dir
    logical :: yes
    character(len=:), allocatable :: path
    character(len=48) :: token
    character(kind=c_char) :: empty(1)
    integer(int64) :: ticks
    integer :: attempt
    integer(c_int) :: rc
    yes = .false.
    if (len_trim(dir) == 0) return
    empty(1) = c_null_char
    do attempt = 1, 64
      call system_clock(ticks)
      write(token, "(i0,'-',i0)") ticks, attempt
      call join_dir(trim(dir), "dseams-probe-try-" // trim(token), path)
      rc = dseams_probe_write(f_to_c(path), empty, 0_c_size_t)
      if (rc == 0_c_int) then
        call dseams_probe_unlink(f_to_c(path))
        yes = .true.
        return
      end if
      if (rc < 0_c_int) return
    end do
  end function can_write

  subroutine env_string(name, value)
    character(len=*), intent(in) :: name
    character(len=:), allocatable, intent(out) :: value
    integer :: length, stat
    call get_environment_variable(name, length=length, status=stat)
    if (stat /= 0 .or. length <= 0) then
      value = ""
      return
    end if
    allocate(character(len=length) :: value)
    call get_environment_variable(name, value)
  end subroutine env_string

  subroutine join_dir(dir, name, path)
    character(len=*), intent(in) :: dir, name
    character(len=:), allocatable, intent(out) :: path
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
  end subroutine join_dir

  ! Create a private 0700 subdirectory inside dir using mkdir.
  subroutine create_probe_dir(dir, priv_dir)
    character(len=*), intent(in) :: dir
    character(len=:), allocatable, intent(out) :: priv_dir
    character(len=48) :: token
    integer(int64) :: ticks
    integer :: attempt
    integer(c_int) :: rc
    priv_dir = ""
    do attempt = 1, 100
      call system_clock(ticks)
      write(token, "(i0,'-',i0)") ticks, attempt
      call join_dir(dir, "dseams-probe-" // trim(token), priv_dir)
      rc = dseams_probe_mkdir(f_to_c(priv_dir))
      if (rc == 0_c_int) return
      if (rc < 0_c_int) then
        priv_dir = ""
        return
      end if
    end do
    priv_dir = ""
  end subroutine create_probe_dir

  ! Called at most once per process inside the shared once-guard.
  subroutine warn_probe_directory()
    write(error_unit, "(a)") "dseams: no writable directory for the reader probe " // &
      "(tried TMPDIR, TEMP, TMP and the working directory)"
    flush(error_unit)
  end subroutine warn_probe_directory

  ! Left in base_dir only when DSEAMS_PROBE_STAMP is set to a non-zero
  ! value, so a test can see which directory was used. "1" selects the
  ! default name "dseams-probe-stamp"; any other value names the stamp
  ! file directly so parallel test variants do not share one path.
  subroutine write_stamp(base_dir, probe)
    character(len=*), intent(in) :: base_dir, probe
    character(len=:), allocatable :: flag, stamp, stamp_name
    character(kind=c_char), allocatable :: buf(:)
    integer :: i, n
    integer(c_int) :: rc
    call env_string("DSEAMS_PROBE_STAMP", flag)
    if (len_trim(flag) == 0) return
    if (trim(flag) == "0") return
    if (trim(flag) == "1") then
      stamp_name = "dseams-probe-stamp"
    else
      stamp_name = trim(flag)
    end if
    call join_dir(base_dir, stamp_name, stamp)
    n = len_trim(probe) + 1
    allocate(buf(n))
    do i = 1, n - 1
      buf(i) = probe(i:i)
    end do
    buf(n) = new_line("a")
    rc = dseams_probe_write_stamp(f_to_c(stamp), buf, int(n, c_size_t))
    deallocate(buf)
  end subroutine write_stamp

  ! True only when the engine both accepts the file and keeps at least
  ! one atom. A missing reader returns an error and zero atoms; a probe
  ! that failed to parse must not be reported as support.
  function reader_accepts(path) result(yes)
    character(len=*), intent(in) :: path
    logical :: yes
    type(seams_frame) :: frame
    integer(seams_int) :: stat
    character(len=:), allocatable :: err
    yes = .false.
    frame = new_frame(stat, err)
    if (stat /= SEAMS_OK) return
    call frame%read(path, stat=stat, errmsg=err)
    if (stat /= SEAMS_OK) return
    yes = frame%count() > 0_seams_int
  end function reader_accepts

  subroutine write_probe_pdb(path, ok)
    character(len=*), intent(in) :: path
    logical, intent(out) :: ok
    character(len=80) :: lines(4)
    lines(1) = "HEADER    ONE OXYGEN"
    lines(2) = "CRYST1    1.000    1.000    1.000  90.00  90.00  90.00 P 1           1"
    lines(3) = "ATOM      1  OW  SOL A   1       0.000   0.000   0.000  1.00  0.00           O"
    lines(4) = "END"
    call write_probe_lines(path, lines, ok)
  end subroutine write_probe_pdb

  ! First frame of input/eon/tiny_multi_cuh2.con. The box rows use the
  ! tab separators that file uses. Four atoms, which is also the count
  ! the readers test expects from the fixture.
  subroutine write_probe_con(path, ok)
    character(len=*), intent(in) :: path
    logical, intent(out) :: ok
    character(len=1) :: tab
    character(len=80) :: box_a, box_b
    character(len=80) :: lines(17)
    tab = achar(9)
    box_a = "15.345600" // tab // "21.702000" // tab // "100.000000"
    box_b = "90.000000" // tab // "90.000000" // tab // "90.000000"
    lines(1) = "Random Number Seed"
    lines(2) = '{"con_spec_version":2}'
    lines(3) = box_a
    lines(4) = box_b
    lines(5) = "0 0"
    lines(6) = "218 0 1"
    lines(7) = "2"
    lines(8) = "2 2"
    lines(9) = "63.546000 1.007930"
    lines(10) = "Cu"
    lines(11) = "Coordinates of Component 1"
    lines(12) = "   0.6394    0.9045    6.9753 1    0"
    lines(13) = "   3.1969    0.9045    6.9753 1    1"
    lines(14) = "H"
    lines(15) = "Coordinates of Component 2"
    lines(16) = "   8.6823    9.947   11.733 0  2"
    lines(17) = "   7.9421    9.947   11.733 0  3"
    call write_probe_lines(path, lines, ok)
  end subroutine write_probe_con

  subroutine write_probe_lines(path, lines, ok)
    character(len=*), intent(in) :: path
    character(len=*), intent(in) :: lines(:)
    logical, intent(out) :: ok
    character(kind=c_char), allocatable :: buf(:)
    character(len=1) :: lf
    integer :: i, j, pos, nline, total
    integer(c_int) :: rc
    ok = .false.
    lf = new_line("a")
    total = 0
    do i = 1, size(lines)
      total = total + len_trim(lines(i)) + 1
    end do
    if (total <= 0) return
    allocate(buf(total))
    pos = 1
    do i = 1, size(lines)
      nline = len_trim(lines(i))
      do j = 1, nline
        buf(pos) = lines(i)(j:j)
        pos = pos + 1
      end do
      buf(pos) = lf
      pos = pos + 1
    end do
    rc = dseams_probe_write(f_to_c(path), buf, int(total, c_size_t))
    deallocate(buf)
    ok = (rc == 0_c_int)
  end subroutine write_probe_lines
end submodule seams_methods
