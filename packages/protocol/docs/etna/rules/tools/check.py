#!/usr/bin/env python3
"""Consistency checks for the rule-reference layer.

    python3 rules/tools/check.py [--base REV] [--amendments-base REV]

Checks:
  1. purity   (only when --base is given) stripping every marker from SPEC.md reproduces that
              revision, after normalising line ends and markdown table padding - the repository's
              prettier hook owns whitespace, so a byte-exact comparison would fail by design
  2. markers  IDs are unique, in document order, and contiguous per section; an ID inserted with a
              suffix letter (FI-7.2-3a) attaches to its parent number, and a gap left by a retired
              ID is allowed when INDEX.md marks that ID retired; INDEX.md's section is the section
              the marker sits in, so a rule that moves keeps its ID
  3. index    every marker has exactly one INDEX.md row (a duplicate row fails) and every live row
              has a marker; types are rule, limitation, assumption or retired
  4. assets   every section has a vectors and a review file; every live rule ID has a vector
              heading; no vector heading names an unknown ID
  5. incorporation UPGRADES.md sections have live governing rule IDs and SPEC backlinks
     amendments compare complete governed scopes and require fresh content digests
     coverage checks actual ID/vector/question counts and unique vector labels
     structure checks ATX headings, closed fences and authorized marker placement
  6. links    relative links and #fragments resolve, and markdown tables have consistent columns
              (pipes inside inline code spans and escaped pipes are not separators)

Exit code 0 only if every check passes.
"""
import argparse, glob, hashlib, os, re, subprocess, sys

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


