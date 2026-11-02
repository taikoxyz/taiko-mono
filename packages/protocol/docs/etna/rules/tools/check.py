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
              (GFM pipes require escaping, including inside inline code spans)

Exit code 0 only if every check passes.
"""
import argparse, glob, hashlib, os, re, subprocess, sys
from collections import Counter
from functools import lru_cache
from html.parser import HTMLParser

try:
    from cmarkgfm.cmark import Options as CMarkOptions, markdown_to_html_with_extensions
    from markdown_it import MarkdownIt
    from markdown_it.rules_block import table as table_rule
    from markdown_it.rules_block.table import escapedSplit, getLine
    from markdown_it.rules_inline import emphasis
    from markdown_it.tree import SyntaxTreeNode
except ModuleNotFoundError as error:
    if error.name not in ("cmarkgfm", "_cffi_backend", "markdown_it", "mdurl"):
        raise
    requirements = os.path.join(os.path.dirname(os.path.realpath(__file__)), "requirements.txt")
    raise SystemExit("Missing checker dependency; install with: python3 -m pip install -r " + requirements) from None


HERE = os.path.dirname(os.path.realpath(__file__))
RULES = os.path.dirname(HERE)
DOCS = os.path.dirname(RULES)
SPEC = os.path.join(DOCS, "SPEC.md")
INDEX = os.path.join(RULES, "INDEX.md")
NL = chr(10)

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
    """Use the same escaped-pipe splitting as the enabled GFM table rule.

    GFM splits pipes even inside code spans; a literal pipe must be escaped.
    """
    cells = escapedSplit(line.strip())
    if cells and not cells[0]:
        cells.pop(0)
    if cells and not cells[-1]:
        cells.pop()
    return [cell.strip() for cell in cells]


def parse_index(text):
    rows, dups = {}, []
    for _node, cells in markdown(text).rows():
        if len(cells) != 5 or not re.fullmatch(ID, cells[0]):
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
    """Map source offsets to actual rendered SPEC section headings."""
    doc = markdown(text)
    starts = []
    for node in doc.headings():
        match = SECTION.match(doc.source(node).lstrip())
        if match:
            starts.append((doc.span(node)[0], match[1] or match[2]))

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


def sourced_emphasis(state, silent):
    """Retain delimiter source positions through markdown-it's strong processing."""
    start, count = state.pos, len(state.tokens)
    matched = emphasis.tokenize(state, silent)
    if matched and not silent:
        for token in state.tokens[count:]:
            token.meta["source_span"] = (start, state.pos)
    return matched


def sourced_table(state, start, end, silent):
    """Retain all source cells before GFM pads or truncates body rows."""
    count = len(state.tokens)
    matched = table_rule(state, start, end, silent)
    if matched and not silent:
        for token in state.tokens[count:]:
            if token.type == "tr_open":
                token.meta["cells"] = split_cells(getLine(state, token.map[0]))
    return matched


MD = MarkdownIt("commonmark", {"inline_definitions": True}).enable("table")
MD.inline.ruler.at("emphasis", sourced_emphasis)
MD.block.ruler.at("table", sourced_table, {"alt": ["paragraph", "reference"]})


