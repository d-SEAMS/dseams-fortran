Build
=====

fpm
---

.. code-block:: bash

   export FPM_LDFLAGS="$(pkg-config --libs-only-L seams) -Wl,-rpath,$(pkg-config --variable=libdir seams)"
   export LD_LIBRARY_PATH="$(pkg-config --variable=libdir seams)"
   export OMP_NUM_THREADS=1
   fpm test
   fpm run --example cubic
   fpm run --example minimal -- input/traj/genice_sI.lammpstrj

``fpm test`` runs ``check_dseams`` (prints ``dseams fortran ok``),
``capi`` (prints ``fortran ok``), ``high`` (prints ``fortran high ok``)
and ``lang_tasks``. The ice Ih line from ``lang_tasks`` is on the
`language-task page <../../lang/task-fortran.html>`_.

``test/test_capi.f90`` calls every ``bind(C)`` procedure in ``seams_c``
on the 64-atom cell, then reads the fixtures under ``input/``. The
lines it prints before those reads are

.. code-block:: text

   fortran call cubic 64
   fortran call q6 0.628539361055
   fortran call cages 0 64 0 0
   fortran call sig 0 0
   fortran call cn 4.063492063492
   fortran call hbond 0
   fortran call sheet 128
   fortran call vert 6 0

It then reads ice Ih (128 atoms) and the sI cell (46 atoms) and prints
``fortran call read 128 46`` and ``fortran ok``.

Meson
-----

.. code-block:: bash

   meson setup build/meson
   meson test -C build/meson

When pkg-config cannot resolve ``seams`` and ``seams-lang``, name the
directories: ``meson setup build/meson -Dseams_libdir="$PREFIX/lib"``.
A parent project calls ``subproject('dseams-fortran')`` and then
``dependency('dseams-fortran')``. The meson test names are
``fortran_capi``, ``fortran_check``, ``fortran_high``,
``fortran_one_file``, ``fortran_lang_tasks``, ``fortran_cubic`` and
``fortran_minimal``.

One file
--------

``seams.f90`` at the repository root includes every module in
dependency order:

.. code-block:: bash

   gfortran -c seams.f90
   gfortran your_program.f90 seams.o -L"$SEAMS_LIB_DIR" -lseams -Wl,-rpath,"$SEAMS_LIB_DIR"

fpm and meson compile ``src/`` and must not also compile this file.
Linking ``example/cubic.f90`` this way prints the census on the
`API page <../../api/fortran.html>`_, starting ``version 2.14.2``.

Separate objects
----------------

``seams_c`` does not depend on the other modules. ``test/test_capi.f90``
uses only that module:

.. code-block:: bash

   mkdir -p build/fmod
   gfortran -Jbuild/fmod -c src/seams_kinds.f90 -o build/fmod/seams_kinds.o
   gfortran -Jbuild/fmod -Ibuild/fmod -c src/seams_c.f90 -o build/fmod/seams_c.o
   gfortran -Jbuild/fmod -Ibuild/fmod -c src/seams_support.f90 -o build/fmod/seams_support.o
   gfortran -Jbuild/fmod -Ibuild/fmod -c src/seams.f90 -o build/fmod/seams.o
   gfortran -Jbuild/fmod -Ibuild/fmod -c src/seams_methods.f90 -o build/fmod/seams_methods.o
   gfortran -Ibuild/fmod test/test_capi.f90 build/fmod/seams_c.o \
     -o build/test_seams -L"$SEAMS_LIB_DIR" -lseams -Wl,-rpath,"$SEAMS_LIB_DIR"
   build/test_seams "$PWD"

A program that uses ``seams`` links ``seams_kinds.o``,
``seams_c.o``, ``seams_support.o``, ``seams.o`` and
``seams_methods.o``, in that order. Set ``LD_LIBRARY_PATH`` to the
directory that holds ``libseams.so`` when that library does not find
``libyodaLib.so`` on its own.
