#!/usr/bin/env python3
"""
Roll the canonical Fullworks free-plugin tooling out to a plugin repository.

    bin/sync-tooling.sh /path/to/plugin-repo [--svn-slug SLUG] [--port N] [--tests-port N] [--php-version 8.4]

Everything under tooling/ in this repository is the source of truth. Fix problems there
first, then re-run this script against each plugin repository. Values are detected from
the target (plugin directory, main file, default branch, version constant, wp-env ports)
and can be pinned in an optional .tooling.json at the target root:

    {"svn_slug": "...", "port": 8710, "tests_port": 8711, "php_version": "8.4", "plugin_dir": "...",
     "tag_prefix": "v", "youtrack_project": "KEY", "pipeline": "freemius-two-tag" | "own-site",
     "free_repo": "alanef/...", "freemius_id": "1234", "changelog_url": "https://...", "hosting": "site-slug"}
"""
import argparse, glob, json, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLING = os.path.join(os.path.dirname(HERE), "tooling")

PHP_PLATFORM = {"7.4": "7.4.33", "8.0": "8.0.30", "8.1": "8.1.31", "8.2": "8.2.27", "8.3": "8.3.15", "8.4": "8.4.2"}
ALL_PHP = ["7.4", "8.0", "8.1", "8.2", "8.3", "8.4"]
LEGACY_WORKFLOWS = ["php.yml", "plugincheck.yml", "plugin_ check.yml", "plugin_check.yml", "test-svn.yml"]
LEGACY_SCRIPTS = {"lint", "lint:fix", "phpcs-security", "phpcompat", "test:unit", "test:integration", "test-verbose",
                  "phpcs-fix", "plugin:install", "plugin:update", "plugin:dump", "compat:5.6", "post-update-cmd",
                  "make-pot", "build", "phpcs", "check", "test", "plugin-update"}
CANON_DEV = {"squizlabs/php_codesniffer", "wp-coding-standards/wpcs", "phpcompatibility/phpcompatibility-wp",
             "phpunit/phpunit", "yoast/phpunit-polyfills", "dealerdirect/phpcodesniffer-composer-installer", "php"}
GITIGNORE_DROP = {"package-lock.json", "/package-lock.json", "composer.lock", "/composer.lock", "yarn.lock"}

log = lambda *a: print("  -", *a)
semver = lambda v: tuple(int(x) for x in re.findall(r"\d+", v)[:3])  # "^11.14.0" -> (11, 14, 0)


def sh(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True).stdout.strip()


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def write(p, s, mode=None):
    os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)
    if mode:
        os.chmod(p, mode)


def header(main_php, key):
    m = re.search(r"^\s*\*?\s*" + re.escape(key) + r":\s*(.+?)\s*$", main_php, re.M)
    return m.group(1).strip() if m else ""


