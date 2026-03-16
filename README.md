# WordPress Plugin Boilerplate

A modern, comprehensive WordPress plugin boilerplate with built-in support for multiple deployment strategies, coding standards, testing, and development tools.

## Features

- 🚀 **Quick Setup** - Get a working plugin in under 5 minutes
- 📦 **Multiple Deployment Options** - GitHub, WordPress.org SVN, Freemius
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
   npm run env:start
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
npm run env:start
```

## Project Structure

```
wordpress-plugin-boilerplate/
├── .github/                      # GitHub Actions workflows
│   ├── workflows/
│   │   ├── checks.yml            # Quality checks (PHPCS, compatibility, security)
│   │   ├── release.yml           # Automated release builds with quality checks
│   │   └── *.yml.example          # Optional deployment workflows
│   └── ISSUE_TEMPLATE/            # Issue templates
├── plugin-name/                   # Main plugin directory
│   ├── plugin-name.php            # Main plugin file
│   ├── readme.txt                 # WordPress.org readme
│   ├── uninstall.php              # Cleanup on uninstall
│   └── .distignore                # Build exclusions
├── tests/                         # PHPUnit tests
├── bin/                           # Build and setup scripts
├── .wp-env.json                   # Local development config
├── composer.json                  # PHP dependencies
├── package.json                   # Node dependencies
└── phpcs.xml.dist                 # Coding standards config
```

## Available Commands

### Development

```bash
# Start local WordPress environment
npm run env:start

# Stop environment
npm run env:stop

# Reset environment
npm run env:reset

# Access WP-CLI
npm run env:cli
```

### Code Quality

```bash
# Check PHP coding standards
npm run lint:php

# Fix PHP coding standards
npm run lint:php:fix

# Run PHPUnit tests
npm run test
```

### Build & Release

```bash
# Build release package (includes plugin dependencies)
npm run build

# Setup new plugin from boilerplate
npm run setup
```

### Plugin Dependencies & Autoloading

The plugin has its own `composer.json` with classmap autoloading:

```bash
# Install plugin dependencies and generate autoloader
npm run plugin:install

# Update plugin dependencies
npm run plugin:update

# Regenerate autoloader only (after adding new classes)
npm run plugin:dump
```

**Note:** The plugin's `vendor/` directory is included in builds. Classes are autoloaded via `vendor/autoload.php`.

## Deployment Strategies

### 1. GitHub Only (Default)

The simplest deployment strategy. Push tags to trigger automated GitHub releases.

```bash
git tag v1.0.0
git push origin v1.0.0
```

The `release.yml` workflow will run quality checks and automatically create a release with the plugin ZIP file.

### 2. WordPress.org SVN Repository

For free plugins distributed via WordPress.org:

1. Rename `.github/workflows/deploy-wordpress-svn.yml.example` to `.github/workflows/deploy-wordpress-svn.yml`
2. Add secrets to your GitHub repository:
   - `SVN_USERNAME` - Your WordPress.org username
   - `SVN_PASSWORD` - Your WordPress.org password
   - `SLUG` - Your plugin slug on WordPress.org

### 3. Freemius Integration

For premium or freemium plugins:

#### Premium Only
1. Rename `.github/workflows/deploy-freemius.yml.example` to `.github/workflows/deploy-freemius.yml`
2. Add Freemius secrets to GitHub:
   - `FREEMIUS_DEV_ID`
   - `FREEMIUS_PLUGIN_ID`
   - `FREEMIUS_PUBLIC_KEY`
   - `FREEMIUS_SECRET_KEY`

#### Freemium (Free + Premium)
1. Use both Freemius deployment and sync workflows
2. Rename `.github/workflows/sync-freemius-free.yml.example` to `.github/workflows/sync-freemius-free.yml`
3. This will sync the free version from Freemius to your public repository
4. For advanced automation setup, see [FREEMIUS-WORKFLOW-SETUP.md](FREEMIUS-WORKFLOW-SETUP.md)

## Development Workflow

### Initial Setup

The setup script handles most renaming automatically. For manual renaming or troubleshooting, see [RENAMING-GUIDE.md](RENAMING-GUIDE.md).

1. **Configure Plugin Header**: Edit `your-plugin/your-plugin.php` with your plugin information
2. **Update Metadata**: Modify `composer.json` and `package.json` with your details
3. **Set Text Domain**: Ensure your text domain is consistent throughout
4. **Update phpcs.xml.dist**: Set correct text domain and prefixes (minimum 4 characters)
5. **Run Quality Checks**: `npm run lint:php` must pass with 0 errors before committing

### Daily Development

1. **Start Environment**: `npm run env:start`
2. **Access WordPress**: http://localhost:8888 (admin/password)
3. **Make Changes**: Edit files in your plugin directory
4. **Test Changes**: Your plugin is auto-mounted in the local environment
5. **Run Tests**: `npm run test`
6. **Check Standards**: `npm run lint:php`

### Release Process

1. **Update Version**: In main plugin file and readme.txt
2. **Update Changelog**: In readme.txt
3. **Commit Changes**: `git commit -am "Version 1.0.1"`
4. **Tag Release**: `git tag v1.0.1`
5. **Push**: `git push && git push --tags`

## Testing

### PHPUnit Setup

Tests are configured to run in the wp-env environment:

```bash
# Run all tests
npm run test

# Run specific test suite
npm run test:unit
npm run test:integration
```

### Writing Tests

Place test files in:
- `tests/unit/` - Unit tests
- `tests/integration/` - Integration tests

Example test included in `tests/test-sample.php`

## Coding Standards

This boilerplate enforces WordPress Coding Standards:

```bash
# Check for violations
composer run lint

# Auto-fix violations
composer run lint:fix
```

Configuration in `phpcs.xml.dist` includes:
- WordPress-Core
- WordPress-Docs
- WordPress-Extra
- PHP Compatibility checks

## Configuration Files

### `.wp-env.json`
Local WordPress environment configuration. Modify to:
- Change PHP version
- Add additional plugins
- Configure WordPress settings

### `phpcs.xml.dist`
Coding standards configuration. Customize:
- Text domain
- Function prefixes
- Excluded files/directories

### `.distignore`
Files excluded from distribution builds. Add:
- Development files
- Build tools
- Documentation

## Requirements

- **PHP**: 7.4 or higher
- **WordPress**: 5.8 or higher
- **Node.js**: 18.0.0 or higher
- **npm**: 8.0.0 or higher
- **Composer**: 2.0 or higher

## Troubleshooting

### Port Conflicts

If port 8888 is in use, modify `.wp-env.json`:

```json
{
    "port": 8889
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