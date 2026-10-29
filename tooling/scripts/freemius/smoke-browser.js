#!/usr/bin/env node
// Managed by wordpress-plugin-boilerplate/tooling - fix there first, then run bin/sync-tooling.sh
//
// Browser half of smoke-free-build.sh. A PHP-clean page can still be broken: a script that
// throws on load (a variable localized on a handle only the premium build registers) leaves a
// block missing from the inserter with HTTP 200 and an empty debug.log (DEE 6.9.0-beta.4).
//
//   node smoke-browser.js <base url> <plugin dir> <paths file> [block name...]
//
// Logs in as admin, loads every path in the paths file and the block editor, and:
//   FAIL  an uncaught JavaScript error from one of the plugin's scripts
//   FAIL  a plugin asset (under /plugins/<dir>/) that does not load (4xx/5xx or failed)
//   FAIL  a block whose block.json ships in the build but is not registered in the editor
//   WARN  uncaught errors from other scripts, console errors from the plugin's scripts
// Exit code 1 on any FAIL.

const { chromium } = require('playwright');
const fs = require('fs');

const [base, dir, pathsFile, ...blocks] = process.argv.slice(2);
if (!base || !dir || !pathsFile) {
    console.error('Usage: smoke-browser.js <base url> <plugin dir> <paths file> [block name...]');
    process.exit(2);
}
const mine = (s) => String(s || '').includes(`/plugins/${dir}/`);
const paths = [...new Set(fs.readFileSync(pathsFile, 'utf8').split('\n').filter(Boolean))];
let fail = 0;
let pageFailed = false;
const bad = (m) => { console.log(`FAIL ${m}`); fail = 1; pageFailed = true; };

(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage();
    let where = '';
    page.on('pageerror', (e) => {
        const m = `${where}: uncaught ${e.name}: ${e.message}`;
        mine(e.stack) ? bad(m) : console.log(`WARN ${m}`);
    });
    page.on('console', (msg) => {
        if (msg.type() === 'error' && mine(msg.location().url)) console.log(`WARN ${where}: console error: ${msg.text()}`);
    });
    page.on('response', (r) => { if (mine(r.url()) && r.status() >= 400) bad(`${where}: ${r.url()} returned ${r.status()}`); });
    page.on('requestfailed', (r) => { if (mine(r.url())) bad(`${where}: ${r.url()} failed: ${r.failure()?.errorText}`); });

    await page.goto(`${base}/wp-login.php`);
    await page.fill('#user_login', 'admin');
    await page.fill('#user_pass', 'password');
    await Promise.all([page.waitForNavigation(), page.click('#wp-submit')]);

    const load = async (path) => {
        where = path;
        pageFailed = false;
        try {
            await page.goto(base + path, { waitUntil: 'networkidle', timeout: 45000 });
            if (!pageFailed) console.log(`ok   browser ${path}`);
        } catch (e) {
            bad(`${path}: did not load in the browser: ${e.message.split('\n')[0]}`);
        }
    };
    const editor = '/wp-admin/post-new.php';
    for (const p of paths) if (p !== editor) await load(p);

    await load(editor);
    try {
        await page.waitForFunction(() => window.wp && wp.blocks && wp.blocks.getBlockTypes().length > 0, null, { timeout: 45000 });
        const missing = await page.evaluate((names) => names.filter((n) => !wp.blocks.getBlockType(n)), blocks);
        for (const n of blocks) {
            missing.includes(n) ? bad(`block ${n} ships a block.json but is not registered in the editor (not in the inserter)`) : console.log(`ok   block ${n} registered`);
        }
    } catch (e) {
        bad(`the block editor did not start: ${e.message.split('\n')[0]}`);
    }

    await browser.close();
    process.exit(fail);
})().catch((e) => {
    console.log(`FAIL browser check could not run: ${e.message}`);
    process.exit(1);
});