def detect(target, args):
    cfg = {}
    if os.path.exists(os.path.join(target, ".tooling.json")):
        cfg = json.load(open(os.path.join(target, ".tooling.json")))
    plugin_dir = args.plugin_dir or cfg.get("plugin_dir")
    if not plugin_dir:
        cands = []
        for d in sorted(os.listdir(target)):
            p = os.path.join(target, d)
            if d in ("dist", "node_modules", "vendor", "tests", "tooling", "bin") or d.startswith(".") or not os.path.isdir(p):
                continue
            if os.path.exists(os.path.join(p, "readme.txt")) and any("Plugin Name:" in read(f) for f in glob.glob(p + "/*.php")):
                cands.append(d)
        if len(cands) != 1:
            sys.exit("Could not determine plugin directory (candidates: %s). Set plugin_dir in .tooling.json." % cands)
        plugin_dir = cands[0]
    pdir = os.path.join(target, plugin_dir)
    main_file = next(os.path.basename(f) for f in sorted(glob.glob(pdir + "/*.php")) if "Plugin Name:" in read(f))
    main_php = read(os.path.join(pdir, main_file))
    php_min = header(main_php, "Requires PHP") or "7.4"
    if php_min not in ALL_PHP:
        php_min = "7.4"
    # The version constant: a define() named *VERSION* whose value looks like a version number.
    m = re.search(r"define\(\s*['\"]([A-Z0-9_]*VERSION[A-Z0-9_]*)['\"]\s*,\s*['\"]\d+\.\d+", main_php)
    branch = sh("git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null", target).replace("origin/", "") \
        or sh("git rev-parse --abbrev-ref HEAD", target)
    remote = sh("git remote get-url origin", target)
    rm = re.search(r"github\.com[:/]([^/]+/[^/.]+)", remote)
    repo = rm.group(1) if rm else "alanef/" + os.path.basename(target)
    # Release type, read exactly as release.yml does: no Type: header means GitHub only.
    readme = read(os.path.join(pdir, "readme.txt")) if os.path.exists(os.path.join(pdir, "readme.txt")) else ""
    tm = re.search(r"^[ \t]*Type:[ \t]*(.*)$", readme, re.M | re.I)
    release_type = tm.group(1).strip().lower() if tm else ""
    vconst = m.group(1) if m else ""
    prefix = re.sub(r"_?VERSION$", "", vconst) or "".join(w.capitalize() for w in re.split(r"[^a-zA-Z0-9]+", plugin_dir) if w)
    wpenv = {}
    if os.path.exists(os.path.join(target, ".wp-env.json")):
        wpenv = json.load(open(os.path.join(target, ".wp-env.json")))
    port = args.port or cfg.get("port") or wpenv.get("port") or wpenv.get("env", {}).get("development", {}).get("port") or 8888
    tests_port = args.tests_port or cfg.get("tests_port") or wpenv.get("testsPort") or wpenv.get("env", {}).get("tests", {}).get("port") or (port + 1)
    # Tag style: keep whatever the repo already does. The newest version-like tag decides
    # (release.yml accepts both); a repo with no tags gets the documented vX.Y.Z.
    tag_prefix = cfg.get("tag_prefix")
    if tag_prefix is None:
        tags = [t for t in sh("git tag -l --sort=-creatordate", target).splitlines() if re.match(r"^v?\d+(\.\d+)+$", t)]
        tag_prefix = "v" if not tags or tags[0].startswith("v") else ""
    # Which release pipeline /tk-deploy live follows. Only a .tooling.json pin selects the
    # non-standard ones; otherwise the readme Type: header decides, as in release.yml.
    # A Freemius plugin's pipeline can't be told from readme.txt (QPP releases in two tags
    # with its own release.yml), and a full sync would overwrite its workflows. Make it pinned.
    if not cfg.get("pipeline"):
        for root, dirs, files in os.walk(pdir):
            dirs[:] = [d for d in dirs if d not in ("vendor", "node_modules", "freemius", "freemius-sdk")]
            if any(f.endswith(".php") and "fs_dynamic_init(" in read(os.path.join(root, f)) for f in files):
                sys.exit("%s is a Freemius plugin (fs_dynamic_init) with no pipeline pinned. Add .tooling.json "
                         "with \"pipeline\": \"freemius-two-tag\" (plus free_repo, freemius_id, changelog_url) or "
                         "\"single-tag\", then re-run." % plugin_dir)
    pipeline = cfg.get("pipeline") or ("github" if release_type == "" else "single-tag")
    if pipeline not in ("github", "single-tag", "freemius-two-tag", "own-site"):
        sys.exit("Unknown pipeline %r in .tooling.json (use freemius-two-tag or own-site, or omit it)." % pipeline)
    missing = [k for k in {"freemius-two-tag": ("free_repo", "freemius_id", "changelog_url"), "own-site": ("hosting",)}.get(pipeline, ()) if not cfg.get(k)]
    if missing:
        sys.exit("pipeline %s needs %s in .tooling.json" % (pipeline, ", ".join(missing)))
    return dict(
        PLUGIN_DIR=plugin_dir, MAIN_FILE=main_file, PLUGIN_NAME=header(main_php, "Plugin Name") or plugin_dir,
        TEXT_DOMAIN=header(main_php, "Text Domain") or plugin_dir, PHP_MIN=php_min,
        PHP_PLATFORM=PHP_PLATFORM.get(php_min, php_min + ".0"), VERSION_CONSTANT=m.group(1) if m else "",
        BRANCH=branch, REPO=repo, REPO_NAME=repo.split("/")[-1], PORT=str(port), TESTS_PORT=str(tests_port),
        SVN_SLUG=args.svn_slug or cfg.get("svn_slug") or plugin_dir,
        PHP_VERSION=args.php_version or cfg.get("php_version") or "8.4",
        PHPUNIT_EXCLUDES=cfg.get("phpunit_exclude", []),
        RELEASE_TYPE=release_type, UPDATER_NS=prefix + "\\Updater",
        PLUGIN_CHECK_EXCLUDES="plugin_updater" if release_type == "" else "",
        VERSION=header(main_php, "Version"), TAG_PREFIX=tag_prefix, PIPELINE=pipeline,
        YOUTRACK_PROJECT=str(cfg.get("youtrack_project", "")), FREE_REPO=str(cfg.get("free_repo", "")),
        FREEMIUS_ID=str(cfg.get("freemius_id", "")), CHANGELOG_URL=str(cfg.get("changelog_url", "")),
        HOSTING=str(cfg.get("hosting", "")),
    ), wpenv


