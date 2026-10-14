Stop at the first failure and report it. Never retry a tag push, never force
anything, never delete a tag to "try again". Use absolute paths throughout:
`CDPATH` is set on Alan's machines and sends a relative `cd` somewhere else.

```bash
P=$(git rev-parse --show-toplevel)
GIT_TERMINAL_PROMPT=0 git -C $P fetch origin --tags
V=$(grep -m1 -oP '^[ \t]*\*?[ \t]*Version:[ \t]*\K\S+' $P/__PLUGIN_DIR__/__MAIN_FILE__)
TAG=__TAG_PREFIX__$V          # this repo's tag style (pin "tag_prefix" in .tooling.json)
PREV=$(git -C $P tag -l | grep -E '^v?[0-9]+(\.[0-9]+)+$' | awk '{t=$0; sub(/^v/,"",t); print t" "$0}' | sort -V | tail -1 | cut -d' ' -f2)
KEY=$(grep -oP '^YOUTRACK_PROJECT=["'\'']?\K[A-Za-z0-9_]+' $P/.env.youtrack 2>/dev/null)
KEY=${KEY:-__YOUTRACK_PROJECT__}   # empty: YouTrack step is skipped with a note
```

Check `git -C $P remote get-url origin` names `__REPO__` before going on.

## Preconditions

All must hold, otherwise stop:

- On `__BRANCH__` and level with `origin/__BRANCH__`
  (`git -C $P rev-parse HEAD` = `git -C $P rev-parse origin/__BRANCH__`).
- No tracked changes: `git -C $P status --porcelain --untracked-files=no` is empty.
- Version agreement everywhere, no prerelease suffix, changelog heading in place:
  `$P/scripts/release/bump-version.sh --check $V` exits 0.
- Tag absent locally and on origin, in either style (release.yml fires on both):
  `git -C $P tag -l "$V" "v$V"` and
  `GIT_TERMINAL_PROMPT=0 git -C $P ls-remote --tags origin "refs/tags/$V" "refs/tags/v$V"` are empty.
- `$P/.sdlc/releases/$V/RELEASE_NOTES.md` exists (from `/tk-release $V`).
- `$P/.sdlc/releases/$V/TESTS_PASSED.md` exists, and its commit
  `C=$(grep -oP '^\*\*Commit:\*\* \K[0-9a-f]+' $P/.sdlc/releases/$V/TESTS_PASSED.md)`
  is an ancestor of HEAD (`git -C $P merge-base --is-ancestor $C HEAD`) with no plugin
  code changed since
  (`git -C $P diff --quiet $C HEAD -- __PLUGIN_DIR__/ ':!__PLUGIN_DIR__/changelog.txt'`).
  Otherwise re-run `$P/scripts/release/run-tests-and-mark.sh $V`. If the marker shows
  PHPUnit `SKIPPED`, say so to the user when asking for confirmation.
- `$P/.sdlc/releases/$V/DEPENDENCY_AUDIT.md` exists (from `scripts/release/check-dependencies.sh`).
- The latest Plugin Check run on `__BRANCH__` is for HEAD and succeeded:
  `gh run list -R __REPO__ --workflow checks.yml --branch __BRANCH__ --limit 1 --json headSha,status,conclusion`
  shows `headSha` = HEAD, `completed`, `success`.

Then show the user: `$PREV..HEAD` (`git -C $P log --oneline $PREV..HEAD`; no tags yet
means `$PREV` is empty, so show `git -C $P log --oneline -20` and say it is a first release), the issue ids
in range, the `= $V =` section of `__PLUGIN_DIR__/changelog.txt`, and exactly what the next
step will publish. **Ask for explicit confirmation before tagging.** Anything other than a
clear yes means stop.
