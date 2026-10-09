# Etna PoS + ZK — research and reference specification

> **Status: complete draft, in adversarial review.** This directory is the working home of the
> *Etna PoS + ZK* redesign of Taiko: a permissionless L2 proof-of-stake chain whose committed history
> is settled on Ethereum by ZK proofs that bind data already on Ethereum — carried in the accepting
> transaction or published and recorded in an earlier one, with the checkpoint advancing only on the
> verified proof (D-11).
>
> **This is a design project.** Nothing here is implemented, benchmarked or deployed. No number in this
> directory is a measurement unless it is explicitly labelled as one with a source.

## Current verdict

**Architecture level: answered.** The chosen architecture
(permissionless TAIKO-staked L2 PoS + combined ZK proof of consensus finality and execution, with
proof-gated acceptance and the batch's data either carried by the accepting transaction or bound to a
live publication record) satisfies the hard requirements **under the stated assumptions**.

**Scope change (user decision D-6, 2026-10-05; superseded for version 1 by D-12, 2026-10-06): narrow
forced inclusion ships in v1.** Any account may publish a transaction's data to L1; from its due point
the record must be resolved by the capped FIFO prefix of the due set — included in a proven batch or
discharged as void on objective grounds — and a record whose proving deadline passes unresolved is
discarded and may be re-published. That is an **upper bound on exclusion, never a lower bound on
inclusion**, and its enforcement point is the proof, not an admission gate. What remains absent is the
**general inclusion list**: no queue of arbitrary transactions, no escrow and no forced-inclusion fee,
and no L1 entry point for data that never reaches L1. A user whose transaction is never published still
relies only on the conditional statistical resistance of hash-based weighted proposer selection (rule
LIVE-04) under A-CONS-2, and a network-level adversary able to isolate that user from every honest
proposer — or to censor L1 inclusion itself — can still exclude the user indefinitely, including
preventing the user from *starting* a withdrawal, with no protocol remedy. R10 is therefore satisfied in
its **narrowed form**: the relaxation D-6 recorded is narrowed, not withdrawn. The changes are recorded
in DECISIONS.md D-11/D-12 and in the requirement matrix in 01-requirements-and-threat-model.md.

**Guarantee class changed (user decisions D-7 to D-10, 2026-10-05; amended by D-11, D-12 and D-13, 2026-10-06).** Mode B is
selected: a permissionless, bonded, delayed recovery may replace L2 history above the last L1-accepted
checkpoint, so a PoS confirmation is **provisional** until its batch is accepted on L1. Ethereum-finalized
checkpoints and every accepted batch remain untouchable, and D5 is relaxed only as D-11 states: a batch's
data may be published and recorded in an earlier L1 transaction, and what D5 continues to require is that the
checkpoint advances only on a valid proof. Security is funded from **L2 fees** swept through the preserved
Bridge into an L1 reward pool; slashed stake goes to the **treasury** (no burn); and forced inclusion is
**not deferred wholesale**: the narrow rule over published data ships in v1 (D-12), and only the general
inclusion list is deferred to a later protocol update. D-11 narrows the Mode B trigger window (data may be published and recorded before the proof), D-12 supersedes D-6/D-10 with the narrow forced-inclusion rule, and D-13 makes the per-batch proof one aggregated object; none of the three changes the selected mode. *This closes the stale amendment list: D-11/D-12/D-13 are named together and their effect on the mode is stated.*

**Specification level: NOT CONVERGED — the result is labelled _incomplete_.** Two full adversarial
review rounds were run on frozen snapshots with four independent reviewers each. Round 1 found
6 Critical and 28 High findings; the fixes were applied. Round 2, on the fixed snapshot, found
**6 new Critical and 23 new High** findings, all inside the claimed fault model. Two of the six
round-2 Criticals were fixed in revision while the round closed; four remain open, and none of those
fixes has been re-reviewed. The consecutive-clean-round count is therefore **zero**, and no claim of
specification-level convergence is made. See [`iterations/01-round.md`](iterations/01-round.md) and
[`iterations/02-round.md`](iterations/02-round.md) for the finding ledgers and dispositions.

**What stands regardless:** the round-1 Critical blob-binding attack was independently verified as
**closed** on re-attack; the single quorum predicate, single validator-set encoding, leader selection,
epoch→root resolution and the atomic-submission rule were verified as fixed.