class MarkdownDocument:
    """One CommonMark + GFM parse supplies visibility, containers and source maps."""

    def __init__(self, text):
        self.text = text
        self.lines = text.splitlines(keepends=True)
        self.offsets = [0]
        for line in self.lines:
            self.offsets.append(self.offsets[-1] + len(line))
        self.tree = SyntaxTreeNode(MD.parse(text))
        self.nodes = list(self.tree.walk(include_self=False))

    def span(self, node):
        return self.offsets[node.map[0]], self.offsets[node.map[1]]

    def source(self, node):
        start, end = self.span(node)
        return self.text[start:end]

    def headings(self, level=None):
        return [node for node in self.nodes if node.type == "heading"
                and (level is None or node.tag == "h" + str(level))]

    def title(self, node):
        return node.children[0].content

    def sections(self, title=None):
        headings = [node for node in self.tree.children if node.type == "heading" and node.tag == "h2"]
        return [(node, self.span(headings[i + 1])[0] if i + 1 < len(headings) else len(self.text))
                for i, node in enumerate(headings) if title is None or self.title(node) == title]

    def rows(self, start=0, end=None):
        # Registry/declaration/coverage tables are document blocks, never nested examples.
        for table in (node for node in self.tree.children if node.type == "table"):
            for node in table.walk(include_self=False):
                if node.type == "tr" and start <= self.span(node)[0] < (len(self.text) if end is None else end):
                    yield node, node.meta["cells"]

    def fences(self):
        return [node for node in self.nodes if node.type == "fence"]

    def unclosed(self):
        # The parser excludes both delimiters from content, including in list containers.
        return any(node.map[1] - node.map[0] != node.content.count(NL) + 2 for node in self.fences())

    def governing(self):
        return [(self.span(node)[0], match[1]) for node in self.nodes
                if node.type == "html_block"
                and (match := re.fullmatch(r"<!-- governed-by: (" + ID + r") -->\n?", self.source(node)))]

    def inline_markers(self):
        """Return canonical source markers that the inline parser renders as strong IDs."""
        visible, lookalikes = Counter(), []
        for inline in (node for node in self.nodes if node.type == "inline"):
            for node in inline.walk(include_self=False):
                if node.type != "strong" or len(node.children) != 1 or node.children[0].type != "text":
                    continue
                match = re.fullmatch(r"\[(" + ID + r")\]", node.children[0].content)
                if not match:
                    continue
                tokens = node.to_tokens()
                start = tokens[0].meta.get("source_span", (0, 0))[0]
                end = tokens[-1].meta.get("source_span", (0, 0))[1]
                source = inline.content[start:end]
                canonical = "**[" + match[1] + "]**"
                if source != canonical or inline.content[end:end + 1] != " ":
                    lookalikes.append(match[1])
                else:
                    line = inline.map[0] + inline.content[:start].count(NL)
                    visible[line, match[1]] += 1
            # Entity/escape spellings may render marker punctuation as ordinary text.
            for node in inline.children:
                if node.type == "text":
                    lookalikes.extend(re.findall(r"\*\*\[(" + ID + r")\]\*\*", node.content))
        markers = []
        for match in INLINE.finditer(self.text):
            line = self.text.count(NL, 0, match.start())
            if visible[line, match[1]]:
                visible[line, match[1]] -= 1
                markers.append(match)
        return markers, lookalikes


@lru_cache(maxsize=32)
def markdown(text):
    return MarkdownDocument(text)


class RenderedHTML(HTMLParser):
    """Compare renderer output without serialization-only HTML whitespace.

    Keep all text within inline/text containers and pre/code, including whitespace-only
    code. Only indentation/newlines between document/list/table blocks are discarded.
    """

    VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}
    TEXT = {"p", "li", "summary", "td", "th", "a", "em", "strong", "del", "pre", "code",
            "h1", "h2", "h3", "h4", "h5", "h6"}

    def __init__(self, source):
        super().__init__(convert_charrefs=True)
        self.events, self.stack = [], []
        self.feed(source)
        self.close()

    def handle_starttag(self, tag, attrs):
        self.events.append(("start", tag, tuple(sorted(attrs, key=repr))))
        if tag not in self.VOID:
            self.stack.append(tag)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in self.VOID:
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        if tag in self.VOID:
            return
        self.events.append(("end", tag))
        if tag in self.stack:
            del self.stack[len(self.stack) - 1 - self.stack[::-1].index(tag):]

    def handle_data(self, data):
        if not data.strip() and not any(tag in self.TEXT for tag in self.stack):
            return
        if self.events and self.events[-1][0] == "text":
            self.events[-1] = ("text", self.events[-1][1] + data)
        else:
            self.events.append(("text", data))

    def handle_comment(self, data):
        self.events.append(("comment", data))


def renderer_agreement(text):
    """Require the source-map parser and GitHub's reference parser to agree.

    These documents use their shared bounded syntax, rather than accepting all GFM.
    Enable GitHub extensions and footnotes on the reference side so hidden/deleted
    content or differing HTML block grammars cannot masquerade as shared syntax.
    """
    reference = markdown_to_html_with_extensions(
        text, options=CMarkOptions.CMARK_OPT_UNSAFE | CMarkOptions.CMARK_OPT_FOOTNOTES,
        extensions=["table", "autolink", "tagfilter", "strikethrough", "tasklist"])
    return RenderedHTML(MD.render(text)).events == RenderedHTML(reference).events



