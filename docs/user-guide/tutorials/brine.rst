Brine front
===========

.. include:: ../../_includes/brine.rst

``input/traj/nacl_front.lammpstrj`` in a seams-core checkout is 873
atoms: 864 of type 1, 5 of type 3 and 4 of type 4. The engine tutorial
names the ion types and the slabs they sit in:
`Brine and NaCl <https://docs.dseams.info/tutorials/brine.html>`_.

Read every atom (``type_filter=-1``). CHILL+ with ``typ=1`` labels the
type-1 atoms and leaves the other 9 unclassified:

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
   * - unclassified
     - 9

Mark cubic and hexagonal atoms as ice (353 atoms) and build the front
along axis 2, which is the default. ``water_type=1`` keeps type 1 as
water. ``ion_type=3`` keeps type 3 as the ion.

.. code-block:: fortran

   allocate(ice(size(labels)))
   ice = 0
   where (labels == SEAMS_LABEL_CUBIC .or. labels == SEAMS_LABEL_HEXAGONAL)
     ice = 1
   end where
   front = frame%brine(ice, water_type=1_seams_int, ion_type=3_seams_int)
   call front%fronts(z_enter, z_exit, thickness, found)
   call front%rejection(c_ice, c_liquid, k, defined)
   call front%pockets(n_pockets, reservoir)

With one thread the front is found (``found`` is 1). The ice run
enters at 2.422623 angstrom and leaves at 23.503619 angstrom, so the
thickness is 21.080996 angstrom. The molal rejection coefficient is
defined: ``c_ice`` is 0.108840, ``c_liquid`` is 0.256983 and ``k`` is
0.423529. ``pockets`` returns 0 pockets and 511 reservoir waters.
``ion_type=0`` is the same geometry with no ion species. Lengths are
angstrom. ``front%close`` releases the front; it does not free the
frame.
