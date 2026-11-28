# zkVM Feasibility — Raw Research Notes

**Target:** `Etna PoS + ZK` (Taiko L2 redesign) — permissionless L2 PoS finalizing blocks every ~2 s; L1 accepts an L2 batch **only if** batch data **and** a zkVM validity proof land in the **same L1 transaction** (no data-first path).

**Question:** can **RISC Zero** and **SP1** prove, in one guest or two composed proofs, (W1) L2 PoS finality (a ≥2/3-stake quorum certificate over chain id / validator-set version / height / block hash, anchored to an L1-authoritative validator-set commitment, plus epoch transitions) **and** (W2) correct EVM execution from the last L1-accepted state root?

**Retrieval date for every external claim below: 2026-10-05.**
**Evidence rule applied:** every version, size, gas figure, benchmark and cryptographic claim is traced to a URL that was actually fetched. Anything not so traced is explicitly marked **UNVERIFIED**. No cycle counts, GPU throughput, proving costs or latencies have been invented.

> ⚠️ This is a *raw* evidence file. Section 10 separates what is known in principle from what is measured, what is estimated, and what is simply unknown.

---

## 0. Obligation decomposition (why the crypto matrix matters)

| Obligation | What the guest must do | Primitives required |
|---|---|---|
| **W1a** — Bind the authoritative validator set | Recompute/verify the validator-set commitment against a value that the **L1 contract supplies as a public input** (never a prover-supplied witness) | keccak256 (SSZ/MPT or a custom tree), sha256 (if SSZ), possible bn254/bigint for tree math |
| **W1b** — Verify the quorum certificate | Verify ≥2/3 of TAIKO stake signed `(chain_id, epoch, height, block_hash)` | **secp256k1 ECDSA** (typical for an Ethereum-adjacent validator set) or **Ed25519**; stake-weighted aggregation; keccak/sha256 over the signing root |
| **W1c** — Epoch / reconfiguration transitions | Walk validator-set versions across the batch range | hashing + bitfield/stake accumulation, bigint for stake arithmetic |
| **W2** — EVM execution | Execute L2 blocks, produce the post-state root and receipts | keccak256 (MPT/trie + EVM), secp256k1 **recover** (tx sender), bn254/modexp if EVM precompiles must match, bigint |
| **(optional) DA binding** | Bind the blob **versioned hash** to the blob data | sha256 + **BLS12-381 KZG commitment** (MSM over 4096 elements) or a KZG opening check |

Two structural facts drive the whole study:

1. **Neither zkVM can establish that a validator set is "authoritative."** Authoritativeness is an *L1-state* fact. It must enter the guest as a public input derived by the L1 verifier contract, or be committed on L1 and read by the guest. A prover-supplied witness may never define the set.
2. **Blob data must be bound to the protocol's KZG commitment, not to a keccak hash of the data.** A keccak hash proves "I saw these bytes"; only the KZG commitment is what the L1 `BLOBHASH`/versioned-hash value commits to. See §4.

---

## 1. Version pin record

### 1.1 RISC Zero

Verified against the crates.io API, the GitHub releases API, and the raw `Cargo.toml` **at tag `v3.0.6`**.

