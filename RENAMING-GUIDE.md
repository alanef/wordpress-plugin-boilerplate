# Plugin Renaming Guide

This guide explains how to properly rename `plugin-name` to your actual plugin name in all the correct places. Following these steps ensures consistency and prevents issues.

## Prerequisites

Before starting, decide on:
- **Plugin Name**: Human-readable name (e.g., "My Awesome Plugin")
- **Plugin Slug**: Lowercase, hyphenated (e.g., "my-awesome-plugin")
- **Text Domain**: Usually same as slug (e.g., "my-awesome-plugin")
- **Prefix**: Unique prefix for functions/constants (e.g., "myawesomeplugin" or "map")
  - **IMPORTANT**: Minimum 4 characters required by WordPress.org

## Automated Method (Recommended)

Use the setup script to handle all replacements automatically:

```bash
./bin/setup-plugin.sh "My Awesome Plugin" "my-awesome-plugin"
```

This script will handle all the replacements listed below.

## Manual Renaming Checklist

If you need to rename manually or fix issues after automated setup, follow this checklist:

### 1. Directory and File Names

- [ ] Rename `plugin-name/` directory to `your-plugin-slug/`
- [ ] Rename `plugin-name/plugin-name.php` to `your-plugin-slug/your-plugin-slug.php`

```bash
mv plugin-name my-awesome-plugin
mv my-awesome-plugin/plugin-name.php my-awesome-plugin/my-awesome-plugin.php
```

### 2. Plugin Header (`your-plugin-slug.php`)

Edit the main plugin file header:

```php
/**
 * Plugin Name:       My Awesome Plugin
 * Plugin URI:        https://example.com/plugins/my-awesome-plugin/
 * Description:       Your plugin description
 * Version:           1.0.0
 * Requires at least: 5.8
 * Requires PHP:      7.4
 * Author:            Your Name
 * Author URI:        https://yoursite.com/
 * License:           GPL v2 or later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       my-awesome-plugin    // <-- MUST match slug
 * Domain Path:       /languages
 *
 * @package MyAwesomePlugin               // <-- CamelCase version
 */
```

### 3. Constants

Replace these constants throughout the plugin:

**Before:**
```php
define( 'PLUGIN_NAME_VERSION', '1.0.0' );
define( 'PLUGIN_NAME_PATH', plugin_dir_path( __FILE__ ) );
```

**After:**
```php
define( 'MY_AWESOME_PLUGIN_VERSION', '1.0.0' );  // All caps, underscores
define( 'MY_AWESOME_PLUGIN_PATH', plugin_dir_path( __FILE__ ) );
```

**Files to check:**
- Main plugin file
- Any included files that use constants

### 4. Function Prefixes

All global functions must have a unique prefix (minimum 4 characters):

**Before:**
```php
function plugin_name_init() {
function plugin_name_activate() {
```

**After:**
```php
function myawesomeplugin_init() {           // Or use: map_init()
function myawesomeplugin_activate() {
```

**Files to check:**
- Main plugin file
- `uninstall.php`
- Any included PHP files with global functions

### 5. Class Names and Namespaces

**Before:**
```php
namespace PluginName;
class Plugin_Name {
```

**After:**
```php
namespace MyAwesomePlugin;                   // CamelCase, no hyphens
class My_Awesome_Plugin {                   // CamelCase with underscores
```

### 6. Text Domain

Replace in ALL translation functions:

**Before:**
```php
__( 'Text', 'plugin-name' )
_e( 'Text', 'plugin-name' )
esc_html__( 'Text', 'plugin-name' )
```

**After:**
```php
__( 'Text', 'my-awesome-plugin' )
_e( 'Text', 'my-awesome-plugin' )
esc_html__( 'Text', 'my-awesome-plugin' )
```

**IMPORTANT**: Text domain must match your plugin slug exactly!

### 7. Configuration Files

#### `phpcs.xml.dist`

Update the text domain and prefixes:

```xml
<rule ref="WordPress.WP.I18n">
    <properties>
        <property name="text_domain" type="array">
            <element value="my-awesome-plugin"/>  <!-- Your slug -->
        </property>
    </properties>
</rule>

<rule ref="WordPress.NamingConventions.PrefixAllGlobals">
    <properties>
        <property name="prefixes" type="array">
            <element value="myawesomeplugin"/>     <!-- lowercase prefix -->
            <element value="MY_AWESOME_PLUGIN"/>   <!-- UPPERCASE prefix -->
            <element value="MyAwesomePlugin"/>     <!-- CamelCase prefix -->
        </property>
    </properties>
</rule>
```

#### `composer.json`

```json
{
    "name": "yourname/my-awesome-plugin",
    "description": "Your plugin description",
    "type": "wordpress-plugin",
    // ... rest of config
}
```

#### `package.json`

```json
{
    "name": "my-awesome-plugin",
    "description": "Your plugin description",
    // ... rest of config
}
```

#### `.wp-env.json`

