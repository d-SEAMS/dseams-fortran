# Changelog

All notable changes to the `dseams` fpm package are documented in this file.

The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The package version follows the seams-core release whose C API it binds.
Changes before 2.14.0 are in the seams-core changelog.

Unreleased notes live in [`changelog.d/`](changelog.d/) and are assembled
by [towncrier](https://towncrier.readthedocs.io/).

<!-- towncrier release notes start -->

## [2.14.1]

### Added

- The manual and the FORD reference are published at https://fortran.dseams.info/ from every push to `main`. The README links the site, the engine manual's Fortran page and the Fortran recording.

### Changed

- Pin CI builds, packaging metadata and documentation to seams-core v2.14.1.
- The documentation site moves to https://fortran.dseams.info/.
- The manual is organised as getting started, a user guide, a FORD API reference and development notes. Tutorial pages embed the matching d-SEAMS recordings, and the docs build fails when a public symbol has no generated page.

### Fixed

- Fix Flang 19 builds by declaring the internal handle type public only once.


## [2.14.0] - 2026-11-17

### Added

- The Fortran modules are the `dseams` fpm package at the root of d-SEAMS/dseams-fortran, split out of seams-core with history. Depend on it with `dseams = { git = "https://github.com/d-SEAMS/dseams-fortran", tag = "v2.14.0" }`.
- `fpm test lang_tasks` runs the language-front ice Ih census against `libseams_lang` and fails unless it prints the line every d-SEAMS language front prints.
- `fpm test` reads its trajectories from `input/` in this repository and no longer needs a seams-core checkout beside it.
- `meson.build` is a standalone project: a parent takes `dependency('dseams-fortran')` from it as a subproject, and `-Dseams_libdir` names libseams directories pkg-config cannot resolve.
