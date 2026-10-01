# Artifact validation and evidence boundary

This report concerns the research documents and static sites. No production contracts or clients were implemented, deployed or tested. A design-level argument is not an implementation audit, performance result or authenticated deployment manifest.

## Source and review provenance

- Initial code-reading snapshot: `961bbd8ff55a0f66f44ad04160eb51638d655b66` on main. Original file/line citations retain that identity.
- Successful public main refresh: `31df8fe8ef7c027840abf122ec36f87c41c3ce94`. The complete protocol/client delta was read; the [addendum](notes/main-refresh.md) documents the 100% source basefee share and verifier identifiers without asserting deployment. Core/shared/Anchor and client runtime source were unchanged in that interval.
- L1 roadmap and Frame Transactions sources were retrieved during this session, dated 2026-09-30. Selection status, document maturity and activation are separate facts in the [survey](02-l1-roadmap-survey.md).
- Immutable review snapshots, model assignments, input order, concrete attacks, accepted risks and checks are in [iterations](iterations/). Failed/filtered invocations contribute no review coverage.
- The PDF was absent for the original independent report. The October1 peer follow-up below records the now-completed review of its public copy.

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

Fresh rounds07–08 meet the stated stopping criterion at the eight-round cap. The final reviewed normative candidate is `c60b2042af3d422fff96e79c59f283b40cab41a5`; subsequent edits reconcile verdicts, a stale “affected anchors” phrase and source navigation, without changing interfaces, parameters, encodings or transition rules. Round07’s Medium pre-activation intake issue is corrected and independently checked in round08. Current R1–R7 pass; every Medium has an explicit disposition in [08-round](iterations/08-round.md) and the [final judge](iterations/08-judge.md). Round07’s old immutable candidate retains its narrow R7 failure; the stopping criterion is not represented as two historical all-gate passes.

The final judge reproduced17 named digest outputs, two fragment digests and six rent values with known Keccak checks. This is component arithmetic only. Browser validation after the force-intake correction again passed all21 pages. Source references outside the standalone site root now use immutable GitHub permalinks to the audited checkout; they are navigation links, not runtime dependencies. Final link/ID/asset and whitespace checks passed. EIP sources and David’s issue/corrections were checked on October1; the unrelated roadmap survey retains its September30 research date.

## Publication

