Development
===========

This repository is the Fortran side. The engine, ``include/seams.h``
and ``libseams_lang`` are developed in
`seams-core <https://github.com/d-SEAMS/seams-core>`_. An analysis or
a C API change lands there first and is bound here afterwards. The
contributing guide at the repository root is the contract for that
split. The package version is the seams-core release it binds,
currently 2.14.0.

Build the manual
----------------

From the repository root, with FORD 7 and Sphinx installed:

.. code-block:: bash

   ford ford.md
   python3 docs/check_api_coverage.py build/ford
   sphinx-build -W -b html docs build/html
   python3 docs/assemble_site.py build/html build/ford
   python3 docs/check_site.py build/html

``ford.md`` is the FORD project file. It reads ``src/`` and writes
``build/ford``. The coverage check reads the public names in
``seams``, ``seams_c`` and ``seams_kinds`` and fails if a name has no
page. ``seams_support`` is the reference-counted handle box and is
excluded. The assemble step copies the FORD tree to
``build/html/api/generated``. Open ``build/html/index.html``.

Run the package
---------------

.. code-block:: bash

   export FPM_LDFLAGS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
   export LD_LIBRARY_PATH="$PREFIX/lib"
   export OMP_NUM_THREADS=1
   fpm test
   fpm run --example cubic
   fpm run --example minimal -- input/traj/genice_sI.lammpstrj
   meson setup build/meson -Dseams_libdir="$PREFIX/lib"
   meson test -C build/meson --print-errorlogs

``$PREFIX`` is a seams-core 2.14.0 install. CI builds that tag. A
local build tree works the same way: ``libseams.so`` is in
``bbdir/src`` and ``libseams_lang.so`` is in ``bbdir/bindings``.

Releases follow seams-core. The order is in the README. Fragments in
``changelog.d/`` are the unreleased notes.
