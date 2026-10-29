#!/usr/bin/env python3
"""Consistency checks for the rule-reference layer.

Run from anywhere:  python3 rules/tools/check.py [--base REV]

Checks, in order:
  1. purity      stripping every ID marker from SPEC.md reproduces the base revision byte for byte.
                This is a migration check: pass --base as the commit before IDs were attached, or
                as the revision you are editing from. Omit it once rule text is amended on purpose.
  2. markers     IDs are unique, contiguous within each section, and in document order
  3. index       every marker has exactly one INDEX.md row, and every row has a marker
  4. assets      every section has vectors + review; every rule ID has a vector heading; every cited
                 review question exists
  5. links       relative links and #fragments resolve; markdown tables have consistent columns

Exit code 0 only if every check passes.
"""
import argparse, glob, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
RULES = os.path.dirname(HERE)
DOCS = os.path.dirname(RULES)
SPEC = os.path.join(DOCS, "SPEC.md")
ID = r"[A-Z][A-Z0-9]*-[0-9.ABC]+-[0-9]+"
INLINE = re.compile(r"\*\*\[(" + ID + r")\]\*\* ")
CODE = re.compile(r"^\s*// \[(" + ID + r")\]$", re.M)

def fail(msgs):
    for m in msgs: print("FAIL " + m)
    return len(msgs)

def git_show(rev, path):
    try:
        top = subprocess.check_output(["git", "-C", DOCS, "rev-parse", "--show-toplevel"]).decode().strip()
        rel = os.path.relpath(path, top)
        return subprocess.check_output(["git", "-C", DOCS, "show", rev + ":" + rel]).decode()
    except Exception:
        return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=None, help="revision to compare SPEC.md against for the purity check: the commit before IDs were attached, or the revision you are editing from (default: merge-base HEAD origin/HEAD; purity is skipped if neither is available)")
    a = ap.parse_args()
    text = open(SPEC).read()
    bad = 0

    # 1. purity
    base = a.base
    if not base:
        try:
            base = subprocess.check_output(["git", "-C", DOCS, "merge-base", "HEAD", "origin/HEAD"], stderr=subprocess.DEVNULL).decode().strip()
        except Exception:
            base = None
    if not base:
        print("SKIP purity (no --base and no origin/HEAD)")
    else:
        rev = git_show(base, SPEC)
        if rev is None:
            bad += fail(["purity: cannot read SPEC.md at " + base])
        else:
            stripped = INLINE.sub("", text)
            stripped = "\n".join(l for l in stripped.split("\n") if not CODE.match(l))
            if stripped != rev:
                import difflib
                d = list(difflib.unified_diff(rev.split("\n"), stripped.split("\n"), "base", "stripped", lineterm="", n=0))
                bad += fail(["purity: SPEC.md is NOT identical to %s after stripping markers (%d diff lines)" % (base, len(d)), "purity: if rule text changed on purpose, pass the revision you are editing from, or omit --base"])
            else:
                print("ok   purity (%s)" % base[:12])

    # 2. markers
    marks = [m.group(1) for m in INLINE.finditer(text)] + [m.group(1) for m in CODE.finditer(text)]
    msgs = []
    if len(marks) != len(set(marks)): msgs.append("markers: duplicate ID")
    by = {}
    pos = [m.start() for m in INLINE.finditer(text)] + [m.start() for m in CODE.finditer(text)]
    for p, m in zip(pos, marks): by.setdefault(m.split("-")[1], []).append((p, m))
    for sec, lst in by.items():
        nums = [int(m.rsplit("-", 1)[1]) for _, m in lst]
        if nums != list(range(1, len(nums) + 1)):
            msgs.append("markers: section %s is not contiguous 1..n: %s" % (sec, nums[:8]))
        if [m for _, m in lst] != [m for _, m in sorted(lst)]:
            msgs.append("markers: section %s out of document order" % sec)
    bad += fail(msgs) if msgs else (print("ok   markers (%d)" % len(marks)) or 0)

    # 3. index: every marker has exactly one INDEX row and vice versa
    msgs, props = [], {}
    for line in open(os.path.join(RULES, "INDEX.md")).read().split("\n"):
        m = re.match(r"^\| (" + ID + r") \| (rule|limitation|assumption) \|.*\| ([0-9.ABC]+) \|", line)
        if m: props[m.group(1)] = {"id": m.group(1), "section": m.group(3), "type": m.group(2)}
    missing = sorted(set(marks) - set(props))
    extra = sorted(set(props) - set(marks))
    if missing: msgs.append("index: %d marker(s) with no INDEX row, e.g. %s" % (len(missing), missing[:3]))
    if extra: msgs.append("index: %d INDEX row(s) with no marker, e.g. %s" % (len(extra), extra[:3]))
    bad += fail(msgs) if msgs else (print("ok   index (%d)" % len(props)) or 0)

    # 4. assets
    msgs = []
    for it in props.values():
        sec = it["section"]
        vf = os.path.join(RULES, "vectors", sec + ".md")
        rf = os.path.join(RULES, "review", sec + ".md")
        if not os.path.exists(vf): msgs.append("assets: missing vectors/%s.md" % sec)
        if not os.path.exists(rf): msgs.append("assets: missing review/%s.md" % sec)
    for vf in glob.glob(os.path.join(RULES, "vectors", "*.md")):
        vt = open(vf).read()
        sec = os.path.basename(vf)[:-3]
        allowed = {i for i, it in props.items() if it["section"] == sec}
        want = {i for i in allowed if props[i].get("type", "rule") == "rule"}
        got = set(re.findall(r"^## (" + ID + r")\s*$", vt, flags=re.M))
        for m in sorted(want - got)[:3]: msgs.append("assets: no vector heading for " + m)
        for m in sorted(got - allowed)[:3]: msgs.append("assets: vector heading for unknown id " + m)
    bad += fail(msgs) if msgs else (print("ok   assets") or 0)

    # 5. links + tables
    msgs = []
    def slug(h):
        return re.sub(r"[^\w\- ]", "", h.lower().strip()).replace(" ", "-")
    for f in glob.glob(os.path.join(RULES, "**", "*.md"), recursive=True) + [SPEC]:
        t = open(f).read()
        for m in re.finditer(r"\]\(([^)]+)\)", t):
            u = m.group(1).strip()
            if u.startswith("http"): continue
            p, _, frag = u.partition("#")
            tgt = os.path.normpath(os.path.join(os.path.dirname(f), p)) if p else f
            if not os.path.exists(tgt): msgs.append("links: %s -> %s" % (os.path.basename(f), u)); continue
            if frag:
                hs = {slug(x.group(2)) for x in re.finditer(r"^(#{1,6}) (.*)$", open(tgt).read(), flags=re.M)}
                if frag not in hs: msgs.append("links: %s -> %s (fragment)" % (os.path.basename(f), u))
    def cells(ln):
        s = ln.strip()
        if s.startswith("|"): s = s[1:]
        if s.endswith("|"): s = s[:-1]
        return len(re.split(r"(?<!\\)\|", s))
    for f in glob.glob(os.path.join(RULES, "**", "*.md"), recursive=True) + [SPEC]:
        block = []
        for ln in open(f).read().split("\n") + [""]:
            if ln.startswith("|"): block.append(ln)
            else:
                if len(block) >= 2 and len({cells(b) for b in block}) != 1:
                    msgs.append("tables: %s has a row with a different column count" % os.path.basename(f))
                block = []
    bad += fail(msgs) if msgs else (print("ok   links and tables") or 0)

    print("\n%s" % ("ALL CHECKS PASSED" if bad == 0 else "%d problem(s)" % bad))
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main())