def render(text, v):
    compat = [p for p in ALL_PHP if float(p) >= float(v["PHP_MIN"])][::-1]
    scripts = "\n".join('    "compat:%s": "phpcs %s -s --standard=PHPCompatibilityWP --ignore=*/vendor/* --extensions=php --runtime-set testVersion %s",' % (p, v["PLUGIN_DIR"], p) for p in compat)
    calls = "\n".join('      "@compat:%s",' % p for p in compat)
    text = text.replace("__COMPAT_SCRIPTS__", scripts).replace("__COMPAT_CALLS__", calls)
    # CI runs on the default branch and on develop, because work lands on develop
    # and a check that only fires on the default branch reports nothing until merge.
    # Deduped, so a repo whose default already IS develop gets one entry, not two.
    branches = [v["BRANCH"]] + [b for b in ("develop",) if b != v["BRANCH"]]
    text = text.replace("__BRANCH_LIST__", "\n".join("      - %s" % b for b in branches))
    excludes = "\n".join("            <exclude>./tests/%s</exclude>" % e for e in v.get("PHPUNIT_EXCLUDES", []))
    text = text.replace("__PHPUNIT_EXCLUDES__\n", excludes + "\n" if excludes else "")
    note = " and `%s` in the main file" % v["VERSION_CONSTANT"] if v["VERSION_CONSTANT"] else ""
    text = text.replace("__VERSION_CONSTANT_NOTE__", note)
    for k, val in v.items():
        if isinstance(val, str):
            text = text.replace("__%s__" % k, val)
    return text


UPDATER_FILE = "includes/class-github-updater.php"
UPDATER_BLOCK = (
    "\n// Self-update from GitHub releases. Managed by wordpress-plugin-boilerplate/tooling: present only\n"
    "// while readme.txt has no Type: header (GitHub-only release).\n"
    "if ( file_exists( __DIR__ . '/%s' ) ) {\n"
    "\trequire_once __DIR__ . '/%s';\n"
    "}\n" % (UPDATER_FILE, UPDATER_FILE))
UPDATER_BLOCK_RE = re.compile(r"\n// Self-update from GitHub releases\. Managed by wordpress-plugin-boilerplate/tooling.*?\n}\n", re.S)
UPDATE_URI_RE = re.compile(r"^([ \t]*\*[ \t]*)Update URI:[ \t]*.*\n", re.M)


