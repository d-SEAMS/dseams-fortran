# Copyright (c) d-SEAMS developers
# SPDX-License-Identifier: MIT
#
# Meson build of the Fortran modules, for projects that pull this
# repository in as a subproject. fpm.toml is the other build. Both link
# an installed libseams from seams-core tag v2.14.1, found through pkg-config
# (seams.pc) or, failing that, on the linker search path and in the
# directories named by -Dseams_libdir.
project(
  'dseams-fortran',
  'fortran', 'c',
  # [[[cog import tomllib; from pathlib import Path; v = tomllib.load(Path("fpm.toml").open("rb"))["version"]; cog.outl(f"  version: '{v}',")]]]
  version: '2.14.1',
  # [[[end]]]
  license: 'MIT',
  meson_version: '>=1.1.0',
  default_options: ['warning_level=1'],
)

# The Fortran sources only link libseams. C include paths in seams.pc are
# dropped, and so are any SEAMS_HAS_* macros. Nothing in this package
# reads them. has_chemfiles and has_readcon ask the loaded library.
# This package does not link chemfiles or readcon-core and does not
# compile a reader.
seams_pc = dependency('seams', version: '>=2.14.1', required: false)
if seams_pc.found()
  seams_dep = seams_pc.partial_dependency(links: true, link_args: true)
else
  seams_dep = meson.get_compiler('fortran').find_library(
    'seams',
    dirs: get_option('seams_libdir'),
  )
endif

fortran_lib_src = files(
  'src/seams_kinds.f90',
  'src/seams_c.f90',
  'src/seams_support.f90',
  'src/seams.f90',
  'src/seams_methods.f90',
)

# has_chemfiles and has_readcon each run their probe behind an
# in-process once-guard, a C11 stdatomic.h compare-and-swap with no
# lock file and no OS mutex, not a pthread_once: the library itself
# links no pthread symbol. Only the thread_safety test, which spawns
# real pthreads to exercise the guard, needs dependency('threads').
# This is its own static_library, not a source file of dseams_lib
# directly, so the one-file build below (which compiles seams.f90
# through a separate custom_target, not dseams_lib) can link it too.
once_guard_lib = static_library(
  'dseams_once',
  files('src/dseams_once.c'),
  pic: true,
)

dseams_lib = static_library(
  'dseams_fortran',
  fortran_lib_src,
  link_with: once_guard_lib,
  dependencies: [seams_dep],
  pic: true,
)
dseams_fortran_dep = declare_dependency(
  link_with: [dseams_lib, once_guard_lib],
  include_directories: dseams_lib.private_dir_include(),
  dependencies: [seams_dep],
)
meson.override_dependency('dseams-fortran', dseams_fortran_dep)

