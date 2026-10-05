# S3 — L1 cost per batch, the fee flow, and the reward floor

Status: **spike specification, not results** · Owner: S3 engineer · Reviewer: protocol lead · Date: 2026-10-05
Plan of record: [05-phase-b-plan.md](../05-phase-b-plan.md) §1 (S3), §2 (measurement discipline), §3 (gates), §5 (kill criteria), §8 (the DA-bound target)
Why it is security-critical: [iterations/04-round.md](../iterations/04-round.md) — "S3 now owns a security-critical interface, not just a gas measurement"; finding R4-PB-01 (the fee sweep can be redirected to the caller) and the "landing market is unpriced" High (an empty pool reaches the recovery trigger with no adversary).
Feeds the recovery repair: [S5-recovery-repair.md](./S5-recovery-repair.md) §1 (retired-heights record), §4 (bond sizing), §7 (the sweep interface), §8 (the fee-vault credit check).

**Pins.** Repo: commit `f9e5203d561cf9d50894247711496a664e5ac824`, branch `etna-pos-zk` (2026-10-05). Toolchain: Foundry **1.8.3** (`forge`/`cast`, commit `cae51ad458f6abb64852b7709eb784352429825d`), **solc 0.8.30**, `evm_version = "osaka"` — all read from [foundry.toml](../../../../foundry.toml), not chosen here. Libraries: **forge-std 1.9.5** (`vm.blobBaseFee`, `vm.blobhashes`, `vm.startSnapshotGas`/`stopSnapshotGas` are present in the installed `Vm.sol`); **risc0-ethereum v3.0.1** and **sp1-contracts v6.1.1** (the imports already pinned in `packages/protocol/package.json`). Ethereum constants: `FIELD_ELEMENTS_PER_BLOB = 4096`, 131,072 bytes per blob, point-evaluation precompile at `0x0A` at **50,000 gas**, `GAS_PER_BLOB = 131,072` (*sourced*, EIP-4844); blob target/maximum **6/9** per L1 block (*sourced*, EIP-7691); L1 slot **12 s** (*sourced*, re-derive if Ethereum changes it — plan §8.2).

**Number tags used below.** `sourced` (with a source), `derived` (arithmetic shown), `hypothesis` (a pre-registered belief this spike tests), `unmeasured` (an output of this spike). Nothing in this document is a measurement.

## 1. One-sentence purpose, and the parameters it fills

**Purpose.** Measure the L1 gas and ETH cost of the acceptance path `land(data, proof)` for both data paths and for K ∈ {8, 32, 128}, measure the cost curve of publication against the blob base fee rather than one price point, measure the per-new-storage-slot cost that budgets S5's recovery state, and derive the minimum reward per batch (`REWARD_QUOTE` floor) at which a permissionless prover still lands — while pinning, as a security deliverable, the exact fee-sweep bridge message and the fee-vault credit enforcement.

