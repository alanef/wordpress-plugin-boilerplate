<?php
/**
 * Fired when the plugin is uninstalled.
 *
 * When populating this file, consider the following flow
 * of control:
 *
 * - This method should be static
 * - Check if the $_REQUEST content actually is the plugin name
 * - Run an admin referrer check to make sure it goes through authentication
 * - Verify the output of $_GET makes sense
 * - Repeat with other user roles. Best directly by using the links/query string parameters.
 * - Repeat things for multisite. Once for a single site in the network, once sitewide.
 *
 * @link       https://example.com
 * @since      1.0.0
 *
 * @package    PluginName
 */

// If uninstall not called from WordPress, then exit.
if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) {
	exit;
}

// Clear any cached data that has been removed.
wp_cache_flush();

/**
 * Delete plugin options.
 *
 * Uncomment the lines below to remove options from the database.
 * Make sure to change 'plugin_name' to your actual option names.
 */

// Single site.
// delete_option( 'plugin_name_option' );
// delete_option( 'plugin_name_settings' );

// For site options in Multisite.
// delete_site_option( 'plugin_name_option' );

/**
 * Delete plugin transients.
 */
// delete_transient( 'plugin_name_transient' );

/**
 * Delete plugin user meta.
 */
// $users = get_users();
// foreach ( $users as $user ) {
// 	delete_user_meta( $user->ID, 'plugin_name_user_meta' );
// }

/**
 * Delete plugin post meta.
 */
// delete_post_meta_by_key( 'plugin_name_post_meta' );

/**
 * Drop custom database tables.
 *
 * Uncomment and modify as needed if your plugin creates custom tables.
 */
// global $wpdb;
// $wpdb->query( "DROP TABLE IF EXISTS {$wpdb->prefix}plugin_name_table" );