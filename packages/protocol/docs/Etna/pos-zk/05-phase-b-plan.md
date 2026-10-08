# Phase B plan — measurement and de-risking

Status: ready to start · Owner: protocol lead · Date: 2026-10-05
Base snapshot: `838558419` · Decisions in force: D1–D10 (see `DECISIONS.md`)

## 0. Can Phase B start? Yes — with one adjustment

**Answered already (Phase A).** Mode B selected (D-7); security funded from L2 fees (D-8); penalties to
the treasury (D-9); forced inclusion deferred to a later update (D-10). Those were the decisions Phase B
was waiting for.

**Still open, and it does not block Phase B.** Round 4 showed the recovery mechanism is broken as
specified (the recovery authorization is a tautology; the bond is refunded on success; the trigger can be
reached with no adversary). Those are design defects, not measurements, and every one of them needs a
number that Phase B produces. So Phase B and the recovery repair run **in parallel**, and the recovery
repair consumes Phase B's outputs:

| Recovery defect | Phase B output that fixes it |
|---|---|
| Bond refunded in full on success, nothing at risk | S3 gives the cost to land a batch, and S1 the cost to prove one — the size of what a rollback can destroy follows from the value at stake per block |
| Trigger reachable by rational inaction (empty pool, `rewardPaid = 0`) | S1 + S3 give the true cost floor, which sets the minimum reward and therefore the pool size needed |
| No completion depth, no cancellation window | S2 gives real inclusion and finality latencies in L2 blocks, which is what the window must be expressed in |
| On-chain budget for recovery state is unbudgeted | S3 measures gas per storage slot written on the acceptance path |

**What Phase B does NOT depend on.** Proving cost and throughput, round timing, L1 gas, and the blob
binding are all independent of the recovery mechanism. None of them changes if the recovery design does.

## 1. The five workstreams

S1–S4 are measurements; S5 is the design pass that runs alongside them.

### S1 — Proving throughput and cost (the highest-value spike)

**Question.** For a representative L2 block workload, what are (a) cycles per unit of L2 gas, (b) seconds
and cost per proof of a K-block batch, (c) proven gas per second per machine, and (d) the in-guest cost
of the blob polynomial evaluation?

**Harness.** Do **not** build the production guest. Use an existing type-1 EVM guest implementation for
each backend at the pinned versions (RISC Zero `v3.0.6`, SP1 `v6.8.1`), wrapped in a small program that
adds the consensus half (Ed25519 batch verification over N signatures with distinct messages, plus a
Keccak header-chain walk) and the blob half (Lagrange evaluation over 4,096 field elements). This is a
measurement artifact, not a protocol implementation.

**Method.** Fix the workload first: block gas limit, transaction mix, state size, batch size K = 8, 32,
128. Report cycles, wall-clock, GPU model and count, memory, variance across runs, and the raw artifacts.

**Pass/fail.** Pass if sustained proven gas/s ≥ the L2 target gas/s with an affordable fleet, and if the
blob evaluation is a small fraction of the batch cost. Fail → the operating envelope changes (see §5).

**Deliverable.** A measurement report with the numbers, the harness pinned by commit, and the formula
inputs for `LIVE-03`.

### S2 — Round timing at the target validator count

**Question.** Can one round complete inside 2 s with 50 / 100 / 200 validators spread across regions, and
what timeout ladder is required?

**Harness.** A stock consensus engine (CometBFT-class) with the intended timeout ladder and vote sizes;
the vote-format change is irrelevant to timing, so do not build it. Fault injection: slow validators,
partitions, leader failure.

**Metrics.** Round completion distribution (p50/p95/p99), view-change rate, bandwidth per validator,
messages per round, and the largest n at which the 2 s target holds with the assumed delay bound.

**Pass/fail.** Pass at the intended n with the declared delay bound. Fail → n, cadence, or the timeout
policy must change, and a cadence change is a user decision (D1).

### S3 — L1 cost per batch, fee flow, and the reward floor

**Question.** What does one `land(data, proof)` transaction cost with real blob counts and each
backend's verifier, how much of it is storage growth, and what is the minimum reward that keeps a
permissionless prover landing batches?

