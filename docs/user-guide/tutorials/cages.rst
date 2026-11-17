Cages
=====

.. include:: ../../_includes/cages.rst

``frame%cages`` returns hexagonal cages, double-diamond cages, water
(neither), and atoms in both. The default graph is the seeded cage
graph: mutual four-nearest seeds, then union completions. ``k``
defaults to 4 and the cutoff defaults to 3.5 angstrom.

The sI cell in this package
---------------------------

``input/traj/genice_sI.lammpstrj`` is 46 atoms, all type 1.
``frame%chill_plus`` labels all 46 clathrate (``counts(5)``).
``frame%cages`` returns ``0 0 46 0``: the topological unit search
does not call this host ice Ih or ice Ic. A ring signature does.
``call frame%signature("512", n_cages, n_atoms)`` returns 2 cages and
40 atoms. That is the 5\ :sup:`12` census on the cutoff graph.

``example/minimal.f90`` reads the same file, requires
``counts(5) == 46``, 48 five-rings and 54 six-rings, and prints
``fortran example ok``.

Ice
---

On ``input/traj/ice1h.lammpstrj`` the same call returns 128 hexagonal
cages and no double-diamond cage. On the 64-atom cell in
``example/cubic.f90`` it returns 64 double-diamond cages and no
hexagonal cage. The four cage codes are ``SEAMS_CAGE_WATER``,
``SEAMS_CAGE_HEX``, ``SEAMS_CAGE_CUBIC`` and ``SEAMS_CAGE_BOTH``.

The engine comparison with TRACE is
`Cages and TRACE <https://docs.dseams.info/howto/cages-trace.html>`_.
