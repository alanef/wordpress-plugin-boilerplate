#!/usr/bin/env bash
# Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh
#
# Static checks on the free build Freemius generated from our premium zip: the exact zip that
# goes to wordpress.org. Two things must hold before it ships:
#   1. no premium code in it (paid features given away, and a wordpress.org guideline breach);
#   2. nothing in it that fatals because Freemius stripped what it calls.
#
#   scripts/freemius/check-free-build.sh <free.zip> [<premium.zip>]
#
# Checks: php -l on every file; every @fs_premium_only path from the premium main file absent;
# no file or folder named like premium code; free-build-scan.php (leaked premium definitions,
# guards the stripper missed, calls to stripped code); and, if the project has one,
# .freemius-free-denylist (one extended regex per line, # comments) of strings that must never
# reach the free build, such as premium class names or API endpoints.
# Accepted scan findings live in .freemius-free-scan-ignore, each with its reason.
# Exits 1 on any failure. Run by freemius-free-check.yml on an alpha, and by release.yml before
# the free build is pushed to the free repo or wordpress.org.
set -uo pipefail

FREE_ZIP="${1:?Usage: $0 <free.zip> [<premium.zip>]}"
PREMIUM_ZIP="${2:-}"
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
DIR="__PLUGIN_DIR__"
MAIN="__MAIN_FILE__"
HERE="$(cd "$(dirname "$0")" && pwd)"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
fail=0
bad() { echo "FAIL $*"; fail=1; }

unzip -q "$FREE_ZIP" -d "$W/free" || { echo "FAIL cannot unzip $FREE_ZIP"; exit 1; }
F="$W/free/$DIR"
[ -f "$F/$MAIN" ] || { echo "FAIL $FREE_ZIP has no $DIR/$MAIN"; exit 1; }
P=""
if [ -n "$PREMIUM_ZIP" ]; then
	unzip -q "$PREMIUM_ZIP" -d "$W/premium" || { echo "FAIL cannot unzip $PREMIUM_ZIP"; exit 1; }
	P="$W/premium/$DIR"
fi
echo "Free build: $FREE_ZIP ($(grep -m1 -oP 'Version:\s*\K\S+' "$F/$MAIN"))"

# 1. Every file parses, on the PHP that runs this (CI: the plugin's Requires PHP and 8.4).
lint=0
while IFS= read -r -d '' f; do
	out=$(php -l "$f" 2>&1) || { bad "php -l ${f#"$W/free/"}: $(echo "$out" | head -1)"; lint=1; }
done < <(find "$F" -name '*.php' -not -path '*/node_modules/*' -print0)
[ "$lint" = 0 ] && echo "ok   php -l: every file parses ($(php -r 'echo PHP_VERSION;'))"

# 2. @fs_premium_only paths, read from the premium main file (or, without one, the free one,
#    which keeps the header). Freemius splits the list on commas and spaces.
hdr="${P:-$F}/$MAIN"
paths=$(grep -oP '@fs_premium_only\s+\K.*' "$hdr" | tr ', ' '\n\n' | sed '/^$/d')
for p in $paths; do
	[ -e "$F/${p#/}" ] && bad "@fs_premium_only path present in the free build: $p"
done
[ -n "$paths" ] && echo "ok   @fs_premium_only: $(echo "$paths" | wc -l) paths checked"

# 3. Files or folders named like premium code (Freemius strips *__premium_only*; a typo isn't).
names=$(cd "$F" && find . -iname '*prem*only*' -not -path '*/freemius/*' -not -path '*/node_modules/*' | sed 's|^\./||')
if [ -n "$names" ]; then
	while IFS= read -r n; do bad "premium-named path in the free build: $n"; done <<< "$names"
else
	echo "ok   no premium-named files or folders"
fi

# 4. Token scan.
scan=$(php "$HERE/free-build-scan.php" "$F" "$P" "$ROOT/.freemius-free-scan-ignore"); rc=$?
[ -n "$scan" ] && echo "$scan" | sed 's/^/     /'
if [ "$rc" = 0 ]; then echo "ok   code scan"; else bad "code scan (above)"; fi

# 5. Project denylist.
if [ -f "$ROOT/.freemius-free-denylist" ]; then
	while IFS= read -r re; do
		case "$re" in ''|'#'*) continue ;; esac
		hits=$(grep -rnE --exclude-dir=freemius --exclude-dir=node_modules -- "$re" "$F" | sed "s|$W/free/||" | head -5)
		[ -n "$hits" ] && bad "denylisted /$re/ found:"$'\n'"$(echo "$hits" | sed 's/^/     /')"
	done < "$ROOT/.freemius-free-denylist"
	echo "ok   denylist checked"
fi

if [ "$fail" = 0 ]; then
	echo "PASS free build is clean"
else
	echo "BLOCKED: the free build has premium code or calls to stripped code. Fix the guards in the premium source, upload a new alpha and check again." >&2
fi
exit "$fail"
