# S1 — Proving throughput and cost

**Phase B spike specification. This is an experiment design, not a result: it contains no measurement of its own.**
Every number below is tagged *sourced* (source named), *derived* (arithmetic shown), or *hypothesis to be tested*.

Status: ready to execute · Date: 2026-10-05 · Owner: protocol lead
Reads: `05-phase-b-plan.md` §1 (S1) and §8; `03-zkvm-feasibility.md` §§2, 6–7, 10; `spec/09-parameters.html` (PARAM-02, PARAM-03); `spec/05-proof-statement.html` (PRF-07); `spec/04-l1-integration.html` (DA-03)
Fills register rows: `b` (bytes per L2 gas), `G_L2_TARGET` (derived from `b`), `C` (cycles per L2 gas), `R_gas` (proven gas/s per machine), the in-guest blob-evaluation cost, and the evidence behind `BATCH_BLOCKS` (K), `MAX_BATCH_BLOCKS`, pipeline depth, fleet sizing and `LIVE-03`(i)–(ii).

## 1. Purpose, and the parameters this spike fills

**Purpose.** Measure, on a frozen L2 workload and at pinned zkVM versions, the cycles and wall-clock cost of a K-block batch (existing type-1 EVM execution + a thin consensus half + the EIP-4844 blob half), so that `b` = billed L1 data bytes per unit of L2 gas and the proven gas rate per machine can be evaluated against the DA-bound throughput target derived in `05-phase-b-plan.md` §8.

| Parameter (register spelling) | Unit | Value / formula before S1 | What S1 supplies |
|---|---|---|---|
| `b` | bytes per L2 gas | **unmeasured** (plan §8.2) | measured `b_payload` and `b_billed`, per workload and per K |
| `G_L2_TARGET` | L2 gas/s | `65,536 / b` *(derived below)* | the number, once `b` is measured |
| `C` | zkVM cycles per L2 gas | unmeasured (PARAM-03) | measured, per backend, per workload |
| `R_gas` | proven gas/s per machine | unmeasured (PARAM-03) | measured, per backend and machine class |
| In-guest blob evaluation | cycles per blob / per 4,096 elements | **unmeasured** (PARAM-03, open item F2) | measured, plus its share of batch cycles |
| `BATCH_BLOCKS` (K) | L2 blocks | 32 placeholder, unmeasured | cost/latency curve for K ∈ {8, 32, 128} |
| `T_PROOF_MAX_PERMITTED` (evidence) | seconds | unmeasured | per-batch proof latency distribution at each K |
| `MAX_BATCH_BLOCKS` | L2 blocks | unset | the publishability bound derived in §4.4 |

**The target, re-derived from plan §8 so the engineer never has to re-read it.** Plan §8.1 writes `G_L2_TARGET = DA_bytes_per_l1_block x blobs_per_block_target / L1_slot_seconds / b`; plan §8.2 fixes the operands as 131,072 bytes per blob (sourced, EIP-4844), 6 target blobs per L1 block (sourced, EIP-7691) and 12 s per L1 slot (sourced). The operative form is therefore

    DA_bytes_per_second = 6 x 131,072 / 12 = 786,432 / 12 = 65,536 bytes/s      [derived]
    G_L2_TARGET         = 65,536 / b                                            [gas/s]

*Illustrative only — arithmetic on an invented `b`, exactly as plan §8.2 says, and not quotable as a result:* `b` = 0.006 bytes/gas gives `65,536 / 0.006 = 10.92` Mgas/s; `b` = 0.02 gives 3.28 Mgas/s. This 3–5x sensitivity is why `b` is measured, not assumed.

**Two spellings of `b`, both required.** DA capacity is consumed in whole 131,072-byte blobs, so the tariff-relevant quantity is blob-quantised:

    b_payload = len(P) / gasUsed                          [bytes/gas]
    b_billed  = 131,072 x blobCount / gasUsed          [bytes/gas], blobCount = ceil(len(P) / 131,072)

`P` is the PRF-07(0) canonical payload (four-byte big-endian length prefix per height, then the RLP transaction list, no compression or extra framing field). `b_billed >= b_payload` always; the gap is blob padding. The plan's formula consumes **`b_billed`**; `b_payload` is reported because it is the only part a codec can improve.

## 2. The question, and the decision it unblocks

