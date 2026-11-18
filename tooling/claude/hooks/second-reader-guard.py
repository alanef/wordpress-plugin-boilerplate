#!/usr/bin/env -S python3 -I
"""PreToolUse guard for the second-reader subagent: Bash may only read git history.

The second reader reviews another session's work, so it must never touch that session's
working tree, index or branches. Its tool list removes Edit and Write, but it needs Bash for
`git show` / `git diff`, and a tool list cannot narrow Bash. This hook does.

Allowed, and nothing else:
  [cd PATH &&] [GIT_TERMINAL_PROMPT=0] git [-C PATH] SUB ARGS [| FILTER ARGS]...
  SUB    = a read-only git subcommand (READ_ONLY below), or `fetch` with no refspec
  FILTER = grep, head, tail, wc, sort, cut, nl
No redirection, command substitution, chaining, backgrounding, `git -c`, or --output.
Anything else is blocked with exit 2 and the reason on stderr.
"""
import json
import re
import shlex
import sys

READ_ONLY = {
    "show", "diff", "log", "rev-parse", "merge-base", "ls-tree", "ls-files", "cat-file",
    "grep", "blame", "describe", "shortlog", "rev-list", "for-each-ref", "name-rev",
}
FILTERS = {"grep", "head", "tail", "wc", "sort", "cut", "nl"}
BANNED_ARGS = ("--output", "--ext-diff", "--exec", "--upload-pack", "--open-files-in-pager")


def block(reason):
    sys.stderr.write("second-reader guard: %s. Read-only: git show/diff/log/... on refs, "
                     "optionally piped to grep/head/tail/wc/sort/cut/nl.\n" % reason)
    sys.exit(2)


def check_git(words):
    i = 0
    if words[i:i + 1] == ["GIT_TERMINAL_PROMPT=0"]:
        i += 1
    if words[i:i + 1] != ["git"]:
        block("the command must start with git")
    i += 1
    while i < len(words) and words[i] == "-C":
        if i + 1 >= len(words):
            block("-C needs a path")
        i += 2
    if i >= len(words):
        block("no git subcommand")
    sub, args = words[i], words[i + 1:]
    if sub.startswith("-"):
        block("git global option %s is not allowed" % sub)
    for a in args:
        if a.startswith(BANNED_ARGS):
            block("%s is not allowed" % a.split("=")[0])
    if sub == "grep" and any(a == "-O" or (a.startswith("-O") and not a.startswith("-O-")) for a in args):
        block("git grep -O opens a pager command")
    if sub == "fetch":
        if any(":" in a and not a.startswith("-") for a in args):
            block("git fetch with a refspec can move local branches")
        return
    if sub not in READ_ONLY:
        block("git %s is not read-only" % sub)


def check_filter(words):
    if not words or words[0] not in FILTERS:
        block("only grep/head/tail/wc/sort/cut/nl may follow a pipe")
    if words[0] == "sort" and any(a.startswith(("-o", "--output", "--compress-program")) for a in words[1:]):
        block("sort may not write files or run programs")


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        block("unreadable hook input")
    if data.get("tool_name") != "Bash":
        return
    cmd = (data.get("tool_input") or {}).get("command", "").strip()
    if not cmd:
        block("empty command")
    if "\n" in cmd or re.search(r"[;<>`]|\$\(|\|\||&(?!&)|(?<!&)&", cmd.replace("&&", "")):
        block("redirection, substitution, chaining and backgrounding are not allowed")
    m = re.match(r"cd\s+(\S+)\s*&&\s*(.*)$", cmd, re.S)
    if m:
        cmd = m.group(2)
    if "&&" in cmd:
        block("only a single leading `cd PATH &&` may be chained")
    try:
        stages = [shlex.split(s) for s in cmd.split("|")]
    except ValueError:
        block("unbalanced quotes")
    check_git(stages[0])
    for s in stages[1:]:
        check_filter(s)


if __name__ == "__main__":
    main()
