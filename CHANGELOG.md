# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-10-09

### Added

- GitHub-only plugins (no `Type:` in readme.txt) now update themselves from their GitHub releases through the normal WordPress update screens, so sites no longer need manual zip uploads or a Git Updater plugin (which cannot work here: it expects assets named after the repository, not the plugin folder). The sync renders a per-plugin `includes/class-github-updater.php`, sets the `Update URI` header from the git remote, adds a guarded `require` to the main file and excludes Plugin Check's `plugin_updater` check; adding a `Type:` removes all of it, because WordPress.org forbids off-site updates. It reads the latest release from the github.com redirect (no API, token or rate limit), caches it (6 h, 1 h after a failure, 5 s timeout) so an unreachable GitHub never slows the admin, keeps an update in the folder the plugin is installed in, and ships with a generated PHPUnit test. A synced copy was chosen over a Composer library because a shared class loaded by several plugins resolves to whichever loads first.
- `Build Release` now reads a `Type:` header from the plugin's `readme.txt` to decide where a release goes, so the same workflow serves every repo and a GitHub-only plugin no longer needs a hand-edited, divergent `release.yml`. No header means GitHub only, `free` adds WordPress.org, `freemium` adds WordPress.org and Freemius, `premium` is GitHub and Freemius. WordPress.org accepts non-standard readme headers, so the tag ships harmlessly. An unrecognised value fails the release rather than falling back to the default: a typo that silently skips WordPress.org is only noticed when someone asks why an update never landed. Resolved targets are printed in the job log and the run summary.
- `run-tests.sh` now runs a plugin's pure unit suite on the host, with no WordPress loaded, when `tests/phpunit-unit.xml.dist` exists. Such a suite stubs `wp_remote_post()` and friends behind `function_exists()`; run under the wp-env bootstrap the real WordPress functions already exist, so the stubs never install and the tests issue live HTTP. They then fail as though the product were broken. Pair it with `"phpunit_exclude": ["unit"]` in `.tooling.json` so the wp-env suite does not run them a second time.
- `wp-env start` in the PHPUnit job now retries up to three times, stopping between attempts so a half-started environment does not poison the next try, and fails loudly with an annotation if all three fail. It flakes intermittently on container and network timing, and a flake previously read as a test failure. The fix existed in the boilerplate's own CI but had never reached the template, so no plugin had it.
- Plugin Check now runs on `develop` as well as the repository's default branch. Work lands on `develop`, so a check wired only to the default branch reported nothing until merge time, which is exactly when it is least useful. The generated workflow takes a `__BRANCH_LIST__` block instead of a single `__BRANCH__`, deduped so a repo whose default already is `develop` gets one entry rather than two.

### Fixed

- `bin/setup-plugin.sh` no longer turns the main file's `Plugin Name:` header into `<name>: <name>`. Its placeholder replacement also matched the header key, so every new plugin started with a broken header and the tooling sync it runs could not find the plugin ("Could not determine plugin directory").
- The Plugin Check and Build Release jobs no longer fail with `wp: command not found` when setup-php intermittently reports "Could not setup wp-cli" (it carries on regardless, so the job only died later at the dist-archive step). A new `Ensure WP-CLI` step downloads the phar directly, with retries, whenever setup-php did not provide it. It failed 3 of 7 runs while releasing fullworks-gravity-to-listmonk 1.0.0, each needing a manual re-run.
- Plugin Check now lists the built zip's contents and deletes any `.wp-env.override.json` before starting wp-env. A committed override with a `plugins` entry mounts the source directory over the build mapping, so Plugin Check inspected the repository (reporting `.distignore` as a hidden file) instead of the zip.
- `bin/sync-tooling.sh` no longer resets a plugin repo's `package.json` version or downgrades a dev dependency the repo has already moved past (e.g. `@wordpress/env` 11).

## [1.0.0]

- Baseline. Earlier history is in `plugin-name/readme.txt`.
