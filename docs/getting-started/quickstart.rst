Quickstart
==========

Eight water sites on a cubic diamond lattice, edge
``2.75 * 4 / sqrt(3)`` angstrom. ``counts(1)`` is the cubic-ice
population, because the C label 0 is the first Fortran element.

.. code-block:: fortran

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

With one thread the program prints

.. code-block:: text

   cubic 8 of 8

``labels`` and ``counts`` are allocatable and belong to the caller.
``frame%close`` destroys the C frame. The same eight sites are the
body of ``examples/downstream``.

Next, read a trajectory in the
`Fortran tutorial <../tutorials/fortran.html>`_.
