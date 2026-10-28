# Etna PoS + ZK design specification

The Etna PoS + ZK design specification and its acceptance and launch
checklist, as HTML pages: one per section, an index and the checklist.

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
| [index.html](spec/index.html)                               | Summary, scope, contents of every page and source files         |
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

## Sources and regeneration

`sources/spec.md` and `sources/acceptance.md` hold the text. They are Markdown
with two block tags: `<callout>` for a note, and `<toggle>` for a collapsible
block whose first line is its title. A plain `<toggle>` becomes a detail block;
`<toggle heading="h2">` or `<toggle heading="h3">` becomes a heading. Links to
`index.html` and `acceptance.html` point at the generated pages.
`sources/manifest.json` records the revision date, the SHA-256 of each source
and the renderer version.

To change the spec, edit the sources, set `revision` in the manifest, and
regenerate from the monorepo root. If a top-level section is added, removed or
renamed, also update `SPEC_PAGES` in both `scripts/render.mjs` and
`scripts/verify.py`. Marked stays in a temporary directory, so the workspace
dependencies and lockfile are untouched:

```sh
npm --prefix /tmp/etna-docs-tools install marked@17.0.5
export MARKED_MODULE=/tmp/etna-docs-tools/node_modules/marked/lib/marked.esm.js
node packages/protocol/docs/etna-pos-zk/scripts/render.mjs
node packages/protocol/docs/etna-pos-zk/scripts/render.mjs --check
python3 -I packages/protocol/docs/etna-pos-zk/scripts/verify.py
```

The renderer changes presentation only. Review the diff of `sources/` together
with the regenerated pages.

## What the checks cover

- `render.mjs --check` (Node.js 20 or later): the sources match the manifest
  hashes, the loaded Marked version matches the manifest, and every page
  in `spec/` is byte-identical to a fresh render, with no stale pages.
- `verify.py` (Python standard library only) compares the pages with the
  sources themselves rather than with other generated files: every word and
  punctuation mark in order, each code example byte for byte, heading levels and
  titles, detail titles, table shapes and ordered-list numbering. It also checks
  that every local link and fragment resolves, that external links use https to
  `github.com`, that pages contain only expected tags with no inline scripts,
  styles or event handlers, and that each page names the revision and its source
  hash.
