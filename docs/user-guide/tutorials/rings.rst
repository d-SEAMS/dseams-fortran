Primitive rings
===============

.. include:: ../../_includes/rings.rst

``frame%rings`` finds primitive rings. ``max_depth`` defaults to 6
and must be from 3 through 12. The default graph is the cutoff graph
at 3.5 angstrom. ``histogram`` is 0-based: index ``k`` is the number
of rings of size ``k``.

sI host
-------

On ``input/traj/genice_sI.lammpstrj``, with ``max_depth=6``:

.. code-block:: text

   five-rings 48
   six-rings 54

``example/minimal.f90`` checks those two numbers.
``call rings%fraction(6_seams_int, fraction)`` is the fraction of
atoms that sit on a six-ring. Size 0 counts atoms that sit on any
ring. ``call rings%vertices(1_seams_int, atoms)`` returns the atom
indices of the first ring. The index is 1-based.

Ice Ih
------

On ``input/traj/ice1h.lammpstrj`` the same histogram holds 256
six-rings and no smaller ring. The fraction of atoms on a six-ring
is 1.

The engine page for the mixed TIP4P census is
`Primitive rings <https://docs.dseams.info/tutorials/rings.html>`_.
