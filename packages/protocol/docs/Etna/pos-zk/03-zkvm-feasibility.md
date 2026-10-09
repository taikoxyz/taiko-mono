# 03 — zkVM feasibility: RISC Zero and SP1 at pinned versions

> **Status:** consolidated deliverable · **Phase:** 2 (parallel research) · **Date:** 2026-10-05 (Asia/Singapore) · **Baseline pin:** `7718753c1cece7d7705afaf33e6f9680115086dd` (branch `etna-pos-zk`) · **Prior Etna pin:** `a829f79723de9a09205660d9895418577cfe9aa9` (branch `etna/converged-spec`, read-only)
>
> **Consolidated from:** [research/zkvm-feasibility-raw.md](research/zkvm-feasibility-raw.md) — the raw evidence file, read in full. The raw file is **not modified** and remains the unedited evidence record. This study supports the proof statement in [spec/05-proof-statement.html](spec/05-proof-statement.html) (`PRF-01`…`PRF-13`) and the proof-shape selection in [04-architecture-decision.md](04-architecture-decision.md) §§4, 6. Where this document and the specification disagree, the specification wins.
>
> **Retrieval date for every external source: 2026-10-05.** Every version, address, gas figure, size and cryptographic claim below is traced to a URL that was retrieved; anything not so traced keeps the marker **UNVERIFIED**. No cycle count, GPU throughput, proving cost or latency has been invented here. Numbers are tagged `sourced`, `derived` or `unmeasured`; none is a measurement by us.
>
> **Evidence classes** follow [spec/index.html](spec/index.html) rule `GEN-08`: **[1]** compatibility in principle · **[2]** existing implementation or published benchmark (with version, hardware, workload and transferability) · **[3]** analytical estimate · **[4]** unmeasured implementation question. Section 13 separates the four.
>
> **Section map for cross-references written against the raw file:** raw §3.1 (capability matrix) is this document's §4.1; raw §9 (supply chain and advisories) is §12 here. The SP1 recursion advisory is discussed in §9 and §12.

## 1. What a reader should take from this

1. **The statement in [spec/05-proof-statement.html](spec/05-proof-statement.html) is expressible in one guest on both backends at the pinned versions.** Every everyday primitive the statement needs — keccak256, sha256, secp256k1 verify, Ed25519, bn254, bigint/modexp — is documented as circuit-accelerated on both (§4). [1]
2. **"Accelerated" is not a security argument, and the trust model is per mechanism.** Circuit accelerators are constrained by their STARK tables/circuits, but host reads and unconstrained regions are not; the guest-side usage constraints (canonical field elements, on-curve checks, distinct x, no infinity, the `sys_bigint` bound, 4-byte alignment, no direct `ECALL` halt) are part of the trusted code base (§5, `PRF-11`). [1]
3. **The live version-skew hazard is unresolved and is the top integration risk.** SP1 documentation pins supported versions to V5.x.y / V6.1.0 while the SDK is 6.8.1 and mainnet carries V6_1_0 verifiers; the mechanism mapping a release to a verifier VKEY is **UNVERIFIED** (§2.3). [4]
4. **Both on-chain wrappers add a trusted setup the STARK does not need, and neither wrapper is post-quantum.** RISC Zero: circuit-specific Groth16 ceremony on PSE infrastructure (Hermez 2^23 ptau). SP1: circuit-specific Groth16 with 18 named contributors, or PLONK over the universal Aztec Ignition SRS. No vendor post-quantum claim was fetched for either (§3). [1]/[4]
5. **The blob path must not rely on in-guest MSM or in-guest pairings.** RISC Zero's patched `blst`/`c-kzg` are documented as patched crates, but MSM and pairing acceleration are **UNVERIFIED**; SP1 exposes BLS12-381 add/double/decompress/Fp/Fp2 syscalls but has no MSM and no pairing syscall (§4, §6). [1]
6. **A keccak commitment is not the protocol's KZG commitment.** The versioned hash is `0x01 ++ sha256(commitment)[1:]` over a BLS12-381 G1 point built from 4096 field elements; a guest that only checks keccak proves "I saw these bytes", not "this is the polynomial L1's DA layer addresses" (§6). [1]
7. **The chosen binding sidesteps in-guest MSM and pairings entirely:** in-guest Lagrange evaluation of the executed blob field elements at an on-chain Fiat–Shamir challenge `z`, plus an on-chain KZG opening check through the point-evaluation precompile (`0x0A`, 50,000 gas, EIP-4844). Premises: KZG binding, random-oracle-model Fiat–Shamir, canonical field elements, correct in-guest field arithmetic. In-guest cost is **UNMEASURED** (§7, `PRF-07`). [1]/[4]
8. **The calldata path remains the unconditionally sound and best-evidenced alternative**, and the design keeps both paths domain-separated so a calldata proof can never satisfy a blob rule (`PRF-07(a)` vs `(b)`). [1]
9. **One combined guest is the recommendation** (one TCB, one verifier route, one program identity to govern); composition is retained only as an optimisation gated on two conditions (§14). [3]
10. **Aggregation is a cost/latency optimisation only, and it is constrained:** the outer program must hard-code accepted inner program identities, must expose the verified `(predecessor, successor, data commitment)` triples in its own journal, and the L1 contract must compare journals rather than trust them (§9, `PRF-12`). [1]
11. **Throughput cannot be sized from published evidence.** No vendor publishes the numbers this design needs (`C` = cycles per L2 gas for this workload; `R` = proven cycles/s per machine). The one sourced benchmark (§10: SP1 Hypercube, 16×RTX 5090, 954 L1 Ethereum blocks, 99.7% under 12 s) transfers only to a W2-like execution component and says nothing about W1, blob KZG, RISC Zero or Etna's smaller blocks. The arithmetic consequence that does transfer is Little's law: at Δ = 2 s and L = 1800 s, **≈900 proofs in flight**. [2]/[3]
12. **Supply-chain risk is material and a soundness bug is bridge-theft class.** Both vendors shipped high/critical soundness advisories recently; the remediation is a new circuit plus a new verifier route, not a contract patch. SP1 shipped 5 releases in 29 days against RISC Zero's 3-day router timelock and a longer audit cycle (§11, §12). [1]/[2]

## 2. Version pin record

All items verified 2026-10-05 against the URLs in the rows. No version is inferred from a page banner where an API/tag value exists.

### 2.1 RISC Zero

