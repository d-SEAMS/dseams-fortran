Install
=======

The package links an installed ``libseams`` and does not build it.
From a `seams-core <https://github.com/d-SEAMS/seams-core>`_ checkout
at tag ``v2.14.0``:

.. code-block:: bash

   meson setup build --prefix="$PREFIX" --libdir=lib
   meson install -C build

That installs ``libseams.so``, ``libseams_lang.so`` and ``seams.pc``
under ``$PREFIX``. A meson install leaves the libraries libseams loads
beside it without a RUNPATH, so the loader also needs

.. code-block:: bash

   export LD_LIBRARY_PATH="$PREFIX/lib"

Use it from fpm
---------------

.. code-block:: toml

   [dependencies]
   dseams = { git = "https://github.com/d-SEAMS/dseams-fortran", tag = "v2.14.0" }

With ``seams.pc`` on ``PKG_CONFIG_PATH``:

.. code-block:: bash

   export FPM_LDFLAGS="$(pkg-config --libs-only-L seams) -Wl,-rpath,$(pkg-config --variable=libdir seams)"
   fpm build

Without pkg-config, name the directory that holds ``libseams.so``:

.. code-block:: bash

   export FPM_LDFLAGS="-L$SEAMS_LIB_DIR -Wl,-rpath,$SEAMS_LIB_DIR"

``examples/downstream`` is a separate fpm project with a path
dependency on this one. From that directory, ``fpm run`` prints

.. code-block:: text

   downstream: 8 of 8 waters are cubic ice

Other builds
------------

`Build with gfortran or meson <../user-guide/howto/build.html>`_
covers the single-file compile and a meson subproject. The next page
is a first program.
