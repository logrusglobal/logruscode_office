#!/usr/bin/env python3
"""Shared file operations for the OpenCode office kit (install.sh / uninstall.sh).

The bash scripts drive the install; every operation that has to parse JSON or
rewrite Markdown safely lives here instead, because doing either with sed and
grep is how configs get corrupted. This mirrors scripts/lib/common.ps1 in the
Windows kit - keep the two in step when changing behaviour.

Every subcommand prints nothing on success unless it has a value to return, and
uses the exit code to report "did something change": 0 = changed / found,
1 = nothing to do. Hard failures raise and exit 2 with a message on stderr.
"""
import argparse
import glob
import json
import os
import re
import sys
from collections import OrderedDict

MARK_START = "<!-- opencode-kit:%s:start -->"
MARK_END = "<!-- opencode-kit:%s:end -->"
ANY_MARK_START = re.compile(r"^<!-- opencode-kit:[^:]+:start -->$")
ANY_MARK_END = re.compile(r"^<!-- opencode-kit:[^:]+:end -->$")
HEADING = re.compile(r"^#\s+\S")

NOTHING = 1

# Every string this kit handles is UTF-8 (Russian prose, the shortcut name).
# Under LC_ALL=C - or any non-UTF-8 locale - Python would otherwise pick an
# ASCII stdout codec and die on the first Cyrillic heading it prints.
#
# newline="\n" matters just as much: the shell reads this output back with
# `read -r` and into files that are matched line by line, so a translated
# "\r\n" would silently glue a carriage return onto every language code and
# every heading.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", newline="\n")
    except (AttributeError, ValueError):
        pass


def read_json(path):
    # utf-8-sig: OpenCode itself and some editors leave a BOM on opencode.json.
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f, object_pairs_hook=OrderedDict)


def write_json(path, value):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(value, f, ensure_ascii=False, indent=2)
        f.write("\n")


def read_text(path):
    with open(path, encoding="utf-8-sig") as f:
        return f.read()


def write_text(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


# --------------------------------------------------------------------------
# Messages


def cmd_msgs(a):
    """Print the i18n table as shell assignments, English first as the base.

    A missing translation degrades to English instead of printing an empty
    line, which is why en.json is always loaded underneath.
    """
    base = os.path.join(a.i18n_dir, "en.json")
    if not os.path.exists(base):
        sys.exit("Message file not found: %s" % base)
    messages = read_json(base)
    if a.lang != "en":
        loc = os.path.join(a.i18n_dir, "%s.json" % a.lang)
        if os.path.exists(loc):
            messages.update(read_json(loc))
    for key, value in messages.items():
        if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key):
            continue
        # Single-quote for the shell, escaping embedded quotes the only way
        # a POSIX shell allows inside single quotes.
        safe = str(value).replace("'", "'\\''")
        print("M_%s='%s'" % (key, safe))
    return 0


def cmd_langs(a):
    for path in sorted(glob.glob(os.path.join(a.i18n_dir, "*.json"))):
        print(os.path.splitext(os.path.basename(path))[0])
    return 0


# --------------------------------------------------------------------------
# AGENTS.md marked blocks


def cmd_block_set(a):
    """Write content between markers, replacing an earlier copy of the block.

    Markers are what makes uninstall precise: anything the user added to the
    file by hand is left alone.
    """
    start, end = MARK_START % a.id, MARK_END % a.id
    block = "%s\n%s\n%s" % (start, read_text(a.content).strip(), end)
    if os.path.exists(a.path):
        text = read_text(a.path)
        pattern = re.compile(re.escape(start) + r"[\s\S]*?" + re.escape(end))
        if pattern.search(text):
            text = pattern.sub(lambda _: block, text)
        else:
            text = text.rstrip() + "\n\n" + block
    else:
        text = block
    write_text(a.path, text.rstrip() + "\n")
    return 0


def cmd_block_del(a):
    if not os.path.exists(a.path):
        return NOTHING
    start, end = MARK_START % a.id, MARK_END % a.id
    text = read_text(a.path)
    pattern = re.compile(re.escape(start) + r"[\s\S]*?" + re.escape(end))
    if not pattern.search(text):
        return NOTHING
    text = pattern.sub("", text).strip()
    if not text:
        os.remove(a.path)
    else:
        write_text(a.path, text + "\n")
    return 0