if not meson.is_subproject()
  root = meson.project_source_root()
  fortran_env = environment()
  fortran_env.set('OMP_NUM_THREADS', '1')
  fortran_env.set('DSEAMS_ROOT', root)

  capi = executable(
    'test_fortran_capi',
    files('test/test_capi.f90', 'src/seams_c.f90'),
    dependencies: seams_dep,
  )
  test('fortran_capi', capi, args: [root], env: fortran_env, timeout: 180)

  # link_language: 'fortran' on every executable below that links
  # dseams_fortran_dep (or once_guard_lib directly, for one_file further
  # down): once a C object (once_guard_lib) is anywhere in an
  # executable's link, meson's default link-language choice can pick
  # the C driver instead of the Fortran one for the final link, which
  # drops the Fortran runtime. gfortran's C and Fortran drivers both
  # pull in libgfortran regardless, so this only shows up as a link
  # failure (missing _FortranAio*/_FortranA* symbols) with flang-new.
  check = executable(
    'test_fortran_check',
    files('test/check_dseams.f90'),
    dependencies: dseams_fortran_dep,
    link_language: 'fortran',
  )
  test('fortran_check', check, env: fortran_env, timeout: 180)

  high = executable(
    'test_fortran_high',
    files('test/test_high.f90'),
    dependencies: dseams_fortran_dep,
    link_language: 'fortran',
  )
  test('fortran_high', high, args: [root], env: fortran_env, timeout: 180)

  readers = executable(
    'test_fortran_readers',
    files('test/test_readers.f90'),
    dependencies: dseams_fortran_dep,
    link_language: 'fortran',
  )
  test('fortran_readers', readers, args: [root], env: fortran_env, timeout: 180)

  feature_query = executable(
    'test_fortran_feature_query',
    files('test/test_feature_query.f90'),
    dependencies: dseams_fortran_dep,
    link_language: 'fortran',
  )
  test('fortran_feature_query', feature_query, env: fortran_env, timeout: 180)

  thread_safety = executable(
    'test_fortran_thread_safety',
    files('test/test_thread_safety.f90'),
    dependencies: [dseams_fortran_dep, dependency('threads')],
    link_language: 'fortran',
  )
  test('fortran_thread_safety', thread_safety, env: fortran_env, timeout: 180)

  no_lock_symlink = executable(
    'test_fortran_no_lock_symlink',
    files('test/test_no_lock_symlink.f90'),
    dependencies: dseams_fortran_dep,
    link_language: 'fortran',
  )
  # Meson's test harness hardcodes exit code 77 as the GNU/automake
  # skip convention (mesonbuild/mtest.py: GNU_SKIP_RETURNCODE); there
  # is no per-test kwarg to set, since it is not configurable. Outside
  # CI, a missing precondition (no writable probe directory, no
  # ln(1)) exits 77 there and is reported SKIP, never "ok".
  test('fortran_no_lock_symlink', no_lock_symlink, env: fortran_env, timeout: 180)

  # The probe uses the first writable directory among TMPDIR, TEMP, TMP
  # and the working directory. A bogus TMPDIR falls through, so a capable
  # build still reports true. With all three unset, the file is in the cwd.
  reader_tmp = meson.project_build_root() / 'reader-tmp'
  run_command('mkdir', '-p', reader_tmp, check: true)
  tmpdir_env = environment()
  tmpdir_env.set('OMP_NUM_THREADS', '1')
  tmpdir_env.set('DSEAMS_ROOT', root)
  tmpdir_env.set('TMPDIR', reader_tmp)
  tmpdir_env.set('DSEAMS_PROBE_STAMP', '1')
  test('fortran_readers_tmpdir', readers, args: [root], env: tmpdir_env, timeout: 180)
  absent_env = environment()
  absent_env.set('OMP_NUM_THREADS', '1')
  absent_env.set('DSEAMS_ROOT', root)
  absent_env.set('TMPDIR', meson.project_build_root() / 'reader-tmp-absent')
  absent_env.set('DSEAMS_PROBE_STAMP', '1')
  test('fortran_readers_tmpdir_absent', readers, args: [root], env: absent_env, timeout: 180)
  cwd_env = environment()
  cwd_env.set('OMP_NUM_THREADS', '1')
  cwd_env.set('DSEAMS_ROOT', root)
  cwd_env.set('TMPDIR', '')
  cwd_env.set('TEMP', '')
  cwd_env.set('TMP', '')
  cwd_env.set('DSEAMS_PROBE_STAMP', '1')
  test('fortran_readers_cwd', readers, args: [root], env: cwd_env, timeout: 180)

  # seams.f90 includes every module source: the single-file build, one
  # plain compiler call as a user without fpm or meson would make it.
  # Meson's module scanner does not follow include lines, so the call is a
  # custom target whose module files order the test program after it.
  fc = meson.get_compiler('fortran')
  one_file_obj = custom_target(
    'seams_one_file',
    input: files('seams.f90'),
    output: [
      'seams_one_file.o',
      'seams_kinds.mod',
      'seams_c.mod',
      'seams_support.mod',
      'seams.mod',
      'seams@seams_methods.smod',
    ],
    command: fc.cmd_array() + ['-fPIC', '-J@OUTDIR@', '-c', '@INPUT@', '-o', '@OUTPUT0@'],
  )
  one_file = executable(
    'test_fortran_one_file',
    files('test/test_high.f90'),
    one_file_obj,
    link_with: once_guard_lib,
    dependencies: [seams_dep],
    link_language: 'fortran',
  )
  test('fortran_one_file', one_file, args: [root], env: fortran_env, timeout: 180)

  seams_lang_dep = dependency('seams-lang', version: '>=2.14.1', required: false)
  if seams_lang_dep.found()
    seams_lang_dep = seams_lang_dep.partial_dependency(links: true, link_args: true)
  else
    seams_lang_dep = meson.get_compiler('fortran').find_library(
      'seams_lang',
      dirs: get_option('seams_libdir'),
    )
  endif
  lang_tasks = executable(
    'test_fortran_lang_tasks',
    files('test/lang_tasks.f90'),
    dependencies: [seams_lang_dep, seams_dep],
  )
  test('fortran_lang_tasks', lang_tasks, env: fortran_env, timeout: 180)

  cubic = executable(
    'fortran_cubic',
    files('example/cubic.f90'),
    dependencies: dseams_fortran_dep,
    link_language: 'fortran',
  )
  test('fortran_cubic', cubic, env: fortran_env, timeout: 180)

  minimal = executable(
    'fortran_minimal',
    files('example/minimal.f90'),
    dependencies: dseams_fortran_dep,
    link_language: 'fortran',
  )
  test(
    'fortran_minimal',
    minimal,
    args: [root / 'input/traj/genice_sI.lammpstrj'],
    env: fortran_env,
    timeout: 180,
  )
endif