def git_show(rev, relative="SPEC.md"):
    top = subprocess.run(["git", "-C", DOCS, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if top.returncode:
        return None
    path = os.path.relpath(os.path.join(DOCS, relative), top.stdout.strip())
    result = subprocess.run(["git", "-C", DOCS, "show", rev + ":" + path], capture_output=True, text=True)
    return result.stdout if result.returncode == 0 else None


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
    rows, dups = {}, []
    for line in open(INDEX).read().split(NL):
        if not line.startswith("|"):
            continue
        cells = split_cells(line)
        if len(cells) < 5 or not re.fullmatch(ID, cells[0]):
            continue
        if cells[0] in rows:
            dups.append(cells[0])
            continue
        rows[cells[0]] = {"type": cells[1], "section": cells[3]}
    return rows, dups


SECTION = re.compile("^#{2,3} (?:Appendix ([A-C])[^A-Za-z0-9]|([0-9]+(?:[.][0-9]+)?)[.]? )", re.M)


def section_finder(text):
    """Return a function mapping a SPEC.md offset to the section that contains it."""
    masked, _ = outside_fences(text)
    starts = [(m.start(), m.group(1) or m.group(2)) for m in SECTION.finditer(masked)]

    def at(pos):
        sec = None
        for start, name in starts:
            if start > pos:
                break
            sec = name
        return sec

    return at


def slug(h):
    s = re.sub("[^0-9a-zA-Z_ -]", "", h.lower().strip())
    return s.replace(" ", "-")


def markdown_regions(text):
    """Mask fenced code while retaining offsets; return complete raw fenced regions."""
    out, opening, regions, offset = [], None, [], 0
    for line in text.splitlines(keepends=True):
        content = line.rstrip("\r\n")
        fence = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", content)
        hidden = opening is not None
        if opening:
            char, length, start, info = opening
            if fence and fence[1][0] == char and len(fence[1]) >= length and not fence[2].strip():
                regions.append((start, offset + len(line), info))
                opening = None
        elif fence and not (fence[1][0] == "`" and "`" in fence[2]):
            opening = (fence[1][0], len(fence[1]), offset, fence[2].strip())
            hidden = True
        out.append(" " * len(content) + line[len(content):] if hidden else line)
        offset += len(line)
    return "".join(out), opening is not None, regions


def outside_fences(text):
    masked, unclosed, _ = markdown_regions(text)
    return masked, unclosed


def check_markdown_structure(name, text):
    masked, unclosed = outside_fences(text)
    msgs = ["markdown: unclosed fence in " + name] if unclosed else []
    lines = masked.splitlines()
    for i, line in enumerate(lines):
        if i and lines[i - 1].strip() and re.fullmatch(r" {0,3}(?:=+|-+)[ \t]*", line):
            msgs.append("markdown: setext headings are unsupported in " + name + "; use ATX headings")
    return msgs


def check_marker_placement(spec):
    _, _, regions = markdown_regions(spec)
    locate, msgs = section_finder(spec), []
    for marker in INLINE.finditer(spec):
        if any(start <= marker.start() < end for start, end, _ in regions):
            msgs.append("placement: inline rule inside fenced code " + marker[1])
    for marker in CODE.finditer(spec):
        authorized = marker[1].startswith("ENC-A-") and locate(marker.start()) == "A" and any(
            start <= marker.start() < end and info == "txt" for start, end, info in regions)
        if not authorized:
            msgs.append("placement: code-before marker outside Appendix A definition " + marker[1])
    return msgs


def check_incorporation(spec, helper, index):
    """Check the explicit exception for definitions incorporated under SPEC rules."""
    # Examples cannot create sections or supply authority. Keep offsets/lines stable.
    body, unclosed = outside_fences(helper)
    sections = list(re.finditer(r"^## (.+)$", body, re.M))
    mappings = re.compile(r"^<!-- governed-by: (" + ID + r") -->$", re.M)
    msgs, seen, used = [], set(), 0
    if unclosed:
        msgs.append("incorporation: unclosed fence in UPGRADES.md")
    if not sections:
        msgs.append("incorporation: UPGRADES.md has no governed sections")
    for i, section in enumerate(sections):
        title = section.group(1)
        end = sections[i + 1].start() if i + 1 < len(sections) else len(body)
        owners = mappings.findall(body[section.end():end])
        used += len(owners)
        if len(owners) != 1:
            msgs.append("incorporation: %s needs exactly one governing ID" % title)
            continue
        rid = owners[0]
        anchor = slug(title)
        if anchor in seen:
            msgs.append("incorporation: duplicate section anchor " + anchor)
        seen.add(anchor)
        if index.get(rid, {}).get("type") != "rule":
            msgs.append("incorporation: %s is not a live rule" % rid)
            continue
        marker = "**[" + rid + "]** "
        rule = re.search(re.escape(marker) + r"([^\n]*?)(?= \*\*\[[A-Z]|\n|$)", spec)
        backlink = "UPGRADES.md#" + anchor
        if not rule or not re.search(r"\]\(" + re.escape(backlink) + r"\)", rule.group(1)):
            msgs.append("incorporation: %s needs owning-rule backlink to %s" % (rid, backlink))
    if used != len(mappings.findall(body)):
        msgs.append("incorporation: governing ID outside a section")
    return msgs


def rule_bodies(text):
    """Extract governed text for amendment comparison, ignoring formatter spacing."""
    markers = sorted([(m.start(), m.end(), m[1], False) for m in INLINE.finditer(text)] +
                     [(m.start(), m.end(), m[1], True) for m in CODE.finditer(text)])
    bodies = {}
    for i, (_start, start, rid, code) in enumerate(markers):
        end = markers[i + 1][0] if i + 1 < len(markers) else len(text)
        if code:
            blank = text.find(NL + NL, start)
            if blank >= 0:
                end = min(end, blank)
        else:
            end = min(end, text.find(NL, start) if NL in text[start:] else len(text))
        body = text[start:end].strip()
        # Preserve definition bytes and inline code; only prose spacing is formatter-owned.
        parts = re.split(r"(`[^`]*`)", body)
        bodies[rid] = body if code else "".join(part if i % 2 else re.sub(r"\s+", " ", part)
                                                for i, part in enumerate(parts)).strip()
    return bodies


def governed_bodies(spec, helper=""):
    """Include incorporated helper sections and the normative landing reference block."""
    bodies = rule_bodies(spec)
    masked, _, regions = markdown_regions(spec)
    if "LAND-6.1-10" in bodies:
        locate = section_finder(spec)
        references = [spec[start:end].strip() for start, end, info in regions
                      if info == "solidity" and locate(start) == "6.1"]
        if len(references) != 1:
            raise ValueError("reference Solidity under LAND-6.1-10 must be exactly one block")
        bodies["LAND-6.1-10"] += "\n[reference Solidity]\n" + references[0]
    masked, _ = outside_fences(helper)
    sections = list(re.finditer(r"^## (.+)$", masked, re.M))
    for i, section in enumerate(sections):
        end = sections[i + 1].start() if i + 1 < len(sections) else len(helper)
        owners = re.findall(r"^<!-- governed-by: (" + ID + r") -->$", masked[section.end():end], re.M)
        if len(owners) == 1 and owners[0] in bodies:
            bodies[owners[0]] += "\n[UPGRADES.md#" + slug(section[1]) + "]\n" + helper[section.start():end].strip()
    return bodies


def content_digest(body):
    return hashlib.blake2s(body.encode("utf-8")).hexdigest()


def check_amendments(spec, index_text, index, baseline=None, helper="", baseline_helper=""):
    section = re.search(r"^## Material amendments\n(.*?)(?=^## |\Z)", index_text, re.M | re.S)
    msgs, declared = [], set()
    try:
        current = governed_bodies(spec, helper)
        previous = governed_bodies(baseline, baseline_helper) if baseline is not None else None
    except ValueError as error:
        return ["amendments: " + str(error)]
    if section:
        for line in section[1].splitlines():
            cells = split_cells(line)
            if not line.startswith("|") or not re.fullmatch(ID, cells[0]):
                continue
            rid = cells[0]
            if rid in declared:
                msgs.append("amendments: duplicate amendment " + rid)
            declared.add(rid)
            if rid not in index:
                msgs.append("amendments: unknown amendment " + rid)
            if len(cells) != 4 or not all(cells[1:]):
                msgs.append("amendments: incomplete amendment " + rid)
            elif rid in current and cells[3] != content_digest(current[rid]):
                msgs.append("amendments: stale content digest " + rid)
    if previous is not None:
        for rid in sorted(previous.keys() & current.keys()):
            if previous[rid] != current[rid] and rid not in declared:
                msgs.append("amendments: undeclared amendment " + rid)
    return msgs


VECTOR_LABEL = re.compile(r"^\| ([0-9]+[a-z]?\.[a-z]+)\b", re.M)


def coverage_counts(index, assets):
    return {sec: (sum(v["section"] == sec and v["type"] != "retired" for v in index.values()),
                  len(VECTOR_LABEL.findall(vectors)), len(re.findall(r"^## Q[^\n]+", review, re.M)))
            for sec, (vectors, review) in assets.items()}


def check_coverage(index_text, index, assets):
    section = re.search(r"^## Coverage\n(.*?)(?=^## |\Z)", index_text, re.M | re.S)
    rows, msgs = {}, []
    if section:
        for line in section[1].splitlines():
            cells = split_cells(line)
            if len(cells) == 4 and all(c.isdigit() for c in cells[1:]):
                if cells[0] in rows:
                    msgs.append("coverage: duplicate section " + cells[0])
                rows[cells[0]] = tuple(map(int, cells[1:]))
    actual = coverage_counts(index, assets)
    for sec, counts in actual.items():
        if sec not in rows:
            msgs.append("coverage: missing " + sec)
        elif rows[sec] != counts:
            msgs.append("coverage: %s says %s but assets contain %s" % (sec, rows[sec], counts))
    for sec in rows.keys() - actual.keys():
        msgs.append("coverage: unknown section " + sec)
    for sec, (vectors, _review) in assets.items():
        for heading in re.finditer(r"^## (" + ID + r")\n(.*?)(?=^## |\Z)", vectors, re.M | re.S):
            seen = set()
            for label in VECTOR_LABEL.findall(heading[2]):
                if label in seen:
                    msgs.append("coverage: duplicate vector %s under %s" % (label, heading[1]))
                seen.add(label)
    return msgs


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
    ap.add_argument("--amendments-base", help="compare governed text against the externally supplied PR/push base; require every amended ID in INDEX.md")
    args = ap.parse_args()
    text = open(SPEC).read()
    index, dup_rows = load_index()
    section_at = section_finder(text)
    bad = 0

    upgrades = os.path.join(DOCS, "UPGRADES.md")
    helper = open(upgrades).read()
    msgs = check_markdown_structure("SPEC.md", text) + check_markdown_structure("UPGRADES.md", helper)
    bad += fail(msgs) if msgs else (print("ok   markdown structure") or 0)
    msgs = check_marker_placement(text)
    bad += fail(msgs) if msgs else (print("ok   marker placement") or 0)

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
    # A rule that moves keeps its ID, so the section in its ID is a citation, not a location:
    # INDEX.md must name the section the marker actually sits in.
    located = {}
    for pos, i in found:
        located[i] = section_at(pos)
        if i in index and index[i]["type"] not in LIVE:
            msgs.append("markers: %s has INDEX type %s but carries a marker" % (i, index[i]["type"]))
        if i in index and index[i]["section"] != located[i]:
            msgs.append("markers: %s sits in section %s but INDEX says %s" % (i, located[i], index[i]["section"]))
    by = {}
    for pos, i in found:
        # numbering and order are per ID namespace; a moved rule is outside its namespace's
        # run of the document, so it is checked for numbering but not for position
        by.setdefault(i.split("-")[1], []).append((pos, parse_id(i), located[i] == i.split("-")[1]))
    for sec in sorted(by):
        seq = [p for _, p, home in by[sec] if home]
        if seq != sorted(seq):
            msgs.append("markers: section %s is not in document order" % sec)
        numbers = {p[0] for _, p, _home in by[sec]}
        gaps = {parse_id(i)[0] for i in retired if i.split("-")[1] == sec}
        missing = sorted(set(range(1, max(numbers) + 1)) - numbers - gaps)
        if missing:
            msgs.append("markers: section %s is missing %s (no marker and not retired in INDEX)" % (sec, missing[:6]))
    bad += fail(msgs) if msgs else (print("ok   markers (%d)" % len(ids)) or 0)

    # 3. index
    msgs = []
    if dup_rows:
        msgs.append("index: %d duplicate INDEX row(s), e.g. %s" % (len(dup_rows), sorted(set(dup_rows))[:3]))
    bad_types = {i: v["type"] for i, v in index.items() if v["type"] not in LIVE + ("retired",)}
    if bad_types:
        msgs.append("index: unknown type(s): %s" % list(bad_types.items())[:3])
    bad += fail(msgs) if msgs else (print("ok   index (%d live, %d retired)" % (len(live), len(retired))) or 0)

    baseline = git_show(args.amendments_base) if args.amendments_base else None
    baseline_helper = (git_show(args.amendments_base, "UPGRADES.md") or "") if args.amendments_base else ""
    msgs = check_amendments(text, open(INDEX).read(), index, baseline, helper, baseline_helper)
    if args.amendments_base and baseline is None:
        msgs.append("amendments: cannot read supplied base")
    bad += fail(msgs) if msgs else (print("ok   amendments" + (" (base delta checked)" if baseline is not None else " (declarations only)")) or 0)

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

    assets = {}
    for sec in {v["section"] for v in index.values()}:
        paths = [os.path.join(RULES, kind, sec + ".md") for kind in ("vectors", "review")]
        if all(os.path.exists(path) for path in paths):
            assets[sec] = tuple(open(path).read() for path in paths)
    msgs = check_coverage(open(INDEX).read(), index, assets)
    bad += fail(msgs) if msgs else (print("ok   coverage counts and vector labels") or 0)

    # 5. explicitly incorporated upgrade definitions
    msgs = check_incorporation(text, helper, index)
    bad += fail(msgs) if msgs else (print("ok   incorporation (UPGRADES.md)") or 0)

    # 6. links and tables
    msgs, cache = [], {}
    def headings(path):
        if path not in cache:
            cache[path] = {slug(m.group(2)) for m in re.finditer("^(#{1,6}) (.*)$", open(path).read(), flags=re.M)}
        return cache[path]
    for f in glob.glob(os.path.join(RULES, "**", "*.md"), recursive=True) + [SPEC, upgrades]:
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