def sync_updater(t, v):
    """GitHub-only plugins update themselves from GitHub releases; typed ones must not."""
    P = lambda *a: os.path.join(t, *a)
    main = P(v["PLUGIN_DIR"], v["MAIN_FILE"])
    php = read(main)
    managed = [P(v["PLUGIN_DIR"], UPDATER_FILE), P("tests", "test-github-updater.php")]
    php = UPDATER_BLOCK_RE.sub("", php)
    if v["RELEASE_TYPE"]:
        for f in managed:
            if os.path.exists(f):
                os.remove(f); log("removed GitHub updater file", os.path.relpath(f, t), "(Type: %s)" % v["RELEASE_TYPE"])
        php, n = UPDATE_URI_RE.subn("", php)
        if n:
            log("removed Update URI header (Type: %s releases do not self-update)" % v["RELEASE_TYPE"])
    else:
        write(managed[0], render(read(os.path.join(TOOLING, "github-updater.php")), v))
        write(managed[1], render(read(os.path.join(TOOLING, "tests", "test-github-updater.php")), v))
        uri = "Update URI:        https://github.com/%s\n" % v["REPO"]
        if UPDATE_URI_RE.search(php):
            php = UPDATE_URI_RE.sub(lambda mm: mm.group(1) + uri, php, count=1)
        else:
            php = re.sub(r"^([ \t]*\*[ \t]*)(Requires PHP:.*\n)", lambda mm: mm.group(1) + mm.group(2) + mm.group(1) + uri, php, count=1, flags=re.M)
            if "Update URI:" not in php:
                sys.exit("Could not add an Update URI header: no 'Requires PHP:' line in %s" % main)
        php = php.rstrip("\n") + "\n" + UPDATER_BLOCK
        log("GitHub updater: %s, Update URI https://github.com/%s" % (UPDATER_FILE, v["REPO"]))
    write(main, php)


# ---------------------------------------------------------------------------
# Changelog: exactly one per plugin, <plugin-dir>/changelog.txt, wp.org style.
#
#   = Unreleased =            work in progress; bump-version.sh renames it at release
#   * Fixed: ...              typed bullets: Added / Changed / Deprecated / Removed / Fixed / Security
#   = 1.2.0 =
#
# It ships in the zip and is what update-changelog.sh publishes to the KB. The Keep a
# Changelog root CHANGELOG.md earlier syncs created is merged into it, then deleted.
# ---------------------------------------------------------------------------
CL_HEADING = re.compile(r"^=[ \t]+(.+?)[ \t]+=[ \t]*$")      # "= 1.2.0 =", not "== Changelog =="
MD_HEADING = re.compile(r"^##[ \t]+\[?([^\]\s]+)\]?")       # "## [1.2.0] - 2026-01-01", "## [Unreleased]"
MD_PLACEHOLDER = re.compile(r"Baseline\. Earlier history is in")


def cl_parse(text):
    """Split changelog.txt into (prelude lines, [(heading, [lines])]) keeping order and text."""
    prelude, sections = [], []
    for line in text.splitlines():
        m = CL_HEADING.match(line)
        if m and not line.startswith("=="):
            sections.append([m.group(1).strip(), []])
        elif sections:
            sections[-1][1].append(line)
        else:
            prelude.append(line)
    return prelude, sections


def cl_render(prelude, sections):
    out = list(prelude)
    for head, lines in sections:
        body = list(lines)
        while body and not body[-1].strip():
            body.pop()
        out += ["= %s =" % head] + body + [""]
    return "\n".join(out).rstrip("\n") + "\n"


def md_entries(text):
    """Real entries from a Keep a Changelog file: [(heading, [bullet lines])], placeholders skipped."""
    out, head, kind = [], None, None
    for line in text.splitlines():
        m = MD_HEADING.match(line)
        if m and not line.startswith("###"):
            head = "Unreleased" if m.group(1).lower() == "unreleased" else m.group(1)
            kind = None
            out.append([head, []])
            continue
        if head is None:
            continue
        k = re.match(r"^###[ \t]+(\w+)", line)
        if k:
            kind = k.group(1).capitalize()
            continue
        b = re.match(r"^[ \t]*[-*][ \t]+(.*)$", line)
        if b and not line.startswith((" ", "\t")):
            item = b.group(1).strip()
            if MD_PLACEHOLDER.search(item):
                continue
            out[-1][1].append("* %s: %s" % (kind, item) if kind else "* %s" % item)
        elif line.startswith((" ", "\t")) and line.strip() and out[-1][1]:
            out[-1][1][-1] += " " + line.strip()      # wrapped continuation of the previous bullet
    return [(h, items) for h, items in out if items]


def version_key(head):
    nums = re.findall(r"\d+", head.split()[0]) if head else []
    return tuple(int(n) for n in nums[:4]) if nums else (10 ** 9,)   # Unreleased sorts above everything