**Harness.** Forge implementation of the acceptance path: both data paths, verifier routes, checkpoint
record, recovery generation. Run gas snapshots and a storage-growth analysis against the Inbox slot
budget.

**Metrics.** Gas per batch by data path and batch size; gas per new storage slot; blob vs calldata cost
curve; the derived reward floor per batch; the fee-sweep volume needed to cover it.

**Pass/fail.** Pass if the fee revenue at the target throughput covers landing plus proving with a
positive margin. Fail → the throughput target or the reward policy must change, and an underpriced
landing market keeps the recovery trigger reachable by inaction.

### S4 — Blob binding implementation and cryptographic review

**Question.** Does the whole-blob commitment, on-chain challenge, KZG-opening and in-guest evaluation
construction work end to end, and does it survive review?

**Harness.** A standalone guest that evaluates the interpolating polynomial of the executed blob at a
challenge point, plus the on-chain point-evaluation check (50,000 gas, EIP-4844), plus a test that a
mismatched payload is rejected. Then an **independent cryptographic review** of the fixed-point argument,
the Fiat–Shamir transcript and the EIP-4844 evaluation-form convention.

**Pass/fail.** Sound → blobs are a usable path. Unsound or unreviewable → calldata-only, which still
satisfies D5; state the throughput consequence explicitly.

PLACE_ADD
### S5 — Recovery mechanism repair (design, parallel)

Not a measurement, but it must land before the D2 review can be re-run: bind the generation to the
signed history; define completion as an L1 event with a depth; void locks above the restored checkpoint;
make the bond genuinely at risk; add a per-epoch configuration registry; restate CONS-12/INV-01 as
generation-scoped. Each of these consumes S1–S3 numbers for sizing.

## 2. Measurement discipline (non-negotiable)

1. Every number carries: value, units, pinned version, hardware, workload, method, date, variance.
2. No benchmark transfers between workloads; if a published figure is cited, say whether it transfers.
3. Raw artifacts are committed with the report; the harness is reproducible from a pinned commit.
4. Results land in the specification's register, and the parameter table is **re-derived** from them, not
   patched.
5. Anything not measured stays labelled `unmeasured`.

## 3. Sequence and gates

| Week | Work |
|------|------|
| 1–2 | S3 harness and first gas numbers; S4 harness; S2 testbed stood up; S5 repair design begins |
| 3–4 | S1 harness reusing existing EVM guests; S2 runs at 50/100/200; S4 internal validation |
| 5–6 | S1 runs across both backends and batch sizes; S4 independent review; parameter re-derivation |

**G1 (end of week 2):** every harness produces a number at all — if not, the spike design is wrong, not
the protocol. **G2 (end of week 4):** each spike has a pass/fail with evidence. **G3 (end of week 6):**
the parameter table is re-derived from measured inputs, the specification is re-frozen, and the D2 review
of the repaired recovery design is scheduled.

## 4. What each result changes in the specification

| Measurement | Spec consequence |
|---|---|
| Cycles per L2 gas, proven gas/s | `BATCH_BLOCKS` K, pipeline depth, `D_MAX`, `T_STALL`, fleet sizing, `LIVE-03` |
| In-guest blob evaluation cost | blob path usable or calldata-only; per-block data budget |
| Round completion times | `TIMEOUT_MIN`/`TIMEOUT_MAX`, cadence feasibility under D1 |
| L1 gas per batch and per slot | reward floor, fee-sweep volume, recovery state budget, bond sizing |
| Blob binding review | D5 data path choice; the residual disclosure if blobs are dropped |

## 5. Kill criteria and contingencies

- **Proving cannot sustain the target gas rate.** Reduce the L2 gas target, raise K, or accept a longer
  envelope — but `LIVE-03`'s inequality must hold, and the cap `D_MAX` must follow from it.
- **Rounds cannot complete in 2 s at the intended n.** Reduce n, tighten the timeout ladder, or change
  cadence — cadence is a user decision (D1), so escalate rather than assume.
- **Blob binding fails review.** Calldata-only. D5 still holds; throughput becomes calldata-bound and the
  data budget must be restated.
