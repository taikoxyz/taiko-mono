# Etna: a fully permissionless based-rollup protocol for Taiko

> **Status: research in progress. This is a design and research artifact, not an implementation.**
> Nothing under this directory changes any deployed contract, client, or existing doc.

Etna is the working name for the successor to Taiko's current (Shasta-era) based-rollup protocol. This directory holds the complete research trail: what the current protocol does, the threat model, the L1 roadmap it depends on, a research sub-project on Frame Transactions as a mutual-exclusion primitive, the design itself, the adversarial red-team rounds it survived (or did not), and a learning site for digesting and challenging it.

## How to read this directory

| If you want to... | Read |
|---|---|
| Understand today's protocol without reading the code | [`00-current-protocol-summary.md`](00-current-protocol-summary.md) |
| See what we are defending against | [`01-threat-model.md`](01-threat-model.md) |
| See which L1 features Etna needs and their status | [`02-l1-roadmap-survey.md`](02-l1-roadmap-survey.md) |
| See whether Frame Transactions give zero-cost losing races | [`03-frame-transactions-research.md`](03-frame-transactions-research.md) |
| Read the full design (engineers, auditors) | [`design/index.html`](design/index.html) |
| Learn the design one block at a time and try to break it | [`learn/index.html`](learn/index.html) |
| See what the red team found and how it was handled | [`iterations/README.md`](iterations/README.md) |
| See the skeptic re-verification reports for the research documents | [`notes/02.verify.md`](notes/02.verify.md), [`notes/03.verify.md`](notes/03.verify.md) |
| See the user-provided input | [`inputs/nonce-as-a-lock.pdf`](inputs/nonce-as-a-lock.pdf) (text extract: [`inputs/nonce-as-a-lock.txt`](inputs/nonce-as-a-lock.txt)) |

## Hard requirements

Every row is a pass/fail gate. The design document states, per row, how it is satisfied; the red team attempts to falsify each claim.

| ID | Requirement | Acceptance criterion |
|----|-------------|----------------------|
| R1 | **100% permissionless.** No central authority and no whitelist of any kind. The DAO is the sole owner and governs only upgradeability. The DAO must have no role in day-to-day operation or liveness. | Every role in the design can be entered and exited by any address by satisfying on-chain, objective conditions (bonding, registration, auctions, etc.). No function in the design is gated by an admin, operator, or allowlist. The chain stays live if the DAO never acts again. |
| R2 | **Reuse the existing SignalService, Bridge and Vault design** on both L1 and L2. These contracts may be upgraded to add functionality, but **no new Bridge, SignalService, or ERC20/ERC721/ERC1155 Vault addresses will be deployed.** | The design specifies the exact interface the new L1 inbox and L2 anchor expose to `SignalService` (checkpoints / state roots), and lists every change (if any) required in `packages/protocol/contracts/shared/{signal,bridge,vault}`, each as a storage-layout-compatible upgrade. |
| R3 | **Richer role set.** The protocol may define more roles than today's proposer (a.k.a. preconfer) and prover, if doing so improves security or liveness. | Every role has: entry and exit conditions, duties, rewards, slashing conditions, and a stated answer to "what happens if every holder of this role goes offline or turns malicious". |
| R4 | **1-second L2 block time.** | The design targets an L2 block cadence of at most 1 second (preconfirmed blocks), with the L1 landing cadence fully decoupled from it. State explicitly what "block time" means (preconf issuance interval) and what latency users see for soft confirmation. |
| R5 | **No dependence on Ethereum's consensus-layer lookahead, and no coupling to L1 slot time.** Ethereum's CL will change substantially; L1 slot time is 12 s today and will shrink. | Role assignment, liveness, and timing rules never consume a validator/proposer lookahead schedule. The design **may** consume CL data that is verifiable on L1 via beacon block roots (EIP-4788) or similar merkle commitments, e.g. for randomness or for proving L1 facts. All protocol timing parameters are expressed in seconds or L1 block numbers, never in slots or epochs, and the design must still work if L1 slot time becomes 6 s, 4 s, or 2 s. |
| R6 | **Penalize and slash.** The protocol must be able to punish any participating party to preserve liveness and to deter malicious behavior and monopolization. | Every slashing condition is objectively verifiable on L1 by anyone (permissionless challenger), specifies the evidence format, who submits it, who receives what share of the slashed amount, and how false accusations are deterred. Anti-monopoly mechanisms are concrete (e.g. rotation, caps, auctions, decay) and their economic parameters are tabulated with rationale. |
| R7 | **Propose-with-proof.** ZK proving of a segment of blocks currently takes minutes. The design must let L2 blocks land on L1 **together with a valid ZK proof in one action**, with minute-level latency, instead of today's separate propose and prove steps. | The design has a single L1 transaction type (or frame) that carries both batch data and proof, and explains: how preconfirmed blocks bridge the minutes-long proving window, what happens if a prover fails mid-window, how forced inclusion / censorship resistance still works, and how L1 finality is defined. Data availability (blobs vs. calldata) must be explicit. |

### Baseline assumptions (from the brief)

- **Frame Transactions** (EIP-8141) **will be live on L1 before Etna launches.** The design uses them, and marks which parts degrade gracefully if they slip.
- The L1 feature horizon is **Glamsterdam plus Hegota**. See `02-l1-roadmap-survey.md`.
- Bond and reward denomination, L2 native token, and gas accounting follow today's Taiko unless a change is justified in the design.

