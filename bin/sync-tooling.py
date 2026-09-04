#!/usr/bin/env python3
"""
Roll the canonical Fullworks free-plugin tooling out to a plugin repository.

    bin/sync-tooling.sh /path/to/plugin-repo [--svn-slug SLUG] [--port N] [--tests-port N] [--php-version 8.4]

Everything under tooling/ in this repository is the source of truth. Fix problems there
first, then re-run this script against each plugin repository. Values are detected from
the target (plugin directory, main file, default branch, version constant, wp-env ports)
and can be pinned in an optional .tooling.json at the target root:

    {"svn_slug": "...", "port": 8710, "tests_port": 8711, "php_version": "8.4", "plugin_dir": "..."}
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
    wpenv = {}
    if os.path.exists(os.path.join(target, ".wp-env.json")):
        wpenv = json.load(open(os.path.join(target, ".wp-env.json")))
    port = args.port or cfg.get("port") or wpenv.get("port") or wpenv.get("env", {}).get("development", {}).get("port") or 8888
    tests_port = args.tests_port or cfg.get("tests_port") or wpenv.get("testsPort") or wpenv.get("env", {}).get("tests", {}).get("port") or (port + 1)
    return dict(
        PLUGIN_DIR=plugin_dir, MAIN_FILE=main_file, PLUGIN_NAME=header(main_php, "Plugin Name") or plugin_dir,
        TEXT_DOMAIN=header(main_php, "Text Domain") or plugin_dir, PHP_MIN=php_min,
        PHP_PLATFORM=PHP_PLATFORM.get(php_min, php_min + ".0"), VERSION_CONSTANT=m.group(1) if m else "",
        BRANCH=branch, REPO=repo, REPO_NAME=repo.split("/")[-1], PORT=str(port), TESTS_PORT=str(tests_port),
        SVN_SLUG=args.svn_slug or cfg.get("svn_slug") or plugin_dir,
        PHP_VERSION=args.php_version or cfg.get("php_version") or "8.4",
        PHPUNIT_EXCLUDES=cfg.get("phpunit_exclude", []),
    ), wpenv


def render(text, v):
    compat = [p for p in ALL_PHP if float(p) >= float(v["PHP_MIN"])][::-1]
    scripts = "\n".join('    "compat:%s": "phpcs %s -s --standard=PHPCompatibilityWP --ignore=*/vendor/* --extensions=php --runtime-set testVersion %s",' % (p, v["PLUGIN_DIR"], p) for p in compat)
    calls = "\n".join('      "@compat:%s",' % p for p in compat)
    text = text.replace("__COMPAT_SCRIPTS__", scripts).replace("__COMPAT_CALLS__", calls)
    excludes = "\n".join("            <exclude>./tests/%s</exclude>" % e for e in v.get("PHPUNIT_EXCLUDES", []))
    text = text.replace("__PHPUNIT_EXCLUDES__\n", excludes + "\n" if excludes else "")
    note = " and `%s` in the main file" % v["VERSION_CONSTANT"] if v["VERSION_CONSTANT"] else ""
    text = text.replace("__VERSION_CONSTANT_NOTE__", note)
    for k, val in v.items():
        if isinstance(val, str):
            text = text.replace("__%s__" % k, val)
    return text


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
    args = ap.parse_args()
    t = os.path.abspath(args.target)
    v, wpenv = detect(t, args)
    print("Syncing tooling into %s" % t)
    for k in ("PLUGIN_DIR", "MAIN_FILE", "PLUGIN_NAME", "BRANCH", "REPO", "VERSION_CONSTANT", "PHP_MIN", "PORT", "TESTS_PORT", "SVN_SLUG"):
        log("%-16s %s" % (k, v[k]))
    P = lambda *a: os.path.join(t, *a)
    R = lambda rel: render(read(os.path.join(TOOLING, rel)), v)

    # Workflows.
    for f in ("checks.yml", "release.yml"):
        write(P(".github", "workflows", f), R("workflows/" + f))
    for f in LEGACY_WORKFLOWS + glob.glob(P(".github", "workflows", "*.yml.example")):
        p = f if os.path.isabs(f) else P(".github", "workflows", f)
        if os.path.exists(p):
            os.remove(p); log("removed legacy", os.path.relpath(p, t))

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

    # Docs (the boilerplate itself carries the master CLAUDE.md / README, so skip it there).
    if os.path.isdir(P("tooling")):
        print("Done (boilerplate itself: docs untouched).")
        return
    cl = P("CLAUDE.md")
    write(cl, replace_block(read(cl) if os.path.exists(cl) else "", R("CLAUDE.md.block"), prepend=True))
    rd = P("README.md")
    existing = read(rd) if os.path.exists(rd) else "# %s\n" % v["PLUGIN_NAME"]
    write(rd, replace_block(existing, R("README.md.block"), prepend=False))
    ch = P("CHANGELOG.md")
    if not os.path.exists(ch):
        ver = header(read(P(v["PLUGIN_DIR"], v["MAIN_FILE"])), "Version")
        write(ch, "# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n"
                  "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),\n"
                  "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n\n"
                  "## [Unreleased]\n\n## [%s]\n\n- Baseline. Earlier history is in `%s/readme.txt`.\n" % (ver, v["PLUGIN_DIR"]))
        log("created CHANGELOG.md baseline")
    print("Done. Next: composer update && npm install && composer run check && npm test")


if __name__ == "__main__":
    main()
