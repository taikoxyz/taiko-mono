"""Check the generated HTML specification against its sources.

Standard library only:
    python3 -I packages/protocol/docs/etna-pos-zk/scripts/verify.py

Every check compares the HTML pages with the source text itself, not with
another generated file:
  - text: every word and punctuation mark, in order, across the pages;
  - code: each fenced example byte for byte;
  - structure: heading levels and titles, detail titles, table shapes and
    ordered-list numbering;
  - links: every local file and fragment resolves and external links are https
    to github.com;
  - safety: only expected tags, no inline scripts, styles or event handlers;
  - provenance: manifest hashes match the sources and every page names them.
Exits with status 1 and lists every problem it finds.
"""
import difflib
import hashlib
import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "spec"
FENCE = re.compile(r"^```([^\n]*)\n(.*?)^```[ \t]*$", re.M | re.S)
ESCAPE = re.compile(r"\\([!-/:-@\[-`{-~])")  # backslash before ASCII punctuation
MD_LINK = re.compile(r"(?<!\\)\[([^\]\n]*)\]\(([^)\s]+)\)")

# Reading order of the design specification, then the checklist.
SPEC_PAGES = [
    "index.html",
    "01-positioning.html",
    "02-components.html",
    "03-consensus.html",
    "04-staking.html",
    "05-data.html",
    "06-landing.html",
    "07-forced-inclusion.html",
    "08-recovery.html",
    "09-sync.html",
    "10-startup.html",
    "11-parameters.html",
    "12-limitations.html",
    "appendix-a-encodings.html",
    "appendix-b-storage.html",
    "appendix-c-funding.html",
]
CHECKLIST = "acceptance.html"
ALLOWED_TAGS = {
    "html", "head", "meta", "title", "link", "script", "body", "header", "nav",
    "main", "article", "footer", "div", "span", "a", "p", "h1", "h2", "h3",
    "h4", "ul", "ol", "li", "strong", "b", "em", "code", "pre", "table",
    "thead", "tbody", "tr", "th", "td", "details", "summary", "blockquote",
    "br", "hr", "time", "button",
}
ALLOWED_HOSTS = {"github.com"}
BLOCK = {"p", "li", "td", "th", "tr", "h1", "h2", "h3", "h4", "summary", "br",
         "blockquote", "details", "div", "pre", "ul", "ol", "table", "article"}
VOID = {"meta", "link", "br", "hr"}

problems = []


def problem(message):
    problems.append(message)


class Source:
    """Plain text and structure of a source file."""

    def __init__(self, text):
        blocks = []

        def keep(match):
            blocks.append(match[2])
            return f"\x00{len(blocks) - 1}\x00"

        body = FENCE.sub(keep, text)
        self.code = blocks
        self.headings, self.summaries, self.tables, self.numbers = [], [], [], []
        lines, out, table = body.split("\n"), [], None
        for i, line in enumerate(lines):
            if line.lstrip().startswith("|"):
                cells = re.split(r"(?<!\\)\|", line.strip())[1:-1]
                if re.fullmatch(r"\s*\|(\s*:?-+:?\s*\|)+\s*", line):
                    continue
                if table is None:
                    table = []
                    self.tables.append(table)
                table.append(len(cells))
                out.append(" ".join(c.strip() for c in cells))
                continue
            table = None
            if re.fullmatch(r"\s*</?callout>\s*|\s*</toggle>\s*", line):
                continue
            toggle = re.fullmatch(r'<toggle(?: heading="h([23])")?>', line)
            if toggle:
                title = clean(lines[i + 1])
                if toggle[1]:
                    self.headings.append((int(toggle[1]), title))
                else:
                    self.summaries.append(title)
                continue
            heading = re.match(r"^(#{2,3}) (.+)$", line)
            if heading:
                self.headings.append((len(heading[1]), clean(heading[2])))
            marker = re.match(r"^(\s*)(#{1,6} |[-*] |(\d+)\. )", line)
            if marker:
                if marker[3]:
                    self.numbers.append(int(marker[3]))
                line = line[marker.end():]
            out.append(line)
        text = clean("\n".join(out), keep_space=True)
        for i, block in enumerate(blocks):
            text = text.replace(f"\x00{i}\x00", block)
        self.tokens = text.split()


