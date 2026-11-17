Nucleation
==========

.. include:: ../../_includes/nucleation.rst

``input/traj/nucleation_three.lammpstrj`` in a seams-core checkout is
the first three frames of the 4096-atom mW trajectory, all type 1.
``path_nframes`` returns 3. ``frame`` on ``frame%read`` is 1-based.
The engine page, including the largest crystal cluster, is
`Nucleation <https://docs.dseams.info/tutorials/nucleation.html>`_.

Published CHILL+ on the cutoff graph, one thread:

.. list-table::
   :header-rows: 1

   * - frame
     - cubic
     - hexagonal
     - q6-bar above 0.36
     - mean q6-bar
   * - 1
     - 47
     - 62
     - 284
     - 0.260630
   * - 2
     - 50
     - 60
     - 290
     - 0.260923
   * - 3
     - 44
     - 69
     - 272
     - 0.261047

Cubic is ``counts(1)`` and hexagonal is ``counts(2)``.
``frame%q6bar`` writes the Lechner-Dellago q6-bar. The ice count is
the number of atoms at or above ``ice_cut``, which defaults to 0.36.
That count is larger than the cubic-plus-hexagonal population: a q6
cut does not separate the two crystals.

.. code-block:: fortran

   do fr = 1, 3
     frame = new_frame()
     call frame%read("input/traj/nucleation_three.lammpstrj", frame=fr)
     call frame%chill_plus(labels, counts)
     call frame%q6bar(q6bar, mean, median, n_ice)
     call frame%close()
   end do
