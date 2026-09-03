# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `composer run build` now strips `.distignore` from the zip. dist-archive-command v3.1.0 (pinned because newer releases require an unreleased WP-CLI) ships the file despite it listing itself, which Plugin Check flags as a hidden file.
- `bin/sync-tooling.sh` no longer resets a plugin repo's `package.json` version or downgrades a dev dependency the repo has already moved past (e.g. `@wordpress/env` 11).

## [1.0.0]

- Baseline. Earlier history is in `plugin-name/readme.txt`.
