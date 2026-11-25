# Changelog

All notable changes to the `dseams` fpm package are documented in this file.

The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The package version follows the seams-core release whose C API it binds.
Changes before 2.14.0 are in the seams-core changelog.

Unreleased notes live in [`changelog.d/`](changelog.d/) and are assembled
by [towncrier](https://towncrier.readthedocs.io/).

<!-- towncrier release notes start -->

## [2.14.2] - 2026-11-24

### Added

- A documented, tested release path: `cog.toml` and `towncrier.toml` drive a `cog bump`, `ci/version/files.txt` lists every copy of the version for `python3 -m cogapp` to rewrite, and `docs/orgmode/contributing/developer/release.org` gives the exact steps. A pull request that touches that machinery gets a `release-prepare` dry run.
- A standalone `feature_query` test exercises `has_chemfiles`, `has_readcon` and `probe_directory` on their own, outside `test_readers.f90`, so a future change that removes or breaks that Fortran-only API fails a build instead of only a reader test.
- `has_chemfiles` and `has_readcon` report whether the loaded libseams reads chemfiles trajectories and EON CON files. The readers test reads a CON, a PDB and a GRO when the matching query is true, and skips that read otherwise.
- `probe_directory(dir)` reports, in its allocatable `intent(out)` argument, the directory where `has_chemfiles` and `has_readcon` write their probe file.

### Changed

- The Fortran package builds and tests against seams-core 2.14.2.
- The chemfiles and readcon probes write their file in the first of `TMPDIR`, `TEMP`, `TMP` and the working directory that can be written. A missing or unwritable directory is skipped. When none can be written, the query is false and one diagnostic is printed.
- The once-guard behind `has_chemfiles`/`has_readcon` (`src/dseams_once.c`) now yields the CPU on each spin iteration instead of busy-looping, using C11 `thrd_yield` where `<threads.h>` is available and `sched_yield`/`SwitchToThread` otherwise. A thread that loses the race to run the probe no longer holds a core at full load for however long the one winner's probe takes.
- `has_chemfiles` and `has_readcon` share one in-process once-guard backed by a C-owned `<stdatomic.h>` `atomic_int` (`src/dseams_once.c`) and cache both answers. Every caller but the one that runs the sequential probe blocks until it finishes, so concurrent calls from different threads never race; the earlier cache was a plain module-level pair with no ordering guarantee between its two writes. Probe files are written in a private `0700` directory via a single `O_CREAT|O_EXCL|O_NOFOLLOW` descriptor, with no lock file and no create-close-reopen TOCTOU window; see `docs/orgmode/contributing/developer/faq.org` for the earlier approaches (`pthread_once`, then an exclusive `flock(2)`) this replaced and why.

### Removed

- The Meson options `with_chemfiles` and `with_readcon` are removed. They only defined `SEAMS_HAS_CHEMFILES` and `SEAMS_HAS_READCON`, which the Fortran sources do not read.

### Fixed

- The documented seams-core install command works on a fresh machine: `-Dwith_tests=false` keeps the engine test suite's libraries out of a library-only install.
- The trajectory tutorial is titled "Reading a trajectory" instead of sharing "Fortran" with the API page, the FORD interface sidebar links reach their sections, and the rings page says which indices are 1-based.
- The internal helpers behind the reader probe (`temp_directory`, `usable_env`, `normalize_dir`, `join_dir`, `env_string`, `probe_path`) and behind every text-returning call (`c_to_f`, `copy_key`) are now subroutines with an allocatable `intent(out)` argument, not functions returning `character(len=:), allocatable`. On this project's own CI compiler, gfortran 13.3.0, a `character(len=:), allocatable` function result is not safe to return to a caller running concurrently, on another thread, with any other call anywhere in the process that also returns such a result, including two unrelated calls to two different functions; the same computation expressed as a subroutine with an allocatable argument is not affected. This replaces an earlier fixed-length buffer workaround that only covered the probe's own lock-directory resolution, now removed along with the lock it resolved a directory for.
- `test_no_lock_symlink` no longer prints its "ok" line when the two preconditions for the symlink-planting check (a writable probe directory, `ln(1)`) are missing. Outside CI that is now a real skip (`STOP 77`, reported as SKIP by meson's test harness); under CI, where both preconditions are expected to hold, it is a hard failure instead, so a broken CI runner cannot pass without the check ever running.


## [2.14.1] - 2026-11-19

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
