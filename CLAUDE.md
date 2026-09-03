# WordPress Plugin Boilerplate - MASTER tooling guide

This repository is the **single source of truth for the tooling used by every Fullworks free
plugin**. Each plugin repository's `CLAUDE.md` links here. Two rules follow from that:

1. **Fix tooling here first, then roll out.** Never patch a workflow, test runner or config
   in an individual plugin repository. Change `tooling/` here, commit, then run
   `bin/sync-tooling.sh` against each plugin repository and commit the result there.
2. **Managed files are overwritten on every sync.** Do not hand-edit them in a plugin repo.

## Standard repository layout

```
<repo>/                                # root = development tooling, never shipped
├── .github/workflows/checks.yml       # push / PR: PHPCS, version consistency, build, Plugin Check, PHPUnit
├── .github/workflows/release.yml      # tag vX.Y.Z: checks, GitHub release + zip, WordPress.org SVN deploy
├── tests/bootstrap.php                # loads the plugin into the WordPress core test library
├── tests/test-*.php | **/*Test.php    # PHPUnit tests (WP_UnitTestCase available)
├── phpunit.xml.dist                   # PHPUnit config (root)
├── run-tests.sh                       # runs PHPUnit inside the wp-env tests container
├── .wp-env.json                       # dev site :PORT, tests site :TESTS_PORT, maps tests/ vendor/ phpunit.xml.dist
├── .wp-env.override.json.example      # local-only overrides (PHP version, sibling plugins) - copy to .wp-env.override.json
├── composer.json                      # dev deps (phpcs, wpcs, phpcompatibility, phpunit, polyfills) + scripts
├── package.json                       # @wordpress/env + npm scripts
├── phpcs.xml / phpcs_sec.xml          # WordPress-Extra (local) / security sniffs (CI)
├── CLAUDE.md, README.md, CHANGELOG.md
└── <plugin-dir>/                      # the plugin exactly as shipped (wp dist-archive + .distignore)
    ├── <plugin-dir>.php               # main file: Version, Requires PHP, Requires at least, Text Domain
    ├── readme.txt                     # Stable tag must equal the header Version
    ├── .distignore
    └── composer.json (optional)       # production dependencies -> <plugin-dir>/vendor or includes/vendor
```

## Managed files (rendered from `tooling/`)

| Target | Source | Sync behaviour |
|---|---|---|
| `.github/workflows/checks.yml`, `release.yml` | `tooling/workflows/` | overwritten; legacy `php.yml`, `plugincheck.yml`, `test-svn.yml`, `*.yml.example` removed |
| `run-tests.sh`, `phpunit.xml.dist` | `tooling/` | overwritten (`tests/phpunit.xml.dist` removed) |
| `tests/bootstrap.php` | `tooling/tests/` | overwritten unless it is a custom bootstrap (then kept and reported) |
| `tests/test-plugin-load.php` | `tooling/tests/` | added only when the repo has no tests |
| `composer.json`, `package.json` | `tooling/` | regenerated; extra dev packages and non-legacy extra scripts are kept |
| `.wp-env.json` | merged | ports, plugins and config kept; `phpVersion` set to 8.4; test mappings added; sibling `../` plugins moved to the override example |
| `<plugin>/.distignore`, `.gitignore` | union | canonical lines plus repo-specific extras |
| `phpcs.xml`, `phpcs_sec.xml` | `tooling/` | added if missing (`phpcs.xml.dist` renamed) |
| `CLAUDE.md`, `README.md` | `tooling/*.block` | block between `<!-- tooling:start -->` / `<!-- tooling:end -->` replaced; rest untouched |
| `CHANGELOG.md` | generated | baseline created if missing |

Per-repo values are detected (plugin dir, main file, default branch, `*_VERSION` constant,
existing wp-env ports) and can be pinned in `.tooling.json` at the target root:

```json
{"svn_slug": "wp-org-slug", "port": 8710, "tests_port": 8711, "php_version": "8.4",
 "phpunit_exclude": ["helper-script.php"]}
```

## Commands (identical in every plugin repository)

