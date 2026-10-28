// Render the spec sources into the HTML specification: one page per
// top-level section, an index, and the acceptance checklist.
// Node >= 20. Marked is a build-time dependency only; see README.md.
// Protocol wording is never edited: only presentation markup is transformed,
// and scripts/verify.py checks the result against the sources independently.
import { readFile, writeFile, readdir, unlink } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const check = process.argv.includes("--check");
const fail = (message) => {
  throw new Error(message);
};

if (!process.env.MARKED_MODULE)
  fail("Set MARKED_MODULE to marked's lib/marked.esm.js (see README.md).");
const markedPath = resolve(process.env.MARKED_MODULE);
const { Marked } = await import(pathToFileURL(markedPath).href);
const manifest = JSON.parse(
  await readFile(resolve(root, "sources/manifest.json"), "utf8"),
);
const markedVersion = await packageVersion(markedPath, "marked");
if (markedVersion !== manifest.renderer.version)
  fail(
    `Loaded marked ${markedVersion}; the manifest pins ${manifest.renderer.version}.`,
  );

// Section prefix in the source heading -> output file and short navigation label.
const SPEC_PAGES = [
  ["1.", "01-positioning.html", "1 Positioning"],
  ["2.", "02-components.html", "2 Components"],
  ["3.", "03-consensus.html", "3 Consensus"],
  ["4.", "04-staking.html", "4 Staking"],
  ["5.", "05-data.html", "5 Data & DA"],
  ["6.", "06-landing.html", "6 Landing"],
  ["7.", "07-forced-inclusion.html", "7 Forced inclusion"],
  ["8.", "08-recovery.html", "8 Recovery"],
  ["9.", "09-sync.html", "9 Sync"],
  ["10.", "10-startup.html", "10 Startup"],
  ["11.", "11-parameters.html", "11 Parameters"],
  ["12.", "12-limitations.html", "12 Limitations"],
  ["Appendix A:", "appendix-a-encodings.html", "A Encodings"],
  ["Appendix B:", "appendix-b-storage.html", "B Storage"],
  ["Appendix C:", "appendix-c-funding.html", "C Funding"],
];
const INDEX = "index.html";
const CHECKLIST = "acceptance.html";

const fence = "`".repeat(3);
const escapeHtml = (s) =>
  s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
const unescapeMarkdown = (s) =>
  s.replace(/\\([\\`*_{}\[\]()#+\-.!|<>~^])/g, "$1");
const plain = (s) =>
  unescapeMarkdown(s.replace(/<[^>]*>/g, "")).replace(
    /&(?:amp|lt|gt|quot|#124);/g,
    (x) =>
      ({
        "&amp;": "&",
        "&lt;": "<",
        "&gt;": ">",
        "&quot;": '"',
        "&#124;": "|",
      })[x],
  );
const slug = (s) =>
  plain(s)
    .toLowerCase()
    .replace(/[^\p{L}\p{N}_ -]/gu, "")
    .replaceAll(" ", "-");
const hash = (s) => createHash("sha256").update(s).digest("hex");

async function packageVersion(modulePath, name) {
  let dir = dirname(modulePath);
  for (let i = 0; i < 5; i++, dir = dirname(dir)) {
    try {
      const pkg = JSON.parse(
        await readFile(resolve(dir, "package.json"), "utf8"),
      );
      if (pkg.name === name) return pkg.version;
    } catch {
      // keep walking up
    }
  }
  fail(`Cannot find ${name}'s package.json above ${modulePath}.`);
}

// Keep fenced examples byte-for-byte; transform only presentation markup.
function outsideFences(input, transform) {
  return input
    .split(/(^`{3}[^\n]*\n[\s\S]*?^`{3}[ \t]*$)/gm)
    .map((part, i) => (i % 2 ? part : transform(part)))
    .join("");
}

function normalize(source) {
  return outsideFences(source, (part) =>
    part
      .replace(/<callout>\n?/g, '<div class="callout" role="note">\n\n')
      .replaceAll("</callout>", "\n</div>")
      .replace(
        /<code>([\s\S]*?)<\/code>/g,
        (_, text) =>
          "<code>" +
          escapeHtml(unescapeMarkdown(text)).replaceAll("|", "&#124;") +
          "</code>",
      ),
  );
}

// Heading toggles become headings; ordinary toggles become native details.
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
      if (!title?.trim()) fail(`Toggle without a title at line ${i}`);
      stack.push(Boolean(heading));
      out.push(
        heading
          ? "#".repeat(Number(heading[1])) + " " + title
          : "<details>\n<summary>" +
              escapeHtml(unescapeMarkdown(title)) +
              "</summary>\n",
      );
    } else if (!inFence && line === "</toggle>") {
      if (!stack.length) fail(`Unexpected closing toggle at line ${i + 1}`);
      if (!stack.pop()) out.push("\n</details>");
    } else out.push(line);
  }
  if (stack.length) fail("Unclosed toggle");
  if (inFence) fail("Unclosed code fence");
  return out.join("\n");
}

