# Etna PoS + ZK — research and reference specification

> **Status: in progress.** This directory is the working home of the *Etna PoS + ZK* redesign of
> Taiko: a permissionless L2 proof-of-stake chain whose committed history is settled on Ethereum by
> ZK proofs that always travel **with** their data.
>
> **This is a design project.** Nothing here is implemented, benchmarked or deployed. No number in
> this directory is a measurement unless it is explicitly labelled as one with a source.

## Fixed decisions (constraints, not options)

| ID | Decision |
|----|----------|
| **D1** | Target one L2 block every **2 s** under explicitly stated operating assumptions. Cadence ≠ finality ≠ proof ≠ Ethereum settlement ≠ withdrawal availability. |
| **D2** | **Prefer Mode A** (a legitimately PoS-finalized block is never invalidated; halt safely instead). **Mode B** (permissionless L1 recovery that may discard *unsettled* PoS-certified history) is an authorized *fallback* that may be selected only after an evidenced infeasibility argument for Mode A plus independent review. |
| **D3** | Preserve the existing L1+L2 **SignalService**, **Bridge**, **ERC20Vault**, **ERC721Vault**, **ERC1155Vault** addresses by in-place upgrade. No replacement deployments. |
| **D4** | L2 PoS may determine binding transaction order. The result is honestly named a **PoS-sequenced validity rollup**, not a based rollup. |
| **D5** | **Atomic data-and-proof submission**: batch data and its valid ZK proof land in the **same L1 transaction**. No data-first / proof-later path exists in any mode, including recovery. |
| **D6** | Proving latency of **a few minutes to 30 minutes** is normal. L2 keeps producing 2 s blocks and reaching the selected mode's PoS confirmation throughout. 30 min = **900 L2 blocks**. |
| **D7** | Staking and slashable collateral are denominated in the **existing TAIKO token**. Gas stays ETH. No replacement staking token. |

## Requirements checklist

R1 permissionless roles · R2 DAO = upgrades only · R3 shared addresses preserved · R4 2 s cadence ·
R5 consensus safety + mode confirmation guarantees · R6 conditional liveness · R7 complete proof
statement (RISC Zero + SP1) · R8 public data bound to the proof · R9 D5 atomicity everywhere ·
R10 censorship resistance + forced inclusion · R11 objective misconduct evidence · R12 no L1
lookahead/fixed-slot dependence · R13 implementable specification · R14 learning site consistency.

Live status: see [`01-requirements-and-threat-model.md`](01-requirements-and-threat-model.md) §7
(matrix) and [`spec/index.html`](spec/index.html) (rule index).

## Current verdict

**Pending.** Phase 3 (architecture selection) has not yet been recorded. See
[`DECISIONS.md`](DECISIONS.md) for the ordered decision log and the Mode A/B record.

## Reading order

1. [`00-baseline-and-lessons.md`](00-baseline-and-lessons.md) — what exists today, what the previous
   Etna programme learned, pinned revisions.
2. [`01-requirements-and-threat-model.md`](01-requirements-and-threat-model.md) — vocabulary, status
   labels, assumptions, fault boundary, threat model, acceptance matrix.
3. [`02-consensus-survey.md`](02-consensus-survey.md) — materially different consensus families,
   evaluated for this exact workload.
4. [`03-zkvm-feasibility.md`](03-zkvm-feasibility.md) — RISC Zero and SP1 at pinned versions.
5. [`04-architecture-decision.md`](04-architecture-decision.md) — candidate comparison, the
   A-first decision procedure, final architecture.
6. [`spec/index.html`](spec/index.html) — **the authoritative specification** (normative rules with
   stable identifiers).
7. [`learn/index.html`](learn/index.html) — the progressive learning course.
8. [`iterations/`](iterations/) — frozen review rounds, findings, dispositions.

## Research provenance

| Source | Revision | Date | Use |
|--------|----------|------|-----|
| `taiko-mono` current baseline | `7718753c1` | 2026-10-05 | current contracts, to be migrated |
| `taiko-mono` `etna/converged-spec` | `a829f79723de9a09205660d9895418577cfe9aa9` | 2026-10-05 | prior accepted Etna design and lessons (read-only) |
| External protocols / zkVMs | pinned per artifact | 2026-10-05 | cited inline with retrieval dates |

Every external claim in this directory carries a source link and a retrieval date. Every claim
about this repository carries a pinned file and line reference at revision `7718753c1`.
Numbers are tagged **derived**, **sourced** or **unmeasured**; proposed parameters are never
presented as results.

## Delegation and model policy

See [`DECISIONS.md`](DECISIONS.md) §"Delegation and model policy" for the recorded policy,
actual assignments per phase, and any limitations (including unavailable usage accounting).

## Outstanding blockers

Tracked in [`DECISIONS.md`](DECISIONS.md) and the latest [`iterations/`](iterations/) round.

## Boundaries

No implementation, no deployments, no secrets, no live changes. Edits are confined to
`packages/protocol/docs/Etna/pos-zk/`. Existing accepted Etna documents are preserved and only
read.
