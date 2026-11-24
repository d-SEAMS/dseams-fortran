---
project: d-SEAMS
summary: Fortran bindings for the d-SEAMS C API
project_github: https://github.com/d-SEAMS/dseams-fortran
project_website: https://docs.dseams.info/
author: Rohit Goswami
author_description: d-SEAMS developers
license: MIT
version: 2.14.2
src_dir: ./src
exclude_dir: ./example
             ./test
exclude: src/seams_support.f90
output_dir: ./build/ford
favicon: ./docs/_ford/favicon-32.png
preprocess: false
display: public
         protected
source: true
warn: true
graph: false
search: true
coloured_edges: true
md_extensions: markdown.extensions.toc
               markdown.extensions.smarty
---

This is the generated API reference for the Fortran package `dseams`.
`seams` is the module a program uses. `seams_c` is the `iso_c_binding`
image of `include/seams.h`. `seams_kinds` holds `seams_real` and
`seams_int`.

Coordinates are `real(seams_real)` with shape `(3, n)`. A missing
`stat` and a missing `errmsg` make a failed call stop with the library
message. The last finalizer of a handle destroys the C object.
Assignment shares that object.

Installation, tutorials and how-tos are the other parts of the dseams
manual. The engine manual is
[docs.dseams.info](https://docs.dseams.info/).