The branch was pushed and [draft PR #22188](https://github.com/taikoxyz/taiko-mono/pull/22188) opened on 2026-09-30. GitHub CLI returned an API `Forbidden` response; the connected GitHub tool created the draft successfully. The PR contains only the Etna documentation directory. No site was deployed.

The anchor-removal revision and round07 correction were pushed on 2026-10-01; the final round08 records and reconciled sites are published in the same branch. The PR was observed in ready state and returned to draft to meet the requested delivery mode. Its existing title and reviewer assignments were preserved; the body now describes the final revised design and evidence. All task changes, measured from the PR merge base and the preceding delivery commit, are confined to the Etna directory; upstream main changes are not attributed to this task.

## Evidence still required before launch

**Open:** authenticate every retained deployed proxy, implementation, owner, initializer, resolver, treasury, wrapper and historical proof-program identity. Compile storage layouts and audit complete inherited/fallback/initializer call graphs. Rehearse legacy drain, activation, historic messages, caches, replay state and wrapper identities against authentic state.

**Open:** implement and audit both full execution relations, all canonical parsers and complete blob/KZG binding. Produce valid end-to-end execution/proof vectors. Measure empty-bootstrap system-call execution, ordinary pin/reveal gas, whole transaction envelopes, worst-case blocks, four-item forced prefixes, fragment publication and sustained one-second execution/proving throughput. Test reorg recovery, header pinning, actual DA retrieval/retention and the deployed Frame Transactions rules.

**Open human/economic decisions:** calibrate rent, service reserves, publication fees and forced-queue throughput against actual revenues and entrant budgets. Explicitly accept revocable soft branches, bounded identity attribution, finite evidence windows, honest deadline defaults under censorship, zero-rent concentration and long paid-backlog delay. No model-generated review can establish a profitable decentralized operator market.

These are launch obligations, not evidence secretly supplied by the documentation tests. The final verdict must preserve their distinction from specification convergence.

## Peer-design comparison and course synchronization — 2026-10-01

Public peer snapshot: `32e78bb2159e0bfb002e65b006a9b50945e0d736` in PR #22184. Four parallel readers examined sequencing/preconfirmation, economics/forced inclusion, bridge/migration and Frame Transactions/PDF sources. The lead spot-checked the cited primary files. The four source contracts supporting the public privilege/migration critique have identical Git blobs at the peer snapshot and our original `961bbd8f` source snapshot. The peer's round06 known findings were distinguished from new comparisons and acknowledged tradeoffs.

A separate fresh reviewer checked confirmation assessments, exact-subject proof sharing, the resource/funding dashboard and the proposed public critique. No material consensus-rule change or new safety contradiction was identified in these additions. Two precision corrections were applied: legacy abandoned transactions are described as losing finalization/surviving history, and unknown observation age is explicit null in the JSON sketch. A follow-up arithmetic check also corrected the zero-byte caveat: the surveyed EIP-7976 64-gas floor applies equally to zero/nonzero bytes. This is targeted review, not a ninth red-team round or an independent external audit.

The PDF input gap is now resolved from the peer's public seven-page copy. Independent extraction and the page-by-page analysis are recorded in the [input register](inputs/README.md) and [Frame addendum](03-frame-transactions-research.md#12-review-of-the-now-available-nonce-lock-pdf). The current raw EIP was refreshed on October1; its fingerprint matches the peer's September30 source. The original report's independent verdict is unchanged. No private Notion resource was accessed.

The reciprocal review arrived during this work. Its cost/capacity concerns are recorded in the [operating-profile dashboard](design/assurance.html#operating-profile): ≤2,048 body bytes/s and ≈67.2 ETH/day rent at a60-second accepted-head interval; ≤136.53 body bytes/s at900 seconds, which also cannot sustain one-second canonical blocks with60 blocks/segment; modeled10,000 publication bytes/s at64gas/B and20gwei costs1,105.92 ETH/day; the1,000-predecessor FIFO example atΔ=660 bounds delay by167,340 seconds. These are checked arithmetic under explicit scenarios, not measurements or proof of a sustainable market. Production feasibility is unresolved.

The optional network schemas, client reporting and evidence organization do not change Inbox admission, proof relations, custody storage, slashing, payouts or consensus constants. The historical round07–08 verdict stays attached to its original mechanism snapshot. No stronger readiness claim is inferred from successful document checks.

**Final follow-up document checks:** all23 HTML pages resolve local file/fragment links with unique IDs and no scripts, iframes or external runtime assets. Chromium loaded every page at1280-pixel desktop and390-pixel mobile widths with zero page-width overflow, zero out-of-viewBox SVG text and zero external asset requests. The23 pages contain27 inline SVGs and35 native hidden-answer blocks. A mobile answer expanded correctly; desktop/mobile screenshots of the new reference pages were inspected. `git diff --check` passes.

All13 learning pages were reviewed and synchronized: the12 lessons keep prerequisite order, motivating problems, diagrams, numeric examples,2–3 hidden answers each and challenge boxes. Updates cover confirmation evidence and local-clock deferral; no-minimum-age origin reorg exposure; per-segment bytes/block counts; exact-statement proof reuse; ACTIVE-only queue intake and the long-backlog example; service capital versus ETH costs; recurring publication cost; rent/throughput tradeoffs; bounded checkpoint/bridge coverage; and the final assembly. All course status banners distinguish the historical review milestone from unresolved production feasibility. No consensus rule was changed to make the course examples work.