**Question.** For the frozen workload, at RISC Zero `v3.0.6` and SP1 `v6.8.1`: what are (a) cycles per L2 gas, (b) seconds and cost per proof for K ∈ {8, 32, 128}, (c) proven gas per second per machine, (d) the in-guest cost of the Lagrange evaluation over 4,096 field elements that PRF-07(b)(iv)/DA-03(iv) requires, and (e) the resulting `b` and `G_L2_TARGET`?

**The decision.** `05-phase-b-plan.md` §8.3: `G_L2_TARGET = min(DA-bound rate, proving-bound rate)`.

- **Pass** (proving-bound ≥ DA-bound at an affordable, pre-registered fleet): the L2 is DA-limited; `G_L2_TARGET = 65,536 / b_billed` stands and is registered, feeding the block gas limit, K, `D_MAX`, the fee model and the recovery bond sizing (plan §8.5).
- **Fail** (proving-bound < DA-bound): the rule that changes is the operating envelope, not the measurement — the L2 must be **throttled to the proving-bound rate**, which caps the block gas limit, which caps fee revenue, which caps the security budget under D-8. That chain is why the fallback is a user decision (plan §8.3) and not an engineering default.

The blob half is a second, independent decision: whether `PRF-07(b)` (blobs) is usable at scale, or the unconditional calldata path is the only path (plan §5, "Blob binding fails review. Calldata-only. D5 still holds; throughput becomes calldata-bound and the data budget must be restated").

**What this spike does not decide.** It does not decide the L1 cost of `land(data, proof)`, the reward floor, or whether fee revenue covers proving — those are S3. It does not decide whether blobs are cryptographically sound — that is S4. It does not re-open D-1 (Ed25519 individual signatures) or the combined-guest selection; it produces the input its recorded decision rule DR-1 needs (see §4.3).

## 3. Harness

### 3.1 What to build

One **measurement guest per backend**, built from three layers, each switchable at run time by a mode flag so that the same binary produces every cell:

| Layer | Work | Inputs (fixture-derived, deterministic) |
|---|---|---|
| E (**execution**) | Reuse the pinned type-1 EVM guest as-is: execute the K blocks of the frozen range, produce a post-state root. | Block bodies from `P`, pre-state root, witness |
| C (**consensus half**) | (i) `N` independent Ed25519 verifications, each over a **distinct** message drawn from a fixed seed; (ii) one keccak over each signature's canonical ~100-byte vote root; (iii) a keccak header-chain walk over the K block headers (parent-hash linkage, state-root extraction); (iv) a quorum skeleton: sum `N` u64 weights and check `3*s > 2*W` for the pre-registered `W`. | `N` x (32 B pubkey, 64 B signature, fixed message), K headers |
| B (**blob half**) | (i) canonicality check of every 32-byte big-endian element against `BLS_MODULUS`; (ii) inverse bit-reversal of the 4,096-element vector (EIP-4844 evaluation order, PRF-07(b)(iv)); (iii) single-point evaluation of the interpolating polynomial at the challenge `z` via the barycentric/Lagrange formula on the 4096th roots of unity — **O(4,096) field operations**, not O(4,096²); (iv) `keccak256(committedBytes)` over the full 131,072 bytes for the DA-03(v) data-commitment recomputation. | 131,072 B per blob, one 32-byte `z` per blob |

Three controls are mandatory and cheap: an **empty guest** (proving-pipeline floor), a **keccak-only** cell (per-permutation cost used to bound omissions in §3.5), and an **Ed25519-only** cell. The B layer also needs two **negative controls** — a blob whose elements are perturbed by one bit must fail, and an element equal to `BLS_MODULUS` must be rejected — because a fast wrong implementation (bytes treated as coefficients, or bit-reversal omitted) would measure the wrong algorithm.

### 3.2 Reuse, pinned

