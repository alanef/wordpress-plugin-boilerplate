## Publish the changelog

`update-changelog.sh` is on PATH from dev_scripts. It reads `.env.wordpress` in the
project root (gitignored: site, credentials, KB post id, `CHANGELOG_FILE`) and finds
`__PLUGIN_DIR__/changelog.txt` itself. Only some plugins have that file.

```bash
if [ -f $P/.env.wordpress ]; then (cd $P && update-changelog.sh); else echo "no .env.wordpress: KB changelog not published for this plugin"; fi
```

A non-zero exit means the KB update failed. The release has already shipped, so report it
and carry on to YouTrack; do not re-tag or re-run the release.