class SupportedHTML(HTMLParser):
    """Validate raw HTML tokens against the small normative-document allowlist."""

    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.invalid = False

    def handle_starttag(self, tag, attrs):
        self.invalid |= re.fullmatch(r"<(?:details|summary|br)>|<br ?/>", self.get_starttag_text()) is None

    handle_startendtag = handle_starttag

    def handle_endtag(self, tag):
        line, column = self.getpos()
        source = self.rawdata.splitlines(keepends=True)
        raw = "".join(source[line - 1:])[column:]
        self.invalid |= re.match(r"</(?:details|summary)>", raw) is None

    def handle_comment(self, data):
        self.invalid = True

    def handle_decl(self, decl):
        self.invalid = True

    def handle_pi(self, data):
        self.invalid = True

    def unknown_decl(self, data):
        self.invalid = True


def check_markdown_structure(name, text):
    doc = markdown(text)
    msgs = ["markdown: unclosed fence in " + name] if doc.unclosed() else []
    if any(node.markup in ("=", "-") for node in doc.headings()):
        msgs.append("markdown: setext headings are unsupported in " + name + "; use ATX headings")
    if name in ("SPEC.md", "UPGRADES.md", "rules/INDEX.md"):
        if not renderer_agreement(text):
            msgs.append("markdown: renderer disagreement in " + name)
        allowed = {pos for pos, _rid in doc.governing()} if name == "UPGRADES.md" else set()
        invalid = False
        for node in doc.nodes:
            if node.type not in ("html_block", "html_inline"):
                continue
            if node.type == "html_block" and doc.span(node)[0] in allowed:
                continue
            parser = SupportedHTML()
            parser.feed(node.content)
            parser.close()
            # A block beginning with an incomplete/unknown HTML opener is not allowed.
            if node.type == "html_block" and not re.match(r"</?(?:details|summary)>|<br ?/?>", node.content):
                invalid = True
            invalid |= parser.invalid
        if invalid:
            msgs.append("markdown: unsupported HTML in " + name
                        + "; use details, summary or br tags, or fenced/inline literal examples")
        if any(node.type == "blockquote" for node in doc.nodes):
            msgs.append("markdown: blockquote containers are unsupported in " + name)
        if any(node.type == "definition" for node in doc.nodes):
            msgs.append("markdown: link reference definitions are unsupported in " + name)
    return msgs


def check_marker_placement(spec):
    doc, msgs = markdown(spec), []
    visible, lookalikes = doc.inline_markers()
    positions = {match.start() for match in visible}
    for rid in lookalikes:
        msgs.append("placement: noncanonical rendered rule marker " + rid)
    for marker in INLINE.finditer(spec):
        if marker.start() in positions:
            continue
        block = next((node for node in doc.nodes if node.map
                      and node.type in ("fence", "code_block", "html_block", "definition")
                      and doc.span(node)[0] <= marker.start() < doc.span(node)[1]), None)
        kind = {"fence": "fenced code", "code_block": "indented code", "definition": "link reference definition"}
        if block is not None and block.type == "html_block":
            reason = "HTML comment" if block.content.startswith("<!--") else "raw HTML code"
        else:
            reason = kind.get(block.type if block is not None else None, "inline code or noncanonical prose")
        if reason == "inline code or noncanonical prose":
            reason = "inline code"  # Also rejects escaped punctuation and HTML attributes.
        msgs.append("placement: inline rule inside " + reason + " " + marker[1])
    for node in doc.nodes:
        if node.type != "paragraph" or node.map[1] - node.map[0] <= 1:
            continue
        previous = None
        for line in doc.source(node).splitlines():
            markers = list(INLINE.finditer(line))
            if previous and line.strip() and (not markers or line[:markers[0].start()].strip()):
                msgs.append("placement: unmarked paragraph continuation after " + previous)
            previous = markers[-1][1] if markers else None
    locate = section_finder(spec)
    for marker in CODE.finditer(spec):
        block = next((node for node in doc.nodes if node.map
                      and node.type in ("fence", "html_block")
                      and doc.span(node)[0] <= marker.start() < doc.span(node)[1]), None)
        if block is not None and block.type == "html_block":
            msgs.append("placement: code-before marker inside hidden HTML " + marker[1])
        elif not (marker[1].startswith("ENC-A-") and locate(marker.start()) == "A"
                  and block is not None and block.info.strip() == "txt"):
            msgs.append("placement: code-before marker outside Appendix A definition " + marker[1])
    return msgs


