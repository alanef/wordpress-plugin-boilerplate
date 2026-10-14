<!-- Managed by wordpress-plugin-boilerplate/tooling (deploy-live.github.md) - fix there first, then run bin/sync-tooling.sh -->
# Deploy live: __PLUGIN_NAME__

Run by `/tk-deploy live`. Releases the version already set in the plugin header. This
plugin has no `Type:` header in `__PLUGIN_DIR__/readme.txt`, so it is released on GitHub
only: one tag here runs `release.yml`, which re-runs the checks and creates the GitHub
release with `__PLUGIN_DIR__-$V.zip` attached. Sites update themselves from that release
through `__PLUGIN_DIR__/includes/class-github-updater.php`.

<!-- include preconditions -->

## Tag and push

```bash
git -C $P tag $TAG && GIT_TERMINAL_PROMPT=0 git -C $P push origin $TAG
```

If the push fails, stop and report: the tag then exists only locally. Do not delete it,
retry or force; tell the user.

## Watch release.yml

```bash
gh run list -R __REPO__ --workflow release.yml --limit 5 --json databaseId,headBranch,status
gh run watch <id> -R __REPO__ --exit-status     # the run whose headBranch is $TAG
```

Run the watch in the background and wait for completion. Every job must succeed. On
failure show `gh run view <id> -R __REPO__ --log-failed` and stop.

## Confirm the release asset

The self-updater builds `releases/download/<tag>/__PLUGIN_DIR__-<version>.zip`, so that
exact asset name must exist or every site's update fails:

```bash
gh release view $TAG -R __REPO__ --json assets,isLatest -q '.isLatest, .assets[].name'
# must print true and list __PLUGIN_DIR__-$V.zip
```

Sites pick the update up on their next check: the updater caches the latest release for
6 hours (1 hour after a failure). "Check again" on Dashboard -> Updates refreshes it at once.

<!-- include after -->

## Finish

Report: tag, release.yml run, the asset confirmed, changelog result, YouTrack updates, and
that sites will see `$V` within 6 hours.