def cmd_headings(a):
    """The top-level headings the kit writes into AGENTS.md.

    Collected from the locale sources themselves - every language, not just the
    one being installed, and no copy of the prose to keep in sync here.
    """
    seen = []
    for root in a.dirs:
        for path in sorted(glob.glob(os.path.join(root, "**", "AGENTS*.md"), recursive=True)):
            for line in read_text(path).splitlines():
                line = line.strip()
                if HEADING.match(line) and line not in seen:
                    seen.append(line)
    for line in seen:
        print(line)
    return 0


def cmd_legacy_strip(a):
    """Remove kit sections that sit OUTSIDE the markers.

    Kit versions released before the marker system wrote these sections into
    AGENTS.md with no markers around them. block-set cannot find such a section,
    so on the next install it survives as a second copy of the rules - and, when
    the language was changed between installs, a copy in the OTHER language,
    which is what actually drives the model's answers.
    """
    if not os.path.exists(a.path):
        return NOTHING
    headings = [h.strip() for h in read_text(a.headings).splitlines() if h.strip()]
    if not headings:
        return NOTHING

    out, in_marked, dropping, removed = [], False, False, False
    for line in read_text(a.path).splitlines():
        if ANY_MARK_START.match(line):
            in_marked, dropping = True, False
        elif ANY_MARK_END.match(line):
            in_marked = False
            out.append(line)
            continue
        if not in_marked:
            if line.strip() in headings:
                dropping, removed = True, True
            elif dropping and HEADING.match(line):
                dropping = False
        if not dropping:
            out.append(line)
    if not removed:
        return NOTHING
    write_text(a.path, re.sub(r"\n{3,}", "\n\n", "\n".join(out)).strip() + "\n")
    return 0


# --------------------------------------------------------------------------
# opencode.json


def cmd_cfg_base(a):
    """Package 1: write the kit's opencode.json over the existing one.

    A reinstall must not throw away the MCP servers and permissions that
    packages 2 and 3 merged in earlier, so those two sections are carried over.
    Prints "carried" when that happened, so the caller can say so.
    """
    cfg = read_json(a.kit_config)
    if os.path.exists(a.config):
        old = read_json(a.config)
        carried = False
        for key in ("mcp", "permission"):
            if key in old:
                cfg[key] = old[key]
                carried = True
        if carried:
            print("carried")
    if a.keep_build:
        cfg.pop("agent", None)
    write_json(a.config, cfg)
    return 0


def cmd_cfg_merge(a):
    """Merge a fragment into cfg["mcp"], then verify every key survived."""
    cfg = read_json(a.config)
    fragment = json.loads(read_text(a.fragment))
    cfg.setdefault("mcp", OrderedDict()).update(fragment)
    for key, value in (a.permission or []):
        cfg.setdefault("permission", OrderedDict())[key] = value
    write_json(a.config, cfg)

    check = read_json(a.config)
    for key in fragment:
        if key not in check.get("mcp", {}):
            sys.exit("merge not confirmed: mcp.%s" % key)
    for key, _ in (a.permission or []):
        if key not in check.get("permission", {}):
            sys.exit("merge not confirmed: permission.%s" % key)
    return 0


def cmd_cfg_get(a):
    cfg = read_json(a.config)
    if a.key not in cfg:
        return NOTHING
    print(cfg[a.key])
    return 0


def cmd_cfg_del(a):
    """Remove keys from opencode.json; print what went, exit 1 if nothing did.

    --section K removes cfg[section][K] and drops the section once empty.
    --top K removes cfg[K], optionally only when its value starts with --prefix
    or equals --equals, so a value the user changed by hand is left alone.
    """
    if not os.path.exists(a.config):
        return NOTHING
    cfg = read_json(a.config)
    cleaned = []

    for spec in a.section or []:
        section, _, key = spec.partition(".")
        node = cfg.get(section)
        if isinstance(node, dict) and key in node:
            del node[key]
            cleaned.append("%s.%s" % (section, key))
            if not node:
                del cfg[section]

    for key in a.top or []:
        if key not in cfg:
            continue
        value = cfg[key]
        if a.prefix and not str(value).startswith(a.prefix):
            continue
        if a.equals and str(value) != a.equals:
            continue
        del cfg[key]
        cleaned.append(key)

    if not cleaned:
        return NOTHING
    write_json(a.config, cfg)
    print(",".join(cleaned))
    return 0


