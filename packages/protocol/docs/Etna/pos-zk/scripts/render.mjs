// Render complete Notion snapshots without editing protocol language.
// Node >= 20; Marked is a build-time dependency only (see README).
import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import assert from "node:assert/strict";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const check = process.argv.includes("--check");
const modulePath = process.env.MARKED_MODULE
  ? pathToFileURL(resolve(process.env.MARKED_MODULE)).href
  : "marked";
const { Marked } = await import(modulePath);
const manifest = JSON.parse(
  await readFile(resolve(root, "sources/manifest.json"), "utf8"),
);
const fence = String.fromCharCode(96).repeat(3);
const escapeHtml = (s) =>
  s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
const unescapeMarkdown = (s) =>
  s.replace(/\\([\\\u0060*_{}\[\]()#+\-.!|<>~^])/g, "$1");
const plain = (s) =>
  unescapeMarkdown(s.replace(/<[^>]*>/g, "")).replace(
    /&(?:amp|lt|gt|quot);/g,
    (x) => ({ "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"' })[x],
  );
const slug = (s) =>
  plain(s)
    .toLowerCase()
    .replace(/[^\p{L}\p{N}_ -]/gu, "")
    .replaceAll(" ", "-");
const hash = (s) => createHash("sha256").update(s).digest("hex");
const pages = [];

// Keep fenced examples byte-for-byte; transform only presentation markup.
function outsideFences(input, transform) {
  return input
    .split(/(^\u0060{3}[^\n]*\n[\s\S]*?^\u0060{3}[ \t]*$)/gm)
    .map((part, i) => (i % 2 ? part : transform(part)))
    .join("");
}

function normalize(source) {
  return outsideFences(source, (part) =>
    part
      .replace(/<table-of-contents\s*\/>/g, "")
      .replace(/<span\b[^>]*>/g, "")
      .replaceAll("</span>", "")
      .replace(
        /<mention url="([^"]+)">([\s\S]*?)<\/mention>/g,
        (_, url, label) => "[" + label + "](" + url + ")",
      )
      .replace(
        /<page url="([^"]+)">\s*([\s\S]*?)\s*<\/page>/g,
        (_, url, label) => "[" + label + "](" + url + ")",
      )
      .replace(/<callout\b[^>]*>\n?/g, "<blockquote>\n\n")
      .replaceAll("</callout>", "\n</blockquote>")
      .replace(
        /<code>([\s\S]*?)<\/code>/g,
        (_, text) =>
          "<code>" +
          escapeHtml(unescapeMarkdown(text)).replaceAll("|", "&#124;") +
          "</code>",
      ),
  );
}

function toggles(input) {
  const stack = [];
  const lines = input.split("\n");
  const out = [];
  let inFence = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith(fence)) inFence = !inFence;
    if (!inFence && /^<toggle(?: heading="h[23]")?>$/.test(line)) {
      const heading = line.match(/heading="h([23])"/);
      const title = lines[++i];
      assert(title?.trim(), "A toggle must have a title");
      stack.push(Boolean(heading));
      out.push(
        heading
          ? "#".repeat(Number(heading[1])) + " " + title
          : "<details>\n<summary>" +
              escapeHtml(unescapeMarkdown(title)) +
              "</summary>\n",
      );
    } else if (!inFence && line === "</toggle>") {
      assert(stack.length, "Unexpected closing toggle");
      if (!stack.pop()) out.push("\n</details>");
    } else out.push(line);
  }
  assert.equal(stack.length, 0, "Unclosed toggle");
  return out.join("\n");
}

