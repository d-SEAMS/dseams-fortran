# Contributing to dseams-fortran

This file is the working contract for anyone changing this repository. The
README is for users of the `dseams` fpm package; this file is for people
editing it.

## What lives here and what does not

This repository holds the Fortran modules on top of the d-SEAMS C API. The
engine, the C API (`libseams`, header `include/seams.h`) and the
language-front ABI (`libseams_lang`) live in
[d-SEAMS/seams-core](https://github.com/d-SEAMS/seams-core).

- A new analysis, a changed result, a C API function or enumerator, a reader
  for a new file format, or a bug inside libseams: change seams-core first.
  Bind it here once a seams-core commit carries it, and move the pin.
- An `iso_c_binding` interface, a derived-type method, a Fortran error
  message, the fpm or meson build, docs or examples: change it here.
- Do not copy engine sources into this tree. The package links an installed
  libseams and never builds one.

## Layout

| Path | Contents |
|---|---|
| `fpm.toml` | The `dseams` package: library, tests, examples. fpm reads it from the repository root for git and registry dependencies |
| `src/seams_kinds.f90` | `seams_real`, `seams_int`, checked against the C kinds |
| `src/seams_c.f90` | `seams_c`, the `bind(C)` image of `seams.h` |
| `src/seams_support.f90` | Reference-counted handle box; not public API |
| `src/seams.f90`, `src/seams_methods.f90` | `seams`, the derived-type API, and its submodule |
| `seams.f90` | Includes every `src/` file in order, for a one-file build. fpm and meson must not compile it with `src/` |
| `test/` | `check_dseams.f90`, `test_capi.f90`, `test_high.f90`, `lang_tasks.f90`, `test_readers.f90`, `test_feature_query.f90`, `test_thread_safety.f90`, `test_no_lock_symlink.f90` |
| `example/` | `cubic.f90` and `minimal.f90`, run as fpm examples and meson tests |
| `examples/downstream/` | A separate fpm project with a path dependency on this one |
| `input/` | Trajectories the tests read, copied from seams-core |
| `meson.build`, `meson.options` | Standalone meson project, exported as `dependency('dseams-fortran')` for subprojects |
| `docs/` | User manual: getting started, tutorials, how-tos, the narrative API page, and the FORD coverage check |
| `ford.md` | FORD settings; output goes to `build/ford` |
| `packaging/fpm/registry.toml` | Stanza for the fortran-lang fpm registry |
| `changelog.d/` | Unreleased changelog fragments |
| `.github/workflows/ci.yml` | Builds seams-core at the pin and runs every check below |

## How the build finds libseams

Neither build compiles the engine's C or C++. Both link `-lseams`, and the
`lang_tasks` test also links `-lseams_lang`. The one exception is
`src/dseams_once.c`: a few lines of `<stdatomic.h>`, owned by this
repository, not vendored from seams-core, giving the probe's once-guard
(`has_chemfiles`/`has_readcon`, `src/seams_methods.f90`) an in-process
compare-and-swap with no OS-specific static initializer and no lock file.
Both fpm (which picks up a `.c` file placed in `src/` on its own) and
meson (`add_languages('c')`, a small `static_library` the Fortran library
links) compile it.

- fpm: `FPM_LDFLAGS` carries the search path and the rpath. With an
  installed prefix,
  `FPM_LDFLAGS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"`, or the pkg-config
  form in the README. A meson install of seams-core leaves the libraries
  libseams loads without a RUNPATH, so set `LD_LIBRARY_PATH=$PREFIX/lib`
  as well.
- meson: the pkg-config modules `seams` and `seams-lang` (link flags only;
  their C compile flags are dropped). When pkg-config cannot resolve them,
  `-Dseams_libdir=dir1,dir2` names the directories to search.

CI builds the seams-core tag named by `SEAMS_CORE_REPOSITORY` and
`SEAMS_CORE_REF` at the top of `.github/workflows/ci.yml`. A release
pins that tag.

## Build and test

Build seams-core at the pinned tag in a sibling checkout. Its build tree
holds `libseams.so` in `bbdir/src` and `libseams_lang.so` in
`bbdir/bindings`:

```bash
git -C ../seams-core checkout "$SEAMS_CORE_REF"
(cd ../seams-core && pixi run meson setup bbdir && pixi run ninja -C bbdir)

SC=$PWD/../seams-core/bbdir
export FPM_LDFLAGS="-L$SC/src -L$SC/bindings -Wl,-rpath,$SC/src -Wl,-rpath,$SC/bindings"
export LD_LIBRARY_PATH=$SC/src:$SC/bindings
export OMP_NUM_THREADS=1
```

Then, from the repository root:

```bash
fpm build
fpm test
fpm run --example cubic
fpm run --example minimal -- input/traj/genice_sI.lammpstrj
(cd examples/downstream && fpm run)

meson setup build/meson -Dseams_libdir=$SC/src,$SC/bindings
meson test -C build/meson --print-errorlogs

fpm build --dump fpm_model.json && fpm publish --show-upload-data
ford ford.md
```

`fpm test` prints `dseams fortran ok`, `fortran ok`, `fortran high ok`,
the `lang_tasks` line `pairs 512 rings 0 0 0 0 0 0 256 chill 0 128 0 0 0 0
0 0 0`, and from `readers` the lines `has_chemfiles`, `has_readcon`,
`read` or `skip` for `con`, `pdb` and `gro`, then `fortran readers ok`.
`feature_query` prints the same two feature-query lines from a
standalone consumer and `fortran feature query ok`; it does not build
against a `seams.mod` from before `has_chemfiles` existed.
`thread_safety` spawns sixteen POSIX threads that all call
`has_chemfiles` and `has_readcon` at once and prints `fortran thread
safety ok` once every thread agrees with a single-threaded baseline.
`no_lock_symlink` plants a symlink at the once-guard's old lock-file
name, pointing at a file with known content, runs the real probe, and
checks that file is untouched, printing `fortran no lock symlink ok`.
Meson runs fourteen tests, including the one-file build of `seams.f90`
and three `readers` runs that vary `TMPDIR`, `TEMP` and `TMP`.

Every check must pass before a change is called done. Fix the code under
test; do not skip, comment out, loosen or delete a test to get there. A test
may change only when the behavior it pins changes on purpose, and the commit
says so.

## When seams.h changes

1. Move `SEAMS_CORE_REF` in `.github/workflows/ci.yml` to the seams-core
   commit or tag.
2. Add the `bind(C)` interfaces to `src/seams_c.f90`, matching the header's
   argument order, `value` attributes and kinds.
3. Wrap them in `seams` (`src/seams.f90` for the interface,
   `src/seams_methods.f90` for the body), with `stat` and `errmsg`.
4. Call the new symbols from `test/test_capi.f90` and `test/test_high.f90`.
   FORD publishes them from the source comments.
   `docs/check_api_coverage.py` fails the docs build when a public
   symbol has no page. Describe the call in `docs/api/fortran.md` when
   a reader needs a worked example.
5. A new module file goes in the `include` list of `seams.f90` and in
   `fortran_lib_src` and the one-file custom target in `meson.build`.

## Commits and changelog

- [Conventional Commits](https://www.conventionalcommits.org/):
  `feat`, `fix`, `docs`, `test`, `build`, `ci`, `refactor`, `style`, `chore`,
  with a scope where it helps (`build(meson): ...`). One logical change per
  commit; formatter-only changes go in their own `style:` commit.
- ASCII punctuation in code, docs and commit messages. Comments say what the
  code does and why, in the present tense; history belongs in the commit.
- Every user-visible change adds a fragment to `changelog.d/`, named
  `<issue>.<type>.md` or `+<slug>.<type>.md`, where `<type>` is `added`,
  `changed`, `deprecated`, `removed`, `fixed` or `security`. See
  `changelog.d/README.md`.

## Releases

The package version is the seams-core version it binds. The path from a
clean clone to a published release is
`docs/orgmode/contributing/developer/release.org`. Follow that file.
`changelog.d/` holds the towncrier fragments, `cog.toml` drives the
version commit and the `v` tag, and `ci/version/files.txt` lists the
copies cogapp rewrites from `fpm.toml`.
