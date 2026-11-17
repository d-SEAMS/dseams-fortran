dseams
======

``dseams`` is the Fortran package for the
`d-SEAMS <https://docs.dseams.info/>`_ engine. A program uses the ``seams`` module. Coordinates are ``real(seams_real)`` with shape
``(3, n)``. The package links an installed libseams 2.14.0 and does not
build one.

.. toctree::
   :maxdepth: 2
   :caption: Getting started

   getting-started/index

.. toctree::
   :maxdepth: 2
   :caption: User guide

   user-guide/index

.. toctree::
   :maxdepth: 2
   :caption: API reference

   api/index

.. toctree::
   :maxdepth: 2
   :caption: Development

   development/index

The engine manual, including the C API and the science of each
analysis, is `docs.dseams.info <https://docs.dseams.info/>`_. Its
Fortran page is
`the stable Fortran guide <https://docs.dseams.info/stable/fortran.html>`_.
The generated symbol pages are the `FORD reference <api/generated/index.html>`_.

The recording runs the ice Ih census from Fortran:

.. include:: _includes/fortran.rst

Recordings of the same analyses are on the
`d-SEAMS Odysee channel <https://odysee.com/@d-SEAMS:0b23224c14d44b2a90deee60b7cc8c54e2331e9d>`_.
