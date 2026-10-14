## Publish the changelog

`update-changelog.sh` is on PATH from dev_scripts. It reads `.env.wordpress` in the
project root (gitignored: site, credentials, `WP_POST_ID`, `CHANGELOG_FILE`) and publishes
`__PLUGIN_DIR__/changelog.txt` to the KB page `$KB`.

- `$KB` empty: no KB changelog page. Note "no KB changelog page" and go on; nothing to warn.
- `$KB` set and `.env.wordpress` complete (as checked in the preconditions):

  ```bash
  (cd $P && update-changelog.sh); echo "exit $?"
  curl -s "$KB" | grep -c "Version $V"     # must be at least 1
  ```

- `$KB` set but the user accepted, at the preconditions, releasing without `.env.wordpress`:
  do not run it.

If the publish was skipped, exited non-zero, or the page does not show `Version $V`, the
final report MUST carry a separate, prominent line, never folded into a summary:

```
CHANGELOG PAGE NOT UPDATED: <reason: no .env.wordpress / missing WP_POST_ID / update-changelog.sh exit N / page does not show Version $V>, page $KB
```

The release has already shipped, so carry on to YouTrack; do not re-tag or re-run the release.
