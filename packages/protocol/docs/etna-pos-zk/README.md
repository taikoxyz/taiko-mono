# Etna PoS + ZK design specification

An offline HTML copy of the
[Etna PoS + ZK Design Spec](https://app.notion.com/p/3fe9673143d6817a9f0fdaaf1b965d7a)
and its
[Etna Acceptance and Launch Checklist](https://app.notion.com/p/4059673143d6817fbd80ec6bec24b95b),
one page per section. The Notion pages are authoritative; this directory holds
the snapshot listed under [Provenance](#provenance).

In Etna, a committee of TAIKO stakers produces blocks with stock CometBFT and
finalizes them instantly; anyone can land a proven batch on L1, and funds on L1
recognize only landed checkpoints. The target is Stage 0.

## Reading

GitHub shows HTML files as source, so clone or download this directory and open
`spec/index.html` in a browser. The pages need no network, server or build step:
they load only the adjacent `spec.css` and an optional `reader.js`, which adds
expand/collapse/print buttons and opens every detail block for printing and for
Ctrl/Cmd+F. Without JavaScript, all text and navigation still work; open detail
blocks by hand before printing.

| Page                                                        | Contents                                                        |
| ----------------------------------------------------------- | --------------------------------------------------------------- |
| [index.html](spec/index.html)                               | Summary, scope, contents of every page and snapshot details     |
| [01-positioning.html](spec/01-positioning.html)             | 1. Positioning and security model                               |
| [02-components.html](spec/02-components.html)               | 2. Components                                                   |
| [03-consensus.html](spec/03-consensus.html)                 | 3. Consensus and blocks: engine, header, anchor, validity       |
| [04-staking.html](spec/04-staking.html)                     | 4. Staking and committees: registry, epochs, derivation         |
| [05-data.html](spec/05-data.html)                           | 5. Data formats and DA: envelope, blob payload, reconstruction  |
| [06-landing.html](spec/06-landing.html)                     | 6. Landing and settlement: land, proofs, batches, back-pressure |
| [07-forced-inclusion.html](spec/07-forced-inclusion.html)   | 7. Forced inclusion                                             |
| [08-recovery.html](spec/08-recovery.html)                   | 8. Halts and recovery                                           |
| [09-sync.html](spec/09-sync.html)                           | 9. Sync and weak subjectivity                                   |
| [10-startup.html](spec/10-startup.html)                     | 10. Startup and deployment                                      |
| [11-parameters.html](spec/11-parameters.html)               | 11. Parameters                                                  |
| [12-limitations.html](spec/12-limitations.html)             | 12. Known limitations and open items (18 items)                 |
| [appendix-a-encodings.html](spec/appendix-a-encodings.html) | Appendix A: encodings                                           |
| [appendix-b-storage.html](spec/appendix-b-storage.html)     | Appendix B: L1 storage layout                                   |
| [appendix-c-funding.html](spec/appendix-c-funding.html)     | Appendix C: operating funding and cost assumptions              |
| [acceptance.html](spec/acceptance.html)                     | Acceptance and launch checklist                                 |

## Key review points

- **Consensus and signing:** stock CometBFT v0.40.0 with secp256k1eth keys, a
  signing domain bound to the deployment and recovery generation, committee
  changes activated two heights after they are derived, and an external signer
  that signs only after the node authenticates the latest L1 checkpoint.
- **Settlement:** exactly two sub-proofs, at least one of them ZK. A batch proves
  the range (p,h], from its proof origin p to its terminal height h. When `land`
  executes it reads c, the latest checkpoint height, and settles only the new
  suffix (c,h]. Each grid leaf binds the height, EL hash, Comet hash and FI cursor
  of its own grid point in (p,h). Before proof verification, `land` checks the
  leaf at c (when c > p) against c's slot 285 record and that record's FI cursor
  against the current FI head; the other leaves are bound only through cutHash
  in the proofs.
- **Fees:** all L2 base fees and tips go to each block's beneficiary. Forced
  inclusion fees stay in the Inbox, and anyone may sweep its ETH balance to the
  fixed DAO treasury. Landing earns no protocol reward.
- **Recovery:** the owner calls `recover` with the expected generation and c and
  atomic exclusion and FI-blanking lists; the Inbox keeps no recovery queue or
  stall timer. Exclusions force exits without slashing. The settled prefix stays;
  the unsettled suffix is discarded, and the new generation starts from a fixed,
  authenticated origin. A verifier failure is not handled by `recover`: its
  settlement rollback runs in the same DAO upgrade of the Inbox and registry that
  replaces the verifier.
- **Open design and acceptance:** the Unzen switch and bridge wiring (section 12
  item 9), upgrade activation (item 10), registration admission bounds (item 14)
  and a concrete total-stake floor (item 18) remain open. The value of K and the
  proving capacity behind it (6.3, section 11) are set by the checklist's
  resource acceptance, as are the real-guest, signer, recovery and launch checks.

These points are reading aids. The specification pages hold the validity rules,
and the checklist holds the acceptance and launch requirements.

## Provenance

| Source                                                                                            | Last edited in Notion (UTC) |
| ------------------------------------------------------------------------------------------------- | --------------------------- |
| [Etna PoS + ZK Design Spec](https://app.notion.com/p/3fe9673143d6817a9f0fdaaf1b965d7a)            | 2026-10-28T12:18:10.133Z    |
| [Etna Acceptance and Launch Checklist](https://app.notion.com/p/4059673143d6817fbd80ec6bec24b95b) | 2026-10-28T12:18:24.105Z    |

`sources/` keeps each page body exactly as Notion returned it, and
`sources/manifest.json` records the page identities, edit times, SHA-256 hashes
and renderer version. The renderer changes presentation only: callouts become
notes, ordinary toggles become native detail blocks, heading toggles become
headings, links to the two Notion pages point to the local copies, and comment
markers are dropped while their text stays. Section numbers and order follow
Notion. Raise any protocol question against the Notion page, not this copy.

## Refreshing the snapshot

1. Fetch each page with the Notion MCP server's `notion-fetch` tool. It returns
   Notion-flavored Markdown (`<toggle>`, `<callout>`, `<mention>` and `<page>`
   tags), which the renderer expects; Notion's Export → Markdown produces a
   different format.
2. Save the text between `<content>` and `</content>`, without the line break
   that follows `<content>` or the one before `</content>`, plus one final newline,
   as `sources/design-spec.notion.md` or `sources/acceptance.notion.md`.
3. Set each page's `lastEditedAt` in `sources/manifest.json` to the fetch's
   `page_last_edited_at`, and update the table above. The renderer fills in the
   hashes.
4. If Notion added, removed or renamed a top-level section, update `SPEC_PAGES`
   in both `scripts/render.mjs` and `scripts/verify.py`.
5. Regenerate and check from the monorepo root. Marked stays in a temporary
   directory, so the workspace dependencies and lockfile are untouched:

```sh
npm --prefix /tmp/etna-docs-tools install marked@17.0.5
export MARKED_MODULE=/tmp/etna-docs-tools/node_modules/marked/lib/marked.esm.js
node packages/protocol/docs/etna-pos-zk/scripts/render.mjs
node packages/protocol/docs/etna-pos-zk/scripts/render.mjs --check
python3 -I packages/protocol/docs/etna-pos-zk/scripts/verify.py
```

Review the diff of `sources/` together with the regenerated pages.

## What the checks cover

- `render.mjs --check` (Node.js 20 or later): the retained sources match the
  manifest hashes, the loaded Marked version matches the manifest, and every page
  in `spec/` is byte-identical to a fresh render, with no stale pages.
- `verify.py` (Python standard library only) compares the pages with the Notion
  sources themselves rather than with other generated files: every word and
  punctuation mark in order, each code example byte for byte, heading levels and
  titles, detail titles, table shapes and ordered-list numbering. It also checks
  that every local link and fragment resolves, that external links use https to
  `app.notion.com` or `github.com`, that no Notion link is left in the protocol
  text, that pages contain only expected tags with no inline scripts, styles or
  event handlers, and that each page names its source edit time and hash.
