<?php
/**
 * Class SampleTest
 *
 * @package PluginName
 */

/**
 * Sample test case.
 */
class SampleTest extends WP_UnitTestCase {

	/**
	 * Set up before each test.
	 */
	public function setUp(): void {
		parent::setUp();
		// Your setup code here.
	}

	/**
	 * Tear down after each test.
	 */
	public function tearDown(): void {
		// Your teardown code here.
		parent::tearDown();
	}

	/**
	 * Test that plugin is active.
	 */
	public function test_plugin_is_active() {
		$this->assertTrue( function_exists( 'plugin_name_init' ) );
	}

	/**
	 * Test plugin constants are defined.
	 */
	public function test_plugin_constants_defined() {
		$this->assertTrue( defined( 'PLUGIN_NAME_VERSION' ) );
		$this->assertTrue( defined( 'PLUGIN_NAME_PATH' ) );
		$this->assertTrue( defined( 'PLUGIN_NAME_URL' ) );
		$this->assertTrue( defined( 'PLUGIN_NAME_BASENAME' ) );
	}

	/**
	 * Test plugin version.
	 */
	public function test_plugin_version() {
		$this->assertEquals( '1.0.0', PLUGIN_NAME_VERSION );
	}

	/**
	 * A test with WordPress functions.
	 */
	public function test_wordpress_functionality() {
		// Create a test post.
		$post_id = $this->factory->post->create(
			array(
				'post_title'   => 'Test Post',
				'post_content' => 'This is a test post.',
				'post_status'  => 'publish',
			)
		);

		// Assert the post was created.
		$this->assertIsInt( $post_id );
		$this->assertGreaterThan( 0, $post_id );

		// Get the post.
		$post = get_post( $post_id );

		// Assert post properties.
		$this->assertEquals( 'Test Post', $post->post_title );
		$this->assertEquals( 'This is a test post.', $post->post_content );
		$this->assertEquals( 'publish', $post->post_status );
	}

	/**
	 * Test hooks are registered.
	 */
	public function test_hooks_registered() {
		// Test that init hook is registered.
		$this->assertNotFalse( has_action( 'init', 'plugin_name_init' ) );
		
		// Test that script hooks are registered.
		$this->assertNotFalse( has_action( 'admin_enqueue_scripts', 'plugin_name_admin_enqueue_scripts' ) );
		$this->assertNotFalse( has_action( 'wp_enqueue_scripts', 'plugin_name_enqueue_scripts' ) );
	}

	/**
	 * Test with user capabilities.
	 */
	public function test_user_capabilities() {
		// Create a test user with administrator role.
		$user_id = $this->factory->user->create(
			array(
				'role' => 'administrator',
			)
		);

		// Set the current user.
		wp_set_current_user( $user_id );

		// Check capabilities.
		$this->assertTrue( current_user_can( 'manage_options' ) );
		$this->assertTrue( current_user_can( 'activate_plugins' ) );
	}

	/**
	 * Data provider example.
	 *
	 * @return array
	 */
	public function data_provider_example() {
		return array(
			array( 'input1', 'expected1' ),
			array( 'input2', 'expected2' ),
			array( 'input3', 'expected3' ),
		);
	}

	/**
	 * Test with data provider.
	 *
	 * @dataProvider data_provider_example
	 *
	 * @param string $input    The input value.
	 * @param string $expected The expected value.
	 */
	public function test_with_data_provider( $input, $expected ) {
		// Your test logic here.
		$this->assertIsString( $input );
		$this->assertIsString( $expected );
	}
}