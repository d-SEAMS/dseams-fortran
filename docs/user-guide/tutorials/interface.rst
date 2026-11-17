Ice-water interface
===================

.. include:: ../../_includes/interface.rst

``input/traj/interface_f0.lammpstrj`` in a seams-core checkout is one
basal-interface frame, 864 atoms, all type 1. Read it with
``type_filter=1`` and call ``frame%chill_plus`` with ``typ=1``. The
default is the published rule on the cutoff graph at 3.5 angstrom.
With one thread the populations are

.. list-table::
   :header-rows: 1

   * - label
     - atoms
   * - cubic
     - 1
   * - hexagonal
     - 352
   * - water
     - 434
   * - interfacial
     - 49
   * - clathrate
     - 3
   * - interClathrate
     - 25

``label_name`` returns those strings. ``counts(i)`` is the population
of label ``i - 1``. The hexagonal and water counts are the two large
bins; the other four bins are the rest of the 864. The engine page,
including the slab profile along the long edge, is
`Ice-water interface <https://docs.dseams.info/tutorials/interface.html>`_.

.. code-block:: fortran

   frame = new_frame()
   call frame%read("input/traj/interface_f0.lammpstrj", type_filter=1_seams_int)
   call frame%chill_plus(labels, counts, typ=1_seams_int)
