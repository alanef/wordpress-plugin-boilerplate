#!/bin/bash
#
# Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh
#
# Run the PHPUnit suite inside the wp-env tests container.
#
# The repository root is mapped into the container (see .wp-env.json "mappings")
# so tests/, vendor/ and phpunit.xml.dist are available at /var/www/html.

set -o pipefail

WP_ENV="npx wp-env"

echo "======================================"
echo "Running PHPUnit tests in wp-env"
echo "======================================"
echo ""

if [ ! -d vendor/yoast/phpunit-polyfills ]; then
    echo "Dev dependencies missing - running composer install"
    composer install --prefer-dist --no-progress || exit 1
fi

# Pure unit tests run on the host, with no WordPress loaded.
#
# They MUST NOT run under the wp-env bootstrap. A unit test of this kind stubs
# wp_remote_post() and friends behind `if ( ! function_exists() )`; with
# WordPress loaded the real functions already exist, the stubs never install,
# and the test issues live HTTP instead of reading its fixture. It then fails
# in a way that reads as a product bug rather than a harness fault.
#
# Exclude the same directory from phpunit.xml.dist via "phpunit_exclude" in
# .tooling.json, or the wp-env suite will run these a second time and fail.
UNIT_STATUS=0
if [ -f tests/phpunit-unit.xml.dist ]; then
    echo "Running unit tests (no WordPress)..."
    echo ""
    ( cd tests && php ../vendor/bin/phpunit --configuration phpunit-unit.xml.dist --colors=always --testdox $* )
    UNIT_STATUS=$?
    echo ""
fi

if ! $WP_ENV run tests-cli wp core version > /dev/null 2>&1; then
    echo "Starting wp-env..."
    $WP_ENV start || exit 1
fi

echo ""
echo "Running tests..."
echo ""

$WP_ENV run tests-cli bash -c "
    export WP_TESTS_DIR=/wordpress-phpunit && \
    export WP_TESTS_PHPUNIT_POLYFILLS_PATH=/var/www/html/vendor/yoast/phpunit-polyfills && \
    cd /var/www/html && \
    php ./vendor/bin/phpunit --configuration phpunit.xml.dist --colors=always --testdox $*
"
STATUS=$?

# Either suite failing fails the run.
if [ $UNIT_STATUS -ne 0 ]; then
    STATUS=$UNIT_STATUS
fi

echo ""
if [ $STATUS -eq 0 ]; then
    echo -e "\033[32m✅ All tests passed!\033[0m"
else
    echo -e "\033[31m❌ Some tests failed!\033[0m"
fi
echo ""
exit $STATUS