| Item | Pinned value | Verification source |
|---|---|---|
| Latest **stable** release tag | **v3.0.6, published 2026-07-17** | [GitHub releases API](https://api.github.com/repos/risc0/risc0/releases) |
| `risc0-zkvm` crate | **3.0.6** (`max_stable_version`); `max_version` = **5.0.0-rc.1**; 91 versions | [crates.io API](https://crates.io/api/v1/crates/risc0-zkvm) |
| Prerelease | **v5.0.0-rc.1, published 2026-01-15** — release body empty, contents **UNVERIFIED** | [GitHub releases API](https://api.github.com/repos/risc0/risc0/releases) |
| Workspace version at tag v3.0.6 | `[workspace.package] version = "3.0.0"` | [raw Cargo.toml @v3.0.6](https://raw.githubusercontent.com/risc0/risc0/v3.0.6/Cargo.toml) |
| `risc0-build` | **3.0.6** | same |
| `risc0-zkp` | **3.0.5** | same |
| `risc0-circuit-rv32im` (RISC-V circuit) | **4.0.5** | same |
| `risc0-circuit-recursion` (recursion circuit) | **4.0.5** | same |
| `risc0-circuit-keccak` (dedicated Keccak circuit) | **4.0.6** | same |
| `risc0-groth16` (STARK→SNARK) | **3.0.5** | same |
| `risc0-bigint2` | **1.4.14** | same |
| `risc0-zkos-v1compat` | **2.2.3** | same |
| `rzup` toolchain manager | **0.5.2** | same |
| Verifier contracts repo | **risc0-ethereum v3.0.1, published 2025-11-06** | [risc0-ethereum releases API](https://api.github.com/repos/risc0/risc0-ethereum/releases) |
| Mainnet verifier **router** | `0x8EaB2D97Dfce405A1692a21b3ff3A172d593D319` | [deployment.toml @v3.0.1](https://raw.githubusercontent.com/risc0/risc0-ethereum/v3.0.1/contracts/deployment.toml) |
| Router admin timelock | 259200 s (3 days) | same |
| Deployed Groth16 verifier versions + **selectors** | 1.1.0-rc.3 `0x50bd1769`; 1.2.0 `0xc101b42b`; 2.0.0-rc.3 `0x9f39696c` (**stopped**); 2.1.0 `0xf536085a` (**stopped**); 2.2.0 `0xbb001d44`; **3.0.0 `0x73c457ba`** | same |
| Docs site version inventory | dev.risczero.com serves versions 1.0 … 3.0 plus Next; **3.0 is "latest"**, Next is unreleased | [sitemap](https://dev.risczero.com/sitemap.xml) + page banner |
| Verifier architecture | base verifiers are **stateless + immutable**; `RiscZeroVerifierRouter` routes on a 4-byte selector; each implementation has a `RiscZeroVerifierEmergencyStop` proxy; selector derived from a hash of label + params (**Groth16 vkey + control root**) | [version-management-design.md](https://raw.githubusercontent.com/risc0/risc0-ethereum/release-1.0/contracts/version-management-design.md) |
| Image ID vs control root | Image ID = hash of the guest ELF; **control root** = the allowed recursion programs (`lift`, `join`, `resolve`, `identity_p254`), each with a control ID. The control root is hard-coded into the on-chain verifier and also passed as a public input to the STARK→SNARK circuit, "allowing for updates to our RISC-V Prover without requiring a new trusted setup ceremony" | [security-model](https://dev.risczero.com/api/next/security-model), [recursion](https://dev.risczero.com/api/next/recursion) |

### 2.2 SP1

| Item | Pinned value | Verification source |
|---|---|---|
| Latest release tag | **v6.8.1, published 2026-09-24** | [SP1 releases API](https://api.github.com/repos/succinctlabs/sp1/releases?per_page=5) |
| Recent release cadence | v6.5.0 (2026-08-26), v6.6.0 (2026-09-02), v6.7.0 (2026-09-07), v6.8.0 (2026-09-11), v6.8.1 (2026-09-24) — **5 releases in 29 days** | same |
| `sp1-zkvm` crate | **6.8.1** (`max_stable_version`, updated 2026-09-24; 69 versions) | [crates.io API](https://crates.io/api/v1/crates/sp1-zkvm) |
| `sp1-lib` | **6.8.1**, published 2026-09-24 | [docs.rs sp1-lib](https://docs.rs/sp1-lib/latest/sp1_lib/) |
| Verifier contracts repo | **sp1-contracts v6.1.1, published 2026-04-28** (v6.1.0 2026-04-15; v6.0.0 2026-02-18) | [sp1-contracts releases API](https://api.github.com/repos/succinctlabs/sp1-contracts/releases) |
| **Officially supported versions (documentation)** | "The current officially supported versions of SP1 are **V5.x.y and V6.1.0** (Hypercube)." | [contract-addresses](https://docs.succinct.xyz/docs/sp1/verification/contract-addresses) |
| Mainnet **Groth16** gateway | `0x397A5f7f3dBd538f23DE225B51f532c34448dA9B` | same + [deployments/1.json @v6.1.1](https://raw.githubusercontent.com/succinctlabs/sp1-contracts/v6.1.1/contracts/deployments/1.json) |
| Mainnet **PLONK** gateway | `0x3B6041173B80E77f038f3F2C0f9744f04837185e` | same |
| Per-version mainnet verifiers | V5_0_0 Groth16 `0x50ACFBE…` / PLONK `0x0459d5…`; V6_0_0 Groth16 `0x99A74A…` / PLONK `0x8a0fd5…`; **V6_1_0 Groth16 `0xb69f2584…` / PLONK `0xc3c6dDDA…`** (addresses truncated as published) | [deployments/1.json @v6.1.1](https://raw.githubusercontent.com/succinctlabs/sp1-contracts/v6.1.1/contracts/deployments/1.json) |
| Gateway route additions | `safe-batches/1_add-route_v6_0_0.json`, `1_add-route_v6_1_0.json` | [sp1-contracts tree @v6.1.1](https://api.github.com/repos/succinctlabs/sp1-contracts/git/trees/v6.1.1?recursive=1) |
| Proving modes | `core` (STARK, size ∝ execution), `compressed` (constant-size STARK, recursively verifiable **inside SP1**), `plonk` (~868 bytes SNARK), `groth16` (~260 bytes SNARK) | [proof-types](https://docs.succinct.xyz/docs/sp1/generating-proofs/proof-types) |
| SP1 Hypercube | shards of ~**2^22 RISC-V instructions**; sub-protocols Zerocheck, **Jagged PCS** ([ePrint 2025/917](https://eprint.iacr.org/2025/917)), LogUp GKR ([ePrint 2023/1284](https://eprint.iacr.org/2023/1284)), Basefold ([ePrint 2024/1571](https://eprint.iacr.org/2024/1571)); shard proofs recursively aggregated | [hypercube](https://docs.succinct.xyz/docs/sp1/hypercube/) |
| Prover-gas metric | introduced in versions **>= 4.1.4** | [prover-gas](https://docs.succinct.xyz/docs/sp1/optimizing-programs/prover-gas) |
| Documentation inventory | SP1 docs sitemap fetched; version-specific pages are "current" and unversioned | [SP1 sitemap](https://docs.succinct.xyz/sitemap.xml) |

### 2.3 Version-skew hazards (unresolved)

| # | Hazard | Evidence (2026-10-05) | Consequence for this design |
|---|---|---|---|
| V1 | **Docs pin ≠ SDK pin.** The canonical mainnet deployment exposes a V6.1.0 verifier and the docs state V5.x.y / V6.1.0 are supported, while the SDK/crates are at **6.8.1** | [contract-addresses](https://docs.succinct.xyz/docs/sp1/verification/contract-addresses) vs [crates.io sp1-zkvm](https://crates.io/api/v1/crates/sp1-zkvm) | An operator who upgrades the prover without checking the route produces proofs L1 rejects → **liveness** failure; a contract left accepting an old route → **soundness** exposure |
| V2 | **Release → verifier-version/VKEY mapping is UNVERIFIED.** Which SP1 SDK version the mainnet V6.1.0 verifier actually accepts cannot be asserted from the fetched sources | — | The acceptance policy (`PRF-09`) and the fleet upgrade runbook cannot be written as fact yet; the mapping must be established by test before launch |
| V3 | **RISC Zero `v5.0.0-rc.1`** (published 2026-01-15) has an empty release body; no docs version maps to 5.x; whether its circuit line changes the crypto precompile set is **UNVERIFIED** | [releases API](https://api.github.com/repos/risc0/risc0/releases), [sitemap](https://dev.risczero.com/sitemap.xml) | The next RISC Zero circuit line is an unquantified upgrade step (§11) |
| V4 | **Aggregation can pin an old inner circuit into a new outer route.** An aggregate proof's route follows the *outer* identity, so an inner, superseded (possibly vulnerable) circuit can remain load-bearing | [proof-aggregation](https://docs.succinct.xyz/docs/sp1/writing-programs/proof-aggregation), [recursion](https://dev.risczero.com/api/next/recursion) | `PRF-12` requires the outer guest to hard-code accepted inner identities; otherwise aggregation is a stale-version bypass (§9) |
| V5 | **Release cadence vs audit/governance latency.** SP1: 5 releases in 29 days; RISC Zero router additions sit behind a 3-day timelock; an audit cycle is longer than either | [SP1 releases API](https://api.github.com/repos/succinctlabs/sp1/releases?per_page=5), [deployment.toml @v3.0.1](https://raw.githubusercontent.com/risc0/risc0-ethereum/v3.0.1/contracts/deployment.toml) | A prover fleet can move faster than the L1 verifier's upgrade path; the protocol must decide which side waits (§11) |
### 2.4 Could not verify (carried from the raw file)

| Item | Status |
|---|---|
| Contents of RISC Zero `v5.0.0-rc.1` (empty release body; no docs version mapped to 5.x) | **UNVERIFIED** |
| Which SP1 SDK version the canonical mainnet `V6.1.0` verifier accepts, and the release→VKEY mapping | **UNVERIFIED** |
| RISC Zero circuit **identity hashes** (control IDs / control root values) for v3.0.6 | **UNVERIFIED** (not published on the pages fetched) |
| Exact verifier **gas** for RISC Zero Groth16 on Ethereum from an official source | **UNVERIFIED** |
| Whether the `5.0.0-rc.1` circuit line changes the crypto precompile set | **UNVERIFIED** |

## 3. Trusted setup and cryptographic assumptions

### 3.1 RISC Zero (v3.0.6 / risc0-ethereum v3.0.1)

| Property | Finding | Source |
|---|---|---|
| Proof system | STARKs for the RISC-V circuit and the recursion circuit; an **R1CS STARK→SNARK circuit** verifies recursion proofs | [recursion](https://dev.risczero.com/api/next/recursion) |
| STARK-only mode | Yes — `ReceiptKind::Composite` / `Succinct`; a `SuccinctReceipt` is a STARK of ~200 kB | [recursion](https://dev.risczero.com/api/next/recursion), [shrink-wrapping](https://dev.risczero.com/api/next/blockchain-integration/shrink-wrapping) |
| Wrapped SNARK | **Groth16** is "the only currently officially supported shrink-wrapping type" | [shrink-wrapping](https://dev.risczero.com/api/next/blockchain-integration/shrink-wrapping) |
| Trusted setup | **Circuit-specific Groth16 ceremony** on **PSE's ceremony infrastructure** (`ceremony.pse.dev`, "RISC Zero STARK-to-SNARK Prover" page). Circuit = `stark_verify.circom` + `risc0.circom`; Powers of Tau = **Hermez rollup, 2^23 powers**; reference `r1cs` SHA-256 = `84d3c34b7c0eb55ad1b16b24f75e0b9de307f7b74089ea4a20a998390ee24178`; verified with circom **v2.2.2** + snarkjs | [trusted-setup-ceremony](https://dev.risczero.com/api/next/trusted-setup-ceremony) |
| What the setup secures | "This ceremony secures our STARK Verify circuit so we can publish Groth16 receipts for our general purpose zkVM to limited-memory environments like blockchains." | same |
| Ceremony participant count | **UNVERIFIED** (verification procedure documented; no participant list fetched) | — |
| Recursion pipeline | `lift` → `join` (pairwise) → `resolve` (assumption removal) → `identity_p254` → `compress()` → `Groth16Receipt` | [recursion](https://dev.risczero.com/api/next/recursion) |
| Conjectured security | "With default parameters, this system achieves perfect zero-knowledgeness and 98 bits of conjectured security." | [README @v3.0.6](https://raw.githubusercontent.com/risc0/risc0/v3.0.6/README.md) |
| Zero-knowledge caveat | "we have not written a mathematical argument to prove that our system is zero-knowledge" | [security-model](https://dev.risczero.com/api/next/security-model) |
| Wrapper proof size / verifier gas | **UNVERIFIED** — not published on the pages fetched; no official gas number located | — |

### 3.2 SP1 (v6.8.1 / sp1-contracts v6.1.1)

| Property | Finding | Source |
|---|---|---|
| Proof system | Hypercube: multilinear IOP over **KoalaBear** (`p = 2^31 − 2^24 + 1`) with **Poseidon2**, width 16, S-box degree 3, 8 external / 20 internal rounds (Plonky3 parameters) | [security-model](https://docs.succinct.xyz/docs/sp1/security/security-model) |
| Fiat–Shamir | Random-oracle model over Poseidon2; "we ensure that the depth of the overall circuit being proven is less than that of the Poseidon hash, thereby avoiding the recent Fiat–Shamir attack" | same |
| FRI assumptions | "SP1 Hypercube does not rely on proximity gap conjectures. Rather, it relies on proximity gap theorems established in (<https://eprint.iacr.org/2020/654.pdf>), while operating in the unique decoding regime." | same |
| Trusted setup — PLONK | "For PLONK, SP1 uses the Aztec Ignition ceremony, which is a universal trusted setup designed for reuse across multiple circuits." Cost: **3–4× Groth16 proving** | same |
| Trusted setup — Groth16 | **Circuit-specific ceremony** run by Succinct with **18 named contributors** (Etherealize, Polygon, OP Labs, Alpen Labs, Offchain Labs, Coinbase, Across, Succinct); artifacts generated with **Semaphore**. "circuit-specific ceremonies inherently carry higher trust assumptions"; "Users uncomfortable with these security assumptions are strongly encouraged to use PLONK instead." | same |
| Documentation inconsistency | The proof-types page says "PLONK does not require a trusted setup and reuses contributions from the Aztec Ignition ceremony", while the security model calls Aztec Ignition a *universal trusted setup*. Both fetched verbatim; treat the proof-types phrasing as loose — a universal SRS is still a setup | [proof-types](https://docs.succinct.xyz/docs/sp1/generating-proofs/proof-types) vs [security-model](https://docs.succinct.xyz/docs/sp1/security/security-model) |
| On-chain gas (official figure) | Groth16: **~260 bytes, ~270k gas**; PLONK: **~868 bytes, ~300k gas**; "Plonk proofs take about ~1m30s longer to generate over a compressed proof" | [proof-types](https://docs.succinct.xyz/docs/sp1/generating-proofs/proof-types) |
| Zero-knowledge | A dedicated "Groth16, PLONK, and the Zero-Knowledgeness of SP1" section exists; heading fetched, full text not read → **UNVERIFIED** | [security-model](https://docs.succinct.xyz/docs/sp1/security/security-model) |
| **Approved-prover doctrine** | "we officially recommend the use of an approved prover for any application handling critical or sensitive amounts of value. An approved prover refers to an implementation where there is a list of whitelisted provers or oracles who provide an additional sanity check that the proof's claimed outputs are correct." | same |
| Proof type semantics | `compressed` is explicitly **not** for on-chain verification; recursive verification inside SP1 requires a `compressed` inner proof | [proof-types](https://docs.succinct.xyz/docs/sp1/generating-proofs/proof-types), [proof-aggregation](https://docs.succinct.xyz/docs/sp1/writing-programs/proof-aggregation) |
### 3.3 Side-by-side, and post-quantum considerations

| Dimension | RISC Zero (v3.0.6 / risc0-ethereum v3.0.1) | SP1 (v6.8.1 / sp1-contracts v6.1.1) |
|---|---|---|
| Native proof | STARK (transparent, hash-based) | STARK/Hypercube (transparent, hash-based, Poseidon2/KoalaBear) |
| On-chain wrapper | Groth16 only | Groth16 **or** PLONK |
| Setup assumption for the wrapper | Circuit-specific ceremony (PSE; Hermez 2^23 ptau) | Groth16: circuit-specific, 18 contributors. PLONK: Aztec Ignition universal |
| STARK-only on-chain path | None found → **UNVERIFIED** | None — `compressed` is explicitly not for on-chain verification |
| Wrapper proof size | **UNVERIFIED** (not published on pages fetched) | ~260 B (Groth16) / ~868 B (PLONK), documented |
| On-chain gas | **UNVERIFIED** | ~270k (Groth16) / ~300k (PLONK), documented |
| Post-quantum posture | STARK side hash-based and transparent (plausibly PQ-relevant); Groth16 wrap is not | Same; the Groth16 wrap is not, the PLONK wrap inherits the universal SRS |
| Vendor caveat on prover trust | Secure-SDLC programme, audits, advisories | "Approved prover" whitelist recommended for critical value |

**Post-quantum considerations.** The STARK sides are hash-based and transparent, which is the part of the stack usually described as plausibly post-quantum-relevant; the **on-chain wrappers are not** — Groth16 (both backends) and PLONK (SP1) rely on pairing-based assumptions and on their setup. The Ethereum KZG ceremony is itself a large MPC ([EF blog, 2024-01-23](https://blog.ethereum.org/en/2024/01/23/kzg-wrap), "largest MPC of its kind by participant count") and is not PQ either; the blob path's on-chain check therefore inherits the protocol's own posture, not a new one. **No vendor post-quantum claim was fetched for either zkVM → UNVERIFIED as a vendor statement.** For a long-lived L1 contract (§11) the practical consequence is that a PQ migration would require a new verifier route and a new program identity, exactly like any other upgrade.

## 4. Capability matrix

Legend: **Accelerated** = the vendor documents a dedicated precompile/circuit, or a patched crate that routes the operation to one. **Software** = correct in-guest implementation with no acceleration documented. **UNVERIFIED** = no fetched page states it. A patched crate is *not by itself* proof that the operation is a single accelerated op (see §5.4).

### 4.1 The matrix

| Operation | RISC Zero v3.0.6 | SP1 6.8.1 | Exact documentation source |
|---|---|---|---|
| **keccak256** | **Accelerated** — dedicated `risc0-circuit-keccak` **4.0.6** circuit; patched `tiny-keccak` 2.0.2 (`tiny-keccak/v2.0.2-risczero.0`) | **Accelerated** — `syscall_keccak_permute`; patched `tiny-keccak`, `sha3` | RZ: [Cargo.toml @v3.0.6](https://raw.githubusercontent.com/risc0/risc0/v3.0.6/Cargo.toml), [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles). SP1: [sp1-lib 6.8.1](https://docs.rs/sp1-lib/latest/sp1_lib/), [precompiles](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles). SP1 warns a dropped `sha3` patch silently "drop[s] keccak256 to software (a large cycle regression, since keccak drives MPT/state-root hashing)" |
| **sha256** | **Accelerated** — patched `sha2` (0.10.9/0.10.8/0.10.7/0.10.6/0.9.9); precompiles page names "SHA-256, RSA, elliptic curve, and modular multiplication operations" | **Accelerated** — `syscall_sha256_compress`, `syscall_sha256_extend`; patched `sha2` (`patch-sha2-0.11.0-sp1-6.2.0`, also 0.10.x tags) | RZ [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles); SP1 [sp1-lib](https://docs.rs/sp1-lib/latest/sp1_lib/), [precompiles](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles) |
| **secp256k1 ECDSA verify** | **Accelerated** — patched `k256` (0.13.4…0.13.1); the fork diff routes core EC ops to "the precompiled 256-bit elliptic curve instructions. E.g. `lincomb`." | **Accelerated** — `syscall_secp256k1_add`, `_double`, `_decompress`; patched `k256` (`patch-k256-13.4-sp1-6.0.0`) and `secp256k1` | RZ [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles); SP1 [precompiles](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles) |
| **secp256k1 ECDSA recover** | **UNVERIFIED** — no explicit doc statement that `recover`/`ecrecover` is accelerated; the patched `k256` accelerates the underlying EC ops recovery uses | **Partial / design-dependent** — SP1's `unconstrained!` macro doc explicitly names ecrecover: "running `ecrecover` is expensive in the VM but verifying a signature when you know the public key is not. `unconstrained` can be used to provide the public key without spending VM CPU cycles." The recovered pubkey is **not verified** unless the program separately verifies the signature against it | [sp1-lib 6.8.1](https://docs.rs/sp1-lib/latest/sp1_lib/) |
| **Ed25519 verify** | **Accelerated** — patched `curve25519-dalek` (4.1.3…4.1.0) | **Accelerated** — `syscall_ed_add`, `syscall_ed_decompress`; patched `curve25519-dalek` and `curve25519-dalek-ng` | Both [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles) pages |
| **secp256r1 (P-256)** | **Accelerated** — patched `p256` 0.13.2 | **Accelerated** — `syscall_secp256r1_add`/`_double`/`_decompress`; patched `p256` | Both [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles) pages |
| **BLS12-381 G1/G2 add–double** | **Accelerated (claimed)** — patched `bls12_381` 0.8.0 **and** patched `blst` 0.3.16/0.3.15/0.3.14 | **Accelerated** — `syscall_bls12381_add`, `_double`, `_decompress`, `_fp{,2}_addmod/mulmod/submod` | RZ [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles); SP1 [sp1-lib](https://docs.rs/sp1-lib/latest/sp1_lib/) |
| **BLS12-381 MSM** | **UNVERIFIED** — `blst` is the canonical MSM/pairing library and RISC Zero patches it, but neither the precompiles page nor any fetched page states MSM itself is accelerated | **Not accelerated / absent** — no dedicated syscall; MSM must be composed from `syscall_bls12381_add`/`_double` (O(n) syscalls for n points) | [sp1-lib](https://docs.rs/sp1-lib/latest/sp1_lib/) (full rustdoc index fetched — no MSM syscall) |
| **BLS12-381 pairing** | **UNVERIFIED** — same reasoning: `blst` patch exists, acceleration not documented | **No pairing syscall found.** Whether pairing is reachable at acceptable cost is **UNVERIFIED** | [sp1-lib](https://docs.rs/sp1-lib/latest/sp1_lib/) |
| **BLS signature verification / aggregation** | **UNVERIFIED** (library-level via `blst`/`bls12_381`; acceleration undocumented) | **UNVERIFIED** — only `bls12381::decompress_pubkey` is a named helper; `verify`/`aggregate` are not precompile entry points | [sp1-lib::bls12381](https://docs.rs/sp1-lib/latest/sp1_lib/bls12381/index.html) |
| **bn254 (alt_bn128)** | **Accelerated** — patched `substrate-bn` 0.6.0 | **Accelerated** — `syscall_bn254_add`, `_double`, `_fp{,2}_*`; patched `substrate-bn` | Both [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles) pages |
| **bigint / modexp** | **Accelerated** — `risc0-bigint2` **1.4.14** + patched `crypto-bigint` 0.5.x; audited (`veridise_bigint2_240324.pdf`) | **Accelerated** — `sys_bigint`, `syscall_u256x2048_mul`, `syscall_uint256_{add,mul}_with_carry`, `syscall_uint256_mulmod`; patched `crypto-bigint` | RZ [Cargo.toml](https://raw.githubusercontent.com/risc0/risc0/v3.0.6/Cargo.toml), [audits/precompiles](https://api.github.com/repos/risc0/rz-security/contents/audits/precompiles); SP1 [sp1-lib](https://docs.rs/sp1-lib/latest/sp1_lib/) |
| **RSA** | **Accelerated** — patched `rsa` 0.9.9 | **Accelerated** — patched `rsa` (`patch-0.9.6-sp1-6.0.0`) | Both [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles) pages |
| **Poseidon2** | **UNVERIFIED** — not listed as a patched crate on the page fetched | **Accelerated** — `syscall_poseidon2` | [sp1-lib](https://docs.rs/sp1-lib/latest/sp1_lib/) |
| **EIP-4844 / c-kzg** | **Accelerated (claimed)** — patched `c-kzg` 1.0.3/2.1.0/2.1.1/2.1.5 ([risc0/c-kzg-4844](https://raw.githubusercontent.com/risc0/c-kzg-4844/main/README.md), tag `v2.1.5-risczero.0`). Footnote: "The `c-kzg` crate depends on the `blst` crate (version 0.3.16) and also requires a patched version of `blst` to enable full acceleration." | **No c-kzg patch listed** → in-guest blob KZG must be assembled from BLS12-381 primitives | RZ [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles); SP1 [precompiles](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles) |
### 4.2 What the matrix decides for this design

- **W1 (consensus evidence) and W2 (execution) everyday primitives are covered on both.** Ed25519 verification, SHA-256/keccak, secp256k1 verify, bn254, bigint/modexp and RSA are all documented as accelerated. The architecture decision's choice of CometBFT-native Ed25519 votes rests on this row existing. [1]
- **secp256k1 recovery is the one W2 primitive with a trust-model trap.** On SP1 the documented pattern hands the recovered public key over as a hint; it must then be constrained by verifying the signature against it (`PRF-11`). On RISC Zero the acceleration of `recover` itself is **UNVERIFIED**.
- **The blob path must avoid in-guest MSM and in-guest pairings** because neither is established: RISC Zero's MSM/pairing acceleration is **UNVERIFIED**, and SP1 has no MSM or pairing syscall at all. This is the finding that produced the chosen binding in §7.
- **Poseidon2 acceleration is SP1-only** in the fetched evidence; RISC Zero's is **UNVERIFIED**. If any design component adopts a Poseidon-family commitment (e.g. for the validator-set tree), this asymmetry must be resolved by measurement or by choosing a hash both backends accelerate.

## 5. The syscall, hint and accelerator trust model

`PRF-11` states the rule: nothing computed by the host is trusted, and every accelerated primitive is trusted only to the extent the proof system's circuits constrain its input–output relation. This section records, per mechanism, *what actually constrains the result* and *what remains for the guest program to check*.

### 5.1 How a result becomes constrained

| Mechanism | What constrains the result | Residual gap |
|---|---|---|
| **RISC Zero circuit extension ("precompile")** | The rv32im implementation "includes a number of specialized extension circuits" and "the circuitry is extended to compute otherwise expensive operations in fewer instruction cycles"; the precompile's input→output map is proven by a STARK that the recursion circuit verifies, so the result is a *proven* function of guest memory — not a host hint | The per-precompile constraint systems are not described on the pages fetched, so "the circuit enforces X" is verified at the level of *architecture*, not *trace constraints* → per-op **UNVERIFIED** |
| **SP1 custom STARK tables via `ecall`** | "precompiles are implemented as custom STARK tables dedicated to proving one or few operations … exposed as system calls executed through the `ecall` RISC-V instruction." Results returned into guest memory are constrained by those tables | The *guest program* must satisfy documented usage constraints (§5.3); those checks are part of the trusted code base |
| **Host reads (stdin/input)** | Nothing. RISC Zero `sys_read` and SP1's stdin/hint channel deliver prover-controlled bytes | Every value must be constrained by an explicit check before use (§5.2) |
| **Unconstrained regions** | Nothing by construction. SP1's `unconstrained!` macro: a block "does not need to be constrained by the VM" | The guest must explicitly verify anything it trusts; e.g. an unconstrained `ecrecover` is unverified until the signature is checked |
| **Recursion / deferred verification** | RISC Zero: `env::verify` adds an **assumption** to the `ReceiptClaim`, discharged by `resolve`. SP1: `syscall_verify_sp1_proof` verifies another SP1 proof (inner proof required to be `compressed`) | A defect in the inner backend or recursion circuit propagates to the outer proof (§9) |

### 5.2 Host-controlled input is a proven exploit class, not a hypothetical

- RISC Zero advisory **GHSA-jqq4-c7wq-36h7** (critical, published 2025-10-01): "Arbitrary code execution in guest via memory safety failure in `sys_read`" — "the host is able to use a crafted response to write to an arbitrary memory location in the guest … all guest programs built with the affected versions are vulnerable. This critically compromises the soundness guarantees." Patched in risc0-zkvm **≥2.3.2, ≥3.0.3** (fix PR #3351). Source: [GHSA-jqq4](https://api.github.com/repos/risc0/risc0/security-advisories/GHSA-jqq4-c7wq-36h7), [advisories API](https://api.github.com/repos/risc0/risc0/security-advisories).
- Both systems take guest input from the host; the design rule is that the validator-set commitment, chain id, epoch, height, block hash, predecessor state root and DA commitment are **public inputs** (journal/public values) that the L1 contract derives from its own state or the transaction, or values re-derived in-guest from such an anchor. Anything a prover could supply (a "validator set" list, a stake table, a quorum threshold) must be re-derived and the signature relation checked — never asserted from a hint (`PRF-02`, `PRF-03`, `PRF-13`; see also the skeletons in §8).
- Named advisories relevant to this model: RISC Zero **GHSA-g3qg-6746-3mg9** (critical, 2025-06-18, "zkVM Underconstrained Vulnerability"); **GHSA-5c79-r6x7-3jx9** (high, 2024-09-25, "Insufficient zkVM validation of multi-step instruction modes"); **GHSA-f6rc-24x4-ppxp** (medium, 2025-08-04, "Underconstrained Vulnerability: Division"); **GHSA-349p-x622-29x6** (low, 2024-11-13, "Possible abuse of syscalls by malicious proving hosts"). SP1 **GHSA-63x8-x938-vx33** (high, 2026-04-11, V6 recursion row-count binding gap; affected 6.0.0–6.0.2, fixed 6.1.0). Full advisory tables are in §12.3.

### 5.3 Backend-specific usage constraints (each is a TCB obligation)

All rows are from SP1's [safe precompile usage](https://docs.succinct.xyz/docs/sp1/security/safe-precompile-usage) page (retrieved 2026-10-05) unless stated otherwise.

| Constraint | Exact requirement | Consequence if the guest omits it |
|---|---|---|
| **No direct ECALL / HALT** | "Do not use direct ECALL … directly calling `HALT` to stop the program execution leads to security vulnerabilities." | Program termination is not proven; soundness failures |
| **Pointer alignment** | Pointers must be 4-byte aligned | Proof may be unverifiable (DoS) |
| **Canonical field elements** | Field inputs must be canonical; "Using non-canonical representations may result in unverifiable SP1 proofs." | Unverifiable proofs; prover-caused liveness loss |
| **On-curve checks** | "the elliptic curve precompiles assume that inputs are valid elliptic curve points. Since this validity is not enforced within the precompile circuits, it is the responsibility of the user program to verify that the points lie on the curve." | Application-level unsoundness: computations over invalid points |
| **Distinct x for `add`** | Weierstrass `add` requires different x-coordinates; equal points sent to `add` yield unverifiable proofs | DoS |
| **No points at infinity** | Points at infinity are unsupported by `add`/`double` | DoS or wrong result |
| **`sys_bigint` bound** | Requires `x * y < 2^256 * modulus` for the proof to be verifiable | Unverifiable proof |
| **Patched-crate hygiene** | A dropped `sha3`/`tiny-keccak` patch silently drops keccak256 to software | Large cycle regression (correctness preserved) |
| **RISC Zero per-op trace constraints** | Not documented on the pages fetched | Per-op **UNVERIFIED**; the RISC Zero precompiles page also carries a timing-attack caveat whose text is not quoted here |
### 5.4 The precise statement of what is and is not proven

A guest that verifies a signature with an accelerated Ed25519 syscall gets a **proven** Boolean. A guest that accepts a recovered public key from an unconstrained block or a hint gets **an unproven assertion** and must verify the signature relation itself. A guest that builds a pairing or MSM from add/double syscalls gets a proven result **only if** it also enforces on-curve membership, distinct-x, no-infinity and the `sys_bigint` bound — those checks are part of the trusted code base exactly as much as the field arithmetic is. This is the reason the chosen blob binding (§7) pushes the pairing to L1 and keeps only field arithmetic plus a Lagrange evaluation in-guest.

## 6. EIP-4844 blob binding

### 6.1 What the protocol actually requires

From [EIP-4844](https://eips.ethereum.org/EIPS/eip-4844) (retrieved 2026-10-05):

| Quantity | Value |
|---|---|
| `FIELD_ELEMENTS_PER_BLOB` | **4096** |
| Field element size | 32 bytes (BLS modulus) → **131,072 bytes per blob** |
| `VERSIONED_HASH_VERSION_KZG` | `0x01` |
| Versioned hash | `kzg_to_versioned_hash(commitment) = VERSIONED_HASH_VERSION_KZG ++ sha256(commitment)[1:]` |
| Block validity | "The KZG commitments hash to the versioned hashes, i.e. `kzg_to_versioned_hash(commitments[i]) == tx_payload_body.blob_versioned_hashes[i]`" |
| Point evaluation precompile | "verifies a KZG proof which claims that a blob (represented by a commitment) evaluates to a given value at a given point"; it "also verif[ies] that the provided commitment matches the provided versioned_hash". Cost **50,000 gas** (`0x0A`) |
| Curve | BLS12-381 (KZG commitments/proofs; the precompile returns `BLS_MODULUS`) |

### 6.2 Why a keccak commitment is NOT the protocol's KZG commitment

| | keccak256(data) | Protocol KZG commitment |
|---|---|---|
| What it is | One 32-byte hash of the byte string | A **BLS12-381 G1 point** = `Σ_i c_i · [τ^i]` over the 4096 field elements (an MSM) |
| Who can check it cheaply | Anyone, in-guest, ~1 hash | Only with the KZG structured reference string; on L1 via the point-evaluation precompile |
| What L1 consensus enforces | Nothing | `kzg_to_versioned_hash(C) == blob_versioned_hash`; DA sampling is over the *blob*, addressed by the versioned hash |
| Binding value | "I saw these bytes" | "this is the polynomial the protocol's DA layer is committing to" |
| If the guest only checks keccak | A malicious proposer can publish **different bytes** under the same versioned hash in the blob field, because the versioned hash commits to the KZG commitment, not to the bytes. The proof's keccak hash would be over data that L1 never bound | The versioned hash is the protocol-native handle |

→ A calldata+keccak binding is only sound because the batch data is in calldata, where L1 execution makes the bytes part of the transaction and the contract can hash them directly. **For blobs the binding must go through the KZG commitment.**
### 6.3 The two candidate bindings, with feasibility per backend

| Candidate binding | RISC Zero | SP1 | Evidence |
|---|---|---|---|
| **(A) Blob → in-guest KZG commitment and/or opening** | Vendor-patched `c-kzg` exists (tags up to `v2.1.5-risczero.0`; the fork's README confirms the EIP-4844 Polynomial Commitments API: `compute_kzg_proof`, `verify_kzg_proof`, …), and `blst` is patched to "enable full acceleration". **But**: no doc statement that MSM is a single accelerated op; no cycle/latency figure; MSM/pairing acceleration **UNVERIFIED**; SRS-in-guest **UNVERIFIED**; cost **UNMEASURED** | **No c-kzg patch listed.** Blob→commitment MSM must be composed from O(4096) `syscall_bls12381_add`/`_double` calls, each subject to the on-curve/distinct-x/no-infinity constraints, with the guest implementing the bucket/accumulator logic. **No pairing syscall found** → an opening check is **UNVERIFIED** as practical | RZ: [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles), [c-kzg README](https://raw.githubusercontent.com/risc0/c-kzg-4844/main/README.md); SP1: [sp1-lib](https://docs.rs/sp1-lib/latest/sp1_lib/), [safe-precompile-usage](https://docs.succinct.xyz/docs/sp1/security/safe-precompile-usage) |
| **(B) Calldata → keccak** | Accelerated keccak circuit; the contract hashes the exact calldata slice itself and the guest recomputes the same hash. No probabilistic argument needed | Accelerated `syscall_keccak_permute`; same contract-side binding | Both [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles) pages |
| **(rejected) Versioned hash only** | The guest can take the versioned hash as a public input from the contract (from `BLOBHASH`) and check whatever the contract requires without recomputing the commitment — **but then the proof says nothing about the bytes**, and for blobs L1 cannot cheaply enforce data↔hash equality | Same | [EIP-4844](https://eips.ethereum.org/EIPS/eip-4844) |

**SRS availability is an unmeasured blocker for (A) on both backends.** The KZG SRS is large (4096+ G1 points); whether the Ethereum KZG ceremony output can be loaded into the guest within the documented memory envelope is **UNVERIFIED** for both; SP1 documents a **~2 GB** zkVM memory limit ([proof-aggregation](https://docs.succinct.xyz/docs/sp1/writing-programs/proof-aggregation)).

## 7. The chosen binding (and its alternatives)

The project's selected blob binding, recorded in [04-architecture-decision.md](04-architecture-decision.md) §4.1 and normative as `PRF-07(b)`, is **not** candidate (A). It is:

> **In-guest Lagrange evaluation of the executed blob field elements at an on-chain Fiat–Shamir challenge point `z`, plus an on-chain KZG opening check through the EIP-4844 point-evaluation precompile.**

### 7.1 The mechanism, step by step

1. The L1 contract requires `blobhash(i)` in the same transaction to be non-zero and equal to the i-th versioned hash committed by the proof.
2. The contract recomputes `challengeZ = H(all other journal fields)` and requires the proof's `challengeZ` to match — so the prover cannot choose `z` after fixing its data.
3. For each blob the contract calls the point-evaluation precompile at `0x0A` with `(versionedHash_i, z, y_i, commitment_i, proof_i)`; the precompile verifies both `kzg_to_versioned_hash(commitment_i) == versionedHash_i` and the opening `p(z) = y_i`. **50,000 gas** per call (EIP-4844).
4. The guest computes, from the blob field elements it actually executed, the evaluation `p'(z)` of the polynomial those elements interpolate — a **Lagrange evaluation: ≈ O(4096) field operations per blob**, using accelerated big-integer primitives — and requires `p'(z) == y_i` for every blob.
5. The guest also requires `keccak256(executed data) == dataCommitment`, as in the calldata path.

### 7.2 Premises, stated

- **KZG binding** (the commitment is binding and the opening check is sound).
- **Random-oracle model** for the Fiat–Shamir derivation of `z`.
- **Canonical field elements** and correct in-guest field arithmetic.
- The published blob is fixed by the protocol's KZG commitment before the prover fixes `z`, because `z` is derived by the contract from the prover's own committed values. If the executed data and the published blob differ as polynomials, their evaluations agree at `z` with probability at most `deg/|F|` — about **2^-243** per attempt — and each attempt requires a fresh commitment. (Figure quoted from [spec/05-proof-statement.html](spec/05-proof-statement.html) `PRF-07(b)` and [04-architecture-decision.md](04-architecture-decision.md) §4.1; the EIP itself supplies `|F|` and the degree.)
- If any premise fails, the blob path is unsound — which is why the calldata path remains unconditionally available and the journal domain-separates `da_mode`.
### 7.3 What is measured, and what is not

- **In-guest cost of the Lagrange evaluation is UNMEASURED** (architecture decision open item **F2**; `PRF-07` is marked *Proven unmeasured*). No cycle count, latency or gas figure exists for it. It is a measurement gate, not a launch blocker for the calldata path.
- The **on-chain** side is the only part with a sourced figure: 50,000 gas per blob opening, from EIP-4844, quoted by the architecture decision.
- The design deliberately **avoids in-guest MSM and in-guest pairings**, which §4/§6 found unverified for both backends. That is the single most important design consequence of this study.

### 7.4 Comparison of the three paths

| Dimension | **Chosen: in-guest Lagrange + on-chain opening** | RISC Zero patched `c-kzg` in-guest (candidate A) | Calldata + keccak (candidate B) |
|---|---|---|---|
| Guest work per blob | ≈ O(4096) field ops (Lagrange evaluation) + SHA-256/keccak | MSM over 4096 G1 points + pairing check for the opening | ~1 keccak permutation per 136 bytes |
| Accelerated? | Field arithmetic via accelerated bigint primitives; no MSM/pairing in guest | Claimed via patched `c-kzg`/`blst`; **MSM/pairing acceleration UNVERIFIED** | Both: dedicated keccak circuits |
| Where the pairing happens | **On L1**, in the point-evaluation precompile (50,000 gas) | In-guest (no pairing syscall on SP1) | None needed |
| SRS in guest? | **No** | Yes — SRS loading **UNVERIFIED** for both backends | No |
| Binding strength | Sound under the premises in §7.2; probabilistic at 2^-243 per attempt | Sound if the KZG library and its acceleration behave as documented | Unconditional — the calldata bytes *are* the transaction payload |
| Backend coverage | Both (RISC Zero and SP1), provided field arithmetic is accelerated | **RISC Zero only** in the fetched evidence | Both |
| Evidence quality | [1] + [4] (cost UNMEASURED) | [1] + [4] (vendor patch claimed; cost/acceleration UNVERIFIED) | [1] — best-evidenced |
| L1 data cost | Blob gas market (cheaper per byte) | Blob gas market | Calldata gas (more expensive per byte) |
| When it is preferred | Default when blobs are used | Only after a measurement shows in-guest MSM/pairing is affordable and audited | Always available; the fallback that cannot be argued away |

## 8. The two proof-statement skeletons

Notation: `pub` = public input (checked by the L1 verifier contract); `wit` = private witness (prover-supplied, must be fully constrained). These skeletons expand `PRF-02`…`PRF-07`; the normative list is the journal in [spec/05-proof-statement.html](spec/05-proof-statement.html).

### 8.1 COMBINED — one guest proves W1 ∧ W2 (and W3)

**Public inputs (journal / committed public values)**

| # | Value | Why public |
|---|---|---|
| 1 | `chain_id` | Domain separation; prevents cross-chain replay |
| 2 | `l1_contract` address (+ `l1_chain_id`, verifier version tag) | Prevents replay into a different deployment/version |
| 3 | `batch_id` / `last_accepted_batch` | Ordering; prevents skipping/replaying batches |
| 4 | `prev_state_root` | Must equal the L1-accepted root (W2 start) |
| 5 | `new_state_root` | W2 end state |
| 6 | `first_block_number`, `last_block_number` (batch range) | Range binding; bounded batches prevent head replay |
| 7 | `head_block_hash`, `head_height` | The finalized head that W1 certifies |
| 8 | **`validator_set_commitment`** (root of the authoritative set for the relevant epoch) | **Anchored on L1** — the contract reads it from its own state; a prover can never supply it |
| 9 | `validator_set_version` / `epoch` (+ `epoch_transition_commitment` if the batch spans epochs) | Selects which set the QC must verify against |
| 10 | `quorum_threshold` (e.g. the exact integer threshold) | The contract, not the prover, defines "2/3" |
| 11 | `qc_signing_root` = `H(chain_id ‖ version ‖ height ‖ block_hash)` | Ties the signature domain to the certified statement |
| 12 | `public_values_hash` of the batch's data commitment | Ties data to proof |
| 13 | `blob_versioned_hashes[]` **or** `calldata_hash` | The DA binding of §6 |
| 14 | `da_mode` (blob / calldata) | Domain separation between the two binding rules |
| 15 | `gas_used` / `receipts_hash` (optional but common) | Lets L1 sanity-check work |

**Private witness**

| # | Witness | Constrained by |
|---|---|---|
| 1 | Validator set leaves (pubkeys, stake amounts) | Must Merkle/SSZ-verify against #8; the tree rule is hard-coded in the guest |
| 2 | Merkle/SSZ inclusion proofs for each signer | Hash-checked in-guest |
| 3 | QC bitfield / signer index list | Checked against #8 and the quorum rule |
| 4 | **Signatures** over #11 | **Signature verification in-guest** (Ed25519 or secp256k1) — the cryptographic core of W1 |
| 5 | Stake values / aggregation arithmetic | Summed in-guest as bigint; requires `sum(participating stake) ≥ threshold(#10)` |
| 6 | Epoch-transition data (old set, new set, activation height) | Hash-chained to #8/#9 |
| 7 | L2 block bodies, transactions, receipts, state trie nodes | Executed / trie-verified in-guest |
| 8 | Blob data + KZG commitment (if `da_mode = blob`) | Chosen binding: Lagrange evaluation at `z` must equal the precompile-accepted `y`; `sha256(commitment)` → versioned hash #13 |

**Checked in-guest:** signature validity; stake-weighted quorum ≥ threshold; validator-set membership vs the anchored commitment; epoch/version consistency; full EVM state transition `prev_state_root → new_state_root`; block-hash/height continuity; DA binding.

**What binds the parts:** #4 (prev root), #8/#9 (authoritative set + version) and #11/#13 are computed by the contract and checked by the on-chain verifier against the journal. The **only** cryptographic link between "L1 believes set S" and "the QC was signed by S" is the in-guest membership + signature check, whose result is a STARK/SNARK-constrained computation.

### 8.2 COMPOSED — consensus proof ⊗ execution proof

Two guests, two image IDs / VKEYs. Composition can be **recursive** (outer guest verifies the inner proof via `env::verify` / `syscall_verify_sp1_proof`) or **on-chain** (the L1 contract verifies both seals).

| | Consensus guest (W1) | Execution guest (W2) |
|---|---|---|
| Public inputs | `chain_id`, `l1_contract`, `validator_set_commitment`, `validator_set_version`/`epoch`, `quorum_threshold`, `head_height`, `head_block_hash`, `qc_signing_root`, `batch_id`, `epoch_transition_commitment` | `chain_id`, `l1_contract`, `batch_id`, `prev_state_root`, `new_state_root`, `first_block_number`, `last_block_number`, `head_block_hash`, `head_height`, `da_commitment`, `da_mode` |
| Private witness | validator leaves + inclusion proofs, signatures, stake table, bitfield, epoch-transition data | block bodies, txs, receipts, trie nodes, blob data + KZG (if blob mode) |
| Proof size / mode | small program → `compressed` STARK is likely sufficient; **UNMEASURED** | large program |
| **Binding between the two** | **`head_block_hash` + `head_height` + `batch_id` appear in BOTH public-input lists**, enforced by the L1 contract requiring both journals to carry identical values; if composed recursively, the outer guest takes the inner journal as a public input and checks equality in-circuit | |

**Composition modes and what they cost**

| Mode | Mechanism | Binding enforced by | Risk |
|---|---|---|---|
| On-chain composition | Contract calls two verifiers (two routes/selectors) and compares journals | L1 contract code | Contract bug = forgery; two upgrade surfaces; ~2× verification gas |
| Recursive composition (RISC Zero) | `env::verify(inner_image_id, inner_journal)` in the outer guest → `ReceiptClaim` assumption → `resolve` | Recursion circuit + assumption machinery | A bug in the inner verifier backend can let a false inner claim be assumed, and the outer proof is then valid for a false statement |
| Recursive composition (SP1) | `syscall_verify_sp1_proof` over a `compressed` inner proof | Recursion/aggregation circuit | Same class of risk; **GHSA-63x8** was exactly a recursion-circuit soundness gap (V6, fixed in 6.1.0) |

**"Can a bug in one backend forge the other?"**

- **Combined guest:** moot — there is only one backend; but the single backend's soundness bug forges everything at once (W1 **and** W2).
- **On-chain composition:** a forged proof must pass a concrete verifier; a bug in verifier A cannot forge verifier B, **but** it can forge A's half. Because the contract compares journals rather than re-deriving them, a forged *consensus* proof with attacker-chosen `head_block_hash` can be paired with a genuine execution proof only if the execution half also accepts those values. Execution binds `prev_state_root` from L1, so it cannot be entirely fabricated; the consensus half is the softer target because its statement is small and its witness is fully prover-supplied.
- **Recursive composition:** the outer proof attests to the inner *statement*; if the inner proof system is broken, the outer system faithfully proves a false statement. This is the strongest argument for keeping the consensus half in the same guest as the execution half, or for on-chain composition with two independently audited verifiers.
### 8.3 Tradeoffs

| Dimension | COMBINED (8.1) | COMPOSED (8.2) |
|---|---|---|
| On-chain verification cost | 1 verification (~270k–300k gas per SP1 doc figures; RISC Zero gas **UNVERIFIED**) | 2 verifications (≈2×) unless recursively aggregated back into one |
| Proof size | 1 seal | 2 seals (or 1 if the outer aggregates) |
| Latency | Must wait for finality before starting; single pipeline | **Can pipeline**: execution proof starts at block production, consensus proof at finality, then compose — reduces the critical path if finality lags |
| Upgrade independence | **Low** — any change to the consensus rule *or* the EVM changes the image ID and therefore the verifier route | **High** — consensus format and EVM can be versioned independently |
| Version surface on L1 | 1 route | 2 routes (or 1 route + 1 inner-verifier dependency) |
| Security surface | 1 TCB; single bug → both broken | 2 TCBs + the composition glue; a bug forges only its half **unless** composed recursively in a broken backend |
| Reuse/amortization | Consensus work re-done per batch incl. the full signature set | Consensus proof can be **reused across many batches** in the same epoch — signature verification becomes per-epoch, not per-batch |
| Failure isolation | None | Good — e.g. a DA-mode bug does not stop finality proofs |

**Reading of the evidence (an argument, not a finding):** if the design wants the smallest number of things that can go wrong on L1, **COMBINED** wins. If the design wants to amortize signature verification across an epoch and upgrade the two halves independently, **COMPOSED** wins — at the cost of a second verifier route and an explicit journal-equality check. §14 states the recommendation.

## 9. Aggregation and recursion

| Capability | RISC Zero (v3.0.6) | SP1 (6.8.1) |
|---|---|---|
| In-proof parallelism | Program split into **segments**, each proven, then `lift`ed; `join` pairs of `SuccinctReceipt`s repeatedly until one remains | Execution split into **shards of ~2^22 RISC-V instructions**, shard proofs generated in parallel, then "recursively aggregating the proofs" |
| Recursion primitive | `lift`, `join`, `resolve`, `identity_p254`; `compress()` → Groth16 | `syscall_verify_sp1_proof` over a **compressed** proof |
| User-level aggregation program | Proof composition via `add_assumption` / `env::verify`; `resolve` removes the assumption | **Yes** — official aggregation example: "aggregating multiple SP1 proofs into a single SP1 proof" |
| Aggregate many per-batch proofs into one per L1 posting | Yes in principle (join/aggregate), **but no per-batch aggregation example was fetched** → **UNVERIFIED** as a documented pattern | Yes — explicitly listed: "Reducing on-chain verification costs by aggregating multiple SP1 proofs into a single SP1 proof" |
| Documented caveat | none fetched | **warning**: "Generally proving a single program is faster and more cost-effective than generating mul…" (text truncated at fetch; the full sentence was not captured) — i.e. aggregation is **not** automatically cheaper |
| When the vendor says aggregation is *necessary* | — | "When your computation requires more than the zkVM's limited (~2GB) memory, or is extremely long (>120B cycles)"; when combining proofs from **different parties**; when parts can start at different times |
| SNARK wrap for the aggregate | `ReceiptKind::Groth16` shrink-wrap (requires `rzup install risc0-groth16`) | `groth16` / `plonk` wrap of the aggregated proof |

**Constraints the design imposes on any aggregation layer (`PRF-12`):**

1. **Hard-code the accepted inner program identities.** The outer guest must enforce the expected inner image ID / control root / VKEY in-circuit. Otherwise an aggregation layer can pin an old, possibly vulnerable inner circuit version into a new outer route (§2.3 V4).
2. **Expose the verified triples in the outer journal.** The outer proof must publish the set of `(predecessor, successor, data commitment)` triples it verified, and the L1 contract must perform the journal comparison itself rather than trust a prover-supplied journal.
3. **Fail closed.** An aggregated proof must fail to verify if any inner journal is inconsistent with the outer claim.
4. **Aggregation stays optional.** The protocol must be able to operate one proof per batch, because aggregation adds the recursion program to the trusted computing base.
5. **A broken inner verifier is a false-statement risk, not just a cost risk.** SP1's most recent high-severity advisory **GHSA-63x8-x938-vx33** was exactly a *recursion-circuit* soundness gap: "A soundness vulnerability in the SP1 V6 recursive shard verifier allows a malicious prover to construct a recursive proof from a shard proof that the native verifier would reject." Affected `>= 6.0.0, <= 6.0.2`; fixed in **6.1.0**. Making recursion load-bearing for bridge security is a deliberate risk decision, not a free optimization.

**Latency/cost consequences.** Both systems make a single batch's proof internally parallel. Aggregation adds a **serial tail** (recursive roll-up + SNARK wrap). SP1 documents the PLONK wrap alone as **+~1m30s** over a compressed proof; no equivalent RISC Zero wrap-time figure was found → **UNVERIFIED**. Aggregation buys **one** on-chain verification instead of N at the price of extra recursive proving. For W1, the same QC/validator-set statement can be proven once per epoch and reused as an inner proof for every batch in that epoch — the strongest technical argument for the composed design (§14).

## 10. Throughput and the 2 s cadence

**No number below is invented.** Where a published measurement exists it is quoted with hardware, workload, version and methodology. Where none exists the entry is **UNVERIFIED** and only a formula is given.

### 10.1 The constraint, as formulas

Let `G` = sustained L2 gas/s to be proven; `C` = zkVM cycles per L2 gas for *this* workload (**UNVERIFIED** for any EVM+consensus workload — the single most important unknown); `R` = cycles/s proven by one machine (**UNVERIFIED** for both systems on this workload); `Δ` = L1 posting interval (s); `L` = end-to-end proving latency budget (the brief allows up to ~1800 s); `B` = L2 gas in one batch = `G · Δ`; `e` = efficiency factor (parallel scaling loss, aggregation tail, retries), `e ≥ 1`.

```text
(1) Required aggregate cycle throughput   T_req = e · G · C                [cycles/s]
(2) Required fleet size (throughput-bound) N_thr = T_req / R = e·G·C / R
(3) Work per batch                         W = B · C = G · Δ · C          [cycles]
(4) Latency for one batch on k machines    L_batch = W / (k · R)
(5) Latency feasibility                    k ≥ W / (L · R)
(6) In-flight (concurrency) requirement    Q = L / Δ   (Little's law)      [proofs]
(7) Fleet size (concurrency-bound)         N_conc = Q · k = (L/Δ)·k
(8) FLEET = max(N_thr, N_conc) = max( e·G·C/R , (L/Δ)·k )
(9) Cost per batch ≈ (W / R) · p_machine   where p_machine = price per machine-second
(10) Staleness window: a proof started at batch n is posted at ≥ t_n + L, so the L1 contract must tolerate a proof for an *older* head than the current L2 head.
```

**Key structural insight from (6)–(8):** because a proof may take up to 30 minutes while blocks arrive every 2 s, the fleet is **concurrency-bound, not throughput-bound**, whenever `L/Δ` exceeds `e·G·C/R`. With `Δ = 2 s` and `L = 1800 s`, **Q = 900 proofs in flight** — `derived`, an arithmetic consequence of the stated constraints, independent of hardware. That number is a design input for the queue and hardware fleet regardless of how fast a single machine is. If the L1 posting interval is larger (e.g. one posting every few minutes), Q falls proportionally.

**Pipelining levers** (all require the L1 contract to accept proofs about a *specific, bounded* batch rather than "the latest head"):
1. Per-batch parallel proofs + aggregation (§9) — raises throughput, adds a serial tail.
2. Segment/shard parallelism inside one proof — both zkVMs do this natively.
3. **Queue depth ≥ Q**, with bounded retry.
4. **Per-epoch reuse of the consensus (W1) proof** — turns a per-batch signature-verification cost into a per-epoch cost.
5. Deferring the SNARK wrap: produce the STARK/compressed proof early, wrap late (the wrap is the part the chain needs).

### 10.2 The single sourced published benchmark, and what it does not cover

| # | Vendor/system | Hardware | Workload | Published result | Version | Transferable? |
|---|---|---|---|---|---|---|
| **M1** | Succinct **SP1 Hypercube** | **16 × NVIDIA RTX 5090** | "a random set of 954 blocks, taken between block number 23807739 and 23812008" — **L1 Ethereum block execution** | "proves 99.7% of L1 Ethereum blocks … under 12s, and 95.4% of blocks under 10s" | "the latest version of SP1 Hypercube" (blog states no semver) — [blog.succinct.xyz](https://blog.succinct.xyz/real-time-proving-16-gpus/) | **Partially.** It is EVM execution on L1 mainnet blocks — the closest published analogue to **W2** — but not W1 (no validator-set/QC/signature work), not blob KZG, and not RISC Zero. Whether 16 GPUs suffice for *this* workload is **UNVERIFIED** |
| M2 | SP1 local-proving minimums | CPU 16+ cores / 16 GB+ RAM (core, compress); Groth16 16 GB+, PLONK 64 GB+ | — | "The final wrapping step requires roughly 14GB of memory for Groth16 and 60GB for PLONK" | [hardware-requirements](https://docs.succinct.xyz/docs/sp1/getting-started/hardware-requirements) | Resource envelope only — **not** a throughput measurement |
| M3 | SP1 GPU requirements | 24 GB+ VRAM, compute capability ≥ 8.0 (A100, RTX 30/40, H100) | — | minimum spec | [hardware-acceleration](https://docs.succinct.xyz/docs/sp1/generating-proofs/hardware-acceleration) | Envelope only |
| M4 | RISC Zero | none published | — | The docs instruct users to generate their **own** datasheet: `cargo run --release --example datasheet` (with `-F cuda` or `-F metal`), plus a Fibonacci benchmark | [benchmarks](https://dev.risczero.com/api/next/zkvm/benchmarks) (v3.0.6 docs) | **No published per-machine number exists on the pages fetched → UNVERIFIED.** Any RISC Zero throughput claim in a design doc must come from a self-run datasheet or a third-party benchmark |
| M5 | SP1 Hypercube aggregate claim | — | — | "first general-purpose hash-based zkVM to completely eliminate the need for proximity gap conjectures" (a soundness claim, not a perf number) | [hypercube](https://docs.succinct.xyz/docs/sp1/hypercube/) | Not a perf measurement |
| M6 | Third-party zkEVM benchmark (Nethermind `zkevm-benchmark-workload`) | — | gas-categorized workloads; 0.4M/1M gas and risc0 variants exist | Page content JS-rendered; **no numbers could be extracted → UNVERIFIED** | — | Would need a browser fetch; not usable as evidence here |

**The explicit statement: no vendor publishes the numbers this design needs.** Neither vendor publishes (a) cycles per L2 gas for an Etna-style workload including tx-signature recovery and trie hashing, (b) proven cycles/s per machine for a guest of this size, or (c) an end-to-end L2 batch-proof latency with consensus evidence attached. RISC Zero publishes no per-machine benchmark at all on the pages fetched; SP1's published number is for a different circuit line, hardware class and workload. [4]

**Transferability of M1, stated precisely.** M1 transfers only to the **W2 execution** component, only for **L1-mainnet-like** blocks, only on **that 16×RTX 5090 cluster**, and only for the SP1 **Hypercube** circuit line. It says nothing about (a) the signature/quorum work in W1, (b) BLS12-381 KZG MSM/pairing in the blob path, (c) the smaller ~2 s-cadence L2 blocks of Etna, or (d) RISC Zero.
### 10.3 What must be true for proving to keep pace

| Requirement | Statement | Status |
|---|---|---|
| R1 | Aggregate proven cycles/s ≥ `e · G · C` | **Cannot be evaluated** — `C` and `R` are UNVERIFIED for this workload |
| R2 | Fleet ≥ `(L/Δ)·k` concurrent proving jobs (≈900 in flight at Δ = 2 s, L = 30 min) | Arithmetic consequence of the stated constraints, independent of hardware |
| R3 | Each batch's proof completes within `L` on `k` machines | Requires a measured per-machine rate |
| R4 | L1 verifier accepts a proof for a **bounded, specific** batch (not "latest") | Design requirement implied by formula (10) |
| R5 | Either the consensus half is amortized per epoch, or its per-batch cost is included in `C` | Design requirement — W1 cost is otherwise repeated per 2 s |
| R6 | A prover-fleet member cannot influence the statement (only liveness) | Security requirement (§5.2) |

## 11. Program-image and verifier upgrade paths

### 11.1 Mechanisms as documented

| | RISC Zero | SP1 |
|---|---|---|
| Guest program identity | **Image ID** (hash of the guest ELF) + **control root** (allowed recursion programs; each `lift`/`join`/`resolve`/`identity_p254` has a control ID) | **VKEY** (verification key) for the guest program |
| What the L1 contract stores | The verifier **selector** in the seal routes to a base verifier; each base verifier is "stateless and immutable" and hard-codes the **control root** and the Groth16 vkey. The program Image ID is passed by the *application* as the expected image id | The proof carries the SP1 version; the **gateway** routes to the correct per-version verifier; the app supplies the expected VKEY |
| Adding a new version | Admin adds an implementation to `RiscZeroVerifierRouter`; "once removed it can never be replaced. I.e. each identifier can have at most one implementation across time." RISC Zero's own router additions go through a **`TimelockController`** (mainnet delay = 259200 s = 3 days) | "Whenever a verifier for a new SP1 version is deployed, the gateway contract will be updated"; routes added via **Safe batches** (e.g. `1_add-route_v6_0_0.json`, `1_add-route_v6_1_0.json`) |
| Removing / freezing a version | `RiscZeroVerifierEmergencyStop` proxy per base verifier; triggerable by a **guardian** or by "proving the existence of a critical vulnerability" (circuit breaker). Apps can deploy their **own** router/estop | "If a verifier for an SP1 version has an issue, the route will be frozen" |
| App-side options | (i) call an immutable verifier directly (no upgrade, no shutdown — "even in the event of vulnerabilities"); (ii) estop proxy; (iii) own router with a chosen subset | Use the canonical gateway, or deploy your own verifier and follow the `ISP1Verifier` interface |
| Testnet vs mainnet policy | — | "On mainnets, only official versioned releases are deployed and added to the gateway. Testnets have … versions of the verifier deployed supported in addition to the official versions." |
| Upgrade guide | [version-management-design.md](https://raw.githubusercontent.com/risc0/risc0-ethereum/release-1.0/contracts/version-management-design.md) | [Upgrade guides](https://docs.succinct.xyz/docs/sp1/developers/upgrades): V6 introduces Hypercube with **breaking API changes**; patches and the "version string … when specifying the circuit version" must be upgraded |

Supporting URLs for this table: RISC Zero verifier contracts — [contracts/verifier](https://dev.risczero.com/api/next/blockchain-integration/contracts/verifier); SP1 version registry — [contract-addresses](https://docs.succinct.xyz/docs/sp1/verification/contract-addresses), [deployments/1.json @v6.1.1](https://raw.githubusercontent.com/succinctlabs/sp1-contracts/v6.1.1/contracts/deployments/1.json).

### 11.2 Consequences for a long-lived L1 contract

1. **Every guest change is a verifier-route change.** Changing one line of the consensus rule changes the Image ID / VKEY. The L1 contract must hold a *set* of accepted program identities, with an explicit governance path to add and remove them (`PRF-09`, `PRF-10`).
2. **Stale-version acceptance is the dominant long-run risk.** RISC Zero's router allows a version to be removed but never replaced; SP1's gateway can freeze a route. A contract that "accepts any seal the router accepts" inherits the router admin's judgement — including a **3-day timelock** before a new version is usable, and RISC Zero's caveat that a directly-called immutable verifier **cannot be shut down even if a vulnerability is found**. The safe pattern is an **application-owned router** (RISC Zero explicitly supports this) or an application-owned allow-list of identities.
3. **Aggregation can pin an old inner version into a new outer route** unless the outer guest enforces an expected inner identity in-circuit (§9, `PRF-12`).
4. **Release cadence vs audit cadence.** SP1 shipped 5 releases in 29 days; an L1 governance timelock (3 days for RISC Zero's router) and an audit cycle are on different clocks. Any "rotate the fleet quickly" plan must reconcile with the verifier's upgrade latency.
5. **Migration discipline is normative.** `PRF-10` and `MIG-05`/`GOV-03`: an upgrade adds a new accepted identity but must not remove the ability to accept proofs for batches whose head block was finalized under the previous identity; an identity may be withdrawn only after finality of (or a published deadline past) all batches that require it, and removing an accepted identity is treated as malicious governance. A verifier left accepting a superseded vulnerable identity is the soundness failure; a proof stranded by an upgrade is the liveness failure (a halt under Mode A).
6. **The live version skew (§2.3 V1/V2) is exactly this risk, today.** An operator who upgrades the prover without a route produces proofs L1 rejects; the inverse leaves an old route open. Both are named in the specification as consequences of the acceptance policy being "Open" in `PRF-09`.

## 12. Supply-chain and implementation risk

### 12.1 Audits (verified listings)

| System | Where | Items found |
|---|---|---|
| RISC Zero | [rz-security audits](https://api.github.com/repos/risc0/rz-security/contents/audits) | Directories: `circuits`, `contracts`, `groth16`, [precompiles](https://api.github.com/repos/risc0/rz-security/contents/audits/precompiles), [zkVM](https://api.github.com/repos/risc0/rz-security/contents/audits/zkVM), plus `blobstream`, `boundless`, `kailua`, `povw`, `r0vm-helios`, `steel`. **zkVM:** `hexens_zkVM_20231031.pdf`, `veridise_zkVM_20250224.pdf`, `veridise_zkVM_260212.pdf` (**2026-02-12**). **Precompiles:** `veridise_bigint2_240324.pdf`, `veridise_keccak-250221.pdf` |
| SP1 | [sp1 audits directory](https://api.github.com/repos/succinctlabs/sp1/contents/audits?ref=dev) + [commit history](https://api.github.com/repos/succinctlabs/sp1/commits?path=audits&per_page=12) | `cantina.pdf`, `code4rena.pdf`, `hypercube-zellic.pdf`, `kalos.md`, `rkm0959.md`, `sp1-v4.md`, `veridise.pdf`, `zellic.pdf`. Commit dates on that path: 2026-02-12, 2026-02-06, 2025-01-30, 2025-01-26, 2025-01-14, 2024-11-12, 2024-11-07, 2024-07-19 |

RISC Zero's security programme is described on its [Secure SDLC](https://dev.risczero.com/api/next/secure-sdlc) page.

### 12.2 Bug bounties — both amounts UNVERIFIED

| System | Evidence | Amounts |
|---|---|---|
| SP1 | Docs sidebar "Bug Bounty" → [code4rena.com/bounties/succinct](https://code4rena.com/bounties/succinct) (link extracted from the [safe-precompile-usage](https://docs.succinct.xyz/docs/sp1/security/safe-precompile-usage) page). The Code4rena page is JS-rendered and returned no readable content | **UNVERIFIED** |
| RISC Zero | Footer link "Bug Bounties" exists on dev.risczero.com pages; no href resolvable from the fetched HTML | **UNVERIFIED** |

### 12.3 Known soundness issues / advisories

**RISC Zero** — [advisories API](https://api.github.com/repos/risc0/risc0/security-advisories):

| ID | Severity | Published | Title | Patched |
|---|---|---|---|---|
| GHSA-jqq4-c7wq-36h7 | **critical** | 2025-10-01 | Arbitrary code execution in guest via memory safety failure in `sys_read` — "the host is able to use a crafted response to write to an arbitrary memory location in the guest … all guest programs built with the affected versions are vulnerable. This critically compromises the soundness guarantees" | risc0-zkvm **≥2.3.2, ≥3.0.3** (fix PR #3351) |
| GHSA-g3qg-6746-3mg9 | **critical** | 2025-06-18 | zkVM Underconstrained Vulnerability | (not read) |
| GHSA-5c79-r6x7-3jx9 | high | 2024-09-25 | Insufficient zkVM validation of multi-step instruction modes | (not read) |
| GHSA-f6rc-24x4-ppxp | medium | 2025-08-04 | Underconstrained Vulnerability: Division | (not read) |
| GHSA-349p-x622-29x6 | low | 2024-11-13 | Possible abuse of syscalls by malicious proving hosts | (not read) |
| GHSA-5xgj-pmjj-gw49 | low | 2024-07-15 | RISC Zero zkVM notes on zero-knowledge | (not read) |

**SP1** — [advisories API](https://api.github.com/repos/succinctlabs/sp1/security-advisories):

| ID | Severity | Published | Title | Patched |
|---|---|---|---|---|
| GHSA-63x8-x938-vx33 | **high** | 2026-04-11 | **SP1 V6 Recursion Circuit Row-Count Binding Gap** — "A soundness vulnerability in the SP1 V6 recursive shard verifier allows a malicious prover to construct a recursive proof from a shard proof that the native verifier would reject." Affected `>= 6.0.0, <= 6.0.2`; V5 not affected | `sp1_sdk`, `sp1_recursion_circuit`, `sp1_prover` → **6.1.0** |
| GHSA-6248-228x-mmvh | high | 2025-06-03 | Vulnerability in Plonky3, insufficient checks in the Rust verifier and embedded allocators | (not read) |
| GHSA-c873-wfhp-wx5m | high | 2025-01-15 | Missing verifier checks and Fiat–Shamir observations | (not read) |
| GHSA-f77q-r5qm-w4m8 | high | 2024-10-28 | Insufficient range checks of BabyBear arithmetic | (not read) |
| GHSA-8m24-3cfx-9fjw | medium | 2024-11-08 | Insufficient observation of cumulative sum | (not read) |

### 12.4 Why a soundness bug equals bridge theft

- Both systems have a **recent history of high/critical soundness defects**, and in both cases the remediation was **"upgrade to version X"** — i.e. the fix lives in the prover and in a new circuit, not in a patch the L1 contract can apply to itself. An L1 verifier that cannot be quickly pointed at a new circuit **cannot be fixed**.
- **The consensus half (W1) is the highest-value target** because its witness is entirely prover-supplied: a forged consensus proof with an attacker-chosen `head_block_hash`, paired with a genuine execution proof for a state the attacker controls, is a plausible bridge-theft primitive. Hard-anchoring the validator-set commitment as a *public input from L1 state* is the single most important mitigation (`PRF-03`, `PRF-13`).
- **Prover-side trust is explicitly acknowledged by Succinct**: outside parties may run provers, and the docs recommend an *approved prover* whitelist for critical value — in tension with a **permissionless** prover fleet.
- **RISC Zero's zero-knowledge caveat** ("we have not written a mathematical argument to prove that our system is zero-knowledge") matters if witness secrecy is relied upon; here the witness is public data, so it is not a blocker.
- **The host is untrusted and has been exploitable** (GHSA-jqq4). Witness generation must never be treated as trusted input; only the journal/public values matter.
- **Two-backend policy is the stated escape hatch** (`PRF-09(b)`): if the measured soundness posture of either backend is unacceptable, require two independent backends per batch — at the cost of doubling the proving fleet under `HALT-03`.

## 13. Separation of evidence quality

Per `GEN-08`, every feasibility claim is exactly one of four classes. The classes are never merged: the benchmark in (2) is not an estimate, and the estimates in (3) are not measurements.

### 13.1 (1) Compatibility in principle — high confidence, documentary

| Claim | Evidence class |
|---|---|
| Both zkVMs are STARK-based general-purpose RISC-V machines with a Groth16 (RISC Zero) / Groth16+PLONK (SP1) on-chain wrap | [1] Official docs, fetched |
| keccak256, sha256, secp256k1, Ed25519, bn254, bigint/modexp are all accelerated in both stacks | [1] Official precompile pages + syscall enumeration |
| RISC Zero ships a patched **c-kzg-4844** and a patched **blst**, i.e. the vendor intends EIP-4844 KZG to run in-guest | [1] Official precompiles page (explicit footnote) |
| SP1 exposes BLS12-381 add/double/decompress/Fp/Fp2 syscalls but **no MSM and no pairing syscall** | [1] Full `sp1-lib` rustdoc index, fetched |
| Both provide recursion/aggregation capable of combining per-batch proofs | [1] RISC Zero `lift/join/resolve`; SP1 aggregation example + `syscall_verify_sp1_proof` |
| Both provide explicit upgrade/version-management machinery for on-chain verifiers | [1] RISC Zero version-management design; SP1 gateway versioning policy |

### 13.2 (2) Evidence from existing implementations or published benchmarks — sparse

| What exists | What it does **not** cover |
|---|---|
| SP1 Hypercube: 16×RTX 5090, 954 L1 Ethereum blocks, 99.7% < 12 s / 95.4% < 10 s (M1) | Consensus/QC verification; blob KZG; RISC Zero; this workload's `C` |
| SP1 local proving memory floors (14 GB Groth16 wrap, 60 GB PLONK wrap) | Throughput |
| RISC Zero audit reports incl. a 2026-02-12 zkVM report | Throughput — **no published per-machine benchmark found at all** |
| Vendor-published advisories on both systems | — |
| **No published end-to-end "batch proof" latency for either system on an Ethereum L2 with a consensus proof attached was found** | — |

### 13.3 (3) Analytical estimates — clearly labelled

- The **concurrency requirement** `Q = L/Δ` (≈**900** in-flight proofs at Δ = 2 s, L = 30 min) follows from arithmetic on the stated constraints, not from measurement.
- `FLEET = max(e·G·C/R, (L/Δ)·k)` is an identity, not an estimate.
- The claim that **W1 is cheap relative to W2** (signature verification + a Merkle walk vs. full EVM execution) is an inference from the shape of the work, **not** measured. It is the basis for the per-epoch amortization idea in §§9–10 and should be tested first.
- The claim that **BLS12-381 MSM for 4096 elements dominates the blob path** is inferred from the EIP's own parameterisation (4096 field elements per blob) — the *constant* is sourced; the *cost* is not.

### 13.4 (4) Unmeasured implementation questions

1. What is `C` (cycles per L2 gas) for an Etna-style EVM guest **including** tx-signature recovery and trie hashing?
2. What is `R` (proven cycles/s) for each system on the chosen hardware, for a guest of this size (which determines memory pressure and whether the ~2 GB SP1 memory ceiling forces sharding)?
3. Does RISC Zero's `blst` patch accelerate **MSM and pairing** as single ops, and at what cost?
4. Can a 4096-point KZG MSM (or an opening check) be built in SP1 **without a pairing syscall**, and is the resulting proof verifiable given the on-curve / distinct-x / no-infinity constraints?
5. Can the Ethereum KZG SRS be loaded into the guest within the memory envelope of either zkVM?
6. What is the audited cost of the SNARK wrap in each system for a guest of this size (SP1 documents +1m30s for PLONK; RISC Zero publishes nothing)?
7. How many verifier routes must the L1 contract hold open, and what is the governance latency vs. the prover fleet's release cadence?
8. What is the actual on-chain gas of RISC Zero Groth16 verification, and does the SP1 ~270k/~300k figure still hold for the V6.1.0 verifier?

## 14. Recommendation and open questions

### 14.1 Recommendation: one combined guest

**COMBINED (8.1) is the better default for the Etna batch proof**, matching [04-architecture-decision.md](04-architecture-decision.md) §6 and `PRF-01`; composition is retained as an *optimization*, not the primary architecture. Reasons, in order of evidential weight:

1. **One TCB, one verifier route, one version to govern.** The dominant long-run risk in §§11–12 is stale-version acceptance and auditor lag, not on-chain gas. Every additional verifier route doubles that surface.
2. **The 30-minute latency budget removes the main argument for composition.** Composed proofs win when the consensus half can be produced much earlier than the execution half *and* latency is binding. Here latency is explicitly not binding (D6).
3. **Recursive composition re-introduces the exact bug class that has already been exploited.** SP1's most recent high-severity advisory (**GHSA-63x8**) was a *recursion-circuit* soundness gap; making the recursion circuit load-bearing for bridge security should require strong justification.
4. **On-chain composition costs ~2× verification** (≈2 × 270k–300k gas per the only sourced figures) and adds a journal-equality check that is itself part of the TCB.

### 14.2 The two conditions that would switch the choice to COMPOSED

1. **The consensus rule is expected to change on a cadence different from the EVM** (so upgrade independence is worth a second route and a second TCB).
2. **Per-epoch aggregation of the consensus proof produces a measured, material cost reduction** (today the "W1 is cheap" claim is class [3], not [2]).

If either is met, the composed design **must** (i) enforce the inner program identity in-circuit, (ii) compare journals on L1, and (iii) never let an inner proof's version float.

**Non-negotiable design invariants, independent of the choice:**

- `validator_set_commitment`, `validator_set_version`/`epoch`, `quorum_threshold`, `chain_id`, `prev_state_root` and the DA commitment are **public inputs derived from L1 state**, never prover-supplied witnesses.
- The guest re-derives membership and stake from that commitment and **verifies the signatures**; it never trusts a hint about who signed.
- For blobs, bind to the **KZG commitment / versioned hash**, never to a keccak of the bytes alone.
- The DA mode is domain-separated so a calldata proof can never satisfy a blob rule.
- The L1 contract pins **bounded batch ranges**, so a proof cannot be replayed for a different head.

### 14.3 Open questions, ordered by importance

Ordered by how much each can change the design. "Closes with" names the evidence that would retire it.

1. **Version skew: which SP1 SDK versions the mainnet verifiers accept, and the release→VKEY mapping** (§2.3 V1/V2, **UNVERIFIED**). This decides whether the prover fleet can be upgraded at all and whether the acceptance policy is implementable. **Closes with:** a documented/measured release→verifier-version/VKEY mapping, verified on mainnet and testnet.
2. **In-guest cost of the chosen blob binding** (the Lagrange evaluation at `z`; architecture decision F2; **UNMEASURED**). If it is not affordable, the blob path collapses to candidate (A) — whose MSM/pairing support is UNVERIFIED — or to calldata. **Closes with:** a measured cycle count and latency on both backends for 1..n blobs.
3. **Does RISC Zero accelerate BLS12-381 MSM and pairing as single ops?** (**UNVERIFIED**.) This is the fallback path for blobs if the Lagrange evaluation is too expensive, and it is also the reason §7 avoids pairings. **Closes with:** a kernel-level source read or a benchmark, with the exact patch tag.
4. **Is RISC Zero throughput adequate at all, for any workload?** No per-machine benchmark exists on the pages fetched. **Closes with:** a self-run datasheet (the vendor's own `datasheet` example) on the intended hardware, for this guest.
5. **What are `C` and `R` for the Etna workload on each backend?** (§10; **UNVERIFIED**.) Blocks fleet sizing entirely. **Closes with:** the measurement program in §10.1 plus a pre-committed fleet-size threshold.
6. **Can the Ethereum KZG SRS be loaded into the guest within the ~2 GB SP1 memory envelope (and RISC Zero's envelope)?** (**UNVERIFIED**.) Decides candidate (A) for both backends. **Closes with:** a memory-profiled guest run, or a documented in-guest SRS scheme.
7. **RISC Zero on-chain Groth16 verify gas** (**UNVERIFIED**; no official figure found), and whether SP1's ~270k/~300k still holds for the V6.1.0 verifier. Decides L1 affordability and the 2×-composition argument. **Closes with:** an official number or a measured mainnet-fork gas report per verifier version.
8. **Do per-precompile trace-level constraints match the documented behaviour?** Per-op **UNVERIFIED** on both backends; "the circuit enforces X" is currently verified at architecture level only. **Closes with:** reading the circuit/table specifications for each primitive the guest uses.
9. **What is the audited SNARK-wrap cost per backend for this guest size?** (RISC Zero: **UNVERIFIED**, nothing published; SP1: +~1m30s for PLONK, sourced.) Determines the serial tail in the 2 s cadence. **Closes with:** a vendor figure or a measurement.
10. **What is inside RISC Zero `v5.0.0-rc.1`, and does its circuit line change the crypto precompile set?** (**UNVERIFIED**.) The next upgrade step. **Closes with:** a release note, docs version or tag inspection.
11. **RISC Zero control IDs / control root values at v3.0.6** (**UNVERIFIED**). Needed to pin the verifier identity for a deployed contract. **Closes with:** published values, or derivation from the pinned toolchain and a reproducible build.
12. **Groth16 ceremony participant counts (RISC Zero) and bounty amounts (both)** (**UNVERIFIED**). Trust/supply-chain assessment, not a launch blocker. **Closes with:** the ceremony attestation page and the bounty program pages.
13. **Full text of SP1's aggregation warning and of its "Zero-Knowledgeness of SP1" section.** Truncated/not read at fetch → **UNVERIFIED**. Completeness of the aggregation and privacy analysis. **Closes with:** a full-text fetch or a pinned docs revision.

## Sources

Every URL below was retrieved **2026-10-05**; group headings state the version/tag the page documents where determinable. The same URLs appear inline where they are load-bearing.

**RISC Zero (v3.0.6 / risc0-ethereum v3.0.1 unless a page is unversioned "Next" docs):**
- Releases and crates: [releases API](https://api.github.com/repos/risc0/risc0/releases) · [crates.io risc0-zkvm](https://crates.io/api/v1/crates/risc0-zkvm) · [Cargo.toml @v3.0.6](https://raw.githubusercontent.com/risc0/risc0/v3.0.6/Cargo.toml) · [README @v3.0.6](https://raw.githubusercontent.com/risc0/risc0/v3.0.6/README.md) · [risc0-ethereum releases](https://api.github.com/repos/risc0/risc0-ethereum/releases)
- Verifier contracts: [deployment.toml @v3.0.1](https://raw.githubusercontent.com/risc0/risc0-ethereum/v3.0.1/contracts/deployment.toml) · [version-management-design.md](https://raw.githubusercontent.com/risc0/risc0-ethereum/release-1.0/contracts/version-management-design.md) · [contracts/verifier](https://dev.risczero.com/api/next/blockchain-integration/contracts/verifier)
- Docs ("Next" = 3.0 line): [recursion](https://dev.risczero.com/api/next/recursion) · [trusted-setup-ceremony](https://dev.risczero.com/api/next/trusted-setup-ceremony) · [security-model](https://dev.risczero.com/api/next/security-model) · [precompiles](https://dev.risczero.com/api/next/zkvm/precompiles) · [shrink-wrapping](https://dev.risczero.com/api/next/blockchain-integration/shrink-wrapping) · [composition](https://dev.risczero.com/api/next/zkvm/composition) · [benchmarks](https://dev.risczero.com/api/next/zkvm/benchmarks) · [Secure SDLC](https://dev.risczero.com/api/next/secure-sdlc) · [sitemap](https://dev.risczero.com/sitemap.xml)
- Advisories and audits: [advisories API](https://api.github.com/repos/risc0/risc0/security-advisories) · [GHSA-jqq4-c7wq-36h7](https://api.github.com/repos/risc0/risc0/security-advisories/GHSA-jqq4-c7wq-36h7) · [audits](https://api.github.com/repos/risc0/rz-security/contents/audits) · [audits/zkVM](https://api.github.com/repos/risc0/rz-security/contents/audits/zkVM) · [audits/precompiles](https://api.github.com/repos/risc0/rz-security/contents/audits/precompiles)
- Blob library: [risc0/c-kzg-4844 README](https://raw.githubusercontent.com/risc0/c-kzg-4844/main/README.md)

**SP1 (v6.8.1 / sp1-contracts v6.1.1 unless a page is unversioned "current" docs):**
- Releases and crates: [releases API](https://api.github.com/repos/succinctlabs/sp1/releases?per_page=5) · [crates.io sp1-zkvm](https://crates.io/api/v1/crates/sp1-zkvm) · [sp1-contracts releases](https://api.github.com/repos/succinctlabs/sp1-contracts/releases) · [sp1-contracts tree @v6.1.1](https://api.github.com/repos/succinctlabs/sp1-contracts/git/trees/v6.1.1?recursive=1) · [deployments/1.json @v6.1.1](https://raw.githubusercontent.com/succinctlabs/sp1-contracts/v6.1.1/contracts/deployments/1.json)
- Docs: [contract-addresses](https://docs.succinct.xyz/docs/sp1/verification/contract-addresses) · [proof-types](https://docs.succinct.xyz/docs/sp1/generating-proofs/proof-types) · [security-model](https://docs.succinct.xyz/docs/sp1/security/security-model) · [safe-precompile-usage](https://docs.succinct.xyz/docs/sp1/security/safe-precompile-usage) · [precompiles](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles) · [precompile-specification](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompile-specification) · [proof-aggregation](https://docs.succinct.xyz/docs/sp1/writing-programs/proof-aggregation) · [hypercube](https://docs.succinct.xyz/docs/sp1/hypercube/) · [prover-gas](https://docs.succinct.xyz/docs/sp1/optimizing-programs/prover-gas) · [hardware-requirements](https://docs.succinct.xyz/docs/sp1/getting-started/hardware-requirements) · [hardware-acceleration](https://docs.succinct.xyz/docs/sp1/generating-proofs/hardware-acceleration) · [upgrades](https://docs.succinct.xyz/docs/sp1/developers/upgrades) · [sitemap](https://docs.succinct.xyz/sitemap.xml)
- Rustdoc (6.8.1): [sp1_lib](https://docs.rs/sp1-lib/latest/sp1_lib/) · [sp1_lib::bls12381](https://docs.rs/sp1-lib/latest/sp1_lib/bls12381/index.html)
- Advisories, audits, benchmark, bounty: [advisories API](https://api.github.com/repos/succinctlabs/sp1/security-advisories) · [GHSA-63x8-x938-vx33](https://api.github.com/repos/succinctlabs/sp1/security-advisories/GHSA-63x8-x938-vx33) · [audits dir](https://api.github.com/repos/succinctlabs/sp1/contents/audits?ref=dev) · [audits commit history](https://api.github.com/repos/succinctlabs/sp1/commits?path=audits&per_page=12) · [16-GPU blog](https://blog.succinct.xyz/real-time-proving-16-gpus/) · [Code4rena bounty](https://code4rena.com/bounties/succinct)

**Ethereum / cryptography:**
- [EIP-4844](https://eips.ethereum.org/EIPS/eip-4844) (Final EIP text) · [EF KZG ceremony wrap-up, 2024-01-23](https://blog.ethereum.org/en/2024/01/23/kzg-wrap) · [ePrint 2020/654](https://eprint.iacr.org/2020/654.pdf) (proximity gaps) · [ePrint 2023/1284](https://eprint.iacr.org/2023/1284) (LogUp GKR) · [ePrint 2024/1571](https://eprint.iacr.org/2024/1571) (Basefold) · [ePrint 2025/917](https://eprint.iacr.org/2025/917) (Jagged PCS)

**Repository sources (pinned):** [research/zkvm-feasibility-raw.md](research/zkvm-feasibility-raw.md) (this session, unmodified) · [04-architecture-decision.md](04-architecture-decision.md) · [spec/05-proof-statement.html](spec/05-proof-statement.html) · [spec/index.html](spec/index.html) · [DECISIONS.md](DECISIONS.md).

## Appendix — UNVERIFIED register (do not cite as fact)

| # | Item | Why it matters |
|---|---|---|
| U1 | Any per-machine proving throughput for RISC Zero on any workload | Blocks §10 entirely for RISC Zero |
| U2 | `C` (cycles per L2 gas) for the Etna workload, either system | Blocks fleet sizing |
| U3 | Whether RISC Zero accelerates BLS12-381 **MSM** and **pairing** as single ops | Decides fallback blob-path feasibility |
| U4 | Whether SP1 can do a BLS12-381 **pairing** at acceptable cost without a pairing syscall | Decides whether KZG *opening* checks are possible in SP1 |
| U5 | In-guest cost of a 4096-point MSM (either system) | Dominant blob-path cost driver for candidate (A) |
| U6 | Whether the Ethereum KZG SRS fits in the guest (SP1 documents a ~2 GB zkVM memory limit) | Blob-path feasibility for candidate (A) |
| U7 | RISC Zero on-chain Groth16 verify gas (no official figure found) | L1 affordability |
| U8 | Contents of RISC Zero `v5.0.0-rc.1` (empty release body) | Future upgrade path |
| U9 | The SP1 release → verifier-version/VKEY mapping (docs pin V5.x.y/V6.1.0; SDK is 6.8.1) | Live version-skew hazard |
| U10 | RISC Zero control IDs / control root values at v3.0.6 | Verifier pinning |
| U11 | Groth16 ceremony participant counts (RISC Zero) and bounty amounts (both) | Trust/supply-chain assessment |
| U12 | Per-precompile trace-level constraint descriptions (both vendors) | Depth of the trust-model claim in §5 |
| U13 | Full text of SP1's aggregation warning and of its "Zero-Knowledgeness of SP1" section | Completeness of §9 and §3.2 |
| U14 | Any published end-to-end L2 batch-proof latency, either system | §10 transferability |