| Item | Pinned value | How verified |
|---|---|---|
| Latest **stable** release tag | **`v3.0.6`, published 2026-07-17** | [GitHub releases API (risc0/risc0)](https://api.github.com/repos/risc0/risc0/releases) |
| `risc0-zkvm` crate | **3.0.6** (`max_stable_version`); `max_version` = `5.0.0-rc.1`; 91 versions total | [crates.io API](https://crates.io/api/v1/crates/risc0-zkvm) |
| Prerelease | **`v5.0.0-rc.1`, published 2026-01-15** — GitHub release body is **empty**, so what it contains is **UNVERIFIED** | [GitHub releases API](https://api.github.com/repos/risc0/risc0/releases) |
| Workspace version at `v3.0.6` | `[workspace.package] version = "3.0.0"` | [raw Cargo.toml @v3.0.6](https://raw.githubusercontent.com/risc0/risc0/v3.0.6/Cargo.toml) |
| `risc0-build` | 3.0.6 | same |
| `risc0-zkp` | 3.0.5 | same |
| **`risc0-circuit-rv32im`** (RISC-V circuit) | **4.0.5** | same |
| **`risc0-circuit-recursion`** (recursion circuit) | **4.0.5** | same |
| **`risc0-circuit-keccak`** (dedicated Keccak circuit) | **4.0.6** | same |
| `risc0-groth16` (STARK→SNARK) | 3.0.5 | same |
| `risc0-bigint2` | 1.4.14 | same |
| `risc0-zkos-v1compat` | 2.2.3 | same |
| `rzup` toolchain manager | 0.5.2 | same |
| Verifier contracts repo | **risc0-ethereum `v3.0.1`, published 2025-11-06** | [GitHub releases API](https://api.github.com/repos/risc0/risc0-ethereum/releases) |
| Mainnet verifier **router** | `0x8EaB2D97Dfce405A1692a21b3ff3A172d593D319` | [deployment.toml @v3.0.1](https://raw.githubusercontent.com/risc0/risc0-ethereum/v3.0.1/contracts/deployment.toml) |
| Mainnet router admin timelock | 259200 s (3 days) | same |
| Deployed Groth16 verifier versions + **selectors** | 1.1.0-rc.3 `0x50bd1769`; 1.2.0 `0xc101b42b`; 2.0.0-rc.3 `0x9f39696c` (**stopped**); 2.1.0 `0xf536085a` (**stopped**); 2.2.0 `0xbb001d44`; **3.0.0 `0x73c457ba`** | same |
| Docs site version | `dev.risczero.com` serves versions `1.0 … 3.0` plus `Next`; **3.0 is "latest"**, `Next` is unreleased | [sitemap](https://dev.risczero.com/sitemap.xml) + page banner |
| Verifier architecture | base verifiers are **stateless + immutable**; `RiscZeroVerifierRouter` routes on a 4-byte selector; each implementation has a `RiscZeroVerifierEmergencyStop` proxy; selector derived from a hash of label + params (**Groth16 vkey + control root**) | [version-management-design.md](https://raw.githubusercontent.com/risc0/risc0-ethereum/release-1.0/contracts/version-management-design.md) |

**Circuit-version semantics (important).** RISC Zero separates the *program image ID* (hash of the guest ELF) from the **control root** — the set of allowed recursion programs (`lift`, `join`, `resolve`, `identity_p254`), each identified by a control ID. The control root is **hard-coded into the on-chain verifier contract** and is also passed as a public input to the STARK→SNARK circuit, *"allowing for updates to our RISC-V Prover without requiring a new trusted setup ceremony."* Sources: [security-model](https://dev.risczero.com/api/next/security-model), [recursion](https://dev.risczero.com/api/next/recursion).

### 1.2 SP1

| Item | Pinned value | How verified |
|---|---|---|
| Latest release tag | **`v6.8.1`, published 2026-09-24** | [GitHub releases API](https://api.github.com/repos/succinctlabs/sp1/releases?per_page=5) |
| Recent release cadence | v6.5.0 (2026-08-26), v6.6.0 (2026-09-02), v6.7.0 (2026-09-07), v6.8.0 (2026-09-11), v6.8.1 (2026-09-24) — **5 releases in 29 days** | same |
| `sp1-zkvm` crate | **6.8.1** (`max_stable_version`, updated 2026-09-24; 69 versions) | [crates.io API](https://crates.io/api/v1/crates/sp1-zkvm) |
| `sp1-lib` | **6.8.1** (published 2026-09-24) | [docs.rs sp1-lib](https://docs.rs/sp1-lib/latest/sp1_lib/) |
| Verifier contracts repo | **sp1-contracts `v6.1.1`, published 2026-04-28** (v6.1.0 2026-04-15; v6.0.0 2026-02-18) | [GitHub releases API](https://api.github.com/repos/succinctlabs/sp1-contracts/releases) |
| **Officially supported versions (documentation)** | *"The current officially supported versions of SP1 are V5.x.y and V6.1.0 (Hypercube)."* | [contract-addresses](https://docs.succinct.xyz/docs/sp1/verification/contract-addresses) |
| Mainnet **Groth16** gateway | `0x397A5f7f3dBd538f23DE225B51f532c34448dA9B` | same + [deployments/1.json @v6.1.1](https://raw.githubusercontent.com/succinctlabs/sp1-contracts/v6.1.1/contracts/deployments/1.json) |
| Mainnet **PLONK** gateway | `0x3B6041173B80E77f038f3F2C0f9744f04837185e` | same |
| Per-version mainnet verifiers | V5_0_0 Groth16 `0x50ACFBE…` / PLONK `0x0459d5…`; V6_0_0 Groth16 `0x99A74A…` / PLONK `0x8a0fd5…`; **V6_1_0 Groth16 `0xb69f2584…` / PLONK `0xc3c6dDDA…`** | [deployments/1.json @v6.1.1](https://raw.githubusercontent.com/succinctlabs/sp1-contracts/v6.1.1/contracts/deployments/1.json) |
| Gateway route additions | `safe-batches/1_add-route_v6_0_0.json`, `1_add-route_v6_1_0.json` | [sp1-contracts tree @v6.1.1](https://api.github.com/repos/succinctlabs/sp1-contracts/git/trees/v6.1.1?recursive=1) |
| Proving modes | `core` (STARK, size ∝ execution), `compressed` (constant-size STARK, recursively verifiable **inside SP1**), `plonk` (~868 bytes SNARK), `groth16` (~260 bytes SNARK) | [proof-types](https://docs.succinct.xyz/docs/sp1/generating-proofs/proof-types) |
| SP1 Hypercube | Shards of ~**2^22 RISC-V instructions**; sub-protocols Zerocheck, **Jagged PCS** ([eprint 2025/917](https://eprint.iacr.org/2025/917)), LogUp GKR ([2023/1284](https://eprint.iacr.org/2023/1284)), Basefold ([2024/1571](https://eprint.iacr.org/2024/1571)); shard proofs recursively aggregated | [hypercube intro](https://docs.succinct.xyz/docs/sp1/hypercube/) |
| Prover-gas metric | introduced in versions **>= 4.1.4** | [prover-gas](https://docs.succinct.xyz/docs/sp1/optimizing-programs/prover-gas) |

**Version-skew flag (unresolved).** The canonical mainnet deployment exposes a **V6.1.0** verifier, and the docs page states V5.x.y / V6.1.0 are the supported versions, while the SDK/crates are at **6.8.1**. The precise mechanism mapping an SP1 release to a verifier version / VKEY is **UNVERIFIED** — this is a real integration hazard for a long-lived L1 verifier (§8).

### 1.3 Could not verify

| Item | Status |
|---|---|
| Contents of RISC Zero `v5.0.0-rc.1` (empty release body; no docs version mapped to 5.x) | **UNVERIFIED** |
| Which SP1 SDK version the canonical mainnet `V6.1.0` verifier actually accepts, and the release→VKEY mapping | **UNVERIFIED** |
| RISC Zero circuit **identity hashes** (control IDs / control root values) for v3.0.6 | **UNVERIFIED** (not published on the pages fetched) |
| Exact verifier **gas** for RISC Zero Groth16 on Ethereum from an official source | **UNVERIFIED** (no official number found; §2.3) |
| Whether the `5.0.0-rc.1` circuit line changes the crypto precompile set | **UNVERIFIED** |

---

## 2. Trusted setup and cryptographic assumptions

### 2.1 RISC Zero

| Property | Finding | Source |
|---|---|---|
| Proof system | STARKs for the RISC-V circuit and the recursion circuit; an **R1CS STARK→SNARK circuit** verifies recursion proofs | [recursion](https://dev.risczero.com/api/next/recursion) |
| STARK-only mode | Yes — `ReceiptKind::Composite` / `Succinct`; a `SuccinctReceipt` is a **STARK of ~200 kB** | [recursion](https://dev.risczero.com/api/next/recursion), [shrink-wrapping](https://dev.risczero.com/api/next/blockchain-integration/shrink-wrapping) |
| Wrapped SNARK | **Groth16** is *"the only currently officially supported shrink-wrapping type"* | [shrink-wrapping](https://dev.risczero.com/api/next/blockchain-integration/shrink-wrapping) |
| Trusted setup | **Circuit-specific Groth16 ceremony** run on **PSE's ceremony infrastructure** (`ceremony.pse.dev`, "RISC Zero STARK-to-SNARK Prover" page). Circuit = `stark_verify.circom` + `risc0.circom`; Powers of Tau = **Hermez rollup, 2^23 powers**; reference `r1cs` SHA-256 = `84d3c34b7c0eb55ad1b16b24f75e0b9de307f7b74089ea4a20a998390ee24178`; verified with circom **v2.2.2** + snarkjs | [trusted-setup-ceremony](https://dev.risczero.com/api/next/trusted-setup-ceremony) |
| What the setup secures | *"This ceremony secures our STARK Verify circuit so we can publish Groth16 receipts for our general purpose zkVM to limited-memory environments like blockchains."* | same |
| Ceremony **participant count** | **UNVERIFIED** (page describes verification procedure; I did not fetch a participant list) | — |
| Post-quantum | STARK side is hash-based (transparent, plausibly PQ-relevant); **Groth16 wrap is not** — it inherits the ceremony assumption. No vendor PQ claim was fetched → **UNVERIFIED** as a vendor statement | — |
| Recursion / aggregation | `lift` → `join` (pairwise) → `resolve` (assumption removal) → `identity_p254` → `compress()` → `Groth16Receipt` | [recursion](https://dev.risczero.com/api/next/recursion) |
| Conjectured security | *"With default parameters, this system achieves perfect zero-knowledgeness and 98 bits of conjectured security."* | [README @v3.0.6](https://raw.githubusercontent.com/risc0/risc0/v3.0.6/README.md) |
| Zero-knowledge caveat | *"we have not written a mathematical argument to prove that our system is zero-knowledge"* | [security-model](https://dev.risczero.com/api/next/security-model) |
| Verifier gas | **UNVERIFIED** — no official number located | — |

### 2.2 SP1

| Property | Finding | Source |
|---|---|---|
| Proof system | Hypercube: multilinear IOP over **KoalaBear** (`p = 2^31 − 2^24 + 1`) with **Poseidon2**, width 16, S-box degree 3, 8 external / 20 internal rounds (Plonky3 parameters) | [security-model](https://docs.succinct.xyz/docs/sp1/security/security-model) |
| Fiat–Shamir | Random-oracle model over Poseidon2; *"we ensure that the depth of the overall circuit being proven is less than that of the Poseidon hash, thereby avoiding the recent Fiat–Shamir attack"* | same |
| FRI assumptions | *"SP1 Hypercube does not rely on proximity gap conjectures. Rather, it relies on proximity gap theorems established in (https://eprint.iacr.org/2020/654.pdf), while operating in the unique decoding regime."* | same |
| Trusted setup — PLONK | *"For PLONK, SP1 uses the Aztec Ignition ceremony, which is a universal trusted setup designed for reuse across multiple circuits."* Cost: **3–4× Groth16 proving** | same |
| Trusted setup — Groth16 | **Circuit-specific ceremony** run by Succinct with **18 named contributors** (Etherealize, Polygon, OP Labs, Alpen Labs, Offchain Labs, Coinbase, Across, Succinct); artifacts generated with **Semaphore** (originally Worldcoin). *"circuit-specific ceremonies inherently carry higher trust assumptions"*; *"Users uncomfortable with these security assumptions are strongly encouraged to use PLONK instead."* | same |
| Documentation inconsistency | The proof-types page says *"PLONK does not require a trusted setup and reuses contributions from the Aztec Ignition ceremony"*, while the security model calls Aztec Ignition a *universal trusted setup*. Both were fetched verbatim; treat the proof-types phrasing as loose (a universal SRS is still a setup) | [proof-types](https://docs.succinct.xyz/docs/sp1/generating-proofs/proof-types) vs [security-model](https://docs.succinct.xyz/docs/sp1/security/security-model) |
| Proving modes | `core` / `compressed` / `plonk` / `groth16` | [proof-types](https://docs.succinct.xyz/docs/sp1/generating-proofs/proof-types) |
| On-chain gas (official doc figure) | Groth16: **~260 bytes, ~270k gas**; PLONK: **~868 bytes, ~300k gas**; *"Plonk proofs take about ~1m30s longer to generate over a compressed proof"* | same |
| Zero-knowledge | SP1 security model has a dedicated "Groth16, PLONK, and the Zero-Knowledgeness of SP1" section (heading fetched; full text not read) | [security-model](https://docs.succinct.xyz/docs/sp1/security/security-model) |
| **Approved Prover doctrine** | *"we officially recommend the use of an approved prover for any application handling critical or sensitive amounts of value. An approved prover refers to an implementation where there is a list of whitelisted provers or oracles who provide an additional sanity check that the proof's claimed outputs are correct."* | same |

### 2.3 Side-by-side

| Dimension | RISC Zero (v3.0.6 / risc0-ethereum v3.0.1) | SP1 (v6.8.1 / sp1-contracts v6.1.1) |
|---|---|---|
| Native proof | STARK (transparent, hash-based) | STARK/Hypercube (transparent, hash-based, Poseidon2/KoalaBear) |
| On-chain wrapper | Groth16 only | Groth16 **or** PLONK |
| Setup assumption for wrapper | Circuit-specific ceremony (PSE; Hermez 2^23 ptau) | Groth16: circuit-specific, 18 contributors. PLONK: Aztec Ignition universal |
| STARK-only on-chain? | No official on-chain STARK path found → **UNVERIFIED** | No — `compressed` is explicitly *not* for on-chain verification |
| Wrapper proof size | not published on the pages fetched → **UNVERIFIED** | ~260 B (Groth16) / ~868 B (PLONK), documented |
| On-chain gas | **UNVERIFIED** | ~270k (Groth16) / ~300k (PLONK), documented |
| Post-quantum posture | STARK side yes-in-principle; Groth16 no. No vendor claim fetched | Same; no vendor claim fetched |
| Explicit vendor caveat on prover trust | Secure-SDLC programme, audits, advisories | **"Approved prover" whitelist recommended for critical value** |

## 3. Supported cryptographic operations and the trust model

All syscall names below are from the **`sp1-lib` 6.8.1 rustdoc index** ([docs.rs](https://docs.rs/sp1-lib/latest/sp1_lib/), published 2026-09-24), which is the authoritative enumeration of SP1's precompile surface, and from the **RISC Zero precompiles page** ([dev.risczero.com/api/next/zkvm/precompiles](https://dev.risczero.com/api/next/zkvm/precompiles)) plus the `v3.0.6` `Cargo.toml`.

### 3.1 Capability matrix

Legend: **A** = circuit-accelerated (vendor documents a dedicated precompile/circuit or a patched crate that routes to one). **S** = software implementation inside the guest (correct but not accelerated). **?** = UNVERIFIED.

| Operation | RISC Zero (v3.0.6) | SP1 (6.8.1) | Notes / exact evidence |
|---|---|---|---|
| **keccak256** | **A** — dedicated `risc0-circuit-keccak` **4.0.6** circuit; patched `tiny-keccak` 2.0.2 (`tiny-keccak/v2.0.2-risczero.0`) | **A** — `syscall_keccak_permute`; patched `tiny-keccak`, `sha3`; docs warn a dropped `sha3` patch silently *"drop[s] keccak256 to software (a large cycle regression, since keccak drives MPT/state-root hashing)"* | RZ: Cargo.toml@v3.0.6 + precompiles page. SP1: sp1-lib fn list + [precompiles](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles) |
| **sha256** | **A** — patched `sha2` (0.10.9/0.10.8/0.10.7/0.10.6/0.9.9); precompiles page: *"SHA-256, RSA, elliptic curve, and modular multiplication operations"* | **A** — `syscall_sha256_compress`, `syscall_sha256_extend`; patched `sha2` (`patch-sha2-0.11.0-sp1-6.2.0`, also 0.10.x tags) | RZ precompiles page; SP1 sp1-lib + precompiles page |
| **secp256k1 ECDSA verify** | **A** — patched `k256` (0.13.4…0.13.1); docs show the ECDSA example and the patched `k256` fork diff that routes core EC ops to *"the precompiled 256-bit elliptic curve instructions. E.g. `lincomb`."* | **A** — `syscall_secp256k1_add`, `_double`, `_decompress`; patched `k256` (`patch-k256-13.4-sp1-6.0.0`) and `secp256k1` | RZ precompiles page; SP1 precompiles page |
| **secp256k1 ECDSA recover** | **?** — no explicit doc statement found that `recover`/`ecrecover` is accelerated (the patched `k256` accelerates the underlying EC ops that recovery uses). **UNVERIFIED** | **Partial / design-dependent** — SP1's `unconstrained!` macro doc explicitly names ecrecover as the motivating example: *"running `ecrecover` is expensive in the VM but verifying a signature when you know the public key is not. `unconstrained` can be used to provide the public key without spending VM CPU cycles."* The recovered pubkey is **not verified** unless the program separately verifies the signature against it | [sp1-lib](https://docs.rs/sp1-lib/latest/sp1_lib/) |
| **Ed25519 verify** | **A** — patched `curve25519-dalek` (4.1.3…4.1.0) | **A** — `syscall_ed_add`, `syscall_ed_decompress`; patched `curve25519-dalek` and `curve25519-dalek-ng` | Both precompiles pages |
| **secp256r1 (P-256)** | **A** — patched `p256` 0.13.2 | **A** — `syscall_secp256r1_add/_double/_decompress`; patched `p256` | Both |
| **BLS12-381 G1/G2 add–double** | **A (claimed)** — patched `bls12_381` 0.8.0 **and** patched `blst` 0.3.16/0.3.15/0.3.14 | **A** — `syscall_bls12381_add`, `_double`, `_decompress`, `_fp{,2}_addmod/mulmod/submod` | Both precompiles/syscall lists |
| **BLS12-381 MSM (multi-scalar mul)** | **?** — `blst` is the canonical MSM/pairing library and RISC Zero patches it, but **neither the precompiles page nor any fetched page states that MSM itself is accelerated**. **UNVERIFIED** | **No dedicated syscall.** MSM must be composed from `syscall_bls12381_add`/`_double` (O(n) syscalls for n points) | sp1-lib fn list (fetched in full — no MSM syscall) |
| **BLS12-381 pairing** | **?** — same reasoning as MSM: `blst` patch exists, acceleration not documented. **UNVERIFIED** | **No pairing syscall found** in the sp1-lib surface. **UNVERIFIED** whether pairing is reachable at acceptable cost | sp1-lib fn list |
| **BLS signature verification / aggregation** | **?** (library-level via `blst`/`bls12_381`; acceleration UNVERIFIED) | **?** — only `bls12381::decompress_pubkey` is a named helper; `verify`/`aggregate` are not precompile entry points | [sp1-lib::bls12381](https://docs.rs/sp1-lib/latest/sp1_lib/bls12381/index.html) |
| **bn254 (alt_bn128)** | **A** — patched `substrate-bn` 0.6.0 | **A** — `syscall_bn254_add`, `_double`, `_fp{,2}_*`; patched `substrate-bn` | Both |
| **modexp / bigint** | **A** — `risc0-bigint2` **1.4.14** + patched `crypto-bigint` 0.5.x. Audited: `veridise_bigint2_240324.pdf` | **A** — `sys_bigint`, `syscall_u256x2048_mul`, `syscall_uint256_{add,mul}_with_carry`, `syscall_uint256_mulmod`; patched `crypto-bigint` | RZ Cargo.toml + [rz-security/audits/precompiles](https://api.github.com/repos/risc0/rz-security/contents/audits/precompiles); SP1 sp1-lib |
| **RSA** | **A** — patched `rsa` 0.9.9 | **A** — patched `rsa` (`patch-0.9.6-sp1-6.0.0`) | Both precompiles pages |
| **Poseidon2** | not listed as a patched crate on the page fetched → **UNVERIFIED** | **A** — `syscall_poseidon2` | sp1-lib |
| **EIP-4844 / c-kzg** | **A (claimed)** — patched **`c-kzg` 1.0.3/2.1.0/2.1.1/2.1.5** (`github.com/risc0/c-kzg-4844`, tag `v2.1.5-risczero.0`). Footnote: *"The `c-kzg` crate depends on the `blst` crate (version 0.3.16) and also requires a patched version of `blst` to enable full acceleration."* | **no c-kzg patch listed** → in-guest blob KZG must be assembled from BLS12-381 primitives | RZ precompiles page |

### 3.2 The trust model, stated precisely

The question "is the result constrained by the proof?" has a different answer per mechanism, and this is where a W1/W2 design can silently break.

**(a) RISC Zero — circuit extension ("precompile"), not a hint.**
RISC Zero documents three circuits: the RISC-V STARK circuit, the **Recursion circuit**, and the STARK→SNARK R1CS circuit. The recursion circuit is *"designed to efficiently generate proofs for the verification of STARK proofs and to support the integration of custom accelerator circuits into the zkVM."* The precompiles page says the rv32im implementation *"includes a number of specialized extension circuits"* and that *"the circuitry is extended to compute otherwise expensive operations in fewer instruction cycles."*
→ **Consequence:** the precompile's input→output map is proven by a STARK that the recursion circuit verifies; the result is a *proven* function of the guest's memory, i.e. **not** an unconstrained host hint. The residual gap is documentation depth: the per-precompile constraint systems are not described on the pages fetched, so "the circuit enforces X" is verified at the level of *architecture*, not at the level of *trace constraints* → per-op **UNVERIFIED**.

**(b) SP1 — custom STARK tables reached by `ecall`.**
*"precompiles are implemented as custom STARK tables dedicated to proving one or few operations … exposed as system calls executed through the `ecall` RISC-V instruction."* Results returned into guest memory are constrained by those tables ([precompile-specification](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompile-specification)).
**But the safe-usage page attaches real constraints that the *guest program* must satisfy** ([safe-precompile-usage](https://docs.succinct.xyz/docs/sp1/security/safe-precompile-usage)):
- *"Do not use direct ECALL … directly calling `HALT` to stop the program execution leads to security vulnerabilities."*
- Pointers must be 4-byte aligned.
- Field inputs must be **canonical**; *"Using non-canonical representations may result in unverifiable SP1 proofs."*
- **Elliptic-curve precompiles do not check that inputs are on the curve:** *"the elliptic curve precompiles assume that inputs are valid elliptic curve points. Since this validity is not enforced within the precompile circuits, it is the responsibility of the user program to verify that the points lie on the curve."*
- Weierstrass `add` requires **different x-coordinates**; sending equal points to `add` yields unverifiable proofs; **points at infinity are unsupported** by `add`/`double`.
- `sys_bigint` requires **`x * y < 2^256 * modulus`** for the proof to be verifiable.
→ **Consequence:** a naive BLS12-381 MSM/pairing built on these syscalls can produce *unverifiable* (DoS) or *unsound-at-the-application-level* results unless the guest performs subgroup/on-curve/edge-case checks. Those checks are part of the trusted code base.

**(c) Hints and unconstrained execution are NOT verified — this is the W1 hazard.**
- SP1 exposes `syscall_hint_len`, `syscall_hint_read`, `syscall_enter_unconstrained`, `syscall_exit_unconstrained`, the `unconstrained!` macro, and `invalid_hint`/`halt_invalid_hint`. An unconstrained block *"does not need to be constrained by the VM"*. The guest must explicitly verify anything it trusts.
- Both systems take guest input from the host (`sys_read` on RISC Zero; the stdin/hint channel on SP1). RISC Zero's advisory **GHSA-jqq4-c7wq-36h7** (critical, 2025-10-01) is precisely a host-controlled `sys_read` response achieving arbitrary guest code execution — i.e. *the host is untrusted and this has been exploitable*.
→ **Design rule:** the validator-set commitment, chain id, epoch, height, block hash and the accepted L1 state root must be **public inputs** (journal/public-values) that the L1 verifier contract checks, or values derived from L1 state the contract commits to. Anything a prover could supply (a "validator set" list, a stake table, a quorum threshold) must be re-derived in-guest from that anchored commitment, and the proof must check the signature relation, not merely assert that a hint said so.

**(d) Recursion / deferred verification.**
- SP1: `syscall_verify_sp1_proof` lets a guest verify another SP1 proof; the docs require the *inner* proof to be `compressed` ([proof-aggregation](https://docs.succinct.xyz/docs/sp1/writing-programs/proof-aggregation)).
- RISC Zero: `env::verify` inside the guest adds an **assumption** to the `ReceiptClaim`, later discharged by the `resolve` recursion program; `add_assumption` is host-side ([composition](https://dev.risczero.com/api/next/zkvm/composition)).

---

## 4. EIP-4844 blob binding in-guest

### 4.1 What the protocol actually requires

From [EIP-4844](https://eips.ethereum.org/EIPS/eip-4844) (fetched 2026-10-05):

| Quantity | Value |
|---|---|
| `FIELD_ELEMENTS_PER_BLOB` | **4096** |
| Field element size | 32 bytes (BLS modulus) → **131,072 bytes per blob** |
| `VERSIONED_HASH_VERSION_KZG` | `0x01` |
| Versioned hash | `kzg_to_versioned_hash(commitment) = VERSIONED_HASH_VERSION_KZG ++ sha256(commitment)[1:]` |
| Block validity | *"The KZG commitments hash to the versioned hashes, i.e. `kzg_to_versioned_hash(commitments[i]) == tx_payload_body.blob_versioned_hashes[i]`"* |
| Point evaluation precompile | *"verifies a KZG proof which claims that a blob (represented by a commitment) evaluates to a given value at a given point"*; it *"also verif[ies] that the provided commitment matches the provided versioned_hash"* |
| Curve | BLS12-381 (KZG commitments/proofs; the precompile returns `BLS_MODULUS`) |

**"keccak commitment to the data" ≠ "the protocol's KZG commitment."** These are different objects with different verifiers and different trust:

| | keccak256(data) | Protocol KZG commitment |
|---|---|---|
| What it is | One 32-byte hash of the byte string | A **BLS12-381 G1 point** = `Σ_i c_i · [τ^i]` over the 4096 field elements (an MSM) |
| Who can check it cheaply | Anyone, in-guest, ~1 hash | Only with the KZG structured reference string; on L1 via the point-evaluation precompile |
| What L1 consensus enforces | Nothing | `kzg_to_versioned_hash(C) == blob_versioned_hash`; DA sampling is over the *blob*, addressed by the versioned hash |
| Binding value | *"I saw these bytes"* | *"this is the polynomial the protocol's DA layer is committing to"* |
| If the guest only checks keccak | A malicious proposer can publish **different bytes** under the same versioned hash in the blob field, because the versioned hash commits to the KZG commitment, not to the bytes. The proof's keccak hash would be over data that L1 never bound | The versioned hash is the protocol-native handle |

→ **A calldata+keccak binding is only sound if the batch data is in calldata** (where L1 execution itself makes the bytes part of the transaction and the contract can hash them directly). **For blobs you must go through the KZG commitment**, or you must add an explicit in-transaction check that ties bytes → commitment → versioned hash.

### 4.2 Feasibility per zkVM

| Path | RISC Zero | SP1 |
|---|---|---|
| Vendor-supported blob library | **Yes** — `c-kzg` patched (`risc0/c-kzg-4844`, tags up to `v2.1.5-risczero.0`), and c-kzg's README confirms it implements *"the Polynomial Commitments API for EIP-4844"* with `compute_kzg_proof`, `verify_kzg_proof`, etc. | **No c-kzg patch listed** in the patched-crate table → must be hand-built from BLS12-381 syscalls or a Rust KZG crate |
| Blob→commitment (MSM over 4096 G1 points) | **Plausible but UNMEASURED.** The patch exists and `blst` is patched specifically to *"enable full acceleration"* of c-kzg — but no cycle count, no latency, and no doc statement that MSM is a single accelerated operation | **Composed from O(4096) EC syscalls.** No MSM syscall exists. Each add/double must satisfy the safe-usage constraints (on-curve, distinct x, no infinity) — the guest must implement the bucket/accumulator logic and its checks |
| KZG **opening** check (`verify_kzg_proof`) | Same library surface; a pairing check is required | **No pairing syscall found**; a pairing built from fp/fp2 syscalls is the main risk. **UNVERIFIED** whether this is practical |
| Fiat–Shamir / challenge derivation | Standard SHA-256-based (c-kzg uses SHA-256 in the FS transform) — available in both | same |
| KZG SRS availability in-guest | The SRS is large (4096+ G1 points); whether the Ethereum KZG ceremony output can be loaded into the guest within the documented memory envelope is **UNVERIFIED** for both. SP1 documents a **~2 GB** zkVM memory limit | [proof-aggregation](https://docs.succinct.xyz/docs/sp1/writing-programs/proof-aggregation) |
| Cheaper alternative: only bind the versioned hash | The guest can take the versioned hash as a **public input** supplied by the L1 contract (from `BLOBHASH`) and check whatever the contract requires *without* recomputing the commitment — but then the proof says nothing about the bytes, so the contract must separately enforce data↔hash equality, which for blobs it cannot do on L1 cheaply | Same |

### 4.3 Cost drivers (qualitative — no invented numbers)

1. **Number of G1 scalar-multiplications**: 4096 per blob (one per field element). This dominates everything else.
2. **Whether MSM is a native circuit op or a syscall loop** (RISC Zero: plausibly native via the patched `blst`; SP1: syscall loop).
3. **Number of blobs per batch** — linear in the above.
4. **Whether an opening proof (pairing) must be checked in addition to the commitment** — a pairing is far more expensive than the MSM in most implementations, and SP1 has no pairing syscall.
5. **SRS loading**: memory + hashing cost proportional to the SRS size.
6. **Fiat–Shamir hashing** over the blob (SHA-256 over 128 KiB per blob) — comparatively small but not free.

### 4.4 Calldata + keccak comparison

| | Blob + KZG (in-guest) | Calldata + keccak (in-guest) |
|---|---|---|
| Guest work per byte | MSM over 4096 elements + SHA-256 | ~one keccak permutation per 136 bytes |
| Accelerated? | RZ: patched c-kzg/blst (claimed); SP1: no | Both: dedicated keccak circuits |
| Sound binding to what L1 sees | Yes, via versioned hash | **Yes** — the calldata bytes *are* the L1 transaction payload; the contract can keccak them itself, or the guest proves `keccak(data) == public_input` and the contract hashes its own calldata |
| L1 data cost | Cheaper per byte (blob gas market) | Expensive (calldata gas) |
| Proof cost | Much higher | Much lower |
| **Recommendation implied by the evidence** | If blobs are used, the *cheapest sound* design is: contract passes the versioned hashes (and any needed commitment) as **public inputs**, and the guest binds the data to the commitment; otherwise the blob path adds the largest single primitive risk in the whole design | Simplest and best-evidenced path |

---

## 5. Two worked proof-statement skeletons

Notation: `H` = a hash anchored by the protocol; `pub` = public input (checked by the L1 verifier contract); `wit` = private witness (prover-supplied, must be fully constrained).

### 5(a) COMBINED — one guest proves W1 ∧ W2

**Public inputs (journal / committed public values)**

| # | Value | Why public |
|---|---|---|
| 1 | `chain_id` | Domain separation; prevents cross-chain replay |
| 2 | `l1_contract` address (+ `l1_chain_id`, verifier version tag) | Prevents replay into a different deployment/version |
| 3 | `batch_id` / `last_accepted_batch` | Ordering; prevents skipping/replaying batches |
| 4 | `prev_state_root` | Must equal the L1-accepted root (W2 start) |
| 5 | `new_state_root` | W2 end state |
| 6 | `first_block_number`, `last_block_number` (batch range) | Range binding |
| 7 | `head_block_hash`, `head_height` | The finalized head that W1 certifies |
| 8 | **`validator_set_commitment`** (root of the authoritative set, as of the relevant epoch) | **Anchored on L1** — the contract reads it from its own state; a prover can never supply it |
| 9 | `validator_set_version` / `epoch` (+ `epoch_transition_commitment` if the batch spans epochs) | Selects which set the QC must verify against |
| 10 | `quorum_threshold` (e.g. `> 2/3` of committed TAIKO stake, or the exact integer threshold) | The contract, not the prover, defines "2/3" |
| 11 | `qc_signing_root` (i.e. `H(chain_id ‖ version ‖ height ‖ block_hash)`) | Ties the signature domain to the certified statement |
| 12 | `public_values_hash` of the batch's data commitment | Ties data to proof |
| 13 | `blob_versioned_hashes[]` **or** `calldata_hash` | The DA binding of §4 |
| 14 | `da_mode` (blob / calldata) | Domain separation between the two binding rules |
| 15 | `gas_used` / `receipts_hash` (optional but common) | Lets L1 sanity-check work |

**Private witness**

| # | Witness | Constrained by |
|---|---|---|
| 1 | Validator set leaves (pubkeys, stake amounts) | Must Merkle/SSZ-verify against #8; the *tree rule* is hard-coded in the guest |
| 2 | Merkle/SSZ inclusion proofs for each signer | Hash-checked in-guest |
| 3 | QC bitfield / signer index list | Checked against #8 and the quorum rule |
| 4 | **Signatures** over #11 | **Signature verification in-guest** (secp256k1/Ed25519) — this is the cryptographic core of W1 |
| 5 | Stake values / aggregation arithmetic | Summed in-guest as bigint; requires `sum(participating stake) ≥ threshold(#10)` |
| 6 | Epoch-transition data (old set, new set, activation height) | Hash-chained to #8/#9 |
| 7 | L2 block bodies, transactions, receipts, state trie nodes | Executed / trie-verified in-guest |
| 8 | Blob data + KZG commitment (if `da_mode = blob`) | MSM + `sha256` → **must equal** versioned hash #13 |

**Checked in-guest:** signature validity; stake-weighted quorum ≥ threshold; validator-set membership vs the anchored commitment; epoch/version consistency; full EVM state transition `prev_state_root → new_state_root`; block-hash/height continuity; DA binding.

**What binds the parts:** #4 (prev root), #8/#9 (authoritative set + version) and #11/#13 are computed by the contract and checked by the on-chain verifier against the journal. The **only** cryptographic link between "L1 believes set S" and "the QC was signed by S" is the in-guest membership + signature check, whose result is a STARK/SNARK-constrained computation.

### 5(b) COMPOSED — consensus proof ⊗ execution proof

Two guests, two image IDs. Composition can be **recursive** (outer guest verifies the inner proof via `env::verify` / `syscall_verify_sp1_proof`) or **on-chain** (the L1 contract verifies both seals).

| | Consensus guest (W1) | Execution guest (W2) |
|---|---|---|
| Public inputs | `chain_id`, `l1_contract`, `validator_set_commitment`, `validator_set_version`/`epoch`, `quorum_threshold`, `head_height`, `head_block_hash`, `qc_signing_root`, `batch_id`, `epoch_transition_commitment` | `chain_id`, `l1_contract`, `batch_id`, `prev_state_root`, `new_state_root`, `first_block_number`, `last_block_number`, `head_block_hash`, `head_height`, `da_commitment`, `da_mode` |
| Private witness | validator leaves + inclusion proofs, signatures, stake table, bitfield, epoch-transition data | block bodies, txs, receipts, trie nodes, blob data+KZG (if blob mode) |
| Proof size / mode | small program → `compressed` STARK is likely sufficient; **UNMEASURED** | large program |
| **Binding between the two** | **`head_block_hash` + `head_height` + `batch_id` appear in BOTH public-input lists.** Enforced by the L1 contract requiring both journals to carry identical values. If composed recursively, the outer guest takes the inner journal as a public input and checks equality in-circuit |

**Composition modes and what they cost**

| Mode | Mechanism | Binding enforced by | Risk |
|---|---|---|---|
| On-chain composition | Contract calls two verifiers (two routes/selectors) and compares journals | L1 contract code | Contract bug = forgery; two upgrade surfaces; ~2× verification gas |
| Recursive composition (RISC Zero) | `env::verify(inner_image_id, inner_journal)` in the outer guest → `ReceiptClaim` assumption → `resolve` | Recursion circuit + assumption machinery | A bug in the *inner verifier* backend can let a false inner claim be assumed, and then the outer proof is valid for a false statement |
| Recursive composition (SP1) | `syscall_verify_sp1_proof` over a `compressed` inner proof | Recursion/aggregation circuit | Same class of risk; note **GHSA-63x8** was exactly a *recursion-circuit* soundness gap (V6, fixed in 6.1.0) |

**"Can a bug in one backend forge the other?"**
- **Combined guest:** there is only one backend, so the question is moot — but the *single* backend's soundness bug forges everything at once (W1 **and** W2).
- **On-chain composition:** a forged proof must pass a concrete verifier; a bug in verifier A cannot forge verifier B, **but** it can forge A's half — and because the contract compares journals rather than re-deriving them, a forged *consensus* proof with attacker-chosen `head_block_hash` **can** be paired with a genuine execution proof for those same attacker-chosen values only if the execution half also accepts them. Execution binds `prev_state_root` (from L1) so it cannot be entirely fabricated; the consensus half is the softer target because its statement is small and its witness is fully prover-supplied.
- **Recursive composition:** the outer proof attests to the inner *statement*; if the inner proof system is broken, the outer system faithfully proves a false statement. This is the strongest argument for keeping the *consensus* half in the same guest as the execution half, or for on-chain composition with two independently audited verifiers.

### 5(c) Tradeoffs

| Dimension | COMBINED (a) | COMPOSED (b) |
|---|---|---|
| On-chain verification cost | 1 verification (~270k–300k gas per SP1 doc figures; RZ gas UNVERIFIED) | 2 verifications (≈2×) unless recursively aggregated back into one |
| Proof size | 1 seal | 2 seals (or 1 if outer aggregates) |
| Latency | Must wait for finality before starting; single pipeline | **Can pipeline**: execution proof starts at block production, consensus proof at finality, then compose — reduces critical path if finality lags |
| Upgrade independence | **Low** — any change to the consensus rule *or* the EVM changes the image ID and therefore the verifier route | **High** — consensus format and EVM can be versioned independently |
| Version surface on L1 | 1 route | 2 routes (or 1 route + 1 inner-verifier dependency) |
| Security surface | 1 TCB; single bug → both broken | 2 TCBs + the composition glue; a bug forges only its half **unless** composed recursively in a broken backend |
| Reuse/amortization | Consensus work re-done per batch incl. full signature set | Consensus proof can be **reused across many batches** in the same epoch (a big win: signature verification is per-epoch, not per-batch) |
| Failure isolation | None | Good — e.g. DA-mode bug doesn't stop finality proofs |

**Reading of the evidence (not an assertion of fact):** if the design wants the *smallest* number of things that can go wrong on L1, **COMBINED** wins. If the design wants to *amortize* signature verification across an epoch and to upgrade the two halves independently, **COMPOSED** wins — at the cost of a second verifier route and an explicit journal-equality check. §11 states a recommendation.

---

## 6. Aggregation and pipelining

| Capability | RISC Zero (v3.0.6) | SP1 (6.8.1) |
|---|---|---|
| In-proof parallelism | Program split into **Segments**, each proven, then `lift`ed; **`join`** pairs of `SuccinctReceipt`s repeatedly until one remains | Execution split into **shards of ~2^22 RISC-V instructions**, shard proofs generated **in parallel**, then *"recursively aggregating the proofs"* ([proof-aggregation](https://docs.succinct.xyz/docs/sp1/writing-programs/proof-aggregation), [hypercube](https://docs.succinct.xyz/docs/sp1/hypercube/)) |
| Recursion primitive | `lift`, `join`, `resolve`, `identity_p254`; `compress()` → Groth16 | `syscall_verify_sp1_proof` over a **compressed** proof |
| User-level aggregation program | Proof composition via `add_assumption` / `env::verify`; `resolve` removes the assumption | **Yes** — official `aggregation example`; *"aggregating multiple SP1 proofs into a single SP1 proof"* |
| Aggregate many **per-batch** proofs into one per L1 posting | Yes in principle (join/aggregate), **but no per-batch aggregation example was fetched** → unverified as a documented pattern | Yes — explicitly listed as a use case: *"Reducing on-chain verification costs by aggregating multiple SP1 proofs into a single SP1 proof"* |
| Documented caveat | none fetched | **`warning`: "Generally proving a single program is faster and more cost-effective than generating mul…"** (text truncated at fetch; the full sentence was not captured) — i.e. the docs warn aggregation is **not** automatically cheaper |
| When the vendor says aggregation is *necessary* | — | *"When your computation requires more than the zkVM's limited (~2GB) memory, or is extremely long (>120B cycles)"*; when combining proofs from **different parties**; when parts can start at different times |
| SNARK wrap for the aggregate | `ReceiptKind::Groth16` shrink-wrap (requires `rzup install risc0-groth16`) | `groth16` / `plonk` wrap of the aggregated proof |

**Consequences**

- **Latency:** both systems make a single batch's proof *internally* parallel (segments/shards). Aggregation adds a **serial tail** (the recursive roll-up + the SNARK wrap). SP1 documents the PLONK wrap alone as **+~1m30s** over a compressed proof ([proof-types](https://docs.succinct.xyz/docs/sp1/generating-proofs/proof-types)). No equivalent RISC Zero wrap-time figure was found → **UNVERIFIED**.
- **Cost:** aggregation buys **one** on-chain verification instead of N, at the price of extra recursive proving. SP1's own docs warn single-program proving is generally faster/cheaper than proving N programs and aggregating — so aggregate only when N proofs must become one seal.
- **Upgrade/compatibility:** an aggregate proof's verifier route is determined by the **outer** program's image ID and the aggregation circuit's version — *not* by the inner proofs' versions. That means an aggregation layer can **pin an old, vulnerable inner circuit version into a new outer route**. This is a concrete stale-version hazard (§8).
- **Per-epoch amortization:** for W1, the same QC/validator-set statement can be proven once per epoch and **reused** as an inner proof for every batch in that epoch (recursive composition). This is the strongest technical argument for the composed design.

## 7. Proving throughput vs. the ~2 s block cadence

**No number below is invented.** Where a published measurement exists it is quoted with hardware, workload, version and methodology. Where none exists, the entry is **UNVERIFIED** and only a *formula* is given.

### 7.1 The constraint, as formulas

Let:
- `G` = sustained L2 gas/s to be proven (the throughput the L2 actually produces)
- `C` = zkVM cycles per L2 gas for *this* workload (**UNVERIFIED** for any EVM+consensus workload; it is the single most important unknown)
- `R` = cycles/s proven by one machine (**UNVERIFIED** for both systems on this workload)
- `Δ` = L1 posting interval (s)
- `L` = end-to-end proving latency budget (the brief allows up to ~1800 s)
- `B` = L2 gas in one batch = `G · Δ`
- `e` = efficiency factor (parallel scaling loss, aggregation tail, retries), `e ≥ 1`

Then:

```
(1) Required aggregate cycle throughput   T_req = e · G · C                [cycles/s]
(2) Required fleet size (throughput-bound) N_thr = T_req / R = e·G·C / R
(3) Work per batch                         W = B · C = G · Δ · C          [cycles]
(4) Latency for one batch on k machines    L_batch = W / (k · R)
(5) Latency feasibility                    k ≥ W / (L · R)
(6) In-flight (concurrency) requirement    Q = L / Δ   (Little's law)      [proofs]
(7) Fleet size (concurrency-bound)         N_conc = Q · k = (L/Δ)·k
(8) FLEET = max(N_thr, N_conc) = max( e·G·C/R , (L/Δ)·k )
(9) Cost per batch ≈ (W / R) · p_machine   where p_machine = price per machine-second
(10) Staleness window: a proof started at batch n is posted at ≥ t_n + L, so the
     L1 contract must tolerate a proof for an *older* head than the current L2 head.
```

**Key structural insight from (6)–(8):** because a proof may take up to 30 minutes while blocks arrive every 2 s, the fleet is **concurrency-bound, not throughput-bound**, whenever `L/Δ` exceeds `e·G·C/R`. With `Δ = 2 s` and `L = 1800 s`, **Q = 900 proofs in flight**. That number is a design input for the queue and hardware fleet regardless of how fast a single machine is. Conversely, if the L1 posting interval `Δ` is much larger (e.g. one posting every few minutes), Q falls proportionally.

**Pipelining levers** (all require the L1 contract to accept proofs about a *specific, bounded* batch rather than "the latest head"):
1. Per-batch parallel proofs + aggregation (§6) — raises throughput, adds a serial tail.
2. Segment/shard parallelism inside one proof — both zkVMs do this natively.
3. **Queue depth ≥ Q**, with bounded retry.
4. **Per-epoch reuse of the consensus (W1) proof** — turns a per-batch signature-verification cost into a per-epoch cost.
5. Deferring the SNARK wrap: produce the STARK/compressed proof early, wrap late (the wrap is the part the chain needs).

### 7.2 Published measurements actually verified

| # | Vendor/system | Hardware | Workload | Published result | Version | Transferable to Taiko W1+W2? |
|---|---|---|---|---|---|---|
| M1 | Succinct **SP1 Hypercube** | **16 × NVIDIA RTX 5090** | *"a random set of 954 blocks, taken between block number 23807739 and 23812008"* — **L1 Ethereum block execution** | *"proves 99.7% of L1 Ethereum blocks … under 12s, and 95.4% of blocks under 10s"* | "the latest version of SP1 Hypercube" (blog does not state a semver; blog post is at [blog.succinct.xyz](https://blog.succinct.xyz/real-time-proving-16-gpus/)) | **Partially.** It is EVM execution on L1 mainnet blocks — closest published analogue to **W2**. It is **not** W1 (no validator-set/QC/signature work) and **not** blob KZG. Whether 16 GPUs suffice for *this* workload is **UNVERIFIED** |
| M2 | SP1 local-proving minimums | CPU 16+ cores / 16 GB+ RAM (core, compress); Groth16 16 GB+, PLONK 64 GB+ | — | *"The final wrapping step requires roughly 14GB of memory for Groth16 and 60GB for PLONK"* | docs.succinct.xyz (current) | Resource envelope only — **not** a throughput measurement |
| M3 | SP1 GPU requirements | 24 GB+ VRAM, compute capability ≥ 8.0 (A100, RTX 30/40, H100) | — | minimum spec | [hardware-acceleration](https://docs.succinct.xyz/docs/sp1/generating-proofs/hardware-acceleration) | Envelope only |
| M4 | RISC Zero | none published | — | The docs instruct users to generate their **own** datasheet: `cargo run --release --example datasheet` (with `-F cuda` or `-F metal`), plus a Fibonacci benchmark | v3.0.6 docs | **No published per-machine number exists on the pages fetched → UNVERIFIED.** Any RISC Zero throughput claim in a design doc must come from a self-run datasheet or a Boundless/third-party benchmark |
| M5 | SP1 Hypercube aggregate claim | — | — | *"first general-purpose hash-based zkVM to completely eliminate the need for proximity gap conjectures"* (a soundness claim, not a perf number) | blog | Not a perf measurement |
| M6 | Third-party zkEVM benchmark (Nethermind `zkevm-benchmark-workload`) | — | gas-categorized workloads, pages for 0.4M/1M gas and risc0 variants exist | Page content is JS-rendered; **no numbers could be extracted** → **UNVERIFIED** | — | Would be useful if fetched in a browser; not usable as evidence here |

**Explicit statement on transferability:** M1 is the only hard published latency figure found, and it transfers only to the **W2 execution** component of this design, only for **L1-mainnet-like** blocks, only on **that 16×RTX 5090 cluster**, and only for the SP1 **Hypercube** circuit line. It says nothing about (a) the signature/quorum work in W1, (b) BLS12-381 KZG MSM/pairing in the blob path, (c) the smaller ~2 s-cadence L2 blocks of Etna, or (d) RISC Zero.

### 7.3 What must be TRUE for proving to keep pace

| Requirement | Statement | Status |
|---|---|---|
| R1 | Aggregate proven cycles/s ≥ `e · G · C` | **Cannot be evaluated** — `C` and `R` are UNVERIFIED for this workload |
| R2 | Fleet ≥ `(L/Δ)·k` concurrent proving jobs (≈900 in-flight at Δ=2 s, L=30 min) | Arithmetic consequence of the stated constraints, independent of hardware |
| R3 | Each batch's proof completes within `L` on `k` machines | Requires a measured per-machine rate |
| R4 | L1 verifier accepts a proof for a **bounded, specific** batch (not "latest") | Design requirement implied by (10) |
| R5 | Either the consensus half is amortized per epoch, or its per-batch cost is included in `C` | Design requirement — W1 cost is otherwise repeated per 2 s |
| R6 | A prover-fleet member cannot influence the statement (only liveness) | Security requirement (§3.2c) |

---

## 8. Program-image and verifier upgrade paths

### 8.1 Mechanisms as documented

| | RISC Zero | SP1 |
|---|---|---|
| Guest program identity | **Image ID** (hash of the guest ELF) + **control root** (the allowed recursion programs; each `lift`/`join`/`resolve`/`identity_p254` has a control ID) | **VKEY** (verification key) for the guest program |
| What the L1 contract stores | The verifier **selector** in the seal routes to a base verifier; each base verifier is *"stateless and immutable"* and hard-codes the **control root** and the Groth16 vkey. The program Image ID is passed by the *application* as the expected image id | The proof carries the SP1 version; the **gateway** routes to the correct per-version verifier; the app supplies the expected VKEY |
| Adding a new version | Admin adds an implementation to `RiscZeroVerifierRouter`; *"once removed it can never be replaced. I.e. each identifier can have at most one implementation across time."* RISC Zero's own router additions go through a **`TimelockController` (mainnet delay = 259200 s = 3 days)** | *"Whenever a verifier for a new SP1 version is deployed, the gateway contract will be updated"*; routes added via **Safe batches** (e.g. `1_add-route_v6_0_0.json`, `1_add-route_v6_1_0.json`) |
| Removing / freezing a version | `RiscZeroVerifierEmergencyStop` proxy per base verifier; triggerable by a **guardian** or by *"proving the existence of a critical vulnerability"* (circuit breaker). Apps can deploy their **own** router/estop | *"If a verifier for an SP1 version has an issue, the route will be frozen"* |
| App-side options | (i) call an immutable verifier directly (no upgrade, no shutdown — *"even in the event of vulnerabilities"*); (ii) estop proxy; (iii) own router with a chosen subset | Use the canonical gateway, or deploy your own verifier and follow the SP1Verifier interface |
| Testnet vs mainnet policy | — | *"On mainnets, only official versioned releases are deployed and added to the gateway. Testnets have … versions of the verifier deployed supported in addition to the official versions."* |
| Upgrade guide | Version-management design doc | [Upgrade Guides](https://docs.succinct.xyz/docs/sp1/developers/upgrades): V6 introduces Hypercube with **breaking API changes**; patches and the "version string … when specifying the circuit version" must be upgraded |

### 8.2 Consequences for a long-lived L1 contract with a rotating prover fleet

1. **Every guest change is a verifier-route change.** Changing one line of the consensus rule changes the Image ID / VKEY. The L1 contract must therefore hold a *set* of accepted program identities, with an explicit governance path to add/remove them.
2. **Stale-version acceptance is the dominant long-run risk.** RISC Zero's router allows a version to be removed but never replaced; SP1's gateway can *freeze* a route. A contract that "accepts any seal the router accepts" inherits the router admin's judgement — including a **3-day timelock** delay before a new version becomes usable, and RISC Zero's own caveat that a directly-called immutable verifier **cannot be shut down even if a vulnerability is found**. The safe pattern is an **application-owned router** (RISC Zero explicitly supports this) / an application-owned allow-list of identities.
3. **Aggregation can pin an old inner version into a new outer route** (§6): if inner proofs are verified recursively, the outer proof's validity does not reveal which inner circuit version produced them unless the outer guest enforces an expected inner Image ID/control root/VKEY in-circuit. **The outer guest must hard-code the accepted inner program identity.**
4. **Release cadence vs. audit cadence.** SP1 shipped **5 releases in 29 days** (v6.5.0 → v6.8.1) — a prover fleet can move much faster than an L1 governance timelock (RISC Zero: 3 days) or an audit cycle. Any "rotate the fleet quickly" plan must be reconciled with the L1 verifier's upgrade latency.
5. **Version-skew hazard (concrete, currently live):** SP1 docs pin supported versions to **V5.x.y / V6.1.0** while the SDK is at **6.8.1** and mainnet has `V6_1_0` verifiers. An operator who upgrades the prover without checking the verifier route produces proofs the L1 contract rejects — a **liveness** failure. The inverse (a contract left accepting an old route) is a **soundness** failure. The release→VKEY mapping is **UNVERIFIED**.

---

## 9. Supply chain and implementation risk

### 9.1 Audits (verified listings)

| System | Where | Items found |
|---|---|---|
| RISC Zero | [github.com/risc0/rz-security/tree/main/audits](https://api.github.com/repos/risc0/rz-security/contents/audits) | Directories: `circuits`, `contracts`, `groth16`, `precompiles`, `zkVM`, plus `blobstream`, `boundless`, `kailua`, `povw`, `r0vm-helios`, `steel`. **zkVM:** `hexens_zkVM_20231031.pdf`, `veridise_zkVM_20250224.pdf`, `veridise_zkVM_260212.pdf` (**2026-02-12**). **Precompiles:** `veridise_bigint2_240324.pdf`, `veridise_keccak-250221.pdf` |
| SP1 | [github.com/succinctlabs/sp1/tree/dev/audits](https://api.github.com/repos/succinctlabs/sp1/contents/audits?ref=dev) | `cantina.pdf`, `code4rena.pdf`, `hypercube-zellic.pdf`, `kalos.md`, `rkm0959.md`, `sp1-v4.md`, `veridise.pdf`, `zellic.pdf`. Commit history on that path: 2026-02-12, 2026-02-06, 2025-01-30, 2025-01-26, 2025-01-14, 2024-11-12, 2024-11-07, 2024-07-19 |

### 9.2 Bug bounties

| System | Evidence | Amounts |
|---|---|---|
| SP1 | Docs sidebar "Bug Bounty" → `https://code4rena.com/bounties/succinct` (link extracted from the [safe-precompile-usage](https://docs.succinct.xyz/docs/sp1/security/safe-precompile-usage) page). The Code4rena page is JS-rendered and returned no readable content | **UNVERIFIED** |
| RISC Zero | Footer link "Bug Bounties" exists on dev.risczero.com pages; no href resolvable from the fetched HTML | **UNVERIFIED** |

### 9.3 Known soundness issues / advisories (GitHub Security Advisories API)

**RISC Zero** — [advisories API](https://api.github.com/repos/risc0/risc0/security-advisories):

| ID | Severity | Published | Title | Patched |
|---|---|---|---|---|
| GHSA-jqq4-c7wq-36h7 | **critical** | 2025-10-01 | Arbitrary code execution in guest via memory safety failure in `sys_read` — *"the host is able to use a crafted response to write to an arbitrary memory location in the guest … all guest programs built with the affected versions are vulnerable. This critically compromises the soundness guarantees"* | risc0-zkvm **≥2.3.2, ≥3.0.3** (fix PR #3351) |
| GHSA-g3qg-6746-3mg9 | **critical** | 2025-06-18 | zkVM Underconstrained Vulnerability | (not read) |
| GHSA-5c79-r6x7-3jx9 | high | 2024-09-25 | Insufficient zkVM validation of multi-step instruction modes | (not read) |
| GHSA-f6rc-24x4-ppxp | medium | 2025-08-04 | Underconstrained Vulnerability: Division | (not read) |
| GHSA-349p-x622-29x6 | low | 2024-11-13 | Possible abuse of syscalls by malicious proving hosts | (not read) |
| GHSA-5xgj-pmjj-gw49 | low | 2024-07-15 | RISC Zero zkVM notes on zero-knowledge | (not read) |

**SP1** — [advisories API](https://api.github.com/repos/succinctlabs/sp1/security-advisories):

| ID | Severity | Published | Title | Patched |
|---|---|---|---|---|
| GHSA-63x8-x938-vx33 | **high** | 2026-04-11 | **SP1 V6 Recursion Circuit Row-Count Binding Gap** — *"A soundness vulnerability in the SP1 V6 recursive shard verifier allows a malicious prover to construct a recursive proof from a shard proof that the native verifier would reject."* Affected `>= 6.0.0, <= 6.0.2`; V5 not affected | `sp1_sdk`, `sp1_recursion_circuit`, `sp1_prover` → **6.1.0** |
| GHSA-6248-228x-mmvh | high | 2025-06-03 | Vulnerability in Plonky3, insufficient checks in the Rust verifier and embedded allocators | (not read) |
| GHSA-c873-wfhp-wx5m | high | 2025-01-15 | Missing verifier checks and Fiat–Shamir observations | (not read) |
| GHSA-f77q-r5qm-w4m8 | high | 2024-10-28 | Insufficient range checks of BabyBear arithmetic | (not read) |
| GHSA-8m24-3cfx-9fjw | medium | 2024-11-08 | Insufficient observation of cumulative sum | (not read) |

### 9.4 What this means when a soundness bug == bridge theft

- Both systems have a **recent history of high/critical soundness defects**, and in both cases the remediation was **"upgrade to version X"** — i.e. the fix lives in the prover and in a new circuit, not in a patch the L1 contract can apply to itself. An L1 verifier that cannot be quickly pointed at a new circuit **cannot be fixed**.
- **The consensus half (W1) is the highest-value target** because its witness is entirely prover-supplied: a forged consensus proof with an attacker-chosen `head_block_hash` plus a genuine execution proof for a state the attacker controls is a plausible bridge-theft primitive. Hard-anchoring the validator-set commitment as a *public input from L1 state* is the single most important mitigation.
- **Prover-side trust is explicitly acknowledged by Succinct**: outside parties may run provers, and the docs recommend an *approved prover* whitelist for critical value — which is in tension with a **permissionless** prover fleet.
- **RISC Zero's zero-knowledge caveat** (*"we have not written a mathematical argument to prove that our system is zero-knowledge"*) matters if witness secrecy is relied upon; here the witness is public data, so it is not a blocker.
- **The host is untrusted and has been exploitable** (GHSA-jqq4). Witness generation must therefore never be treated as trusted input; only the journal/public values matter.

---

## 10. Separation of evidence quality

### (1) Compatibility in principle — *high confidence, documentary*

| Claim | Evidence class |
|---|---|
| Both zkVMs are STARK-based general-purpose RISC-V machines with a Groth16 (RZ) / Groth16+PLONK (SP1) on-chain wrap | Official docs, fetched |
| keccak256, sha256, secp256k1, Ed25519, bn254, bigint/modexp are all accelerated in both stacks | Official precompile pages + syscall enumeration |
| RISC Zero ships a patched **c-kzg-4844** and a patched **blst**, i.e. the vendor intends EIP-4844 KZG to run in-guest | Official precompiles page (explicit footnote) |
| SP1 exposes BLS12-381 **add/double/decompress/Fp/Fp2** syscalls but **no MSM and no pairing syscall** | Full `sp1-lib` rustdoc index, fetched |
| Both provide recursion/aggregation capable of combining per-batch proofs | Official docs (RZ `lift/join/resolve`; SP1 aggregation example + `syscall_verify_sp1_proof`) |
| Both provide explicit upgrade/version-management machinery for on-chain verifiers | RZ version-management design; SP1 gateway versioning policy |

### (2) Evidence from existing implementations or published benchmarks — *sparse*

| What exists | What it does **not** cover |
|---|---|
| SP1 Hypercube: 16×RTX 5090, 954 L1 Ethereum blocks, 99.7% <12 s / 95.4% <10 s | Consensus/QC verification; blob KZG; RISC Zero; this workload's `C` |
| SP1 local proving memory floors (14 GB Groth16 wrap, 60 GB PLONK wrap) | Throughput |
| RISC Zero audit reports incl. a 2026-02-12 zkVM report | Throughput — **no published per-machine benchmark found at all** |
| Vendor-published advisories on both systems | — |
| **No published end-to-end "batch proof" latency for either system on an Ethereum L2 with a consensus proof attached was found** | — |

### (3) Analytical estimates — *clearly labelled as such*

- The **concurrency requirement** `Q = L/Δ` (≈**900** in-flight proofs at Δ=2 s, L=30 min) follows from arithmetic on the stated constraints, not from measurement.
- `FLEET = max(e·G·C/R, (L/Δ)·k)` is an identity, not an estimate.
- The claim that **W1 is cheap relative to W2** (signature verification + a Merkle walk vs. full EVM execution) is an inference from the shape of the work, **not** measured. It is the basis for the per-epoch amortization idea in §6/§7 and should be tested first.
- The claim that **BLS12-381 MSM for 4096 elements dominates the blob path** is inferred from the EIP's own parameterisation (4096 field elements per blob) — the *constant* is sourced; the *cost* is not.

### (4) Unmeasured implementation questions

1. What is `C` (cycles per L2 gas) for an Etna-style EVM guest **including** tx-signature recovery and trie hashing?
2. What is `R` (proven cycles/s) for each system on the chosen hardware, for a guest of this size (which determines memory pressure and whether the ~2 GB SP1 memory ceiling forces sharding)?
3. Does RISC Zero's `blst` patch accelerate **MSM and pairing** as single ops, and at what cost?
4. Can a 4096-point KZG MSM (or an opening check) be built in SP1 **without a pairing syscall**, and is the resulting proof verifiable given the on-curve / distinct-x / no-infinity constraints?
5. Can the Ethereum KZG SRS be loaded into the guest within the memory envelope of either zkVM?
6. What is the **audited** cost of the SNARK wrap in each system for a guest of this size (SP1 documents +1m30s for PLONK; RISC Zero publishes nothing)?
7. How many verifier routes must the L1 contract hold open, and what is the governance latency vs. the prover fleet's release cadence?
8. What is the actual on-chain gas of RISC Zero Groth16 verification, and does the SP1 ~270k/~300k figure still hold for the V6.1.0 verifier?

---

## 11. Recommendation (combined vs. composed)

**COMBINED is the better default for the Etna batch proof**, with composition retained as an *optimization* rather than the primary architecture. Reasons, in order of evidential weight:

1. **One TCB, one verifier route, one version to govern.** The dominant long-run risk in §8/§9 is stale-version acceptance and auditor lag, not on-chain gas. Every additional verifier route doubles that surface.
2. **The 30-minute latency budget removes the main argument for composition.** Composed proofs win when the consensus half can be produced much earlier than the execution half *and* latency is binding. Here latency is explicitly not binding.
3. **Recursive composition re-introduces the exact bug class that has already been exploited.** SP1's most recent high-severity advisory (**GHSA-63x8**) was a *recursion-circuit* soundness gap; making the recursion circuit load-bearing for bridge security should require strong justification.
4. **On-chain composition costs ~2× verification** (≈2×270–300k gas per the only sourced figures) and adds a journal-equality check that is itself part of the TCB.

**When to switch to COMPOSED:** if (a) the consensus rule is expected to change on a cadence different from the EVM, or (b) per-epoch aggregation of the consensus proof produces a measured, material cost reduction. In that case the composed design **must** (i) enforce the inner program identity in-circuit, and (ii) compare journals on L1, and (iii) never let an inner proof's version float.

**Non-negotiable design invariants, independent of the choice:**

- `validator_set_commitment`, `validator_set_version`/`epoch`, `quorum_threshold`, `chain_id`, `prev_state_root` and the DA commitment are **public inputs derived from L1 state**, never prover-supplied witnesses.
- The guest re-derives membership and stake from that commitment and **verifies the signatures**; it never trusts a hint about who signed.
- For blobs, bind to the **KZG commitment / versioned hash**, not to a keccak of the bytes.
- The DA mode is domain-separated so a calldata proof can never satisfy a blob rule.
- The L1 contract pins **bounded batch ranges**, so a proof cannot be replayed for a different head.

---

## Sources

All URLs retrieved **2026-10-05**. "Version" is the version/tag the page documents, where determinable.

| # | URL | Version / tag | Used for |
|---|---|---|---|
| S1 | [api.github.com/repos/risc0/risc0/releases](https://api.github.com/repos/risc0/risc0/releases) | v3.0.6 (2026-07-17), v5.0.0-rc.1 (2026-01-15) | RZ release pins |
| S2 | [crates.io/api/v1/crates/risc0-zkvm](https://crates.io/api/v1/crates/risc0-zkvm) | risc0-zkvm 3.0.6 (max_version 5.0.0-rc.1) | RZ crate pin |
| S3 | [raw Cargo.toml @v3.0.6](https://raw.githubusercontent.com/risc0/risc0/v3.0.6/Cargo.toml) | tag v3.0.6 | RZ circuit/crate matrix |
| S4 | [RZ recursion](https://dev.risczero.com/api/next/recursion) | docs "Next" (3.0 = latest) | lift/join/resolve/identity_p254, 200 kB SuccinctReceipt, 3 circuits |
| S5 | [RZ trust: Trusted Setup](https://dev.risczero.com/api/next/trusted-setup-ceremony) | docs "Next" | Groth16 ceremony, PSE, Hermez 2^23 |
| S6 | [RZ Cryptographic Security Model](https://dev.risczero.com/api/next/security-model) | docs "Next" | Component/audit table, control root, ZK caveat |
| S7 | [RZ precompiles](https://dev.risczero.com/api/next/zkvm/precompiles) | docs "Next" | Patched-crate table incl. c-kzg, blst, bls12_381, substrate-bn; timing-attack caveat |
| S8 | [RZ verifier contracts](https://dev.risczero.com/api/next/blockchain-integration/contracts/verifier) | docs "Next" | Router usage, image ID |
| S9 | [RZ shrink-wrapping](https://dev.risczero.com/api/next/blockchain-integration/shrink-wrapping) | docs "Next" | Groth16-only wrap |
| S10 | [RZ proof composition](https://dev.risczero.com/api/next/zkvm/composition) | docs "Next" | Assumptions / resolve |
| S11 | [RZ benchmarks](https://dev.risczero.com/api/next/zkvm/benchmarks) | docs "Next" | "generate your own datasheet" |
| S12 | [RZ Secure SDLC](https://dev.risczero.com/api/next/secure-sdlc) | docs "Next" | Audit/advisory links |
| S13 | [risc0 README @v3.0.6](https://raw.githubusercontent.com/risc0/risc0/v3.0.6/README.md) | v3.0.6 | "98 bits of conjectured security" |
| S14 | [risc0-ethereum v3.0.1 deployment.toml](https://raw.githubusercontent.com/risc0/risc0-ethereum/v3.0.1/contracts/deployment.toml) | v3.0.1 | Router address, selectors, timelock |
| S15 | [RZ version-management-design.md](https://raw.githubusercontent.com/risc0/risc0-ethereum/release-1.0/contracts/version-management-design.md) | risc0-ethereum (release-1.0 branch) | Router/estop/selector semantics |
| S16 | [risc0 advisories API](https://api.github.com/repos/risc0/risc0/security-advisories) | — | GHSA list + fix versions |
| S17 | [GHSA-jqq4-c7wq-36h7](https://api.github.com/repos/risc0/risc0/security-advisories/GHSA-jqq4-c7wq-36h7) | — | `sys_read` critical advisory |
| S18 | [rz-security audits](https://api.github.com/repos/risc0/rz-security/contents/audits) + [zkVM](https://api.github.com/repos/risc0/rz-security/contents/audits/zkVM) + [precompiles](https://api.github.com/repos/risc0/rz-security/contents/audits/precompiles) | — | Audit inventory |
| S19 | [RZ docs sitemap](https://dev.risczero.com/sitemap.xml) | — | Doc version inventory |
| S20 | [SP1 releases API](https://api.github.com/repos/succinctlabs/sp1/releases?per_page=5) | v6.8.1 (2026-09-24) | SP1 release pin + cadence |
| S21 | [crates.io sp1-zkvm](https://crates.io/api/v1/crates/sp1-zkvm) | 6.8.1 | SP1 crate pin |
| S22 | [SP1 contract addresses](https://docs.succinct.xyz/docs/sp1/verification/contract-addresses) | docs current | Supported versions V5.x.y/V6.1.0, gateways |
| S23 | [sp1-contracts deployments/1.json @v6.1.1](https://raw.githubusercontent.com/succinctlabs/sp1-contracts/v6.1.1/contracts/deployments/1.json) | v6.1.1 | Per-version mainnet verifier addresses |
| S24 | [sp1-contracts releases](https://api.github.com/repos/succinctlabs/sp1-contracts/releases) | v6.1.1 (2026-04-28) | Contracts repo pin |
| S25 | [SP1 proof types](https://docs.succinct.xyz/docs/sp1/generating-proofs/proof-types) | docs current | core/compressed/plonk/groth16, ~260 B/~270k gas, ~868 B/~300k gas, +1m30s |
| S26 | [SP1 security model](https://docs.succinct.xyz/docs/sp1/security/security-model) | docs current | Poseidon2/KoalaBear, FRI, trusted setups, 18 contributors, approved prover |
| S27 | [SP1 safe precompile usage](https://docs.succinct.xyz/docs/sp1/security/safe-precompile-usage) | docs current | On-curve/alignment/canonical/bigint constraints; code4rena bounty link |
| S28 | [SP1 precompiles](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles) | docs current | Patched crates, keccak regression warning |
| S29 | [SP1 precompile specification](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompile-specification) | docs current | ecall / custom STARK tables |
| S30 | [sp1-lib rustdoc 6.8.1](https://docs.rs/sp1-lib/latest/sp1_lib/) | 6.8.1 (2026-09-24) | Full syscall enumeration; `unconstrained!` ecrecover note |
| S31 | [sp1-lib::bls12381](https://docs.rs/sp1-lib/latest/sp1_lib/bls12381/index.html) | 6.8.1 | Only `decompress_pubkey` named helper |
| S32 | [SP1 proof aggregation](https://docs.succinct.xyz/docs/sp1/writing-programs/proof-aggregation) | docs current | Aggregation + caveats + ~2 GB limit |
| S33 | [SP1 Hypercube](https://docs.succinct.xyz/docs/sp1/hypercube/) | docs current | 2^22 shards, sub-protocols |
| S34 | [SP1 Hypercube 16 GPUs](https://blog.succinct.xyz/real-time-proving-16-gpus/) | "latest version of SP1 Hypercube" | 16×RTX 5090, 954 blocks, 99.7% <12 s |
| S35 | [SP1 upgrade guides](https://docs.succinct.xyz/docs/sp1/developers/upgrades) | docs current | V6 breaking changes |
| S36 | [SP1 hardware requirements](https://docs.succinct.xyz/docs/sp1/getting-started/hardware-requirements) | docs current | Local minimums, wrap memory |
| S37 | [SP1 hardware acceleration](https://docs.succinct.xyz/docs/sp1/generating-proofs/hardware-acceleration) | docs current | CUDA, 24 GB VRAM, CC ≥ 8.0 |
| S38 | [SP1 prover gas](https://docs.succinct.xyz/docs/sp1/optimizing-programs/prover-gas) | >= 4.1.4 | Metric |
| S39 | [sp1 advisories API](https://api.github.com/repos/succinctlabs/sp1/security-advisories) | — | GHSA list |
| S40 | [GHSA-63x8-x938-vx33](https://api.github.com/repos/succinctlabs/sp1/security-advisories/GHSA-63x8-x938-vx33) | affects 6.0.0–6.0.2, fixed 6.1.0 | V6 recursion soundness gap |
| S41 | [sp1 audits dir](https://api.github.com/repos/succinctlabs/sp1/contents/audits?ref=dev) + [commit history](https://api.github.com/repos/succinctlabs/sp1/commits?path=audits&per_page=12) | dev | Audit inventory + dates |
| S42 | [EIP-4844](https://eips.ethereum.org/EIPS/eip-4844) | Final EIP text | 4096 elements, versioned hash, point-eval precompile |
| S43 | [c-kzg-4844 README](https://raw.githubusercontent.com/risc0/c-kzg-4844/main/README.md) | risc0 fork | KZG API inventory |
| S44 | [Wrapping up the KZG Ceremony](https://blog.ethereum.org/en/2024/01/23/kzg-wrap) | EF blog 2024-01-23 | KZG ceremony exists; largest MPC of its kind by participant count |
| S45 | [SP1 docs sitemap](https://docs.succinct.xyz/sitemap.xml) | — | Doc inventory |
| S46 | [code4rena.com/bounties/succinct](https://code4rena.com/bounties/succinct) | JS-rendered, no content extracted | Existence of an SP1 bounty |

---

## Appendix — UNVERIFIED register (do not cite as fact)

| # | Item | Why it matters |
|---|---|---|
| U1 | Any per-machine proving throughput for RISC Zero on any workload | Blocks §7 entirely for RZ |
| U2 | `C` (cycles per L2 gas) for the Etna workload, either system | Blocks fleet sizing |
| U3 | Whether RZ accelerates BLS12-381 **MSM** and **pairing** as single ops | Decides blob-path feasibility |
| U4 | Whether SP1 can do a BLS12-381 **pairing** at acceptable cost without a pairing syscall | Decides whether KZG *opening* checks are possible in SP1 |
| U5 | In-guest cost of a 4096-point MSM (either system) | Dominant blob-path cost driver |
| U6 | Whether the Ethereum KZG SRS fits in the guest (SP1 docs state a ~2 GB zkVM memory limit) | Blob-path feasibility |
| U7 | RISC Zero on-chain Groth16 verify gas (no official figure found) | L1 affordability |
| U8 | Contents of RISC Zero `v5.0.0-rc.1` (empty release body) | Future upgrade path |
| U9 | The SP1 release → verifier-version/VKEY mapping (docs pin V5.x.y/V6.1.0; SDK is 6.8.1) | Live version-skew hazard |
| U10 | RISC Zero control IDs / control root values at v3.0.6 | Verifier pinning |
| U11 | Groth16 ceremony participant counts (RZ) and bounty amounts (both) | Trust/supply-chain assessment |
| U12 | Per-precompile trace-level constraint descriptions (both vendors) | Depth of the trust-model claim in §3.2 |
| U13 | Full text of SP1's aggregation warning and of its "Zero-Knowledgeness of SP1" section | Completeness of §2/§6 |
| U14 | Any published end-to-end L2 batch-proof latency, either system | §7 transferability |


