<!-- Managed by wordpress-plugin-boilerplate/tooling (deploy-live.free.md) - fix there first, then run bin/sync-tooling.sh -->
# Deploy live: __PLUGIN_NAME__

Run by `/tk-deploy live`. Releases the version already set in the plugin header through
the single-tag pipeline: one tag here runs `release.yml`, which re-runs the checks, creates
the GitHub release with `__PLUGIN_DIR__-$V.zip` attached and deploys to what `Type: __RELEASE_TYPE__`
in `__PLUGIN_DIR__/readme.txt` asks for.

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

## Confirm what landed

```bash
gh release view $TAG -R __REPO__ --json assets -q '.assets[].name'   # must list __PLUGIN_DIR__-$V.zip
```
<!-- if wporg -->

WordPress.org SVN must have the tag:

```bash
curl -s https://plugins.svn.wordpress.org/__SVN_SLUG__/tags/ | grep -c ">$V/<"   # must be 1
```

The wordpress.org API
(`https://api.wordpress.org/plugins/info/1.2/?action=plugin_information&request%5Bslug%5D=__SVN_SLUG__`)
will NOT show `$V` yet if release confirmation is on: the release waits for a committer to
confirm it. That is expected; see the manual steps.
<!-- endif -->
<!-- if fsmanual -->

Freemius: `release.yml` resolves the Freemius target (it is in the run summary) but the
single-tag workflow has **no Freemius deploy step yet**, so nothing was uploaded there.
That is a manual step below; do not treat its absence from the run as a failure.
<!-- endif -->
<!-- if fsworkflow -->

Freemius: this plugin's own `release.yml` uploads the build to Freemius (id __FREEMIUS_ID__)
as **beta**. Its deploy job must have succeeded; check the run summary for the uploaded
version. Do not upload the zip again by hand.
<!-- endif -->

<!-- include changelog -->

<!-- include youtrack -->

## Tell the user what is still manual

Always end with these, explicitly:
<!-- if wporg -->

- **Confirm the release on wordpress.org.** Release confirmation holds `$V` until a
  committer approves it from the confirmation email or the plugin's release confirmation
  page. Until then the directory still serves `$PREV`.
<!-- endif -->
<!-- if fsworkflow -->
- **Freemius.** Promote $V from beta to released in the Freemius dashboard. The workflow
  already uploaded it; paying customers do not get the update until it is released there.
<!-- endif -->
<!-- if fsmanual -->
- **Freemius.** Upload `__PLUGIN_DIR__-$V.zip` from the GitHub release in the Freemius
  dashboard and promote it from beta to released. Paying customers do not get the update
  before it is released there.
<!-- endif -->
- Any server side follow-ups recorded in the release notes.

Then report: tag, release.yml run, what was confirmed, changelog result, YouTrack updates. Put any `CHANGELOG PAGE NOT UPDATED` line on its own, first.
