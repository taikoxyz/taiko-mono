# Etna research and design

Etna investigates a fully permissionless successor to Taiko's based-rollup protocol. This is a design project: no production contracts, clients, deployments, or changes outside this directory.

**Verdict: converged design specification.** Six rounds are complete. The [final judge](iterations/06-judge.md) confirms rounds 05–06 have no new Critical/High, all Mediums have written dispositions, and R1–R7 pass under explicit assumptions. This is a reference for implementation, not verified production code or launch approval. Economic concentration, finite accountability and unmeasured deployment/performance remain material limits. Branch: `codex/etna-protocol-design`. [Draft PR #22188](https://github.com/taikoxyz/taiko-mono/pull/22188).

## How to read

1. [Current protocol](00-current-protocol-summary.md) and [threat model](01-threat-model.md).
2. [L1 roadmap](02-l1-roadmap-survey.md) and [Frame Transactions research](03-frame-transactions-research.md).
3. [Design reference](design/index.html) and [progressive learning course](learn/index.html), static HTML with inline SVG, no build or network dependencies.
4. [Review iterations](iterations/) and [subsystem research notes](notes/).

[Validation and evidence limits](validation.md) records checks actually performed. Research notes and historical revisions explain prior observations and alternatives; the seven current HTML reference pages control the specification. Uppercase `Etna/` follows the requested final deliverable layout; no separate lowercase directory is used.

## Requirement ledger

| ID | Hard requirement | Acceptance criterion | Verdict |
|---|---|---|---|
| R1 | 100% permissionless; DAO owns upgradeability only | Any address can enter/exit every role under objective on-chain conditions; no operational admin/operator/allowlist gate; chain remains live without DAO action. | Pass: open objective roles and recovery; DAO authorizes upgrades only. Funding/capability assumptions remain. |
| R2 | Reuse existing SignalService, Bridge, ERC20/ERC721/ERC1155 Vault addresses on both layers | Specify exact checkpoint/state-root interfaces from inbox and anchor; enumerate all shared-contract changes and storage-compatible upgrades; deploy no new frozen addresses. | Pass at specification level: exact checkpoint ABI, retained addresses and enumerated compatible upgrades. Live-state rehearsal remains open. |
| R3 | Richer role set permitted | Every role has entry, exit, duties, rewards, slashing, and all-offline/all-malicious failure analysis. | Pass: every role has funded terms, penalties, exit and total-outage analysis. |
| R4 | At most 1-second preconfirmed L2 block cadence | Define block time as preconfirmation issuance interval and user soft-confirmation latency; decouple L1 landing cadence. | Pass as a conditional one-second issuance target; latency and finality separated. Sustained performance requires measurement. |
| R5 | No CL lookahead or L1-slot coupling | Never consume future validator/proposer schedules; authenticated CL facts allowed; all timers in seconds or L1 block numbers; work with 12/6/4/2-second L1 slots. | Pass: seconds, L1 block identity and authenticated past headers; no CL lookahead. |
| R6 | Objective penalties and slashing; concrete anti-monopoly economics | Specify L1-verifiable evidence, permissionless submitter, payout split, false-accusation deterrence for every offense; tabulate rotation/caps/auctions/decay and rationale. | Pass for objective finite duties and concrete bounded rent economics. Concentration risks explicitly accepted; effectiveness unmeasured. |
| R7 | Propose with proof | Single L1 action/frame carries batch data and valid ZK proof; describe minute-long preconfirmation/proving window, prover failure, forced inclusion, finality and blobs/calldata. | Pass: full data plus proof in one canonical action, exact bootstrap, open recovery and frozen FIFO. Earlier generic DA grants no priority. |

Baseline: assume Frame Transactions live before launch; survey Glamsterdam and Hegota; retain today's bond/reward denomination, native token and gas accounting unless a change is justified. Every design assertion is classified **proven**, **assumed** (named assumption), or **open** (resolution criterion). URC is removed in Etna.

## Phase checklist

- [x] 0: inspect instructions, create branch and requirement ledger.
- [x] 1: read L1, L2/shared, Go, Rust and docs; synthesize baseline and threat model.
- [x] 2: verify current Frame Transactions specification/discussions and L1 roadmap (referenced PDF absent; independent hypothesis analyzed).
- [x] 3: draft glossary, mechanisms, state machines, interfaces, parameters and migration.
- [x] 4–5: independent multi-model red team and judge; revise and log (maximum eight rounds).
- [x] Convergence: two consecutive rounds with no new Critical/High, all Medium dispositions, all R1–R7 pass; **or** evidence-backed negative verdict and smallest relaxation.
- [x] 6: complete design/course HTML, validate artifacts, commit, push and open draft PR.
- [x] 7: deliver verdict, five key decisions, human decisions and entry links in the session report.

Phase boundaries and review rounds are committed separately. Design convergence does not imply launch readiness. The review log records actual reviewer models, concrete attack traces, evidence, severity and disposition.

## Provenance and outstanding inputs

- Session date: 2026-09-30 UTC.
- Initial source snapshot: `961bbd8ff55a0f66f44ad04160eb51638d655b66` (initial main checkout; public fetch subsequently verified main at `31df8fe8ef7c027840abf122ec36f87c41c3ce94`; see baseline addendum).
- The user-authorized branch is `codex/etna-protocol-design`.
- `inputs/nonce-as-a-lock.pdf` has **not been supplied**. The research distinguishes the stated nonce-lock hypothesis from the unavailable PDF. No page-by-page PDF review is claimed.
- Repository guidance: root `CLAUDE.md`, protocol `CLAUDE.md`, client `AGENTS.md` where applicable. Documentation-only checks apply; no contract tests or layout generation are needed without source changes.
- Throwaway analysis belongs in `/tmp/etna-scratch/`; it is not committed and is removed at completion.
- Do not record API keys, private resources or credentials in these artifacts.

## Open the sites

Open `design/index.html` or `learn/index.html` from a local checkout. If the browser blocks local-file styles, serve this directory with a local static server:

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory packages/protocol/docs/Etna
```

Then visit `http://127.0.0.1:8765/learn/` or `/design/`. To serve on GitHub Pages, publish this directory unchanged as the static root; relative links, local CSS, inline SVG and `.nojekyll` need no build step. This task does not deploy a hosted site.

## Human decisions and launch evidence

- Calibrate the proposed 0.05-ETH rent ceiling, 900-second decay, service reserves and force capacity. An illustrative 60-second acceptance cadence alone sinks about 67.2 ETH/day in rent; no sustainable market has been demonstrated.
- Explicitly accept revocable soft branches, limited cross-owner attribution and evidence horizons, zero-rent/high-MEV concentration and paid-backlog delay. Slashing proves exact missed duties, not global gossip or intent.
- Authenticate migration state and layouts, then implement and measure complete proof/DA relations, activation witnesses, maximum-work execution and sustained proving before launch. Supply the missing PDF for a document-specific nonce-lock review.
