#!/usr/bin/env bash
# Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh
#
# Run the release gates locally and write .sdlc/releases/X.Y.Z/TESTS_PASSED.md only if
# every one passes. /tk-deploy live refuses a marker whose commit is not an ancestor of
# what it tags, or when plugin code changed since, so run this AFTER the release commit.
#
#   scripts/release/run-tests-and-mark.sh X.Y.Z
#   scripts/release/run-tests-and-mark.sh X.Y.Z --no-wp-env   PHPUnit skipped, and the
#                                                            marker says so
#
# Gates, the same ones .github/workflows/checks.yml fails the build on, using the commands
# this repository's composer.json, package.json and run-tests.sh define:
#   composer install, composer validate --strict, composer run check (PHPCompatibility for
#   every PHP version from Requires PHP, then security sniffs), version consistency, the
#   build (composer run build, and changelog.txt must be in the zip), Plugin Check (only if
#   a "plugin-check" composer script exists: CI runs it on the built zip with
#   wordpress/plugin-check-action, which has no local equivalent here), and PHPUnit
#   (npm test: the host unit suite if tests/phpunit-unit.xml.dist exists, then the wp-env
#   suite).
set -uo pipefail

V="${1:?Usage: $0 X.Y.Z [--no-wp-env]}"
NO_WP_ENV=0
[ "${2:-}" = "--no-wp-env" ] && NO_WP_ENV=1

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
PLUGIN_DIR="__PLUGIN_DIR__"
OUT="$ROOT/.sdlc/releases/$V"
LOG="$OUT/tests.log"
mkdir -p "$OUT"
rm -f "$OUT/TESTS_PASSED.md"
: > "$LOG"

cd "$ROOT" || exit 1

# The PHPUnit suite runs inside wp-env. run-tests.sh would start it, but that takes minutes
# and needs Docker, so say so up front rather than half-way through the gates.
WP_ENV_UP=0
if npx --no-install wp-env run tests-cli true > /dev/null 2>&1; then WP_ENV_UP=1; fi
if [ "$WP_ENV_UP" = 0 ] && [ "$NO_WP_ENV" = 0 ]; then
	cat >&2 <<-EOF
	wp-env is not running, so the PHPUnit suite (the CI 'tests' job) cannot run.
	  Start it:  npm run start     (dev :__PORT__, tests :__TESTS_PORT__), then re-run this script.
	  Or run without it:  $0 $V --no-wp-env
	    The marker then records PHPUnit as SKIPPED and CI's tests job is the only test gate.
	No marker written.
	EOF
	exit 1
fi

rows=()
gate() {
	local name="$1"; shift
	echo "== $name" >> "$LOG"
	if "$@" >> "$LOG" 2>&1; then
		rows+=("| $name | pass |")
	else
		rows+=("| $name | FAIL |")
		echo "FAILED: $name (see $LOG)" >&2
		return 1
	fi
}

ok=0
gate "composer install"          composer install --prefer-dist --no-progress --no-interaction || ok=1
gate "composer validate --strict" composer validate --strict                                   || ok=1
gate "composer run check"        composer run-script check                                    || ok=1
gate "version consistency"       "$ROOT/scripts/release/bump-version.sh" --check "$V"         || ok=1

build() {
	local pkgs; pkgs=$(wp package list --fields=name 2>/dev/null)
	if ! grep -q '^wp-cli/dist-archive-command$' <<< "$pkgs"; then
		echo "wp dist-archive is not installed: wp package install wp-cli/dist-archive-command:v3.1.0"
		return 1
	fi
	composer run-script build || return 1
	unzip -l "zipped/$PLUGIN_DIR-free.zip" || return 1
	# Listing captured first: grep -q exiting early would SIGPIPE unzip and, under
	# pipefail, report a file that is there as missing.
	local files; files=$(unzip -Z1 "zipped/$PLUGIN_DIR-free.zip") || return 1
	if ! grep -qx "$PLUGIN_DIR/changelog.txt" <<< "$files"; then
		echo "$PLUGIN_DIR/changelog.txt is not in the zip: check $PLUGIN_DIR/.distignore"
		return 1
	fi
}
gate "build (composer run build)" build || ok=1

if grep -qE '^[[:space:]]*plugin-check([[:space:]]|$)' <<< "$(composer run-script --list 2>/dev/null)"; then
	# Plugin Check exits 0 with errors listed, so the output is the verdict. Not
	# tee /dev/stderr: on Linux that reopens the log and truncates it.
	plugin_check() { local out; out=$(composer run-script plugin-check 2>&1); echo "$out"; ! grep -qE '\bERROR\b' <<< "$out"; }
	gate "composer run plugin-check" plugin_check || ok=1
else
	rows+=("| Plugin Check | not run locally (no plugin-check script); CI runs it on the built zip |")
fi

if [ "$WP_ENV_UP" = 1 ]; then
	gate "PHPUnit (npm test)" npm test || ok=1
else
	rows+=("| PHPUnit (npm test) | SKIPPED: wp-env not running (--no-wp-env); CI tests job is the gate |")
fi

[ "$ok" = 0 ] || { echo "Gates failed. No marker written." >&2; exit 1; }

summary() { sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -aE '^(OK \(|Tests: )' | sed 's/^/    /'; }

{
	echo "# Tests Passed: $V"
	echo
	echo "**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "**Commit:** $(git rev-parse HEAD)"
	echo "**Tracked changes at run time:** $(git status --porcelain --untracked-files=no | wc -l)"
	echo
	echo "| Gate | Result |"
	echo "|---|---|"
	printf '%s\n' "${rows[@]}"
	echo
	echo "PHPUnit summaries:"
	echo
	summary
	echo
	echo "Full output: tests.log (not committed)."
} > "$OUT/TESTS_PASSED.md"

echo "All gates passed. Marker written to $OUT/TESTS_PASSED.md"
