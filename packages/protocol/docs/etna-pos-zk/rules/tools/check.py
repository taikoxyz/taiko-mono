#!/usr/bin/env python3
"""Consistency checks for the rule-reference layer.

    python3 rules/tools/check.py [--base REV]

Checks:
  1. purity   (only when --base is given) stripping every marker from SPEC.md reproduces that
              revision, after normalising line ends and markdown table padding - the repository's
              prettier hook owns whitespace, so a byte-exact comparison would fail by design
  2. markers  IDs are unique, in document order, and contiguous per section; an ID inserted with a
              suffix letter (FI-7.2-3a) attaches to its parent number, and a gap left by a retired
              ID is allowed when INDEX.md marks that ID retired
  3. index    every marker has exactly one INDEX.md row and every live row has a marker; types are
              rule, limitation, assumption or retired
  4. assets   every section has a vectors and a review file; every live rule ID has a vector
              heading; no vector heading names an unknown ID
  5. links    relative links and #fragments resolve, and markdown tables have consistent columns
              (pipes inside inline code spans and escaped pipes are not separators)

Exit code 0 only if every check passes.
"""
import argparse, glob, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
RULES = os.path.dirname(HERE)
DOCS = os.path.dirname(RULES)
SPEC = os.path.join(DOCS, "SPEC.md")
INDEX = os.path.join(RULES, "INDEX.md")
NL = chr(10)
BT = chr(96)
BS = chr(92)

# ID grammar. Brackets are matched with character classes so the pattern needs no escapes.
# The trailing [a-z]? is the insertion suffix that README.md and CLAUDE.md mandate.
LB = re.escape("[")
RB = re.escape("]")
ID = "[A-Z][A-Z0-9]*-[0-9.ABC]+-[0-9]+[a-z]?"
INLINE = re.compile("[*][*]" + LB + "(" + ID + ")" + RB + "[*][*] ")
CODE = re.compile("^[ \t]*// " + LB + "(" + ID + ")" + RB + "$", re.M)
LIVE = ("rule", "limitation", "assumption")


def fail(msgs):
    for m in msgs:
        print("FAIL " + m)
    return len(msgs)


def parse_id(rid):
    last = rid.rsplit("-", 1)[1]
    m = re.match("^([0-9]+)([a-z]?)$", last)
    return int(m.group(1)), m.group(2)


def norm(text):
    out = []
    for ln in text.split(NL):
        ln = ln.rstrip()
        if ln.startswith("|"):
            cells = [c.strip() for c in ln.strip().strip("|").split("|")]
            cells = ["-" if (c and set(c) <= set("-:")) else c for c in cells]
            ln = "| " + " | ".join(cells) + " |"
        out.append(ln)
    return NL.join(out)


def git_show(rev):
    try:
        top = subprocess.check_output(["git", "-C", DOCS, "rev-parse", "--show-toplevel"]).decode().strip()
        rel = os.path.relpath(SPEC, top)
        return subprocess.check_output(["git", "-C", DOCS, "show", rev + ":" + rel]).decode()
    except Exception:
        return None


def split_cells(line):
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|") and not s.endswith(BS + "|"):
        s = s[:-1]
    cells, cur, in_code, i = [], [], False, 0
    while i < len(s):
        ch = s[i]
        if ch == BT:
            in_code = not in_code
            cur.append(ch)
        elif in_code:
            cur.append(ch)
        elif ch == BS and i + 1 < len(s) and s[i + 1] == "|":
            cur.append("|")
            i += 1
        elif ch == "|":
            cells.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
        i += 1
    cells.append("".join(cur).strip())
    return cells


def load_index():
    rows = {}
    for line in open(INDEX).read().split(NL):
        if not line.startswith("|"):
            continue
        cells = split_cells(line)
        if len(cells) < 5 or not re.fullmatch(ID, cells[0]):
            continue
        rows[cells[0]] = {"type": cells[1], "section": cells[3]}
    return rows


def slug(h):
    s = re.sub("[^0-9a-zA-Z_ -]", "", h.lower().strip())
    return s.replace(" ", "-")


