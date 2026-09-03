<?php
/**
 * PHPUnit bootstrap.
 *
 * Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh
 *
 * Runs inside the wp-env "tests" container where the WordPress core test
 * library lives at /wordpress-phpunit and the repository root is mapped to
 * /var/www/html (see .wp-env.json "mappings").
 */

$_tests_dir = getenv( 'WP_TESTS_DIR' );

if ( ! $_tests_dir ) {
	if ( file_exists( '/wordpress-phpunit/includes/functions.php' ) ) {
		$_tests_dir = '/wordpress-phpunit';
	} elseif ( file_exists( '/tmp/wordpress-tests-lib/includes/functions.php' ) ) {
		$_tests_dir = '/tmp/wordpress-tests-lib';
	} else {
		$_tests_dir = rtrim( sys_get_temp_dir(), '/\\' ) . '/wordpress-tests-lib';
	}
}

if ( ! getenv( 'WP_TESTS_PHPUNIT_POLYFILLS_PATH' ) ) {
	putenv( 'WP_TESTS_PHPUNIT_POLYFILLS_PATH=' . dirname( __DIR__ ) . '/vendor/yoast/phpunit-polyfills' );
}

if ( ! file_exists( "{$_tests_dir}/includes/functions.php" ) ) {
	echo "Could not find {$_tests_dir}/includes/functions.php" . PHP_EOL;
	exit( 1 );
}

require_once "{$_tests_dir}/includes/functions.php";

/**
 * Load the plugin and fire its activation hook.
 */
function _fullworks_load_plugin_under_test() {
	$plugin_file = WP_PLUGIN_DIR . '/__PLUGIN_DIR__/__MAIN_FILE__';

	if ( ! file_exists( $plugin_file ) ) {
		echo 'Could not find plugin file: ' . $plugin_file . PHP_EOL;
		exit( 1 );
	}

	// Never let Action Scheduler (if bundled) fire its async HTTP queue runner during tests.
	tests_add_filter( 'action_scheduler_allow_async_request_runner', '__return_false' );

	require $plugin_file;

	// Activation hooks do not fire in the test environment.
	do_action( 'activate_' . plugin_basename( $plugin_file ) );
}

tests_add_filter( 'muplugins_loaded', '_fullworks_load_plugin_under_test' );

// wp-env's tests site domain is "localhost", which PHPMailer rejects as a From address.
tests_add_filter(
	'wp_mail_from',
	function () {
		return 'wordpress@example.org';
	}
);

require "{$_tests_dir}/includes/bootstrap.php";