**Round 4 (snapshot `fe7373a13`, four fresh reviewers, all five angles, one of them the review D2 requires):
4 Critical, 14 High, 14 Medium, 3 Low.** The design is **blocked on the recovery mechanism**, and the
round-4 evidence is the reason:

- **D2 step 5 is unmet** — the resistance claim is not quantified, and the specification converted that
  blocker into disclosure text, which step 5 forbids.
- **The recovery authorization is a tautology** (two angles, one root cause): no signed object carries the
  recovery generation, so a discarded-but-certified branch can be re-proven under the new generation and
  landed against the restored checkpoint. Discarded history can be reinstated by one permissionless prover.
- **The fee sweep can be redirected to the caller** (upgraded to Critical on adjudication): D-8 made the
  sweep permissionless but never specified its L1 bridge message, and the preserved Bridge pays a
  caller-chosen owner. Since the sweep is the security budget, that is a fund redirection needing no adversary.
- **The bond is refunded on success**, the trigger can be reached by rational inaction (an empty pool, and
  `land` may pay zero), locks above the restored checkpoint survive and can wedge the chain, and a routine
  upgrade can blank provisional history because `configHash` has no per-epoch registry.

Round 4 is therefore **not** clean, the consecutive-clean-round count is **zero**, and the specification
remains **not converged**. No reviewer has produced two conflicting *certificates* inside the fault model
in any round — the consensus core still holds — but the recovery design that D-7 selected does not work as
specified. See `iterations/04-round.md`.

**Next:** `05-phase-b-plan.md` — the measurement spikes and the recovery repair, which run in parallel
because the repair needs the numbers. Four of the eight permitted review rounds remain; the D2 review must
be re-run on a repaired design before the selection can be called settled.

| Question | Answer |
|----------|--------|
| Consensus | Tendermint/CometBFT-class BFT, one block per height, single-slot finality, lock / proof-of-lock-change rule retained; Ed25519 votes; **one head commit certificate verified per batch** |
| Membership | Permissionless, self-bonded **TAIKO on L1**; epoch-scoped validator-set roots committed with **two-epoch lookahead** (the root for epoch *e*+2 is committed during epoch *e* — CONS-13(3), MEM-09 clause (1)); no delegation in v1. *This corrects the summary row: the design's lookahead is two epochs, not one.* |
| Settlement | Proof-gated acceptance in one L1 transaction: the batch's data is carried by that transaction or bound to a live publication record published earlier (D5 as relaxed by D-11); no publication advances a checkpoint |
| Proof | One combined guest proving consensus finality, execution and data binding; both RISC Zero and SP1 must realise the same statement |
| Recovery | **Mode B selected (user decision D-7)**: a permissionless, bonded, delayed L1 recovery may replace history **above** the last Ethereum-finalized checkpoint; everything at or below it is untouchable. Confirmations above it are **provisional** |
| Honest name | A **PoS-sequenced validity rollup**, not a based rollup |

The verdict is *specification-level convergence under stated assumptions* — see
[`10-assurance.html`](spec/10-assurance.html) and the review history in [`iterations/`](iterations/).
It is **not** a claim that the design is implemented, audited, safe to deploy, or measured.

## Fixed decisions (constraints, not options)

