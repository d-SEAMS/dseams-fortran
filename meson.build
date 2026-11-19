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
  'fortran',
  # [[[cog import dseams_version as v; cog.outl(f"  version: '{v.VERSION}',")]]]
  version: '2.14.1',
  # [[[end]]]
  license: 'MIT',
  meson_version: '>=1.1.0',
  default_options: ['warning_level=1'],
)

# The Fortran sources only link libseams. C include paths in seams.pc are
# dropped. The two reader macros are kept: they name what that libseams
# was built with. A chemfiles or readcon-core pkg-config file is the other
# way to learn the same fact. This package does not link either library
# and does not compile a reader.
seams_pc = dependency('seams', version: '>=2.14.1', required: false)
if seams_pc.found()
  seams_dep = seams_pc.partial_dependency(links: true, link_args: true)
else
  seams_dep = meson.get_compiler('fortran').find_library(
    'seams',
    dirs: get_option('seams_libdir'),
  )
endif

reader_defines = []
if seams_pc.found()
  pkgconfig = find_program('pkg-config', required: false)
  if pkgconfig.found()
    pc_cflags = run_command(pkgconfig, '--cflags', 'seams', check: false).stdout().strip()
    foreach flag : pc_cflags.split()
      # READCON_DB is a different macro. Match the reader flag only.
      if flag.startswith('-DSEAMS_HAS_CHEMFILES') or flag.startswith('-DSEAMS_HAS_READCON=') or flag == '-DSEAMS_HAS_READCON'
        reader_defines += flag
      endif
    endforeach
  endif
endif

chemfiles_defined = false
readcon_defined = false
foreach flag : reader_defines
  if flag.startswith('-DSEAMS_HAS_CHEMFILES')
    chemfiles_defined = true
  elif flag.startswith('-DSEAMS_HAS_READCON')
    readcon_defined = true
  endif
endforeach

# auto: missing library, no macro, build continues (LAMMPS and XYZ only).
# enabled: the macro must come from seams.pc or from the library itself.
# disabled: do not search. A macro already published by seams.pc stays,
# because it describes the libseams this build links.
if not get_option('with_chemfiles').disabled() and not chemfiles_defined
  chemfiles_dep = dependency('chemfiles', required: get_option('with_chemfiles'))
  if chemfiles_dep.found()
    reader_defines += '-DSEAMS_HAS_CHEMFILES=1'
  endif
endif
if not get_option('with_readcon').disabled() and not readcon_defined
  readcon_dep = dependency(
    'readcon-core',
    version: '>=0.16.2',
    required: get_option('with_readcon'),
  )
  if readcon_dep.found()
    reader_defines += '-DSEAMS_HAS_READCON=1'
  endif
endif

seams_compile_args = []
if reader_defines.length() > 0
  seams_compile_args = ['-cpp'] + reader_defines
endif

fortran_lib_src = files(
  'src/seams_kinds.f90',
  'src/seams_c.f90',
  'src/seams_support.f90',
  'src/seams.f90',
  'src/seams_methods.f90',
)

dseams_lib = static_library(
  'dseams_fortran',
  fortran_lib_src,
  fortran_args: seams_compile_args,
  dependencies: seams_dep,
  pic: true,
)
dseams_fortran_dep = declare_dependency(
  link_with: dseams_lib,
  include_directories: dseams_lib.private_dir_include(),
  dependencies: seams_dep,
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

  check = executable(
    'test_fortran_check',
    files('test/check_dseams.f90'),
    dependencies: dseams_fortran_dep,
  )
  test('fortran_check', check, env: fortran_env, timeout: 180)

  high = executable(
    'test_fortran_high',
    files('test/test_high.f90'),
    dependencies: dseams_fortran_dep,
  )
  test('fortran_high', high, args: [root], env: fortran_env, timeout: 180)

  readers = executable(
    'test_fortran_readers',
    files('test/test_readers.f90'),
    dependencies: dseams_fortran_dep,
  )
  test('fortran_readers', readers, args: [root], env: fortran_env, timeout: 180)

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
    command: fc.cmd_array() + seams_compile_args + ['-fPIC', '-J@OUTDIR@', '-c', '@INPUT@', '-o', '@OUTPUT0@'],
  )
  one_file = executable(
    'test_fortran_one_file',
    files('test/test_high.f90'),
    one_file_obj,
    dependencies: seams_dep,
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
  )
  test('fortran_cubic', cubic, env: fortran_env, timeout: 180)

  minimal = executable(
    'fortran_minimal',
    files('example/minimal.f90'),
    dependencies: dseams_fortran_dep,
  )
  test(
    'fortran_minimal',
    minimal,
    args: [root / 'input/traj/genice_sI.lammpstrj'],
    env: fortran_env,
    timeout: 180,
  )
endif
