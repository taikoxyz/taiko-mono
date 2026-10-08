# Phase B — measurement and de-risking: document index

Status: index of record · Date: 2026-10-05 · Authority: [05-phase-b-plan.md](../05-phase-b-plan.md) §1 (workstreams), §2 (measurement discipline), §3 (sequence and gates), §5 (kill criteria)
Base snapshot: `838558419` (plan header) · Decisions in force: D1–D10 ([DECISIONS.md](../DECISIONS.md))

This directory holds the Phase B spike **specifications** (experiment designs, not results), the recovery-repair design pass, and the template every spike fills in. The plan is authoritative; where a document here and the plan disagree, the plan wins. Every spike document states pinned versions, hardware requirements, a fixed workload, pass/fail thresholds, and the falsifiers of the decision it informs. No number in any of them is a measurement yet.

## The five workstreams

| ID | Workstream | Document | Kind | One line: what it unblocks |
|---|---|---|---|---|
| **S1** | Proving throughput and cost | [S1-proving-throughput.md](./S1-proving-throughput.md) | measurement | Measures `b` (bytes per L2 gas), `C` (cycles per L2 gas), proven gas/s per machine and the in-batch blob half; decides whether the L2 is DA-limited or proving-limited and fixes K, fleet sizing and `LIVE-03` (plan §8.3) |
| **S2** | Round timing at the target validator count | [S2-round-timing.md](./S2-round-timing.md) | measurement | Measures round completion at n = 50/100/200 with faults; fixes `TIMEOUT_MIN`/`TIMEOUT_MAX`, `Delta_max`, `X_max`; decides whether D1's 2 s cadence holds at the intended n |
| **S3** | L1 cost per batch, fee flow, reward floor | [S3-l1-cost-and-fee-flow.md](./S3-l1-cost-and-fee-flow.md) | measurement + security interface | Measures `land` gas for both data paths and K ∈ {8, 32, 128}, the blob-price cost curve and gas per storage slot; pins the fee-sweep bridge message and the fee-vault credit check; fixes the `REWARD_QUOTE` floor and `MAX_BATCH_BLOCKS`, and decides whether fee revenue covers landing plus proving (D-8, plan §5) |
| **S4** | Blob binding and independent review | [S4-blob-binding-review.md](./S4-blob-binding-review.md) | measurement + external review | Implements the EIP-4844 evaluation form, the `0x0A` check and the rejection tests, and puts the joint-event argument and transcript in front of an independent cryptographer; decides whether blobs are usable or the data path is calldata-only (D5, plan §8.4) |
| **S5** | Recovery mechanism repair | [S5-recovery-repair.md](./S5-recovery-repair.md) | design pass (not a measurement) | Repairs the round-4 defects (retired heights, completion at L1 finality, locks void above the checkpoint, bond genuinely at risk, per-epoch config registry, generation-scoped uniqueness) so the D-2 review can be re-run; consumes S1–S3 numbers for sizing |

## Gates (plan §3)

| Gate | When | Condition | If it is missed |
|---|---|---|---|
| **G1** | end of week 2 | every harness produces a number at all | the spike design is wrong, not the protocol — fix the harness; do not negotiate the target |
| **G2** | end of week 4 | each spike has a pass/fail with evidence | the missing evidence is escalated with the reason; no pass/fail may be inferred or assumed |
| **G3** | end of week 6 | the parameter table is re-derived from measured inputs, the specification is re-frozen, and the D2 review of the repaired recovery design is scheduled | the unmeasured register stays open with named owners and fallback values; no placeholder is promoted to a value |

## Order to run them in (plan §3)

| Weeks | Work |
|---|---|
| 1–2 | **S3** harness and first gas numbers; **S4** harness; **S2** testbed stood up; **S5** repair design begins |
| 3–4 | **S1** harness reusing the existing EVM guests; **S2** runs at 50/100/200; **S4** internal validation |
| 5–6 | **S1** runs across both backends and batch sizes; **S4** independent review; parameter re-derivation toward G3 |

