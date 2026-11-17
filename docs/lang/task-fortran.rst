Language task
=============

The program binds the language front with ``iso_c_binding``. Every call
returns a status code, and the frame pointer is released on the success
path and on the error path.

It links ``libseams_lang`` (``-lseams_lang``), the language-front C
ABI that seams-core installs beside ``libseams``.

.. literalinclude:: ../../test/lang_tasks.f90
   :language: fortran

``fpm test lang_tasks`` and ``meson test fortran_lang_tasks`` compile
and run this file from the repository root. It prints

.. code-block:: text

   pairs 512 rings 0 0 0 0 0 0 256 chill 0 128 0 0 0 0 0 0 0

for ``input/traj/ice1h.lammpstrj`` and exits 1 on any other line.
``pairs 512`` is the cutoff neighbour list. The ring histogram is
empty below size 6 and holds 256 six-rings. ``chill`` is the nine
CHILL+ populations, with 128 hexagonal. The same line is what the
other language fronts print for this file. The task list is
`Language tasks <https://docs.dseams.info/lang/tasks.html>`_.