| Component | Pin | Source |
|---|---|---|
| RISC Zero | `v3.0.6` (published 2026-07-17); `risc0-zkvm` 3.0.6, `risc0-circuit-rv32im` 4.0.5, `risc0-circuit-keccak` 4.0.6, `risc0-groth16` 3.0.5, `risc0-bigint2` 1.4.14 | `03-zkvm-feasibility.md` §2.1 |
| SP1 | `v6.8.1` (published 2026-09-24); `sp1-zkvm` 6.8.1, `sp1-lib` 6.8.1 | `03-zkvm-feasibility.md` §2.2 |
| Verifier contracts (not used on-chain by this spike) | risc0-ethereum v3.0.1; sp1-contracts v6.1.1 | same |
| Type-1 EVM guest | the Raiko reth-based guest line at the production version recorded in-repo: `raiko2 v0.8.0-rc1`, commit `5738ba13f` (2026-09-21), which already has a RISC0 image-ID route and an SP1 program-VKEY route | `packages/protocol/deployments/mainnet-contract-logs-L1.md` lines 243, 301–303, 315–317 |
| Execution client (witness generation only) | the repo's pinned client for the fixture range; record `packages/taiko-client` or `packages/taiko-client-rs` commit in the manifest | repo |
| Accelerators | the vendor-patched `tiny-keccak`/`sha3`, `sha2` and `curve25519-dalek` crates that ship with each SDK; the SP1 docs warn that a dropped `sha3` patch silently "drop[s] keccak256 to software (a large cycle regression, since keccak drives MPT/state-root hashing)" | `03-zkvm-feasibility.md` §4.1 |

**SDK-match rule.** The pinned guest must be built against the pinned SDK versions above. If the production guest line is on a different SDK, the spike records both versions and marks any cycle result as valid **only for the SDK actually used** (no cross-SDK transfer). The measurement guest's image ID / VKEY is a measurement artifact and MUST NOT be proposed for production registration.

### 3.3 What NOT to build

1. **The production guest.** No PRF-02 journal, no `configHash`/`recoveryGeneration` binding, no L1-anchored validator-set root, no epoch handover, no attestation chain.
2. **The real consensus half.** No Merkle/SSZ membership proofs to a set root, no real vote encoder, no real validator keys, no fork-accountability (JSet) data. §3.5 bounds the omitted terms instead.
3. **The real blob binding.** No on-chain challenge derivation, no `BLOBHASH` handling, no point-evaluation precompile call, no KZG commitment or MSM, no in-guest pairing. The 50,000 gas per blob opening is already *sourced* (EIP-4844, `spec/09-parameters.html` PARAM-02) and the on-chain path is S3/S4.
4. **Proving infrastructure.** No queue, no retries, no aggregation/recursion pipeline, no SGX, no verifier deployment, no on-chain `land()` gas, no prover market/bonding.
5. **A codec.** PRF-07(0) forbids extra framing/compression fields, so `P` is generated by the canonical framing alone; no compression research is in scope.

### 3.4 Why the shortcut is legitimate

The pass/fail needs four additive quantities: cycles of EVM execution, marginal cycles of the consensus half at N signatures, marginal cycles of the blob half at m blobs, and wall-clock per proof. A zkVM proves **one instruction trace**: adding layers adds instructions to that same trace, so the layers are additive in cycles, and the additivity is *verified* (mode-flag cells E, E+C, E+C+B) rather than assumed. Every layer's cost is measured at the exact shapes the specification fixes: `N` distinct signatures (the certificate is per-signer, 02-consensus-survey.md §9.4 row A), one head certificate per K-block batch (02-consensus-survey.md §4.7(5)), and the EIP-4844 evaluation convention of PRF-07(b)(iv). The shortcut removes implementation surface that cannot change a cycle count by more than the terms §3.5 bounds explicitly.

### 3.5 What it does not cover (stated, bounded, and excluded from the gate)

| Omission | Direction | Required bound |
|---|---|---|
| Set membership / set-root hashing, signer bitmap decoding, epoch-transition check | under-states consensus cost | add-on arithmetic using the harness's own measured keccak cost and set sizes n ∈ {100, 150, 200}; reported separately, never folded into the gate |
| Real CometBFT vote encoding and vote-hash length | ± small | record the byte length used and, if it differs from the survey's ~180–300 B estimate, say so |
| On-chain verification gas, blob gas market, L1 inclusion | not this spike | S3 |
| Non-EVM work of the production guest (journal, DA-03(v) beyond the measured keccak) | under-states | included in the report's "known omissions" table |
| Node/fleet orchestration (queueing, retries, partial failures) | optimistic | the gate is a **single-proof** rate; the report must state that sustained fleet throughput is bounded above by it |

## 4. Experiment matrix

### 4.1 Independent variables and the fixed workload

