# Reading a trajectory

<figure class="dseams-video">
<iframe title="Fortran on ice Ih" src="https://odysee.com/$/embed/dseams-fortran:e15a82c2f40ff1fdf10c89ff6c9f78b6b3fd583b" width="960" height="540" allowfullscreen></iframe>
<figcaption>Fortran on ice Ih.</figcaption>
</figure>

`use seams` and read `input/traj/ice1h.lammpstrj`. The dump is 128
waters, all type 1. The default CHILL+ call uses a 3.5 angstrom cutoff,
the cutoff neighbour graph, and the published rule. Run it with one
thread.

```fortran
program ice_ih
  use seams
  implicit none
  type(seams_frame) :: frame
  type(seams_cages) :: cages
  type(seams_rings) :: rings
  integer(seams_int), allocatable :: labels(:), counts(:), hist(:)
  integer(seams_int) :: n_hex, n_cubic, n_water, n_both
  real(seams_real), allocatable :: q4(:), q6(:)
  call set_num_threads(1_seams_int)
  frame = new_frame()
  call frame%read("input/traj/ice1h.lammpstrj")
  call frame%chill_plus(labels, counts)
  call frame%q4q6(q4, q6)
  cages = frame%cages()
  call cages%counts(n_hex, n_cubic, n_water, n_both)
  rings = frame%rings(max_depth=6_seams_int)
  call rings%histogram(hist)
  print "(a,i0)", "atoms ", frame%count()
  print "(a,i0)", "hexagonal ", counts(2)
  print "(a,f0.8)", "q6_mean ", sum(q6) / size(q6)
  print "(a,i0,1x,i0,1x,i0,1x,i0)", "cages ", n_hex, n_cubic, n_water, n_both
  print "(a,i0)", "rings6 ", hist(6)
  call rings%close()
  call cages%close()
  call frame%close()
end program ice_ih
```

```text
atoms 128
hexagonal 128
q6_mean .62585547
cages 128 0 0 0
rings6 256
```

`counts(2)` is hexagonal ice. `cages` is hexagonal, double-diamond,
neither, both: every molecule sits in a hexagonal cage and none in a
double-diamond cage. `hist(6)` is the number of primitive six-rings.
`q6_mean` is the mean of the local q6 from `frame%q4q6`.

`example/minimal.f90` (`fpm run --example minimal --
input/traj/genice_sI.lammpstrj`) reads the GenIce sI cell and prints
`fortran example ok`. `example/cubic.f90` is the 64-atom cubic cell.
The {doc}`API page <../api/fortran>` quotes its output.

The C image of `seams.h` is `seams_c`. `test/test_capi.f90` calls it.
`fpm test capi` and `meson test fortran_capi` run that program. The
{doc}`build how-to <../user-guide/howto/build>` has the gfortran line.

The engine manual for this binding is
[docs.dseams.info](https://docs.dseams.info/fronts/fortran.html).