// Split at level-2 headings outside fences; segment 0 is the preamble.
function splitSections(body) {
  const segments = [[]];
  let inFence = false;
  for (const line of body.split("\n")) {
    if (line.startsWith(fence)) inFence = !inFence;
    if (!inFence && line.startsWith("## ")) segments.push([]);
    segments.at(-1).push(line);
  }
  return segments.map((lines) => lines.join("\n").trim() + "\n");
}

function headingsOf(markdown) {
  const list = [];
  let inFence = false;
  for (const line of markdown.split("\n")) {
    if (line.startsWith(fence)) inFence = !inFence;
    const m = !inFence && line.match(/^(#{2,3}) (.+)$/);
    if (m)
      list.push({ depth: m[1].length, title: plain(m[2]), id: slug(m[2]) });
  }
  return list;
}

// Markdown depth -> HTML depth for the page being rendered.
let depthMap = {};
const parser = new Marked({
  gfm: true,
  renderer: {
    heading({ tokens, depth }) {
      const title = this.parser.parseInline(tokens);
      const id = slug(title);
      const level = depthMap[depth] ?? depth;
      return `<h${level} id="${id}"><a class="anchor" href="#${id}">${title}</a></h${level}>\n`;
    },
    table(token) {
      const row = (cells) =>
        this.tablerow({
          text: cells.map((cell) => this.tablecell(cell)).join(""),
        });
      return (
        '<div class="table-scroll" role="region" aria-label="Scrollable table" tabindex="0"><table><thead>' +
        row(token.header) +
        "</thead><tbody>" +
        token.rows.map(row).join("") +
        "</tbody></table></div>\n"
      );
    },
  },
});
const render = (markdown, map) => {
  depthMap = map;
  return parser.parse(markdown);
};

const sources = {};
for (const doc of manifest.documents) {
  const source = await readFile(resolve(root, "sources", doc.source), "utf8");
  if (check && hash(source) !== doc.sha256)
    fail(`Source hash differs from the manifest: ${doc.source}`);
  doc.sha256 = hash(source);
  sources[doc.name] = { doc, body: toggles(normalize(source)) };
}
const spec = sources["spec"];
const checklist = sources["acceptance"];
if (!spec || !checklist) fail("The manifest must list spec and acceptance.");

const [preamble, ...sections] = splitSections(spec.body);
if (sections.length !== SPEC_PAGES.length)
  fail(
    `Expected ${SPEC_PAGES.length} top-level sections, found ${sections.length}.`,
  );
const specPages = sections.map((markdown, i) => {
  const [prefix, file, label] = SPEC_PAGES[i];
  const [first, ...rest] = markdown.split("\n");
  const titleMarkdown = first.slice(3);
  if (!titleMarkdown.startsWith(prefix + " "))
    fail(
      `Section ${i + 1} is "${titleMarkdown}", expected the prefix "${prefix}".`,
    );
  const subsections = headingsOf(rest.join("\n"));
  return {
    file,
    label,
    title: plain(titleMarkdown),
    id: slug(titleMarkdown),
    titleHtml: parser.parseInline(titleMarkdown),
    subsections,
    article: render(rest.join("\n"), { 3: 2 }),
  };
});

const navItems = [
  { file: INDEX, label: "Overview" },
  ...specPages.map(({ file, label }) => ({ file, label })),
  { file: CHECKLIST, label: "Checklist" },
];
const sequence = [
  { file: INDEX, title: spec.doc.title },
  ...specPages,
  { file: CHECKLIST, title: checklist.doc.title },
];

function frame({ file, title, body, source, hasDetails }) {
  const nav = navItems
    .map(
      (item) =>
        `<a href="${item.file}"${item.file === file ? ' aria-current="page"' : ""}>${escapeHtml(item.label)}</a>`,
    )
    .join("\n    ");
  const at = sequence.findIndex((s) => s.file === file);
  const prev = sequence[at - 1];
  const next = sequence[at + 1];
  const pager =
    '<nav class="pager" aria-label="Previous and next page">' +
    (prev
      ? `<a rel="prev" href="${prev.file}">← ${escapeHtml(prev.title)}</a>`
      : "<span></span>") +
    (next
      ? `<a rel="next" href="${next.file}">${escapeHtml(next.title)} →</a>`
      : "<span></span>") +
    "</nav>";
  const tools = hasDetails
    ? '<div class="tools" hidden><button type="button" data-action="expand">Expand all details</button><button type="button" data-action="collapse">Collapse all details</button><button type="button" data-action="print">Print</button></div>\n'
    : "";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(title)} · Etna PoS + ZK</title>
<link rel="stylesheet" href="spec.css">
<script src="reader.js" defer></script>
</head>
<body>
<a class="skip-link" href="#main">Skip to content</a>
<header class="site">
  <a class="brand" href="${INDEX}">Etna PoS + ZK</a>
  <span class="tag">design specification</span>
  <span class="tag">rev ${manifest.revision}</span>
  <nav aria-label="Specification pages">
    ${nav}
  </nav>
</header>
<main id="main" tabindex="-1">
${tools}${body}
${pager}
</main>
<footer class="site"><p>Revision ${manifest.revision}. Generated by <code>scripts/render.mjs</code> from <a href="../sources/${source.source}"><code>sources/${source.source}</code></a> (SHA-256 <code>${source.sha256}</code>); see <a href="../README.md">README.md</a>.</p></footer>
</body>
</html>
`;
}

const pageToc = (items, href = "") =>
  items.length
    ? '<nav class="page-toc" aria-label="On this page"><p class="eyebrow">On this page</p><ul>' +
      items
        .map(
          (h) =>
            `<li class="depth-${h.depth}"><a href="${href}#${h.id}">${escapeHtml(h.title)}</a></li>`,
        )
        .join("") +
      "</ul></nav>\n"
    : "";

const outputs = [];

// Index: the source preamble, then the contents of every page.
const contents = specPages
  .map(
    (p) =>
      `<div class="toc-entry"><a class="toc-title" href="${p.file}">${escapeHtml(p.title)}</a>` +
      (p.subsections.length
        ? "<ul>" +
          p.subsections
            .map(
              (h) =>
                `<li><a href="${p.file}#${h.id}">${escapeHtml(h.title)}</a></li>`,
            )
            .join("") +
          "</ul>"
        : "") +
      "</div>",
  )
  .join("\n");
const sourceRows = manifest.documents
  .map(
    (d) =>
      `<tr><td><a href="${d.name === "spec" ? "#contents" : CHECKLIST}">${escapeHtml(d.title)}</a></td><td><a href="../sources/${d.source}"><code>sources/${d.source}</code></a></td><td><code>${d.sha256.slice(0, 16)}…</code></td></tr>`,
  )
  .join("");
outputs.push([
  INDEX,
  frame({
    file: INDEX,
    title: spec.doc.title,
    source: spec.doc,
    hasDetails: false,
    body:
      `<h1>${escapeHtml(spec.doc.title)}</h1>\n` +
      '<p class="lede">The Etna PoS + ZK design specification, one page per section, with its acceptance and launch checklist.</p>\n' +
      `<article id="document" data-source>\n${render(preamble, {})}</article>\n` +
      `<h2 id="contents">Contents</h2>\n<div class="toc">\n${contents}\n</div>\n` +
      `<div class="card"><p><strong>Acceptance and launch:</strong> <a href="${CHECKLIST}">${escapeHtml(checklist.doc.title)}</a> collects the resource, latency and recovery acceptance, shared vectors and the launch gate.</p></div>\n` +
      `<h2 id="sources">Sources</h2>\n<div class="table-scroll" role="region" aria-label="Source files" tabindex="0"><table><thead><tr><th>Document</th><th>Source</th><th>SHA-256</th></tr></thead><tbody>${sourceRows}</tbody></table></div>`,
  }),
]);

for (const p of specPages)
  outputs.push([
    p.file,
    frame({
      file: p.file,
      title: p.title,
      source: spec.doc,
      hasDetails: p.article.includes("<details>"),
      body:
        `<h1 id="${p.id}" data-source>${p.titleHtml}</h1>\n` +
        pageToc(p.subsections) +
        `<article id="document" data-source>\n${p.article}</article>`,
    }),
  ]);

const checklistArticle = render(checklist.body, {});
outputs.push([
  CHECKLIST,
  frame({
    file: CHECKLIST,
    title: checklist.doc.title,
    source: checklist.doc,
    hasDetails: checklistArticle.includes("<details>"),
    body:
      `<h1>${escapeHtml(checklist.doc.title)}</h1>\n` +
      pageToc(headingsOf(checklist.body)) +
      `<article id="document" data-source>\n${checklistArticle}</article>`,
  }),
]);

const specDir = resolve(root, "spec");
const generated = new Set(outputs.map(([file]) => file));
const stale = (await readdir(specDir)).filter(
  (f) => f.endsWith(".html") && !generated.has(f),
);
const manifestText = JSON.stringify(manifest, null, 2) + "\n";
if (check) {
  if (stale.length) fail(`Stale generated pages: ${stale.join(", ")}`);
  const onDisk = await readFile(resolve(root, "sources/manifest.json"), "utf8");
  if (onDisk !== manifestText) fail("sources/manifest.json is not normalized.");
  for (const [file, html] of outputs)
    if ((await readFile(resolve(specDir, file), "utf8")) !== html)
      fail(`Generated page is stale: spec/${file}`);
  console.log(
    `Generated pages match the sources: ${outputs.length} pages, marked ${markedVersion}.`,
  );
} else {
  for (const file of stale) await unlink(resolve(specDir, file));
  for (const [file, html] of outputs)
    await writeFile(resolve(specDir, file), html);
  await writeFile(resolve(root, "sources/manifest.json"), manifestText);
  console.log(
    `Wrote ${outputs.length} pages${stale.length ? `, removed ${stale.join(", ")}` : ""}.`,
  );
}