- **The reward floor cannot be met by fee revenue.** The security budget is unfunded; that is a product
  decision (raise fees, cap throughput, or fund from treasury), not a parameter tweak.
- **The recovery bond cannot be made genuinely at risk.** Mode B stays blocked; the fallback is Mode A
  with its unbounded halt, or a different escape design. Do not ship a rollback nobody pays for.

## 6. Team and effort (estimates, not measurements)

Two engineers for S1 and S2, one for S3, one for S4 plus an external cryptographer, and the protocol lead
for S5. Six weeks to G3 with the spikes running in parallel; S4 is the only workstream whose completion
depends on someone outside the team.

## 7. Definition of done for Phase B

1. Four measurement reports exist, each with versions, hardware, workload, method and raw artifacts.
2. Every entry in the specification's unmeasured register is either measured or explicitly bounded with a
   named owner and a fallback value.
3. The parameter table is re-derived; no parameter is a placeholder.
4. The recovery design is repaired and has survived a fresh D2 review, or is explicitly abandoned.
5. The specification is re-frozen, and the next review round starts from a clean snapshot.

---

## 8. The S1 target, as decided by the user (2026-10-05)

**Decision: the L2 gas-throughput target is the rate at which L2 exactly consumes the L1 data-availability
capacity available to it.** In other words the target is *derived from L1's settlement and DA ceiling*,
not chosen as a round number. That is the right shape for a validity rollup whose binding constraint is
data, and it makes S1's pass/fail decidable.

### 8.1 The formula

```
G_L2_TARGET  =  DA_bytes_per_l1_block x blobs_per_block_target / L1_slot_seconds / b

where
  b            = compressed batch bytes per unit of L2 gas        (MEASURED by S1/S3, workload-dependent)
  blobs_per_block_target, bytes per blob, L1 slot seconds        (SOURCED, re-derived when Ethereum changes)
```

Equivalently, per 2-second L2 block: `block_data_budget = DA_bytes_per_second x 2` and
`G_L2_per_block = block_data_budget / b`.

### 8.2 What is sourced, derived and still unknown

| Quantity | Value | Tag |
|---|---|---|
| Bytes per blob | 131,072 | sourced (EIP-4844) |
| Blobs per L1 block (target / maximum) | 14 / 21 | sourced (EIP-7892 BPO2 set in force over the measured window; base-fee update fraction 11,684,671 — Phase B S4 public-data report §3 F6) |
| L1 slot duration | 12 s | sourced, re-derived if Ethereum changes it |
| DA bytes per L1 block (target) | 786,432 | derived |
| DA throughput (target / maximum) | 65,536 / 98,304 bytes per second | derived |
| Data budget per 2 s L2 block (target) | 131,072 bytes (one blob) | derived |
| **`b`, bytes per L2 gas** | **unknown** | **unmeasured — this is S1's headline output** |

*(Design assumption, unchanged: the derived rows above — 786,432 B per L1 block, 65,536 / 98,304 B/s and the 131,072 B per-2 s-block budget — are the plan's own 2026-10-05 baseline at the then-current 6-blob target, not the chain's in-force set. Phase B S4 public-data report §3 F6 measures the in-force set at target 14 / max 21 / base-fee update fraction 11,684,671. This propagation keeps the design rows as written.)*

Illustrative only, to show the sensitivity: at `b = 0.006` bytes/gas the target is ≈ 11 Mgas/s; at
`b = 0.02` (calldata-heavy, poorly compressible workload) it is ≈ 3.3 Mgas/s. These are arithmetic on an
invented `b` and must not be quoted as results — the point is that `b` moves the answer by 3–5x, which is
exactly why S1 measures it rather than assuming it.

### 8.3 The second bound, and the rule when they disagree

The DA ceiling is not automatically achievable: the prover must also keep up. So

```
G_L2_TARGET = min( DA-bound rate , proving-bound rate )
```

**Pass:** proving-bound ≥ DA-bound with an affordable fleet, at which point the L2 is DA-limited and the
target above stands. **Fail:** the L2 is proving-limited. Then the operating envelope is set by the
prover, and the choice is explicit and belongs to the user: buy a bigger fleet, or throttle L2 throughput
to the proving-bound rate. Throttling is contract-visible — it caps the block gas limit, which caps fee
revenue, which caps the security budget under D-8. That chain is why this decision cannot stay implicit.

