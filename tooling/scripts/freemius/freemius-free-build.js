#!/usr/bin/env node
// Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh
//
// Uploads a development (alpha) build to Freemius and downloads the free zip Freemius makes
// from it, so the free build can be checked before it is ever released. Freemius keeps the
// upload as a pending version: nobody is offered it until someone releases it in the
// dashboard, so a development upload is safe (Alan, 2026-10-29).
//
// Only prerelease versions (X.Y.Z-alpha.N and the like) are accepted. A release version is
// uploaded by release.yml, never by a check, so a check can never stand in for a release.
//
// Env: FREEMIUS_DEV_ID, FREEMIUS_PUBLIC_KEY, FREEMIUS_SECRET_KEY, FREEMIUS_PLUGIN_ID,
//      PLUGIN_ZIP_PATH (premium zip), PLUGIN_VERSION, FREE_ZIP_PATH (where to write the free zip).
// Writes free_zip and tag_id to $GITHUB_OUTPUT when set.

const Freemius = require('freemius-node-sdk');
const fs = require('fs');
const path = require('path');

const env = (k) => {
    const v = process.env[k];
    if (!v) {
        console.error(`ERROR: ${k} is not set`);
        process.exit(1);
    }
    return v;
};
const devId = env('FREEMIUS_DEV_ID');
const publicKey = env('FREEMIUS_PUBLIC_KEY');
const secretKey = env('FREEMIUS_SECRET_KEY');
const pluginId = env('FREEMIUS_PLUGIN_ID');
const zipPath = path.resolve(env('PLUGIN_ZIP_PATH'));
const version = env('PLUGIN_VERSION');
const freeZip = path.resolve(env('FREE_ZIP_PATH'));

if (!/^\d+(\.\d+)+-[0-9A-Za-z.-]+$/.test(version)) {
    console.error(`ERROR: ${version} is not a prerelease version. This check uploads alpha builds only (X.Y.Z-alpha.N); releases go through release.yml.`);
    process.exit(1);
}
if (!fs.existsSync(zipPath)) {
    console.error(`ERROR: premium zip not found: ${zipPath}`);
    process.exit(1);
}

const developer = new Freemius('developer', devId, publicKey, secretKey, false);
const out = (k, v) => process.env.GITHUB_OUTPUT && fs.appendFileSync(process.env.GITHUB_OUTPUT, `${k}=${v}\n`);

console.log(`Uploading ${path.basename(zipPath)} (${version}) to Freemius plugin ${pluginId} as a pending version`);
developer.Api(`plugins/${pluginId}/tags.json`, 'POST', { add_contributor: false }, { file: zipPath }, (response) => {
    let tag;
    try {
        tag = JSON.parse(response);
    } catch (e) {
        console.error('ERROR: unexpected Freemius response:', String(response).slice(0, 500));
        process.exit(1);
    }
    if (tag.error) {
        console.error('ERROR from Freemius:', JSON.stringify(tag.error));
        if (/exist/i.test(JSON.stringify(tag.error))) {
            console.error(`Freemius already has ${version}. Bump the alpha number (bump only N) and run the check again.`);
        }
        process.exit(1);
    }
    console.log(`Tag ${tag.id}: version ${tag.version}, release mode ${tag.release_mode}, has free: ${tag.has_free}`);
    if (tag.release_mode && tag.release_mode !== 'pending') {
        // Never expected for a fresh upload; say so loudly rather than carry on quietly.
        console.error(`ERROR: Freemius set release mode "${tag.release_mode}", not pending. Check the version in the dashboard now.`);
        process.exit(1);
    }
    if (!tag.has_free) {
        console.error('ERROR: Freemius generated no free version for this upload, so there is nothing to check.');
        process.exit(1);
    }
    developer.Api(`plugins/${pluginId}/tags/${tag.id}.zip`, 'GET', {}, {}, (zip) => {
        fs.writeFileSync(freeZip, zip);
        const size = fs.statSync(freeZip).size;
        if (size < 1000) {
            console.error(`ERROR: the free zip Freemius returned is ${size} bytes: ${String(zip).slice(0, 300)}`);
            process.exit(1);
        }
        console.log(`Free build written to ${freeZip} (${size} bytes)`);
        out('free_zip', freeZip);
        out('tag_id', tag.id);
        console.log(`::notice::${version} is pending in Freemius (tag ${tag.id}); it is not offered to anyone unless released.`);
    });
});
