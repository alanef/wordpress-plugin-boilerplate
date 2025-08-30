<?php
/**
 * Plugin Name:       Plugin Name
 * Plugin URI:        https://example.com/plugin-name
 * Description:       Brief description of what the plugin does.
 * Version:           1.0.0
 * Requires at least: 5.8
 * Requires PHP:      7.4
 * Author:            Your Name
 * Author URI:        https://example.com
 * License:           GPL v2 or later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       plugin-name
 * Domain Path:       /languages
 *
 * @package PluginName
 */

// If this file is called directly, abort.
if ( ! defined( 'WPINC' ) ) {
	die;
}

// Define plugin constants.
define( 'PLUGIN_NAME_VERSION', '1.0.0' );
define( 'PLUGIN_NAME_PATH', plugin_dir_path( __FILE__ ) );
define( 'PLUGIN_NAME_URL', plugin_dir_url( __FILE__ ) );
define( 'PLUGIN_NAME_BASENAME', plugin_basename( __FILE__ ) );

/**
 * The code that runs during plugin activation.
 */
function plugin_name_activate() {
	// Activation code here.
	// Set default options, create database tables, etc.
}

/**
 * The code that runs during plugin deactivation.
 */
function plugin_name_deactivate() {
	// Deactivation code here.
	// Clean up temporary data, clear caches, etc.
}

// Plugin activation/deactivation hooks.
register_activation_hook( __FILE__, 'plugin_name_activate' );
register_deactivation_hook( __FILE__, 'plugin_name_deactivate' );

/**
 * Initialize the plugin.
 */
function plugin_name_init() {
	// Load plugin text domain for translations.
	load_plugin_textdomain( 'plugin-name', false, dirname( PLUGIN_NAME_BASENAME ) . '/languages' );

	// Hook your plugin initialization here.
}
add_action( 'init', 'plugin_name_init' );

/**
 * Enqueue admin scripts and styles.
 *
 * @param string $hook The current admin page.
 */
function plugin_name_admin_enqueue_scripts( $hook ) {
	// Only load on specific admin pages if needed.
	// wp_enqueue_script( 'plugin-name-admin', PLUGIN_NAME_URL . 'assets/js/admin.js', array( 'jquery' ), PLUGIN_NAME_VERSION, true );
	// wp_enqueue_style( 'plugin-name-admin', PLUGIN_NAME_URL . 'assets/css/admin.css', array(), PLUGIN_NAME_VERSION );
}
add_action( 'admin_enqueue_scripts', 'plugin_name_admin_enqueue_scripts' );

/**
 * Enqueue frontend scripts and styles.
 */
function plugin_name_enqueue_scripts() {
	// wp_enqueue_script( 'plugin-name', PLUGIN_NAME_URL . 'assets/js/frontend.js', array( 'jquery' ), PLUGIN_NAME_VERSION, true );
	// wp_enqueue_style( 'plugin-name', PLUGIN_NAME_URL . 'assets/css/frontend.css', array(), PLUGIN_NAME_VERSION );
}
add_action( 'wp_enqueue_scripts', 'plugin_name_enqueue_scripts' );