def columns(line):
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    out, in_code, i = [], False, 0
    while i < len(s):
        ch = s[i]
        if ch == BT:
            in_code = not in_code
            out.append(ch)
        elif in_code:
            out.append("x" if ch == "|" else ch)
        elif ch == BS and i + 1 < len(s) and s[i + 1] == "|":
            out.append("x")
            i += 1
        else:
            out.append(ch)
        i += 1
    return len("".join(out).split("|"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=None, help="revision to compare SPEC.md against for the purity check (the commit before IDs were attached, or the revision you are editing from). Omit to skip purity: it is a migration check, not an invariant.")
    args = ap.parse_args()
    text = open(SPEC).read()
    index = load_index()
    bad = 0

    # 1. purity
    if not args.base:
        print("SKIP purity (pass --base <revision-before-IDs> to run the migration check)")
    else:
        rev = git_show(args.base)
        if rev is None:
            bad += fail(["purity: cannot read SPEC.md at " + args.base])
        else:
            stripped = INLINE.sub("", text)
            stripped = NL.join(l for l in stripped.split(NL) if not CODE.match(l))
            if norm(stripped) != norm(rev):
                bad += fail(["purity: SPEC.md differs from %s after stripping markers and normalising table padding" % args.base,
                             "purity: if you changed rule text on purpose, compare against the revision you edited from"])
            else:
                print("ok   purity (%s)" % args.base[:12])

    # 2. markers
    found = [(m.start(), m.group(1)) for m in INLINE.finditer(text)]
    found += [(m.start(), m.group(1)) for m in CODE.finditer(text)]
    found.sort()
    ids = [i for _, i in found]
    msgs = []
    if len(ids) != len(set(ids)):
        msgs.append("markers: duplicate ID")
    unknown = sorted(set(ids) - set(index))
    if unknown:
        msgs.append("markers: %d ID(s) with no INDEX row, e.g. %s" % (len(unknown), unknown[:3]))
    retired = {i for i, v in index.items() if v["type"] == "retired"}
    live = {i: v for i, v in index.items() if v["type"] in LIVE}
    unmarked = sorted(set(live) - set(ids))
    if unmarked:
        msgs.append("markers: %d live INDEX row(s) with no marker, e.g. %s" % (len(unmarked), unmarked[:3]))
    still = sorted(retired & set(ids))
    if still:
        msgs.append("markers: %d retired ID(s) still carry a marker, e.g. %s" % (len(still), still[:3]))
    for i in ids:
        if i in index and index[i]["type"] not in LIVE:
            msgs.append("markers: %s has INDEX type %s but carries a marker" % (i, index[i]["type"]))
        if i in index and index[i]["section"] != i.split("-")[1]:
            msgs.append("markers: %s is in section %s but INDEX says %s" % (i, i.split("-")[1], index[i]["section"]))
    by = {}
    for pos, i in found:
        by.setdefault(i.split("-")[1], []).append((pos, parse_id(i)))
    for sec in sorted(by):
        seq = [p for _, p in by[sec]]
        if seq != sorted(seq):
            msgs.append("markers: section %s is not in document order" % sec)
        numbers = {p[0] for _, p in by[sec]}
        gaps = {parse_id(i)[0] for i in retired if i.split("-")[1] == sec}
        missing = sorted(set(range(1, max(numbers) + 1)) - numbers - gaps)
        if missing:
            msgs.append("markers: section %s is missing %s (no marker and not retired in INDEX)" % (sec, missing[:6]))
    bad += fail(msgs) if msgs else (print("ok   markers (%d)" % len(ids)) or 0)

    # 3. index
    msgs = []
    bad_types = {i: v["type"] for i, v in index.items() if v["type"] not in LIVE + ("retired",)}
    if bad_types:
        msgs.append("index: unknown type(s): %s" % list(bad_types.items())[:3])
    bad += fail(msgs) if msgs else (print("ok   index (%d live, %d retired)" % (len(live), len(retired))) or 0)

    # 4. assets
    msgs = []
    for sec in sorted({v["section"] for v in index.values()}):
        for kind in ("vectors", "review"):
            if not os.path.exists(os.path.join(RULES, kind, sec + ".md")):
                msgs.append("assets: missing %s/%s.md" % (kind, sec))
    for vf in sorted(glob.glob(os.path.join(RULES, "vectors", "*.md"))):
        sec = os.path.basename(vf)[:-3]
        allowed = {i for i, v in index.items() if v["section"] == sec}
        want = {i for i in allowed if index[i]["type"] == "rule"}
        got = set(re.findall("^## (" + ID + ")[ \t]*$", open(vf).read(), flags=re.M))
        for i in sorted(want - got)[:3]:
            msgs.append("assets: no vector heading for " + i)
        for i in sorted(got - allowed)[:3]:
            msgs.append("assets: vector heading for unknown id " + i)
    bad += fail(msgs) if msgs else (print("ok   assets") or 0)

    # 5. links and tables
    msgs, cache = [], {}
    def headings(path):
        if path not in cache:
            cache[path] = {slug(m.group(2)) for m in re.finditer("^(#{1,6}) (.*)$", open(path).read(), flags=re.M)}
        return cache[path]
    for f in glob.glob(os.path.join(RULES, "**", "*.md"), recursive=True) + [SPEC]:
        body = open(f).read()
        for m in re.finditer(RB + "[(]([^)]+)[)]", body):
            u = m.group(1).strip()
            if u.startswith("http"):
                continue
            p, _, frag = u.partition("#")
            tgt = os.path.normpath(os.path.join(os.path.dirname(f), p)) if p else f
            if not os.path.exists(tgt):
                msgs.append("links: %s -> %s" % (os.path.basename(f), u))
            elif frag and frag not in headings(tgt):
                msgs.append("links: %s -> %s (dead fragment)" % (os.path.basename(f), u))
        block, fenced = [], False
        for ln in body.split(NL) + [""]:
            if ln.strip().startswith(BT * 3):
                fenced = not fenced
                block = []
                continue
            if fenced:
                continue
            if ln.startswith("|"):
                block.append(ln)
            else:
                if len(block) >= 2 and len({columns(b) for b in block}) != 1:
                    msgs.append("tables: %s has a row with a different column count" % os.path.basename(f))
                block = []
    bad += fail(msgs) if msgs else (print("ok   links and tables") or 0)

    print(NL + ("ALL CHECKS PASSED" if bad == 0 else "%d problem(s)" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
