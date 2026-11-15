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

The package links an installed libseams 2.14.0 and does not build it.
From a seams-core checkout at `v2.14.0`:

```bash
meson setup build --prefix="$PREFIX" --libdir=lib -Dwith_python=false
meson install -C build
```

That installs `libseams.so` and `seams.pc` under `$PREFIX/lib`.

## Use it from fpm

```toml
[dependencies]
dseams = { git = "https://github.com/d-SEAMS/dseams-fortran", tag = "v2.14.0" }
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
`fortran high ok`). The tests read the trajectories under `input/`,
copied from seams-core.

## Meson

`meson.build` builds the same modules for projects that take this
repository as a subproject, and runs the same programs plus the
single-file build:

```bash
meson setup build/meson   # finds libseams through seams.pc
meson test -C build/meson
```

A parent project calls `subproject('dseams-fortran')` and then
`dependency('dseams-fortran')`.

## Single file

`seams.f90` includes every module source in dependency order, for a
build that compiles one file:

```bash
gfortran -c seams.f90
gfortran your_program.f90 seams.o -L"$SEAMS_LIB_DIR" -lseams
```

## Documentation

`docs/api/fortran.md` is the narrative reference and
`docs/tutorials/fortran.md` the tutorial. `ford ford.md` writes the
FORD reference to `build/ford`.

## License

MIT. See `LICENSE`.
