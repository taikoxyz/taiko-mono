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

HERE = os.path.dirname(os.path.realpath(__file__))
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


def git_path_absent(rev, relative):
    """Confirm path absence in a readable commit tree, rather than a failed blob read."""
    top = subprocess.run(["git", "-C", DOCS, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if top.returncode:
        return False
    path = os.path.relpath(os.path.join(DOCS, relative), top.stdout.strip())
    result = subprocess.run(["git", "-C", DOCS, "ls-tree", "--full-tree", "--name-only", "-z",
                             rev + "^{commit}", "--", path], capture_output=True, text=True)
    return result.returncode == 0 and not result.stdout


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


def parse_index(text):
    rows, dups = {}, []
    for line in active_markdown(text).split(NL):
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


def load_index():
    return parse_index(open(INDEX).read())


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


def markdown_regions(text, conservative=False):
    """Mask fenced code while retaining offsets; return complete raw fenced regions."""
    out, opening, regions, offset = [], None, [], 0
    for line in text.splitlines(keepends=True):
        content = line.rstrip("\r\n")
        # Broad masking rejects list-relative examples; only strict fences grant authority.
        indent = r"[ \t]*" if conservative else r" {0,3}"
        fence = re.match(r"^" + indent + r"(`{3,}|~{3,})(.*)$", content)
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


def inline_code_regions(text):
    """Recognize same-line literal spans; block openers never inherit a prior line's span."""
    return [(match.start(), match.end()) for match in re.finditer(
        r"(?<![`\\])(`+)(?!`)[^\r\n]*?(?<!`)\1(?!`)", text)]


def mask_regions(text, regions):
    """Hide source regions without changing offsets or line boundaries."""
    out, end = [], 0
    for start, stop in regions:
        out.extend((text[end:start], re.sub(r"[^\r\n]", " ", text[start:stop])))
        end = stop
    out.append(text[end:])
    return "".join(out)


def comment_regions(text):
    """Find comments outside literal examples, with comments taking precedence over fences."""
    regions, opening, fence, offset = [], None, None, 0
    for line in text.splitlines(keepends=True):
        match = re.match(r"^[ \t]*(`{3,}|~{3,})(.*)$", line.rstrip("\r\n"))
        if opening is None:
            if fence:
                if match and match[1][0] == fence[0] and len(match[1]) >= fence[1] and not match[2].strip():
                    fence = None
                offset += len(line)
                continue
            if match and not (match[1][0] == "`" and "`" in match[2]):
                fence = (match[1][0], len(match[1]))
                offset += len(line)
                continue
        spans, cursor = inline_code_regions(line), 0
        while cursor < len(line):
            if opening is not None:
                closing = line.find("-->", cursor)
                if closing < 0:
                    break
                cursor = closing + 3
                regions.append((opening, offset + cursor))
                opening = None
            else:
                start = line.find("<!--", cursor)
                if start < 0:
                    break
                literal = next((end for begin, end in spans if begin <= start < end), None)
                if literal is not None:
                    cursor = literal
                    continue
                opening, cursor = offset + start, start + 4
        offset += len(line)
    if opening is not None:
        regions.append((opening, len(text)))
    return regions


def is_governing_comment(text, start, end):
    """Only an exact standalone mapping comment can supply helper ownership."""
    return (re.fullmatch(r"<!-- governed-by: " + ID + r" -->", text[start:end]) is not None
            and (start == 0 or text[start - 1] == NL)
            and (end == len(text) or text[end] in "\r\n"))


def without_comments(text, keep_governing=False):
    regions = [(start, end) for start, end in comment_regions(text)
               if not (keep_governing and is_governing_comment(text, start, end))]
    return mask_regions(text, regions)


def active_markdown(text, keep_governing=False):
    """Active headings/tables cannot be supplied by comments or fenced examples."""
    return markdown_regions(without_comments(text, keep_governing), conservative=True)[0]


def check_markdown_structure(name, text):
    masked, unclosed, _ = markdown_regions(without_comments(text), conservative=True)
    msgs = ["markdown: unclosed fence in " + name] if unclosed else []
    lines = masked.splitlines()
    for i, line in enumerate(lines):
        if i and lines[i - 1].strip() and re.fullmatch(r" {0,3}(?:=+|-+)[ \t]*", line):
            msgs.append("markdown: setext headings are unsupported in " + name + "; use ATX headings")
    if name in ("SPEC.md", "UPGRADES.md"):
        # This is a bounded source format, not an attempt to implement arbitrary HTML/CommonMark.
        # A block opener on its own line is structural even after an unmatched backtick.
        literal_mask = mask_regions(masked, inline_code_regions(masked))
        comments = comment_regions(text)
        invalid_comment = any(not (name == "UPGRADES.md" and is_governing_comment(text, start, end))
                              for start, end in comments)
        html = re.finditer(r"(?<!\\)<(?:/?[A-Za-z][A-Za-z0-9-]*(?=[\s/>]|$)|!|[?])", literal_mask)
        invalid_tag = any(not re.match(r"(?:</?(?:details|summary)>|<br ?/?>)", literal_mask[match.start():])
                          for match in html)
        if invalid_comment or invalid_tag:
            msgs.append("markdown: unsupported HTML in " + name
                        + "; use details, summary or br tags, or fenced/inline literal examples")
        if re.search(r"^[ \t]*(?:(?:[-+*]|[0-9]+[.)])[ \t]+)*>", literal_mask, re.M):
            msgs.append("markdown: blockquote containers are unsupported in " + name)
    return msgs


def check_marker_placement(spec):
    masked, _, regions = markdown_regions(spec, conservative=True)
    _, _, definitions = markdown_regions(spec)
    locate, msgs = section_finder(spec), []
    spans = list(re.finditer(r"(?<![`\\])(`+)(?!`)(?:[^\n]|\n(?![ \t]*\n))*?(?<!`)\1(?!`)", masked))
    comments, raw_html, hidden_end = comment_regions(spec), [], 0
    literal_mask = mask_regions(mask_regions(masked, comments), inline_code_regions(masked))
    # Search raw text for closing tags: a hidden HTML region may contain an entire fence.
    # Only the opener uses fence masking, so literal tags within a code example stay literal.
    for opening in re.finditer(r"<(pre|script|style|textarea)(?=[\s>])[^>]*>", spec, re.I):
        if opening.start() < hidden_end or literal_mask[opening.start()] != "<":
            continue
        closing = re.search(r"</" + opening[1] + r"\s*>", spec[opening.end():], re.I)
        hidden_end = opening.end() + closing.end() if closing else len(spec)
        raw_html.append((opening.start(), hidden_end))
    # Preserve valid nested list items: their container indentation is not code indentation.
    list_indents, indented, offset = [], set(), 0
    lines = spec.splitlines(keepends=True)
    for line in lines:
        indent = len(re.match(r"^[ \t]*", line)[0].expandtabs(4))
        fenced = any(start <= offset < end for start, end, _ in regions)
        if line.strip():
            while list_indents and indent < list_indents[-1]:
                list_indents.pop()
            container = list_indents[-1] if list_indents else 0
            item = re.match(r"^[ ]*(?:[-+*]|[0-9]+[.)])[ \t]+", line)
            if indent - container >= 4:
                indented.add(offset)
            elif item and not fenced:
                list_indents.append(len(item[0].expandtabs(4)))
        offset += len(line)
    for marker in INLINE.finditer(spec):
        if any(start <= marker.start() < end for start, end, _ in regions):
            msgs.append("placement: inline rule inside fenced code " + marker[1])
        elif any(start <= marker.start() < end for start, end in comments):
            msgs.append("placement: inline rule inside HTML comment " + marker[1])
        elif any(start <= marker.start() < end for start, end in raw_html):
            msgs.append("placement: inline rule inside raw HTML code " + marker[1])
        elif any(span.start() <= marker.start() < span.end() for span in spans):
            msgs.append("placement: inline rule inside inline code " + marker[1])
        elif spec.rfind(NL, 0, marker.start()) + 1 in indented:
            msgs.append("placement: inline rule inside indented code " + marker[1])
    for line, following in zip(lines, lines[1:]):
        markers = INLINE.findall(line)
        # One-line scopes cannot silently leave the rest of a rendered paragraph ungoverned.
        boundary = re.match(r"^[ \t]*(?:#{1,6} |[|>]|`{3,}|~{3,}|[-+*] |[0-9]+[.)] |<!--)", following)
        if (markers and not line.lstrip().startswith("|") and following.strip()
                and not INLINE.search(following) and not boundary):
            msgs.append("placement: unmarked paragraph continuation after " + markers[-1])
    for marker in CODE.finditer(spec):
        if any(start <= marker.start() < end for start, end in comments + raw_html):
            msgs.append("placement: code-before marker inside hidden HTML " + marker[1])
            continue
        authorized = marker[1].startswith("ENC-A-") and locate(marker.start()) == "A" and any(
            start <= marker.start() < end and info == "txt" for start, end, info in definitions)
        if not authorized:
            msgs.append("placement: code-before marker outside Appendix A definition " + marker[1])
    return msgs


def check_incorporation(spec, helper, index):
    """Check the explicit exception for definitions incorporated under SPEC rules."""
    # Examples cannot create sections or supply authority. Keep offsets/lines stable.
    body = active_markdown(helper, keep_governing=True)
    _, unclosed = outside_fences(without_comments(helper))
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
    text = without_comments(text)
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
    masked = active_markdown(helper, keep_governing=True)
    sections = list(re.finditer(r"^## (.+)$", masked, re.M))
    for i, section in enumerate(sections):
        end = sections[i + 1].start() if i + 1 < len(sections) else len(helper)
        owners = re.findall(r"^<!-- governed-by: (" + ID + r") -->$", masked[section.end():end], re.M)
        if len(owners) == 1 and owners[0] in bodies:
            bodies[owners[0]] += "\n[UPGRADES.md#" + slug(section[1]) + "]\n" + helper[section.start():end].strip()
    return bodies


def content_digest(body, kind):
    """Bind both the statement's governed content and its normative Type."""
    return hashlib.blake2s(("type: " + kind + "\n" + body).encode("utf-8")).hexdigest()


def amendment_rows(text, heading="Material amendments"):
    section = re.search(r"^## " + re.escape(heading) + r"\n(.*?)(?=^## |\Z)",
                        active_markdown(text), re.M | re.S)
    if section:
        for line in section[1].splitlines():
            cells = split_cells(line)
            header = ["ID", "Prior meaning", "Current amendment", "Content digest"]
            if (line.startswith("|") and cells != header
                    and not all(re.fullmatch(r":?-+:?", cell) for cell in cells)):
                yield cells


def git_declaration_snapshots(rev, current_index_text):
    """Verify superseded declarations on ancestry edges after the supplied Git base.

    Each edge supplies one occurrence of an exact row only when its digest binds the
    parent's complete governed content and Type. Legacy/unreadable states supply no proof.
    """
    base = subprocess.run(["git", "-C", DOCS, "rev-parse", "--verify", rev + "^{commit}"],
                          capture_output=True, text=True)
    if base.returncode:
        raise ValueError("cannot read declaration provenance at supplied base")
    base = base.stdout.strip()
    graph = subprocess.run(["git", "-C", DOCS, "rev-list", "--parents", "--ancestry-path", base + "..HEAD"],
                           capture_output=True, text=True)
    if graph.returncode:
        raise ValueError("cannot read declaration provenance after supplied base")
    edges = [line.split() for line in graph.stdout.splitlines()]
    ancestry = {base} | {edge[0] for edge in edges}
    cache, snapshots = {}, []
    head = subprocess.run(["git", "-C", DOCS, "rev-parse", "--verify", "HEAD"],
                          capture_output=True, text=True)
    if head.returncode:
        raise ValueError("cannot read declaration provenance at HEAD")
    head = head.stdout.strip()
    # Pre-commit checks include the working declaration transition exactly once. After a
    # commit this edge is unchanged; the actual parent->commit edge then supplies the proof.
    if head in ancestry:
        working = "working declaration"
        cache[working] = (parse_index(current_index_text)[0],
                          {row[0]: row for row in amendment_rows(current_index_text)})
        edges.insert(0, [working, head])

    def state(commit):
        if commit not in cache:
            source = git_show(commit, "rules/INDEX.md")
            cache[commit] = None if source is None else (
                parse_index(source)[0], {row[0]: row for row in amendment_rows(source)})
        return cache[commit]

    for child, *parents in edges:
        now = state(child)
        if now is None:
            continue
        for parent in parents:
            if parent not in ancestry:
                continue
            before = state(parent)
            if before is None:
                continue
            index, declared = before
            candidates = [row for rid, row in declared.items()
                          if rid in now[1] and row != now[1][rid] and len(row) == 4
                          and re.fullmatch(ID, rid) and index.get(rid, {}).get("type") in LIVE + ("retired",)]
            if not candidates:
                continue
            spec, helper = git_show(parent), git_show(parent, "UPGRADES.md")
            if spec is None:
                continue
            if helper is None:
                if "UPGRADES.md" in spec or not git_path_absent(parent, "UPGRADES.md"):
                    continue
                helper = ""
            try:
                bodies = governed_bodies(spec, helper)
            except ValueError:
                continue
            snapshots.extend(row for row in candidates
                             if (row[0] in bodies or index[row[0]]["type"] == "retired")
                             and row[3] == content_digest(bodies.get(row[0], ""), index[row[0]]["type"]))
    return snapshots


def check_amendments(spec, index_text, index, baseline=None, helper="", baseline_helper="",
                     baseline_index_text=None, verified_snapshots=()):
    msgs, declared = [], {}
    try:
        current = governed_bodies(spec, helper)
        previous = governed_bodies(baseline, baseline_helper) if baseline is not None else None
    except ValueError as error:
        return ["amendments: " + str(error)]
    for cells in amendment_rows(index_text):
        rid = cells[0]
        if rid in declared:
            msgs.append("amendments: duplicate amendment " + rid)
        declared[rid] = cells
        if rid not in index:
            msgs.append("amendments: unknown amendment " + rid)
        if len(cells) != 4 or not all(cells[1:]):
            msgs.append("amendments: incomplete amendment " + rid)
        elif rid in index and (rid in current or index[rid]["type"] == "retired"):
            if cells[3] != content_digest(current.get(rid, ""), index[rid]["type"]):
                msgs.append("amendments: stale content digest " + rid)
    snapshots = list(amendment_rows(index_text, "Amendment history"))
    for cells in snapshots:
        rid = cells[0]
        if rid not in index:
            msgs.append("amendments: unknown historical amendment " + rid)
        if len(cells) != 4 or not all(cells[1:]) or not re.fullmatch(r"[0-9a-f]{64}", cells[-1]):
            msgs.append("amendments: malformed historical amendment " + rid)
    if previous is not None:
        for rid in sorted(previous.keys() - current.keys()):
            if index.get(rid, {}).get("type") != "retired":
                msgs.append("amendments: missing retired tombstone " + rid)
        for rid in sorted(previous.keys() & current.keys()):
            if previous[rid] != current[rid] and rid not in declared:
                msgs.append("amendments: undeclared amendment " + rid)
    if baseline_index_text is not None:
        prior_snapshots = list(amendment_rows(baseline_index_text, "Amendment history"))
        if snapshots[:len(prior_snapshots)] != prior_snapshots:
            msgs.append("amendments: historical snapshots are not append-only")
        added_snapshots = snapshots[len(prior_snapshots):]
        verified = list(verified_snapshots)
        prior_index, _ = parse_index(baseline_index_text)
        for rid, old in prior_index.items():
            now = index.get(rid)
            if now is None:
                message = "amendments: missing retired tombstone " + rid
                if message not in msgs:
                    msgs.append(message)
            elif old["type"] == "retired" and (now["type"] != "retired" or rid in current):
                msgs.append("amendments: retired ID reused " + rid)
            elif old["type"] != now["type"] and rid not in declared:
                message = "amendments: undeclared amendment " + rid
                if message not in msgs:
                    msgs.append(message)
        for cells in amendment_rows(baseline_index_text):
            rid = cells[0]
            if rid not in declared:
                msgs.append("amendments: removed history " + rid)
            elif len(cells) > 1 and len(declared[rid]) > 1 and cells[1] != declared[rid][1]:
                msgs.append("amendments: rewritten prior meaning " + rid)
            if rid in declared and cells != declared[rid]:
                if cells not in added_snapshots:
                    msgs.append("amendments: missing declaration snapshot " + rid)
                else:
                    added_snapshots.remove(cells)
                    if cells in verified:
                        verified.remove(cells)
        for cells in added_snapshots:
            if cells in verified:
                verified.remove(cells)
            else:
                msgs.append("amendments: unsupported declaration snapshot " + cells[0])
    return msgs


VECTOR_LABEL = re.compile(r"^\| ([0-9]+[a-z]?\.[a-z]+)\b", re.M)


def coverage_counts(index, assets):
    return {sec: (sum(v["section"] == sec and v["type"] != "retired" for v in index.values()),
                  len(VECTOR_LABEL.findall(active_markdown(vectors))),
                  len(re.findall(r"^## Q[^\n]+", active_markdown(review), re.M)))
            for sec, (vectors, review) in assets.items()}


def check_coverage(index_text, index, assets):
    section = re.search(r"^## Coverage\n(.*?)(?=^## |\Z)", active_markdown(index_text), re.M | re.S)
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
        for heading in re.finditer(r"^## (" + ID + r")\n(.*?)(?=^## |\Z)", active_markdown(vectors), re.M | re.S):
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
    if args.amendments_base is not None and not args.amendments_base.strip():
        ap.error("--amendments-base must not be empty")
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

    base_files, msgs = {}, []
    if args.amendments_base:
        for path in ("SPEC.md", "rules/INDEX.md", "UPGRADES.md"):
            base_files[path] = git_show(args.amendments_base, path)
            if base_files[path] is None:
                base_spec = base_files.get("SPEC.md")
                if (path == "UPGRADES.md" and base_spec is not None and "UPGRADES.md" not in base_spec
                        and git_path_absent(args.amendments_base, path)):
                    base_files[path] = ""
                else:
                    msgs.append("amendments: cannot read %s at supplied base" % os.path.basename(path))
    baseline = base_files.get("SPEC.md")
    verified = []
    if not msgs and args.amendments_base:
        try:
            verified = git_declaration_snapshots(args.amendments_base, open(INDEX).read())
        except ValueError as error:
            msgs.append("amendments: " + str(error))
    if not msgs:
        msgs = check_amendments(text, open(INDEX).read(), index, baseline, helper,
                                base_files.get("UPGRADES.md", ""), base_files.get("rules/INDEX.md"),
                                verified_snapshots=verified)
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
        got = set(re.findall("^## (" + ID + ")[ \t]*$", active_markdown(open(vf).read()), flags=re.M))
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
            cache[path] = {slug(m.group(2)) for m in re.finditer("^(#{1,6}) (.*)$", active_markdown(open(path).read()), flags=re.M)}
        return cache[path]
    for f in glob.glob(os.path.join(RULES, "**", "*.md"), recursive=True) + [SPEC, upgrades]:
        source = open(f).read()
        body = active_markdown(source)
        if f not in (SPEC, upgrades) and markdown_regions(without_comments(source), conservative=True)[1]:
            msgs.append("markdown: unclosed fence in " + os.path.relpath(f, DOCS))
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
        block = []
        for ln in body.split(NL) + [""]:
            if ln.startswith("|"):
                block.append(ln)
            else:
                if block and (len(block) < 2 or not all(
                        re.fullmatch(r":?-{3,}:?", cell) for cell in split_cells(block[1]))):
                    msgs.append("tables: %s needs a header and separator before table rows" % os.path.basename(f))
                if len(block) >= 2 and len({columns(b) for b in block}) != 1:
                    msgs.append("tables: %s has a row with a different column count" % os.path.basename(f))
                block = []
    bad += fail(msgs) if msgs else (print("ok   links and tables") or 0)

    print(NL + ("ALL CHECKS PASSED" if bad == 0 else "%d problem(s)" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