| Parameter / rule | Unit | What S3 fixes | Register |
|---|---|---|---|
| `REWARD_QUOTE` | ETH per successful `land(data, proof)` | the floor, from measured `C_land + C_prove` plus a pre-registered margin | [09-parameters.html](../spec/09-parameters.html) (`REWARD_QUOTE`, tagged unmeasured) |
| `MAX_BATCH_BLOCKS`, `BATCH_BLOCKS` (K) | L2 blocks | the largest K that is atomic at the target data budget, hence the admission bound | [09-parameters.html](../spec/09-parameters.html); [L1-05](../spec/04-l1-integration.html#L1-05) row 7 |
| gas per new storage slot | gas per slot | the unit S5 multiplies by its recovery-state slot count | plan §0 table row 4; S5 §1 |
| `C_L1_data`, `C_L1_verify`, `C_bridge_ops` | ETH per batch | the landing and bridge terms of the funding identity | [ECON-02](../spec/07-economics-slashing.html#ECON-02) clause 1 |
| the sweep message (selector, sender, `destOwner`, `to`, `data`, fee arithmetic, replay) | — | the exact interface `ECON-02(7)(b)` and `L1-11` must state | [ECON-02](../spec/07-economics-slashing.html#ECON-02) clause 7, [L1-11](../spec/04-l1-integration.html#L1-11); S5 §7 |
| fee-vault credit enforcement | rule | the check that makes "L2 fees must reach the vault" valid, not aspirational | R4-PB-08; S5 §8; [PRF-06](../spec/05-proof-statement.html#PRF-06), [CONS-01](../spec/02-consensus.html#CONS-01) |
| `b` (bytes per L2 gas), `G_L2_TARGET` | bytes/gas, gas/s | **not measured here**; S3 supplies the cost side of the fee-coverage test that consumes S1's `b` | plan §8.1, §8.5 |

## 2. The question and the decision it unblocks

**Question.** What does one `land(data, proof)` transaction cost with real blob counts and each backend's verifier, how much of it is storage growth, what does publication cost as a function of the blob base fee, and what is the minimum reward per batch that keeps a permissionless prover landing?

**Decisions that change with the answer.**

1. **`REWARD_QUOTE` is set, or the throughput target is changed.** The pass condition is plan §1 S3 and §5: *fee revenue at the target throughput covers landing plus proving with a positive margin*. If it does not, the choice among (a) raise L2 fees, (b) cap throughput, (c) a bounded, expiring subsidy, (d) change K/data budget is a **product decision** (D-8 funding, D1 cadence) — not a parameter tweak. This spike produces the break-even fee level at which that decision is made.
2. **`MAX_BATCH_BLOCKS` / K.** The blob path is bounded by the per-transaction blob maximum (**9**, *sourced*, EIP-7691) at the same time as by gas. At the target per-2 s-block data budget of 131,072 bytes (*derived*, plan §8.2: 786,432 bytes per L1 block ÷ 6 L2 blocks), a K-block batch carries K × 131,072 bytes = K blobs, so `n_blobs = K` and `K ≤ 9` for one atomic blob-path transaction (*derived*). K = 32 and K = 128 are therefore either multi-transaction batches or batches with a reduced per-block data budget; the spike measures both regimes and the report states the largest atomic K.
3. **S5's recovery-state budget and bond sizing.** `gas_per_new_slot` and the number of slots written on the acceptance path are the units S5 uses to size the retired-height record and to compare the bond with `value_at_risk(D_MAX)` (S5 §1, §4).
4. **The sweep interface becomes normative.** The measured interface is written into `ECON-02(7)` and `L1-11`; if the conforming message does not credit the pool exactly and only through the authenticated invocation, the interface is wrong and the D-8 funding path stays Open.
5. **The fee-vault credit check.** If the check cannot be stated as a total predicate over executed state and receipts, D-8's funding path is unenforceable and the round-4 High (fee diversion with no enforcement point) stands.

**Falsifiers.**
- If a *conforming* sweep message can be built by a non-protocol caller such that the pool is not credited while the value leaves the vault, the sweep interface falsifies D-8 as designed.
- If the break-even fee level exceeds the observed L2 fee level at the target throughput by any margin, the plan's pass condition is false and the throughput target or reward policy must change (plan §5).
- If `n_blobs` at the target data budget exceeds 9 for the nominal K, the "one atomic batch of K blocks" reading of D5 is false for blobs and the batch/admission design changes.

## 3. Harness — what to build, what to reuse, what NOT to build

### 3.1 Build (measurement artifacts only)

1. **`LandHarness.sol`** — a non-upgradeable, non-production Solidity contract that implements exactly the acceptance path of the specification and nothing else: the [L1-05](../spec/04-l1-integration.html#L1-05) payload decode; the [L1-05](../spec/04-l1-integration.html#L1-05) row checks that cost gas (range, `MAX_BATCH_BLOCKS`, `dataCommitment` derivation); the [DA-02](../spec/04-l1-integration.html#DA-02) calldata commitment; the [DA-03](../spec/04-l1-integration.html#DA-03) `BLOBHASH` loop, per-blob challenge derivation, `0x0A` precompile call and return check; the [L1-07](../spec/04-l1-integration.html#L1-07) checkpoint write plus `recoveryGeneration`; one call into a verifier route; the [L1-11](../spec/04-l1-integration.html#L1-11) reward-ledger update; events. It must be a faithful gas model, so storage layout and ordering are part of the artifact and are frozen at first run.
2. **`SweepVault.sol`** (L2 side) — the proposed `sweep()` with no caller-influenced destination: it constructs the Bridge message from protocol constants and sends it (see §3.4). The measured interface is a deliverable, so the harness contains the interface, not a mock of it.
3. **`RewardPoolReceiver.sol`** (L1 side) — a staking-contract-shaped receiver exposing `onMessageInvocation(bytes)` and a *credited balance* that increases only on the authenticated invocation path; plus a bare fallback (so a wrong-selector refund is observable as an uncredited balance delta).
4. **`FeeVaultCreditCheck`** — a Solidity mirror of the check of §3.4 plus its negative fixture, so the harness can show that a batch whose execution diverts fees is rejected by the guest-side predicate. The in-guest cost is S1's; the L1 side of the same check (an added journal field in the statement hash) is measured here.
5. **A blob-price sweep driver** — a forge script that samples blob base fee and L1 base fee from a *recorded, cited* source at run time (never hard-coded), then replays the matrix under those values with `vm.blobBaseFee` and a base-fee/priority-fee override.

### 3.2 Reuse (pinned)

| Reused | Pin | Why it is the right object |
|---|---|---|
| `forge`, `cast` | 1.8.3, commit `cae51ad458…` | `vm.blobBaseFee`, `vm.blobhashes`, `vm.startSnapshotGas` are present in the installed forge-std; `evm_version = osaka` makes `0x0A` and `BLOBHASH` available in tests |
| verifier **contracts** | risc0-ethereum **v3.0.1** (`RiscZeroVerifierRouter`, `RiscZeroGroth16Verifier`, `ControlID.sol`), sp1-contracts **v6.1.1** (`src/v6.1.0/SP1VerifierGroth16.sol`, `SP1VerifierGateway`) | the exact versions this repository already imports; the verifier route is a real routed call, not a mock |
| verifier **fixtures** | `node_modules/risc0-ethereum/contracts/test/TestReceiptV3_0.sol` (real Groth16 seal + journal + image id); `node_modules/sp1-contracts/contracts/test/SP1VerifierGroth16V6.sol` (real Groth16 proof bytes) | a real seal is needed for the verifier to do its work; generating a new proof only changes the seal bytes, not the verifier's gas, which is a function of the pinned verifier and proof encoding |
| Bridge + SignalService | the repository's preserved contracts at the pinned commit ([Bridge.sol](../../../../contracts/shared/bridge/Bridge.sol), [IBridge.sol](../../../../contracts/shared/bridge/IBridge.sol)) | the sweep's L2 and L1 legs must be measured against the preserved surface, including its own status machine |
| Bridge test plumbing | the repository's existing bridge test harness (received-signal proofs, checkpoint anchoring) | re-deriving the SignalService proof plumbing is not the question; reusing it keeps the L1 leg honest |
| `IMessageInvocable` selector | computed by `cast sig "onMessageInvocation(bytes)"` = `0x7f07c947` (*derived* from [IBridge.sol](../../../../contracts/shared/bridge/IBridge.sol) line 165; re-derive with the pinned `cast` and record the output) | the canonical invocation selector the Bridge compares against ([Bridge.sol](../../../../contracts/shared/bridge/Bridge.sol) lines 713–714) |

### 3.3 Do NOT build

- **No guest, no prover, no proof generation.** The acceptance path's gas does not depend on the proof's contents once the route and proof encoding are fixed; the verifier route is measured with the vendor's own fixture at the pinned version.
- **No production Inbox, no upgradeability, no access control, no deployment scripts.** Gas differences from proxies/immutables are noted as a limitation (§8), not modeled.
- **No consensus verification, no epoch/set logic, no signature checking.** These are S1's subject and contribute no gas to `land` beyond a fixed-size journal field.
- **No bridge changes and no new bridge message types.** The preserved Bridge is used as-is; the sweep is constrained to what its existing `sendMessage`/`processMessage` accept.
- **No L2 node and no fee-market simulation.** The fee level is an *observed* input to the cost-coverage test, sampled and cited; it is not modeled from first principles.

*Why these shortcuts are legitimate.* Gas on the acceptance path is a function of: calldata/byte lengths, the number of blob references, the number and shape of storage writes, hash input lengths, one precompile call per blob, and one verifier call whose gas is a property of the pinned verifier and proof encoding. None of those terms depends on how the proof was produced or on consensus semantics. The report must nonetheless enumerate every module boundary not covered (proxy indirection, access checks, the L2 fee policy contract, real blob transaction intrinsic cost) so a reader can add them explicitly.

### 3.4 The two security deliverables, specified to be measured

**The sweep interface.** The vault's `sweep()` takes no argument that influences the destination and constructs the `Message` itself:

| Field | Value constructed | Rule it satisfies |
|---|---|---|
| `id`, `from`, `srcChainId` | assigned by the L2 Bridge ([Bridge.sol](../../../../contracts/shared/bridge/Bridge.sol) lines 247–249) | the caller cannot choose them |
| `srcOwner` | the constant `L2FeeVault` address | ties the source |
| `destOwner` | **the reward-pool protocol constant** (never caller-supplied) | closes R4-PB-01's redirect: on a failed invocation the Bridge refunds `value` to `destOwner` ([Bridge.sol](../../../../contracts/shared/bridge/Bridge.sol) lines 344–349, 400) |
| `destChainId` | L1 chain id constant | [MSG-02](../spec/04-l1-integration.html#MSG-02) |
| `to` | **the reward-pool address** | the pool is called |
| `data` | `abi.encodeWithSelector(IMessageInvocable.onMessageInvocation.selector, payload)` with selector `0x7f07c947` | any other selector (or `data.length < 4`) makes `_unableToInvokeMessageCall` true and the value is refunded without invoking the pool ([Bridge.sol](../../../../contracts/shared/bridge/Bridge.sol) lines 713–714) |
| `value` | the vault balance to deliver | this is what the pool credits |
| `fee` | the Bridge fee, **additional ETH** | `value + fee == msg.value` is enforced ([Bridge.sol](../../../../contracts/shared/bridge/Bridge.sol) line 242); the spec sentence "the fee is charged against the swept amount" is therefore corrected by this spike, and `fee != 0` requires `gasLimit != 0` (lines 229–233) |
| `gasLimit` | ≥ the measured `getMessageMinGasLimit(data.length)`, and enough that `processMessage` can invoke the pool | a too-small limit yields `RETRIABLE`, not credit |

One-shot and replay rules: the Bridge's per-message status (`NEW/RETRIABLE/DONE/FAILED/RECALLED`) is the replay guard ([MSG-02](../spec/04-l1-integration.html#MSG-02)); the vault is non-reentrant; a zero-balance sweep returns without sending and must not revert; the pool credits only when `context().from == L2FeeVault` and `context().srcChainId ==` the L2 chain id, as recorded by the Bridge before the invocation.

**The fee-vault credit check.** Define, for one batch, `expected = Σ over executed transactions gasUsed × effectiveGasPrice` where both the base-fee and priority components are routed to the vault ([ECON-02](../spec/07-economics-slashing.html#ECON-02) clause 7(a)); let `delta = balance(L2FeeVault, lastHeight) − balance(L2FeeVault, firstHeight − 1)`. The **proposal is valid only if `delta ≥ expected`**, computed in-guest from the executed receipts and the two account reads, and bound into the statement as a journal field so the claim is public. `≥` rather than `==` is deliberate: a donation to the vault must not invalidate every honest proposal for the range (a griefing DoS), and a diverter who must donate back what was diverted gains nothing. The spike measures the L1 marginal cost of binding the field and tests both comparison forms; the exact form and the journal-field name are S3's recommendation to the spec owner (S5 §8).

## 4. Experiment matrix

**Independent variables.**

| Variable | Values | Notes |
|---|---|---|
| data path (`daMode`) | `CALLDATA` (1), `BLOB` (2) | hybrid (3) is out of scope; it is the sum of the two paths plus a second hash |
| K | 8, 32, 128 | plan §1 S1/S3 |
| payload regime | (a) target budget `D_block = 131,072` bytes/block; (b) atomic-fit `P ≤ 1,179,648` bytes (9 blobs), i.e. `D_block = floor(1,179,648/K)` | (a) is the plan §8.2 target, (b) is the EIP-7691 per-transaction maximum. Both are needed: (a) determines the target, (b) determines whether one transaction can carry it |
| blobs per batch `n` | `ceil(P/131,072)`, swept over {1, 2, 3, 6, 9} | 6 = EIP-7691 target per L1 block, 9 = maximum |
| verifier route | SP1 v6.1.0 Groth16; SP1 v6.1.0 PLONK (secondary); RISC Zero v3.0.1 Groth16 | two backends are required by `PRF-09`; RISC Zero on-chain gas is `unmeasured` in [03-zkvm-feasibility.md](../03-zkvm-feasibility.md) §2.4 and must come from this run |
| blob base fee | sampled at run time from a cited public source over a stated window: minimum (1 wei/blob gas, *sourced*, EIP-4844), p50, p90, p99, max observed, and 10 × max as a stress point | plan §8.4 requires a **cost curve**, not one price point. The sampled values are recorded with their source and window; nothing is hard-coded |
| L1 base fee / priority fee | sampled the same way: p10, p50, p90, max of the same window | `foundry.toml`'s 10 Gwei default is a test default, not a market value, and MUST NOT be used as the measured price |
| storage case | cold (fresh range) and warm (immediately following range, same test) | isolates the per-slot `SSTORE` cost from access-list effects |
| sweep case | balance ∈ {0, 1 wei, 1 ETH-class, large}; selector conforming / wrong-4-byte / absent; pool receiver succeeds / reverts → `RETRIABLE`; retry after `RETRIABLE` | the interface's failure paths carry the security budget |

**Fixed workload.** The payload `P` is the [PRF-07](../spec/05-proof-statement.html#PRF-07)(0) framing — `frame(h) = be32(len(body_h)) || body_h` — over K frames of a fixed byte size, with a fixed pseudorandom seed recorded in the artifact. Content is uniform bytes: every gas term measured here is byte-length-driven (calldata, keccak, `BLOBHASH` count, precompile count, storage), so compressibility affects only the mapping from L2 blocks to bytes (S1's `b`), not the gas per byte; the report must state this and must not infer `b` from this harness. The exact `body_h` byte layout, the seed, and the resulting `len(P)` are frozen in the artifacts.

**Repetitions.** Five independent runs per configuration; each run rebuilds state in `setUp` so cold-storage behaviour is not polluted by a previous configuration. Gas is expected to be deterministic; any spread is a harness defect and must be reported, not averaged away. Wall-clock is reported for the harness only (build/run), with the machine recorded.

**Derived feasibility cells the matrix must include.** `n_blobs(K) = ceil(P/131,072)`. At regime (a): K=8 → 8 blobs (fits 9); K=32 → 32 blobs (does not fit one transaction); K=128 → 128 blobs (does not fit). At regime (b): K=8 → ≤9 blobs; K=32 → 9 blobs; K=128 → 9 blobs. The report must state, for each (K, regime), whether a single atomic `land` is possible and, if not, the minimum number of transactions and the per-L1-block batch count needed to sustain the target rate.

## 5. Metrics

Every row is recorded per configuration with units, method and variance; the run-metadata block of [report-template.md](./report-template.md) is mandatory.

| Quantity | Unit | How measured |
|---|---|---|
| `gas_land` total | gas | `vm.startSnapshotGas`/`stopSnapshotGas` around the `land` call, plus `--gas-report` for the function breakdown; block gas and tx gas recorded |
| gas decomposition | gas | intrinsic (21,000 + calldata zero/nonzero mix), `keccak256(P)`, `blobhash` loop, `50,000·n` precompile, verifier route, storage writes, events, return/ABI decode |
| `n_blobs` and `P_bytes` | count, bytes | from the frozen workload |
| `gas_per_new_storage_slot` | gas/slot | difference between the measured checkpoint+recovery-generation write and the same call with the write removed; cross-checked against the sourced constants (cold key access 2,100 gas, zero→nonzero `SSTORE` 20,000 gas — EIP-2929, EIP-2200) |
| slots written on the acceptance path | count and slot list | the harness's storage layout, frozen and committed |
| verifier-route gas | gas | the routed call with the pinned fixture, per backend and per proof type |
| execution gas price | wei/gas | sampled base fee + sampled priority fee, with the source and window |
| blob cost per batch | wei (and ETH) | `n × GAS_PER_BLOB × blob_base_fee`, plus execution gas × price; *derived* from the measured `n` and the sampled price; `GAS_PER_BLOB` *sourced* (EIP-4844) |
| `C_land(batch)` | ETH | measured gas × sampled price + blob cost; both terms reported separately |
| `C_bridge_ops(sweep)` | ETH | measured L2 sweep gas × L2 price + measured L1 release gas × L1 price + the Bridge `fee` actually charged |
| sweep delivered amount | ETH | `value` credited by the pool on the conforming path; `refundAmount` and its recipient on every other path; message status transitions |
| vault balance delta vs `expected` | ETH | the §3.4 check on the positive fixture (delta = expected) and the diverting fixture (delta < expected → reject) |
| `R_min` (reward floor) | ETH/batch | `(C_land + C_prove + C_bridge_ops + C_ops) / (1 − ε)`, `ε` pre-registered (see §6); `C_prove` is S1's measured cost per batch and is cited, not measured here |
| break-even fee level | wei per L2 gas | the `f` solving `G_L2_per_batch × f = C_land + C_prove`, with `G_L2_per_batch` from plan §8.1 and S1's `b` |
| fee revenue at target | ETH/batch | `G_L2_per_batch × f_obs`, `f_obs` sampled from the deployed chain's observed fee level over a stated window (source recorded); this is an *input*, not a measurement of this harness |

**Run metadata (mandatory, per plan §2):** pinned repo commit; Foundry/solc/forge-std/verifier-package versions; hardware (CPU model, cores, RAM, OS) — the harness is CPU-only; workload hash; method (commands, cheatcodes, snapshot API); date/time with timezone; repetitions and variance; the sampled price series with its source URL and retrieval date.

## 6. Pass/fail

| # | Threshold | Pass condition (mechanically checkable) | If it fails |
|---|---|---|---|
| P1 | **Fee coverage with positive margin** (plan §1 S3, §5) | With `ε ≥ 0` pre-registered in the report before the run: `G_L2_per_batch × f_obs ≥ (1 + ε) × (C_land + C_prove)`. Both sides in ETH per batch, at the sampled p50 price and at the plan §8.2 target rate. The report must also state the break-even `f*` and the ratio `f_obs / f*` | **Product decision** (plan §5): raise L2 fees, cap throughput, or fund from the treasury with a bounded, expiring subsidy ([ECON-02](../spec/07-economics-slashing.html#ECON-02) clause 4). Escalate to the D-8/D1 owners; do not adjust `REWARD_QUOTE` silently |
| P2 | **Blob-path atomicity** | For each K, `n_blobs_at_target(K) ≤ 9` and `gas_land ≤` the sourced per-transaction gas cap and L1 block gas headroom | `MAX_BATCH_BLOCKS` is set to the largest K that passes; if K = 8 fails, K shrinks and the pipeline depth/batch cadence is re-derived; escalated as a K/`D_MAX` change (plan §4) |
| P3 | **Cost curve, not a point** | A monotone-in-blob-price curve of `C_land(batch)` exists over at least the sampled {min, p50, p90, p99, max, 10×max} points, with the break-even blob base fee stated | The fee model cannot promise the nominal rate; the report states the blob price above which publication is unfunded and the maximum sustained-congestion duration, feeding `D_MAX` and the plan §8.4 backpressure statement |
| P4 | **Sweep interface** | The conforming message credits exactly `value` to the pool's credited balance; the wrong-selector and absent-selector messages credit **zero** (value is refunded to the pool constant as `destOwner` but is not credited); a zero-balance sweep is a gas-only no-op; the arithmetic observed is exactly `msg.value == value + fee` | The interface as built does not satisfy [ECON-02](../spec/07-economics-slashing.html#ECON-02)(7)(b) / [L1-11](../spec/04-l1-integration.html#L1-11); S3 returns to design, D-8's funding path stays Open, and the round-4 Critical is not closed |
| P5 | **Fee-vault credit enforcement** | The positive fixture is accepted and the diverting fixture (delta < expected) is rejected by the predicate; `expected` is computed from executed receipts only | Enforcement cannot be stated; escalate to S5 §8 and to `CONS-01` validity — do not ship D-8 without it |
| P6 | **Storage budget for S5** | `gas_per_new_storage_slot` and the acceptance-path slot list are reported; `gas_per_new_slot × slots_recovery ≤` a stated share of one `land` gas budget, with the share recorded by S5 | S5 sizes the retired-height record against the measured unit or reduces its slot count; the recovery repair cannot claim a budget it does not have |

*Falsification of the design decision.* P1 failing falsifies "L2 fee revenue funds landing plus proving at the target rate" — the D-8 funding premise. P4 failing falsifies "the caller chooses only when" in [ECON-02](../spec/07-economics-slashing.html#ECON-02)(7)(b) and reopens R4-PB-01. P2 failing falsifies "one atomic batch of the nominal K at the target data budget" and forces the admission bound or the data budget to move.

## 7. Worked example of the arithmetic the engineer will do (symbolic only)

Let `g_d` = measured total gas of `land` for data path `d` at batch size K and payload `P`; `p_e` = sampled L1 execution price (wei/gas); `p_b` = sampled blob base fee (wei/blob gas); `n = ceil(|P| / 131,072)`; `GAS_PER_BLOB = 131,072`.

    C_land(K, d) = g_d(K, P) · p_e  +  n · GAS_PER_BLOB · p_b                [wei]

    g_BLOB(K) = 21,000 + g_calldata(|P|, mix) + g_blobhash(n) + 50,000·n
                + g_verifier(route) + g_keccak(|P|) + g_sstore(slots) + g_events
        (each term measured; only the 50,000·n term is sourced, EIP-4844)

    gas_per_new_slot = g_sstore(slots) / slots_new       (measured; cross-check 20,000 + 2,100 sourced)

    R_min(K) = (C_land(K) + C_prove(K) + C_bridge_ops + C_ops) / (1 − ε)     [wei/batch]

    fee_revenue(K) = G_L2_per_batch(K) · f_obs        with   G_L2_per_batch = K · (131,072 / b)
        (b from S1, bytes per L2 gas; 131,072 derived, plan §8.2)

    break-even:  f* = (C_land(K) + C_prove(K)) / G_L2_per_batch(K)           [wei per L2 gas]
    margin ratio = fee_revenue / (C_land + C_prove) − 1     (P1 requires ≥ ε)

    sweep delivery:  msg.value = value + fee;  arrival = value;  swept_for(R_min) = R_min + fee
        (the corrected arithmetic of ECON-02(7)(c): the fee is additional ETH, so the vault must
         hold value + fee, and arrival(s) = swept(s) − fee(s))

    multi-transaction case:  batches_per_L1_block = ceil(rate_batches_per_second · 12)
        blobs_per_L1_block = batches_per_L1_block · n  ≤ 6 (target) with n ≤ 9 (max)
        (6/9 sourced, EIP-7691; the resulting constraint on K is the P2 output)

    recovery budget:  gas_recovery_state = slots_recovery · gas_per_new_slot
        value_at_risk(D_MAX) per S5 §4 is then compared with B_REC_KEEP in the same ETH units.

No symbol above may be replaced by a number that this spike did not measure or cite.

## 8. Risks, confounders, and what would make the measurement invalid

| # | Risk / confounder | Effect | Control |
|---|---|---|---|
| R1 | Measurement harness diverges from the production Inbox (proxies, immutables, access checks, storage packing) | gas understated or overstated | `LandHarness` is frozen per run; the divergence list is a required artifact section; the report gives a corrected range, not a single number, where a term is known to differ |
| R2 | Vendor fixtures are not produced by *our* guest | verifier gas could differ if the proof encoding or public-values length differed | the verifier's gas depends on the pinned verifier and the proof encoding; the fixture's program identity and public-values length are recorded; if S1 produces its own proof, the route gas is re-measured with it and both values are reported |
| R3 | `vm.blobhashes`/`vm.blobBaseFee` set state and do not reproduce a real blob transaction's intrinsic accounting | `gas_land` omits the blob-transaction intrinsic cost | blob gas is added analytically (`n · GAS_PER_BLOB · p_b`) and labelled *derived*; the harness gas is labelled "execution gas only"; the gap is stated, not glossed |
| R4 | Calldata zero/nonzero byte mix and calldata-floor costs | intrinsic gas varies | the exact byte mix is frozen in the workload and reported; the calldata path's cost is reported per mix |
| R5 | A single price snapshot treated as a market | the pass/fail becomes unfalsifiable | P3 requires the curve; the sampled series and its source/window are artifacts; the report must state the break-even blob price explicitly |
| R6 | Observed L2 fee level is taken from a different workload/period | the coverage test transfers an unrelated fee level | the fee series is sampled with its source and window and its workload mix; the report states explicitly that it is an input, not a measurement, and gives the coverage test as a function of `f_obs` |
| R7 | Verifier version skew | SP1 mainnet carries `V6_1_0` while the SDK is 6.8.1 ([03-zkvm-feasibility.md](../03-zkvm-feasibility.md) §2.3 V1/V2) | the harness pins the *contract* version (sp1-contracts v6.1.1) and records which verifier address/route was exercised; the release→VKEY mapping remains UNVERIFIED and is called out as an S1 dependency |
| R8 | Sweep L1 leg measured without real bridge state (statuses, quota, fee refunds) | delivered amount and gas wrong | the real preserved Bridge and SignalService are used; the fixture's message status transitions are recorded; the `RETRIABLE` and refund paths are exercised, not mocked |
| R9 | Fee-vault credit check tested only in the equality form | griefing DoS or diversion hole survives | both `≥` and `==` are tested; the donating-griefer case is a named negative test |
| R10 | Warm/cold contamination between matrix cells | non-reproducible gas | fresh state per cell; five runs; any non-determinism is reported as a defect |

**Invalidating conditions.** The measurement is invalid if (a) the harness performs any state write that the specification's acceptance path does not perform, or omits one it does; (b) the verifier fixture is rejected (the route gas is then not the route gas); (c) price inputs are hard-coded rather than sampled with a source; (d) the report quotes a gas figure without the split between execution gas and derived blob gas; (e) a pass/fail is reported without the `ε` or share value fixed *before* the run.

## 9. Artifacts to commit and where

Root: `packages/protocol/docs/Etna/pos-zk/phase-b/artifacts/S3/` (created on first run).

| Path | Content |
|---|---|
| `harness/` | the forge project: `LandHarness.sol`, `SweepVault.sol`, `RewardPoolReceiver.sol`, `FeeVaultCreditCheck`, tests, the frozen storage layout, and a `README.md` with the exact commands and the toolchain versions |
| `fixtures/` | negative and positive fixtures (diverting proposal, donating griefer, wrong selector, absent selector, `RETRIABLE` + retry), each with SHA-256 |
| `prices/` | the sampled blob-base-fee and L1-price series with their source URL, retrieval date and window; the sampling script |
| `raw/` | `gas-<config>.json` (forge snapshot JSON, one per configuration), raw logs, five repetitions per cell |
| `summary.csv` | one row per configuration: independent variables, all §5 metrics, units, variance |
| `summary.json` | the machine-readable block of [report-template.md](./report-template.md) |
| `report.md` | the filled [report-template.md](./report-template.md) |
| `sweep-interface.md` | the normative text proposed for `ECON-02(7)`/`L1-11`, with the measured selector, fields, arithmetic and status transitions |
| `fee-vault-check.md` | the normative text proposed for the guest/L1 enforcement check, with the measured marginal cost |
| `falsifiers.md` | every statement in this spike that the run would falsify, and the observed status |

Nothing under `artifacts/S3/` may be edited after G2 except by appending a dated correction; raw files are write-once.

## 10. Effort estimate and skill profile (estimate, not a measurement)

**Estimate: 10–12 working days for one engineer**, plus 1–2 days of protocol-lead review of the two security deliverables.

| Phase | Days | Work |
|---|---|---|
| Harness | 3–4 | `LandHarness` + verifier-route wiring + fixture reuse + frozen storage layout |
| Sweep + fee-vault check | 2–3 | real Bridge/SignalService plumbing, all status paths, the enforcement fixtures |
| Matrix execution | 2 | both paths, three K, two regimes, six price points, five repetitions |
| Analysis + report | 2–3 | the §7 arithmetic, P1–P6 evaluation, artifacts, falsifier list |

**Skill profile.** One Solidity/Foundry engineer comfortable with storage-layout-level gas analysis, the preserved Bridge's status machine, and forge cheatcodes; able to read [spec/04](../spec/04-l1-integration.html) and [spec/07](../spec/07-economics-slashing.html) as normative text. No zkVM or cryptography skill is required for S3; the verifier is a call site. The two security deliverables need a second reader with protocol authority (the lead) because they change rules, not just numbers.
