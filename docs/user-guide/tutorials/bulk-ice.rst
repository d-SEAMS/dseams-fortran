Bulk ice
=========

.. include:: ../../_includes/fortran.rst

Two cells in this package are pure ice, and one mixed frame in
seams-core is not. The engine walk-through of that mixed frame is
`Classify ice on the mixed TIP4P example <https://docs.dseams.info/tutorials/bulk-ice.html>`_.

Ice Ih
------

``input/traj/ice1h.lammpstrj`` is 128 waters. The program on the
`Reading a trajectory <../../tutorials/fortran.html>`_ page reads it.
CHILL+ labels
every molecule hexagonal, the cage search finds 128 hexagonal cages
and no double-diamond cage, and the ring histogram holds 256
six-rings. The mean local q6 is 0.62585547.

Cubic ice
---------

``example/cubic.f90`` builds a 64-atom cubic cell in memory, two
repeats of the eight-site cell on an edge of
``2.75 * 4 / sqrt(3)`` angstrom. ``fpm run --example cubic`` checks
the classification and prints the census quoted on the
`API page <../../api/fortran.html>`_. All 64 atoms are cubic ice.
The cage census is ``0 64 0 0``: no hexagonal cage, 64
double-diamond cages, no water, no atom in both.

A mixed frame
-------------

``input/traj/exampleTraj.lammpstrj`` in a seams-core checkout is one
frame of 750 atoms: 250 of type 2 and 500 of type 1. Read type 2 and
pass ``typ=2`` so CHILL+ and the cage search see those 250 atoms.
The cutoff graph (the default) labels 9 interClathrate and 241 water.
The mutual four-neighbour graph labels 1 clathrate, 7 interClathrate
and 242 water. The seeded cage search labels all 250 water:
``cages`` returns ``0 0 250 0``.

.. code-block:: fortran

   frame = new_frame()
   call frame%read("input/traj/exampleTraj.lammpstrj", type_filter=2_seams_int)
   call frame%chill_plus(labels, counts, typ=2_seams_int)
   call frame%chill_plus(labels, counts, typ=2_seams_int, graph=SEAMS_GRAPH_MUTUAL)
   cages = frame%cages(typ=2_seams_int)

CHILL+ is a four-neighbour star. Cages ask whether the molecule
belongs to a complete hexagonal or double-diamond cage. On this frame
the star finds a few eclipsed shells and the cage search finds none.
The same split, with the command-line names, is on the engine page
linked above.