# --------------------------------------------------------------------------
# auth.json


def cmd_auth_set(a):
    auth = read_json(a.auth) if os.path.exists(a.auth) else OrderedDict()
    auth[a.provider] = OrderedDict([("type", "api"), ("key", a.key)])
    write_json(a.auth, auth)
    return 0


def cmd_auth_del(a):
    """Remove the kit's provider entry from auth.json - without a backup.

    Deliberately unlike opencode.json: the only thing the kit owns here is the
    API key, so a backup would do nothing but leave that secret in plaintext
    next to the file it was just removed from - and would copy any other
    provider's key along with it. Other entries are kept in place, so there is
    nothing a backup could recover.
    """
    if not os.path.exists(a.auth):
        return NOTHING
    auth = read_json(a.auth)
    if a.provider not in auth:
        return NOTHING
    del auth[a.provider]
    write_json(a.auth, auth)
    return 0


# --------------------------------------------------------------------------
# Templating


def cmd_render(a):
    """Substitute {{TOKEN}} placeholders, failing loudly on a missing one."""
    text = read_text(a.source)
    for pair in a.set or []:
        token, _, value = pair.partition("=")
        placeholder = "{{%s}}" % token
        if placeholder not in text:
            sys.exit("placeholder %s missing from %s" % (placeholder, a.source))
        text = text.replace(placeholder, value)
    left = re.search(r"\{\{[A-Z_]+\}\}", text)
    if left:
        sys.exit("placeholder %s left unresolved in %s" % (left.group(0), a.source))
    write_text(a.dest, text)
    return 0


# --------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd")

    p = sub.add_parser("msgs"); p.add_argument("i18n_dir"); p.add_argument("lang"); p.set_defaults(fn=cmd_msgs)
    p = sub.add_parser("langs"); p.add_argument("i18n_dir"); p.set_defaults(fn=cmd_langs)

    p = sub.add_parser("block-set"); p.add_argument("path"); p.add_argument("id"); p.add_argument("content"); p.set_defaults(fn=cmd_block_set)
    p = sub.add_parser("block-del"); p.add_argument("path"); p.add_argument("id"); p.set_defaults(fn=cmd_block_del)
    p = sub.add_parser("headings"); p.add_argument("dirs", nargs="+"); p.set_defaults(fn=cmd_headings)
    p = sub.add_parser("legacy-strip"); p.add_argument("path"); p.add_argument("headings"); p.set_defaults(fn=cmd_legacy_strip)

    p = sub.add_parser("cfg-base"); p.add_argument("kit_config"); p.add_argument("config")
    p.add_argument("--keep-build", action="store_true"); p.set_defaults(fn=cmd_cfg_base)
    p = sub.add_parser("cfg-merge"); p.add_argument("config"); p.add_argument("fragment")
    p.add_argument("--permission", nargs=2, action="append", metavar=("KEY", "VALUE")); p.set_defaults(fn=cmd_cfg_merge)
    p = sub.add_parser("cfg-get"); p.add_argument("config"); p.add_argument("key"); p.set_defaults(fn=cmd_cfg_get)
    p = sub.add_parser("cfg-del"); p.add_argument("config")
    p.add_argument("--section", action="append", metavar="SECTION.KEY")
    p.add_argument("--top", action="append", metavar="KEY")
    p.add_argument("--prefix"); p.add_argument("--equals"); p.set_defaults(fn=cmd_cfg_del)

    p = sub.add_parser("auth-set"); p.add_argument("auth"); p.add_argument("provider"); p.add_argument("key"); p.set_defaults(fn=cmd_auth_set)
    p = sub.add_parser("auth-del"); p.add_argument("auth"); p.add_argument("provider"); p.set_defaults(fn=cmd_auth_del)

    p = sub.add_parser("render"); p.add_argument("source"); p.add_argument("dest")
    p.add_argument("--set", action="append", metavar="TOKEN=VALUE"); p.set_defaults(fn=cmd_render)

    args = parser.parse_args()
    if not getattr(args, "fn", None):
        parser.print_help()
        return 2
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
