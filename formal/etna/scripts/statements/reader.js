"use strict";
(() => {
  const data = JSON.parse(document.getElementById("etna-data").textContent);
  const $ = (id) => document.getElementById(id);
  const node = (tag, attributes = {}, ...children) => {
    const element = document.createElement(tag);
    for (const [key, value] of Object.entries(attributes))
      element.setAttribute(key, value);
    for (const child of children.flat()) {
      if (child !== null && child !== undefined) element.append(child);
    }
    return element;
  };
  const entries = new Map(
    data.declarations.map((entry) => [entry.name, entry]),
  );
  const clauses = new Map(data.clauses.map((clause) => [clause.id, clause]));
  const rulesByTheorem = new Map();
  for (const rule of data.rules) {
    for (const name of rule.theorems) {
      if (!rulesByTheorem.has(name)) rulesByTheorem.set(name, []);
      rulesByTheorem.get(name).push(rule);
    }
  }
  const shortNames = new Map();
  for (const entry of data.declarations) {
    const parts = entry.name.split(".");
    for (let index = 1; index < parts.length; index++) {
      const suffix = parts.slice(index).join(".");
      shortNames.set(suffix, shortNames.has(suffix) ? null : entry.name);
    }
  }
  const resolve = (word) => (entries.has(word) ? word : shortNames.get(word));
  const declarationLink = (name, label = name) =>
    node("a", { href: `#decl=${encodeURIComponent(name)}` }, label);
  const badge = (label, kind = "") =>
    node("span", { class: `badge ${kind}` }, label);
  const fileURL = (path) =>
    `${data.github}/blob/${data.branch}/formal/etna/${path.split("/").map(encodeURIComponent).join("/")}`;
  const authorityURL = (clause) => {
    const pin = data.authorities[clause.path];
    return `${data.github}/blob/${pin.commit}/${pin.github_path}#L${clause.github_start_line}-L${clause.github_end_line}`;
  };
  const explanations = {
    "Etna.Design.Current.Protocol.Certifies":
      "A pure certificate at the statement's immutable reference prefix. It existentially supplies the hash-bound physical ancestry, parent and batch, with their full validity conditions.",
    "Etna.Design.Current.Protocol.ImageCertifies":
      "The pure batch certificate plus proof-image support. Live storage compatibility is derived separately from actual history and pure soundness.",
    "Etna.Design.Current.Protocol.VerifierSound":
      "The external accepted-proof soundness obligation for reachable decoded worlds. This is a premise; Lean does not establish real verifier or guest correctness here.",
    "Etna.Design.Current.Protocol.ReferenceBinding":
      "Injectivity of the idealized reference commitment over complete closed prefixes, including the relevant L1 storage snapshots.",
    "Etna.Design.Current.Protocol.Trace":
      "The modeled sequence of decoded protocol steps. It records admissible execution; it is not an EVM implementation trace.",
    "Etna.Design.Current.Archive.Authenticated":
      "The complete physical ancestry from the generation origin through the actual parent and batch. Headers are hash-bound and their anchors cannot lie after the reference.",
    "Etna.Design.Current.Protocol.Custody.Coherent":
      "All retained Etna signal headers share one retained authenticated chain. This is stronger than separately supplying a path for each signal.",
    "Etna.Statements.Current.Premises":
      "The fifteen primitive and deployment obligations supplied jointly to current H1–H3. Inspect every field and its component definition before applying the headlines.",
    "Etna.Statements.Current.NormalAccountability":
      "Live risk for quorum-overlap members above the actual checkpoint, under an authenticated candidate and an execution with no rollback since fresh deployment.",
    "Etna.Statements.Current.NormalCommitteeRetention":
      "Bond-status retention for every member of a valid candidate committee above the checkpoint. This does not replenish principal after punishment.",
    "Etna.Statements.Current.LandingService":
      "An accepted landing consumes exactly its FIFO interval, with timely decoded byte actions and unchanged queue entries.",
    "Etna.Statements.Current.NoEarlySkip":
      "Before the queue entry's inclusion deadline, a consuming valid block must include its transaction at the decoded position-zero boundary.",
  };
  const premiseNotes = {
    currentPrimitives:
      "Header and execution primitives, authenticated roots and their consistency obligations.",
    currentVerifierSound:
      "Pure soundness for the accepted proof / image combination over reachable worlds.",
    currentStandardToken:
      "The declared standard-token transfer and accounting semantics.",
    currentSignatureAgreement:
      "Signature-refinement and vote-field agreement at the decoded boundary.",
    currentBountyBound:
      "The configured slash bounty is below 10,000 basis points; zero is allowed.",
    currentCodec:
      "Consensus value / header codec soundness at every reachable world.",
    currentVoteAttribution:
      "Votes in the declared engine are attributed to the matching decoded signers.",
    currentClock: "Strictly increasing L1 block times.",
    currentCatalogueHash:
      "Selected ruleset byte primitives use the environment's transaction hash.",
    currentReferenceBinding:
      "The reference hash binds the complete canonical closed L1 prefix.",
    currentRegistryGenesis:
      "A raw, fresh registry opening with the required genesis invariants.",
    currentSignatureSound:
      "The signature relation supports attribution and the no-false-slash boundary.",
    currentSelfAllowance:
      "The initial token ledger grants zero registry-to-itself allowance.",
    currentUnzenExtension:
      "Accepted decoded Unzen headers extend the physical header parent chain.",
    currentEvidenceWindow:
      "Deployment policy: a positive evidence window no longer than the immutable withdrawal delay. This is not a contract initialization check.",
  };
  const premise = entries.get("Etna.Statements.Current.Premises");
  const premiseSource = data.files[premise.file].text
    .split("\n")
    .slice(premise.line - 1, premise.endLine)
    .join("\n");
  const premiseFields = [
    ...premiseSource.matchAll(/^  (current\w+)\s*:/gm),
  ].map((match) => match[1]);
  for (const [count, label] of [
    [data.counts.current, "current named declarations"],
    [premiseFields.length, "joint current premises"],
    [
      data.declarations.filter((entry) => entry.contract).length,
      "reviewed theorem contracts · all profiles",
    ],
  ])
    $("ledger").append(
      node(
        "div",
        {},
        node("strong", {}, count.toLocaleString("en")),
        node("span", {}, label),
      ),
    );
  for (const field of premiseFields)
    $("premise-list").append(
      node(
        "div",
        { class: "premise-row" },
        node("dt", {}, declarationLink(premise.name, field)),
        node(
          "dd",
          {},
          premiseNotes[field] ||
            "Read the exact field in the complete premise record.",
        ),
      ),
    );
  $("provenance").append(
    node(
      "p",
      {},
      `Toolchain: ${data.toolchain}. ${Object.keys(data.files).length} source files embedded. Shared entries supply primitives imported by the current model; that label does not grant them rule evidence.`,
    ),
  );
  for (const [path, digest] of Object.entries(data.fingerprints))
    $("provenance").append(
      node("div", { class: "fingerprint" }, path, node("br"), digest),
    );

  let selected = null;
  let lastActivator = null;
  let limit = 50;
  function sourceCode(entry) {
    const lines = data.files[entry.file].text.split("\n");
    const full = $("full-file").checked;
    const start = full ? 0 : entry.line - 1;
    const end = full ? lines.length : entry.endLine;
    const fragment = document.createDocumentFragment();
    const keywords = new Set([
      "def",
      "abbrev",
      "structure",
      "inductive",
      "theorem",
      "lemma",
      "where",
      "namespace",
      "end",
      "by",
      "Prop",
      "Type",
      "fun",
      "match",
      "with",
      "if",
      "then",
      "else",
      "import",
      "open",
      "let",
      "have",
      "exact",
      "intro",
    ]);
    for (let index = start; index < end; index++) {
      const line = node("span", {
        class: `code-line${index + 1 >= entry.line && index + 1 <= entry.endLine ? " highlight" : ""}`,
      });
      line.append(
        node("span", { class: "ln", "aria-hidden": "true" }, String(index + 1)),
      );
      const text = node("span", { class: "code-text" });
      for (const word of lines[index].split(/([\p{L}_][\p{L}\p{N}_.'!?]*)/u)) {
        const target = resolve(word);
        if (target && target !== entry.name) {
          const link = declarationLink(target, word);
          link.className = "identifier";
          link.title = target;
          text.append(link);
        } else if (keywords.has(word))
          text.append(node("span", { class: "kw" }, word));
        else text.append(word);
      }
      line.append(text);
      fragment.append(line);
    }
    $("source-code").replaceChildren(fragment);
    $("code-label").textContent = full
      ? "Complete embedded module"
      : "Named declaration · exact source";
  }
  function select(name, open = true) {
    const entry = entries.get(name);
    if (!entry) return;
    selected = entry;
    $("source-name").textContent = entry.name;
    $("source-badges").replaceChildren(
      badge(entry.kind),
      badge(
        entry.profile === "current" ? "current" : "shared",
        entry.profile,
      ),
    );
    if (entry.contract)
      $("source-badges").append(
        badge(entry.contract.role, entry.contract.role),
      );
    $("source-location").replaceChildren(
      node("div", {}, `${entry.file}:${entry.line}`),
      node(
        "a",
        {
          href: `${fileURL(entry.file)}#L${entry.line}`,
          target: "_blank",
          rel: "noopener noreferrer",
        },
        "GitHub branch ↗",
      ),
      " · ",
      node(
        "a",
        {
          href: `${entry.file}#L${entry.line}`,
          target: "_blank",
          rel: "noopener noreferrer",
        },
        "Local source ↗",
      ),
    );
    const summary = $("source-summary");
    summary.replaceChildren();
    if (explanations[name]) summary.append(node("p", {}, explanations[name]));
    if (entry.doc)
      summary.append(
        node("h3", {}, "Source documentation"),
        node("p", {}, entry.doc),
      );
    if (entry.contract) {
      const contract = entry.contract;
      summary.append(
        node("h3", {}, "Exact reviewed theorem type"),
        node("pre", {}, contract.type),
        node("h3", {}, "Reviewed scope"),
        node("p", {}, contract.scope),
        node("h3", {}, "Declared boundary notes"),
      );
      for (const assumption of contract.assumptions)
        summary.append(node("p", {}, assumption));
      summary.append(
        node(
          "p",
          {},
          "These boundary notes accompany the contract. The actual hypotheses are in the Lean type and referenced definitions. A role describes this theorem's evidence, not whole-protocol verification.",
        ),
      );
    }
    const evidence = $("source-evidence");
    evidence.replaceChildren();
    const rules = rulesByTheorem.get(name) || [];
    evidence.append(node("h3", {}, "Exact binding-rule edges"));
    if (!rules.length)
      evidence.append(
        node(
          "p",
          {},
          "No exact current binding-rule edge. Module membership or clause citations do not supply one.",
        ),
      );
    for (const rule of rules)
      evidence.append(
        node(
          "div",
          { class: "evidence-item" },
          node(
            "a",
            {
              href: authorityURL(clauses.get(rule.clause)),
              target: "_blank",
              rel: "noopener noreferrer",
            },
            `${rule.rule} · ${rule.status} ↗`,
          ),
          node("p", {}, rule.reason),
        ),
      );
    if (entry.contract && entry.contract.sources.length) {
      evidence.append(node("h3", {}, "Reviewed source-clause citations"));
      for (const id of entry.contract.sources) {
        const clause = clauses.get(id);
        if (!clause) continue;
        evidence.append(
          node(
            "div",
            { class: "evidence-item" },
            node(
              "a",
              {
                href: authorityURL(clause),
                target: "_blank",
                rel: "noopener noreferrer",
              },
              `${clause.path.split("/").pop()}:${clause.github_start_line}–${clause.github_end_line} ↗`,
            ),
            node("p", {}, clause.summary),
          ),
        );
      }
    }
    evidence.append(
      node("h3", {}, "Embedded file SHA-256"),
      node("p", { class: "fingerprint" }, data.files[entry.file].sha256),
    );
    $("full-file").checked = false;
    sourceCode(entry);
    $("source-scroll").scrollTop = 0;
    $("copy").textContent = "Copy name";
    if (open) {
      $("source-panel").classList.add("open");
      document.body.classList.add("source-open");
      if (matchMedia("(max-width: 760px)").matches) $("close-source").focus();
    }
  }
  function closeSource() {
    $("source-panel").classList.remove("open");
    document.body.classList.remove("source-open");
    if (lastActivator && document.contains(lastActivator))
      lastActivator.focus();
  }
  function selectFromHash() {
    if (location.hash.startsWith("#decl=")) {
      try {
        select(decodeURIComponent(location.hash.slice(6)));
      } catch {
        /* Ignore malformed fragments. */
      }
    }
  }
  document.addEventListener("click", (event) => {
    const link = event.target.closest("a[href^='#decl=']");
    if (link) {
      lastActivator = link;
      if (link.hash === location.hash) selectFromHash();
    }
  });
  addEventListener("hashchange", selectFromHash);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeSource();
  });
  $("close-source").addEventListener("click", closeSource);
  $("full-file").addEventListener("change", () => {
    if (selected) sourceCode(selected);
  });
  $("copy").addEventListener("click", async () => {
    if (!selected) return;
    try {
      await navigator.clipboard.writeText(selected.name);
      $("copy").textContent = "Copied";
    } catch {
      $("copy").textContent = "Select name to copy";
    }
  });

  const searchTexts = new Map(
    data.declarations.map((entry) => [
      entry.name,
      [
        entry.name,
        entry.module,
        entry.kind,
        entry.doc,
        explanations[entry.name] || "",
        entry.contract
          ? `${entry.contract.type} ${entry.contract.scope} ${entry.contract.role} ${entry.contract.assumptions.join(" ")}`
          : "",
        data.files[entry.file].text
          .split("\n")
          .slice(entry.line - 1, entry.endLine)
          .join("\n"),
        ...(rulesByTheorem.get(entry.name) || []).map((rule) => rule.rule),
      ]
        .join(" ")
        .toLowerCase(),
    ]),
  );
  function modules() {
    const profile = $("profile").value;
    const old = $("module").value;
    const values = [
      ...new Set(
        data.declarations
          .filter((entry) => profile === "all" || entry.profile === profile)
          .map((entry) => entry.module),
      ),
    ].sort();
    $("module").replaceChildren(
      node("option", { value: "all" }, "All modules"),
      ...values.map((module) => node("option", { value: module }, module)),
    );
    if (values.includes(old)) $("module").value = old;
  }
  function render() {
    const query = $("search")
      .value.toLowerCase()
      .trim()
      .split(/\s+/)
      .filter(Boolean);
    const profile = $("profile").value;
    const kind = $("kind").value;
    const module = $("module").value;
    const isRules = kind === "rules";
    $("profile").disabled = isRules;
    $("module").disabled = isRules;
    let rows;
    if (isRules)
      rows = data.rules.filter((rule) =>
        query.every((word) =>
          `${rule.rule} ${rule.title} ${rule.reason} ${rule.status} ${rule.type} ${rule.theorems.join(" ")}`
            .toLowerCase()
            .includes(word),
        ),
      );
    else
      rows = data.declarations.filter(
        (entry) =>
          (profile === "all" || entry.profile === profile) &&
          (module === "all" || entry.module === module) &&
          (kind === "all" ||
            (kind === "theorems"
              ? ["theorem", "lemma"].includes(entry.kind)
              : !["theorem", "lemma"].includes(entry.kind))) &&
          query.every((word) => searchTexts.get(entry.name).includes(word)),
      );
    $("result-count").textContent =
      `${rows.length.toLocaleString("en")} ${isRules ? "current rule / assumption rows" : "declarations"} · showing ${Math.min(limit, rows.length)}`;
    const fragment = document.createDocumentFragment();
    if (!rows.length)
      fragment.append(
        node(
          "p",
          { class: "empty" },
          "No matches. Try another name or broaden the profile / module filters.",
        ),
      );
    for (const row of rows.slice(0, limit)) {
      const article = node("article", { class: "result" });
      if (isRules) {
        const clause = clauses.get(row.clause);
        article.append(
          node(
            "div",
            { class: "result-top" },
            badge(row.status, row.status),
            node(
              "a",
              {
                class: "decl-link",
                href: authorityURL(clause),
                target: "_blank",
                rel: "noopener noreferrer",
              },
              row.rule,
            ),
          ),
          node("p", {}, row.title),
          node(
            "p",
            {},
            row.reason ||
              "No reviewed exact theorem edge; this obligation is deferred.",
          ),
          node("div", { class: "metadata" }, `${row.type} · ${row.section}`),
        );
        for (const name of row.theorems)
          article.append(node("p", {}, declarationLink(name)));
      } else {
        const link = declarationLink(
          row.name,
          row.name.split(".").slice(-2).join("."),
        );
        link.className = "decl-link";
        article.append(
          node("div", { class: "result-top" }, badge(row.kind), link),
          node("div", { class: "full-name" }, row.name),
        );
        if (row.contract)
          article.append(
            node("p", { class: "type-preview" }, row.contract.type),
          );
        const description =
          explanations[row.name] ||
          row.doc ||
          (row.contract ? row.contract.scope : "");
        if (description)
          article.append(
            node(
              "p",
              {},
              description.length > 300
                ? `${description.slice(0, 300)}…`
                : description,
            ),
          );
        article.append(
          node(
            "div",
            { class: "metadata" },
            `${row.file}:${row.line}`,
            row.contract ? `role: ${row.contract.role}` : "source definition",
            ...(rulesByTheorem.get(row.name) || []).map((rule) => rule.rule),
          ),
        );
      }
      fragment.append(article);
    }
    $("results").replaceChildren(fragment);
    $("more").hidden = rows.length <= limit;
  }
  for (const id of ["search", "profile", "kind", "module"])
    $(id).addEventListener(id === "search" ? "input" : "change", () => {
      limit = 50;
      if (id === "profile") modules();
      render();
    });
  $("more").addEventListener("click", () => {
    limit += 50;
    render();
  });
  $("reset").addEventListener("click", () => {
    $("search").value = "";
    $("profile").value = "current";
    $("kind").value = "all";
    $("module").value = "all";
    limit = 50;
    modules();
    render();
  });
  modules();
  render();
  if (location.hash.startsWith("#decl=")) selectFromHash();
  else select("Etna.Statements.Current.Premises", false);
})();