// Prose order/content must be identical after removing presentation alone.
function projection(text) {
  return text
    .replace(/^\u0060{3}[^\n]*\n[\s\S]*?^\u0060{3}[ \t]*$/gm, "")
    .replace(/<table-of-contents\s*\/>/g, "")
    .replace(/(?<!\\)\[([^\]\n]*)\]\([^)]+\)/g, "$1")
    .replace(
      /<\/?(?:toggle|callout|blockquote|details|summary|span|code|b|mention|page)\b[^>]*>/g,
      "",
    )
    .replace(
      /&(?:amp|lt|gt|quot|#124);/g,
      (x) =>
        ({
          "&amp;": "&",
          "&lt;": "<",
          "&gt;": ">",
          "&quot;": '"',
          "&#124;": "|",
        })[x],
    )
    .replace(/^[ \t]*(?:#{1,6} |[-*] |\d+\. )/gm, "")
    .replace(/[\\*_\u0060\s]/g, "");
}

const codeBlocks = (s) =>
  [...s.matchAll(/^\u0060{3}([^\n]*)\n([\s\S]*?)^\u0060{3}[ \t]*$/gm)].map(
    (m) => [m[1], m[2]],
  );
const headings = (s) =>
  [...s.matchAll(/^(#{2,3}) (.+)$/gm)].map((m) => ({
    depth: m[1].length,
    title: plain(m[2]),
    id: slug(m[2]),
  }));
const sourceNames = new Map(
  manifest.pages.map((p) => [
    p.pageId.replaceAll("-", ""),
    p.name === "design-spec" ? "SPEC.md" : "ACCEPTANCE.md",
  ]),
);
const localLinks = (s) =>
  s.replace(
    /https:\/\/app\.notion\.com\/p\/([a-f0-9]{32})/g,
    (url, id) => sourceNames.get(id) || url,
  );
const htmlLinks = (html) =>
  html
    .replace(
      /href="SPEC\.md(#[^"]*)?"/g,
      (_, f = "") => 'href="index.html' + f + '"',
    )
    .replace(
      /href="ACCEPTANCE\.md(#[^"]*)?"/g,
      (_, f = "") => 'href="acceptance.html' + f + '"',
    );