| Variable | Levels | Notes |
|---|---|---|
| Backend | RISC Zero v3.0.6; SP1 v6.8.1 | both mandatory |
| K (blocks per batch) | 8; 32; 128 | plan §1 S1; K=32 is the current placeholder |
| N (signers in the head certificate) | 67; 101; 133 (= ceil(2n/3) for n = 100/150/200) plus a 0 control | distinct messages, 02-consensus-survey.md §10.5(a) |
| m (blobs per batch) | natural `ceil(len(P)/131,072)` at each K, plus cells at 1, 6, 9 for per-blob scaling | 6/9 are the EIP-7691 target/maximum |
| Layer mode | E; E+C; E+C+B | additivity control |
| Proof mode | `core/succinct` AND the wrapped mode actually used on L1 (Groth16; PLONK separately if used) | wrap is part of cost per proof |
| Machine class | one primary GPU class (N_MAX machines, pre-registered) + one CPU-only baseline | hardware envelope in §10 |

**Fixed workload (frozen before run 1; recorded in the manifest).** A contiguous range of at least 4,096 blocks from the deployed Taiko L2 (the in-repo deployment logs annotate those L2 contracts with `@167000`; the manifest MUST record the chain id actually used), chosen so that no block has `gasUsed = 0`, ending at least 24 h before fixture generation. The manifest records: chain id, first/last height, every block hash, `gasUsed` per block, transaction count, serialized payload bytes `len(P)`, the pre-state root, and the witness bytes. K-block batches are the consecutive slices starting at the range's first block; each K has ≥ 8 batches and ≥ 5 wall-clock repetitions.

*Workload-sensitivity add-on (required, not optional).* Run at least one alternative workload to bound `b`'s dependence on the mix — either a second frozen range with a visibly different gas mix, or a local devnet at a pinned client version running (a) transfers only and (b) calldata-heavy calls. If neither is built, the report MUST state "b is measured for one workload; sensitivity unmeasured" and the parameter is registered with that caveat.

### 4.2 Staged design (full factorial is 300+ cells; do not run it)

| Stage | Cells | Repetitions |
|---|---|---|
| 0 controls | empty guest; keccak-only; Ed25519-only; B negative controls (per backend) | 3 |
| 1 main | backend x K x {E, E+C, E+C+B}, N=101, natural m | 8 consecutive batches for the cycle/gas distribution, plus 4 repeats of one fixed batch for wall-clock variance |
| 2 consensus scaling | backend x N ∈ {67, 101, 133}, K=32 | ≥ 3 |
| 3 blob scaling | backend x m ∈ {1, 6, 9}, K=32 | ≥ 3 |
| 4 wrap | backend x {unwrapped, Groth16; PLONK if used} at K=32 | ≥ 3 |
| 5 CPU baseline | 1 cell per backend at K=32 | ≥ 3 |

Cycle counts are expected to be **deterministic** for a fixed input and toolchain: any nonzero cycle variance across repeated runs of the same cell is itself a finding and must be reported with the run pair.

### 4.3 Pre-registration (mandatory; 02-consensus-survey.md §10.5 "Pre-commitment")

Before run 1, the manifest MUST record: `N_MAX` (fleet size actually provisioned and available for the whole run), `B_fleet` (monthly budget in ETH at a dated price source), the dominance definition for Ed25519-vs-BLS decision rule DR-1 (share of batch cycles at s=101 attributable to signature verification), and the batch-start rule. Thresholds and pre-registrations may not be edited after the first run.

### 4.4 Derived boundary condition the matrix must expose (not a measurement)

At the DA-bound rate, one 2 s L2 block consumes `65,536 x 2 = 131,072` bytes = one blob (derived: 65,536 B/s x 2 s). A K-block batch therefore publishes up to **K blobs**:

    blobCount(K) <= K,  with equality when len(P) is blob-aligned    [derived]

EIP-7691 caps blobs at 6 target / 9 maximum **per L1 block**, and D5/L1-01 lands a batch's data and proof in **one** transaction. Consequence: at the DA-bound rate, **K > 9 is not publishable in a single `land` transaction**; the K = 32 and K = 128 cells remain necessary to measure cost and pipeline depth, but they are not simultaneously reachable with the DA-bound rate and one-transaction batches. The report MUST state, for every K: `blobCount`, `b_billed`, and whether `blobCount <= 9`. (Derived from EIP-4844 131,072 B/blob and EIP-7691 6/9, `spec/09-parameters.html` PARAM-02; confirm against L1-01/D5 with S3/S4.)

