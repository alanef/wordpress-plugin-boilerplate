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
├── .github/workflows/release.yml      # tag vX.Y.Z: checks, GitHub release + zip, deploys per readme Type:
├── tests/bootstrap.php                # loads the plugin into the WordPress core test library
├── tests/test-*.php | **/*Test.php    # PHPUnit tests (WP_UnitTestCase available)
├── phpunit.xml.dist                   # PHPUnit config (root)
├── run-tests.sh                       # runs PHPUnit inside the wp-env tests container
├── .wp-env.json                       # dev site :PORT, tests site :TESTS_PORT, maps tests/ vendor/ phpunit.xml.dist
├── .wp-env.override.json.example      # local-only overrides (PHP version, sibling plugins) - copy to .wp-env.override.json
├── composer.json                      # dev deps (phpcs, wpcs, phpcompatibility, phpunit, polyfills) + scripts
├── package.json                       # @wordpress/env + npm scripts
├── phpcs.xml / phpcs_sec.xml          # WordPress-Extra (local) / security sniffs (CI)
├── scripts/release/*.sh               # /tk-release hooks: bump-version, check-dependencies, run-tests-and-mark
├── .claude/commands/deploy-live.md    # /tk-deploy live for this plugin's release pipeline
├── .sdlc/releases/X.Y.Z/              # release evidence (notes, TESTS_PASSED, DEPENDENCY_AUDIT)
├── CLAUDE.md, README.md
└── <plugin-dir>/                      # the plugin exactly as shipped (wp dist-archive + .distignore)
    ├── <plugin-dir>.php               # main file: Version, Requires PHP, Requires at least, Text Domain
    ├── readme.txt                     # Stable tag must equal the header Version
    ├── changelog.txt                  # THE changelog (wp.org style), ships in the zip
    ├── .distignore
    └── composer.json (optional)       # production dependencies -> <plugin-dir>/vendor or includes/vendor
                                       #   (no composer.lock: plugin deps resolve fresh on every build)
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
| `<plugin>/changelog.txt` | generated / merged | created if missing (from readme.txt `== Changelog ==` version entries, else a `* Baseline.` entry); a root `CHANGELOG.md` is merged in (`## [x.y.z]` -> `= x.y.z =`, `### Fixed` + `- item` -> `* Fixed: item`, Unreleased kept, baseline placeholders dropped) and deleted. Idempotent |
| `scripts/release/{bump-version,check-dependencies,run-tests-and-mark}.sh` | `tooling/scripts/release/` | overwritten, executable (release-only: an unmanaged `run-tests-and-mark.sh` is kept) |
| `.claude/commands/deploy-live.md` | `tooling/claude/commands/deploy-live.<pipeline>.md` | overwritten; template chosen from the pipeline (below) |
| `<plugin>/includes/class-github-updater.php`, `tests/test-github-updater.php`, `Update URI:` header, guarded `require` block at the end of the main file | `tooling/github-updater.php`, `tooling/tests/` | GitHub-only plugins (no `Type:` in readme.txt): overwritten, header set from the git remote. Any `Type:`: all removed |

Per-repo values are detected (plugin dir, main file, default branch, `*_VERSION` constant,
existing wp-env ports) and can be pinned in `.tooling.json` at the target root:

```json
{"svn_slug": "wp-org-slug", "port": 8710, "tests_port": 8711, "php_version": "8.4",
 "phpunit_exclude": ["helper-script.php"], "tag_prefix": "v", "youtrack_project": "KEY"}
```

`tag_prefix` defaults to the style of the newest existing version tag (`v` if none).
`free_tag_prefix` (two-tag Freemius only) is the free repo's own tag style; it defaults to
`tag_prefix`. DEE tags `v6.7.2` in its dev repo but `6.7.2` in the free repo.
`youtrack_project` is only used when the repo has no `.env.youtrack`.
`changelog_url` names the plugin's KB changelog page; without it the deploy command finds the
`fullworksplugins.com/docs/...change-log...` link in `readme.txt`. A plugin with a KB page will
not tag without a `.env.wordpress` that sets `WP_POST_ID` and `CHANGELOG_FILE` unless the user
explicitly accepts a stale page, and the final report then says `CHANGELOG PAGE NOT UPDATED`.

## Release pipelines (`/tk-release`, `/tk-deploy live`)

`/tk-release X.Y.Z` runs the synced hooks: `bump-version.sh` sets header, version constant,
Stable tag, package.json (root and plugin dir, where it has a version), `.pot` Project-Id-Version and renames
`= Unreleased =` in changelog.txt, then reads every one back and fails on a mismatch (refuses
`-` prerelease versions; X.Y only where the plugin already uses it); `check-dependencies.sh`
resolves the plugin's composer deps fresh (a committed lock is audited as-is; an untracked
local one is set aside, since it may be stale) and blocks on any advisory, warning only for root
composer and npm; `run-tests-and-mark.sh` runs checks.yml's gates locally (PHPUnit needs
wp-env running, or `--no-wp-env` records it as skipped) and writes `TESTS_PASSED.md` with the
commit. Run it after the release commit. `/tk-deploy live` then follows the rendered
`deploy-live.md`, chosen per plugin:

| Pipeline | When | Template |
|---|---|---|
| GitHub only | no `Type:` header | `deploy-live.github.md`: tag, release.yml, confirm the `<plugin-dir>-X.Y.Z.zip` asset, self-updater picks it up |
| single tag | `Type: free`, `freemium`, `premium` | `deploy-live.free.md`: tag, release.yml, SVN tag check (wp.org types), manual wp.org confirmation / Freemius |
| two-tag Freemius | `"pipeline": "freemius-two-tag"` + `free_repo`, `freemius_id`, `changelog_url` | `deploy-live.freemius-two-tag.md`: QPP's flow, tag here then the free repo |
| own site | `"pipeline": "own-site"` + `hosting` | `deploy-live.own-site.md`: build the zip and hand off to HOSTING DevOps; never deploys |

Every template checks the same preconditions (`_preconditions.md`: level with origin, clean,
`bump-version.sh --check`, tag absent both styles, evidence present and fresh, checks.yml
green on HEAD), asks for explicit confirmation before tagging, stops at the first failure,
never retries a tag push, and ends with the KB changelog (`update-changelog.sh`, only with
`.env.wordpress`, `_changelog.md`) and YouTrack (`_youtrack.md`).

**Release-only sync.** The `freemius-two-tag` and `own-site` pipelines (or `--release-only`)
sync only `<plugin>/changelog.txt`, `scripts/release/bump-version.sh`, `check-dependencies.sh`
and `.claude/commands/deploy-live.md`. Their workflows, composer/test setup and docs differ on
purpose (QPP's release.yml deploys to Freemius and syncs the free repo), so nothing else is
touched. A `run-tests-and-mark.sh` without the `Managed by wordpress-plugin-boilerplate/tooling`
marker is kept, since those plugins' test gates are their own; if there is none, the generic one
is rendered with a warning to check its commands against the plugin's composer scripts.
A Freemius plugin (any `fs_dynamic_init(` in the plugin dir) with no `pipeline` in
`.tooling.json` is refused outright: pin `freemius-two-tag` or `single-tag` first, so a
missing pin can never overwrite its own workflows with a full sync.

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
  creates the GitHub release with `zipped/<plugin-dir>-X.Y.Z.zip` attached, then deploys to
  the targets the plugin asks for.

  **Deploy targets come from the plugin, not the workflow.** `Build Release` reads a `Type:`
  header from `<plugin-dir>/readme.txt` so one CI serves every repo and no plugin needs a
  hand-edited workflow: no header means GitHub only, `free` adds WordPress.org, `freemium`
  adds WordPress.org and Freemius, `premium` is GitHub and Freemius. WordPress.org tolerates
  non-standard readme headers, so `Type:` is safe to ship. An unrecognised value fails the
  release rather than falling back, since a typo that silently skips WordPress.org is not
  discovered until someone asks why the update never landed. The resolved targets are printed
  in the job log and the run summary.

  WordPress.org deploys need repository secrets `SVN_USERNAME` and `SVN_PASSWORD`; the step
  fails loudly if they are missing or the SVN tag already exists.

  **Listing assets** (banners, icon, screenshots, `blueprints/blueprint.json`) live in
  `.wordpress-org/` at project root, never inside the plugin directory, so they cannot reach
  the zip. The WordPress.org deploy rsyncs that folder (minus its `README.md`) to SVN
  `assets/` in the same commit as `trunk` and the tag, so a listing change ships with the
  next release.

Known traps already handled in the templates (do not regress them):

- WP-CLI's bundled Composer 2.2 rejects the runner token that setup-php persists in
  auth.json, and anonymous installs hit GitHub's rate limit. The dist-archive step strips
  the persisted auth and passes the token back as http-basic, pinned to v3.1.0.
- `softprops/action-gh-release` does not support `path#name`; the zip is copied to its
  versioned name before upload.
- Plugin Check runs on the *built* zip so `.distignore` mistakes surface in CI.
- Jobs run on `ubuntu-24.04`, not `ubuntu-latest`, so a GitHub image change (Ubuntu 26 from
  19 October 2026) cannot silently change every plugin's CI at once. Moving image is a
  deliberate tooling change here, rolled out like any other.
- Actions are on their Node 24 majors (`checkout@v7`, `cache@v6`, `setup-node@v7`,
  `action-gh-release@v3`; `setup-php@v2` floats to a Node 24 build). A Node 20
  deprecation annotation that remains comes from inside `wordpress/plugin-check-action`,
  which is a composite action outside our control.

## GitHub self-update (GitHub-only plugins)

A plugin with no `Type:` header in `readme.txt` is released only on GitHub, so it updates
itself from its releases through the normal WordPress update screens. The sync renders a
per-plugin copy of `tooling/github-updater.php` (namespace `<PREFIX>\Updater`, from the
`*_VERSION` constant, so copies in different plugins never collide), sets
`Update URI: https://github.com/<owner>/<repo>` from the git remote, appends a guarded
`require` to the main file, and excludes Plugin Check's `plugin_updater` check in
checks.yml. Setting `Type: free|freemium|premium` and re-syncing removes all of it:
WordPress.org forbids off-site updates and Freemius updates premium plugins itself.

How it works: core (5.8+) skips WordPress.org for a plugin whose `Update URI` host is
`github.com` and fires `update_plugins_github.com` instead. The updater reads the
`Location` of `github.com/<repo>/releases/latest` (HEAD, no redirects, 5 s timeout; no
GitHub API, token or rate limit), builds the package URL
`releases/download/<tag>/<plugin-dir>-<version>.zip` (what release.yml always attaches),
and caches the lookup in a site transient for 6 h, or 1 h after a failure. It also answers
"View details", installs into the folder the plugin already lives in (a `-main` source
install does not get a second copy), and "Check again" on Dashboard → Updates refreshes it.

Why a synced copy rather than a Composer library (like `free_plugin_lib`): a shared class
loaded by several plugins resolves to whichever plugin loads first, so one stale copy would
run the update channel for all of them; the sync is already the fix-once, roll-out-everywhere
path; and the sync can add or remove the updater per plugin from `Type:`.

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
(`1.4.0-alpha.1`); release.yml refuses to publish a version containing `-`.

Each plugin has exactly one changelog, `<plugin-dir>/changelog.txt`, in wp.org style: headings
`= X.Y.Z =`, work in progress under `= Unreleased =` at the top, typed bullets (`* Added:`,
`* Changed:`, `* Deprecated:`, `* Removed:`, `* Fixed:`, `* Security:`). It ships in the zip and
is what `update-changelog.sh` publishes to the KB. No root `CHANGELOG.md` in plugin repos;
`readme.txt`'s `== Changelog ==` may link to the KB page or repeat recent entries. This
repository's own `CHANGELOG.md` is the boilerplate project's history, not `plugin-name`'s.

## Release

A plugin: `/tk-release X.Y.Z`, commit, `/tk-deploy live` (see Release pipelines). This
repository itself: move `## [Unreleased]` in `CHANGELOG.md` to the version, commit, tag. The
tag fires this repo's own release.yml.

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

Before syncing a plugin that is on WordPress.org, check its `readme.txt` has `Type: free` (or
`freemium`). Without it the sync treats the plugin as GitHub-only: it adds the self-updater,
which WordPress.org forbids, and renders the GitHub-only deploy command. Several older wp.org
plugins predate the header.

## Creating a new plugin from this boilerplate

`./bin/setup-plugin.sh "Plugin Name" "plugin-slug"` renames everything and renders the standard
tooling for the new slug. Then `composer install && npm install && npm run start`.

## Plugin code guidelines

Read `AI-WORDPRESS-PLUGIN-PROMPT.md` before writing plugin code: sanitise every input, escape
every output at the last moment, nonces and capability checks on every form and AJAX handler,
unique 4+ character prefixes for functions, constants, classes and namespaces, WordPress
functions over PHP natives (`wp_remote_get` not curl), scripts and styles enqueued, and no
"WordPress" in plugin names. Composer classmap autoloading for classes.
