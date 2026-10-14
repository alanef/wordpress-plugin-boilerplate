## YouTrack

If `$KEY` is empty, skip this step and say so: no `.env.youtrack` `YOUTRACK_PROJECT` and no
`youtrack_project` pin in `.tooling.json`.

Issues in the release: the `Issues Included` table in `.sdlc/releases/$V/RELEASE_NOTES.md`,
else ids at the start of commit subjects in range
(`git -C $P log --format=%s $PREV..$TAG | grep -oE "^$KEY-[0-9]+" | sort -u`), not body
mentions.

Decide per issue whether it shipped plugin code: list the paths its commits in range touch,
and check whether any is inside `__PLUGIN_DIR__/`. Decide by path, never by commit subject:

```bash
ID=<issue id>   # \b keeps QPP-6 from matching QPP-61
for c in $(git -C $P log --format=%H --grep="^$ID\b" -E $PREV..$TAG); do
  git -C $P diff-tree --no-commit-id --name-only -r $c
done | grep -q '^__PLUGIN_DIR__/' && echo shipped || echo non-shipping
```

For each issue:

- Stage: `Deployed`, **only if it shipped plugin code**. An issue whose commits in range touch
  only paths outside `__PLUGIN_DIR__/` (tests, tooling, marketing, docs) keeps its Stage as it is.
- Resolution: `Done`, if the issue is not already resolved.
- Fix versions: `$V`, only if that version already exists in the project's Fix versions
  bundle (check the field schema with `get_issue_fields_schema`). If it does not, say so in
  the report and leave the field alone; never create the version.
- Comment, on every issue in range including non-shipping ones: `Released in $V`, with the
  GitHub release link (`https://github.com/__REPO__/releases/tag/$TAG`) and, for anything
  user-visible, one line on what changed.
