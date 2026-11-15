# Fortran tutorial

`src/seams.f90` is the Fortran module. `src/seams_c.f90` is the `iso_c_binding` image of `seams.h`. `test/test_capi.f90` calls that image. `test/test_high.f90` calls the derived-type API.

```bash
mkdir -p build/fmod
gfortran -Jbuild/fmod -c src/seams_kinds.f90 -o build/fmod/seams_kinds.o
gfortran -Jbuild/fmod -Ibuild/fmod -c src/seams_c.f90 -o build/fmod/seams_c.o
gfortran -Jbuild/fmod -Ibuild/fmod -c src/seams_support.f90 -o build/fmod/seams_support.o
gfortran -Jbuild/fmod -Ibuild/fmod -c src/seams.f90 -o build/fmod/seams.o
gfortran -Jbuild/fmod -Ibuild/fmod -c src/seams_methods.f90 -o build/fmod/seams_methods.o
gfortran -Ibuild/fmod test/test_capi.f90 build/fmod/seams_c.o \
  -o build/test_seams -L"$SEAMS_LIB_DIR" -lseams -Wl,-rpath,"$SEAMS_LIB_DIR"
build/test_seams "$PWD"
```

It prints `fortran ok` after the 64-atom cell is entirely cubic under both CHILL+ rules, q6 is above 0.3, and the six-ring fraction is above one half.
`fpm test capi` and `meson test fortran_capi` run the same program from the repository root.
The same program calls `seams_chill`, `seams_steinhardt`, `seams_cages`, `seams_signature_cages`, `seams_neighbours_knn`, `seams_rdf`, `seams_running_cn`, `seams_coordination`, `seams_hbonds`, `seams_density_axis`, `seams_fingerprint`, `seams_contact_pairs`, `seams_domains`, `seams_prisms`, `seams_monolayer`, `seams_rings_vertices`, `seams_site_table`, and `seams_system_read`.
The lines it prints are:

```
fortran call cubic 64
fortran call q6 0.628539361055
fortran call cages 0 64 0 0
fortran call sig 0 0
fortran call cn 4.063492063492
fortran call hbond 0
fortran call sheet 128
fortran call vert 6 0
fortran call read 128 46
```

`cubic 64` is the published CHILL+ count. `q6` is the mean of `seams_q4q6`.
`cages` is the seeded census. `sig 0 0` is the `512` signature on this cubic cell.
`read 128 46` is ice Ih and the sI guest frame.

The part of the program that prints those lines:

```{literalinclude} ../../test/test_capi.f90
:language: fortran
:lines: 38-75
```


