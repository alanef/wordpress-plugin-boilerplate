<?php
/**
 * PHPUnit bootstrap file
 *
 * @package PluginName
 */

// Get the plugin directory.
$_tests_dir = getenv( 'WP_TESTS_DIR' );

if ( ! $_tests_dir ) {
	$_tests_dir = rtrim( sys_get_temp_dir(), '/\\' ) . '/wordpress-tests-lib';
}

// Forward custom PHPUnit Polyfills configuration to PHPUnit bootstrap file.
$_phpunit_polyfills_path = getenv( 'WP_TESTS_PHPUNIT_POLYFILLS_PATH' );
if ( false !== $_phpunit_polyfills_path ) {
	define( 'WP_TESTS_PHPUNIT_POLYFILLS_PATH', $_phpunit_polyfills_path );
}

if ( ! file_exists( $_tests_dir . '/includes/functions.php' ) ) {
	echo "Could not find $_tests_dir/includes/functions.php, have you run bin/install-wp-tests.sh ?" . PHP_EOL; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
	exit( 1 );
}

// Give access to tests_add_filter() function.
require_once $_tests_dir . '/includes/functions.php';

/**
 * Manually load the plugin being tested.
 */
function _manually_load_plugin() {
	// Update the path to your plugin's main file.
	$plugin_dir = dirname( __DIR__ );
	$plugin_slug = basename( glob( $plugin_dir . '/*/plugin-name.php' )[0] ?? 'plugin-name/plugin-name.php', '.php' );
	
	// Try to find the main plugin file.
	$possible_files = array(
		$plugin_dir . '/' . $plugin_slug . '/' . $plugin_slug . '.php',
		$plugin_dir . '/plugin-name/plugin-name.php',
	);
	
	foreach ( $possible_files as $file ) {
		if ( file_exists( $file ) ) {
			require $file;
			return;
		}
	}
	
	// If we get here, we couldn't find the plugin file.
	echo "Could not find plugin file to load for testing." . PHP_EOL;
	exit( 1 );
}

tests_add_filter( 'muplugins_loaded', '_manually_load_plugin' );

// Start up the WP testing environment.
require $_tests_dir . '/includes/bootstrap.php';