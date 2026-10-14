#!/usr/bin/env bash
# Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh
#
# Set the release version everywhere __PLUGIN_NAME__ keeps it, then prove they agree.
# Called by /tk-release X.Y.Z. Safe to run again: a place already at X.Y.Z is left alone.
#
#   scripts/release/bump-version.sh X.Y.Z           set, then read back
#   scripts/release/bump-version.sh --check X.Y.Z   read back only (used by /tk-deploy live)
#
#   plugin header Version:                } CI fails the build if these differ,
#   version constant ($CONST, if any)     } and release.yml if the tag differs
#   readme.txt Stable tag                 }
#   package.json version                    root and plugin dir, where the file has a "version" key
#   languages/__TEXT_DOMAIN__.pot           Project-Id-Version, when the .pot carries a version
#   changelog.txt                           "= Unreleased =" becomes "= X.Y.Z =", or the top
#                                           heading must already be X.Y.Z
set -euo pipefail

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
V="${1:-}"

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
P="$ROOT/__PLUGIN_DIR__"
MAIN="$P/__MAIN_FILE__"
README="$P/readme.txt"
CHANGELOG="$P/changelog.txt"
CONST="__VERSION_CONSTANT__"
POT="$(find "$P" -maxdepth 3 -name '__TEXT_DOMAIN__.pot' -not -path '*/vendor/*' | head -1)"

# A release is X.Y.Z. X.Y is accepted only where this plugin already uses two-part
# versions (a changelog heading or a tag), so a typo cannot slip through as "1.4".
two_part=0
if grep -qE '^= [0-9]+\.[0-9]+ =$' "$CHANGELOG" 2>/dev/null \
	|| grep -qE '^v?[0-9]+\.[0-9]+$' <<< "$(git -C "$ROOT" tag -l)"; then
	two_part=1
fi
if [[ "$V" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { [ "$two_part" = 1 ] && [[ "$V" =~ ^[0-9]+\.[0-9]+$ ]]; }; then
	:
else
	echo "Usage: $0 [--check] X.Y.Z  (no v prefix, no prerelease suffix: this is a release)" >&2
	[[ "$V" == *-* ]] && echo "Refusing prerelease version '$V': drop the suffix to release." >&2
	exit 1
fi

# First match only, flexible whitespace. Q is the version quoted for a perl regex.
Q="${V//./\\.}"
set_first() { perl -0pi -e "$1" "$2"; }
# A package.json without a "version" key (a private dev project) carries no version to keep in step.
has_version() { [ -f "$1" ] && grep -qE '"version"[[:space:]]*:' "$1"; }

if [ "$CHECK" = 0 ]; then
	set_first "s/^([ \t]*\*?[ \t]*Version:[ \t]*)\S+/\${1}$V/m" "$MAIN"
	if [ -n "$CONST" ]; then
		set_first "s/(define\(\s*['\"]$CONST['\"]\s*,\s*['\"])[^'\"]*(['\"])/\${1}$V\${2}/" "$MAIN"
	fi
	set_first "s/^(Stable tag:[ \t]*)\S+/\${1}$V/m" "$README"
	for pj in "$ROOT/package.json" "$P/package.json"; do
		has_version "$pj" && set_first "s/(\"version\"\s*:\s*\")[^\"]*\"/\${1}$V\"/" "$pj"
	done
	if [ -n "$POT" ]; then
		set_first "s/(\"Project-Id-Version: [^\"\\\\]*? )[0-9][0-9A-Za-z.+-]*(\\\\n\")/\${1}$V\${2}/" "$POT"
	fi
	if [ -f "$CHANGELOG" ]; then
		top="$(grep -m1 -E '^= .+ =$' "$CHANGELOG" || true)"
		if [ "$top" = "= Unreleased =" ]; then
			set_first "s/^= Unreleased =\$/= $V =/m" "$CHANGELOG"
		fi
	fi
fi

# Read every place back. A substitution that matched nothing changes nothing silently,
# so the only proof is what the files now say.
declare -A found=(
	[header]="$(grep -m1 -oP '^[ \t]*\*?[ \t]*Version:[ \t]*\K\S+' "$MAIN" || true)"
	[stable_tag]="$(grep -m1 -oP '^Stable tag:[ \t]*\K\S+' "$README" || true)"
	[changelog]="$(grep -m1 -oP '^= \K.+(?= =$)' "$CHANGELOG" 2>/dev/null || echo 'missing changelog.txt')"
)
if [ -n "$CONST" ]; then
	found[constant]="$(grep -m1 -oP "define\(\s*['\"]$CONST['\"]\s*,\s*['\"]\K[^'\"]*" "$MAIN" || true)"
fi
for pj in "$ROOT/package.json" "$P/package.json"; do
	has_version "$pj" && found["package_json:${pj#"$ROOT"/}"]="$(grep -m1 -oP '"version"\s*:\s*"\K[^"]*' "$pj")"
done
if [ -n "$POT" ]; then
	pot_v="$(grep -m1 -oP '"Project-Id-Version: [^"\\]*? \K[0-9][0-9A-Za-z.+-]*(?=\\n")' "$POT" || true)"
	if [ -n "$pot_v" ]; then
		found[pot]="$pot_v"
	else
		echo "WARNING ${POT#"$ROOT"/} Project-Id-Version carries no version; regenerate it with 'composer run make-pot'." >&2
	fi
fi

fail=0
for k in "${!found[@]}"; do
	if [ "${found[$k]}" != "$V" ]; then
		echo "MISMATCH $k: '${found[$k]}' (want $V)" >&2
		fail=1
	fi
done

if grep -q '^= Unreleased =$' "$CHANGELOG" 2>/dev/null; then
	echo "MISMATCH changelog: an '= Unreleased =' heading is still there" >&2
	fail=1
fi
# The release section must say something: a version nobody can read the reason for is not done.
if [ -f "$CHANGELOG" ] && ! awk -v h="= $V =" '$0==h{s=1;next} /^= .+ =$/{s=0} s&&/^\*/{n++} END{exit n?0:1}' "$CHANGELOG"; then
	echo "MISMATCH changelog: '= $V =' has no '* Type: ...' entries" >&2
	fail=1
fi

[ "$fail" = 0 ] || exit 1

# Upgrade notices are written, not generated. Warn rather than invent one.
if grep -q '^== Upgrade Notice ==' "$README" && ! grep -q "^= $Q =$" <<< "$(sed -n '/^== Upgrade Notice ==/,$p' "$README")"; then
	echo "WARNING readme.txt has no '= $V =' upgrade notice. Write one if this release needs it." >&2
fi

if [ "$CHECK" = 1 ]; then
	echo "Version $V agrees in: $(printf '%s ' "${!found[@]}" | tr ' ' '\n' | sort | xargs)."
else
	echo "Version $V set and read back in: $(printf '%s ' "${!found[@]}" | tr ' ' '\n' | sort | xargs)."
fi
