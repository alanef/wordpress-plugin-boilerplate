<?php
/**
 * Self-update from GitHub releases, for plugins not hosted on WordPress.org.
 *
 * Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh.
 * Only present when the plugin's readme.txt has no `Type:` header (GitHub-only release).
 *
 * Uses core's Update URI mechanism (WordPress 5.8+): the main plugin file declares
 * `Update URI: https://github.com/<owner>/<repo>`, which stops core asking WordPress.org
 * about the plugin and fires the `update_plugins_github.com` filter instead. The latest
 * release is found from the redirect of github.com/<owner>/<repo>/releases/latest (no
 * GitHub API, no token, no rate limit) and the package URL is built from the tag, because
 * the Build Release workflow always attaches `<plugin-dir>-<version>.zip`.
 *
 * @package PLUGIN_NAME\Updater
 */

namespace PLUGIN_NAME\Updater;

defined( 'ABSPATH' ) || exit;

/**
 * GitHub release updater (tooling version 1.0.0).
 */
class GitHub_Updater {

	/**
	 * Seconds a successful lookup is cached.
	 */
	const CACHE_TTL = 6 * HOUR_IN_SECONDS;

	/**
	 * Seconds a failed lookup is cached, so an outage does not slow every update check.
	 */
	const FAILURE_TTL = HOUR_IN_SECONDS;

	/**
	 * Plugin basename, e.g. my-plugin/my-plugin.php.
	 *
	 * @var string
	 */
	private $basename;

	/**
	 * Canonical plugin directory: the release zip's top folder and file-name prefix, and the
	 * slug. A site may have installed the plugin under another folder name.
	 */
	const PLUGIN_DIR = 'plugin-name';

	/**
	 * Register the hooks for one plugin.
	 *
	 * @param string $plugin_file Absolute path to the main plugin file.
	 */
	public static function register( $plugin_file ) {
		$updater = new self( $plugin_file );
		add_filter( 'update_plugins_github.com', array( $updater, 'check' ), 10, 3 );
		add_filter( 'plugins_api', array( $updater, 'info' ), 10, 3 );
		add_filter( 'upgrader_source_selection', array( $updater, 'keep_folder' ), 10, 4 );
		add_action( 'load-update-core.php', array( $updater, 'maybe_force_check' ) );
		return $updater;
	}

	/**
	 * Constructor.
	 *
	 * @param string $plugin_file Absolute path to the main plugin file.
	 */
	public function __construct( $plugin_file ) {
		$this->basename = plugin_basename( $plugin_file );
	}

	/**
	 * Answer core's update check for this plugin.
	 *
	 * @param array|false $update      Update data from an earlier filter, or false.
	 * @param array       $plugin_data Plugin headers.
	 * @param string      $plugin_file Plugin basename being checked.
	 * @return array|false
	 */
	public function check( $update, $plugin_data, $plugin_file ) {
		if ( $plugin_file !== $this->basename || ! empty( $update ) ) {
			return $update;
		}
		$repo = self::repo_from_uri( isset( $plugin_data['UpdateURI'] ) ? $plugin_data['UpdateURI'] : '' );
		if ( '' === $repo ) {
			return $update;
		}
		$release = $this->latest_release( $repo );
		if ( ! $release ) {
			return $update;
		}
		return array(
			'id'      => 'github.com/' . $repo,
			'slug'    => self::PLUGIN_DIR,
			'plugin'  => $this->basename,
			'version' => $release['version'],
			'url'     => 'https://github.com/' . $repo,
			'package' => $release['package'],
		);
	}

	/**
	 * Supply "View details" for this plugin from the cached release.
	 *
	 * @param false|object|array $result Result so far.
	 * @param string             $action plugins_api action.
	 * @param object             $args   Request arguments.
	 * @return false|object|array
	 */
	public function info( $result, $action, $args ) {
		if ( 'plugin_information' !== $action || ! isset( $args->slug ) || self::PLUGIN_DIR !== $args->slug ) {
			return $result;
		}
		if ( ! function_exists( 'get_plugin_data' ) ) {
			require_once ABSPATH . 'wp-admin/includes/plugin.php';
		}
		$data = get_plugin_data( WP_PLUGIN_DIR . '/' . $this->basename, false, false );
		$repo = self::repo_from_uri( $data['UpdateURI'] );
		if ( '' === $repo ) {
			return $result;
		}
		$release = $this->latest_release( $repo );
		$version = $release ? $release['version'] : $data['Version'];
		$notes   = 'https://github.com/' . $repo . '/releases' . ( $release ? '/tag/' . rawurlencode( $release['tag'] ) : '' );
		return (object) array(
			'name'          => $data['Name'],
			'slug'          => self::PLUGIN_DIR,
			'version'       => $version,
			'author'        => $data['Author'],
			'homepage'      => 'https://github.com/' . $repo,
			'requires'      => $data['RequiresWP'],
			'requires_php'  => $data['RequiresPHP'],
			'download_link' => $release ? $release['package'] : '',
			'sections'      => array(
				'description' => '<p>' . esc_html( $data['Description'] ) . '</p>',
				'changelog'   => '<p><a href="' . esc_url( $notes ) . '">' . esc_html( $notes ) . '</a></p>',
			),
		);
	}

