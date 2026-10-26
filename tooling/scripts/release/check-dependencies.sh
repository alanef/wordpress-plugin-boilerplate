#!/usr/bin/env bash
# Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh
#
# Whole-tree dependency audit for /tk-release. Per-issue security review only sees
# changed code, so an advisory against a package nobody touched gets past it.
# Writes .sdlc/releases/X.Y.Z/DEPENDENCY_AUDIT.md.
#
# Policy:
#   __PLUGIN_DIR__/ composer, no dev   ships in the zip          -> any advisory BLOCKS
#   project root composer              tests and tooling         -> warn only
#   npm (root, and plugin dir)         dev env / asset build     -> warn only
#
# Plugin dependencies have no committed composer.lock: CI resolves them fresh on every
# build. So the audit resolves them fresh too (lock only, nothing installed) and audits
# that, which is what the next build will ship. A lock this script created is removed.
set -uo pipefail

V="${1:?Usage: $0 X.Y.Z}"
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
P="$ROOT/__PLUGIN_DIR__"
OUT="$ROOT/.sdlc/releases/$V"
mkdir -p "$OUT"

run() { ( cd "$1" && shift && "$@" ) 2>&1 | grep -v 'legacy composer-installer'; return "${PIPESTATUS[0]}"; }

if [ -f "$P/composer.json" ]; then
	# Only a committed lock is what ships. An untracked local one may be stale, so set it
	# aside and resolve fresh, as CI does; it is put back afterwards.
	made_lock=0; held_lock=""
	if [ -f "$P/composer.lock" ] && ! git -C "$ROOT" ls-files --error-unmatch "$P/composer.lock" >/dev/null 2>&1; then
		held_lock=$(mktemp); mv "$P/composer.lock" "$held_lock"
		trap '[ -n "$held_lock" ] && mv -f "$held_lock" "$P/composer.lock"' EXIT
	fi
	[ -f "$P/composer.lock" ] || made_lock=1
	if [ "$made_lock" = 1 ]; then
		# Composer 2.9+ refuses to resolve versions with advisories; let it, so the audit
		# below names the advisory instead of reporting an unexplained resolve failure.
		resolve=$(COMPOSER_NO_BLOCKING=1 COMPOSER_NO_SECURITY_BLOCKING=1 run "$P" composer update --no-dev --no-install --no-scripts --no-plugins --no-progress --no-interaction); resolve_rc=$?
	else
		resolve="using committed __PLUGIN_DIR__/composer.lock"; resolve_rc=0
	fi
	# A plugin whose composer.json only autoloads resolves to a lock with no packages, and
	# composer audit exits 1 on that ("No installed packages found") rather than 0.
	no_pkgs=0
	if [ "$resolve_rc" = 0 ] && php -r '$l = json_decode(file_get_contents($argv[1]), true); exit(is_array($l) && empty($l["packages"]) ? 0 : 1);' "$P/composer.lock" 2>/dev/null; then
		no_pkgs=1
	fi
	if [ "$no_pkgs" = 1 ]; then
		prod="__PLUGIN_DIR__/composer.json requires no packages: the plugin ships no Composer dependencies."; prod_rc=0
	elif [ "$resolve_rc" = 0 ]; then
		prod=$(run "$P" composer audit --locked --no-dev --format=plain); prod_rc=$?
		[ -n "$prod" ] || prod="No security vulnerability advisories found."
	else
		prod="Could not resolve plugin dependencies, so they were not audited:
$resolve"; prod_rc=1
	fi
	[ "$made_lock" = 1 ] && rm -f "$P/composer.lock"
	if [ -n "$held_lock" ]; then mv -f "$held_lock" "$P/composer.lock"; held_lock=""; trap - EXIT; fi
	prod_result=$( [ "$no_pkgs" = 1 ] && echo "none shipped" || { [ "$prod_rc" = 0 ] && echo clean || echo ADVISORIES; } )
else
	prod="__PLUGIN_DIR__/composer.json absent: the plugin ships no Composer dependencies."; prod_rc=0; prod_result="none shipped"
fi

if [ -f "$ROOT/composer.lock" ]; then
	dev=$(run "$ROOT" composer audit --locked --format=plain); dev_rc=$?
elif [ -f "$ROOT/composer.json" ]; then
	dev=$(run "$ROOT" composer audit --format=plain); dev_rc=$?
else
	dev="no root composer.json, not audited"; dev_rc=0
fi

npm_out=""; npm_rc=0
for d in "$ROOT" "$P"; do
	if [ -f "$d/package-lock.json" ]; then
		out=$(run "$d" npm audit --omit=optional); rc=$?
		rel=${d#"$ROOT"}; rel=${rel#/}
		npm_out+="### ${rel:-repository root} (exit $rc)"$'\n'"$(echo "$out" | tail -40)"$'\n'
		[ "$rc" = 0 ] || npm_rc=$rc
	fi
done
[ -n "$npm_out" ] || npm_out="no package-lock.json, not audited"

{
	echo "# Dependency Audit: $V"
	echo
	echo "**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "**Commit:** $(git -C "$ROOT" rev-parse --short HEAD)"
	echo
	echo "| Tree | Policy | Exit | Result |"
	echo "|---|---|---|---|"
	echo "| plugin composer (no dev) | block | $prod_rc | $prod_result |"
	echo "| root composer (tooling) | warn | $dev_rc | $( [ "$dev_rc" = 0 ] && echo clean || echo advisories ) |"
	echo "| npm (dev env / build) | warn | $npm_rc | $( [ "$npm_rc" = 0 ] && echo clean || echo advisories ) |"
	echo
	echo '## plugin composer (no dev)'; echo '```'; echo "$prod"; echo '```'
	echo '## root composer'; echo '```'; echo "$dev"; echo '```'
	echo '## npm'; echo '```'; echo "$npm_out"; echo '```'
} > "$OUT/DEPENDENCY_AUDIT.md"

[ "$dev_rc" = 0 ] || echo "WARNING advisories in root (tooling) composer tree, see $OUT/DEPENDENCY_AUDIT.md" >&2
[ "$npm_rc" = 0 ] || echo "WARNING advisories in an npm tree (dev/build only), see $OUT/DEPENDENCY_AUDIT.md" >&2

if [ "$prod_rc" != 0 ]; then
	echo "BLOCKED: advisories in (or no resolve of) shipped dependencies. Fix with 'composer update' in ./__PLUGIN_DIR__ on a branch, test, then re-run /tk-release." >&2
	exit 1
fi
echo "Dependency audit written to $OUT/DEPENDENCY_AUDIT.md"