def sync_changelog(t, v, boilerplate=False):
    """Make <plugin-dir>/changelog.txt the one changelog. Idempotent; logs what it did."""
    P = lambda *a: os.path.join(t, *a)
    cl = P(v["PLUGIN_DIR"], "changelog.txt")
    md = P("CHANGELOG.md")
    if os.path.exists(cl):
        prelude, sections = cl_parse(read(cl))
        created = False
    else:
        readme = read(P(v["PLUGIN_DIR"], "readme.txt")) if os.path.exists(P(v["PLUGIN_DIR"], "readme.txt")) else ""
        m = re.search(r"^==[ \t]*Changelog[ \t]*==[ \t]*\n(.*?)(?=^==[ \t]*[^=\n]+==[ \t]*$|\Z)", readme, re.M | re.S | re.I)
        prelude, sections = cl_parse(m.group(1)) if m else ([], [])
        sections = [s for s in sections if re.match(r"^\d+(\.\d+)+", s[0])]
        if sections:
            log("changelog: created %s/changelog.txt from %d readme.txt entries" % (v["PLUGIN_DIR"], len(sections)))
        else:
            sections = [[v["VERSION"] or "1.0.0", ["* Baseline."]]]
            log("changelog: created %s/changelog.txt baseline = %s =" % (v["PLUGIN_DIR"], sections[0][0]))
        prelude, created = [], True
    # The boilerplate's own CHANGELOG.md is the boilerplate project's history, not plugin-name's.
    merged, md_removed = 0, False
    if not boilerplate and os.path.exists(md):
        for head, items in md_entries(read(md)):
            existing = next((s for s in sections if s[0].split()[0].lower() == head.lower()), None)
            if existing is None:
                existing = [head, []]
                idx = next((i for i, s in enumerate(sections) if version_key(s[0]) < version_key(head)), len(sections))
                sections.insert(idx, existing)
            have = {l.strip() for l in existing[1]}
            new = [i for i in items if i.strip() not in have]
            if new:
                body = existing[1]
                while body and not body[-1].strip():
                    body.pop()
                body += new
                merged += len(new)
        os.remove(md); md_removed = True
        subprocess.run(["git", "rm", "-q", "--cached", "--ignore-unmatch", "CHANGELOG.md"], cwd=t)
        log("changelog: merged %d CHANGELOG.md entr%s into %s/changelog.txt and removed CHANGELOG.md"
            % (merged, "y" if merged == 1 else "ies", v["PLUGIN_DIR"]))
    if created or merged:
        write(cl, cl_render(prelude, sections))
    elif not md_removed:
        log("changelog: %s/changelog.txt already canonical" % v["PLUGIN_DIR"])


# ---------------------------------------------------------------------------
# Release hooks (/tk-release) and the /tk-deploy live command.
# ---------------------------------------------------------------------------
DEPLOY_TEMPLATES = {"github": "deploy-live.github.md", "single-tag": "deploy-live.free.md",
                    "freemius-two-tag": "deploy-live.freemius-two-tag.md", "own-site": "deploy-live.own-site.md"}
COND_RE = re.compile(r"^<!-- if (\w+) -->\n(.*?)^<!-- endif -->\n", re.S | re.M)


def conditionals(text, v):
    """Keep <!-- if wporg|freemius|nowporg --> ... <!-- endif --> blocks that apply to this plugin's Type:."""
    flags = {"wporg": v["RELEASE_TYPE"] in ("free", "freemium"),
             "freemius": v["RELEASE_TYPE"] in ("freemium", "premium")}
    flags["nowporg"] = not flags["wporg"]
    return COND_RE.sub(lambda m: m.group(2) if flags[m.group(1)] else "", text)


MANAGED_MARK = "Managed by wordpress-plugin-boilerplate/tooling"
RELEASE_ONLY_PIPELINES = ("freemius-two-tag", "own-site")
RELEASE_ONLY_SKIPPED = (".github/workflows/*", "run-tests.sh", "phpunit.xml.dist", "tests/", "composer.json",
                        "package.json", ".wp-env.json", ".gitignore", "<plugin>/.distignore", "phpcs*.xml",
                        "GitHub updater", "CLAUDE.md / README.md blocks")


