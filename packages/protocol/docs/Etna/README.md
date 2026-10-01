# Etna research and design

Etna investigates a fully permissionless successor to Taiko's based-rollup protocol. This is a design project: no production contracts, clients, deployments, or changes outside this directory.

**Research candidate; current acceptance gates are not all demonstrated.** Etna adopts [David’s standard-call direction](https://github.com/taikoxyz/taiko-mono/issues/22147#issuecomment-5756531478): standard EIP-4788/2935, ordinary permissionless checkpoint persistence, and no L2 anchor transaction. Product, resource and economic issues remain open, particularly R4/R6/R7. This is not an implementation-ready or production-ready verdict. Branch: `codex/etna-protocol-design`. [Draft PR #22188](https://github.com/taikoxyz/taiko-mono/pull/22188).

**Historical review milestone:** model-generated rounds07–08 reported convergence for the anchor-removal snapshot `c60b2042af3d422fff96e79c59f283b40cab41a5`; the [judge](iterations/08-judge.md) records no new Critical/High and dispositions for every Medium. Later peer criticism exposes unresolved acceptance questions that this historical result does not settle. Accepting a finding as Medium cannot waive a hard requirement. No ninth full round or impossibility proof is claimed.

## How to read

1. [Current protocol](00-current-protocol-summary.md) and [threat model](01-threat-model.md).
2. [L1 roadmap](02-l1-roadmap-survey.md) and [Frame Transactions research](03-frame-transactions-research.md).
3. [Design reference](design/index.html) and [progressive learning course](learn/index.html), static HTML with inline SVG, no build or network dependencies.
4. [Review iterations](iterations/) and [subsystem research notes](notes/).

[Validation and evidence limits](validation.md) records checks actually performed. Research notes and historical revisions explain prior observations and alternatives; the eight mechanism pages control consensus; the two new companion pages specify optional proof discovery and consolidate launch evidence. Uppercase `Etna/` follows the requested final deliverable layout; no separate lowercase directory is used.

## Peer-design follow-up — October1

[Comparison with Claude’s PR #22184](notes/peer-design-comparison.md): adopted explicit [confirmation assessments](design/index.html#assessment), clock-policy deferral, optional [proof discovery](design/proof-discovery.html), and an [invariant/resource/funding dashboard](design/assurance.html). The public nonce-lock PDF was also reviewed. These additions specify client behavior and evidence; Inbox rules, proof thresholds, timing constants and custody transitions are unchanged. The original convergence record is scoped to its reviewed snapshot; this follow-up receives targeted validation, not a ninth full round.

**Production feasibility remains unresolved.** The [reciprocal peer review](https://github.com/taikoxyz/taiko-mono/pull/22188#issuecomment-5926119441) correctly challenges throughput, recurring publication cost and paid-backlog delay. The earlier review-loop stopping criterion does not settle these product/economic questions. This operating profile is not a production launch recommendation.

**All-comment follow-up:** the [complete disposition ledger](notes/pr-comment-dispositions.md) accounts for all nine distinct records observed across the initial read and final refresh, including both inline findings and every substantive point in the longer reviews. It distinguishes corrected documentation, resolved old defects and unresolved mechanisms. The [course synchronization checklist](notes/design-course-sync.md) maps reference changes to lessons and validation.

**A stronger cost result:** sustaining one accepted L2 block per second requires at least67.2 ETH/day in canonical rent under the current limits, regardless of regular versus bursty landing. At10,000 encoded body bytes/s the optimistic necessary bound is346.7625 ETH/day. This is proved arithmetic under the rules, not a measured market; R4's soft issuance target alone does not require every candidate to land. See the [derivation and budget frontier](design/assurance.html#operating-profile).

### Unverified numeric assumptions and derived bounds

The [central resource register](design/assurance.html#dependencies) distinguishes configured limits, derived byte bounds and unmeasured performance. No row below is a completed benchmark.

| Proposed bounds / assumptions | Evidence still required |
|---|---|
| 1-second issuance; 10M gas/block,120M/segment; ≤60 blocks | Sustained execution and proving of admitted workloads, including standard system calls |
| Retrieval60s + proving180s; stage age360–900s; origin age≤900s; fragment publication≤240s | Tail latency, concurrency, inclusion/funding and expiry recovery |
| Body122,880 blob bytes or32,768 calldata bytes; complete proof ABI≤16,384 bytes | Valid proofs and complete L1 action including all overhead |
| Forced raw transaction≤2,048 bytes,gas≤1M; ≤4 frozen-prefix entries | Supported Bridge-operation coverage and congestion/backlog behavior |
| L1 header≤1,536 bytes,12–32 scalar fields; L2 header≤1,024 bytes; oracle read100,000 gas | Launch-fork schemas, exact runtime code and maximum pin/reveal/bootstrap gas |
| Derived forced-reveal≤1,845 bytes; empty-bootstrap body≤1,039 bytes | Analytical serialization bounds have scratch checks; the body bound is not a full L1 transaction bound; valid execution/proof envelopes and gas remain unmeasured |
| Rent ceiling0.05 ETH/900s decay; 10/1,000 TAIKO duty/job bonds; 10% reporter/90% sink slash | Affordable funded service, entrant competition and calibrated deterrence; all amounts remain proposed |

Other exact timeouts, fees and caps retain their owning [core](design/index.html), [roles](design/roles.html) and [accountability](design/accountability.html) tables. Permanent origin/checkpoint storage remains unbounded over time; no new persistence tariff has been adopted.

## Requirement ledger

| ID | Hard requirement | Acceptance criterion | Verdict |
|---|---|---|---|
| R1 | 100% permissionless; DAO owns upgradeability only | Any address can enter/exit every role under objective on-chain conditions; no operational admin/operator/allowlist gate; chain remains live without DAO action. | Specified: objective entry/recovery and upgrade-only DAO. Complete deployed selector/call-graph validation and funded-operation assumptions remain open. |
| R2 | Reuse existing SignalService, Bridge, ERC20/ERC721/ERC1155 Vault addresses on both layers | Specify exact checkpoint/state-root interfaces from inbox and anchor; enumerate all shared-contract changes and storage-compatible upgrades; deploy no new frozen addresses. | Specified: exact checkpoint ABI, retained addresses and compatible-upgrade plan. Authenticated deployments, layouts and historical-state rehearsal remain open. |
| R3 | Richer role set permitted | Every role has entry, exit, duties, rewards, slashing, and all-offline/all-malicious failure analysis. | Role terms and conditional failure analysis documented. Economically willing, capable entrants remain an assumption. |
| R4 | At most 1-second preconfirmed L2 block cadence | Define block time as preconfirmation issuance interval and user soft-confirmation latency; decouple L1 landing cadence. | Open: one-second issuance target specified, with revocable locally valid branches. Sustained performance and acceptable soft-confirmation semantics have not been established. |
| R5 | No CL lookahead or L1-slot coupling | Never consume future validator/proposer schedules; authenticated CL facts allowed; all timers in seconds or L1 block numbers; work with 12/6/4/2-second L1 slots. | Specification inspection establishes schedule independence: seconds, block identity and authenticated past headers. Cross-cadence performance remains unmeasured. |
| R6 | Objective penalties and slashing; concrete anti-monopoly economics | Specify L1-verifiable evidence, permissionless submitter, payout split, false-accusation deterrence for every offense; tabulate rotation/caps/auctions/decay and rationale. | Open: finite objective duties and conditional rent deterrence specified; practical anti-monopoly effectiveness and affordable funded competition unestablished. No universal attribution or punishment claim. |
| R7 | Propose with proof | Single L1 action/frame carries batch data and valid ZK proof; describe minute-long preconfirmation/proving window, prover failure, forced inclusion, finality and blobs/calldata. | Open: atomic full data+proof, exact bootstrap and frozen FIFO specified. Sustained minute-level proving, supported forced operations, complete resource bounds and economics unestablished. Earlier generic DA grants no priority. |

Baseline: assume Frame Transactions live before launch; survey Glamsterdam and Hegota; retain today's bond/reward denomination, native token and gas accounting unless a change is justified. Every design assertion is classified **proven**, **assumed** (named assumption), or **open** (resolution criterion). URC is removed in Etna.

## Phase checklist

- [x] 0: inspect instructions, create branch and requirement ledger.
- [x] 1: read L1, L2/shared, Go, Rust and docs; synthesize baseline and threat model.
- [x] 2: verify current Frame Transactions specification/discussions and L1 roadmap (initially independent; public PDF reviewed in the October1 follow-up).
- [x] 3: draft glossary, mechanisms, state machines, interfaces, parameters and migration.
- [x] 4–5: independent multi-model red team and judge; revise and log (maximum eight rounds).
- [x] Historical loop completed: eight rounds; rounds07–08 reported the stopping criterion at their reviewed snapshot.
- [ ] Current acceptance: close peer-review product/resource/economic findings and demonstrate all R1–R7, or establish an evidence-backed negative verdict. Neither outcome is currently established.
- [x] 6: complete design/course HTML, validate artifacts, commit, push and open draft PR.
- [x] 7: deliver verdict, five key decisions, human decisions and entry links in the session report.

Phase boundaries and review rounds are committed separately. Design convergence does not imply launch readiness. The review log records actual reviewer models, concrete attack traces, evidence, severity and disposition.

## Provenance and outstanding inputs

- Initial session: 2026-09-30 UTC; anchor-removal revision: 2026-10-01 UTC.
- Initial source snapshot: `961bbd8ff55a0f66f44ad04160eb51638d655b66` (initial main checkout; public fetch subsequently verified main at `31df8fe8ef7c027840abf122ec36f87c41c3ce94`; see baseline addendum).
- The user-authorized branch is `codex/etna-protocol-design`.
- The seven-page nonce-lock PDF is now reviewed from the public peer PR; [provenance/checksum](inputs/README.md) and the [dated review](03-frame-transactions-research.md#12-review-of-the-now-available-nonce-lock-pdf) preserve the distinction from the original independent analysis.
- Repository guidance: root `CLAUDE.md`, protocol `CLAUDE.md`, client `AGENTS.md` where applicable. Documentation-only checks apply; no contract tests or layout generation are needed without source changes.
- Throwaway analysis belongs in `/tmp/etna-scratch/` (initial work) or `/tmp/etna-anchor-scratch/` (revision); it is not committed and is removed at completion.
- Do not record API keys, private resources or credentials in these artifacts.

## Open the sites

Open `design/index.html` or `learn/index.html` from a local checkout. If the browser blocks local-file styles, serve this directory with a local static server:

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory packages/protocol/docs/Etna
```

Then visit `http://127.0.0.1:8765/learn/` or `/design/`. To serve on GitHub Pages, publish this directory unchanged as the static root; relative links, local CSS, inline SVG and `.nojekyll` need no build step. This task does not deploy a hosted site.

## Human decisions and launch evidence

- Calibrate the proposed 0.05-ETH rent ceiling,900-second decay, service reserves and force capacity. Sustaining one accepted block/s costs at least67.2 ETH/day in rent under these rules; no sustainable market has been demonstrated. Lowering the rent weakens the same capture-cost argument.
- Explicitly accept revocable soft branches, limited cross-owner attribution and evidence horizons, zero-rent/high-MEV concentration and paid-backlog delay. Slashing proves exact missed duties, not global gossip or intent.
- Authenticate migration state and layouts, then implement and measure complete proof/DA relations, activation certificates, maximum-work execution and sustained proving before launch.

## Anchor-removal revision checklist

- [x] Read issue #22147 and its corrections; map current responsibilities and expiry/migration attacks.
- [x] Integrate standard EIP-4788/2935, permissionless pins/reveals, preserved custody and anchor-free bootstrap.
- [x] Fresh rounds 07–08; preserve the original eight-round cap and report any unresolved findings honestly.
- [x] Validate reference/course, commit, push and update draft PR #22188.

The original phase checklist records the earlier completed delivery. The revision checklist above controls this follow-up.
