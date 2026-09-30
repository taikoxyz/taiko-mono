# Etna research and design

Etna investigates a fully permissionless successor to Taiko's based-rollup protocol. This is a design project: no production contracts, clients, deployments, or changes outside this directory.

**Status:** Round1 complete: one High withholding failure found; revision1 adds public-data staging and objective duties and awaits fresh independent review. PDF-specific review remains unavailable. No implementation-readiness claim. Branch: `codex/etna-protocol-design`.

## How to read

1. [Current protocol](00-current-protocol-summary.md) and [threat model](01-threat-model.md).
2. [L1 roadmap](02-l1-roadmap-survey.md) and [Frame Transactions research](03-frame-transactions-research.md).
3. [Design reference](design/index.html) and [progressive learning course](learn/index.html), static HTML with inline SVG, no build or network dependencies.
4. [Review iterations](iterations/) and [subsystem research notes](notes/).

Links to unfinished phases become available as work completes. Uppercase `Etna/` follows the requested final deliverable layout; no separate lowercase directory is used.

## Requirement ledger

| ID | Hard requirement | Acceptance criterion | Verdict |
|---|---|---|---|
| R1 | 100% permissionless; DAO owns upgradeability only | Any address can enter/exit every role under objective on-chain conditions; no operational admin/operator/allowlist gate; chain remains live without DAO action. | Unassessed |
| R2 | Reuse existing SignalService, Bridge, ERC20/ERC721/ERC1155 Vault addresses on both layers | Specify exact checkpoint/state-root interfaces from inbox and anchor; enumerate all shared-contract changes and storage-compatible upgrades; deploy no new frozen addresses. | Unassessed |
| R3 | Richer role set permitted | Every role has entry, exit, duties, rewards, slashing, and all-offline/all-malicious failure analysis. | Unassessed |
| R4 | At most 1-second preconfirmed L2 block cadence | Define block time as preconfirmation issuance interval and user soft-confirmation latency; decouple L1 landing cadence. | Unassessed |
| R5 | No CL lookahead or L1-slot coupling | Never consume future validator/proposer schedules; authenticated CL facts allowed; all timers in seconds or L1 block numbers; work with 12/6/4/2-second L1 slots. | Unassessed |
| R6 | Objective penalties and slashing; concrete anti-monopoly economics | Specify L1-verifiable evidence, permissionless submitter, payout split, false-accusation deterrence for every offense; tabulate rotation/caps/auctions/decay and rationale. | Unassessed |
| R7 | Propose with proof | Single L1 action/frame carries batch data and valid ZK proof; describe minute-long preconfirmation/proving window, prover failure, forced inclusion, finality and blobs/calldata. | Unassessed |

Baseline: assume Frame Transactions live before launch; survey Glamsterdam and Hegota; retain today's bond/reward denomination, native token and gas accounting unless a change is justified. Every design assertion is classified **proven**, **assumed** (named assumption), or **open** (resolution criterion). URC is removed in Etna.

## Phase checklist

- [x] 0: inspect instructions, create branch and requirement ledger.
- [x] 1: read L1, L2/shared, Go, Rust and docs; synthesize baseline and threat model.
- [x] 2: verify current Frame Transactions specification/discussions and L1 roadmap (referenced PDF absent; independent hypothesis analyzed).
- [x] 3: draft glossary, mechanisms, state machines, interfaces, parameters and migration.
- [ ] 4–5: independent multi-model red team and judge; revise and log (maximum eight rounds).
- [ ] Convergence: two consecutive rounds with no new Critical/High, all Medium dispositions, all R1–R7 pass; **or** evidence-backed negative verdict and smallest relaxation.
- [ ] 6: complete design/course HTML, validate artifacts, commit, push and open draft PR.
- [ ] 7: report verdict, five key decisions, human decisions and entry links.

Each phase is committed before the next. No phase completion implies readiness. The review log records actual reviewer models, concrete attack traces, evidence, severity and disposition.

## Provenance and outstanding inputs

- Session date: 2026-09-30 UTC.
- Initial source snapshot: `961bbd8ff55a0f66f44ad04160eb51638d655b66` (checkout fetch configuration selects `main`; remote freshness to verify).
- The user-authorized branch is `codex/etna-protocol-design`.
- `inputs/nonce-as-a-lock.pdf` has **not been supplied**. The research will distinguish analysis of the stated nonce-lock hypothesis from review of the unavailable PDF. No PDF claims will be invented.
- Repository guidance: root `CLAUDE.md`, protocol `CLAUDE.md`, client `AGENTS.md` where applicable. Documentation-only checks apply; no contract tests or layout generation are needed without source changes.
- Throwaway analysis belongs in `/tmp/etna-scratch/`; it is not committed and is removed at completion.
- Do not record API keys, private resources or credentials in these artifacts.