def clean(text, keep_space=False):
    text = MD_LINK.sub(r"\1", text)
    text = re.sub(r"</?(?:b|code)>", "", text)
    text = ESCAPE.sub(r"\1", text)
    return text if keep_space else " ".join(text.split())


class Page(HTMLParser):
    """Collect protocol text (data-source regions), structure, links and tags."""

    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.ids, self.links, self.assets = [], [], []
        self.parts, self.code, self.headings, self.summaries = [], [], [], []
        self.tables, self.numbers = [], []
        self.depth = 0  # >0 while inside a data-source element
        self.stack, self.capture, self.pre, self.lists = [], None, None, []
        self.feed(path.read_text(encoding="utf-8"))
        self.close()

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag not in ALLOWED_TAGS:
            problem(f"{self.path.name}: unexpected <{tag}>")
        for name, _ in attrs:
            if name.startswith("on") or name == "style":
                problem(f"{self.path.name}: disallowed attribute {name} on <{tag}>")
        if tag == "script" and a.get("src") != "reader.js":
            problem(f"{self.path.name}: unexpected script")
        if "id" in a:
            self.ids.append(a["id"])
        if tag == "a" and "href" in a:
            self.links.append(a["href"])
        if tag == "link":
            self.assets.append(a.get("href", ""))
        if tag == "script":
            self.assets.append(a.get("src", ""))
        if tag in VOID:
            if tag == "br" and self.depth:
                self.parts.append(" ")
            return
        source = "data-source" in a
        self.stack.append((tag, source))
        if source:
            self.depth += 1
        if not self.depth:
            return
        if tag in BLOCK:
            self.parts.append(" ")
        if tag in ("h1", "h2", "h3", "h4", "summary"):
            self.capture = (tag, [])
        elif tag == "pre":
            self.pre = []
        elif tag == "table":
            self.tables.append([])
        elif tag == "tr":
            self.tables[-1].append(0)
        elif tag in ("td", "th"):
            self.tables[-1][-1] += 1
        elif tag in ("ol", "ul"):
            self.lists.append(int(a.get("start", 1)) if tag == "ol" else None)
        elif tag == "li" and self.lists and self.lists[-1] is not None:
            self.numbers.append(self.lists[-1])
            self.lists[-1] += 1

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        if not self.stack or self.stack[-1][0] != tag:
            problem(f"{self.path.name}: unbalanced </{tag}>")
            return
        _, source = self.stack.pop()
        if self.depth:
            if tag in BLOCK:
                self.parts.append(" ")
            if self.capture and self.capture[0] == tag:
                text = " ".join("".join(self.capture[1]).split())
                if tag == "summary":
                    self.summaries.append(text)
                else:
                    self.headings.append((int(tag[1]), text))
                self.capture = None
            elif tag == "pre":
                self.code.append("".join(self.pre))
                self.pre = None
            elif tag in ("ol", "ul"):
                self.lists.pop()
        if source:
            self.depth -= 1

    def handle_data(self, data):
        if not self.depth:
            return
        self.parts.append(data)
        if self.capture:
            self.capture[1].append(data)
        if self.pre is not None:
            self.pre.append(data)

    def tokens(self):
        return "".join(self.parts).split()


def compare(name, kind, expected, actual):
    if expected == actual:
        return
    matcher = difflib.SequenceMatcher(None, expected, actual, autojunk=False)
    shown = 0
    for op, i1, i2, j1, j2 in matcher.get_opcodes():
        if op == "equal":
            continue
        context = " ".join(map(str, expected[max(0, i1 - 6):i1]))
        problem(f"{name}: {kind} {op} after …{context[-60:]!r}: "
                f"source {expected[i1:i2][:12]!r} -> html {actual[j1:j2][:12]!r}")
        shown += 1
        if shown == 10:
            problem(f"{name}: further {kind} differences omitted")
            break


