# Etna PoS + ZK — Consensus Survey (raw evidence file)

Status: RAW research dump for the Etna PoS + ZK design. Not a spec.
Author: delegated research agent. Retrieval date for every source: **2026-10-05** (unless a source itself carries a different date, which is quoted).
Write target: this file only. No other file in the repository was modified.

## 0. How to read this document (evidence classes)

Every statement below is tagged with one of four classes, because the design decision hinges on which class a claim belongs to:

| Tag | Meaning |
|---|---|
| **[C]** | **Compatibility in principle** — a property that follows from the protocol's stated rules (quoted from a primary source) applied to our target context. It is an argument, not a measurement. |
| **[I]** | **Evidence from an existing implementation or published benchmark** — a number or behaviour reported by a named implementation version / paper, with the URL. |
| **[A]** | **Analytical estimate** — my calculation from verified protocol parameters. No measurement. Clearly derived, reproducible from the inputs shown. |
| **[U]** | **UNVERIFIED / unmeasured** — cannot be established from the sources retrieved. What would verify it is stated. |

Sources are inline as markdown links; the consolidated list with versions and retrieval dates is in Section 12. Where the repository itself is referenced, the path is given as a link.

## 1. Fixed target context and derived requirements

The target is fixed by the task and is not re-litigated here:

- Ethereum L2, transaction order determined by **permissionless L2 PoS validators** (no strict L1/based sequencing).
- L2 target cadence: **one block every 2 seconds**.
- Finalized L2 history is settled on L1 by an **Inbox** contract that accepts a batch **only if the batch data and a zkVM validity proof land in the same L1 transaction** (no data-first/proof-later path).
- The zkVM proof must authenticate **(a)** the PoS consensus evidence making the batch's head block final, and **(b)** correct EVM execution of the batch. Proving latency of minutes to 30 minutes is normal.
- Validators are **permissionless** and stake the **existing TAIKO ERC-20** (not ETH).
- The validator set must ultimately be **authenticated from L1**; a prover-supplied witness must never define its own authoritative validator set.
- **Mode A** (safety-first): no recovery path may invalidate a legitimately PoS-finalized block; a safe halt is acceptable. **Mode B** (permissionless L1 recovery) exists but is not preferred — so Mode A feasibility must be established first.
- Weak subjectivity / long-range attacks must be analysed honestly.
- The preconf **URC** is not a building block.

### 1.1 What the consensus layer must therefore expose

| # | Requirement | Why it follows from the target |
|---|---|---|
| R1 | A **finality certificate** that is a self-contained, bounded-size object for a head block. | It must be embedded in (or referenced by) an L1 transaction together with the batch data. |
| R2 | A certificate whose verification is cheap in a zkVM guest (bounded signature verifications, bounded hashing). | Requirement (a) of the proof obligation. |
| R3 | An explicit **epoch / validator-set binding** inside the certificate. | The L1 contract, not the prover, must decide which set counts. |
| R4 | A rule for **how a certificate from an older set is judged later** (superseded epochs). | Permissionless staking means the set changes continuously. |
| R5 | Safety under **partial synchrony** with an explicit fault threshold, plus a story for what happens when the threshold is violated (safe halt / Mode B). | Mode A. |
| R6 | A **locking/commit rule** such that a certificate that is never published cannot later invalidate a decision already taken. | The L1 Inbox decides irreversibly; a withheld certificate must not be able to rewrite that. |
| R7 | Liveness that does not require a specific correct leader forever, with bounded recovery from a stalled round. | 2 s cadence and permissionless participation. |
| R8 | Cost model as a function of n (messages, bytes, signature verifications). | Validator set size is a design variable (TAIKO stake distribution). |
| R9 | Behaviour under equivocation, partition, selective delivery, and equivocation visibility. | Needed for slashing/accountability and for Mode B triggers. |
| R10 | Honest separation of measured vs estimated cadence and latency. | No fabricated benchmarks. |

### 1.2 Grounding in this repository

- The existing L1 entry points are [Inbox.sol](../../../../contracts/layer1/core/impl/Inbox.sol) with a `propose(...)` function (line 270) and a separate `prove(...)` function (line 321), plus an `IProofVerifier` abstraction (line 17, 71). The target design removes the data-first/proof-later split for Mode A; the `propose`/proof-later path is exactly the path that must not be able to finalize.
- The staking asset already exists as [TaikoToken.sol](../../../../contracts/layer1/mainnet/TaikoToken.sol) — an L1 ERC-20, which is what makes "validator set authenticated from L1" implementable as a staking-contract state commitment rather than a witness.

*Repository-relative link paths in this file are repointed to correct targets (the same path appears in §8.6, item 4); this closes review round 9 finding R9-AC-02.*

## 2. Candidate set

| Family | Instances surveyed here | Why included |
|---|---|---|
| A | Tendermint / CometBFT (consensus spec at `main`, releases up to v0.40.0 and v1.0.1) | Highest-maturity partial-synchrony BFT with per-validator signatures (no DKG) and an explicit lock/unlock rule; large production base; the polling/vote structure produces a natural, small finality certificate. |
| B | HotStuff, DiemBFT v4, Jolteon/Ditto, HotStuff-2, Carry-the-Tail (2025) | The linear-communication lineage; threshold-signature QCs make certificates tiny; HotStuff-2 removes the third phase. |
| C | DAG-Rider, Narwhal/Tusk, Bullshark, Shoal++, Mysticeti/Mysticeti-FPC, Starfish (2025), Beluga (2025) | The latency/throughput state of the art; production (Sui). Included mainly to test whether their finality evidence is zk-provable. |
| D1 | Casper FFG + LMD-GHOST (Gasper) style checkpoint attestations with BLS aggregates | The materially different design: finality evidence is one aggregate signature + a bitmap, verified with 2 pairings; the Ethereum light-client protocol is a fully specified instance of exactly this artifact shape. |
| D2 | Simplex (Chan & Pass, TCC 2023) | Deliberately minimal 2-chain protocol with a bare PKI, no threshold setup; a plausible "smallest protocol that satisfies R6/R7" baseline. |
| D3 | Streamlet (Chan & Shi, AFT 2020) | Included as a simplicity baseline; **not deep-dived**: the primary text was not retrieved in this session (see §6.3). |

Rejected as a building block: the preconf URC (per task), and any design in which the prover supplies the validator set (violates the L1-authentication requirement).

---
## 3. Family A — Tendermint / CometBFT

### 3.0 Version anchors (retrieved 2026-10-05)

