# S4 — Blob binding: implementation, rejection tests, and independent cryptographic review

Status: **spike specification, not results** · Owner: S4 engineer · External reviewer: cryptographer (independent) · Date: 2026-10-05
Plan of record: [05-phase-b-plan.md](../05-phase-b-plan.md) §1 (S4), §3 (gates, sequence), §5 (kill criteria), §8 (the DA-bound target and §8.4)
Normative rules under test: [DA-03](../spec/04-l1-integration.html#DA-03) in full (whole-blob commitment, `BLOBHASH`, on-chain KZG opening, per-blob challenge, in-guest evaluation, the joint-event argument and its five premises) and [PRF-07(b)](../spec/05-proof-statement.html#PRF-07).
Prior evidence: [03-zkvm-feasibility.md](../03-zkvm-feasibility.md) §4 (no MSM/pairing acceleration established on either backend), §6–§7 (why the chosen binding avoids in-guest MSM and pairings; cost UNMEASURED — open item F2); [04-round.md](../iterations/04-round.md) R4-PB-05 (contract-side and guest-side challenge derivation had diverged; every honest blob batch would have failed to land).

**Pins.** Repo: commit `f9e5203d561cf9d50894247711496a664e5ac824`, branch `etna-pos-zk` (2026-10-05). Backends: **RISC Zero v3.0.6** (`risc0-zkvm` 3.0.6, `risc0-circuit-keccak` 4.0.6, `risc0-bigint2` 1.4.14, `rzup` 0.5.2 — [03-zkvm-feasibility.md](../03-zkvm-feasibility.md) §2.1) and **SP1 6.8.1** (`sp1-zkvm`/`sp1-lib` 6.8.1 — §2.2). On-chain: Foundry **1.8.3** (commit `cae51ad458f6abb64852b7709eb784352429825d`), **solc 0.8.30**, `evm_version = "osaka"` from [foundry.toml](../../../../foundry.toml) (Osaka includes the Cancun precompiles); forge-std **1.9.5**. EIP-4844 constants (*sourced*, EIP-4844): `FIELD_ELEMENTS_PER_BLOB = 4096`, 131,072 bytes per blob, point-evaluation precompile at `0x0A` costing **50,000 gas**, `BLS_MODULUS = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001`. Blob limits 6/9 (*sourced*, EIP-7691). The versioned-hash form is `0x01 ++ sha256(commitment)[1:]`.

**Number tags.** `sourced` (with source), `derived` (arithmetic shown), `hypothesis` (pre-registered and tested here), `unmeasured` (output of this spike). No cycle count, latency, or gas figure below is a result.

## 1. One-sentence purpose, and the parameters it fills

**Purpose.** Build the smallest honest end-to-end implementation of the chosen blob binding — a standalone guest that evaluates the interpolating polynomial of the executed blob at the challenge point in the EIP-4844 evaluation form with the bit-reversed setup convention, the on-chain `0x0A` point-evaluation check, and a rejection test proving a mismatched payload fails — then put the fixed-point argument, the Fiat–Shamir transcript, the contract/guest challenge identity, and the canonical field-element check in front of an independent cryptographer whose job is to break them.

| Register entry | Unit | What S4 closes | Owner |
|---|---|---|---|
| In-guest cost of the blob polynomial evaluation (DA-03) | cycles, seconds, memory | the `unmeasured` gate that decides whether the blob path is usable at scale or calldata is the only path ([09-parameters.html](../spec/09-parameters.html) PARAM-03) | S4 (+ S1 for the batch baseline) |
| `PRF-07(b)` fixed-point argument and its premises | — | proof-sketch → independently reviewed argument, or a named failure | S4 reviewer |
| Contract/guest challenge identity (DA-03(iii) vs PRF-07(b)(ii)) | — | the R4-PB-05 divergence risk | S4 harness |
| Canonical field-element rule (DA-03(iv)) | — | an ambiguity that would make two byte strings map to one polynomial | S4 harness + review |
| Blob-path usability → per-block data budget, `b`, `G_L2_TARGET`, K | bytes, gas/s | plan §4 row "In-guest blob evaluation cost" and §5 kill criteria | feeds S1/S3 and the D5 owner |

## 2. The question and the decision it unblocks

**Question.** Does the whole-blob commitment, on-chain challenge, KZG-opening and in-guest evaluation construction work end to end, and does it survive independent cryptographic review?

**Decision.** **Sound and reviewable → blobs are a usable path.** **Unsound or unreviewable → calldata-only**, which still satisfies D5 because the calldata path is unconditional ([DA-02](../spec/04-l1-integration.html#DA-02), [PRF-07(a)](../spec/05-proof-statement.html#PRF-07)). The spec text that changes is `PRF-07(b)`, `DA-03`, the `daMode` acceptance policy, the data budget, and the unmeasured register.

**The throughput consequence of a calldata-only outcome, stated with plan §8.** The DA ceiling is a byte budget bought with blob gas; calldata consumes L1 **execution** gas, so the ceiling does not merely shrink — its *shape* changes:

    blob-bound:      G_L2_TARGET = DA_bytes_per_l1_block · blobs_per_block_target / L1_slot_seconds / b
    calldata-bound:  G_L2_TARGET = (L1 execution gas available to data per second) / (calldata_gas_per_byte) / b

The second expression is set by the L1 block gas budget shared with verification, storage and every other transaction, and by the calldata byte price; it is not a fixed 786,432 bytes per L1 block and it cannot be bought at the blob market price. Plan §8.4's caveat becomes stronger, not weaker: the rate is exposed to L1 execution-gas congestion as well as to a blob market that no longer exists for this path. The report must state the ratio of the two expressions at the measured prices; if the calldata path is the only path, `G_L2_TARGET` and the block gas limit that follows from it are re-derived by S3's calldata cost curve.

**Falsifiers of the blob design decision** (any one ends the blob path):
1. A counterexample to the joint-event fixed-point argument, or an attack cheaper than `q · 4095/|F|` (*derived* below).
2. A transcript in which `z` does not depend on the whole committed payload, or in which contract and guest derivations can differ.
3. Any rejection test in §4 that accepts its invalid input.
4. A review that cannot evaluate the construction because a definition, encoding, or bound is missing or wrong.

## 3. Harness — what to build, what to reuse, what NOT to build

### 3.1 Build

1. **`blob-eval` guest (measurement artifact, both backends).** One Rust program per backend that: parses `n` blob byte strings as 4096 big-endian field elements each; rejects any element `≥ BLS_MODULUS`; applies the inverse bit-reversal permutation of the 12-bit index; interpolates the evaluations over the 4096th roots of unity; evaluates the polynomial at `z`; recomputes `keccak256(committedBytes)` and the [DA-03](../spec/04-l1-integration.html#DA-03)(0) `dataCommitment`; requires equality with the journal and `p_D(z) == y`. It reports guest cycles per phase and per blob, wall-clock, and peak memory. It is deliberately **not** the production guest (no EVM, no consensus half).
2. **`ChallengeLib.sol` + `challenge.rs` — the differential pair.** The Solidity derivation of `z_i` exactly as [DA-03](../spec/04-l1-integration.html#DA-03)(iii) fixes it, and an independent Rust re-implementation used by the guest, plus a differential test that generates N random journals (N ≥ 10,000, seed recorded) and asserts byte equality of every `z_i`, including the `% BLS_MODULUS` reduction and the `uint16(i)` encoding. This test exists to kill R4-PB-05's failure class: two encodings that "look the same" and make every honest batch unlandable.
3. **`PrecompileCheck.t.sol`.** Calls `0x0A` from a forge test under the pinned EVM with the 192-byte input `(versionedHash, z, y, commitment, proof)`; asserts success and the exact return `abi.encode(4096, BLS_MODULUS)`; measures the `gasleft()`/snapshot delta cold and warm; isolates the precompile's own **50,000 gas** (*sourced*) from the surrounding call overhead by a control measurement of the call overhead (cold account access, input/output memory, `STATICCALL`), and requires the arithmetic to close exactly.
4. **`Rejection.t.sol` and guest negative cases** (§4). Rejection is the security property; each case must fail closed at the layer that owns it (contract or guest), and the report records which layer rejected it.
5. **Fixture generator.** A pinned reference implementation of EIP-4844 (the `c-kzg-4844` line that RISC Zero patches is the documented one, `c-kzg` 2.1.5 per [03-zkvm-feasibility.md](../03-zkvm-feasibility.md) §4.1) generating valid `(blob, commitment, proof, z, y)` fixtures from a recorded seed and, where required, from the published EIP-4844 test vectors; the generator script, its resolved tag/commit, and SHA-256 of every fixture are committed. If a published vector set is used, its exact release tag is recorded — never "latest".

### 3.2 Reuse (pinned)

| Reused | Pin | Why it is legitimate |
|---|---|---|
| RISC Zero toolchain | v3.0.6 (`rzup` 0.5.2) | the pinned backend; `risc0-circuit-keccak` 4.0.6 accelerates the keccak that recompletes `dataCommitment` |
| SP1 toolchain | 6.8.1 | the pinned backend; `syscall_keccak_permute` for the same hash |
| accelerated bigint | `risc0-bigint2` 1.4.14; SP1 `sys_bigint` | the field arithmetic the Lagrange evaluation needs; measuring the *accelerated* path is the point (a pure-Rust fallback is measured as a second data point, never silently substituted) |
| EIP-4844 semantics | EIP-4844 text, retrieved 2026-10-05 in [03-zkvm-feasibility.md](../03-zkvm-feasibility.md) §6.1 | the field size, the 50,000 gas precompile, the versioned-hash form, the evaluation-form convention |
| `0x0A` on the pinned EVM | Foundry 1.8.3, `evm_version = "osaka"` | revm implements the Cancun precompiles at this spec; the test therefore measures the real precompile, not a mock |
| fixture library | `c-kzg-4844`, `c-kzg` 2.1.5 line | the same KZG implementation family the vendor patches; generates commitments and openings independently of the guest's field arithmetic |

### 3.3 Do NOT build

- **No production guest and no proof-statement integration.** The question is the blob half's cost, convention and reviewability; the EVM and consensus halves are S1's, and their cost is additive, not interacting.
- **No in-guest MSM, no in-guest pairing, no SRS loading.** [03-zkvm-feasibility.md](../03-zkvm-feasibility.md) §4/§6 found MSM/pairing acceleration UNVERIFIED on both backends; the design deliberately puts the pairing on L1. The RISC Zero patched `c-kzg` in-guest route (candidate A) is a *fallback* and would be a different spike with a larger TCB.
- **No recursion or aggregation.** PRF-12's constraints make aggregation optional; it adds serial latency and TCB for no answer this spike needs.
- **No production verifier deployment and no gas optimization.** The on-chain check is the precompile call; the surrounding contract cost belongs to S3.
- **No new cryptographic construction.** The harness implements the specification as written. If the reviewer wants a change, the change is a spec edit, and the harness is re-run.

*Why these shortcuts are legitimate.* The blob binding's cost and correctness are local to: parsing and canonicality of field elements, bit-reversal plus interpolation over the roots of unity, one keccak over the committed bytes, and one precompile call. None of those depends on execution or consensus. The report nevertheless states that the measured cost is **incremental** and must be added to S1's batch cost, not quoted as a batch cost.

### 3.4 The candidate conventions that must be distinguished

| # | Convention | Correct per EIP-4844? | Test |
|---|---|---|---|
| V1 | element `j` is the evaluation at `ω^j` | **no** — the blob is in bit-reversed order | must fail the fixture (`p(z) != y`) |
| V2 | element `j` is the evaluation at `ω^{brp(j)}` (`brp` = 12-bit bit-reversal) | **yes** | must equal the fixture's KZG evaluation |
| V3 | elements are coefficients of `p(X)` | **no** | must fail |
| V4 | inverse bit-reversal then Lagrange over evaluations | equivalent to V2 | must equal V2 byte-for-byte in the differential test |

The report must show the V1/V3 failures explicitly; "the guest implements the right convention" is not evidence unless the wrong ones are shown to fail.

### 3.5 The review protocol (external cryptographer)

The reviewer receives a frozen, self-contained bundle: [DA-03](../spec/04-l1-integration.html#DA-03) and [PRF-07](../spec/05-proof-statement.html#PRF-07) verbatim; the transcript preimage and its exact byte encodings; the differential test; the fixture generator; the harness sources; the pinned versions; and the list of claims below. Output is a written finding per claim: **broken** (with a counterexample or attack), **not broken within the stated model** (with the model stated), or **not evaluable** (with the missing definition named). A claim may not be marked "not broken" without a stated attack model. The review is time-boxed (see §10) and any claim left unreviewed at the box is recorded as such, which fails the reviewability gate.

**Claims to attack (the mandatory scope).**

1. **The joint-event fixed-point argument.** That `z_i` is a deterministic function of the transcript containing `dataCommitment = f(keccak(D))` and `blobHashesHash`, so a cheating prover needs `p_D(z(D)) = p_B(z(D))` — a fixed-point condition, not a linear equation in the free part of `D`; that the union bound over payload searches is `q · deg/|F|`; that `D` is not free because the certified header chain fixes the transactions ([PRF-04](../spec/05-proof-statement.html#PRF-04)(v), [PRF-06](../spec/05-proof-statement.html#PRF-06)); and that the bound is unaffected by the `% BLS_MODULUS` reduction (the reviewer must recompute the reduction term, not accept it — see §7 and R6).
2. **The Fiat–Shamir transcript.** That the preimage `("TAIKO_ETNA_CHALLENGE", l2ChainId, statementCoreHash, dataCommitment, blobHashesHash, uint16(i))` commits everything load-bearing, including the committed bytes (`dataCommitment`) and the ordered blob set (`blobHashesHash`); that excluding `challengeZ`/`challengeY` from `statementCoreHash` is well-defined (no circularity) and covers every other journal field; that `abi.encode` leaves no ambiguity between fields; that the per-blob index is bound; and that no field an attacker can vary after `z` is fixed is left out.
3. **Contract/guest identity.** That the contract's derivation ([DA-03](../spec/04-l1-integration.html#DA-03)(iii), [L1-05](../spec/04-l1-integration.html#L1-05) row 18) and the guest's recomputation are the same byte-for-byte function, including the modulus reduction, the integer widths, and the encoding of `i`; the differential test is the evidence.
4. **The canonical field-element check.** That rejecting any element `≥ BLS_MODULUS` (in the blob bytes and in every field element the guest constructs) is sufficient to make the byte string → polynomial map injective, and that the precompile's own rejection of non-canonical `z`/`y` is relied on only where it is documented.
5. **Whether a cheaper attack exists.** Specifically: committing a prefix or a free suffix; choosing `D` after seeing `z` (closed by the transcript, but the reviewer must attempt to construct a two-message or re-entrant game); two blobs sharing a challenge (index binding); substituting another transaction's blobs (closed by `BLOBHASH` being transaction-scoped); grinding the certificate (the header chain binds `D`); replaying a valid proof for a different blob set; exploiting the `q`-search bound's assumptions; and any attack that avoids the KZG binding entirely.

## 4. Experiment matrix

**Independent variables.**

| Variable | Values | Notes |
|---|---|---|
| backend | RISC Zero v3.0.6; SP1 6.8.1 | both are required by `PRF-09` for the statement |
| blobs per batch `n` | 1, 2, 4, 9 | 9 is the EIP-7691 maximum per transaction |
| field-arithmetic path | accelerated bigint (primary); pure-Rust fallback (secondary) | the fallback exists to expose the cost of a dropped accelerator; it is never reported as the primary number |
| payload boundary | `P` ends before the last blob (zero remainder); `P` ends at the last byte of the last blob | tests "the unused remainder is committed too" ([DA-03](../spec/04-l1-integration.html#DA-03)(0)) |
| convention | V2/V4 correct; V1 and V3 wrong (expectation: reject) | §3.4 |
| differential journals | 10,000 random journals, fixed seed | contract vs guest `z_i` equality |
| review claims | the five claims of §3.5 | one finding per claim per reviewer |

**Fixed workload.** `n` blobs of exactly 131,072 bytes; 4096 canonical field elements per blob from a recorded seed; `P` is the [PRF-07](../spec/05-proof-statement.html#PRF-07)(0) framing over K frames (K is not the variable here; the payload is a fixed byte string whose length and boundaries are recorded) followed by zero padding to the end of the last blob. The fixture generator's output, seed, and SHA-256 hashes are frozen before the first run.

**Repetitions.** Five guest runs per (backend, n, arithmetic path) cell; cycles should be deterministic, so any spread is recorded as a defect; wall-clock and memory are reported with min/median/max. The differential test is one run of 10,000 journals plus a re-run with a second seed.

### 4.1 Rejection cases (each must reject, at the named layer)

| Case | Invalid input | Owning layer |
|---|---|---|
| RC-1 | executed payload `D` differs from the blob by one byte (and the guest recompletes `dataCommitment` honestly) | guest: `p_D(z) != y` |
| RC-2 | a blob element `≥ BLS_MODULUS` | guest canonicality check |
| RC-3 | elements treated as coefficients (V3) or without bit-reversal (V1) | guest: evaluation disagrees with the fixture |
| RC-4 | commitment does not match the versioned hash | contract: precompile reverts |
| RC-5 | opening proof is for a different `(z, y)` | contract: precompile reverts |
| RC-6 | guest-computed `dataCommitment` differs from the journal value used to derive `z` | guest: equality check |
| RC-7 | challenge recomputed by the guest differs from the contract's | differential test (S2 gate) |
| RC-8 | a second blob of the batch reuses the first blob's `z` (index not bound) | contract/guest: challenge includes `uint16(i)` |
| RC-9 | blob slot has no blob in this transaction (`blobhash(i) == 0`) | contract: `BlobHashMismatch(i)` |

## 5. Metrics

| Quantity | Unit | How measured |
|---|---|---|
| parse + canonicality cycles | cycles | guest-reported cycles per phase, per blob |
| bit-reversal + interpolation + evaluation cycles | cycles | same; also per element (`/4096`) |
| keccak cycles for `keccak256(committedBytes)` | cycles | same, per blob |
| total blob-path guest cycles | cycles | per n; the incremental figure to add to S1's batch cost |
| wall-clock per blob and per n | seconds | measured on the stated machine; excludes wrap unless the wrap is run |
| peak memory | MiB | guest/toolchain-reported; compared with SP1's documented ~2 GB zkVM memory limit ([03-zkvm-feasibility.md](../03-zkvm-feasibility.md) §6.3) |
| contract-side challenge gas (marginal) | gas | differential harness; the marginal cost of deriving one more `z_i` |
| precompile call cost | gas | measured total delta cold and warm, split into the sourced 50,000 and the measured call overhead |
| rejection outcomes | pass/fail per case | §4.1; the rejecting layer is recorded |
| differential equality | count mismatches / 10,000 | the contract/guest test |
| review findings | per claim | broken / not broken (model stated) / not evaluable, with the reviewer's name and date |
| derived share of batch cost | % | `n · cycles_per_blob / cycles_S1_batch` once S1 lands; otherwise `n · cycles_per_blob / R` seconds against the 1,800 s envelope |

**Run metadata (plan §2):** repo commit; both backend versions and the exact accelerator crates; GPU model/count and driver (SP1 documents 24 GB+ VRAM, compute capability ≥ 8.0, [03-zkvm-feasibility.md](../03-zkvm-feasibility.md) §10.2 M3; RISC Zero publishes no minimum, M4 — record exactly what was used); CPU/RAM; fixture hashes; commands; date/time; repetitions and variance. Cycles measured without a GPU must say so.

## 6. Pass/fail

| # | Gate | Pass condition (mechanically checkable) | If it fails |
|---|---|---|---|
| S1 | **Soundness (implementation)** | Every §4.1 rejection case rejects, at the layer that owns it; the V1 and V3 convention cases fail; the correct-convention cases pass on both backends | Blobs are not usable as implemented; fix the harness if the defect is local, otherwise the design |
| S2 | **Contract/guest identity** | Zero mismatches over 10,000 random journals, both seeds, including the modulus reduction and `uint16(i)` | Any mismatch reproduces R4-PB-05's class: every honest blob batch fails to land. Blob path blocked until fixed and re-run |
| S3 | **Cryptographic review: sound** | No claim of §3.5 is marked **broken**, and no claim is left **not evaluable** | Blob path unsound or unreviewable → **calldata-only**; register the residual and restate the data budget |
| S4 | **Cryptographic review: reachable** | The reviewer completes all five claims within the time-box, and states for each the attack model | A design that cannot be evaluated in the box is not reviewable; same routing as S3 |
| S5 | **Cost (pre-registered hypothesis)** | With `T_PROOF_ENVELOPE = 1,800` s (*decided*, D6) and the pre-registered share `σ = 0.05` (*hypothesis*): the measured blob-evaluation time for n = 9 satisfies `t_blob(9) ≤ σ · T_PROOF_ENVELOPE = 90` s on the measured machine. If S1 has landed, the binding form is `n · t_blob(n=1) ≤ σ · t_batch(S1)` and the envelope form is secondary | The blob evaluation consumes a material share of the proving budget; the choice is calldata-only, or the RISC Zero patched-`c-kzg` candidate (A) is measured as a separate spike. Do not silently shrink σ |
| S6 | **On-chain check holds the sourced constant** | Measured precompile component equals **50,000 gas** (*sourced*) and the return equals `abi.encode(4096, BLS_MODULUS)` on the pinned EVM | The pinned EVM and mainnet disagree; escalate as a version/`evm_version` finding before any gas number is used |

*Falsification.* S1 or S3 failing falsifies "the blob binding is sound and reviewable", which is the design decision D5's blob path rests on. S5 failing does not falsify soundness; it falsifies "the blob path is usable at the target rate" and moves the decision to the calldata-only branch with the plan §8 consequence stated in §2.

## 7. Worked example of the arithmetic the engineer will do (symbolic only)

**The evaluation itself.** Let `ω` be a primitive 4096th root of unity, `n = 4096`, `brp(j)` the 12-bit bit-reversal of `j`, and `y_j` the `j`-th big-endian field element of the committed blob. In the EIP-4844 convention the evaluation points are `x_j = ω^{brp(j)}`, and

    p_D(z) = Σ_j y_j · L_j(z),      L_j(z) = Π_{k≠j} (z − x_k) / (x_j − x_k)

For roots of unity this reduces to the form the harness must implement:

    L_j(z) = (z^n − 1) · x_j / ( n · (z − x_j) )
    p_D(z) = ((z^n − 1) / n) · Σ_j  y_j · x_j / (z − x_j)

so the guest needs one exponentiation `z^n`, `n` inversions (batchable to one inversion plus `3(n−1)` multiplications by Montgomery's trick), and `O(n)` multiplications/additions in `F_r`. The measured cycle count is modelled as

    cycles_blob = c_parse + c_canon + c_brp + c_pow + c_batchinv + n·(c_mul + c_add) + c_keccak(131,072)

with every `c_*` taken from the run, never assumed. The derived cost share is

    σ_measured = n · cycles_blob / cycles_batch(S1)          (compare with the pre-registered σ = 0.05)

**The probability bound.** For any fixed payload `D`, `(p_D − p_B)` is a non-zero polynomial of degree ≤ 4095, so it has at most 4095 roots and

    Pr[ p_D(z(D)) = p_B(z(D)) ]  ≤  deg / |F|  ≈  4095 / BLS_MODULUS  ≈  2^12 / 2^254.86  ≈  2^-243

and a search over `q` candidate payloads wins with probability at most `q · 2^-243`. The reviewer must recompute `|F|` and the exponent from the modulus above.

**The reduction term the review must fix, not inherit.** [DA-03](../spec/04-l1-integration.html#DA-03)(iii) states that the `% BLS_MODULUS` reduction "biases the distribution by at most `BLS_MODULUS / 2^256 ≈ 2^-127` in statistical distance". That ratio does not follow arithmetically: `BLS_MODULUS ≈ 2^254.86`, so `BLS_MODULUS / 2^256 ≈ 2^-1.14`, not `2^-127`. The correct per-value statement is `Pr[Z = z] ≤ ceil(2^256 / p) / 2^256 ≈ 1/p + 2^-256`, so the union bound over ≤ 4095 roots is still `≈ 2^-243` and the headline bound stands; only the "statistical distance = 2^-127" sentence is wrong and must be corrected or deleted in the specification. This is a required review output, not an optional observation.

**On-chain check.** With `cold = 2,600` gas (*sourced*, EIP-2929 cold account access) plus the measured input-memory cost `c_mem` and call overhead:

    gas_call_measured  = 50,000 (precompile, sourced) + cold + c_mem + overhead
    require: gas_call_measured − (cold + c_mem + overhead) == 50,000     (S6)

No symbol above may be replaced by a number this spike did not measure or cite.

## 8. Risks, confounders, and what would make the measurement invalid

| # | Risk | Effect | Control |
|---|---|---|---|
| R1 | Fixture commitment/proof generated under a different SRS or convention than mainnet | the guest could agree with a local fixture while disagreeing with L1 | fixtures are checked by the real `0x0A` precompile in the same test, which enforces `kzg_to_versioned_hash(commitment) == vh` and the opening |
| R2 | Wrong bit-reversal or endianness | all honest blob batches fail (the V1/V3 tests exist to catch it); or a wrong polynomial is proven | V1–V4 matrix; differential test against the reference library's evaluation |
| R3 | Accelerated arithmetic is dropped silently (e.g., a missing crate patch) | the primary number becomes a software number | record resolved dependency versions in the run metadata; run the fallback path explicitly and label both |
| R4 | Guest measures single-blob cost and extrapolates linearly to n = 9 | wrong incremental cost if there are per-run fixed costs or memory effects | n ∈ {1, 2, 4, 9} measured, not extrapolated |
| R5 | Review is time-boxed and a claim is left unread | the "sound" gate passes without evaluation | S4 requires every claim classified; unreviewed = **not evaluable** = fail |
| R6 | The specification's own numeric claims are accepted on trust | a wrong bound ships with a "reviewed" label | the reviewer must recompute every numeric claim in [DA-03](../spec/04-l1-integration.html#DA-03) and [PRF-07](../spec/05-proof-statement.html#PRF-07); the `2^-127` sentence (§7) is the pre-identified instance |
| R7 | `z` equals an evaluation point `x_j` (measure-zero event) | division by zero or an implementation trap | the harness defines the behaviour explicitly and tests it with a constructed `z = x_j` |
| R8 | Reviewer's model differs from the protocol's (ROM, KZG binding, canonicality) | a "not broken" verdict for the wrong game | §3.5 requires the model to be stated per claim; the premises are taken verbatim from [DA-03](../spec/04-l1-integration.html#DA-03) |
| R9 | The spike's guest is not the production guest | the measured cost is not the production cost | the report labels it incremental and names every omitted part (EVM, consensus, journal encoding, wrap) |
| R10 | The pinned EVM (`osaka`) and mainnet's current fork differ on the precompile | S6 passes locally and fails in production, or vice versa | record the pinned `evm_version`; S6 states the comparison to mainnet as a separate, owner-named check |
| R11 | Contract-side and guest-side hashing differ only in an untested corner (e.g., `i ≥ 2^16`, empty blob set, `daMode = 3`) | R4-PB-05 recurs | the differential matrix includes boundary journals: n = 0 (invalid), n = 9, `i = 0` and `i = 8`, hybrid mode |

**Invalidating conditions.** The measurement is invalid if: the fixtures were generated by the same code being tested; the precompile call is mocked or `vm.etch`-ed; the guest's field arithmetic is not the pinned backend's; a cycle count is reported without the resolved dependency versions; or a review finding is recorded without the attack model.

## 9. Artifacts to commit and where

Root: `packages/protocol/docs/Etna/pos-zk/phase-b/artifacts/S4/` (created on first run).

| Path | Content |
|---|---|
| `guest-risc0/`, `guest-sp1/` | the measurement guest sources, the frozen lockfiles, the exact build commands, per-run cycle logs |
| `fixtures/` | blob bytes, commitments, proofs, `z`, `y`, expected evaluations, seed, generator script and its resolved tag/commit, SHA-256 of every fixture |
| `challenge-differential/` | `ChallengeLib.sol`, `challenge.rs`, the 10,000-journal test and both seeds |
| `forge/` | `PrecompileCheck.t.sol`, `Rejection.t.sol`, the convention matrix, gas snapshots, the control measurement |
| `review/` | the frozen review bundle, the claim list, the per-claim findings, the reviewer's name and date, the time-box record |
| `raw/` | unedited run logs, five repetitions per cell, memory and cycle traces |
| `summary.csv`, `summary.json` | the metrics of §5 in the [report-template.md](./report-template.md) shape |
| `report.md` | the filled [report-template.md](./report-template.md) |
| `spec-findings.md` | every defect found in [DA-03](../spec/04-l1-integration.html#DA-03)/[PRF-07](../spec/05-proof-statement.html#PRF-07) while building (including the §7 reduction-bias arithmetic), each with the exact rule and proposed correction |
| `falsifiers.md` | the §2 falsifiers with their observed status |

Raw files are write-once; the review bundle is hashed before it is handed over and the hash is recorded in `review/`.

## 10. Effort estimate and skill profile (estimate, not a measurement)

**Estimate: 15 working days for one engineer, plus 3 weeks elapsed for the external cryptographer** (the review can start only after the bundle is frozen, and it is the only Phase B workstream whose completion depends on someone outside the team — plan §6).

| Phase | Days | Work |
|---|---|---|
| Fixture + reference generation | 2–3 | pinned `c-kzg` line, seeds, vector checks, hashes |
| Guest on both backends | 5–6 | parse/canonicality, bit-reversal, Lagrange, keccak, cycles/memory, n ∈ {1,2,4,9} |
| Differential + precompile + rejection tests | 3–4 | `ChallengeLib.sol`/`challenge.rs`, 10k journals, `0x0A` split, V1–V4 and boundary cases |
| Bundle + review support | 2–3 | freeze, hash, hand over, answer reviewer questions, adjudicate findings |
| Report | 2 | fill the template, spec findings, falsifiers |

**Skill profile.** One Rust engineer with zkVM experience (guest build, cycle profiling, accelerator crates) and enough Solidity/Foundry to write the challenge library and precompile tests. The reviewer must be an **independent cryptographer** with polynomial-commitment and Fiat–Shamir experience, given the bundle and no stake in the design; a vendor engineer or anyone who authored the construction does not satisfy "independent". Neither role requires production-guest work.