## 5. Metrics

| # | Quantity | Unit | How measured |
|---|---|---|---|
| M1 | `gasUsed` per batch | gas | sum over the K blocks from the fixture |
| M2 | `len(P)` per batch | bytes | length of the PRF-07(0) framing produced by the harness |
| M3 | `blobCount` per batch | count | `ceil(M2 / 131,072)`; recorded, not assumed |
| M4 | `b_payload`, `b_billed` | bytes/gas | §1 formulas |
| M5 | cycles per mode (E, E+C, E+C+B) | cycles | backend report: RISC Zero executor cycles; SP1 instruction count + `prover_gas` (metric exists from versions >= 4.1.4, `03-zkvm-feasibility.md` §2.2) |
| M6 | `C` | cycles/gas | `cycles(E) / M1` |
| M7 | `c_sig` | cycles/signature | slope of cycles(E+C) vs N over {67, 101, 133}; report the intercept too |
| M8 | `c_blob`, split into (a) keccak of 131,072 B, (b) canonicality+bit-reversal+field ops | cycles/blob | difference between m cells |
| M9 | blob share | % of batch cycles | `(cycles(E+C+B) - cycles(E+C)) / cycles(E+C+B)` at each K |
| M10 | `T_proof` | s | wall clock, per mode, from witness-ready to receipt; report p50/p95/max and the count |
| M11 | `R_gas` | gas/s per machine | `M1 / T_proof`, per backend and machine class |
| M12 | peak memory (host RSS, VRAM) | GiB | vendor tooling + OS counters |
| M13 | proof size | bytes | receipt/proof artifact |
| M14 | machine price `p_machine` | ETH/s | provider price page, URL + retrieval date + instance type |
| M15 | additivity residual | % | `abs(combined - sum) / combined` |

**Run metadata (every run, no exceptions).** Date/time and timezone; harness commit; backend and full crate/SDK version list; guest image ID or VKEY; guest build flags; proof mode; machine class (CPU model, core count, GPU model and count, VRAM, driver, CUDA version, RAM, disk); fixture digest and K/N/m; repetition index; measured or reported variance; the exact command line. Records with any missing field are discarded, not averaged.

## 6. Pass/fail

All gates are evaluated from the run manifest, not from judgement.

| Gate | Condition | Threshold |
|---|---|---|
| **G-RATE** (primary) | `R_fleet(N_MAX) = N_MAX x R_gas >= 65,536 / b_billed`, at ≥ 1 backend | yes/no |
| **G-FLEET** | required fleet `FLEET <= N_MAX` **and** monthly cost of `FLEET` machines `<= B_fleet` (both pre-registered) | yes/no |
| **G-BLOB** | blob share at K=32 | pass ≤ 5%; conditional 5–15%; fail > 15% |
| **G-VALID** (harness validity) | additivity residual ≤ 5%; cycle determinism holds; accelerator positive control passes; no cell discarded | yes/no |

Threshold rationale, fixed before the run: `N_MAX` and `B_fleet` are the fleet the project can actually provision and fund, so "affordable" is a recorded input rather than a post-hoc judgement. The 5% / 15% blob boundary is a *design* threshold: below 5% the blob half cannot move the fleet size by more than one machine in twenty; above 15% it can move it by more than one in seven, so it is no longer "a small fraction of the batch cost" in the sense of plan §1 S1. The 5% additivity residual is the tolerance within which the three-layer model is accepted as additive.

**Verdict rules.**
1. **PASS** iff G-VALID and G-RATE and G-FLEET hold, and G-BLOB is pass or conditional. On pass, register `b_billed` (per workload), `G_L2_TARGET = 65,536 / b_billed`, `C`, `R_gas`, and the K/latency curve; proceed to plan §8.5 parameter registration.
2. **FAIL (proving-limited)** iff G-VALID holds but G-RATE or G-FLEET fails. The report states `N* = ceil(G_L2_TARGET / R_gas)` and `c_prove` in ETH per L2 gas, and escalates the envelope choice to the user (plan §8.3): buy the fleet, or throttle L2 to the proving-bound rate `N_MAX x R_gas`, noting that the throttle caps the block gas limit, hence fee revenue, hence the D-8 security budget.
3. **FAIL (blob path)** iff G-BLOB is fail. The blob path is not usable at scale at the measured cost; the calldata path remains (plan §5), and S3 must restate the data budget and the cost curve for calldata. If G-BLOB is conditional, register the blob half as an explicit fleet-sizing term.
4. **INVALID** iff G-VALID fails. The measurement is not a result: fix the harness and re-run; do not report partial numbers.

