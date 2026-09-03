# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Plugin Check now lists the built zip's contents and deletes any `.wp-env.override.json` before starting wp-env. A committed override with a `plugins` entry mounts the source directory over the build mapping, so Plugin Check inspected the repository (reporting `.distignore` as a hidden file) instead of the zip.
- `bin/sync-tooling.sh` no longer resets a plugin repo's `package.json` version or downgrades a dev dependency the repo has already moved past (e.g. `@wordpress/env` 11).

## [1.0.0]

- Baseline. Earlier history is in `plugin-name/readme.txt`.