def check_document(name, source, pages, level_shift):
    text, code, headings, summaries, tables, numbers = [], [], [], [], [], []
    for page in pages:
        text += page.tokens()
        code += page.code
        headings += [(level + level_shift.get(page.path.name, 0), t) for level, t in page.headings]
        summaries += page.summaries
        tables += page.tables
        numbers += page.numbers
    compare(name, "text", source.tokens, text)
    if code != source.code:
        problem(f"{name}: code blocks differ from the source ({len(code)} vs {len(source.code)})")
    compare(name, "heading", source.headings, headings)
    compare(name, "detail title", source.summaries, summaries)
    compare(name, "table shape", [tuple(t) for t in source.tables], [tuple(t) for t in tables])
    compare(name, "list numbering", source.numbers, numbers)
    print(f"{name}: {len(text)} words, {len(code)} code blocks, {len(headings)} headings, "
          f"{len(summaries)} details, {len(tables)} tables, {len(numbers)} numbered items")


def ids_of(path):
    if path.suffix == ".html":
        return set(Page(path).ids)
    slugs = set()
    for m in re.finditer(r"^#{1,6} (.+)$", path.read_text(encoding="utf-8"), re.M):
        slugs.add(re.sub(r"[^\w -]", "", m[1].lower()).replace(" ", "-"))
    return slugs


def check_link(origin, link, asset=False):
    parts = urlsplit(link)
    if parts.scheme or parts.netloc:
        if asset:
            problem(f"{origin.name}: remote asset {link}")
        elif parts.scheme != "https" or parts.netloc not in ALLOWED_HOSTS:
            problem(f"{origin.name}: link outside the allowed https hosts: {link}")
        return 0
    target = (origin.parent / unquote(parts.path)).resolve() if parts.path else origin
    if not target.is_relative_to(ROOT):
        problem(f"{origin.name}: link leaves the documentation directory: {link}")
    elif not target.is_file():
        problem(f"{origin.name}: missing target {link}")
    elif parts.fragment and unquote(parts.fragment) not in ids_of(target):
        problem(f"{origin.name}: missing fragment {link}")
    return 1


manifest = json.loads((ROOT / "sources/manifest.json").read_text(encoding="utf-8"))
sources = {}
for entry in manifest["documents"]:
    data = (ROOT / "sources" / entry["source"]).read_bytes()
    if hashlib.sha256(data).hexdigest() != entry["sha256"]:
        problem(f"{entry['source']}: SHA-256 differs from the manifest")
    sources[entry["name"]] = (entry, Source(data.decode("utf-8")))

expected = set(SPEC_PAGES) | {CHECKLIST}
present = {p.name for p in SPEC.glob("*.html")}
for name in sorted(present - expected):
    problem(f"spec/{name}: unexpected page")
for name in sorted(expected - present):
    problem(f"spec/{name}: missing page")
if problems:
    print("\n".join(problems))
    sys.exit(1)

pages = {name: Page(SPEC / name) for name in sorted(expected)}
spec_entry, spec_source = sources["spec"]
check_entry, check_source = sources["acceptance"]
# Spec section pages use h1 for a "##" section and h2 for "###"; elsewhere levels match.
shift = {name: 1 for name in SPEC_PAGES[1:]}
check_document("spec", spec_source, [pages[n] for n in SPEC_PAGES], shift)
check_document("acceptance", check_source, [pages[CHECKLIST]], {})

links = 0
for name, page in pages.items():
    if len(page.ids) != len(set(page.ids)):
        problem(f"{name}: duplicate ids")
    raw = page.path.read_text(encoding="utf-8")
    for marker in ("<toggle", "<callout"):
        if marker in raw:
            problem(f"{name}: leftover source markup {marker!r}")
    entry = check_entry if name == CHECKLIST else spec_entry
    if f"Revision {manifest['revision']}." not in raw or entry["sha256"] not in raw:
        problem(f"{name}: footer does not name the revision and source hash")
    for link in page.links:
        links += check_link(page.path, link)
    for asset in page.assets:
        links += check_link(page.path, asset, asset=True)

readme = ROOT / "README.md"
for _, link in MD_LINK.findall(FENCE.sub("", readme.read_text(encoding="utf-8"))):
    links += check_link(readme, link)

if problems:
    print("\n".join(problems))
    sys.exit(1)
print(f"Verified {links} local links and assets across {len(pages)} pages and README.md.")