def sync_release(t, v, release_only=False):
    P = lambda *a: os.path.join(t, *a)
    for f in ("bump-version.sh", "check-dependencies.sh", "run-tests-and-mark.sh"):
        dest = P("scripts", "release", f)
        if f == "run-tests-and-mark.sh" and release_only:
            # These pipelines keep their own test setup, so their test gates are their own too
            # (QPP: composer test:unit, test:integration, compat:*). Never replace a hand-written one.
            if os.path.exists(dest) and MANAGED_MARK not in read(dest):
                log("release-only: kept project-specific scripts/release/run-tests-and-mark.sh")
                continue
            if not os.path.exists(dest):
                log("WARNING release-only: rendered the generic scripts/release/run-tests-and-mark.sh. It runs the "
                    "boilerplate's gates (composer run check, composer run build, npm test); check them against "
                    "this plugin's own composer scripts before relying on its marker.")
        write(dest, render(read(os.path.join(TOOLING, "scripts", "release", f)), v), 0o755)
    tpl = DEPLOY_TEMPLATES[v["PIPELINE"]]
    cmd = lambda f: read(os.path.join(TOOLING, "claude", "commands", f))
    text = re.sub(r"^<!-- include (\w+) -->\n", lambda m: cmd("_%s.md" % m.group(1)), cmd(tpl), flags=re.M)
    text = render(conditionals(text, v), v)
    left = sorted(set(re.findall(r"__[A-Z][A-Z0-9_]+__", text)))
    if left:
        sys.exit("unrendered placeholders in %s: %s" % (tpl, left))
    write(P(".claude", "commands", "deploy-live.md"), text)
    log("release: scripts/release/ hooks, .claude/commands/deploy-live.md from %s (tags %sX.Y.Z)" % (tpl, v["TAG_PREFIX"]))


