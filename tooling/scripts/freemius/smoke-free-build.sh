#!/usr/bin/env bash
# Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh
#
# Runtime check of the free build: installs the zip Freemius generated, alone, on a clean
# WordPress (wp-env, WP_DEBUG on) and loads the pages a free user reaches. The static scan
# finds calls to stripped code; this finds the ones only a page load shows.
#
#   scripts/freemius/smoke-free-build.sh <free.zip>
#
# Steps: activate (no output allowed beyond the success line); load the front page, wp-admin,
# Plugins, and every ?page= screen in the admin menu, before and after skipping the Freemius
# opt-in; then each line of the project's
# .freemius-free-smoke, which may add
#   url /some/path            a page to load (logged in as admin)
#   shortcode [a_shortcode]   rendered on a published page that is then loaded
#   block namespace/name      a block that must be registered in the editor, for blocks
#                             registered in JavaScript with no block.json (found automatically)
# Fails on an HTTP 500, WordPress's critical error page, or a PHP fatal, parse error or uncaught
# exception in debug.log. Warnings and notices from the plugin are listed but do not fail.
# Then loads the same pages and the block editor in a headless browser (smoke-browser.js):
# fails on an uncaught error from the plugin's scripts, a plugin asset that does not load, or
# a block whose block.json ships but is not registered in the editor.
# Needs Docker and Node (as CI and local wp-env already do). Port: SMOKE_PORT, default 8895.
set -uo pipefail

ZIP="$(cd "$(dirname "${1:?Usage: $0 <free.zip>}")" && pwd)/$(basename "$1")"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
DIR="__PLUGIN_DIR__"
PORT="${SMOKE_PORT:-8895}"
URL="http://localhost:$PORT"
W="$(mktemp -d)"
fail=0
bad() { echo "FAIL $*"; fail=1; }
# </dev/null: npx would otherwise read the rest of a loop's input (the smoke file).
cli() { (cd "$W" && npx --yes @wordpress/env@10 run cli -- "$@" 2>/dev/null </dev/null); }
# wp-env destroy asks for confirmation, so take the environment down directly: containers,
# volumes and its folder under ~/wp-env. Nothing of it may outlive the check.
cleanup() {
	local ip
	ip=$(cd "$W" && npx --yes @wordpress/env@10 install-path 2>/dev/null </dev/null | tail -1)
	if [ -n "$ip" ] && [ -f "$ip/docker-compose.yml" ]; then
		docker compose -f "$ip/docker-compose.yml" down -v --remove-orphans >/dev/null 2>&1
		rm -rf "${ip:?}" 2>/dev/null || echo "WARN could not remove $ip (root-owned files; remove with sudo)"
	fi
	rm -rf "${W:?}"
}
trap cleanup EXIT

unzip -q "$ZIP" -d "$W" || { echo "FAIL cannot unzip $ZIP"; exit 1; }
cat > "$W/.wp-env.json" <<EOF
{
  "core": null,
  "phpVersion": "8.4",
  "plugins": [],
  "mappings": { "wp-content/plugins/$DIR": "./$DIR" },
  "port": $PORT,
  "env": { "tests": { "port": $((PORT + 1)) } },
  "config": { "WP_DEBUG": true, "WP_DEBUG_LOG": true, "WP_DEBUG_DISPLAY": false }
}
EOF
echo "Starting a clean WordPress with only the free build ($URL)"
start_log=$(cd "$W" && npx --yes @wordpress/env@10 start 2>&1 </dev/null) || { echo "FAIL wp-env did not start:"; echo "$start_log" | tail -5; exit 1; }

act=$(cli wp plugin activate "$DIR" 2>&1)
if echo "$act" | grep -q "^Success"; then
	extra=$(echo "$act" | grep -v -e '^Success' -e "^Plugin '$DIR' activated" -e '^ℹ' -e '^✔' -e '^$')
	[ -n "$extra" ] && bad "activation printed output:"$'\n'"$extra"
	echo "ok   activated"
else
	bad "activation failed: $act"
fi

jar="$W/cookies"
curl -s -o /dev/null -c "$jar" -b "wordpress_test_cookie=WP+Cookie+check" \
	--data "log=admin&pwd=password&wp-submit=Log+In&testcookie=1" "$URL/wp-login.php"