### Working assumptions made by the architect (in place of clarifying questions)

The brief was executed autonomously. Where a clarifying question would normally have been asked, the following assumptions were made. Each is revisited in the final report; reversing any of them is a bounded change to the design.

| # | Question I would have asked | Assumption taken |
|---|---|---|
| A1 | Directory casing: the brief says `docs/etna/` in Phase 0 and `docs/Etna/` in Section 7. | `packages/protocol/docs/Etna/` (Section 7 is the deliverable layout). |
| A2 | Does "no whitelist of any kind" (R1) also forbid a **verifier-key registry** for ZK proof systems (the set of accepted verifying keys / program image IDs)? | Yes for operation, no for upgradeability: the accepted proof-system set is part of the protocol code and can only change by DAO upgrade, never by an operational allowlist. Etna treats the ZK verifier set as "code", not as a "role". |
| A3 | Is SGX / TEE still an acceptable proof tier, given R7 says "valid **ZK** proof"? | ZK is the finality proof. TEE proofs are permitted only as an optional **fast-lane attestation** that never substitutes for ZK at finality. The design must remain sound with TEEs removed entirely. |
| A4 | Should the design retain a **contestation / fraud-proof window** at all? | No fraud-proof window for finality (R7 makes finality = valid ZK proof accepted on L1). Contestation survives only as a *slashing* mechanism for preconf misbehavior, never as a gate on state finality. |
| A5 | May the design introduce a **new L1 contract** besides the inbox (e.g. a role registry, a slashing module, a gate contract)? R2 freezes only Bridge, SignalService and Vaults. | Yes. New non-frozen contracts are allowed; the frozen three are reused at their existing addresses. |
| A6 | Bond token: TAIKO on L2 (today's `BondManager` in Anchor) vs. ETH on L1? | Kept as today (TAIKO-denominated bonds via the existing bond design) unless the design justifies otherwise; the design section on economics states where ETH is used and why. |
| A7 | Is the target for R4's "1-second block time" a hard protocol rule or a client-level cadence? | A protocol-level 1-second issuance cadence that is a *rewarded duty* whose hard bound is the committee timeout (5 s): silence is deliberately never slashed because a colluding committee could manufacture it, so the enforcement is loss of rewards, replacement within one timeout, and the strike ladder (revised during Phase 3; see the design's certificate page and limitation L16). |
| A8 | How many red-team models are available? | The environment offers `opus`, `sonnet`, `haiku`, `fable`. Each round uses at least three distinct models; the iteration log records which. |

## Phase checklist

Updated as each phase completes. A phase is checked only once its artifact is committed.

- [x] **Phase 0: Setup.** Branch `claude/beautiful-maxwell-8pyecj`, directory `packages/protocol/docs/Etna/`, this README, PDF input copied to `inputs/`.
- [x] **Phase 1: Learn.** `00-current-protocol-summary.md`, `01-threat-model.md` (verified by independent sub-agents; reports and gap fills in `notes/`).
- [x] **Phase 2: Research.** `02-l1-roadmap-survey.md`, `03-frame-transactions-research.md` (each independently re-verified by a skeptic agent; reports in `notes/`).
- [x] **Phase 3: Design draft.** `design/index.html` and fourteen section pages (three independent designs per building block, judged and synthesized, then a cross-block consistency pass; the architect's decisions are listed on the overview page).
- [ ] **Phase 4: Red team round 1.** `iterations/01-round.md` (three or more adversarial agents on different models, plus a judge).
- [ ] **Phase 5: Revise and loop.** One `iterations/NN-round.md` per round; loop until converged, negative verdict, or the 8-round cap.
- [ ] **Phase 6: Deliverables.** Design site, learning site, commit, push, draft PR.
- [ ] **Phase 7: Report.** Final message: verdict, top-five decisions, open questions, links.

## Convergence status

| Round | Models | New Critical | New High | Open Medium | Verdict |
|---|---|---|---|---|---|
| (none yet) | | | | | |

**Design readiness: NOT READY.** The design is declared ready only if two consecutive red-team rounds produce no new Critical or High findings, every Medium is mitigated or accepted with written rationale, and all of R1 to R7 pass.

## Rules this work followed

1. No implementation: no production code, contracts, or client changes. Interface sketches live only inside the design document.
2. Throwaway experiments only in the session scratchpad, never committed.
3. Nothing outside `packages/protocol/docs/Etna/` is modified.
4. No deployments, no keys, no private resources. The Notion page referenced by the original brief was not accessible; the PDF in `inputs/` is used instead.
5. External facts (EIP numbers, fork contents, status) are verified via the web at run time and cited in `02-l1-roadmap-survey.md`.
6. Every claim in the design is marked **proven** (with argument), **assumed** (with the assumption named), or **open** (with what would resolve it).
7. Repository `CLAUDE.md` conventions are followed for commits and the PR. The PR is opened as a draft.

## Things deliberately ignored

- **URC (Universal Registry Contract)** and all lookahead-related code (for example `packages/taiko-client-rs/crates/bindings/src/lookahead_store.rs`, `packages/taiko-client/driver/preconf_blocks/lookahead.go`). Noted only as "removed in Etna".
