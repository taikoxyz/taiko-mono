# Etna PoS + ZK — reference specification

A complete, reviewable snapshot of the current
[Etna PoS + ZK Design Spec](https://app.notion.com/p/3fe9673143d6817a9f0fdaaf1b965d7a)
and its
[Acceptance and Launch Checklist](https://app.notion.com/p/4059673143d6817fbd80ec6bec24b95b).

TAIKO stakers run stock CometBFT to order and commit L2 blocks. Permissionless landers
settle proven batches on Ethereum; L1 funds recognize only landed checkpoints.
The target is Stage 0.

**Status: design specification snapshot.** This directory publishes the source's
rules, constraints, reference examples and open items. It adds no implementation
or measurement, and claims no audit, review convergence or deployment readiness.
The approximately 4 s block time, 20 min landing cadence and U = 3,600 are
unmeasured operating targets/reference configuration subject to the acceptance
checklist. K remains unset.

## Where to read

| Entry                                                          | Purpose                                                                                                      |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| [SPEC.md](SPEC.md)                                             | Complete specification: sections 1–12 and appendices A–C, including every detail block and reference example |
| [spec/index.html](spec/index.html)                             | The same full specification as an offline reader with a section sidebar, foldable details and print controls |
| [ACCEPTANCE.md](ACCEPTANCE.md)                                 | Complete companion acceptance and launch checklist                                                           |
| [spec/acceptance.html](spec/acceptance.html)                   | The same checklist in the offline reader                                                                     |
| [sources/manifest.json](sources/manifest.json)                 | Page identities, source edit times, SHA-256 hashes and renderer version                                      |
| [sources/design-spec.notion.md](sources/design-spec.notion.md) | Retained complete Notion body before presentation conversion                                                 |
| [sources/acceptance.notion.md](sources/acceptance.notion.md)   | Retained complete checklist body before presentation conversion                                              |

Download this directory and open **spec/index.html** directly in a browser.
Both HTML documents contain their full text and use only the adjacent local CSS
and optional JavaScript. There is no CDN, external font, network fetch or server
requirement. Section navigation and native detail controls also work without
JavaScript. Expand all details before using the browser's menu-based Find command;
Ctrl/Cmd+F expands them automatically. Printing expands details and restores their
previous state afterward.

## Reading map

The section numbers and order follow Notion exactly.

| Topic                                                                     | Complete specification                                                              |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Security model and trust assumptions                                      | [1. Positioning and security model](SPEC.md#1-positioning-and-security-model)       |
| Roles and components                                                      | [2. Components](SPEC.md#2-components)                                               |
| Stock CometBFT, EL integration, anchors, validity and size limits         | [3. Consensus and blocks](SPEC.md#3-consensus-and-blocks)                           |
| Registration, exits, double-sign evidence, epochs and committee selection | [4. Staking and committees](SPEC.md#4-staking-and-committees)                       |
| Private envelopes, public blobs and public EL reconstruction              | [5. Data formats and DA](SPEC.md#5-data-formats-and-da)                             |
| Landing checks, two proofs, grid cuts, overlapping jobs and back-pressure | [6. Landing and settlement](SPEC.md#6-landing-and-settlement)                       |
| Queue admission, singleton builds, legal skipping and protocol fees       | [7. Forced inclusion](SPEC.md#7-forced-inclusion)                                   |
| Pauses, safety halts, verifier failure and atomic DAO recovery            | [8. Halts and recovery](SPEC.md#8-halts-and-recovery)                               |
| L1 checkpoint trust, guarded signing and private-history availability     | [9. Sync and weak subjectivity](SPEC.md#9-sync-and-weak-subjectivity)               |
| Genesis, deployment constraints and protocol upgrade boundaries           | [10. Startup and deployment](SPEC.md#10-startup-and-deployment)                     |
| Parameter sources, constraints and reference values                       | [11. Parameters](SPEC.md#11-parameters)                                             |
| All 18 limitations and open items                                         | [12. Known limitations and open items](SPEC.md#12-known-limitations-and-open-items) |
| Exact domains, encodings, ABI and reference examples                      | [Appendix A](SPEC.md#appendix-a-encodings)                                          |
| Inbox and registry slots, packing and namespaces                          | [Appendix B](SPEC.md#appendix-b-l1-storage-layout)                                  |
| DAO operating funding and worst-case cost assumptions                     | [Appendix C](SPEC.md#appendix-c-operating-funding-and-cost-assumptions)             |

## Key review points

- **Consensus and signing:** stock CometBFT v0.40.0, secp256k1eth, a full
  deployment/generation-bound signing domain, H+2 committee activation and an
  external signer gated by authenticated checkpoint trust.
- **Settlement:** exactly two sub-proofs with at least one ZK proof. A batch proves
  the full (p,h] range; execution reads c atomically and settles only (c,h].
  Grid leaves bind the current EL hash, Comet hash and FI cursor before verification.
- **Fees:** all L2 base fees and tips go to each block's beneficiary. FI admission
  fees stay in the Inbox and anyone may sweep its entire ETH balance to the fixed
  DAO treasury. Landing has no protocol reward.
- **Recovery:** the owner calls recover with expected generation/c and atomic
  exclusion/FI-blanking lists. Inbox stores no recovery queue or separate stall
  timer. Exclusions force exits without slashing. The settled prefix remains;
  the unsettled suffix is discarded, with a fixed authenticated origin for the
  new generation. Verifier-failure rollback is a separate DAO upgrade.
- **Open design and acceptance:** the Unzen switch and bridge wiring, upgrade
  activation, K/proving capacity, registry admission and an external capital
  target for the total-stake floor remain as disclosed in section 12.
  The full real-guest, signer, resource, recovery and launch checks remain required.

These are reading aids. The complete specification body supplies the validity
rules; the companion checklist supplies acceptance and launch requirements.
The source's normative checks and illustrative helper bodies remain distinguished,
including in the section 6.1 reference Solidity.

## Source provenance and editorial scope

| Source                          | Last edited in Notion (UTC) |
| ------------------------------- | --------------------------- |
| Design specification            | 2026-10-28T08:47:22.317Z    |
| Acceptance and launch checklist | 2026-10-27T02:33:26.010Z    |

The retained sources are the complete fetched page bodies. Page-wrapper metadata
is recorded in the manifest; Notion's generated table of contents is regenerated.
Notion callouts become blockquotes, ordinary toggles become native details, and
section-heading toggles become visible numbered headings. Discussion decoration
is removed while its text remains. Page mentions resolve to the included local
document; external technical references remain linked. Protocol prose order,
tables, formulas and all five fenced examples are retained.

The Notion design body remains the authority for validity rules. These files
represent the dated snapshot above; later Notion edits require an explicit refresh.
Any apparent protocol contradiction should be raised against the source, rather
than silently resolved in an exported copy.

[PR #22262](https://github.com/taikoxyz/taiko-mono/pull/22262) supplies the
documentation/reading style. Its older mechanisms, decision and review history,
convergence labels and course content are not source material for this snapshot.

## Regeneration and verification

Reading requires no tools. Regeneration requires Node.js 20+ and
[Marked](https://github.com/markedjs/marked) 17.0.5. Keep that build dependency in
a temporary directory so the monorepo's workspace dependencies stay unchanged:

```sh
# Run from the monorepo root; create the directory if it does not exist.
mkdir -p /tmp/etna-docs-tools
pnpm --dir /tmp/etna-docs-tools add marked@17.0.5
export MARKED_MODULE=/tmp/etna-docs-tools/node_modules/marked/lib/marked.esm.js

node packages/protocol/docs/Etna/pos-zk/scripts/render.mjs
node packages/protocol/docs/Etna/pos-zk/scripts/render.mjs --check
python3 packages/protocol/docs/Etna/pos-zk/scripts/verify.py
git diff --check
```

The renderer checks ordered prose preservation and byte-identical fenced examples.
Its check mode verifies source hashes and byte-identical generated output.
The structural verifier checks every local file/fragment link, section and
detail/table count, rendered prose, and rendered code against the Markdown.

To refresh, fetch both complete Notion bodies, replace the two retained sources,
update their manifest titles/URLs/edit times and this provenance table, then
regenerate and run the checks. Review the source diff alongside generated files.