**Escalation path if G-VALID cannot be made to hold within the schedule:** stop and redesign, per plan §3 G1 ("if not, the spike design is wrong, not the protocol").

## 7. Worked example of the arithmetic (symbolic; every symbol is a measured or pre-registered input)

Given one cell (backend, K, machine class) with `R` repetitions:

    gasUsed, len(P), blobCount = ceil(len(P) / 131072)
    cycles_E, cycles_EC, cycles_ECB, T_proof (median of R), peak_mem
    p_machine [ETH/s], N_MAX, B_fleet

Step 1 — per-gas and per-signature costs:

    C        = cycles_E / gasUsed                                  [cycles/gas]
    c_sig    = (cycles_EC(N=133) - cycles_EC(N=67)) / (133 - 67)   [cycles/signature]
    c_blob   = (cycles_ECB(m) - cycles_E) / m                      [cycles/blob]
    share_B  = (cycles_ECB - cycles_EC) / cycles_ECB               [fraction of batch cycles]

Step 2 — the headline:

    b_payload = len(P) / gasUsed
    b_billed  = 131072 * blobCount / gasUsed
    G_DA      = 65536 / b_billed                                   [gas/s, the DA-bound rate]

Step 3 — per-machine rate and fleet:

    R_gas     = gasUsed / T_proof                                  [gas/s per machine]
    N_star    = ceil(G_DA / R_gas)                                 [throughput-bound fleet]
    N_conc    = ceil(T_proof / (2 * K))                            [Little's law: L/Delta, 03 §10.1(6)-(8)]
    FLEET     = ceil(max(N_star, N_conc) * (1 + f_spare))          [f_spare pre-registered]
    R_fleet   = N_MAX * R_gas

Step 4 — the gate:

    G-RATE  holds  iff  R_fleet >= G_DA
    G-FLEET holds  iff  FLEET <= N_MAX  and  FLEET * p_machine * 2,592,000 <= B_fleet   [seconds per 30-day month]

Step 5 — cost per gas and the S3 handoff:

    c_prove = T_proof * N_units_used * p_machine / gasUsed          [ETH per L2 gas]
    F_break_even = c_prove / share_proving                          [ETH per L2 gas the protocol must fund]

S3 compares `F_break_even` against measured fee revenue per gas; a positive margin is S3's pass condition, not S1's. `N_conc` is reported beside `N_star` because at `T_proof` up to `T_PROOF_ENVELOPE` = 1,800 s (decided, D6) the fleet is concurrency-bound whenever `T_proof / (2K) > e * G_DA * C / R` — the structural point of `03-zkvm-feasibility.md` §10.1.

## 8. Risks, confounders, and what makes the measurement invalid

| Risk | Why it bites | Control |
|---|---|---|
| Accelerator silently dropped (keccak/sha2/Ed25519 patches not applied) | keccak drives state-root hashing; a software fallback inflates `C` by a large but unquantified factor | positive control: compare against the keccak-only cell and check the built dependency tree; record the lockfile |
| Wrong blob algorithm measured (coefficients instead of evaluations; bit-reversal omitted; O(n²) interpolation) | would produce a plausible but meaningless blob cost | mandatory negative controls in §3.1; the harness asserts the O(4,096) barycentric path |
| Workload transfer | b is workload-dependent; a single range may not represent the production mix | frozen fixture + the §4.1 sensitivity add-on; state explicitly that b does not transfer across mixes |
| Wall-clock variance from scheduling/thermals | GPU contention changes T_proof, not cycles | report p50/p95/max over ≥ 5 reps; report CV; a cell with CV > 20% is re-run |
| Nondeterminism between cycle counts of identical runs | guest/host nondeterminism (e.g., unordered maps in hints) | 3-run determinism check; any deviation is a finding |
| Wrap cost excluded from "cost per proof" | the L1 path needs the wrapped proof | proof-mode is an explicit matrix level; report unwrapped and wrapped separately |
| OOM / memory envelope | SP1 documents ~2 GB guest memory and 14 GB (Groth16) / 60 GB (PLONK) host memory for wrapping (03 §§3.2, 6.3) | record peak memory; an OOM cell is invalid, not failed |
| Fixture drift | a mutable source range makes runs incomparable | fixture digest in every run record; the manifest is committed before run 1 |
| Fleet realised rate < single-proof rate | queueing, retries, partial failures | the gate is explicitly a single-proof upper bound; sustained fleet throughput is a stated omission |

**Invalidity conditions (any one voids the run):** missing metadata; edited pre-registration; a cell without the determinism check; additivity residual > 5% without a documented cause; a fixture whose digest does not match the manifest.

**What would falsify the design decision this spike informs.** (i) G-RATE fails at every backend and every pre-registered fleet → the DA-bound throughput target of plan §8 is not achievable; the design is proving-limited and the §8.3 choice must be taken by the user. (ii) G-BLOB fails → `PRF-07(b)`'s in-guest evaluation is not affordable; blobs are dropped for calldata-only and the data budget is restated. (iii) `b_billed` measured large enough that `G_L2_TARGET` falls below the rate the rest of the design assumes — the target remains formally valid but its value must be re-registered before `D_MAX`, K and the fee model are derived from it.

## 9. Artifacts to commit and where

Under `packages/protocol/docs/Etna/pos-zk/phase-b/artifacts/S1/`:

| Artifact | Content |
|---|---|
| `manifest.json` | pre-registration (N_MAX, B_fleet, DR-1 dominance definition, batch-start rule) + one record per run with every field of §5 |
| `runs.csv` | machine-readable: one row per run; the column set of §5; the summary's single source of truth |
| `summary.json` | per-cell medians, p95s, variances, and the derived quantities of §7 (schema documented in `README.md`) |
| `fixture/` | the frozen workload manifest (hashes and per-block gas), plus either the payloads or a checksum plus a pinned retrieval location |
| `harness/` | the measurement guest and scripts, or a commit pointer to their repository plus the exact commit, build flags and lockfiles |
| `raw/<cell>/<rep>` | cycles reports, proof receipts/sizes, prover logs, `nvidia-smi`/`rocm-smi` captures, memory samples, timing logs |
| `report` | `phase-b/S1-proving-throughput-report.md` — the measurement report with versions, hardware, workload, method, date, variance, and the parameter values for re-derivation |

The report MUST include the omissions table of §3.5 and the `blobCount`/`K<=9` statement of §4.4.

## 10. Effort and skills (estimate, not a measurement)

| Item | Estimate | Basis |
|---|---|---|
| Harness (guest layers, modes, fixtures, controls) | 2–3 engineer-weeks | plan §3 puts the S1 harness in weeks 3–4 |
| Runs across both backends and K | 1–2 engineer-weeks; ≈ 200–400 proof runs *(derived: ~40 cells x 8 batches + repeats)* | GPU-hours cannot be stated before `T_proof` is measured — producing them is part of this spike's output |
| Analysis, artifacts, report | 1 engineer-week | — |
| **Total** | **4–6 engineer-weeks** for 2 engineers | consistent with plan §§3, 6 |

**Skill profile.** Rust and the RISC Zero and SP1 guest toolchains; EVM/reth internals and witness generation; zkVM benchmarking discipline (cycles vs wall clock, determinism); GPU node operations (drivers/CUDA, memory accounting); enough EIP-4844/PRF-07 knowledge to implement the blob half to the letter, including the evaluation-order convention and field-element canonicality. Statistical literacy for medians/percentiles and variance reporting.

**Hardware envelope (minimum for a valid run).** x86-64 Linux; for SP1 at least one GPU with ≥ 24 GB VRAM and compute capability ≥ 8.0 (documented minimum, `03-zkvm-feasibility.md` §10.2 M3); host RAM ≥ 64 GB if the PLONK wrap is measured (14 GB Groth16 / 60 GB PLONK documented, M2), ≥ 16 GB otherwise; ≥ 16 physical cores for the CPU baseline (M2); ≥ 1 TB NVMe for fixtures; 1 Gbit/s. RISC Zero publishes no per-machine number on the pages fetched (M4), so its machine class must be pinned by the run manifest and calibrated with the vendor's own datasheet example.