def check_incorporation(spec, helper, index):
    """Check the explicit exception for definitions incorporated under SPEC rules."""
    doc = markdown(helper)
    sections, mappings = doc.sections(), doc.governing()
    msgs, seen, used = [], set(), 0
    bodies = rule_bodies(spec)
    if doc.unclosed():
        msgs.append("incorporation: unclosed fence in UPGRADES.md")
    if not sections:
        msgs.append("incorporation: UPGRADES.md has no governed sections")
    for section, end in sections:
        title = doc.title(section)
        owners = [rid for start, rid in mappings if doc.span(section)[1] <= start < end]
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
        backlink = "UPGRADES.md#" + anchor
        rule = bodies.get(rid, "")
        links = SyntaxTreeNode(MD.parseInline(rule)).walk(include_self=False)
        if not any(node.type == "link" and node.attrGet("href") == backlink for node in links):
            msgs.append("incorporation: %s needs owning-rule backlink to %s" % (rid, backlink))
    if used != len(mappings):
        msgs.append("incorporation: governing ID outside a section")
    return msgs


def rule_bodies(text):
    """Extract governed text for amendment comparison, ignoring formatter spacing."""
    doc = markdown(text)
    visible, _lookalikes = doc.inline_markers()
    markers = sorted([(m.start(), m.end(), m[1], False) for m in visible] +
                     [(m.start(), m.end(), m[1], True) for m in CODE.finditer(text)
                      if any(doc.span(node)[0] <= m.start() < doc.span(node)[1] for node in doc.fences())])
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
    doc = markdown(spec)
    regions = [(*doc.span(node), node.info.strip()) for node in doc.fences()]
    if "LAND-6.1-10" in bodies:
        locate = section_finder(spec)
        references = [spec[start:end].strip() for start, end, info in regions
                      if info == "solidity" and locate(start) == "6.1"]
        if len(references) != 1:
            raise ValueError("reference Solidity under LAND-6.1-10 must be exactly one block")
        bodies["LAND-6.1-10"] += "\n[reference Solidity]\n" + references[0]
    doc = markdown(helper)
    for section, end in doc.sections():
        owners = [rid for start, rid in doc.governing() if doc.span(section)[1] <= start < end]
        if len(owners) == 1 and owners[0] in bodies:
            start = doc.span(section)[0]
            bodies[owners[0]] += "\n[UPGRADES.md#" + slug(doc.title(section)) + "]\n" + helper[start:end].strip()
    return bodies


def content_digest(body, kind):
    """Bind both the statement's governed content and its normative Type."""
    return hashlib.blake2s(("type: " + kind + "\n" + body).encode("utf-8")).hexdigest()


def amendment_rows(text, heading="Material amendments"):
    doc = markdown(text)
    for section, end in doc.sections(heading):
        for node, cells in doc.rows(doc.span(section)[1], end):
            if node.children[0].type == "td":
                yield cells


def check_amendments(spec, index_text, index, baseline=None, helper="", baseline_helper="",
                     baseline_index_text=None):
    msgs, declared = [], {}
    doc = markdown(index_text)
    for heading in ("Material amendments", "Amendment history"):
        if len(doc.sections(heading)) > 1:
            msgs.append("amendments: duplicate section " + heading)
        for section, end in doc.sections(heading):
            for node, cells in doc.rows(doc.span(section)[1], end):
                if node.children[0].type == "th" and cells != ["ID", "Prior meaning", "Current amendment", "Content digest"]:
                    msgs.append("amendments: invalid table header under " + heading)
    try:
        current = governed_bodies(spec, helper)
        previous = governed_bodies(baseline, baseline_helper) if baseline is not None else None
    except ValueError as error:
        return ["amendments: " + str(error)]
    for cells in amendment_rows(index_text):
        if not cells:
            msgs.append("amendments: incomplete amendment (empty row)")
            continue
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
        rid = cells[0] if cells else "(empty row)"
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
            if not cells:
                msgs.append("amendments: malformed base declaration (empty row)")
                continue
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
        for cells in added_snapshots:
            msgs.append("amendments: unsupported declaration snapshot " + (cells[0] if cells else "(empty row)"))
    return msgs


