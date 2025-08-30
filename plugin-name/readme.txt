=== My Awesome WP Boilerplate ===
Contributors: alanef
Donate link: https://github.com/sponsors/alanef
Tags: boilerplate, development, framework, wordpress, standards
Requires at least: 5.8
Tested up to: 6.8
Stable tag: 1.0.0
Requires PHP: 7.4
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

A standardized, organized foundation for building high-quality WordPress plugins with best practices built in.

== Description ==

My Awesome WP Boilerplate provides developers with a clean, well-structured starting point for WordPress plugin development. This boilerplate follows WordPress coding standards and includes modern development tools to help you build secure, performant plugins.

= Key Features =

* **WordPress Coding Standards**: Pre-configured PHPCS with WPCS ruleset
* **Security Checks**: Built-in security scanning with PHPCompatibility checks
* **Modern Development**: Composer and npm ready with autoloading
* **CI/CD Ready**: GitHub Actions workflows for automated testing and deployment
* **Translation Ready**: Proper internationalization setup with automatic POT generation
* **Clean Architecture**: Organized file structure following best practices
* **Developer Friendly**: Easy customization with clear documentation

= Development Tools Included =

* PHP_CodeSniffer with WordPress Coding Standards
* PHPUnit testing framework with WordPress polyfills
* Automated build and release processes
* Security and compatibility checking
* Translation file generation

= Perfect For =

* Starting new WordPress plugin projects
* Learning WordPress plugin development best practices
* Building plugins for WordPress.org repository
* Creating premium plugins with Freemius integration
* Developing client plugins with professional standards

== Installation ==

= For Developers =

1. Clone or download the repository from GitHub
2. Run the setup script: `./bin/setup-plugin.sh`
3. Install dependencies: `composer install && npm install`
4. Start developing your awesome plugin!

= For Users =

1. Upload the plugin files to the `/wp-content/plugins/my-awesome-wp-boilerplate` directory
2. Activate the plugin through the 'Plugins' screen in WordPress
3. Configure any settings as needed

== Frequently Asked Questions ==

= Is this a functional plugin? =

This is a boilerplate/starter template for developers to build their own plugins. It provides the foundation and structure but needs to be customized with your specific functionality.

= What PHP version is required? =

PHP 7.4 or higher is required, though the boilerplate can be configured for different PHP versions based on your needs.

= Can I use this for commercial plugins? =

Yes! The boilerplate is GPL licensed and can be used for both free and commercial plugins.

= Does it support multisite? =

Yes, the boilerplate includes considerations for multisite installations in its uninstall routine and can be extended for multisite functionality.

= How do I customize the plugin name? =

Run the included setup script (`./bin/setup-plugin.sh`) which will guide you through renaming all instances of the placeholder names.

== Screenshots ==

1. Clean, organized file structure
2. Automated testing and deployment workflows
3. WordPress coding standards compliance

== Changelog ==

= 1.0.0 =
* Initial release
* WordPress coding standards compliance
* Security checks integration
* Automated build processes
* Translation file generation
* GitHub Actions CI/CD workflows
* Modern PHP development setup

== Upgrade Notice ==

= 1.0.0 =
Initial release of the WordPress plugin boilerplate.

== Developer Resources ==

* [GitHub Repository](https://github.com/alanef/wordpress-plugin-boilerplate)
* [Report Issues](https://github.com/alanef/wordpress-plugin-boilerplate/issues)
* [Contributing Guidelines](https://github.com/alanef/wordpress-plugin-boilerplate/blob/main/CONTRIBUTING.md)