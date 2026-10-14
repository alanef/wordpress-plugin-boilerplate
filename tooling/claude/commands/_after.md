## Publish the changelog

`update-changelog.sh` is on PATH from dev_scripts. It reads `.env.wordpress` in the
project root (gitignored: site, credentials, KB post id, `CHANGELOG_FILE`) and finds
`__PLUGIN_DIR__/changelog.txt` itself. Only some plugins have that file.

```bash
if [ -f $P/.env.wordpress ]; then (cd $P && update-changelog.sh); else echo "no .env.wordpress: KB changelog not published for this plugin"; fi
```

A non-zero exit means the KB update failed. The release has already shipped, so report it
and carry on to YouTrack; do not re-tag or re-run the release.

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