| Item | Value | Source |
|---|---|---|
| Latest GitHub release | **v0.40.0**, published 2026-07-27 | [cometbft/cometbft releases/latest](https://api.github.com/repos/cometbft/cometbft/releases/latest) |
| Newest by publication date in last 100 releases | **v0.38.26**, 2026-08-13 | [releases list](https://api.github.com/repos/cometbft/cometbft/releases?per_page=100) |
| Other active lines | v0.39.4 (2026-07-28); v1.0.1 present in the last 100 releases | same |
| Spec text quoted | `spec/consensus/consensus.md`, `spec/abci/abci++_*.md`, `spec/core/data_structures.md` on branch `main` (unversioned; verify against the release tag before relying on a quote) | [consensus.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/consensus.md), [abci++_methods.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_methods.md), [abci++_app_requirements.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_app_requirements.md), [data_structures.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/core/data_structures.md) |

Note on provenance: CometBFT has **four maintained release lines** at once (v0.37.x, v0.38.x LTS, v0.39.x, v0.40.x) plus v1.0.1. Any integration must pin an exact line and re-verify the spec quotes against that tag; the spec files above are branch-tip and unversioned. **[U]** for line-by-line agreement with v0.40.0.

### 3.1 The eleven attributes

| # | Attribute | Finding | Tag |
|---|---|---|---|
| 1 | Safety model | Byzantine voting power **< 1/3**; quorum **> 2/3** of voting power for prevote-PoLC and for commit. Safety holds under **asynchrony**; liveness requires **partial synchrony** (eventual GST + bounded delay). | [C] |
| 2 | Quorum / lock / commit rule | PoLC = +2/3 prevotes for a block or nil at (H,R). Lock on PoLC in the precommit step; unlock only via a later-round PoLC. Commit on +2/3 precommits for a block (see quotes in §3.2). | [C] |
| 3 | Equivocation / partition / withholding | Safety argument: 2/3 precommits at round R implies 1/3+ honest are locked at R; a conflicting PoLC later would need 2/3 prevotes for something else, but at most 2/3 are available (spec's own words). A **withheld certificate cannot invalidate** a decision, because finality is defined by the 2/3 precommit set, not by publication. Partition: safety preserved, liveness lost. | [C] |
| 4 | View change / recovery | Round-based; new round after timeouts (timeout_propose 3 s + 500 ms/round; prevote/precommit 1 s + 500 ms/round). A proposal may carry a **PoLC-Round** to let locked validators unlock. Proposer is chosen deterministically per round; a correct proposer is required in some round after GST (no leader forever needed). Message complexity per round: 2 votes × n broadcasters → O(n²) transmissions. | [C] |
| 5 | Dynamic membership | The application sets validator updates during FinalizeBlock; **updates take effect at H+2**. There is no in-protocol epoch concept and no in-protocol cap on how much voting power may change per height — that discipline lives in the application (for us: the L1 staking/epoch contract). | [C] |
| 6 | Cost per block per validator | Vote broadcast: each validator sends 2 votes/height to n−1 peers → per-validator egress ≈ 2n × (vote size). Global O(n²). Analytical numbers in §3.4. | [A] |
| 7 | Cadence / finality latency | Config defaults: timeout_propose 3 s, timeout_prevote 1 s, timeout_precommit 1 s, timeout_commit 1 s; the config doc states blocks are produced "~ every second (with default consensus parameters)". **No published measurement at 2 s with a named n and hardware was retrieved.** | [I] for defaults, [U] for measurements |
| 8 | Verifier inputs | Commit / ExtendedCommit: BlockID, Height, Round, BlockIDFlag (participation), ValidatorAddress, Timestamp, Signature, and for extended commits Extension + ExtensionSignature + NonRpExtension. Cost driver: one signature verification per signing validator, plus voting-power summation against the epoch set. | [C] |
| 9 | What a certificate cannot show | Data availability of the block contents, off-chain safety, equivocation visibility (a single commit shows one vote per validator), liveness. Fork accountability needs **JSets** (all votes + justifying PoLCs), not the commit alone. | [C] |
| 10 | zkVM fit | Ed25519 (accelerated in both RISC Zero and SP1 via patched curve25519-dalek). Witness ≈ (sig 64 B + pubkey/address 32/20 B) × signers. No DKG, no pairing needed if Ed25519 is used. | [C] + [Z1][Z3] |
| 11 | Modification risk | Replacing individual signatures with a BLS aggregate changes accountability and the proof that applies (§10). Changing the commit rule invalidates the lock/unlock safety proof in §3.2. | [A] |

### 3.2 The rules, quoted (primary source)

From the CometBFT consensus spec ([consensus.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/consensus.md), retrieved 2026-10-05):

- Quorum vocabulary: "A set of +2/3 of prevotes for a particular block or nil at (H,R) is called a **proof-of-lock-change** or PoLC for short."
- Unlock rule (Prevote step): "First, if the validator is locked on a block since LastLockRound but now has a PoLC for something else at round PoLC-Round where LastLockRound < PoLC-Round < R, then it unlocks."
- Lock rule (Precommit step): "If the validator has a PoLC at (H,R) for a particular block B, it (re)locks (or changes lock to) and precommits B and sets LastLockRound = R." / "Else, if the validator has a PoLC at (H,R) for nil, it unlocks and precommits nil." / "Else, it keeps the lock unchanged and precommits nil."
- Commit rule: "After +2/3 precommits for a particular block. --> goto Commit(H)".
- Proof of Safety: "Assume that at most -1/3 of the voting power of validators is byzantine. If a validator commits block B at round R, it's because it saw +2/3 of precommits at round R. This implies that 1/3+ of honest nodes are still locked at round R' > R. These locked validators will remain locked until they see a PoLC at R' > R, but this won't happen because 1/3+ are locked and honest, so at most -2/3 are available to vote for anything other than B." (The hyphenated "-1/3" / "-2/3" are typos in the spec for "less than 1/3" / "less than 2/3".)
- Proof of Liveness: "If 1/3+ honest validators are locked on two different blocks from different rounds, a proposers' PoLC-Round will eventually cause nodes locked from the earlier round to unlock. Eventually, the designated proposer will be one that is aware of a PoLC at the later round."
- Fork accountability: "Define the JSet (justification-vote-set) at height H of a validator V1 to be all the votes signed by the validator at H along with justification PoLC prevotes for each lock change."

**Critical boundary detail for the L1 contract [U]:** the fetched spec text defines "1/3+" as "1/3 or more" but does **not** expand "+2/3" into a comparison. The implementation commits on **strictly more than 2/3** of voting power (equivalently 2f+1 of n=3f+1 with equal power). The Inbox must encode the comparison exactly as the implementation does (strict vs non-strict, and voting-power arithmetic), otherwise a certificate accepted by the chain may be rejected by L1 or vice versa. Verifying this requires reading the release-tag code (e.g. the commit/vote verification path) — not done here.

### 3.3 Vote extensions (ABCI++) — the one place arbitrary data can ride a precommit

From [abci++_methods.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_methods.md) (retrieved 2026-10-05):

- ExtendVote is called when a validator is about to precommit a **non-nil** block, after it sets lockedValue/validValue; the application returns bytes that the consensus engine attaches to the precommit.
- In the extended commit structure ([data_structures.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/core/data_structures.md)): "Extension | bytes | Vote extension provided by the Application ... Length must be zero if BlockIDFlag is not Commit"; "ExtensionSignature | Signature | Signature of the vote extension. Must be valid for the validator public key type if BlockIDFlag is Commit"; plus a NonRpExtension ("non replay-protected vote extension ... signed by CometBFT and attached to the Precommit message. No replay-protection is applied to the data").
- Spec warning relevant to any design that reads extensions: "extensions of votes included in the commit info after the minimum of +2/3 had been reached are not verified" (i.e. the application verifies each received extension, but only those that mattered for reaching the quorum are guaranteed to have been checked by the receiver in the normal flow).

Consequence for Etna **[C]**: a CometBFT-style precommit can carry an application-chosen payload signed with the validator's consensus key, and that payload lands in the ExtendedCommit that a zkVM could consume. That is a real mechanism, but it is *not needed* for the certificate in §3.8 — the state root can be part of the block header/execution proof instead. Using it adds a non-determinism surface (extension verification is application-defined and partly skipped) and should be treated as an optional optimization, not a requirement.

### 3.4 Cost model (analytical, n = validator count)

Inputs: each height has 2 vote messages per validator; a CometBFT vote carries validator address (20 B), block ID (hash 32 B + parts hash 32 B), height, round, timestamp, signature (64 B Ed25519) — call it **~180–300 B** on the wire depending on encoding and extensions. **[A]**

| Quantity | Formula | n = 100 | n = 150 | n = 200 |
|---|---|---|---|---|
| Vote transmissions per height (global) | 2·n·(n−1) | 19,800 | 44,700 | 79,600 |
| Vote bytes per height (global, at 250 B) | 2·n·(n−1)·250 B | ~5.0 MB | ~11.2 MB | ~19.9 MB |
| Per-validator egress per height | 2·(n−1)·250 B | ~49.5 KB | ~74.5 KB | ~99.5 KB |
| Signature verifications per validator per height | 2·(n−1) | 198 | 298 | 398 |
| Signature verifications per validator per second at 2 s blocks | (2·(n−1))/2 | ~99/s | ~149/s | ~199/s |
| Certificate size (one commit, >2/3 signers ≈ 0.67n) | signers × (20 B addr + 64 B sig) + overhead | ~5.7 KB | ~8.5 KB | ~11.4 KB |

At the 2 s target these are modest single-node loads **[A]**; the binding constraint is not bandwidth but (i) the L1-authenticated epoch set and (ii) zkVM signature verification (Section 9). Block propagation (the actual transactions) is additional and dominates bytes for large blocks. **[A]**

### 3.5 Dynamic membership in CometBFT (what has to be replaced for Etna)

- Spec: "Note the updates returned after processing the block at height H will only take effect at block H+2" ([abci++_app_requirements.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_app_requirements.md)).
- The spec parameterizes validator pubkey types ("ValidatorParams.PubKeyTypes ... restricts the type of keys validators can use") but the retrieved section does not enumerate defaults. **[U]** — verify Ed25519-sec1/Ed25519 default against the release tag code before relying on zkVM cost estimates.

For Etna the CometBFT-native update path is the wrong primitive: it lets the L2 application decide the next set. The design must instead **quantize** membership into epochs whose set (pubkeys + stake weights) is computed by the **L1 staking contract** and committed to the Inbox (e.g. a set hash per epoch). The consensus engine then receives an "update to exactly this set" instruction, not a discretionary update. This is a modification with a proof consequence: CometBFT's H+2 and its safety proof are agnostic to how the set was chosen, so the published safety argument still applies **per height** as long as the certificate names the epoch/set it was signed under and the verifier checks that binding. **[C]**

### 3.6 What the L1 Inbox / zkVM guest must check (Family A)

Minimal public inputs: chain id, epoch id, validator-set commitment (root or hash), head block height H, block hash (or BlockID: block hash + parts hash), round, and the batch/state-root commitments.

Witness and checks **[C]**:
1. For each signer: validator address/index, signature over the canonical vote bytes (type, height, round, block ID, timestamp, chain id).
2. Membership + weight: the signer must be in the epoch set, with the weight recorded there (Merkle/SSZ proof, or a set supplied in-witness whose computed root is a public input compared by the contract against L1 storage).
3. Quorum: sum of signing weight strictly exceeds 2/3 of total weight (exact comparison TBD, §3.2).
4. Block binding: the signed BlockID equals the hash of the head block whose state root the execution proof produces.
5. Optional: verify the header chain from the batch's first block to H (hash linkage), while only H's commit needs a signature quorum — finality of H implies its ancestors by the protocol's own safety property; the execution proof covers the state transitions. **[C]** This is what makes the certificate O(n) signatures **per batch**, not per block.

### 3.7 zkVM notes

- Ed25519 verification is accelerated in both zkVMs through patched curve25519-dalek crates ([RISC Zero precompiles](https://dev.risczero.com/api/zkvm/precompiles): "curve25519-dalek 4.1.3, 4.1.2, 4.1.1, 4.1.0"; [SP1 precompiles](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles): "curve25519-dalek ... 4.1.3", "curve25519-dalek-ng ... 4.1.1").
- Published cycle counts for Ed25519 verification in either zkVM were **not found** on the official pages retrieved. **[U]** — measure before sizing batches.

---
## 4. Family B — HotStuff lineage (HotStuff, DiemBFT v4, Jolteon/Ditto, HotStuff-2, Carry-the-Tail)

### 4.0 Version anchors (retrieved 2026-10-05)

| Instance | Primary source | Notes |
|---|---|---|
| HotStuff | [arXiv:1803.05069](https://arxiv.org/abs/1803.05069) (text read via [ar5iv](https://ar5iv.labs.arxiv.org/html/1803.05069)) | The original chained, threshold-signature protocol. |
| DiemBFT v4 | [Diem technical report, 2021-08-17](https://developers.diem.com/papers/diem-consensus-state-machine-replication-in-the-diem-blockchain/2021-08-17.pdf) | **PDF only; not retrievable with the tools available in this session** (application/pdf unsupported). All DiemBFT v4 statements below are therefore marked [U] unless corroborated by Jolteon/Ditto. |
| Jolteon / Ditto | [arXiv:2106.10362](https://arxiv.org/abs/2106.10362) (text read via [ar5iv](https://ar5iv.labs.arxiv.org/html/2106.10362)) | Peer-reviewed description of DiemBFT as 3-chain HotStuff; introduces a 2-chain variant and an asynchronous fallback. |
| HotStuff-2 | [IACR ePrint 2023/397](https://eprint.iacr.org/2023/397) (abstract page retrieved; **PDF fetch blocked by Cloudflare 403**, so protocol details are [U]) | "Extended Abstract ... two-phase commit regime within a view, and optimistic responsiveness", last revised 2023-04-17. |
| Carry-the-Tail | [arXiv:2508.12173](https://arxiv.org/abs/2508.12173) (abstract retrieved) | 2025 "drop-in mechanism for streamlined protocols in the HotStuff family" against tail-forking. |

### 4.1 The eleven attributes

| # | Attribute | Finding | Tag |
|---|---|---|---|
| 1 | Safety / liveness model | Fixed committee n = 3f+1, up to f Byzantine; safety always, liveness after GST with a correct leader in a view (pacemaker). HotStuff-2 adds optimistic responsiveness. | [C] for HotStuff/Jolteon; [U] for HotStuff-2 details |
| 2 | Quorum / lock / commit | QCs are **(k,n)-threshold signatures with k = 2f+1**: "Throughout this paper, we use a threshold of k = 2f+1"; n = 3f+1. HotStuff: three phases inside a view; a replica locks on the precommitQC; decide on commitQC. Jolteon: a **2-chain** commit rule (quoted below). HotStuff-2: two phases. | [C] |
| 3 | Equivocation / partition / withholding | Withheld QC cannot invalidate a decision: safety is the standard quorum-intersection argument over 2f+1 of 3f+1. Equivocation by a leader is handled by the pacemaker (view change), not by slashing evidence inside the QC. A QC does **not** reveal which replicas signed (threshold signature) — accountability is weaker than Tendermint's per-validator votes. | [C] |
| 4 | View change | New-view message carrying the highest QC; with threshold signatures this is O(n) messages, not O(n²) (Jolteon deliberately trades this for a quadratic pacemaker: "quadratic view-change (O(n) messages of O(n) size)"). No correct leader is needed for safety; liveness after GST needs a correct leader in some view. | [C] |
| 5 | Dynamic membership | HotStuff assumes a **fixed** set. The DiemBFT/epoch reconfiguration mechanics are the natural place to look, but the primary text was not retrievable here. **This is the weakest attribute of family B for Etna.** | [U] |
| 6 | Cost per view | Threshold-signature QC: leader ↔ replicas, O(n) messages per view, O(n²) worst case across timeouts. Certificate (QC) size: one threshold signature + identifiers. | [C] |
| 7 | Cadence | Jolteon: 2-chain rule "reducing the steady state block-commit latency by 30%"; the paper implements and evaluates its systems, but absolute latency numbers at a named n/hardware were not extracted here. | [I] relative, [U] absolute |
| 8 | Verifier inputs | QC = (view, block hash, threshold signature) + epoch/set binding. Cost: **1 threshold-signature verification** (2 BLS12-381 pairings) + set/epoch binding. Fallback if individual signatures are aggregated with a bitmap: n signature verifications. | [C] |
| 9 | What a certificate cannot show | Data availability, liveness, **who signed** (threshold sig), and any equivocation evidence. | [C] |
| 10 | zkVM fit | Threshold BLS = 1 signature + 1 pubkey (96 B + 48 B per the Ethereum BLS container sizes) but requires a **DKG / trusted dealer and resharing** as the set changes — awkward under permissionless staking. Aggregate BLS over individual signatures avoids the DKG but needs proof-of-possession registration (see D1). | [C] |
| 11 | Modification risk | Swapping the threshold signature for an aggregate changes the accountability and the dealer assumptions; changing 3-chain to 2-chain removes the third-phase safety argument (Jolteon pays a quadratic view change for it). | [A] |

### 4.2 Rules, quoted

- HotStuff threshold signatures ([arXiv:1803.05069](https://arxiv.org/abs/1803.05069), retrieved via ar5iv 2026-10-05): "We consider a system consisting of a fixed set of n = 3f+1"; "HotStuff makes use of threshold signatures"; "In a (k,n)-threshold signature scheme, there is a single public key ... Throughout this paper, we use a threshold of k = 2f+1."
- HotStuff locking/commit: "it combines them into a precommitQC and broadcasts it"; "a replica becomes locked on the precommitQC at this point by setting its lockedQC to precommitQC"; "it combines them into a commitQC. Once the leader has assembled a commitQC, it sends it in a decide message to all other replicas."
- HotStuff pacemaker: "The mechanisms needed to achieve liveness are encapsulated within a Pacemaker, cleanly separated from the mechanisms needed for safety."
- Jolteon ([arXiv:2106.10362](https://arxiv.org/abs/2106.10362)): "we design a 2-chain version of HotStuff, Jolteon, which leverages a quadratic view-change mechanism to reduce the latency of the standard 3-chain HotStuff"; "Jolteon preserves the structure of HotStuff and its linearity under good network conditions while reducing the steady state block-commit latency by 30% using a 2-chain commit rule. This decrease in latency comes at the cost of a quadratic view-change (O(n) messages of O(n) size)."
- Ditto: "Ditto replaces the pacemaker of HotStuff/DiemBFT (a quadratic module that deals with view synchronization) with an asynchronous fallback."
- HotStuff-2 ([ePrint 2023/397](https://eprint.iacr.org/2023/397)): "it is possible to solve partially-synchronous BFT and simultaneously achieves O(n^2) worst-case communication, optimistically linear communication, a two-phase commit regime within a view, and optimistic responsiveness"; "The main takeaway is that two phases are enough for BFT after all." **[U]:** the exact 2-chain commit predicate and the safety proof are in the full paper, which was not retrievable (PDF). Anyone modifying or implementing it must obtain the PDF and re-derive.
- Carry-the-Tail ([arXiv:2508.12173](https://arxiv.org/abs/2508.12173)): "the first deterministic atomic broadcast protocol in partial synchrony that, after GST, guarantees a constant fraction of commits by non-faulty leaders against tail-forking attacks, and maintains optimal, worst-case quadratic communication under a cascade of faulty leaders"; it is "a practical drop-in mechanism for streamlined protocols in the HotStuff family".

### 4.3 Assessment for Etna

Strengths **[C]**: linear communication with threshold signatures; very small QCs; HotStuff-2's two-phase rule and optimistic responsiveness; an active 2024–2026 line of work (Carry-the-Tail) addressing the exact failure mode (tail-forking / leader-induced stalls) that a 2 s cadence makes painful.

Weaknesses **[C]/[U]**:
1. **Threshold trust setup.** A (2f+1, n) threshold key must be generated and reshared as the permissionless set changes. Under L1-authenticated, staking-weighted membership this is a substantial subsystem, and a resharing failure is a halt (acceptable under Mode A) or a safety risk if done wrong.
2. **Reconfiguration evidence gap.** The retrieved primary sources do not specify epoch reconfiguration; DiemBFT v4's mechanism is behind an unfetchable PDF. For a design whose R3/R4 are the crux, this is the decisive practical gap.
3. **Accountability.** A threshold QC hides the signer set; slashing/evidence (Mode B triggers) needs extra data that is not part of the QC by default.

---

## 5. Family C — DAG-based BFT

### 5.0 Version anchors (retrieved 2026-10-05)

| Instance | Source | Key verified facts |
|---|---|---|
| DAG-Rider | [arXiv:2102.08325](https://arxiv.org/abs/2102.08325) | Abstract retrieved; full text not extractable (ar5iv text exceeded the fetch limit). **[U]** for rule text. |
| Narwhal / Tusk | [arXiv:2105.11827](https://arxiv.org/abs/2105.11827) (ar5iv text read) | Certificate = acks; validity requires 2f+1 certificates of the previous round. |
| Bullshark | [arXiv:2201.05677](https://arxiv.org/abs/2201.05677) (ar5iv text read) | Waves of 4 rounds; 2 rounds to commit a steady-state leader; no view change. |
| Shoal++ | [arXiv:2405.20488](https://arxiv.org/abs/2405.20488) | Average 4.5 message exchanges to commit vs 10.5 for prior DAG-BFT. |
| Mysticeti / Mysticeti-FPC | [arXiv:2310.14821v6](https://arxiv.org/abs/2310.14821v6) (HTML read; **truncated before §III**, see note) | Uncertified DAG; certificate pattern = 2f+1 support; 3 message rounds; Sui production numbers. |
| Starfish (2025) | [ePrint 2025/567](https://eprint.iacr.org/2025/567) | Uncertified-DAG liveness gap and desynchronization attacks; Push pacemaker; Mysticeti-L. |
| Beluga (2025) | [arXiv:2511.15517](https://arxiv.org/abs/2511.15517) | Pull-induction attack on Mysticeti's block synchronizer; up to 3x throughput and 25x lower latency under attack. |

**Fetch limitation to record honestly [U]:** the arXiv HTML for Mysticeti v6 exceeded the fetch budget and was truncated inside Section II; the *exact* Mysticeti-C commit predicate in §III was **not** read. What **is** verified verbatim: block validity ("at least 2f+1 blocks from the previous round" as references), the skip pattern, and the certificate pattern ("at least 2f+1 blocks at round r+1 support a block B ... We then say that B is certified"), plus the claim of committing "within the known lower bound of 3 message rounds". Anyone implementing must read §III of the paper (or the NDSS 2025 version, DOI 10.14722/ndss.2025.240929) before coding the commit rule.

### 5.1 The eleven attributes

| # | Attribute | Finding | Tag |
|---|---|---|---|
| 1 | Safety / liveness | n = 3f+1, up to f Byzantine (Mysticeti: "in each epoch, n = 3f+1 validators"; "a computationally bound adversary can statically corrupt an unknown set of up to f validators"). Safety under asynchrony for the certified designs; liveness after GST (Mysticeti states the GST/Δ model explicitly). | [C] |
| 2 | Quorum / commit | Narwhal: a valid block "must ... contain certificates for at least 2f+1 blocks of round r−1"; a certificate forms from 2f+1 acks. Bullshark: waves of 4 rounds; "It takes two rounds to commit a steady-state leader." Mysticeti: certificate pattern = 2f+1 blocks in round r+1 supporting B; commit every block in 3 message rounds. | [C] |
| 3 | Equivocation / withholding | Certified DAGs: reliable broadcast + certificates make equivocation a non-event. Mysticeti explicitly: "At most one of these equivocating blocks can gather support from 2f+1 validators ... even if A equivocates and one of its blocks is certified, we process it as being correct". A withheld certificate cannot invalidate a decision (quorum intersection). | [C] |
| 4 | Recovery | **No view change**: Bullshark "does not require a view change or view synchronization mechanisms to overcome faulty or slow leaders"; leaders are per-wave (predefined steady-state + a fallback chosen from DAG randomness). A stalled leader delays its own commit, not DAG growth. | [C] |
| 5 | Dynamic membership | All surveyed papers are **per-epoch static**. Mysticeti says properties hold "within a single epoch" and defines equivocation recovery "across epochs"; but no reconfiguration protocol is specified. | [C]/[U] |
| 6 | Cost | Certified (Narwhal/Bullshark): a block carries 2f+1 certificates, each carrying 2f+1 signatures → **O(n²) signatures and O(n²) bytes per block**. Uncertified (Mysticeti): 1 signature per block + 2f+1 hash references → O(n) hashes. | [A] from [C] rules |
| 7 | Cadence | Measured, production: Sui switched from Bullshark (1.9 s P50) to Mysticeti-C (400 ms) "on 106 independently run validators"; paper reports "WAN latency of 0.5s for consensus commit" and "over 200k TPS"; Bullshark paper reports "125k TPS and 2 second latency with 50 honest parties". | [I] |
| 8 | Verifier inputs | Certified: the whole commit structure (leader cert + 2f+1 support certs, each with 2f+1 signatures) → O(n²) signature verifications per committed leader. Uncertified: the supporting blocks themselves (2f+1 blocks with 1 signature each) + reference hashes → O(n) signatures + O(n²) hashes per committed block. | [A] |
| 9 | What a certificate cannot show | The DAG is off-chain: a client/L1 verifier sees a commit proof, not the DAG. Data availability requires the batch data (which our Inbox carries anyway). Equivocation visibility requires publishing the equivocating vertices. | [C] |
| 10 | zkVM fit | Signature scheme is Ed25519-family per validator; cost scales with the *support structure*, not just n. For uncertified DAGs the witness includes many block headers/hashes. **[U]**: no published zk proof of a DAG-BFT commit was found. | [C]/[U] |
| 11 | Modification risk | Collapsing the DAG into a single commit certificate changes the object whose safety was proven; the published safety arguments are about the DAG's implicit certification, not about a standalone certificate. | [A] |

### 5.2 Rules, quoted

- Narwhal ([arXiv:2105.11827](https://arxiv.org/abs/2105.11827), via ar5iv): "Each block from a validator contains a round number, and must include a quorum of certificates from the previous round to be valid"; "Once certificates for round r−1 are accumulated from 2f+1 distinct validators, a validator moves the local round to r, creates, and broadcasts a block for the new round"; "If a block is valid the other validators store it and acknowledge it by signing its block digest, round number, and creator's identity."
- Bullshark ([arXiv:2201.05677](https://arxiv.org/abs/2201.05677), via ar5iv): "Every round in its DAG has at most n vertices (one for each party), each of which contains a block of transactions as well as references (edges) to at least 2f+1 vertices in the previous round."; "BullShark rounds are grouped in waves, each of which consists of 4 rounds."; "It takes two rounds to commit a steady-state leader."; "BullShark does not require a view change or view synchronization mechanisms to overcome faulty or slow leaders."; measured: "achieving 125k TPS and 2 second latency with 50 honest parties".
- Mysticeti ([arXiv:2310.14821v6](https://arxiv.org/abs/2310.14821v6), NDSS 2025): "Once a block contains references to at least 2f+1 blocks from the previous round, the validator signs it and sends it to other validators."; "The certificate pattern ... where at least 2f+1 blocks at round r+1 support a block B ≡ (A,r,h). We then say that B is certified."; "we obtain certificates implicitly by interpreting the DAG, and the certification guarantees are identical to Narwhal"; "requires a single signature generation and verification per block, minimizing the CPU overhead"; "the first DAG-based Byzantine consensus protocol to achieve the lower bounds of latency of 3 message rounds"; "it does not require explicit certificates"; production: "switching from Bullshark (1.9s) to Mysticeti-C (400ms) on 106 independently run validators".
- Shoal++ ([arXiv:2405.20488](https://arxiv.org/abs/2405.20488)): "existing DAG-BFT protocols pay a steep latency premium, requiring on average 10.5 message exchanges to commit a transaction ... Shoal++, a novel DAG-based BFT consensus system that offers the throughput of DAGs while reducing commit latency to an average of 4.5 message exchanges"; "reducing latency by up to 60%".
- Starfish ([ePrint 2025/567](https://eprint.iacr.org/2025/567)): "Uncertified DAG-based BFT protocols, such as Mysticeti and Cordial Miners, achieve state-of-the-art latency by eliminating per-block quorum certificates. However, they have lacked rigorous liveness proofs, and recent work has demonstrated explicit desynchronization attacks where honest parties fail to commit leaders after Global Stabilization Time (GST)."
- Beluga ([arXiv:2511.15517](https://arxiv.org/abs/2511.15517)): "We also uncover a new attack, where an adversary steers honest validators into redundant, uncoordinated pulls that exhaust bandwidth and stall progress"; "We integrate Beluga into Mysticeti, the consensus core of the Sui blockchain, and show on a geo-distributed AWS deployment that Beluga ... under attack, delivers up to 3x higher throughput and 25x lower latency than prior designs."

### 5.3 Why family C is the hardest to settle on L1 (the zk problem)

A DAG-BFT "commit" is a statement about a partially-ordered set of vertices, not about a single signed message. To authenticate a committed leader/block you must convince the verifier that the support pattern exists. That means the witness includes the supporting vertices and *their* ancestors, and the verifier re-derives the DAG patterns. **[A]** For a certified DAG (Narwhal/Bullshark) with n = 100 (f = 33): a leader certificate carries 67 signatures, and its 67 supporting vertices each carry 67 signatures → ≈ 4,489 signature verifications per committed leader (4,489 × 64 B ≈ 287 KB of signatures alone, before the vertex bodies). For an uncertified DAG (Mysticeti) the same pattern costs 67 signatures but requires the supporting blocks' bodies (each with 67 hash references) to be present in the witness to evaluate "support" — so the witness is hash-dominated rather than signature-dominated. **[A]** Neither has a published zk instantiation. **[U]**

Counterpoint worth stating fairly **[C]**: the DAG is built anyway by the L2 validators, and the *batch* that the Inbox settles carries the transactions; a zkVM proving execution of the batch could, in principle, also replay the DAG structure from the witness. The question is whether the DAG replay fits the 30-minute proving budget at realistic block sizes — **unmeasured** [U].

---
## 6. Family D — checkpoint/attestation designs

### 6.1 D1: Casper FFG / Gasper-style finality with BLS aggregate attestations

This is the materially different design: instead of voting on every block with per-validator signatures, validators attest to **checkpoints** once per epoch, and the finality evidence is a **single BLS aggregate signature plus a participation bitmap**.

**Version anchors (retrieved 2026-10-05):** Gasper [arXiv:2003.03052](https://arxiv.org/abs/2003.03052); Casper FFG [arXiv:1710.09437](https://arxiv.org/abs/1710.09437); Ethereum consensus specs on branch master — [altair/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/altair/beacon-chain.md), [altair/light-client/sync-protocol.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/altair/light-client/sync-protocol.md), [phase0/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/beacon-chain.md); [ethereum.org weak subjectivity](https://ethereum.org/en/developers/docs/consensus-mechanisms/pos/weak-subjectivity/); [IETF BLS draft-irtf-cfrg-bls-signature-05](https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-bls-signature-05).

| # | Attribute | Finding | Tag |
|---|---|---|---|
| 1 | Safety / liveness | Safety: < 1/3 of stake Byzantine, enforced by **slashing conditions**; the notion of "accountable safety" comes from Casper FFG: "Slashing conditions: these are conditions that honest validators would never violate and violating validators can provably be caught". Liveness ("plausible liveness") needs 2/3 online; the LMD-GHOST fork choice has independent synchrony-flavoured assumptions and known reorg attacks. | [C] |
| 2 | Quorum / commit rule | Verified verbatim in Casper FFG: "A supermajority link is an ordered pair of checkpoints (a,b), also written a → b, such that at least 2/3 of validators (by deposit) have published votes with source a and target b."; "A checkpoint c is called justified if (1) it is the root, or (2) there exists a supermajority link c′ → c where checkpoint c′ is justified."; "A checkpoint c is called finalized if (1) it is the root or (2) it is justified and there is a supermajority link c → c′ where c′ is a direct child of c." | [C] |
| 3 | Equivocation / partition / withholding | Equivocation is punished by the slashing conditions (double vote; surround vote — exact wording not retrieved here **[U]**). A withheld aggregate cannot invalidate a finalized checkpoint (quorum intersection), but a withheld *conflicting* justification can enable the known reorg-style attacks on the fork-choice/finality interaction. | [C]/[U] |
| 4 | Recovery | No view change. Proposer per slot; fork choice follows the heaviest subtree; recovery from a bad proposer is one slot. Slow finality (epochs), fast fork-choice. | [C] |
| 5 | Dynamic membership | Native and continuous: activation/exit queues and per-epoch churn. The light-client design adds a rotation: sync committees of **512** validators, with the committee committed inside the beacon state and proven to the next committee. | [C] |
| 6 | Cost | Per validator: one attestation signature per epoch (not per block) plus aggregation traffic. Certificate: 1 aggregate signature + bitmap (+ committee commitment). | [C] |
| 7 | Cadence | Checkpoint finality, not per-block finality: on Ethereum, epochs are 32 slots of 12 s and finality takes ~2 epochs (≈12.8 min) — the epoch/period constants were not re-verified in this session beyond SYNC_COMMITTEE_SIZE=512 **[U]**. For Etna the epoch length is a free parameter (e.g. 64 × 2 s = 128 s), and checkpoint finality is a natural match for batch settlement. | [C]/[U] |
| 8 | Verifier inputs | Verified fields from the light-client sync protocol: attested_header, next_sync_committee + branch, finalized_header + finality_branch, sync_aggregate (sync_committee_bits + signature), signature_slot. The 2/3 rule is the spec line "get_set_bit_count(sync_committee_bits) * 3 >= len(sync_committee_bits) * 2"; verification calls "bls.FastAggregateVerify(...)". Sizes: BLSPubkey is Bytes48 and BLSSignature is Bytes96 (phase0/beacon-chain.md); the 512-key committee is therefore 24,576 B of pubkeys if supplied in-witness. | [C] |
| 9 | What a certificate cannot show | Same gaps as A plus: a 512-member committee is a **sample** of the full validator set, so the certificate's safety inherits a sampling assumption unless the full set is used. **[U]**: the exact validity conditions (e.g. how a light client decides the committee is the right one) were only partially read. | [C]/[U] |
| 10 | zkVM fit | 1 aggregate verify = 2 pairings + (k−1) G1 additions for the aggregate pubkey, plus ~log2(state size) hashes for the branch. Both zkVMs patch the bls12_381 crate (RISC Zero also patches blst); **no published pairing cycle counts** were found. **[U]** | [C]/[U] |
| 11 | Modification risk | Customising FFG (epoch length, checkpoint definition, fork choice) invalidates the composition proofs in Gasper; the interaction of LMD-GHOST and FFG is exactly where the published attacks live. Using BLS aggregates requires **proof of possession** at registration (IETF draft §3: "These schemes differ in the ways that they defend against rogue key attacks" — basic / message augmentation / proof of possession). | [C] |

**Why this is attractive for Etna [C]:** the artifact shape is exactly what an L1 contract wants: one 96-byte signature, one 48-byte aggregate pubkey, a 64-byte bitmap, and a set/epoch commitment — and Ethereum L1 already prices the verification: [EIP-2537](https://eips.ethereum.org/EIPS/eip-2537) (Final) specifies BLS12_PAIRING_CHECK at "32600*k + 37700" gas. With k = 2, on-chain verification is ≈102,900 gas plus calldata. The open questions are (i) whether the zkVM can prove the pairing cheaply, and (ii) whether a permissionless TAIKO-staked set can be aggregated without a DKG (yes, with PoP; the aggregate is public).

### 6.2 D2: Simplex (Chan & Pass)

[IACR ePrint 2023/463](https://eprint.iacr.org/2023/463) (TCC 2023). Abstract retrieved verbatim: "We next present a new and simple consensus protocol in the partially synchronous setting, tolerating f < n/3 byzantine faults ... As with the state-of-the-art protocols, our protocol assumes a (bare) PKI, a digital signature scheme, collision-resistant hash functions, and a random leader election oracle, which may be instantiated with a random oracle (or a CRS)."

| # | Attribute | Finding | Tag |
|---|---|---|---|
| 1 | Model | f < n/3, partial synchrony, bare PKI, no threshold setup. | [I] (abstract) |
| 2 | Commit rule | The protocol is widely described as a 2-round "notarize then finalize" rule (2f+1 notarize votes, then 2f+1 finalize votes for the block notarized in the previous round). **UNVERIFIED at source**: the paper is PDF-only and not readable with the tools available here. Verification requires the ePrint PDF or the TCC proceedings version. | [U] |
| 3-5 | Behaviour, recovery, membership | Presumed to mirror HotStuff/Tendermint-family properties (quorum intersection, leader rotation via the random oracle, per-epoch set). Not verified. | [U] |
| 6-8 | Cost / verifier | If the 2-round rule is as described: per round, 2f+1 signatures on a block; the finality certificate is O(n) signatures over 1–2 blocks, i.e. the same verification profile as Tendermint with a 2-round (rather than 3-phase) structure and no DKG. | [A] from [U] rule |
| 10 | zkVM fit | Same as Tendermint if individual signatures; no pairing required. | [C] |

Included because it is the smallest published protocol that plausibly satisfies R6/R7 with a bare PKI, and because its published contribution includes a framework for **optimistic vs pessimistic confirmation time** — useful vocabulary for our latency budgeting.

### 6.3 D3: Streamlet (not deep-dived)

Chan & Shi, "Streamlet: Textbook Streamlined Blockchains", ACM AFT 2020, DOI [10.1145/3419614.3423256](https://dl.acm.org/doi/abs/10.1145/3419614.3423256); ePrint 2020/088. Standard description: epochs with a deterministic leader, a block is notarized by 2/3 signatures, and a chain of three consecutive notarized blocks with increasing epoch numbers finalizes the middle block; it is a **synchronous** protocol (liveness needs synchrony, not just partial synchrony). **[U]** — none of this was verified against the primary text in this session. Note for future readers: the arXiv identifier I first guessed for Streamlet (2002.02798) resolves to an unrelated paper; do not cite it.

---

## 7. Cross-family comparison

### 7.1 Safety, quorum and certificate shape

| Family | Fault threshold | Quorum | Finality object | Finality evidence size | Hides signers? |
|---|---|---|---|---|---|
| A Tendermint/CometBFT | < 1/3 voting power | > 2/3 prevotes (PoLC), > 2/3 precommits (commit) | Commit certificate at (H, R) | (2f+1) signatures + addresses + BlockID, ≈ 5.7–11.4 KB for n = 100–200 **[A]** | No — per-validator votes |
| B HotStuff / DiemBFT v4 / Jolteon / HotStuff-2 | f < n/3, n = 3f+1 | k = 2f+1 threshold shares | QC chain (3-chain HotStuff; 2-chain Jolteon/HotStuff-2) | 1–2 threshold signatures + identifiers, ~200 B | Yes — threshold signature |
| C Narwhal/Bullshark (certified) | f < n/3 | 2f+1 acks per certificate | Leader certificate + support pattern | O(n²) signatures per leader **[A]** | No |
| C Mysticeti (uncertified) | f < n/3 | 2f+1 support blocks | Implicit certificate in round r+1 | 2f+1 signatures + O(n²) hash references **[A]** | No |
| D1 Gasper/FFG + BLS | < 1/3 stake | ≥ 2/3 by deposit | Justified → finalized checkpoint pair | 1 aggregate sig (96 B) + bitmap (64 B) + committee pubkeys if needed (24,576 B for 512) | No, but aggregation hides individual contributions |
| D2 Simplex | f < n/3 | 2f+1 per round (unverified rule) | Notarize/finalize votes | O(n) signatures | No |

### 7.2 Measured cadence/latency evidence (what exists vs what does not)

| System | Number as published | Conditions as published | Source | Class |
|---|---|---|---|---|
| Sui / Mysticeti-C (production) | P50 commit 400 ms (was 1.9 s with Bullshark) | 106 independently run validators | [Mysticeti §I](https://arxiv.org/abs/2310.14821v6) | [I] |
| Mysticeti-C (paper experiments) | WAN commit latency 0.5 s, > 200k TPS | wide-area network deployment | same | [I] |
| Bullshark (paper experiments) | 125k TPS, 2 s latency | 50 honest parties | [arXiv:2201.05677](https://arxiv.org/abs/2201.05677) | [I] |
| Shoal++ | average 4.5 message exchanges to commit vs 10.5; up to 60% lower latency | not extracted in detail | [arXiv:2405.20488](https://arxiv.org/abs/2405.20488) | [I] |
| CometBFT | blocks "~ every second (with default consensus parameters)"; timeout_commit default 1 s | default config, n not stated | [configuration.md](https://raw.githubusercontent.com/cometbft/cometbft/main/docs/core/configuration.md) | [I] for defaults, **[U]** for measurements at 2 s |
| HotStuff / Jolteon | Jolteon 2-chain "reducing the steady state block-commit latency by 30%" | their implementation; absolute numbers not extracted | [arXiv:2106.10362](https://arxiv.org/abs/2106.10362) | [I] relative only |
| Tendermint/CometBFT at n ≈ 100–200, 2 s blocks | no published number found | — | — | **[U]** |

**No measurement for any protocol at our exact target (2 s blocks, TAIKO-staked permissionless set, zkVM-proven finality) exists in the sources retrieved. Every number above is from a different deployment context.** Any claim of "2 s cadence" for Etna is therefore an extrapolation, except for the generic statement that these protocols' timeouts can be configured to 2 s.

### 7.3 Dynamic membership and reconfiguration attack surface

| Family | Set-change mechanism in the source | Attack surface to design against |
|---|---|---|
| A | App-driven validator updates, effective at H+2 (quoted) | Set substitution by the L2 app; stake-bleeding-style grinding is not applicable to explicit-quorum BFT but *set churn* can be used to dodge slashing/accountability if transitions are not recorded on L1 |
| B | Fixed set in HotStuff; Diem epoch reconfiguration not retrievable [U] | Threshold key must be reshared on every set change; a stale-epoch QC must be judged by an explicit epoch rule |
| C | Per-epoch static set; reconfiguration unspecified [U] | Same as B, plus DAG structure from a previous epoch may be replayed |
| D1 | Continuous validator churn; sync-committee rotation committed in state | Rogue-key attack if aggregates are used without proof of possession; weak subjectivity/long-range (below) |

### 7.4 Weak subjectivity and long-range attacks (honest treatment)

[ehereum.org weak subjectivity](https://ethereum.org/en/developers/docs/consensus-mechanisms/pos/weak-subjectivity/) (retrieved 2026-10-05) states the problem plainly:

- "Subjectivity in blockchains refers to reliance upon social information to agree on the current state."
- Attack vectors "including long-range attacks whereby nodes that participated very early in the chain maintain an alternative fork that they release much later to their own advantage."
- "Alternatively, if 33% of validators withdraw their stake but continue to attest and produce blocks, they might generate an alternative fork that conflicts with the canonical chain. New nodes or nodes that have been offline for a long time might not be aware that these attacking validators have withdrawn their funds, so attackers could trick them into following an incorrect chain."
- Mitigation: "weak subjectivity checkpoints ... state roots that all nodes on the network agree belong in the canonical chain"; "The checkpoints act as 'revert limits' because blocks located before weak-subjectivity checkpoints cannot be changed."

Applied to Etna **[C]**:
1. **The L1 contract is the weak-subjectivity checkpoint.** Because the Inbox lives on L1, its stored finalized state root is objective contract state, not social consensus. A new node or a new prover does not need social input to know the current finalized root — it reads L1.
2. **The validator set is objective but the epoch chain is not, by itself.** A long-range attacker can produce valid signatures from a historical TAIKO-staked set. The contract must therefore (a) track a monotonic finalized height, (b) accept only certificates whose epoch is the current epoch or a successor recorded by an L1 transition, and (c) never accept a certificate that conflicts with an already-finalized height. This makes the long-range attack a *contract-invariant* problem, not a consensus-proof problem.
3. **Withdrawal timing is a first-class parameter.** The "33% withdrew but still sign" attack is only prevented if the L1 staking contract enforces an unbonding delay longer than the maximum time between a validator's last possible attestation and the settlement of the batch it signed. Given proving latency up to 30 minutes, the unbonding delay must be hours-to-days, and the epoch set commitment must include stake *as of the epoch*.
4. **Stake-bleeding is not the same threat.** [Stake-Bleeding Attacks on Proof-of-Stake Blockchains](https://eprint.iacr.org/2018/248) (ePrint 2018/248) describes "a general attack on proof-of-stake (PoS) blockchains without checkpointing ... Our attack leverages transaction fees, the longest chain rule to completely dominate a blockchain." Etna has checkpointing on L1 and explicit quorums, so the original attack does not transfer; what transfers is the general lesson that any *chain-based* component (e.g. a fork choice for ordering) can be ground down if it lacks an objective checkpoint.
5. **Weak subjectivity of the *ordering* rule.** If order is determined by the L2 PoS chain rather than by L1, an L2 node that has been offline still needs a trusted, recent L1-finalized root to avoid following a long-range L2 fork. The Inbox's stored root provides exactly that; clients must be specified to use it. **[C]**

---
## 8. What an external verifier must check (L1 contract and/or zkVM guest)

### 8.1 The public-input contract

For Mode A the Inbox should treat these as public inputs that the contract itself fixes (not the prover):

| Public input | Source of truth | Why |
|---|---|---|
| chain id / domain separator | contract constant | Replay protection across chains and across the Inbox's own history. |
| epoch id | L1 staking registry | Binds the certificate to one validator set. |
| validator-set commitment (root/hash), and total stake | L1 staking registry, written once per epoch | Prevents prover-supplied sets (R3). |
| last finalized height + last finalized root | Inbox storage | Enforces monotonicity and no-conflict (Mode A invariant). |
| head height H, head block hash, head state root | certificate + execution proof output | Binds consensus evidence to execution. |
| batch data hash | calldata | Binds the settled data to what was proven. |

### 8.2 Exact data per family

| Family | Data the verifier must see | Signature verifications | Other ops |
|---|---|---|---|
| A Tendermint/CometBFT | Commit/ExtendedCommit for height H: BlockID (block hash + parts hash), Height, Round, BlockIDFlag per validator, ValidatorAddress, Signature, Timestamp (see [data_structures.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/core/data_structures.md)); plus the epoch set (pubkeys + weights) or proofs against its root | one per signer, s ≥ 2f+1 (≤ n) | voting-power sum, set membership, canonical-vote hashing |
| B HotStuff lineage | QC: view/height, block hash, threshold signature; for a 2-chain rule, the child QC (or a single QC if the rule is defined over the child) | 1 threshold verify (2 pairings) or s individual/aggregated verifies | epoch/set binding |
| C DAG (certified) | leader certificate + 2f+1 supporting certificates, each with its own 2f+1 acks | ≈ s² (s = 2f+1) | O(n²) hash/reference checks, DAG pattern evaluation |
| C DAG (uncertified, Mysticeti) | 2f+1 supporting blocks (bodies with 2f+1 references each) + their signatures, over the rounds the commit rule needs | ≈ s per committed block (plus ancestors pulled in) | O(s²) hash/reference checks |
| D1 Gasper/BLS | attested_header + finalized_header + finality_branch + sync_aggregate(bits, signature) + signature_slot + participating committee pubkeys or committee root | 1 FastAggregateVerify (2 pairings) | bitmap 2/3 check, Merkle branch (~log2 state size hashes), pubkey aggregation (s−1 G1 adds) |
| D2 Simplex | notarize + finalize vote sets (rule unverified) | O(n) per round | quorum sum |

### 8.3 The set-authentication pattern (non-negotiable)

A prover-supplied validator set is unsafe because the prover can choose a set it controls. Three workable patterns:

1. **Guest computes, contract compares.** The guest takes the set from the witness, computes its commitment, and exposes that commitment as a **public output**; the Inbox compares it with the epoch's set root in L1 storage and reverts on mismatch. The guest never decides the set; it only proves "the signatures are valid under *this* set". **[C]**
2. **Guest verifies a membership proof against an L1-known root.** The root is passed in as a public input by the contract; individual validators are Merkle/SSZ-proven. Same effect, more hashing in-guest. **[C]**
3. **Set committed on L1 and read by the guest via a storage proof.** Strongest but most expensive; unnecessary if pattern 1 is used correctly. **[C]**

Under all three, the epoch transition itself must be an L1 transaction (staking contract -> Inbox), so that no certificate can be judged under two different sets. **[C]**

### 8.4 Cost drivers as functions of n (analytical)

Let s = number of signers (s ≥ 2f+1 ≈ 0.67n), and let each Ed25519 signature be 64 B with a 32 B public key (RFC 8032 sizes; the RFC was retrieved and uses 32-octet keys and 64-octet signatures). Let BLS12-381 points be 48 B (G1) and 96 B (G2) per the Ethereum containers BLSPubkey = Bytes48 / BLSSignature = Bytes96 ([phase0/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/beacon-chain.md)). **[A]**

| Certificate style | Witness bytes | Verifications | n = 100 (s ≈ 67) | n = 150 (s ≈ 101) | n = 200 (s ≈ 133) |
|---|---|---|---|---|---|
| A: Ed25519 individual | s × 96 + bitmap | s Ed25519 | 6.4 KB, 67 verifies | 9.7 KB, 101 verifies | 12.8 KB, 133 verifies |
| A': + Merkle paths to the set root | s × (96 + ~32·log2 n) | s Ed25519 + hashes | ~26 KB | ~62 KB | ~110 KB |
| B: threshold BLS QC | 96 + 48 + metadata | 2 pairings | ~200 B | ~200 B | ~200 B |
| B': aggregate of individual BLS + bitmap | 96 + s×48 + bitmap | 2 pairings + (s−1) G1 adds | 3.3 KB | 4.9 KB | 6.5 KB |
| C certified DAG (support pattern) | s × (96 + 32·s) ≈ dominated by references | s² Ed25519 | ~4,489 verifies | ~10,201 verifies | ~17,689 verifies |
| C uncertified DAG | s × block bodies + s signatures | s Ed25519 + s² hashes | 67 verifies, ~4.5k hashes | 101 verifies, ~10k hashes | 133 verifies, ~17.7k hashes |
| D1 BLS committee of 512 | 96 + 64 + 512×48 (if pubkeys supplied) = 24.7 KB | 2 pairings | 24.7 KB | 24.7 KB | 24.7 KB |
| D1' compressed (aggregate pubkey precomputed per epoch) | 96 + 48 + 64 = 208 B | 2 pairings | 208 B | 208 B | 208 B |

Observations **[A]**:
- For n ≤ ~150, **individual Ed25519 is competitive with BLS on witness size** (6.4 KB vs 3.3 KB) and loses only on verifier work (67 verifications vs 2 pairings). Whether that matters depends entirely on the measured cost ratio in the chosen zkVM — which is unpublished (§9.5). This is the single most important measurement to make before freezing the design.
- D1's 24.7 KB is dominated by the 512 committee public keys. If the committee's aggregate public key is precomputed per sync-committee period (Ethereum does not do this on-chain, but an L2 could), the artifact collapses to 208 B.
- Certified DAGs are two orders of magnitude worse on verifier work; that is a structural property of "2f+1 acknowledgements per block", not an implementation artifact.

### 8.5 What CANNOT be established from public certificates alone

| Not established | Why | Evidence that would be needed |
|---|---|---|
| Data availability of block bodies | A certificate commits to a BlockID/hash, not to data | The batch data itself (which the Inbox carries in the same transaction) plus DA sampling/publishing rules for blocks not in a batch |
| Off-chain safety (no future conflicting signature) | A certificate proves a quorum signed once; it does not prove they will never sign a conflict | The protocol's fault assumption + slashing/accountability; for threshold/aggregate QCs, signer identity is not recoverable |
| Equivocation visibility | One certificate shows at most one vote per validator | Two conflicting signed messages for the same (height, round, type) — Tendermint's JSet; impossible with a bare threshold signature |
| Liveness | No certificate proves future progress | Liveness monitoring, Mode B triggers, and a published halt policy |
| Set authenticity | Inherited from the certificate only if the epoch/set is bound and checked | L1 set registry + the comparison in §8.3 |
| DAG no-equivocation | The DAG's guarantees come from the vertices, not from a single signature | The full vertex set (or a proof over it) |

### 8.6 Mode A contract invariants (independent of the zkVM)

These belong in the Inbox and are what actually makes "no recovery path invalidates a PoS-finalized block" true **[C]**:

1. **Monotone finalization:** lastFinalizedHeight only increases; every accepted batch must extend lastFinalizedRoot.
2. **Uniqueness:** at most one finalized block hash per height; a conflicting certificate reverts.
3. **Epoch monotonicity:** a certificate is accepted only for the current epoch or a recorded successor; a certificate from a superseded epoch is rejected unless it is exactly the height that epoch transitioned at.
4. **Prove-only-with-data (Mode A):** the entry point takes data + proof in one transaction; the legacy data-first path ([Inbox.propose](../../../../contracts/layer1/core/impl/Inbox.sol)) must not be able to create a finalizable artifact.
5. **Mode B cannot override:** any recovery entry point must be coded to revert if the height it targets is already finalized. This must be a tested invariant, not a convention.
6. **Safe halt:** on failure of any assumption (no valid certificate, set transition not finalized on L1), progress stops rather than falls back.

---

## 9. zkVM feasibility (RISC Zero and SP1), verified against official docs

### 9.1 Version anchors (retrieved 2026-10-05)

| zkVM | Latest stable | Notes |
|---|---|---|
| RISC Zero | **v3.0.6**, published 2026-07-17 ([releases API](https://api.github.com/repos/risc0/risc0/releases?per_page=8)); docs site header says "Version: 3.0" ([precompiles doc](https://dev.risczero.com/api/zkvm/precompiles)) | A **v5.0.0-rc.1** pre-release tag exists (created 2026-01-15, empty release body, marked prerelease). No v4.x tags appear in the 40 most recent tags. Treat the v5 line as not-yet-stable. |
| SP1 | **v6.8.1**, published 2026-09-24 ([releases API](https://api.github.com/repos/succinctlabs/sp1/releases?per_page=8)) | Patch tags in the docs reference "sp1-6.0.0"/"sp1-6.2.0" minimum versions. |

### 9.2 Signature primitives: what is accelerated, per official docs

RISC Zero ([precompiles doc](https://dev.risczero.com/api/zkvm/precompiles), retrieved 2026-10-05) states: "RISC Zero's rv32im implementation includes a number of specialized extension circuits, including 'precompiles' for cryptographic and algebraic functions: SHA-256, RSA, elliptic curve, and modular multiplication operations." It lists patched crates including:

| Scheme | RISC Zero patched crate (as printed) | SP1 patched crate (as printed) |
|---|---|---|
| Ed25519 | curve25519-dalek 4.1.3, 4.1.2, 4.1.1, 4.1.0 (via ed25519-dalek patch) | curve25519-dalek 4.1.3; curve25519-dalek-ng 4.1.1 |
| secp256k1 ECDSA | k256 0.13.4–0.13.1 (some versions need the "unstable" feature flag) | k256 13.4; secp256k1 0.29.1, 0.30.0 |
| secp256r1 / P-256 | p256 0.13.2 | p256 13.2 |
| BN254 | substrate-bn 0.6.0 | substrate-bn 0.6.0 |
| BLS12-381 | bls12_381 0.8.0; **blst 0.3.14** (footnote: c-kzg "requires a patched version of blst to enable full acceleration") | bls12_381 0.8.0 (two patches: crates-io and GitHub variants); kzg-rs is "a pure Rust alternative to c-kzg ... relies on our patched bls12_381 crate" |
| Keccak / SHA | tiny-keccak 2.0.2; sha2 0.10.8/0.10.7/0.10.6/0.9.9 | tiny-keccak 2.0.2; sha3 0.10.8/0.11.0; sha2 up to 0.11.0 |

Caveats printed by the vendors themselves:
- RISC Zero: "Certain versions of patches for some crates (e.g. k256, rsa) depend on more optimized precompiles that are still undergoing revision and review, and so users must opt-in ... by setting the 'unstable' feature flag". Also: "These precompiles do not currently provide strict guarantees about constant-time execution and proving time."
- RISC Zero: "if you set the secp256k1 feature flag, it will use the secp256k1 crate instead, where we don't currently provide a patch."
- SP1: the BLS12_381 patch has two incompatible variants ("some teams use the 'latest' BLS12_381 on GitHub, and some use the one on crates.io"), and keccak patching is feature-dependent ("alloy-primitives selects its keccak256 backend by feature ... if source = registry...crates.io rather than the sp1-patches git source, the keccak patch is not active").

**What this does and does not prove [U]:** the existence of a patched crate means the vendor has an accelerated path for that library's operations. It does **not** tell us which BLS12-381 operations are circuit precompiles (field arithmetic? group ops? the pairing?) or the cycle cost. RISC Zero's own list of circuit-accelerated primitives names "elliptic curve" and "modular multiplication", not pairings. Treat "BLS12-381 pairing is cheap in a zkVM" as **unverified** until measured.

### 9.3 Witness size and scaling

See §8.4. For the recommended Family A design the witness is dominated by s signatures + the set material; it does not grow with the number of blocks in the batch once the head certificate is the only consensus evidence (**[A]**, conditional on the head-certificate argument in §3.6 item 5).

### 9.4 Recursion and on-chain verification

- RISC Zero v3.0.1 release notes (2025-08-21) list: "New much faster recursion witness generation that runs on GPU" and "New much faster Groth16 implementation that run on GPU" ([releases API](https://api.github.com/repos/risc0/risc0/releases?per_page=8)). This is direct evidence that recursion and a Groth16 wrapping path exist in the v3 line; **no gas or cycle figures are given** in the release notes.
- SP1's docs describe off-chain proving and reference patched crates; on-chain verification costs were **not** retrieved from a primary SP1 page in this session **[U]**.
- L1 verification cost of a Groth16/PLONK proof on Ethereum in the current fork was **not** retrieved **[U]**. What **is** verified: [EIP-2537](https://eips.ethereum.org/EIPS/eip-2537) is Final and prices a BLS12-381 pairing check at 32600*k + 37700 gas, so a BLS aggregate can be verified *directly by the L1 contract* for ≈102,900 gas (k = 2) if it chooses not to put that check inside the zkVM.

### 9.5 What is unknown (explicit list)

1. Cycle count of one Ed25519 verification in RISC Zero 3.0.6 / SP1 6.8.1. **[U]**
2. Cycle count of one BLS12-381 pairing (and of FastAggregateVerify) in either zkVM. **[U]**
3. Whether BLS12-381 pairings are a dedicated circuit precompile or software over accelerated field arithmetic. **[U]**
4. Cost of 100–150 Ed25519 verifications in one guest, and the resulting proof time (vs the 30-minute budget). **[U]**
5. Gas cost of verifying a Groth16/PLONK proof on Ethereum today. **[U]**
6. Behaviour of either zkVM on DAG-scale witnesses (millions of hashes). **[U]**
7. A published zkVM proof of *any* BFT finality certificate (any family). Not found. **[U]**

### 9.6 Recommended measurement spike (before freezing the design)

Benchmark, in both zkVMs, with pinned versions: (a) 150 Ed25519 verifications over distinct messages; (b) one BLS12-381 FastAggregateVerify with 100 participating keys plus the keccak/SSZ hashing of the epoch set; (c) the same with a precomputed aggregate pubkey; (d) proof size and L1 verification gas for the wrapping path; (e) end-to-end proving time for a batch of 150 blocks (5 minutes of L2 history) with the execution proof included. Only after (a)–(c) can the Ed25519-vs-BLS decision be made on evidence rather than on crate names.

---

## 10. Modification analysis: which published proofs stop applying

| Modification | Published proof that no longer applies | What would be needed instead |
|---|---|---|
| Replace per-validator Ed25519 precommits with a **BLS aggregate + bitmap** (Family A) | Fork-accountability/JSet reasoning (needs individual signed messages); also the "signer set is provable" part of the safety argument | The quorum-intersection safety proof survives **if** the aggregate provably authenticates exactly the bitmap's participants over the same message and the aggregate is verified with proof-of-possession-registered keys (IETF draft §3: basic / message augmentation / proof of possession schemes exist precisely to stop rogue-key attacks). Requires a new argument for slashing evidence: the aggregate cannot be opened to individual signatures, so evidence must be collected separately. |
| Change HotStuff's 3-phase rule to a **2-chain** rule | The original HotStuff safety proof's three-phase structure | Jolteon's proof (with a quadratic view change) or HotStuff-2's proof; Jolteon states the trade-off explicitly: "reducing the steady state block-commit latency by 30% using a 2-chain commit rule. This decrease in latency comes at the cost of a quadratic view-change". |
| **Pipelining** blocks in flight | The unpipelined pacing/liveness argument (commit order vs view order) | A pipelined safety/liveness argument (the HotStuff paper argues pipelining is natural, but the safety proof must be restated for the pipeline depth and the pacemaker's interaction). |
| **Epoch-quantized, L1-authenticated membership** (all families) | All surveyed papers assume a fixed set per epoch; CometBFT's H+2 rule is the only source with an explicit activation delay | A per-epoch safety statement plus a cross-epoch transition rule: certificate valid under the set of its declared epoch; the contract accepts only certificates of the current/recorded-next epoch; and a proof that two different epochs cannot both finalize conflicting heights. This is a **new** proof obligation for Etna, independent of the family chosen. |
| Use CometBFT **vote extensions** to carry the L2 state root | Nothing directly (extensions are a supported feature), but the spec notes extensions of votes beyond the quorum minimum "are not verified", and verification is application-defined | If the extension is load-bearing for finality, an argument that every extension contributing to a certificate was verified. Recommendation: keep it non-load-bearing; the state root belongs in the execution proof. |
| Swap LMD-GHOST for a simpler fork choice inside a D1-style design | Gasper's composition proof (fork choice + FFG safety/liveness) | A new composition proof; the known reorg/balancing attacks on the LMD-GHOST/FFG interaction are exactly the failure mode to re-analyse. |
| Use a **512-member committee** instead of the full validator set (D1) | Nothing published *for our setting*; Ethereum's light-client security relies on random sampling of the committee | A sampling argument (hypergeometric tail bound) that a < 1/3 stake adversary cannot control ≥ 1/3 of a randomly drawn committee except with negligible probability, plus a committee-rotation rule authenticated from L1. |

---

## 11. Ranking for Etna PoS + ZK

Scoring: 5 = best. Criteria are those requested.

| Criterion | A Tendermint/CometBFT | B HotStuff-2 / Jolteon | C Mysticeti (DAG) | D1 Gasper-BLS | D2 Simplex |
|---|---|---|---|---|---|
| (i) Small, cheap-to-verify finality evidence | **5** (s ≈ 2f+1 Ed25519 sigs; no DKG; ~6–13 KB) | **4** (1–2 threshold sigs, ~200 B, but DKG) | **2** (O(n²) sigs certified; O(n²) hashes uncertified) | **4** (208 B–24.7 KB, 2 pairings) | **4** (O(n) sigs, 2 rounds; rule unverified) |
| (ii) Proven safety+liveness under partial synchrony **with dynamic membership** | **5** (published proof, explicit lock/unlock, H+2 activation in the same spec) | **3** (proof exists for a fixed set; reconfiguration text not retrievable) | **3** (Mysticeti proven in production, but 2025 work documents desync attacks on uncertified DAGs; epoch reconfiguration unspecified) | **3** (FFG safety well studied; composition with fork choice is where attacks live) | **3** (abstract claims a simple proof; rule text unverified) |
| (iii) 2-second cadence compatibility | **4** (timeout_commit configurable to 1 s and shorter; no published 2 s measurement at n ≥ 100) | **5** (2-chain + optimistic responsiveness) | **5** (400 ms measured at 106 validators) | **3** (checkpoint epochs; fast only if epoch is short, which stresses the gadget) | **5** (2 rounds) |
| (iv) Minimal protocol modification for Etna | **4** (needs L1 epoch sets + certificate epoch binding; commit rule unchanged) | **3** (same, plus threshold/DKG subsystem to build) | **2** (whole DAG stack plus a zk story that does not exist) | **3** (a new gadget + fork choice to design and prove) | **3** (protocol is small, but nothing exists to modify) |
| (v) Implementer complexity | **4** (mature implementation; integration + zk guest are the work) | **3** (no production HotStuff-2 implementation found; DKG/resharing) | **4** (Sui's implementation is production-grade; but no zk path) | **2** (many moving parts: fork choice, slashing, committees, light client) | **3** (no implementation to reuse) |
| **Total** | **22** | **18** | **16** | **15** | **18** |

### 11.1 Recommendation

**Adopt a Tendermint/CometBFT-style L2 PoS (Family A) as the Mode A baseline**, with three mandatory modifications:

1. **Head-only finality certificate per batch.** The batch's consensus evidence is one commit certificate for the head block H (chain id, epoch, height, round, BlockID, >2/3 signatures) plus header-chain linkage from the batch's first block to H; execution continuity is the zkVM's job. This keeps the consensus witness O(n) signatures per *batch*, not per block, and it is the cheapest certificate of any family surveyed once the DKG cost of Family B is priced in.
2. **L1-authenticated epoch sets.** Epoch = fixed number of L2 blocks; the TAIKO staking contract writes the epoch's set root and total stake to L1; the Inbox compares the guest's public-output set commitment against it. Long-range and set-substitution attacks become contract invariants (§7.4, §8.6).
3. **Contract-level Mode A invariants** (monotonic height, unique block per height, epoch monotonicity, prove-with-data only, Mode B cannot override). These, not the zk proof, are what make "no recovery invalidates a PoS-finalized block" true.

Keep **BLS aggregation as a measured optimization** (the artifact is smaller and the L1 verification is priced at ≈102,900 gas by EIP-2537), and keep **DAG-BFT out of v1** because its finality evidence is structurally expensive to prove and its liveness story is the subject of active 2025 attacks.

### 11.2 The strongest counter-argument (steelman of the runner-up: HotStuff-2 / Jolteon, Family B)

"Tendermint is the wrong shape for n ≥ 100 at 2 s. Its vote phase is O(n²) broadcasts per height and its commit rule needs two full voting rounds every 2 seconds; CometBFT's own defaults (3 s propose timeout, 1 s precommit, 1 s commit) are tuned for ~1 s blocks on permissioned sets, and no one has published a 2 s run at n ≥ 100 with a permissionless, stake-weighted set. HotStuff-2 was *designed* for this: linear communication with a threshold signature, two phases instead of three, and optimistic responsiveness (the leader can commit as soon as it hears from 2f+1 replicas, with no fixed timeout floor). Add Carry-the-Tail (2025) and you also neutralise tail-forking, the dominant practical source of leader-induced stalls. The DKG objection is an implementation cost, not a theoretical one: the validator set is already known per epoch from L1, so a resharing ceremony once per epoch is a bounded engineering task — and if you refuse the DKG, aggregated BLS over individual signatures still gives you a 200-byte certificate with 2 pairings. With a 30-minute proving budget, the only thing that matters is the size and verifiability of the artifact, and HotStuff-2's artifact is 30x smaller than Tendermint's."

**Why it does not win here:** the artifact-size advantage is real but not decisive at these n (6–13 KB vs 200 B is noise next to the batch's execution witness); the DKG/resharing subsystem is a *new* liveness dependency that must itself be L1-authenticated under permissionless staking; and the primary source for HotStuff-2's exact rule and proof is an extended abstract whose full text could not be retrieved or verified in this survey. If a future measurement shows Ed25519 verification dominating the proving budget, this ranking should flip to Family B.

### 11.3 Is Mode A feasible?

**Yes, conditionally [C]:** the L1 contract can enforce irreversible, monotone finalization of certificates whose signer sets are fixed by L1, and the safety of the accepted certificates reduces to the protocol's < 1/3 assumption plus the correctness of the set binding. Mode A does **not** require the zkVM to be cheap (30-minute proofs are fine) and does **not** require new cryptography. The residual risks are economic and operational (stake concentration, set-transition bugs, halt policy), and the unmeasured risk is proving cost (§9.5). Mode B is therefore not needed for safety; it is needed only if the L1-side set transition or the proving pipeline stalls beyond the halt tolerance.

---

## 12. Open questions and where the evidence is thin

1. **CometBFT's exact quorum predicate.** The spec text retrieved defines "1/3+" but never expands "+2/3". Is the commit check strictly greater than 2/3 of voting power, and how is integer voting power summed? The Inbox must match bit-for-bit. Verifier: the release-tag vote/commit verification code (not read here).
2. **Ed25519 vs BLS in the zkVM.** No published cycle counts for Ed25519 verification, BLS12-381 pairing, or aggregate verification in RISC Zero 3.0.6 or SP1 6.8.1. This single measurement decides the certificate format (§9.6).
3. **Is BLS12-381 pairing actually a precompile in RISC Zero?** The docs name "elliptic curve" and "modular multiplication" circuits and ship a patched blst/bls12_381, but never state that the pairing is circuit-accelerated. Needs a kernel-level source read or a benchmark.
4. **HotStuff-2's exact rule and proof.** The ePrint entry is an "Extended Abstract" and its PDF is Cloudflare-protected; the 2-chain predicate, the liveness proof under a faulty leader, and any reconfiguration discussion are unverified.
5. **DiemBFT v4's reconfiguration mechanism.** The technical report is PDF-only in this environment. This is the closest thing to a production answer for chained-BFT set changes and it is exactly the gap that matters for R3/R4.
6. **Mysticeti-C's exact commit predicate.** §III of the paper was truncated by the fetch limit; the NDSS 2025 version should be read before any claim about its certificate content. Also unknown: whether the Starfish/Beluga desynchronization findings are fixed in the currently deployed Sui version (which version?).
7. **No published reconfiguration protocol for DAG-BFT under permissionless staking.** All surveyed DAG papers are per-epoch static; the cross-epoch rule is unspecified.
8. **No 2 s / n ≥ 100 / permissionless measurement for any family.** Every latency number retrieved is from a different setting (Sui mainnet 106 validators; Bullshark 50 parties; default CometBFT config). We need a testnet measurement with the real stake distribution.
9. **Epoch length, churn limit and unbonding delay for TAIKO staking.** These are economic parameters that determine whether the "withdrew but still signing" attack is possible; no source fixes them.
10. **Whether a head-block certificate formally suffices for batch finality.** I argued it does (finalizing H finalizes its ancestors; execution covers the sequence), but a written argument — including what happens if the batch's first block is not an ancestor of H — is missing.
11. **On-chain zk proof verification cost today.** No primary source retrieved for Groth16/PLONK verifier gas on the current Ethereum fork; only the EIP-2537 pairing price is verified.
12. **Whether a 512-validator committee is acceptable for Etna** or whether the full stake-weighted set must be aggregated; this determines whether D1's sampling assumption is imported.
13. **Mode B's exact rules and the test that it cannot override a Mode A finalization** — a code-level invariant that no source can supply.
14. **Vote extensions as a state-root carrier.** The spec says extensions beyond the quorum minimum are not verified; whether an extension is inside the canonical vote sign-bytes (and thus whether a zkVM can trust it) needs the release-tag data-structure and signing code.
15. **CometBFT's O(n²) vote load at 2 s with n = 150–200 in a real, permissionless network.** The analytical estimate (~75 KB egress/validator/block) looks safe, but it ignores gossip inefficiency, block propagation and node churn; unmeasured.

---

## 13. Sources (URL, title, version/date, retrieval date)

All retrieved **2026-10-05** unless noted.

| # | Source | Title | Version / date as printed |
|---|---|---|---|
| 1 | [consensus.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/consensus.md) | CometBFT consensus specification | branch main (unversioned) |
| 2 | [abci++_methods.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_methods.md) | CometBFT ABCI++ methods (ExtendVote/VerifyVoteExtension) | branch main |
| 3 | [abci++_app_requirements.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_app_requirements.md) | CometBFT ABCI++ application requirements (validator updates, H+2) | branch main |
| 4 | [data_structures.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/core/data_structures.md) | CometBFT data structures (Commit, ExtendedCommit, CanonicalVote) | branch main |
| 5 | [proposer-selection.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/proposer-selection.md) | CometBFT proposer selection procedure | branch main |
| 6 | [configuration.md](https://raw.githubusercontent.com/cometbft/cometbft/main/docs/core/configuration.md) | CometBFT configuration (timeouts) | branch main |
| 7 | [releases API](https://api.github.com/repos/cometbft/cometbft/releases?per_page=100) | CometBFT releases | v0.40.0 (2026-07-27), v0.38.26 (2026-08-13), v0.39.4 (2026-07-28), v1.0.1 present |
| 8 | [releases/latest](https://api.github.com/repos/cometbft/cometbft/releases/latest) | CometBFT latest release | v0.40.0, published 2026-07-27 |
| 9 | [arXiv:1803.05069](https://arxiv.org/abs/1803.05069) (text via [ar5iv](https://ar5iv.labs.arxiv.org/html/1803.05069)) | HotStuff: BFT Consensus with Linearity and Responsiveness | arXiv v1 (2018) |
| 10 | [arXiv:2106.10362](https://arxiv.org/abs/2106.10362) (text via [ar5iv](https://ar5iv.labs.arxiv.org/html/2106.10362)) | Jolteon and Ditto: Network-Adaptive Efficient Consensus with Asynchronous Fallback | arXiv:2106.10362 |
| 11 | [ePrint 2023/397](https://eprint.iacr.org/2023/397) | Extended Abstract: HotStuff-2: Optimal Two-Phase Responsive BFT (Malkhi, Nayak) | last revised 2023-04-17; PDF retrieval blocked (403) |
| 12 | [arXiv:2508.12173](https://arxiv.org/abs/2508.12173) | Carry the Tail in Consensus Protocols | arXiv 2025 |
| 13 | [DiemBFT v4 report](https://developers.diem.com/papers/diem-consensus-state-machine-replication-in-the-diem-blockchain/2021-08-17.pdf) | State Machine Replication in the Diem Blockchain | 2021-08-17; **PDF not retrievable here** |
| 14 | [arXiv:2105.11827](https://arxiv.org/abs/2105.11827) | Narwhal and Tusk: A DAG-based Mempool and Efficient BFT Consensus | arXiv v4 |
| 15 | [arXiv:2201.05677](https://arxiv.org/abs/2201.05677) | Bullshark: DAG BFT Protocols Made Practical | arXiv v3 |
| 16 | [arXiv:2102.08325](https://arxiv.org/abs/2102.08325) | DAG-Rider | abstract only retrieved |
| 17 | [arXiv:2405.20488](https://arxiv.org/abs/2405.20488) | Shoal++: High Throughput DAG BFT Can Be Fast! | arXiv v2 |
| 18 | [arXiv:2310.14821v6](https://arxiv.org/abs/2310.14821v6) | Mysticeti: Reaching the Latency Limits with Uncertified DAGs | v6, 24 Nov 2025; NDSS 2025, DOI 10.14722/ndss.2025.240929 |
| 19 | [ePrint 2025/567](https://eprint.iacr.org/2025/567) | Starfish: ... (uncertified DAG liveness, Push pacemaker, Mysticeti-L) | ePrint 2025 |
| 20 | [arXiv:2511.15517](https://arxiv.org/abs/2511.15517) | Beluga: Block Synchronization for BFT Consensus Protocols | arXiv 2025 |
| 21 | [arXiv:2003.03052](https://arxiv.org/abs/2003.03052) | Combining GHOST and Casper (Gasper) | arXiv 2020 |
| 22 | [arXiv:1710.09437](https://arxiv.org/abs/1710.09437) | Casper the Friendly Finality Gadget | arXiv 2017 |
| 23 | [altair/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/altair/beacon-chain.md) | Ethereum consensus specs, Altair (SYNC_COMMITTEE_SIZE = 512) | branch master |
| 24 | [altair light-client sync-protocol.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/altair/light-client/sync-protocol.md) | Ethereum light client sync protocol (update fields, 2/3 check, FastAggregateVerify) | branch master |
| 25 | [phase0/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/beacon-chain.md) | Ethereum consensus specs, Phase0 (BLSPubkey = Bytes48, BLSSignature = Bytes96) | branch master |
| 26 | [ethereum.org weak subjectivity](https://ethereum.org/en/developers/docs/consensus-mechanisms/pos/weak-subjectivity/) | Weak subjectivity | retrieved 2026-10-05 |
| 27 | [IETF BLS draft](https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-bls-signature-05) | draft-irtf-cfrg-bls-signature-05 (aggregation, rogue-key attack, three schemes) | draft -05 |
| 28 | [ePrint 2018/248](https://eprint.iacr.org/2018/248) | Stake-Bleeding Attacks on Proof-of-Stake Blockchains | ePrint 2018 |
| 29 | [ePrint 2023/463](https://eprint.iacr.org/2023/463) | Simplex Consensus: A Simple and Fast Consensus Protocol (Chan, Pass) | ePrint 2023; TCC 2023 |
| 30 | [ACM AFT 2020](https://dl.acm.org/doi/abs/10.1145/3419614.3423256) | Streamlet: Textbook Streamlined Blockchains | DOI 10.1145/3419614.3423256; ePrint 2020/088; **not read** |
| 31 | [EIP-2537](https://eips.ethereum.org/EIPS/eip-2537) | Precompile for BLS12-381 curve operations | **Final**; pairing 32600*k + 37700 gas; G1ADD 375; G2ADD 600 |
| 32 | [EIP-197](https://eips.ethereum.org/EIPS/eip-197) | Precompiled contracts for optimal ate pairing check on alt_bn128 | pairing 80000*k + 100000 gas |
| 33 | [EIP-7951](https://eips.ethereum.org/EIPS/eip-7951) | Precompile for secp256r1 Curve Support | **Final**; P256VERIFY at 0x100, 6900 gas |
| 34 | [RISC Zero precompiles](https://dev.risczero.com/api/zkvm/precompiles) | Precompiles (RISC Zero Developer Docs) | docs "Version: 3.0" |
| 35 | [RISC Zero releases](https://api.github.com/repos/risc0/risc0/releases?per_page=8) | RISC Zero releases | v3.0.6 (2026-07-17); v5.0.0-rc.1 prerelease (2026-01-15); v3.0.1 notes (recursion/Groth16 GPU) |
| 36 | [SP1 precompiles](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles) | Precompiles (Succinct Docs) | docs "current"; patch tags sp1-6.x |
| 37 | [SP1 releases](https://api.github.com/repos/succinctlabs/sp1/releases?per_page=8) | SP1 releases | v6.8.1 (2026-09-24) |
| 38 | [RFC 8032](https://www.rfc-editor.org/rfc/rfc8032.txt) | Edwards-Curve Digital Signature Algorithm (EdDSA) | 32-octet keys, 64-octet signatures |

### 13.1 Source-quality notes (things a careful reader should know)

- Several key papers (DiemBFT v4, HotStuff-2 full text, Simplex, Streamlet) are **PDF-only or paywalled**, and this environment cannot fetch application/pdf. Where a claim depends on them it is marked **[U]**.
- The CometBFT spec files are on branch main and are not versioned with the releases; quotes must be re-checked against the pinned release tag.
- Two search-engine snippets surfaced a Diem 3-chain proof line and a "Simplex 35/25/3.5Δ" comparison table, but snippets are not primary evidence and were deliberately not used as quotes.
- The Nethermind "ZK Gas Benchmark Report 2025-12-29" appeared in search results as a potential source of zkVM cycle/gas numbers, but its page did not render any text through the fetch tool (client-side rendered). It should be read manually; it is a promising source for the §9.6 measurements.
- No benchmark of any protocol at the exact Etna target (2 s blocks, permissionless TAIKO-staked set, zkVM-proven finality) exists in the retrieved sources. Every performance number in this document is attributed to a different context.
