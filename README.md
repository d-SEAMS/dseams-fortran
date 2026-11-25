# dseams: Fortran interface to d-SEAMS

`dseams` is the fpm package for the [d-SEAMS](https://dseams.info) C API
(`libseams`, header `include/seams.h` in
[seams-core](https://github.com/d-SEAMS/seams-core)). It labels ice and
clathrate structures (CHILL, CHILL+) and computes Steinhardt order
parameters, rings, cages, RDFs and related analyses on frames held in
Fortran arrays.

`seams` is the module programs use. `seams_c` is the `iso_c_binding`
image of `include/seams.h`. Kinds are `seams_real` (`real64`) and
`seams_int` (`int32`). Coordinates have shape `(3, n)`.

A handle is a derived type. Assignment shares it. The last finalizer,
or `close`, destroys the C object. Pass `stat` and `errmsg` to catch a
failure. Omit both and a failure stops the program with the library
message.

## Install libseams

The package links an installed libseams 2.14.2 and does not build it.
From a seams-core checkout at `v2.14.2`:

```bash
meson setup build --prefix="$PREFIX" --libdir=lib
meson install -C build
```

That installs `libseams.so` and `seams.pc` under `$PREFIX/lib`.

## Use it from fpm

```toml
[dependencies]
dseams = { git = "https://github.com/d-SEAMS/dseams-fortran", tag = "v2.14.2" }
```

fpm needs the library directory on the link line, and the loader needs
it at run time. With `seams.pc` on `PKG_CONFIG_PATH`:

```bash
export FPM_LDFLAGS="$(pkg-config --libs-only-L seams) -Wl,-rpath,$(pkg-config --variable=libdir seams)"
fpm build
```

Without pkg-config, name the directory that holds `libseams.so`:

```bash
export FPM_LDFLAGS="-L$SEAMS_LIB_DIR -Wl,-rpath,$SEAMS_LIB_DIR"
```

A meson install leaves the libraries libseams loads beside it without a
RUNPATH, so also set `LD_LIBRARY_PATH="$PREFIX/lib"` to run the
programs.

`examples/downstream` is a project with a path dependency on this one:

```console
$ cd examples/downstream && fpm run
downstream: 8 of 8 waters are cubic ice
```

## Test

```bash
OMP_NUM_THREADS=1 fpm test
fpm run --example cubic
fpm run --example minimal -- input/traj/genice_sI.lammpstrj
```

`fpm test` runs `check_dseams` (the C interface on a cubic cell and ice
Ih, prints `dseams fortran ok`), `capi` (every `bind(C)` procedure,
prints `fortran ok`) and `high` (the derived-type API, prints
`fortran high ok`). `lang_tasks` binds `libseams_lang`, the
language-front C ABI installed beside libseams, and prints
`pairs 512 rings 0 0 0 0 0 0 256 chill 0 128 0 0 0 0 0 0 0` for ice Ih
(`docs/lang/task-fortran.rst`). The tests read the trajectories under
`input/`, copied from seams-core.

## Meson

`meson.build` builds the same modules for projects that take this
repository as a subproject, and runs the same programs plus the
single-file build:

```bash
meson setup build/meson   # finds libseams and libseams_lang through pkg-config
meson test -C build/meson
```

When pkg-config cannot resolve them (for example `seams-core.pc` names
an `eigen3.pc` that is not on the path), name the directories instead:
`meson setup build/meson -Dseams_libdir="$PREFIX/lib"`.

A parent project calls `subproject('dseams-fortran')` and then
`dependency('dseams-fortran')`.

## Single file

`seams.f90` includes every module source in dependency order, for a
build that compiles one Fortran file alongside the C once-guard:

```bash
cc -c src/dseams_once.c
gfortran -c seams.f90
gfortran your_program.f90 seams.o dseams_once.o -L"$SEAMS_LIB_DIR" -lseams
```

## Documentation

- Site: <https://fortran.dseams.info/>, the manual with the
  FORD symbol pages under
  [`api/generated/`](https://fortran.dseams.info/api/generated/index.html).
- Engine manual: [the Fortran page](https://docs.dseams.info/stable/fortran.html)
  of [docs.dseams.info](https://docs.dseams.info).
- Video: [Fortran on ice Ih](https://odysee.com/dseams-fortran:e15a82c2f40ff1fdf10c89ff6c9f78b6b3fd583b).

A push to `main` builds the manual and deploys it to the site.

The manual has four parts: getting started, the user guide (tutorials
and how-tos), the API reference, and development. From this directory:

```bash
ford ford.md
sphinx-build -b html docs build/html
python3 docs/assemble_site.py build/html build/ford
```

Open `build/html/index.html`. `docs/api/fortran.md` is the narrative
reference. FORD writes the symbol pages to `build/ford`, and the
assemble step copies them to `build/html/api/generated`. The engine
manual is [docs.dseams.info](https://docs.dseams.info).

## Development

This repository holds only the Fortran side. The engine, the C API
(`libseams`, `include/seams.h`) and the language-front ABI
(`libseams_lang`) are developed in
[d-SEAMS/seams-core](https://github.com/d-SEAMS/seams-core); an analysis
or a C API change lands there first and is bound here afterwards.
The contributing guide at the repository root has the full contract.

To build against a local seams-core checkout, build it in place and point
both builds at its build tree:

```bash
(cd ../seams-core && meson setup bbdir && ninja -C bbdir)
SC=$PWD/../seams-core/bbdir
export FPM_LDFLAGS="-L$SC/src -L$SC/bindings -Wl,-rpath,$SC/src -Wl,-rpath,$SC/bindings"
export LD_LIBRARY_PATH=$SC/src:$SC/bindings
fpm test

meson setup build/meson -Dseams_libdir=$SC/src,$SC/bindings
meson test -C build/meson
```

CI builds seams-core tag `v2.14.2` on `d-SEAMS/seams-core`, named by
`SEAMS_CORE_REPOSITORY` and `SEAMS_CORE_REF` in
`.github/workflows/ci.yml`.

Releases follow
[docs/orgmode/contributing/developer/release.org](docs/orgmode/contributing/developer/release.org).

## License

MIT. See `LICENSE`.
