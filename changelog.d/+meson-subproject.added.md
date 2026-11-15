`meson.build` is a standalone project: a parent takes `dependency('dseams-fortran')` from it as a subproject, and `-Dseams_libdir` names libseams directories pkg-config cannot resolve.