VECTOR_LABEL = re.compile(r"^([0-9]+[a-z]?\.[a-z]+)\b")


def vector_labels(text, start=0, end=None):
    return [match[1] for node, cells in markdown(text).rows(start, end)
            if node.children[0].type == "td" and cells and (match := VECTOR_LABEL.match(cells[0]))]


def coverage_counts(index, assets):
    return {sec: (sum(v["section"] == sec and v["type"] != "retired" for v in index.values()),
                  len(vector_labels(vectors)),
                  sum(markdown(review).title(node).startswith("Q") for node in markdown(review).headings(2)))
            for sec, (vectors, review) in assets.items()}


def check_coverage(index_text, index, assets):
    doc = markdown(index_text)
    rows, msgs = {}, []
    if len(doc.sections("Coverage")) > 1:
        msgs.append("coverage: duplicate Coverage section")
    for section, end in doc.sections("Coverage"):
        for _node, cells in doc.rows(doc.span(section)[1], end):
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
    for _sec, (vectors, _review) in assets.items():
        doc = markdown(vectors)
        for heading, end in doc.sections():
            if not re.fullmatch(ID, doc.title(heading)):
                continue
            seen = set()
            for label in vector_labels(vectors, doc.span(heading)[1], end):
                if label in seen:
                    msgs.append("coverage: duplicate vector %s under %s" % (label, doc.title(heading)))
                seen.add(label)
    return msgs


def check_tables(name, source):
    doc, msgs = markdown(source), []
    for node in doc.nodes:
        if node.type == "table":
            widths = {len(row.meta["cells"]) for row in node.walk(include_self=False)
                      if row.type == "tr"}
            if len(widths) != 1:
                msgs.append("tables: %s has a row with a different column count" % name)
        elif node.type == "paragraph" and any(line.lstrip().startswith("|") for line in node.children[0].content.splitlines()):
            msgs.append("tables: %s needs a header and separator before table rows" % name)
    return msgs


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
    msgs = (check_markdown_structure("SPEC.md", text)
            + check_markdown_structure("UPGRADES.md", helper)
            + check_markdown_structure("rules/INDEX.md", open(INDEX).read()))
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
    if not msgs:
        msgs = check_amendments(text, open(INDEX).read(), index, baseline, helper,
                                base_files.get("UPGRADES.md", ""), base_files.get("rules/INDEX.md"))
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
        vectors = markdown(open(vf).read())
        got = {vectors.title(node) for node in vectors.headings(2) if re.fullmatch(ID, vectors.title(node))}
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
            doc = markdown(open(path).read())
            cache[path] = {slug(doc.title(node)) for node in doc.headings()}
        return cache[path]
    for f in glob.glob(os.path.join(RULES, "**", "*.md"), recursive=True) + [SPEC, upgrades]:
        source = open(f).read()
        doc = markdown(source)
        if f not in (SPEC, upgrades) and doc.unclosed():
            msgs.append("markdown: unclosed fence in " + os.path.relpath(f, DOCS))
        for node in doc.nodes:
            if node.type not in ("link", "image"):
                continue
            u = node.attrGet("href" if node.type == "link" else "src")
            if re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", u):
                continue
            p, _, frag = u.partition("#")
            tgt = os.path.normpath(os.path.join(os.path.dirname(f), p)) if p else f
            if not os.path.exists(tgt):
                msgs.append("links: %s -> %s" % (os.path.basename(f), u))
            elif frag and frag not in headings(tgt):
                msgs.append("links: %s -> %s (dead fragment)" % (os.path.basename(f), u))
        msgs.extend(check_tables(os.path.basename(f), source))
    bad += fail(msgs) if msgs else (print("ok   links and tables") or 0)

    print(NL + ("ALL CHECKS PASSED" if bad == 0 else "%d problem(s)" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