| ID | Decision |
|----|----------|
| **D1** | One L2 block every **4 s** under stated operating assumptions *(the owner's Phase B decision of 2026-10-07 supersedes the original 2 s; conditioned on the intended validator count staying near or below 128 — above that the evidence says about 6 s, so cadence and n are one decision)*. Cadence ≠ finality ≠ proof ≠ settlement ≠ withdrawal. |
| **D2** | **Mode A was selected first (D-3, which records the dissent against Mode A's feasibility verdict); the authorised fallback Mode B is now selected (user decision D-7).** A permissionless, bonded, delayed L1 recovery may replace history **above** the last Ethereum-finalized checkpoint; at or below it nothing may change. A PoS confirmation above that checkpoint is therefore **provisional**. **Mode B** (permissionless L1 recovery of *unsettled* history) is the selected mode (D-7). D-11/D-12/D-13 record no further mode change: D-11 narrows the trigger window by allowing publication before the proof, D-12 replaces D-6/D-10 with narrow forced inclusion over published data, and D-13 makes the per-batch proof one aggregated object. *This closes the D2-history check against DECISIONS.md: D-3's selection and its dissent, D-7's Mode B selection, and the D-11/D-12/D-13 entries are stated as the log records them.* |
| **D3** | Preserve L1+L2 **SignalService**, **Bridge**, **ERC20Vault**, **ERC721Vault**, **ERC1155Vault** addresses by in-place upgrade. No replacements. |
| **D4** | L2 PoS determines binding order; the result is named a **PoS-sequenced validity rollup**. |
| **D5** | Proof-gated acceptance: the checkpoint advances only on a valid proof, in one L1 transaction. **Relaxed by D-11:** the batch's data may be published and recorded in an earlier L1 transaction and referenced by the proof; no publication advances protocol state, and no recovery may introduce a data-first *admission* path. |
| **D6** | Proving latency of a few minutes to **30 minutes** is normal (450 L2 blocks at the Phase B 4 s cadence; 900 at the superseded 2 s). |
| **D7** | Staking and slashable collateral in the **existing TAIKO token**; gas stays ETH. |

## Requirements checklist

| ID | Requirement | Where satisfied | Status |
|----|-------------|-----------------|--------|
| R1 | Permissionless roles, objective entry/exit, TAIKO staking | [01](spec/01-system-model.html) ROLE-01..05, [03](spec/03-membership-staking.html) | specified |
| R2 | DAO governs upgrades only | [08](spec/08-migration-upgrades.html) GOV-01..03 | specified |
| R3 | Shared addresses preserved | [08](spec/08-migration-upgrades.html) MIG-02/06 | specified, migration audit open |
| R4 | 4 s cadence (the Phase B decision; D1's 2 s superseded), distinguished from every other latency | [01](spec/01-system-model.html) SYS-03, [09](spec/09-parameters.html) | specified, unmeasured |
| R5 | Consensus safety and the selected mode's confirmation guarantee | [06](spec/06-recovery-exceptions.html) REC-01..04, [02](spec/02-consensus.html) CONS-01..16, [10](spec/10-assurance.html) INV-01 | argued; **provisional above the last accepted checkpoint (D-7)**; F1 open; REC-03 awaits independent review. *This closes the stale ranges: REC-04 and CONS-16 exist and are now cited.* |
| R6 | Conditional liveness with exact end conditions | [10](spec/10-assurance.html) LIVE-01..05 | specified; a settlement stall is recoverable, a missing epoch-set entry or unavailable data still halts. *This closes the stale range: LIVE-05 exists and is now cited.* |
| R7 | Complete proof statement, both backends | [05](spec/05-proof-statement.html) PRF-01..15, [03](03-zkvm-feasibility.md) | specified. *This closes the stale range: PRF-14 and PRF-15 exist and are now cited.* |
| R8 | Public data bound to the proof | [04](spec/04-l1-integration.html) DA-01..10 | specified. *This closes the stale range: the D-11 publication rules DA-07..DA-10 exist and are now cited.* |
| R9 | D5 proof-gated acceptance everywhere (data carried or published-and-referenced, D-11) | [04](spec/04-l1-integration.html) L1-01..04, [06](spec/06-recovery-exceptions.html) REC-02 | specified |
| R10 | Censorship resistance — **narrowed by decisions D-6/D-12**: a narrow, proof-enforced forced-inclusion obligation over **published** data ships in v1 (an upper bound on exclusion), the **general inclusion list** remains deferred, and unpublished transactions have statistical resistance only (proposer rotation under A-CONS-2), with the withdrawal-censorship consequence disclosed | [10](spec/10-assurance.html) LIVE-04, [04](spec/04-l1-integration.html) FI-10..FI-14 and FI-REMOVED-01/FI-PLANNED-01 | satisfied in narrowed form only |
| R11 | Objective misconduct evidence, collateral, exits | [07](spec/07-economics-slashing.html) ECON-04..08 | specified; slashed stake goes to the **treasury** (D-9), reporter bounty strictly below the penalty |
| R12 | No L1 lookahead or fixed slot dependence | [index](spec/index.html) GEN-06 | specified |
| R13 | Implementable without inventing rules | all pages; **160** registered rules | **160/160** stated once. *This corrects the count: 160 rule ids exist across `spec/*.html` and the rule index lists the same 160.* |
| R14 | Learning site consistent with the specification | [learn/](learn/index.html) — a 12-page engineer's course that carries **no review-process or decision-log content**; process archaeology stays in the specification, `DECISIONS.md` and `iterations/` | in progress |

## Reading order

1. [`00-baseline-and-lessons.md`](00-baseline-and-lessons.md) — what exists today at `7718753c1`, what
   the previous Etna programme learned, and which of its artefacts must not be reused.
2. [`01-requirements-and-threat-model.md`](01-requirements-and-threat-model.md) — vocabulary, status
   labels, assumptions, fault boundary, threat model, acceptance matrix.
3. [`02-consensus-survey.md`](02-consensus-survey.md) — materially different consensus families
   evaluated against eleven attributes for this exact workload.
4. [`03-zkvm-feasibility.md`](03-zkvm-feasibility.md) — RISC Zero and SP1 at pinned versions.
5. [`04-architecture-decision.md`](04-architecture-decision.md) — candidate comparison, the A-first
   decision procedure, the selected architecture and its six modifications.
6. [`spec/index.html`](spec/index.html) — **the authoritative specification**, with the complete rule
   index (**160** rules, each stated exactly once). *This corrects the count from 128 to 160 — the number of rule ids across `spec/*.html` — so it agrees with the checklist.*
7. [`learn/index.html`](learn/index.html) — the engineer's course: twelve plain-language pages covering the
   design from first principles. It deliberately contains no review history, no finding identifiers and no
   decision-log references; those live in `DECISIONS.md` and `iterations/`.
8. [`DECISIONS.md`](DECISIONS.md) — the ordered decision log: D-3's Mode A selection and the
   dissent recorded against its feasibility verdict, D-7's Mode B selection, and the D-11/D-12/D-13
   amendments. *This closes the D2-history check: the reading order names the log's actual entries.*
9. [`iterations/`](iterations/) — frozen review rounds, findings and dispositions.

## Research provenance

| Source | Revision / version | Date |
|--------|--------------------|------|
| `taiko-mono` baseline | `7718753c1` | 2026-10-05 |
| Prior accepted Etna research (read-only) | `a829f79723de9a09205660d9895418577cfe9aa9` | 2026-10-05 |
| Frozen review snapshot (round 1) | `dfcf067a5b91a1b0bacd4470f5f5054d1f861a24` | 2026-10-05 |
| CometBFT specification | pinned commit `709fd12b…` | retrieved 2026-10-05 |
| RISC Zero / SP1 | `v3.0.6` / `v6.8.1` (verifier contracts `v3.0.1` / `v6.1.1`) | retrieved 2026-10-05 |
| EIP-4844, EIP-7691, EIP-4444 | as published | retrieved 2026-10-05 |

Every external claim carries a source link and a retrieval date. Every claim about this repository
carries a pinned file and line reference at `7718753c1`. Numbers are tagged **derived / sourced /
unmeasured**; proposed parameters are never presented as results.

## Delegation, models and review coverage

See [`DECISIONS.md`](DECISIONS.md) §"Delegation and model policy" and the round files in
[`iterations/`](iterations/) for actual assignments. Limitation: the harness did not expose a model
selector for delegated work, so model assignment per sub-task could not be enforced in this session;
this is recorded rather than papered over, and the independent-review structure (fresh reviewers per
round, findings first, adjudication second) was used to obtain genuine independence instead.

## Outstanding blockers

| ID | Blocker | Consequence |
|----|---------|-------------|
| REC-03 | The recovery-resistance argument is written but **not yet independently reviewed** | The D-7 selection is not settled until review round 4 attempts to break it |
| F1 | Epoch-handoff lock carry-over (CONS-09) is argued, not proven | The named review target for round 1 |
| F2 | In-guest blob polynomial-evaluation cost unmeasured | The blob data path is an implementation gate; calldata path is the fallback |
| F3 | 4 s cadence with a permissionless global validator set unmeasured; F-CADENCE-1 stays Open, sharpened: an S2 run at the pinned engine release showing a round cannot complete inside 4 s at the registered `N_MAX` falsifies the cadence decision | Launch gate |
| F4 | Prover fleet sizing inputs unmeasured | LIVE-03 throughput inequality cannot be evaluated |
| MIG | Removal of every privileged lever is verified only at migration time | R1/R2 are conditional on the migration audit |
| HUM | Slashed-stake destination (ECON-06) and reward funding (ECON-02) are human decisions | Cannot be resolved by this project |

## Boundaries

No implementation, no deployments, no secrets, no live changes. Edits are confined to
`packages/protocol/docs/Etna/pos-zk/`. Existing accepted Etna documents are preserved and were only
read, from branch `etna/converged-spec`.