	/**
	 * Install an update into the folder the plugin already lives in.
	 *
	 * The release zip's top folder is the canonical plugin directory; a site that installed
	 * the plugin under another folder name would otherwise end up with two copies.
	 *
	 * @param string       $source        Extracted source folder.
	 * @param string       $remote_source Parent of the extracted folder.
	 * @param \WP_Upgrader $upgrader      Upgrader.
	 * @param array        $hook_extra    Upgrade context.
	 * @return string|\WP_Error
	 */
	public function keep_folder( $source, $remote_source, $upgrader, $hook_extra = array() ) {
		global $wp_filesystem;
		if ( ! isset( $hook_extra['plugin'] ) || $hook_extra['plugin'] !== $this->basename ) {
			return $source;
		}
		$wanted = trailingslashit( $remote_source ) . dirname( $hook_extra['plugin'] ) . '/';
		if ( untrailingslashit( $source ) === untrailingslashit( $wanted ) || ! $wp_filesystem ) {
			return $source;
		}
		if ( ! $wp_filesystem->move( $source, $wanted, true ) ) {
			return new \WP_Error( 'fwupd_rename_failed', 'Could not rename the update folder to ' . dirname( $hook_extra['plugin'] ) . '.' );
		}
		return $wanted;
	}

	/**
	 * "Check again" on Dashboard -> Updates also refreshes the GitHub lookup.
	 */
	public function maybe_force_check() {
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended -- read-only flag, mirrors core's own force-check handling.
		if ( isset( $_GET['force-check'] ) && current_user_can( 'update_plugins' ) ) {
			delete_site_transient( $this->cache_key() );
		}
	}

	/**
	 * Latest release from the /releases/latest redirect, cached.
	 *
	 * @param string $repo owner/repo.
	 * @return array{tag:string,version:string,package:string}|array{} Empty when unknown.
	 */
	public function latest_release( $repo ) {
		$cached = get_site_transient( $this->cache_key() );
		if ( is_array( $cached ) && ( ! $cached || ( isset( $cached['repo'] ) && $cached['repo'] === $repo ) ) ) {
			return $cached;
		}

		$response = wp_remote_head(
			'https://github.com/' . $repo . '/releases/latest',
			array(
				'redirection' => 0,
				'timeout'     => 5,
			)
		);
		$location = is_wp_error( $response ) ? '' : (string) wp_remote_retrieve_header( $response, 'location' );
		$release  = array();
		if ( preg_match( '#/releases/tag/(v?(\d+\.\d+\.\d+))$#', $location, $m ) ) {
			$release = array(
				'repo'    => $repo,
				'tag'     => $m[1],
				'version' => $m[2],
				'package' => 'https://github.com/' . $repo . '/releases/download/' . $m[1] . '/' . self::PLUGIN_DIR . '-' . $m[2] . '.zip',
			);
		}

		set_site_transient( $this->cache_key(), $release, $release ? self::CACHE_TTL : self::FAILURE_TTL );
		return $release;
	}

	/**
	 * Transient key for this plugin's lookup.
	 *
	 * @return string
	 */
	public function cache_key() {
		return 'fwupd_' . md5( $this->basename );
	}

	/**
	 * Extract owner/repo from an Update URI such as https://github.com/owner/repo.
	 *
	 * @param string $uri Update URI header.
	 * @return string owner/repo, or '' when the URI is not a GitHub repository.
	 */
	public static function repo_from_uri( $uri ) {
		if ( preg_match( '#^https://github\.com/([\w.-]+/[\w.-]+?)(?:\.git)?/?$#', trim( (string) $uri ), $m ) ) {
			return $m[1];
		}
		return '';
	}
}

GitHub_Updater::register( dirname( __DIR__ ) . '/plugin-name.php' );
