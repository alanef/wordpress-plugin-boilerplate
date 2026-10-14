<!-- Managed by wordpress-plugin-boilerplate/tooling (deploy-live.own-site.md) - fix there first, then run bin/sync-tooling.sh -->
# Deploy live: __PLUGIN_NAME__

Run by `/tk-deploy live`. This plugin runs on our own hosting (`"pipeline": "own-site"`,
site `__HOSTING__` in `.tooling.json`). **Never deploy it directly.** Production deploys on
our hosting go through HOSTING DevOps with Alan's approval. This command checks the release
is ready, builds the zip, and hands off.

<!-- include preconditions -->

For this pipeline the confirmation is for building and handing off; tagging comes later,
after HOSTING DevOps reports the deploy done.

## Build the zip

```bash
(cd $P && composer run-script build)
cp $P/zipped/__PLUGIN_DIR__-free.zip $P/zipped/__PLUGIN_DIR__-$V.zip
unzip -p $P/zipped/__PLUGIN_DIR__-$V.zip __PLUGIN_DIR__/__MAIN_FILE__ | grep -m1 -oP 'Version:\s*\K\S+'   # must be $V
sha256sum $P/zipped/__PLUGIN_DIR__-$V.zip
```

Stop if the build fails or the zipped version is not `$V`.

## Hand off to HOSTING DevOps

Do not upload, copy, rsync or activate anything on the server. Write the hand-off for the
user to pass to HOSTING DevOps, and stop:

- Site: `__HOSTING__`
- Plugin: `__PLUGIN_DIR__` `$V` (from `$PREV`), commit `$(git -C $P rev-parse --short HEAD)`
- Zip: `$P/zipped/__PLUGIN_DIR__-$V.zip` and its sha256
- Changes: the `= $V =` section of `__PLUGIN_DIR__/changelog.txt`
- Anything the release notes say the site needs (migrations, settings, cache flush)
- Rollback: the `$PREV` build (`git -C $P checkout $PREV` and `composer run build`)

## After HOSTING DevOps confirms the deploy

Only when the user reports that HOSTING DevOps has deployed `$V` and it is verified:

1. Ask for explicit confirmation to tag. Then
   `git -C $P tag $TAG && GIT_TERMINAL_PROMPT=0 git -C $P push origin $TAG`
   (fires release.yml, which records the GitHub release). A failed push is reported, never
   retried or forced.
2. Watch it: `gh run list -R __REPO__ --workflow release.yml --limit 5`, then
   `gh run watch <id> -R __REPO__ --exit-status`.

<!-- include changelog -->

<!-- include youtrack -->

Then report: hand-off contents, tag, release.yml run, changelog result, YouTrack updates. Put any `CHANGELOG PAGE NOT UPDATED` line on its own, first.
