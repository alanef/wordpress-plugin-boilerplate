## YouTrack

If `$KEY` is empty, skip this step and say so: no `.env.youtrack` `YOUTRACK_PROJECT` and no
`youtrack_project` pin in `.tooling.json`.

Issues in the release: the `Issues Included` table in `.sdlc/releases/$V/RELEASE_NOTES.md`,
else ids at the start of commit subjects in range
(`git -C $P log --format=%s $PREV..$TAG | grep -oE "^$KEY-[0-9]+" | sort -u`), not body
mentions. For each:

- Stage: `Deployed`
- Comment: `Released in $V`, with the GitHub release link
  (`https://github.com/__REPO__/releases/tag/$TAG`) and, for anything user-visible, one line
  on what changed.