Update the plugin path:

```json
{
    "plugins": [
        "./my-awesome-plugin"  // Your plugin directory name
    ]
}
```

### 8. WordPress.org Files

#### `readme.txt`

```
=== My Awesome Plugin ===
Contributors: yourusername
Tags: tag1, tag2
Requires at least: 5.8
Tested up to: 6.4
Stable tag: 1.0.0
Requires PHP: 7.4
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Short description of your plugin

== Description ==
Detailed description...
```

### 9. GitHub Actions

If you have GitHub workflows, update:

#### `.github/workflows/release.yml`

```yaml
env:
  PLUGIN_SLUG: my-awesome-plugin
  PLUGIN_NAME: "My Awesome Plugin"
```

## Verification Checklist

After renaming, verify everything works:

### 1. Run Coding Standards Check

```bash
npm run lint:php
```

**Must pass with NO errors before committing!**

If there are errors, fix them with:

```bash
npm run lint:php:fix
```

Then manually fix remaining issues.

### 2. Check All Instances

Search for remaining instances of old names:

```bash
# Search for plugin-name
grep -r "plugin-name" ./my-awesome-plugin/ --exclude-dir=vendor

# Search for plugin_name
grep -r "plugin_name" ./my-awesome-plugin/ --exclude-dir=vendor

# Search for PLUGIN_NAME
grep -r "PLUGIN_NAME" ./my-awesome-plugin/ --exclude-dir=vendor

# Search for PluginName
grep -r "PluginName" ./my-awesome-plugin/ --exclude-dir=vendor
```

Should return NO results (except in comments/documentation).

### 3. Test Plugin Activation

```bash
# Start wp-env
npm run env:start

# Activate plugin via WP-CLI
npm run env:cli -- wp plugin activate my-awesome-plugin

# Check for errors
npm run env:cli -- wp plugin list
```

### 4. Verify Text Domain

```bash
# Search for hardcoded strings without text domain
grep -rn "__(" ./my-awesome-plugin/ --exclude-dir=vendor | grep -v "my-awesome-plugin"
grep -rn "_e(" ./my-awesome-plugin/ --exclude-dir=vendor | grep -v "my-awesome-plugin"
```

Should return NO results.

## Common Mistakes to Avoid

1. **❌ Using plugin name in text domain**
   ```php
   __( 'Text', 'My Awesome Plugin' )  // WRONG!
   ```
   **✅ Use the slug:**
   ```php
   __( 'Text', 'my-awesome-plugin' )  // CORRECT
   ```

2. **❌ Prefix too short**
   ```php
   define( 'MAP_VERSION', '1.0.0' );  // Only 3 chars - TOO SHORT!
   ```
   **✅ Minimum 4 characters:**
   ```php
   define( 'MYAP_VERSION', '1.0.0' );  // 4 chars - GOOD
   ```

3. **❌ Mismatched text domains**
   - Plugin header says `my-awesome-plugin`
   - Code uses `my-plugin` or `my_awesome_plugin`
   - **Must be exactly the same everywhere!**

4. **❌ Forgetting phpcs.xml.dist**
   - This causes PHPCS to flag all your prefixes and text domains as errors
   - Always update this file to match your plugin

5. **❌ Hyphens in namespaces**
   ```php
   namespace My-Awesome-Plugin;  // WRONG! PHP doesn't allow hyphens
   ```
   **✅ Use CamelCase:**
   ```php
   namespace MyAwesomePlugin;  // CORRECT
   ```

## Files That MUST Be Updated

Minimum files to check/update:

1. `your-plugin-slug/your-plugin-slug.php` (main file)
2. `your-plugin-slug/readme.txt`
3. `your-plugin-slug/uninstall.php`
4. `phpcs.xml.dist`
5. `composer.json`
6. `package.json`
7. `.wp-env.json`
8. Any class files with namespaces
9. Any files with translatable strings

## Quick Reference: Naming Patterns

| Use Case | Pattern | Example |
|----------|---------|---------|
| Plugin slug | lowercase-hyphenated | `my-awesome-plugin` |
| Text domain | Same as slug | `my-awesome-plugin` |
| Function prefix | lowercase, 4+ chars | `myawesomeplugin_` or `map_` |
| Constant prefix | UPPERCASE, 4+ chars | `MY_AWESOME_PLUGIN_` or `MAP_` |
| Namespace | CamelCase, no hyphens | `MyAwesomePlugin` |
| Class names | CamelCase with underscores | `My_Awesome_Plugin` |
| Directory name | Same as slug | `my-awesome-plugin/` |
| Main file | Same as slug | `my-awesome-plugin.php` |

## Need Help?

If you encounter issues:

1. Check the automated setup script: `bin/setup-plugin.sh`
2. Review this guide carefully
3. Run `npm run lint:php` to catch naming issues
4. Search the codebase for old names using grep

Remember: **Consistency is key!** Use the same naming pattern throughout your plugin.