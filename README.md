# WordPress Plugin Boilerplate

A modern, comprehensive WordPress plugin boilerplate with built-in support for multiple deployment strategies, coding standards, testing, and development tools.

## Features

- 🚀 **Quick Setup** - Get a working plugin in under 5 minutes
- 📦 **Deployment** - GitHub release and WordPress.org SVN on tag
- 🔧 **Modern Development Tools** - wp-env, PHPCS, PHPUnit
- ✅ **WordPress Coding Standards** - Pre-configured and enforced
- 🏗️ **Build System** - Automated release builds
- 🧪 **Testing Ready** - PHPUnit configuration included
- 📝 **Well Documented** - Clear instructions and examples

## Quick Start

### Method 1: Use as GitHub Template

1. Click the "Use this template" button on GitHub
2. Clone your new repository
3. Run the setup script:
   ```bash
   ./bin/setup-plugin.sh "Your Plugin Name" "your-plugin-slug"
   ```
4. Install dependencies:
   ```bash
   composer install
   npm install
   ```
5. Start development:
   ```bash
   npm run start
   ```

### Method 2: Clone and Configure

```bash
# Clone the repository
git clone https://github.com/alanef/wordpress-plugin-boilerplate.git my-plugin
cd my-plugin

# Remove git history
rm -rf .git

# Run setup
./bin/setup-plugin.sh "My Plugin" "my-plugin"

# Install dependencies
composer install
npm install

# Start development environment
npm run start
```

## Project Structure

```
wordpress-plugin-boilerplate/
├── .github/                      # GitHub Actions workflows
│   ├── workflows/
│   │   ├── checks.yml            # PHPCS, version consistency, Plugin Check, PHPUnit
│   │   └── release.yml           # GitHub release + WordPress.org SVN deploy on tag
├── plugin-name/                   # Main plugin directory
│   ├── plugin-name.php            # Main plugin file
│   ├── readme.txt                 # WordPress.org readme
│   ├── uninstall.php              # Cleanup on uninstall
│   └── .distignore                # Build exclusions
├── tests/                         # PHPUnit tests (run inside wp-env)
├── tooling/                       # Canonical tooling templates rolled out to every plugin
├── bin/setup-plugin.sh            # Create a new plugin from the boilerplate
├── bin/sync-tooling.sh            # Roll the tooling out to a plugin repository
├── .wp-env.json                   # Local development config
├── phpunit.xml.dist, run-tests.sh
├── composer.json                  # PHP dev dependencies and scripts
├── package.json                   # wp-env and test scripts
└── phpcs.xml, phpcs_sec.xml       # Coding standards config
```

## Available Commands

The tooling is identical in every Fullworks free plugin repository and documented in full
in [CLAUDE.md](CLAUDE.md) (the master tooling guide).

```bash
composer install && npm install    # dev tools
composer run check                 # PHPCompatibility (Requires PHP .. 8.4) + WordPress security sniffs
npm run start | stop | destroy     # wp-env: dev site and tests site (admin / password)
npm test                           # PHPUnit inside the wp-env tests container
npm test -- --filter Name          # pass PHPUnit arguments through
composer run build                 # zipped/<plugin>-free.zip via wp dist-archive (.distignore applies)
composer run make-pot              # regenerate the .pot file
```

## CI and deployment

- `checks.yml` runs on push and pull request: PHPCS, version consistency, a dist-archive
  build, WordPress Plugin Check on the built zip, and the PHPUnit suite in wp-env.
- `release.yml` runs on a `vX.Y.Z` tag: re-runs the checks, creates the GitHub release with
  the versioned zip attached and deploys trunk + tag to WordPress.org SVN. Add the
  `SVN_USERNAME` and `SVN_PASSWORD` repository secrets to enable the deploy.

Release: update `CHANGELOG.md`, set the version in the plugin header, `readme.txt` Stable tag
and the version constant, commit, tag `vX.Y.Z`, push.

## Rolling the tooling out to other plugins

