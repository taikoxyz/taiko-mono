"""Verify complete static documents using only the Python standard library."""
import hashlib
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
FENCES = re.compile(r"^" + chr(96) * 3 + r"([^\n]*)\n(.*?)^" + chr(96) * 3 + r"[ \t]*$", re.M | re.S)
LINKS = re.compile(r"(?<!\\)\[([^\]\n]*)\]\(([^)]+)\)")


class Document(HTMLParser):
    def __init__(self, text, skip_pre=False):
        super().__init__(convert_charrefs=True)
        self.ids, self.links, self.assets, self.text, self.blocks = [], [], [], [], []
        self.counts = {}
        self.pre = None
        self.skip_pre = skip_pre
        self.feed(text)
        self.close()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.counts[tag] = self.counts.get(tag, 0) + 1
        if "id" in attrs:
            self.ids.append(attrs["id"])
        if "href" in attrs:
            self.links.append(attrs["href"])
        if "src" in attrs:
            self.assets.append(attrs["src"])
        if tag == "pre":
            assert self.pre is None, "Nested pre"
            self.pre = []

    def handle_endtag(self, tag):
        if tag == "pre":
            assert self.pre is not None, "Unmatched pre"
            self.blocks.append("".join(self.pre))
            self.pre = None

    def handle_data(self, data):
        if self.pre is not None:
            self.pre.append(data)
        if self.pre is None or not self.skip_pre:
            self.text.append(data)


def github_slug(heading):
    heading = Document(heading).text
    text = "".join(heading).lower()
    return re.sub(r"[^\w -]", "", text).replace(" ", "-")


def alnum(text):
    return "".join(c for c in text if c.isalnum())


def markdown_prose(text):
    text = FENCES.sub("", text)
    text = LINKS.sub(lambda m: m[1], text)
    text = text.replace("\\<", "&lt;").replace("\\>", "&gt;")
    text = re.sub(r"^[ \t]*(?:#{1,6} |[-*] |\d+\. )", "", text, flags=re.M)
    # Tables' separator rows contain no words; formatting and escaped punctuation
    # disappear in the alphanumeric comparison. Exact code is checked separately.
    return alnum("".join(Document(text).text))


manifest = json.loads((ROOT / "sources/manifest.json").read_text())
all_files = sorted(ROOT.rglob("*.html")) + sorted(ROOT.rglob("*.md"))
link_count = 0
for path in all_files:
    text = path.read_text()
    if path.suffix == ".html":
        doc = Document(text)
        assert len(doc.ids) == len(set(doc.ids)), f"Duplicate ids: {path}"
        links = doc.links + doc.assets
        assert not re.search(r"<(?:toggle|mention|callout)\b", text), path
        assert all(not urlsplit(asset).scheme for asset in doc.assets), "Remote asset"
        assert all(not urlsplit(link).scheme for link in re.findall(r'<link[^>]*href="([^"]+)"', text)), "Remote CSS"
    else:
        # Ignore literal code examples when checking Markdown links.
        links = [m[2] for m in LINKS.finditer(FENCES.sub("", text))]
    for link in links:
        parts = urlsplit(link)
        if parts.scheme or parts.netloc:
            continue
        target = (path.parent / unquote(parts.path)).resolve() if parts.path else path
        assert target.is_relative_to(ROOT), f"Local link escapes documentation: {path}: {link}"
        assert target.is_file(), f"Missing local target: {path}: {link}"
        if parts.fragment:
            destination = target.read_text()
            ids = Document(destination).ids if target.suffix == ".html" else [
                github_slug(m[1]) for m in re.finditer(r"^#{1,6} (.+)$", destination, re.M)
            ]
            assert unquote(parts.fragment) in ids, f"Missing fragment: {path}: {link}"
        link_count += 1

for page in manifest["pages"]:
    spec = page["name"] == "design-spec"
    source = (ROOT / "sources" / page["source"]).read_text()
    assert hashlib.sha256(source.encode()).hexdigest() == page["sha256"], page["source"]
    markdown = (ROOT / ("SPEC.md" if spec else "ACCEPTANCE.md")).read_text()
    # The first details block is generated navigation, outside the source body.
    body = markdown.split("</details>\n\n", 1)[1]
    html = (ROOT / "spec" / ("index.html" if spec else "acceptance.html")).read_text()
    article = html.split('<article id="document">', 1)[1].split("</article>", 1)[0]
    doc = Document(article, skip_pre=True)
    expected = markdown_prose(body)
    actual = alnum("".join(doc.text))
    if actual != expected:
        i = next((i for i, (a, b) in enumerate(zip(actual, expected)) if a != b), min(len(actual), len(expected)))
        raise AssertionError(f"Rendered prose differs in {page['name']} at {i}: {actual[i-50:i+100]!r} / {expected[i-50:i+100]!r}")
    blocks = [m[2] for m in FENCES.finditer(source)]
    assert doc.blocks == blocks, f"Rendered code differs: {page['name']}"
    headings = re.findall(r"^#{2,3} ", body, re.M)
    assert len(headings) == doc.counts.get("h2", 0) + doc.counts.get("h3", 0), page["name"]
    ordinary_toggles = len(re.findall(r"^<toggle>$", source, re.M))
    assert ordinary_toggles == doc.counts.get("details", 0), page["name"]
    tables = len(re.findall(r"^\| ---", source, re.M))
    assert tables == doc.counts.get("table", 0), page["name"]
    assert page["lastEditedAt"] in html and page["lastEditedAt"] in markdown
    if spec:
        assert len(re.findall(r"^## (?:\d+\.|Appendix [ABC]:)", body, re.M)) == 15
        limitations = body.split("## 12. Known limitations and open items\n", 1)[1].split("## Appendix A:", 1)[0]
        assert [int(x) for x in re.findall(r"^(\d+)\. ", limitations, re.M)] == list(range(1, 19))
    print(f"{page['name']}: prose preserved; {len(headings)} headings, {ordinary_toggles} details, {tables} tables, {len(blocks)} exact code blocks")

print(f"Verified {link_count} local file/fragment references across {len(all_files)} documents; no remote reader assets.")
