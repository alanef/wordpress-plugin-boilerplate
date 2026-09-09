# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `wp-env start` in the PHPUnit job now retries up to three times, stopping between attempts so a half-started environment does not poison the next try, and fails loudly with an annotation if all three fail. It flakes intermittently on container and network timing, and a flake previously read as a test failure. The fix existed in the boilerplate's own CI but had never reached the template, so no plugin had it.
- Plugin Check now runs on `develop` as well as the repository's default branch. Work lands on `develop`, so a check wired only to the default branch reported nothing until merge time, which is exactly when it is least useful. The generated workflow takes a `__BRANCH_LIST__` block instead of a single `__BRANCH__`, deduped so a repo whose default already is `develop` gets one entry rather than two.

### Fixed

- Plugin Check now lists the built zip's contents and deletes any `.wp-env.override.json` before starting wp-env. A committed override with a `plugins` entry mounts the source directory over the build mapping, so Plugin Check inspected the repository (reporting `.distignore` as a hidden file) instead of the zip.
- `bin/sync-tooling.sh` no longer resets a plugin repo's `package.json` version or downgrades a dev dependency the repo has already moved past (e.g. `@wordpress/env` 11).

## [1.0.0]

- Baseline. Earlier history is in `plugin-name/readme.txt`.