**Interlocks to respect.**
- **S1 ↔ S3.** S3's cost-coverage pass consumes S1's measured proving cost per batch (`C_prove`); S3's `MAX_BATCH_BLOCKS`/atomicity result constrains S1's publishable K (the measured BPO2 per-transaction blob cap makes K > 21 unpublishable in one transaction at the design's target data budget, with 14 the chosen planning length and 21 the hard edge; target 14 / max 21 / update fraction 11,684,671, S4 F6). Run S3's harness first (weeks 1–2) and feed its atomicity bound to S1 before S1's long runs. *(Re-based from the superseded EIP-7691 "K > 9"; this is a measured chain value, not a design rate, and the design's own data budget is unchanged.)*
- **S1 ↔ S4.** Both measure the blob evaluation: S1 inside the batch guest (its share of batch cycles) and S4 standalone with the convention and rejection tests and the external review. S4 owns the canonical correctness artifact and the review; the two cycle numbers must be produced from the same element interpretation and the same fixture, and any divergence is a finding for both reports, reported rather than averaged.
- **S3 ↔ S5.** S5's retired-height record and bond sizing consume S3's `gas_per_new_storage_slot` and cost floor; S5 must not fix a slot count before that number lands.
- **S4 ↔ D5.** A calldata-only outcome changes the DA ceiling's shape, not only its size (plan §8.4; S4 §2); S3 must restate the calldata cost curve and the data budget if S4 fails.
- **Parallelism.** Phase B and the recovery repair run in parallel; the plan (§0) states that proving cost, throughput, round timing, L1 gas and the blob binding do not depend on the recovery design.

## How to use these documents

1. **Every spike fills [report-template.md](./report-template.md).** The template is mechanical on purpose: run metadata, measured quantities with units and variance, derived parameter values, the comparison against the pre-registered threshold, what was NOT measured, and the raw artifact locations. A report that cannot be filled in mechanically is incomplete.
2. **Number tags are mandatory** (plan §2): every number is `sourced` (source named), `derived` (arithmetic shown), `hypothesis` (pre-registered, tested), or `unmeasured`. No fabricated figure, no transfer of a benchmark between workloads, no placeholder promoted to a value.
3. **Artifacts live under `artifacts/S<id>/`** in each spike document's stated layout, committed with the report; raw files are write-once and the harness is reproducible from a pinned commit.
4. **The parameter table is re-derived, not patched** ([09-parameters.html](../spec/09-parameters.html) PARAM-01/PARAM-03): at G3, each measured input replaces the corresponding unmeasured row by re-running the derivation, with the report cited.
5. **Pass/fail thresholds and any pre-registered constants** (S3's margin `ε`, S4's cost share `σ`) are fixed before the run and recorded with a timestamp; a threshold chosen after seeing the data is not a threshold.

## Status of this directory

| Document | Status | Notes |
|---|---|---|
| [S1-proving-throughput.md](./S1-proving-throughput.md) | spike spec, ready to execute | owns `b`, `C`, `R_gas`, K curve, blob-half share |
| [S2-round-timing.md](./S2-round-timing.md) | spike spec, ready to execute | owns the timeout ladder and the 2 s cadence claim |
| [S3-l1-cost-and-fee-flow.md](./S3-l1-cost-and-fee-flow.md) | spike spec, ready to execute | also owns the security-critical sweep interface and the fee-vault credit check (round 4) |
| [S4-blob-binding-review.md](./S4-blob-binding-review.md) | spike spec, ready to execute | the only workstream whose completion depends on someone outside the team |
| [S5-recovery-repair.md](./S5-recovery-repair.md) | design decided, not yet applied to the specification | blocks the D-2 re-review until applied and reviewed |
| [report-template.md](./report-template.md) | template | one filled copy per spike, committed beside its artifacts |

Round 4 ([iterations/04-round.md](../iterations/04-round.md)) is why these spikes exist: every recovery defect it found needs a Phase B number (plan §0), and its Critical finding on the fee sweep is why S3 carries a rule-level deliverable in addition to a gas measurement.