### 8.4 The caveat that must not be lost

The DA ceiling is a **capacity**, not a guarantee. Blob space is a market: the protocol must pay the blob
base fee, and under congestion it can be priced out of the target rate. Therefore:

1. `G_L2_TARGET` is defined at **nominal** blob prices; the sustained rate is whatever the fee budget buys.
2. The unsettled-depth cap `D_MAX` must absorb congestion periods, and the fee model must be able to
   raise the L2 fee so that batch publication stays funded.
3. S3 must measure the **cost curve** of publication against blob price, not a single price point.
4. If the protocol is priced out for longer than the retention window, the correct behaviour is the
   backpressure halt, not a promise it cannot keep.

### 8.5 What the specification must register

The parameter table must gain `G_L2_TARGET` and `b` (bytes per L2 gas) as registered parameters: the
former derived from the latter plus the sourced DA constants, both feeding the block gas limit, the batch
size K, `D_MAX`, the fee model and the recovery bond sizing. **This registration is a Phase B exit
criterion, not an optional extra** — the fee revenue that funds security under D-8 is a function of it.


### 8.6 Derived constraint found while specifying S1: the blob quantisation binds K

At the DA-bound rate the arithmetic is unusually clean: **one 2-second L2 block equals exactly one blob** *(the design's own DA-bound rate, plan §8.2, unchanged)*
(131,072 bytes), so a K-block batch carries about K blobs. D5 requires the batch's data **and** its proof
in one L1 transaction, and the measured BPO2 set caps blobs per L1 block at **14 target / 21 maximum** *(Phase B S4 public-data report §3 F6)*. Therefore:

```
BATCH_BLOCKS x blobs_per_block  <=  blobs_per_L1_tx_max          (a hard ceiling: 21)
BATCH_BLOCKS                    <=  blobs_per_L1_tx_target       (the sustainable value: 14)
```

The retired placeholder `BATCH_BLOCKS = 32` is **not publishable** at the DA-bound rate: it would need
32 blobs in one transaction against a ceiling of 21 *(the measured BPO2 maximum; Phase B S4 public-data report §3 F6)*; the owner's Phase B decision registers the planning length at `BATCH_BLOCKS = 14` — the BPO2 target — which is publishable in one transaction by construction (`spec/09-parameters.html`). This is a derived bound, not a preference, and it
propagates:

| Consequence | Value at the target rate |
|---|---|
| Largest sustainable batch | 6 blocks = 12 s of L2 = exactly one L1 slot |
| Unsettled batches inside the 30-minute envelope | 900 / 6 = **150** |
| Proofs in flight (`L / Δ`) | **≈ 150 concurrent**, not the ≈ 28 the earlier placeholder implied |
| Fleet sizing (S1) | must be evaluated at ≈ 150 in flight, not 28 |
| Reward per batch | spreads over 6 blocks, not 32 — the per-batch reward floor from S3 must be read with this |

*(These consequences are the plan's own 2026-10-05 design arithmetic at the then-current 6-blob chain target; they are design assumptions, not the chain's in-force limits. The measured set is target 14 / max 21 — Phase B S4 public-data report §3 F6 — and this propagation keeps the design rows unchanged rather than re-deriving them.)*

Two ways out, and both are user-visible decisions rather than parameter tweaks: **cap the block gas limit**
so each 2 s block carries less data (more blocks per batch, less throughput), or **accept more than one L1
transaction per batch**, which D5 forbids for an accepted batch. S1 must report `blobCount` and `K <= 21`
per cell for this reason *(the 21-blob BPO2 ceiling — Phase B S4 public-data report §3 F6)*, and S3 must price the constraint, because the fee revenue that funds security is
a function of it.

**Action.** The specification must register the constraint alongside `BATCH_BLOCKS` and `MAX_BATCH_BLOCKS`
(cross-referencing L1-01/L1-05 and D5) as soon as the recovery-repair edits land, so that no implementer
picks a batch size that cannot be published.