```bash
composer install && npm install    # dev tools
composer run check                 # PHPCompatibility for every PHP version from Requires PHP up to 8.4, then security sniffs
composer run phpcs                 # security sniffs only
npm run start | stop | destroy     # wp-env
npm test                           # PHPUnit in the wp-env tests container (starts wp-env if needed)
npm test -- --filter Name          # PHPUnit arguments pass through
composer run build                 # zipped/<plugin-dir>-free.zip via wp dist-archive (respects .distignore)
composer run make-pot              # regenerate languages/<text-domain>.pot
```

`wp dist-archive` needs `wp package install wp-cli/dist-archive-command:v3.1.0` once locally.

## CI

**checks.yml** (push and PR on the default branch, also called by release.yml)

- `checks` job: PHP from `Requires PHP`; `composer validate --strict`; `composer run check`;
  version consistency (header `Version:` = `readme.txt` `Stable tag:` = `*_VERSION` constant if
  the plugin has one); build the zip; `wordpress/plugin-check-action@v1` on the unzipped build.
- `tests` job: composer + plugin production deps + `npm ci`, `npx wp-env start`, `npm test`.

**release.yml** (tags `vX.Y.Z` or `X.Y.Z`)

- Re-runs checks, builds, verifies the tag equals the plugin version and is not a prerelease,
  creates the GitHub release with `zipped/<plugin-dir>-X.Y.Z.zip` attached, then deploys trunk
  and `tags/X.Y.Z` to WordPress.org SVN. Needs repository secrets `SVN_USERNAME` and
  `SVN_PASSWORD`; the step fails loudly if they are missing or the SVN tag already exists.

Known traps already handled in the templates (do not regress them):

- WP-CLI's bundled Composer 2.2 rejects the runner token that setup-php persists in
  auth.json, and anonymous installs hit GitHub's rate limit. The dist-archive step strips
  the persisted auth and passes the token back as http-basic, pinned to v3.1.0.
- `softprops/action-gh-release` does not support `path#name`; the zip is copied to its
  versioned name before upload.
- Plugin Check runs on the *built* zip so `.distignore` mistakes surface in CI.

## Tests

`tests/bootstrap.php` loads the plugin on `muplugins_loaded`, fires its activation hook,
disables Action Scheduler's async runner, and sets a valid `wp_mail_from` (wp-env's tests site
is `localhost`, which PHPMailer rejects). Tests extend `WP_UnitTestCase`; mock HTTP with the
`pre_http_request` filter so the suite never touches the network. The WordPress test installer
resets core tables only, so clear plugin tables in `set_up` if tests depend on them.

Either naming convention is picked up: `tests/test-foo.php` or `tests/**/FooTest.php`.

## Versioning and changelog

Version lives in the plugin header, `readme.txt` Stable tag and the `*_VERSION` constant (if
present); CI fails when they disagree. During development carry a prerelease suffix
(`1.4.0-alpha.1`); release.yml refuses to publish a version containing `-`. `CHANGELOG.md`
(Keep a Changelog) is the single changelog; `readme.txt` may link to it.

## Release

1. Move `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z] - YYYY-MM-DD`.
2. Set the version in every location, drop any prerelease suffix.
3. `composer run check && npm test`.
4. Commit, `git tag vX.Y.Z`, push branch and tag.

## Rolling out a tooling change

```bash
# 1. change tooling/ here, verify on this repo
composer run check && npm test
git commit -am "tooling: ..." && git push
# 2. roll out
for repo in ~/projects/github.com/alanef/<plugin-repo> ...; do
  bin/sync-tooling.sh "$repo" && (cd "$repo" && composer update && npm install && composer run check && npm test)
done
# 3. commit and push each plugin repo, then watch its Plugin Check run
```

## Creating a new plugin from this boilerplate

`./bin/setup-plugin.sh "Plugin Name" "plugin-slug"` renames everything and renders the standard
tooling for the new slug. Then `composer install && npm install && npm run start`.

## Plugin code guidelines

Read `AI-WORDPRESS-PLUGIN-PROMPT.md` before writing plugin code: sanitise every input, escape
every output at the last moment, nonces and capability checks on every form and AJAX handler,
unique 4+ character prefixes for functions, constants, classes and namespaces, WordPress
functions over PHP natives (`wp_remote_get` not curl), scripts and styles enqueued, and no
"WordPress" in plugin names. Composer classmap autoloading for classes.