def replace_block(existing, block, prepend):
    pat = re.compile(r"<!-- tooling:start.*?<!-- tooling:end -->\n?", re.S)
    if existing and pat.search(existing):
        return pat.sub(lambda _: block, existing, count=1)
    if not existing:
        return block
    return (block + "\n" + existing) if prepend else (existing.rstrip("\n") + "\n\n" + block)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target")
    ap.add_argument("--svn-slug"); ap.add_argument("--port", type=int); ap.add_argument("--tests-port", type=int)
    ap.add_argument("--php-version"); ap.add_argument("--plugin-dir")
    ap.add_argument("--release-only", action="store_true",
                    help="only the changelog, scripts/release/ and deploy-live.md (implied by the freemius-two-tag and own-site pipelines)")
    args = ap.parse_args()
    t = os.path.abspath(args.target)
    v, wpenv = detect(t, args)
    print("Syncing tooling into %s" % t)
    for k in ("PLUGIN_DIR", "MAIN_FILE", "PLUGIN_NAME", "BRANCH", "REPO", "VERSION_CONSTANT", "PHP_MIN", "PORT", "TESTS_PORT", "SVN_SLUG", "RELEASE_TYPE", "PIPELINE", "TAG_PREFIX"):
        log("%-16s %s" % (k, v[k]))
    P = lambda *a: os.path.join(t, *a)
    R = lambda rel: render(read(os.path.join(TOOLING, rel)), v)

    # Release-only: plugins on their own pipeline (QPP's Freemius two-tag release.yml, own-site
    # deploys) have workflows, composer/test setup and docs that differ on purpose. Syncing
    # those would break them, so only the release standard is applied.
    if args.release_only or v["PIPELINE"] in RELEASE_ONLY_PIPELINES:
        if os.path.isdir(P("tooling")):
            sys.exit("--release-only is for plugin repositories, not the boilerplate itself")
        log("RELEASE-ONLY sync (%s): changelog.txt, scripts/release/, .claude/commands/deploy-live.md"
            % ("--release-only" if args.release_only else "pipeline " + v["PIPELINE"]))
        sync_changelog(t, v)
        sync_release(t, v, release_only=True)
        log("release-only: skipped " + ", ".join(RELEASE_ONLY_SKIPPED))
        print("Done (release-only).")
        return

    # Workflows.
    for f in ("checks.yml", "release.yml"):
        write(P(".github", "workflows", f), R("workflows/" + f))
    for f in LEGACY_WORKFLOWS + glob.glob(P(".github", "workflows", "*.yml.example")):
        p = f if os.path.isabs(f) else P(".github", "workflows", f)
        if os.path.exists(p):
            os.remove(p); log("removed legacy", os.path.relpath(p, t))

    sync_updater(t, v)

    # Test runner and PHPUnit config.
    write(P("run-tests.sh"), R("run-tests.sh"), 0o755)
    write(P("phpunit.xml.dist"), R("phpunit.xml.dist"))
    for f in ("tests/phpunit.xml.dist", "phpunit.xml"):
        if os.path.exists(P(f)):
            os.remove(P(f)); log("removed", f, "(root phpunit.xml.dist is canonical)")
    bs = P("tests", "bootstrap.php")
    if not os.path.exists(bs) or "_manually_load_plugin" in read(bs) or "Managed by wordpress-plugin-boilerplate" in read(bs):
        write(bs, R("tests/bootstrap.php"))
    else:
        log("KEPT custom tests/bootstrap.php - check it works under run-tests.sh (WP_TESTS_DIR=/wordpress-phpunit)")
    smoke = P("tests", "test-plugin-load.php")
    tests = [f for f in glob.glob(P("tests", "**", "*.php"), recursive=True)
             if (os.path.basename(f).startswith("test-") or f.endswith("Test.php")) and f != smoke]
    if os.path.exists(smoke) and "Generated by wordpress-plugin-boilerplate/tooling" in read(smoke):
        write(smoke, R("tests/test-plugin-load.php")); log("refreshed generated smoke test tests/test-plugin-load.php")
    elif not tests and not os.path.exists(smoke):
        write(smoke, R("tests/test-plugin-load.php")); log("added smoke test tests/test-plugin-load.php")

    # Plugin production dependencies resolve fresh on every build: no plugin-dir lock file.
    plock = P(v["PLUGIN_DIR"], "composer.lock")
    if os.path.exists(plock):
        subprocess.run(["git", "rm", "-q", "--cached", "--ignore-unmatch", plock], cwd=t)
        os.remove(plock); log("removed plugin composer.lock (plugin deps resolve fresh on build)")

    # Plugin .distignore (union), root .gitignore (canonical + kept extras).
    di = P(v["PLUGIN_DIR"], ".distignore")
    canon = R("distignore").splitlines()
    extra = [l for l in (read(di).splitlines() if os.path.exists(di) else []) if l.strip() and l not in canon]
    if any(l.strip().lstrip("/") == "changelog.txt" for l in extra):
        log("%s/.distignore: dropped changelog.txt (the changelog ships in the zip)" % v["PLUGIN_DIR"])
        extra = [l for l in extra if l.strip().lstrip("/") != "changelog.txt"]
    write(di, "\n".join(canon + extra) + "\n")
    gi = P(".gitignore")
    canon = R("gitignore").splitlines()
    extra = [l for l in (read(gi).splitlines() if os.path.exists(gi) else []) if l.strip() and not l.startswith("#") and l not in canon and l.strip() not in GITIGNORE_DROP]
    write(gi, "\n".join(canon + (["# repository specific"] + extra if extra else [])) + "\n")
    if not os.path.exists(P(".wp-env.override.json.example")):
        write(P(".wp-env.override.json.example"), R("wp-env.override.json.example"))

    # package.json / composer.json.
    pj = json.loads(R("package.json"))
    if os.path.exists(P("package.json")):
        old = json.load(open(P("package.json")))
        dropped = sorted(set(old.get("scripts", {})) - {"wp-env", "start", "stop", "destroy", "test", "test:unit", "build"})
        if dropped:
            log("package.json: dropped non-standard scripts", dropped)
        if old.get("version"):
            pj["version"] = old["version"]
        for pkg, ver in old.get("devDependencies", {}).items():
            if pkg in pj["devDependencies"] and semver(ver) > semver(pj["devDependencies"][pkg]):
                pj["devDependencies"][pkg] = ver; log("package.json: kept newer dev package", pkg, ver)
    write(P("package.json"), json.dumps(pj, indent=2) + "\n")
    cj = json.loads(R("composer.json"))
    if os.path.exists(P("composer.json")):
        old = json.load(open(P("composer.json")))
        for pkg, ver in old.get("require-dev", {}).items():
            if pkg not in CANON_DEV:
                cj["require-dev"][pkg] = ver; log("composer.json: kept extra dev package", pkg)
        for name, val in old.get("scripts", {}).items():
            if name not in cj["scripts"] and name not in LEGACY_SCRIPTS and not name.startswith("compat:"):
                cj["scripts"][name] = val; log("composer.json: kept extra script", name)
    write(P("composer.json"), json.dumps(cj, indent=2) + "\n")
    if os.path.exists(P("phpcs.xml.dist")) and not os.path.exists(P("phpcs.xml")):
        shutil.move(P("phpcs.xml.dist"), P("phpcs.xml")); log("renamed phpcs.xml.dist -> phpcs.xml")
    for f in ("phpcs.xml", "phpcs_sec.xml"):
        if not os.path.exists(P(f)):
            write(P(f), R(f)); log("added", f)

    # .wp-env.json merge.
    env = dict(wpenv)
    plugins = env.get("plugins", [])
    sibling = [p for p in plugins if p.startswith("../")]
    if sibling:
        log("wp-env: moved sibling plugin paths to .wp-env.override.json.example (they do not exist in CI):", sibling)
        plugins = [p for p in plugins if p not in sibling]
        ov = {"plugins": ["./" + v["PLUGIN_DIR"]] + sibling}
        write(P(".wp-env.override.json.example"), json.dumps(ov, indent=2) + "\n")
    if "./" + v["PLUGIN_DIR"] not in plugins:
        plugins.insert(0, "./" + v["PLUGIN_DIR"])
    env["plugins"] = plugins
    if env.get("core") == "WordPress/WordPress#master":
        del env["core"]; log("wp-env: removed core=WordPress/WordPress#master (use the current release)")
    env["phpVersion"] = v["PHP_VERSION"]
    env["port"] = int(v["PORT"]); env["testsPort"] = int(v["TESTS_PORT"])
    cfgd = env.setdefault("config", {})
    cfgd.setdefault("WP_DEBUG_LOG", "/var/www/html/wp-content/debug.log")
    mp = env.setdefault("mappings", {})
    mp.update({"tests": "./tests", "vendor": "./vendor", "phpunit.xml.dist": "./phpunit.xml.dist"})
    if "env" in env:
        for e in ("development", "tests"):
            env["env"].get(e, {}).pop("plugins", None); env["env"].get(e, {}).pop("port", None)
        env["env"] = {k: val for k, val in env["env"].items() if val} or None
        if env["env"] is None:
            del env["env"]
    ordered = {k: env[k] for k in ("phpVersion", "plugins", "port", "testsPort", "config", "mappings", "env") if k in env}
    ordered.update({k: env[k] for k in env if k not in ordered})
    write(P(".wp-env.json"), json.dumps(ordered, indent=2) + "\n")

    # The boilerplate itself carries the master CLAUDE.md / README / CHANGELOG.md of the
    # boilerplate project, and is not released with the plugin deploy commands, so only the
    # sample plugin's changelog.txt is handled there.
    if os.path.isdir(P("tooling")):
        sync_changelog(t, v, boilerplate=True)
        print("Done (boilerplate itself: docs, CHANGELOG.md and release commands untouched).")
        return
    sync_changelog(t, v)
    sync_release(t, v)
    cl = P("CLAUDE.md")
    write(cl, replace_block(read(cl) if os.path.exists(cl) else "", R("CLAUDE.md.block"), prepend=True))
    rd = P("README.md")
    existing = read(rd) if os.path.exists(rd) else "# %s\n" % v["PLUGIN_NAME"]
    write(rd, replace_block(existing, R("README.md.block"), prepend=False))
    print("Done. Next: composer update && npm install && composer run check && npm test")


if __name__ == "__main__":
    main()
