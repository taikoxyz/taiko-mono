# Artifact validation and evidence boundary

This report concerns the research documents and static sites. No production contracts or clients were implemented, deployed or tested. A design-level argument is not an implementation audit, performance result or authenticated deployment manifest.

## Source and review provenance

- Initial code-reading snapshot: `961bbd8ff55a0f66f44ad04160eb51638d655b66` on main. Original file/line citations retain that identity.
- Successful public main refresh: `31df8fe8ef7c027840abf122ec36f87c41c3ce94`. The complete protocol/client delta was read; the [addendum](notes/main-refresh.md) documents the 100% source basefee share and verifier identifiers without asserting deployment. Core/shared/Anchor and client runtime source were unchanged in that interval.
- L1 roadmap and Frame Transactions sources were retrieved during this session, dated 2026-09-30. Selection status, document maturity and activation are separate facts in the [survey](02-l1-roadmap-survey.md).
- Immutable review snapshots, model assignments, input order, concrete attacks, accepted risks and checks are in [iterations](iterations/). Failed/filtered invocations contribute no review coverage.
- The referenced PDF was not supplied. [Frame research](03-frame-transactions-research.md) verifies the independently stated hypothesis, not an unseen document.

## Original delivery checks — 2026-09-30

**Proven observations at original delivery:** the reference and course had 19 HTML pages, 23 inline SVG diagrams and 29 native hidden-answer blocks. The final document-parser check reports zero errors for local targets, fragment identifiers, duplicate IDs, scripts/iframes and external asset dependencies. All local links resolve.

Desktop, mobile and dark-mode screenshots were inspected locally. Mobile diagrams were changed to retain readable width inside a keyboard-focusable scrolling region. The browser environment blocks direct file URLs, so actual browser verification uses a localhost static server; no externally hosted site or deployment was created. Relative HTML/CSS links have no runtime network dependency.

Independent component calculations checked known Keccak-256 empty/`abc` values, the exact publication signature domain/type, body/fragment/manifest commitments, fragment receipt key/binding, bootstrap certificate/head hashes and rounding at rent boundaries. Reviewer reports identify which checks each agent actually ran. The small codec fixture deliberately uses a toy header and is not a valid execution proof. Fee arithmetic was updated for 100% coinbase allocation: 21,000 gas at102,500,000 wei basefee contributes2,152,500,000,000 wei basefee plus42,000,000,000 wei for a2,000,000-wei tip, all to coinbase.

All throwaway calculations and browser-check code live only in the session scratchpad and are deleted before completion. The committed deliverables contain documentation, HTML, CSS and SVG; interface sketches are specifications only.

## Original final delivery checks

Completed on 2026-09-30:

- Six adversarial rounds are recorded. The final judge confirms convergence across rounds 05–06: no new Critical/High, every Medium has a written disposition, and R1–R7 pass under their named assumptions. The final normative snapshot is `34f4e8a1cb47e34451b66fa518d5819693833fc0`; subsequent edits reconcile status, navigation and presentation without changing mechanisms, interfaces or parameters.
- All 19 pages loaded in Chromium at desktop and 390-pixel mobile widths. There were zero external asset requests, zero SVG text bounds failures and zero page-width overflows. Native hidden-answer expansion and keyboard scrolling of the mobile concept map passed. Desktop, mobile and dark-mode screenshots were visually inspected.
- A separate read-only course audit checked all eleven lessons for prerequisite order, motivation, mechanism, diagram, concrete example, attack limits, hidden self-check answers and a challenge box. The publication-cost example now explicitly assumes nonzero bytes; the competition lesson distinguishes self-paid L2 fees from irreversible costs.
- A final independent editorial audit checked current status labels and local navigation. Historical reports retain their original verdicts; the current reference and course carry the final result.
- `git diff --check` passes. All deliverable changes are confined to `packages/protocol/docs/Etna/`. No production-code tests, circuit implementation, deployment, layout generation or gas/performance benchmark is represented as completed.

## Anchor-removal revision checks — 2026-10-01

**Proven local observations:** the updated sites have 21 HTML pages, 25 inline SVG diagrams and 32 native hidden-answer blocks. All local file/fragment references resolve; no duplicate IDs, scripts, iframes or external assets were found. Chromium loaded every page at desktop and 390-pixel mobile widths: zero SVG text-bounds failures, zero page-width overflow and zero external asset requests. The new lesson's native hidden answers and keyboard scrolling worked; desktop/mobile screenshots were inspected.

All twelve lessons retain their prerequisite order, motivating problem, mechanism, diagram, numeric example, attack limits, two or three hidden self-check answers and challenge box. A separate read-only course review checked consistency. Independent scratch serialization reproduced the 1,039-byte empty-bootstrap and 1,845-byte forced-reveal envelope bounds; these synthetic framing checks are not complete execution vectors or gas measurements.

The immutable candidate `575d41a5ad2aa1a276c9a491cd04dcd4d1f8d8c2` is under fresh rounds 07–08. Their result will be recorded before publication. The earlier convergence verdict does not automatically cover this changed mechanism. EIP sources and David's issue/corrections were checked on October1; the unrelated roadmap survey retains its September30 research date.

## Publication

The branch was pushed and [draft PR #22188](https://github.com/taikoxyz/taiko-mono/pull/22188) opened on 2026-09-30. GitHub CLI returned an API `Forbidden` response; the connected GitHub tool created the draft successfully. The PR contains only the Etna documentation directory. No site was deployed.

## Evidence still required before launch

**Open:** authenticate every retained deployed proxy, implementation, owner, initializer, resolver, treasury, wrapper and historical proof-program identity. Compile storage layouts and audit complete inherited/fallback/initializer call graphs. Rehearse legacy drain, activation, historic messages, caches, replay state and wrapper identities against authentic state.

**Open:** implement and audit both full execution relations, all canonical parsers and complete blob/KZG binding. Produce valid end-to-end execution/proof vectors. Measure empty-bootstrap system-call execution, ordinary pin/reveal gas, whole transaction envelopes, worst-case blocks, four-item forced prefixes, fragment publication and sustained one-second execution/proving throughput. Test reorg recovery, header pinning, actual DA retrieval/retention and the deployed Frame Transactions rules.

**Open human/economic decisions:** calibrate rent, service reserves, publication fees and forced-queue throughput against actual revenues and entrant budgets. Explicitly accept revocable soft branches, bounded identity attribution, finite evidence windows, honest deadline defaults under censorship, zero-rent concentration and long paid-backlog delay. No model-generated review can establish a profitable decentralized operator market.

These are launch obligations, not evidence secretly supplied by the documentation tests. The final verdict must preserve their distinction from specification convergence.
