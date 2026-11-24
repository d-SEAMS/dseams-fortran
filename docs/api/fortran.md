# Fortran

`seams` is the module a program uses. `seams_c` is the `iso_c_binding`
image of `include/seams.h`. Kinds come from `iso_fortran_env`:
`seams_real` is `real64` and `seams_int` is `int32`, and both are
asserted equal to the C kinds at compile time. Coordinates are
`real(seams_real)` with shape `(3, n)`, x/y/z down the first index,
which is the same memory order as the C array.

The generated pages list every public symbol. They are
<a href="generated/module/seams.html"><code>seams</code></a>,
<a href="generated/module/seams_c.html"><code>seams_c</code></a> and
<a href="generated/module/seams_kinds.html"><code>seams_kinds</code></a>.
The C API is the
[d-SEAMS reference](https://docs.dseams.info/reference/api.html).

## Defaults

A missing optional cutoff is 3.5 angstrom. CHILL and CHILL+ default to
the cutoff graph and the published rule (`SEAMS_CHILL_PUBLISHED`).
Cages default to the seeded graph. Rings default to the cutoff graph
and a maximum size of 6. `frame%read` is 1-based. A negative
`type_filter` keeps every atom. The `typ` argument of an analysis
selects one species in the frame; 0 means every species.

## CHILL+ populations

`counts` has nine elements. Element `i` is label `i - 1`.

| element | label | `label_name` |
|---|---|---|
| `counts(1)` | `SEAMS_LABEL_CUBIC` | cubic |
| `counts(2)` | `SEAMS_LABEL_HEXAGONAL` | hexagonal |
| `counts(3)` | `SEAMS_LABEL_WATER` | water |
| `counts(4)` | `SEAMS_LABEL_INTERFACIAL` | interfacial |
| `counts(5)` | `SEAMS_LABEL_CLATHRATE` | clathrate |
| `counts(6)` | `SEAMS_LABEL_INTERCLATHRATE` | interClathrate |
| `counts(7)` | `SEAMS_LABEL_UNCLASSIFIED` | unclassified |
| `counts(8)` | `SEAMS_LABEL_RECUBIC` | reCubic |
| `counts(9)` | `SEAMS_LABEL_REHEX` | reHex |

Cage codes are `SEAMS_CAGE_WATER` (0), `SEAMS_CAGE_HEX` (1),
`SEAMS_CAGE_CUBIC` (2) and `SEAMS_CAGE_BOTH` (3).
`frame%cages` then `counts` returns hexagonal, double-diamond, water,
both, in that order.

## Ownership

A handle is a derived type with a final procedure. Assignment shares
the C object. `close` or the last finalizer destroys it. Neighbour
lists, rings, cages, fingerprints and brine fronts own their own
copies: closing the frame does not free them. Do not use one handle
from two threads.

## Errors

Pass `stat` and `errmsg`, or neither. With neither, a failed call
stops the program with the library message. With `stat`, the
`seams.h` code is stored and the program continues. The
{doc}`error how-to <../user-guide/howto/errors>` is a negative box edge,
which returns `SEAMS_ERR_BOX`.

## Quickstart

Eight cubic-ice sites. `counts(1)` is 8.

```fortran
program quickstart
  use seams
  implicit none
  integer, parameter :: n = 8
  type(seams_frame) :: frame
  real(seams_real) :: xyz(3, n), lx, ly, lz
  integer(seams_int), allocatable :: labels(:), counts(:)
  lx = 2.75_seams_real * 4 / sqrt(3.0_seams_real)
  ly = lx
  lz = lx
  xyz = lx * reshape(real([0.0, 0.0, 0.0, 0.25, 0.25, 0.25, 0.5, 0.5, 0.0, &
    0.75, 0.75, 0.25, 0.5, 0.0, 0.5, 0.75, 0.25, 0.75, 0.0, 0.5, 0.5, &
    0.25, 0.75, 0.75], seams_real), [3, n])
  frame = new_frame()
  call frame%set_ortho(xyz, lx, ly, lz)
  call frame%chill_plus(labels, counts)
  print "(a,i0,a,i0)", "cubic ", counts(1), " of ", n
  if (counts(1) /= n) error stop "every site is cubic"
  call frame%close()
end program quickstart
```

```text
cubic 8 of 8
```

## Cubic ice

`example/cubic.f90` (`fpm run --example cubic`) is the 64-atom cell,
one thread. This is the output:

```text
version 2.14.2
atoms 64
cubic 64
counts_cubic 64
q6_mean   0.62853936
pairs 256
rings6 128
fraction6   1.00000000
coordination   4.06349206
ql6_first   0.62853936
cages 0 64 0 0
signature512 0 0
rdf_bins 8 2049.208555
hbonds 0
density_bins 4    0.031232
fingerprint 16
contacts 0 0 0
domain 0 0    0.000000
prisms6 0
monolayer6 128
site0 8
symmetry0 1
brine 1    0.000000   12.701706
q6bar_ice 64  0.62853936
```

`cages` is hexagonal, double-diamond, neither, both. All 64 atoms are
double-diamond. `site0` is 8, water oxygen (`SEAMS_SITE_WATER_O` in
`seams.h`). `symmetry0` is 1, ice Ic. `q6bar_ice`
counts atoms above 0.36. The cell has no hydrogens, so `hbonds` is 0.
`signature512` is 0 because this cell is not a clathrate.

## GenIce sI

`example/minimal.f90` (`fpm run --example minimal --
input/traj/genice_sI.lammpstrj`) reads the 46-atom sI cell. The
program checks at least 150 neighbour pairs, clathrate
`counts(5) == 46`, 48 five-rings, 54 six-rings, and a q6 mean above
0.5. It prints `fortran example ok`. `frame%signature("512", ...)`
on that cell returns 2 cages and 40 atoms.