visit() {
	local path="$1" code body
	body=$(curl -s -b "$jar" -w '\n%{http_code}' "$URL$path")
	code=${body##*$'\n'}
	if [ "$code" -ge 500 ] || echo "$body" | grep -q -e 'There has been a critical error' -e 'Fatal error'; then
		bad "$path: HTTP $code or fatal on the page"
	else
		echo "ok   $path ($code)"
		echo "$path" >> "$W/paths"
	fi
}

visit "/"
visit "/wp-admin/"
visit "/wp-admin/plugins.php"
# Every menu screen added with a ?page= slug, wherever its parent is (admin.php, options-general.php,
# edit.php...). Twice: as a fresh install first sees it, then after "Skip" on the Freemius opt-in,
# because Freemius trims the plugin's menu until the user chooses (QPP's top-level screen only
# appears after it).
sweep() {
	for href in $(curl -s -b "$jar" "$URL/wp-admin/" | grep -oP 'href="\K[^"]*[?&](amp;)?page=[^"]*' | sed 's/&amp;/\&/g' | sort -u); do
		case "$href" in http*) href="/${href#*://*/}" ;; /*) ;; *) href="/wp-admin/$href" ;; esac
		case " $seen " in *" $href "*) continue ;; esac
		seen="$seen $href"
		visit "$href"
	done
}
seen=""
sweep
if cli wp eval 'if ( function_exists( "freemius" ) && freemius( __FREEMIUS_ID__ ) ) { freemius( __FREEMIUS_ID__ )->skip_connection(); echo "skipped"; }' | grep -q skipped; then
	echo "ok   Freemius opt-in skipped, as a user choosing Skip"
	sweep
else
	echo "WARN could not skip the Freemius opt-in for module __FREEMIUS_ID__; menus hidden before opt-in were not swept"
fi

if [ -f "$ROOT/.freemius-free-smoke" ]; then
	while IFS= read -r line; do
		case "$line" in
			url\ *) visit "${line#url }" ;;
			shortcode\ *)
				id=$(cli wp post create --post_type=page --post_status=publish --post_title=Smoke --post_content="${line#shortcode }" --porcelain | tr -dc '0-9')
				[ -n "$id" ] && visit "/?page_id=$id" || bad "could not create a page for ${line#shortcode }" ;;
		esac
	done < "$ROOT/.freemius-free-smoke"
fi

# Browser pass, before debug.log is read, so PHP errors from the scripts' own requests count.
# Blocks: every block.json in the build, by name (src/ and build/ copies name the same block),
# plus the smoke file's block lines.
blocks=$( {
	find "$W/$DIR" -name block.json -not -path '*/node_modules/*' -exec php -r 'echo json_decode(file_get_contents($argv[1]))->name ?? "", "\n";' {} \;
	[ -f "$ROOT/.freemius-free-smoke" ] && sed -n 's/^block[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p' "$ROOT/.freemius-free-smoke"
} | sort -u)
if [ ! -d "$HERE/node_modules/playwright" ]; then
	(cd "$HERE" && npm install --ignore-scripts --no-audit --no-fund >/dev/null 2>&1) || bad "could not install the browser check (npm install in $HERE)"
fi
if [ -n "${CI:-}" ]; then (cd "$HERE" && npx playwright install --with-deps chromium >/dev/null 2>&1); else (cd "$HERE" && npx playwright install chromium >/dev/null 2>&1); fi
touch "$W/paths"
# shellcheck disable=SC2086
node "$HERE/smoke-browser.js" "$URL" "$DIR" "$W/paths" $blocks || fail=1

log=$(cli cat wp-content/debug.log 2>/dev/null)
fatal=$(echo "$log" | grep -E 'PHP (Fatal|Parse) error|Uncaught ' | head -10)
[ -n "$fatal" ] && bad "debug.log:"$'\n'"$fatal"
notes=$(echo "$log" | grep -E 'PHP (Warning|Notice|Deprecated)' | grep -F "/plugins/$DIR/" | sort -u | head -10)
[ -n "$notes" ] && echo "WARN plugin warnings/notices in debug.log:"$'\n'"$notes"

if [ "$fail" = 0 ]; then echo "PASS free build runs without fatals or script errors"; else echo "BLOCKED: the free build fatals or its scripts fail. See above." >&2; fi
exit "$fail"