`tooling/` holds the templates and `bin/sync-tooling.sh <repo>` renders them into a plugin
repository (workflows, test runner, PHPUnit config, wp-env mappings, composer/npm scripts,
managed blocks in CLAUDE.md and README.md). Fix tooling here first, then sync each plugin.
See [CLAUDE.md](CLAUDE.md#rolling-out-a-tooling-change).

## Testing

```bash
npm test
```

`tests/bootstrap.php` loads the plugin into the WordPress core test library inside the wp-env
tests container. Add tests as `tests/test-*.php` or `tests/**/*Test.php`, extending
`WP_UnitTestCase`. `tests/test-sample.php` is an example.

## Coding Standards

`composer run check` runs PHPCompatibilityWP for every PHP version from the plugin's
`Requires PHP` up to 8.4, then the WordPress security sniffs in `phpcs_sec.xml`.
`phpcs.xml` (WordPress-Extra) is available for local use: `vendor/bin/phpcs --standard=phpcs.xml <plugin-dir>`.

## Configuration Files

- `.wp-env.json` - local WordPress environments (dev and tests ports, PHP version, plugin and
  test mappings). Local-only tweaks go in `.wp-env.override.json` (see the `.example`).
- `phpcs.xml`, `phpcs_sec.xml` - coding standards.
- `<plugin-dir>/.distignore` - files excluded from the distribution zip.
- `.tooling.json` (optional) - pins values for `bin/sync-tooling.sh` (SVN slug, ports).

## Requirements

- **PHP**: 7.4 or higher
- **WordPress**: 5.8 or higher
- **Node.js**: 18.0.0 or higher
- **npm**: 8.0.0 or higher
- **Composer**: 2.0 or higher

## Troubleshooting

### Port Conflicts

If a port is in use, modify `.wp-env.json` (and `.tooling.json` so syncs keep it):

```json
{
    "port": 8790,
    "testsPort": 8791
}
```

### Permission Issues

Make scripts executable:

```bash
chmod +x bin/*.sh
```

### Build Failures

Ensure all dependencies are installed:

```bash
composer install --no-dev
npm install
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Resources

- [WordPress Plugin Handbook](https://developer.wordpress.org/plugins/)
- [WordPress Coding Standards](https://developer.wordpress.org/coding-standards/wordpress-coding-standards/)
- [wp-env Documentation](https://developer.wordpress.org/block-editor/reference-guides/packages/packages-env/)
- [Freemius SDK](https://docs.freemius.com/)
- [GitHub Actions for WordPress](https://github.com/marketplace?type=actions&query=wordpress)

## AI Development

For AI-assisted plugin development, see [AI-WORDPRESS-PLUGIN-PROMPT.md](AI-WORDPRESS-PLUGIN-PROMPT.md) which contains comprehensive instructions for building WordPress.org compliant plugins that will pass review on first submission.

**Important**: The AI prompt now includes mandatory quality checks that must pass before any task is considered complete.

## Plugin Renaming

Need to rename the plugin manually or fix naming issues? See the comprehensive [RENAMING-GUIDE.md](RENAMING-GUIDE.md) which covers:
- All files and locations that need updating
- Common naming mistakes to avoid
- Verification checklist
- Quick reference for naming patterns

## License

This boilerplate is licensed under GPL v2 or later. Your plugin can use any GPL-compatible license.

## Credits

Created with best practices from the WordPress community and modern development workflows.

---

**Note**: Remember to update this README with your actual plugin information after running the setup script!

<!-- tooling:start (managed by wordpress-plugin-boilerplate/tooling - do not edit by hand) -->
## Development

This repository uses the standard Fullworks free-plugin tooling, documented in
[wordpress-plugin-boilerplate](https://github.com/alanef/wordpress-plugin-boilerplate/blob/main/CLAUDE.md).

[![Plugin Check](https://github.com/alanef/wordpress-plugin-boilerplate/actions/workflows/checks.yml/badge.svg)](https://github.com/alanef/wordpress-plugin-boilerplate/actions/workflows/checks.yml)

```
wordpress-plugin-boilerplate/                     # repository root: development tooling
├── .github/workflows/             # checks.yml on push/PR, release.yml on tag
├── tests/                         # PHPUnit suite, run inside wp-env
├── .wp-env.json                   # dev :8780, tests :8781
├── composer.json                  # dev dependencies and quality scripts
├── package.json                   # wp-env and test scripts
├── phpunit.xml.dist / run-tests.sh
└── plugin-name/                # the plugin (shipped as-is via .distignore)
```

```bash
composer install && npm install        # dev tools
npm run start                          # http://localhost:8780  (admin / password)
composer run check                     # PHPCompatibility + security sniffs
npm test                               # PHPUnit in the wp-env tests container
composer run build                     # zipped/plugin-name-free.zip
```

Releases: set the version in the plugin header and `readme.txt`, update `CHANGELOG.md`,
tag `vX.Y.Z` and push. CI builds the zip, creates the GitHub release and deploys to
WordPress.org.
<!-- tooling:end -->