for (const page of manifest.pages) {
  const source = await readFile(resolve(root, "sources", page.source), "utf8");
  if (check)
    assert.equal(
      hash(source),
      page.sha256,
      "Snapshot hash differs: " + page.source,
    );
  else page.sha256 = hash(source);
  const body = toggles(normalize(source)).trim() + "\n";
  const actualText = projection(body);
  const expectedText = projection(source);
  if (actualText !== expectedText) {
    let i = 0;
    while (actualText[i] === expectedText[i]) i++;
    throw new Error(
      "Source prose differs in " +
        page.name +
        " at character " +
        i +
        "\nactual: " +
        actualText.slice(i - 60, i + 140) +
        "\nsource: " +
        expectedText.slice(i - 60, i + 140),
    );
  }
  assert.deepEqual(
    codeBlocks(body),
    codeBlocks(source),
    "A fenced example changed: " + page.name,
  );
  const list = headings(body);
  assert.equal(
    new Set(list.map((h) => h.id)).size,
    list.length,
    "Duplicate heading anchors",
  );
  const isSpec = page.name === "design-spec";
  const mdFile = isSpec ? "SPEC.md" : "ACCEPTANCE.md";
  const htmlFile = isSpec ? "spec/index.html" : "spec/acceptance.html";
  const intro =
    "# " +
    page.title +
    "\n\n> Complete snapshot of the [Notion source](" +
    page.url +
    "), last edited " +
    page.lastEditedAt +
    ". Generated from the retained source; protocol wording is unchanged. See [README.md](README.md) for scope and provenance.\n\n";
  const toc =
    "<details>\n<summary>Contents</summary>\n\n" +
    list
      .map(
        (h) =>
          (h.depth === 3 ? "  " : "") + "- [" + h.title + "](#" + h.id + ")",
      )
      .join("\n") +
    "\n\n</details>\n\n";
  const markdown = intro + toc + localLinks(body);
  const parser = new Marked({
    gfm: true,
    renderer: {
      heading({ tokens, depth }) {
        const title = this.parser.parseInline(tokens);
        const id = slug(title);
        return (
          "<h" +
          depth +
          ' id="' +
          id +
          '"><a class="heading-link" href="#' +
          id +
          '">' +
          title +
          "</a></h" +
          depth +
          ">\n"
        );
      },
      table(token) {
        const header = this.tablerow({
          text: token.header.map((cell) => this.tablecell(cell)).join(""),
        });
        const rows = token.rows
          .map((row) =>
            this.tablerow({
              text: row.map((cell) => this.tablecell(cell)).join(""),
            }),
          )
          .join("");
        return (
          '<div class="table-scroll" role="region" aria-label="Scrollable reference table" tabindex="0"><table><thead>' +
          header +
          "</thead><tbody>" +
          rows +
          "</tbody></table></div>\n"
        );
      },
    },
  });
  const rendered = htmlLinks(parser.parse(localLinks(body)));
  const contentTitle = isSpec
    ? "Design specification"
    : "Acceptance and launch";
  const tocHtml = list
    .map(
      (h) =>
        '<a class="depth-' +
        h.depth +
        '" href="#' +
        h.id +
        '">' +
        escapeHtml(h.title) +
        "</a>",
    )
    .join("\n");
  const html =
    '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1">\n' +
    "<title>Etna PoS + ZK — " +
    contentTitle +
    '</title>\n<link rel="stylesheet" href="spec.css">\n<script src="reader.js" defer></script>\n</head>\n<body>\n' +
    '<a class="skip-link" href="#main">Skip to specification</a>\n<header class="site"><a class="brand" href="index.html">Etna <span>PoS + ZK</span></a><span class="tag">Reference specification</span>' +
    '<nav aria-label="Documents"><a href="index.html"' +
    (isSpec ? ' aria-current="page"' : "") +
    '>Specification</a><a href="acceptance.html"' +
    (!isSpec ? ' aria-current="page"' : "") +
    '>Acceptance</a><a href="../README.md">README</a></nav></header>\n' +
    '<div class="layout"><aside class="sidebar"><p class="eyebrow">On this page</p><nav aria-label="Contents">' +
    tocHtml +
    '</nav></aside>\n<main id="main" tabindex="-1">' +
    '<p class="eyebrow">Etna / ' +
    contentTitle +
    "</p><h1>" +
    escapeHtml(page.title) +
    '</h1>\n<p class="lede">' +
    (isSpec
      ? "Complete design: consensus, staking, data availability, settlement, forced inclusion, recovery and encodings."
      : "Complete companion checklist: resource acceptance, recovery, shared vectors and the launch gate.") +
    '</p><div class="provenance"><span>Notion edited <time datetime="' +
    page.lastEditedAt +
    '">' +
    page.lastEditedAt +
    '</time></span><a href="' +
    page.url +
    '">Notion source ↗</a><a href="../' +
    mdFile +
    '">Markdown</a></div>\n' +
    '<div class="reader-note">A documentation snapshot. The design retains its open items and unmeasured operating targets; this publication makes no implementation, audit or launch-readiness claim.</div>\n' +
    '<div class="tools"><button type="button" id="expand">Expand all details</button><button type="button" id="collapse">Collapse all details</button><button type="button" id="print">Print</button><span>Use your browser’s find to search the full text.</span></div>\n' +
    '<article id="document">' +
    rendered +
    "</article><footer>Source SHA-256 <code>" +
    page.sha256 +
    '</code><br>Generated from the retained Notion snapshot. <a href="#main">Back to top ↑</a></footer></main></div>\n</body>\n</html>\n';
  pages.push({ page, source, body, markdown, html, mdFile, htmlFile, list });
}

const outputs = pages.flatMap((p) => [
  [p.mdFile, p.markdown],
  [p.htmlFile, p.html],
]);
outputs.push([
  "sources/manifest.json",
  JSON.stringify(manifest, null, 2) + "\n",
]);
for (const [file, content] of outputs) {
  if (check)
    assert.equal(
      await readFile(resolve(root, file), "utf8"),
      content,
      "Generated file is stale: " + file,
    );
  else await writeFile(resolve(root, file), content);
}
console.log(
  (check ? "Verified" : "Generated") + " complete source-faithful documents:",
);
for (const p of pages)
  console.log(
    "  " +
      p.mdFile +
      ": " +
      p.list.length +
      " section anchors, " +
      codeBlocks(p.source).length +
      " unchanged code blocks; SHA-256 " +
      p.page.sha256,
  );
