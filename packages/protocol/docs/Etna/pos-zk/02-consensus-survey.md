# Etna PoS + ZK — Phase 2: Consolidated Consensus Survey

**Status:** consolidated deliverable · **Phase:** 2 (parallel research) · **Date:** 2026-10-05
**Baseline pin:** `7718753c1` (branch `etna-pos-zk`) · **Prior Etna research pin:** `a829f79723de9a09205660d9895418577cfe9aa9` (branch `etna/converged-spec`, read-only)
**Consolidated from:** [research/consensus-survey-raw.md](research/consensus-survey-raw.md) — the raw evidence file, read in full. The raw file is **not modified** and is not deleted; it remains the unedited evidence record.
**Retrieval date for every external source:** **2026-10-05**, unless the source itself carries a different date, which is quoted with it.

Related artifacts: [README.md](README.md) · [01-requirements-and-threat-model.md](01-requirements-and-threat-model.md) · [03-zkvm-feasibility.md](03-zkvm-feasibility.md) · [04-architecture-decision.md](04-architecture-decision.md) · [DECISIONS.md](DECISIONS.md) · [research/taiko-baseline-contracts.md](research/taiko-baseline-contracts.md) · [research/recovery-and-withholding-raw.md](research/recovery-and-withholding-raw.md) · [research/mode-a-feasibility-analysis.md](research/mode-a-feasibility-analysis.md) · [research/zkvm-feasibility-raw.md](research/zkvm-feasibility-raw.md) · [research/spec-authoring-contract.md](research/spec-authoring-contract.md) · [spec/index.html](spec/index.html).

This document is **not** the specification. Normative rules live in [spec/index.html](spec/index.html) and its pages; where this survey and the specification disagree, the specification wins and this survey must be corrected. The survey exists to record *why* the architecture recorded in [04-architecture-decision.md](04-architecture-decision.md) was selected, on what evidence, and what would falsify it. It is written to stand alone: every claim that matters carries its source, its version pin and its retrieval date, and every number is tagged.

---

## What a reader should take from this

1. **The recommendation is Tendermint/CometBFT-class BFT (Family A) as the Mode A baseline** — scored 22/25 — with three mandatory modifications: one head certificate per batch, L1-authenticated epoch sets, and Mode A enforced as contract invariants. This is the family selected in [04-architecture-decision.md](04-architecture-decision.md).
2. **Only one finality certificate per batch needs verifying.** Under CometBFT's published safety argument, the head block's certificate plus header-hash linkage extends uniqueness to the whole prefix, so consensus evidence costs are O(n) signatures per *batch*, not per block. This argument is *assumed-with-argument*, not proven here (it is the architecture decision's open item Q-A2).
3. **Ed25519 individual votes are the primary certificate format** because it does not change CometBFT's vote format; **BLS aggregation is a measured optimisation, not a decision**. No published cycle count exists for Ed25519 verification or BLS12-381 pairing in RISC Zero v3.0.6 or SP1 v6.8.1 — the measurement spike in §10.5 is the gate.
4. **DAG-based BFT is the cadence state of the art and the worst fit for in-guest finality verification.** Mysticeti-C's reported production P50 is 400 ms on 106 validators (source #18), but a certified DAG's commit evidence is structurally quadratic (≈4,489 Ed25519 verifications per committed leader at n = 100, derived), and 2025 work (Starfish, Beluga) documents desynchronisation and pull-induction attacks on uncertified DAGs.
5. **The threshold-signature family (HotStuff lineage, runner-up) buys a ~200 B certificate but adds a DKG/resharing subsystem** that must itself be L1-authenticated under permissionless staking, and its reconfiguration mechanism is not retrievable in this environment (DiemBFT v4 is PDF-only).
6. **No measurement exists at the Etna target workload** — 2 s blocks, a permissionless TAIKO-staked set, zkVM-proven finality — for any family. Every latency number quoted here comes from a different deployment context and is labelled as such (class **[2]**, with transfer explicitly denied).
7. **ZK cannot repair a consensus failure.** Under ≥1/3 Byzantine stake two conflicting finality certificates can both be cryptographically valid; the L1 Inbox's invariants (monotone height, one block per height, epoch monotonicity, prove-only-with-data) are what actually make "no recovery invalidates a PoS-finalized block" true (§9.6, [spec/06-recovery-exceptions.html](spec/06-recovery-exceptions.html)).
8. **Weak subjectivity becomes a contract invariant, not a social process.** Because the Inbox lives on L1, its stored checkpoint is objective contract state; the residual requirement is that the unbonding delay exceed the maximum possible lag between a validator's last signature and the settlement of the batch it signed.
9. **Every number is tagged `derived`, `sourced` or `unmeasured`, and every claim carries one of four evidence classes** (§1.1). Published measurements carry version and conditions; hardware is frequently *not stated by the source* and is recorded as such rather than invented.
10. **The three mandatory modifications each invalidate something published.** Head-only certificates need the prefix-uniqueness argument; L1-authenticated epoch sets need a cross-epoch transition safety statement that no surveyed paper provides; contract invariants replace part of what a reader might expect the ZK proof to establish.
11. **CometBFT spec quotes are from branch `main` and are unversioned.** They must be re-checked against a pinned release tag (v0.40.0 was the latest release on 2026-07-27) before any of them becomes a normative rule; the strict-versus-non-strict quorum comparison is explicitly unresolved (§4.3).
12. **Four source classes are quarantined** and must not be cited: two search-engine snippets (a Diem 3-chain proof line; a "Simplex 35/25/3.5Δ" table), arXiv `2002.02798` (mis-identified as Streamlet; it is an unrelated paper), and the Nethermind ZK Gas Benchmark Report 2025-12-29 (did not render; not evidence until read manually). See §13.3.

---

## 1. How to read this document

### 1.1 The four evidence classes

Every material statement is classified as exactly one of four classes, in the order required by [spec/index.html](spec/index.html) rule `GEN-08` and by the [spec authoring contract](research/spec-authoring-contract.md) §4. The two middle classes are *never* merged: a published benchmark is not an analytical estimate, and an analytical estimate is not a measurement.

| Class | Label | Meaning |
|---|---|---|
| **[1]** | Compatibility in principle | A property that follows from a protocol's stated rules (quoted from a primary source) applied to the Etna context. It is an argument, not a measurement. |
| **[2]** | Published implementation / benchmark evidence | A number or behaviour reported by a named implementation version or paper, with the URL. Must state version, conditions (and hardware where the source states it) and whether it transfers to this workload. It does not. |
| **[3]** | Analytical estimate | A calculation from verified protocol parameters. No measurement. Reproducible from the inputs shown. Tagged `derived`. |
| **[4]** | Unmeasured implementation question | Cannot be established from the retrieved sources. What would verify it is stated. Carries the **UNVERIFIED** marker where the source marked it. |

For traceability with the raw evidence file, the raw tags map as: `[C] → [1]`, `[I] → [2]`, `[A] → [3]`, `[U] → [4]`. Where the raw file used a compound tag such as `[C] + [Z1][Z3]`, both classes are shown here.

### 1.2 Number tags

- **`sourced`** — a number printed by a named external source, with the source's own conditions. Every `sourced` number in this document is a class **[2]** claim.
- **`derived`** — a number computed here from stated inputs. Class **[3]**. The formula is always shown.
- **`unmeasured`** — a parameter or cost with no evidence at all. Class **[4]**.

No number in this document is a measurement by us. [README.md](README.md): "No number in this directory is a measurement unless it is explicitly labelled as one with a source."

### 1.3 The UNVERIFIED marker

Where the source recorded that a claim could not be checked against its primary text, the marker **[4] UNVERIFIED** is kept, together with **what would verify it**. The recurring cases are: DiemBFT v4 (PDF not retrievable in the survey environment), HotStuff-2 full text (extended abstract only; PDF blocked by Cloudflare 403), Simplex (PDF-only), DAG-Rider rule text (abstract only), Mysticeti §III commit predicate (fetch truncated), Streamlet (primary text not read), and CometBFT line-by-line agreement with a release tag (spec files are branch-tip).

### 1.4 Citation rules applied here

Every external citation carries: the source URL as a markdown link, the version / commit / branch pin as printed by the source, and the retrieval date **2026-10-05**. Nothing is "cleaned up": a URL quoted on branch `main` stays a branch URL and is flagged as unversioned; a release number printed on 2026-07-27 stays that number. The consolidated source table is §14.

### 1.5 Where a claim is normative

This survey does not state normative rules. Where a survey conclusion has become a normative rule, the rule id in the specification is cited, e.g. [CONS-03 quorum](spec/02-consensus.html#CONS-03), [CONS-04 lock rule](spec/02-consensus.html#CONS-04), [CONS-05 commit rule](spec/02-consensus.html#CONS-05), [CONS-08 epoch-scoped certificates](spec/02-consensus.html#CONS-08), [CONS-11 equivocation evidence](spec/02-consensus.html#CONS-11), [MEM-01 staking custody](spec/03-membership-staking.html#MEM-01), [L1-01 atomic data+proof](spec/04-l1-integration.html#L1-01), [PRF-03 L1-authenticated set](spec/05-proof-statement.html#PRF-03), [HALT-01 safe halt](spec/06-recovery-exceptions.html#HALT-01).

### 1.6 How the eleven attributes are covered

The brief lists eleven attributes but separates safety from liveness and (in the raw file's table) merges quorum with lock and commit. To make coverage explicit and comparable, every candidate below is presented with **twelve numbered rows** plus a thirteenth row for modification risk:

| Row | Attribute |
|---|---|
| 1 | Safety assumptions |
| 2 | Liveness assumptions |
| 3 | Voting power and quorum thresholds |
| 4 | Locking and unlocking rules |
| 5 | Finality / commit rule, quoted precisely |
| 6 | Equivocation, partition, selective delivery and withheld certificates |
| 7 | Leader change and stalled-round recovery |
| 8 | Dynamic membership and validator-set transitions, including how an old certificate is judged later |
| 9 | Communication, execution, storage and bandwidth costs as functions of n, with formulas |
| 10 | Block cadence and finality latency, with the evidence class of every number |
| 11 | What an external verifier must check, and what cannot be established from public certificates alone |
| 12 | Suitability for verification inside RISC Zero and SP1 |
| 13 | Modification risk (the raw file's eleventh attribute; analysed in §11) |

The eleven attributes are therefore covered by rows 1–12; row 13 is retained because the raw survey used it and because it feeds §11.

---

## 2. Fixed target context and derived requirements

### 2.1 The target is fixed and is not re-litigated

From [01-requirements-and-threat-model.md](01-requirements-and-threat-model.md) §1 (fixed decisions D1–D7):

- Ethereum L2 whose transaction order is determined by **permissionless L2 PoS validators** (no strict L1/based sequencing); the result is named a **PoS-sequenced validity rollup**, never a "based rollup" (`GEN-09`).
- **One L2 block every 2 s** (D1). Cadence ≠ finality ≠ proof ≠ settlement.
- Finalized L2 history is settled on L1 by an **Inbox** contract that accepts a batch **only if the batch data and a zkVM validity proof land in the same L1 transaction** (D5). No data-first / proof-later path in any mode.
- The proof must authenticate **(a)** the PoS consensus evidence making the batch's head block final and **(b)** correct EVM execution of the batch. Proving latency of minutes to 30 minutes is normal (D6); 30 min = 900 L2 blocks.
- Validators are **permissionless** and stake the **existing TAIKO ERC-20** (D7), whose L1 token contract already exists at [TaikoToken.sol](../../../contracts/layer1/mainnet/TaikoToken.sol).
- The validator set must ultimately be **authenticated from L1**; a prover-supplied witness must never define its own authoritative set.
- **Mode A** (safety-first): no recovery path may invalidate a legitimately PoS-finalized block; a safe halt is acceptable. **Mode B** (permissionless L1 recovery of *unsettled* history) exists but is not preferred.
- Weak subjectivity / long-range attacks must be analysed honestly.
- The preconf **URC** is not a building block.

### 2.2 What the consensus layer must expose (R1–R10)

| # | Requirement | Why it follows |
|---|---|---|
| R1 | A **finality certificate** that is a self-contained, bounded-size object for a head block | It must ride in an L1 transaction with the batch data |
| R2 | Certificate verification cheap in a zkVM guest (bounded signature verifications, bounded hashing) | Requirement (a) of the proof obligation |
| R3 | An explicit **epoch / validator-set binding** inside the certificate | The L1 contract, not the prover, must decide which set counts |
| R4 | A rule for **how a certificate from an older set is judged later** | Permissionless staking means the set changes continuously |
| R5 | Safety under **partial synchrony** with an explicit fault threshold, plus a story for threshold violation (safe halt / Mode B) | Mode A |
| R6 | A **locking/commit rule** such that a certificate that is never published cannot later invalidate a decision already taken | The L1 Inbox decides irreversibly |
| R7 | Liveness without a specific correct leader forever, with bounded recovery from a stalled round | 2 s cadence and permissionless participation |
| R8 | Cost model as a function of n (messages, bytes, signature verifications) | n is a design variable (TAIKO stake distribution) |
| R9 | Behaviour under equivocation, partition, selective delivery, and equivocation visibility | Slashing/accountability and Mode B triggers |
| R10 | Honest separation of measured vs estimated cadence and latency | No fabricated benchmarks |

**Repository grounding.** The existing L1 entry points are [Inbox.sol `propose(...)` at line 270](../../../contracts/layer1/core/impl/Inbox.sol#L270) and [`prove(...)` at line 321](../../../contracts/layer1/core/impl/Inbox.sol#L321), plus the [`IProofVerifier` abstraction (import at line 17, immutable at line 72)](../../../contracts/layer1/core/impl/Inbox.sol#L17). The target design removes the data-first/proof-later split for Mode A; the `propose` path is exactly the path that must not be able to finalize. The baseline research records the observed cost of that design: `init3()` (Inbox.sol:246-258) is a one-time owner function that voided forced inclusions whose blob references expired from the retention window after the June 2026 incident, and Inbox.sol:601-603 records that permissionless proposing is temporarily disabled ([research/taiko-baseline-contracts.md](research/taiko-baseline-contracts.md), [04-architecture-decision.md](04-architecture-decision.md) §4).

---

## 3. Candidate set

| Family | Instances surveyed | Why it is materially different / why included |
|---|---|---|
| **A** | Tendermint / CometBFT (spec at branch `main`; releases up to v0.40.0 and v1.0.1) | Highest-maturity partial-synchrony BFT with per-validator signatures (no DKG) and an explicit lock/unlock rule; large production base; the polling/vote structure produces a natural small finality certificate |
| **B** | HotStuff, DiemBFT v4, Jolteon/Ditto, HotStuff-2, Carry-the-Tail (2025) | The linear-communication lineage; threshold-signature QCs make certificates tiny; HotStuff-2 removes the third phase |
| **C** | DAG-Rider, Narwhal/Tusk, Bullshark, Shoal++, Mysticeti/Mysticeti-FPC, Starfish (2025), Beluga (2025) | Latency/throughput state of the art, in production (Sui); included mainly to test whether their finality evidence is zk-provable |
| **D1** | Casper FFG + LMD-GHOST (Gasper) style checkpoint attestations with BLS aggregates | The materially different design: finality evidence is one aggregate signature + a bitmap, verified with 2 pairings; the Ethereum light-client protocol is a fully specified instance of exactly this artifact shape |
| **D2** | Simplex (Chan & Pass, TCC 2023) | Deliberately minimal 2-chain protocol with a bare PKI, no threshold setup; a plausible "smallest protocol that satisfies R6/R7" baseline |
| **D3** | Streamlet (Chan & Shi, AFT 2020) | Simplicity baseline; **not deep-dived** — the primary text was not retrieved in this session (§7.3) |

**Rejected as building blocks, before ranking:** the preconf URC (per the brief), and any design in which the prover supplies the validator set (violates the L1-authentication requirement, R3). Both rejections are restated in [04-architecture-decision.md](04-architecture-decision.md) §8.

---

## 4. Family A — Tendermint / CometBFT

### 4.0 Version anchors (retrieved 2026-10-05)

| Item | Value | Source |
|---|---|---|
| Latest GitHub release | **v0.40.0**, published 2026-07-27 | [cometbft/cometbft releases/latest](https://api.github.com/repos/cometbft/cometbft/releases/latest) |
| Newest by publication date in the last 100 releases | **v0.38.26**, 2026-08-13 | [releases list](https://api.github.com/repos/cometbft/cometbft/releases?per_page=100) |
| Other active lines | v0.39.4 (2026-07-28); v1.0.1 present in the last 100 releases | same |
| Spec text quoted | `spec/consensus/consensus.md`, `spec/abci/abci++_*.md`, `spec/core/data_structures.md` on branch `main` — **unversioned; verify against the release tag before relying on a quote** | [consensus.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/consensus.md), [abci++_methods.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_methods.md), [abci++_app_requirements.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_app_requirements.md), [data_structures.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/core/data_structures.md) |
| Config defaults quoted | [configuration.md](https://raw.githubusercontent.com/cometbft/cometbft/main/docs/core/configuration.md), branch `main` | same caveat |

**Provenance warning (class [4]).** CometBFT maintains **four release lines at once** (v0.37.x, v0.38.x LTS, v0.39.x, v0.40.x) plus v1.0.1. Any integration must pin one exact line and re-verify every spec quote against that tag; the files above are branch-tip. Line-by-line agreement with v0.40.0 is **UNVERIFIED**.

### 4.1 The eleven attributes (rows 1–12, plus modification risk)

| # | Attribute | Finding | Class |
|---|---|---|---|
| 1 | Safety assumptions | Byzantine voting power **< 1/3**; quorum **> 2/3** of voting power for prevote-PoLC and for commit. Safety holds under **asynchrony**. Published *Proof of Safety* quoted in §4.2. | [1] |
| 2 | Liveness assumptions | **Partial synchrony**: eventual GST plus bounded delay; a correct proposer in some round after GST. No leader is needed forever. Published *Proof of Liveness* quoted in §4.2. | [1] |
| 3 | Voting power and quorum thresholds | Stake-weighted (CometBFT: voting power) with strict **> 2/3** for PoLC and commit in the implementation; the fetched spec text does not expand "+2/3" (see §4.3, class [4]). | [1] + [4] on strictness |
| 4 | Locking and unlocking rules | Lock on a PoLC in the precommit step; unlock only via a later-round PoLC. Verbatim rules in §4.2. | [1] |
| 5 | Finality / commit rule | "After +2/3 precommits for a particular block. --> goto Commit(H)" ([consensus.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/consensus.md)). | [1] |
| 6 | Equivocation, partition, selective delivery, withheld certificates | Safety argument: 2/3 precommits at round R implies 1/3+ honest nodes still locked at R; a conflicting PoLC later would need 2/3 prevotes for something else, but at most 2/3 are available (the spec's own words). A **withheld certificate cannot invalidate** a decision, because finality is defined by the 2/3 precommit set, not by publication. Partition: safety preserved, liveness lost. Selective delivery is the adversary model of the safety proof. | [1] |
| 7 | Leader change and stalled-round recovery | Round-based; new round after timeouts (timeout_propose 3 s + 500 ms/round; prevote/precommit 1 s + 500 ms/round). A proposal may carry a **PoLC-Round** so locked validators can unlock. Proposer chosen deterministically per round; a correct proposer is required in some round after GST. Message complexity per round: 2 votes × n broadcasters → O(n²) transmissions. | [1] |
| 8 | Dynamic membership and old certificates | The application sets validator updates during FinalizeBlock; updates **take effect at H+2** (quoted in §4.6). There is **no in-protocol epoch concept** and **no in-protocol cap** on voting-power change per height; that discipline lives in the application (for Etna: the L1 staking/epoch contract). An old certificate is judged under the set of its own height; for Etna this must become the set of its declared epoch (§11.1, M2). | [1] |
| 9 | Costs as functions of n | Per height: 2·n·(n−1) vote transmissions, 2·n·(n−1)·(vote size) bytes global, 2·(n−1)·(vote size) bytes per-validator egress, 2·(n−1) signature verifications per validator. Full table with n = 100/150/200 in §4.5. Certificate ≈ s·(20 B address + 64 B signature) + overhead, s ≥ 2f+1. | [3] |
| 10 | Cadence and finality latency | Config defaults timeout_propose 3 s, timeout_prevote 1 s, timeout_precommit 1 s, timeout_commit 1 s; the config doc states blocks are produced "~ every second (with default consensus parameters)". **No published measurement at 2 s with a named n and hardware was retrieved.** | [2] for defaults, **[4]** for measurements |
| 11 | External verifier | Must check: one signature per signer over canonical vote bytes, epoch-set membership and weight, weighted quorum, signed BlockID = head block hash, optional header-chain linkage from batch start to H. Cannot establish: data availability, off-chain safety, equivocation visibility, liveness; fork accountability needs **JSets** (all votes plus justifying PoLCs), not the commit alone. Detail in §9. | [1] |
| 12 | zkVM suitability (RISC Zero / SP1) | Ed25519 is accelerated in both zkVMs through patched `curve25519-dalek` crates. Witness ≈ (64 B signature + 32 B public key, or 20 B address) × signers. No DKG; no pairing required if Ed25519 is used. Published cycle counts: **none found**. | [1] + [4] |
| 13 | Modification risk | Replacing individual signatures with a BLS aggregate changes accountability and the applicable proof (§11). Changing the commit rule invalidates the lock/unlock safety proof quoted in §4.2. | [3] |

### 4.2 The rules, quoted (primary source)

From the CometBFT consensus spec ([consensus.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/consensus.md), branch `main`, retrieved 2026-10-05; source #1):

- Quorum vocabulary: *"A set of +2/3 of prevotes for a particular block or nil at (H,R) is called a **proof-of-lock-change** or PoLC for short."*
- Unlock rule (Prevote step): *"First, if the validator is locked on a block since LastLockRound but now has a PoLC for something else at round PoLC-Round where LastLockRound < PoLC-Round < R, then it unlocks."*
- Lock rule (Precommit step): *"If the validator has a PoLC at (H,R) for a particular block B, it (re)locks (or changes lock to) and precommits B and sets LastLockRound = R."* / *"Else, if the validator has a PoLC at (H,R) for nil, it unlocks and precommits nil."* / *"Else, it keeps the lock unchanged and precommits nil."*
- Commit rule: *"After +2/3 precommits for a particular block. --> goto Commit(H)"*.
- Proof of Safety: *"Assume that at most -1/3 of the voting power of validators is byzantine. If a validator commits block B at round R, it's because it saw +2/3 of precommits at round R. This implies that 1/3+ of honest nodes are still locked at round R' > R. These locked validators will remain locked until they see a PoLC at R' > R, but this won't happen because 1/3+ are locked and honest, so at most -2/3 are available to vote for anything other than B."* — the hyphenated `-1/3` / `-2/3` are **typos in the spec** for "less than 1/3" / "less than 2/3"; kept verbatim rather than silently corrected.
- Proof of Liveness: *"If 1/3+ honest validators are locked on two different blocks from different rounds, a proposers' PoLC-Round will eventually cause nodes locked from the earlier round to unlock. Eventually, the designated proposer will be one that is aware of a PoLC at the later round."*
- Fork accountability: *"Define the JSet (justification-vote-set) at height H of a validator V1 to be all the votes signed by the validator at H along with justification PoLC prevotes for each lock change."*

These four rules are the basis of the normative rules [CONS-04 lock rule](spec/02-consensus.html#CONS-04), [CONS-05 commit rule](spec/02-consensus.html#CONS-05) and [CONS-11 equivocation evidence](spec/02-consensus.html#CONS-11).

### 4.3 The quorum-comparison boundary — UNVERIFIED

**[4] UNVERIFIED.** The fetched spec text defines "1/3+" as "1/3 or more" but does **not** expand "+2/3" into a comparison. The implementation commits on **strictly more than 2/3** of voting power (equivalently 2f+1 of n = 3f+1 with equal power). The Inbox must encode the comparison exactly as the implementation does — strict vs non-strict, and the voting-power arithmetic — otherwise a certificate accepted by the chain may be rejected by L1 or vice versa. **What would verify it:** read the release-tag vote/commit verification code (not done in the survey). The normative specification states the threshold as *≥ 2/3 of epoch voting power* ([CONS-03](spec/02-consensus.html#CONS-03)); the survey flags that this must be reconciled with the implementation's exact predicate before the certificate format is frozen. This is open question OQ-2.

### 4.4 Vote extensions (ABCI++) — the one place arbitrary data can ride a precommit

From [abci++_methods.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_methods.md) and [data_structures.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/core/data_structures.md) (branch `main`, retrieved 2026-10-05; sources #2, #4):

- ExtendVote is called when a validator is about to precommit a **non-nil** block, after it sets `lockedValue`/`validValue`; the application returns bytes that the consensus engine attaches to the precommit.
- Extended commit fields, verbatim: *"Extension | bytes | Vote extension provided by the Application ... Length must be zero if BlockIDFlag is not Commit"*; *"ExtensionSignature | Signature | Signature of the vote extension. Must be valid for the validator public key type if BlockIDFlag is Commit"*; plus a NonRpExtension (*"non replay-protected vote extension ... signed by CometBFT and attached to the Precommit message. No replay-protection is applied to the data"*).
- Spec warning relevant to any design that reads extensions: *"extensions of votes included in the commit info after the minimum of +2/3 had been reached are not verified"* (the application verifies each received extension, but only those that mattered for reaching the quorum are guaranteed to have been checked by the receiver in the normal flow).

**Consequence for Etna [1]:** a CometBFT-style precommit can carry an application-chosen payload signed with the validator's consensus key, and that payload lands in the ExtendedCommit a zkVM could consume. It is a real mechanism but **not needed** for the certificate described in §4.7 — the state root can be part of the block header/execution proof instead. Using it adds a non-determinism surface (extension verification is application-defined and partly skipped) and should be an optional optimisation, never load-bearing (§11.2, row "Use CometBFT vote extensions").

### 4.5 Cost model (analytical, n = validator count)

Inputs: each height has 2 vote messages per validator; a CometBFT vote carries validator address (20 B), block ID (hash 32 B + parts hash 32 B), height, round, timestamp, signature (64 B Ed25519) — call it **~180–300 B** on the wire depending on encoding and extensions. All values below are **[3] derived** from these inputs.

| Quantity | Formula | n = 100 | n = 150 | n = 200 |
|---|---|---|---|---|
| Vote transmissions per height (global) | 2·n·(n−1) | 19,800 | 44,700 | 79,600 |
| Vote bytes per height (global, at 250 B) | 2·n·(n−1)·250 B | ~5.0 MB | ~11.2 MB | ~19.9 MB |
| Per-validator egress per height | 2·(n−1)·250 B | ~49.5 KB | ~74.5 KB | ~99.5 KB |
| Signature verifications per validator per height | 2·(n−1) | 198 | 298 | 398 |
| Signature verifications per validator per second at 2 s blocks | (2·(n−1))/2 | ~99/s | ~149/s | ~199/s |
| Certificate size (one commit, >2/3 signers ≈ 0.67n) | signers × (20 B address + 64 B signature) + overhead | ~5.7 KB | ~8.5 KB | ~11.4 KB |

At the 2 s target these are modest single-node loads **[3]**; the binding constraints are (i) the L1-authenticated epoch set and (ii) zkVM signature verification (§10). Block propagation (the actual transactions) is additional and dominates bytes for large blocks. **[3]**

### 4.6 Dynamic membership in CometBFT — what has to be replaced for Etna

- Spec: *"Note the updates returned after processing the block at height H will only take effect at block H+2"* ([abci++_app_requirements.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_app_requirements.md), branch `main`, retrieved 2026-10-05; source #3).
- The spec parameterizes validator pubkey types (*"ValidatorParams.PubKeyTypes ... restricts the type of keys validators can use"*) but the retrieved section does not enumerate defaults. **[4] UNVERIFIED** — verify the Ed25519 default against the release-tag code before relying on zkVM cost estimates. **What would verify it:** the release-tag consensus params/defaults source.

For Etna the CometBFT-native update path is the **wrong primitive**: it lets the L2 application decide the next set, while R3 requires L1 to decide. The design must instead **quantize** membership into epochs whose set (pubkeys + stake weights) is computed by the **L1 staking contract** and committed to the Inbox (a set hash per epoch). The consensus engine then receives an "update to exactly this set" instruction, not a discretionary update. **Proof consequence [1]:** CometBFT's H+2 rule and its safety proof are agnostic to *how* the set was chosen, so the published safety argument still applies per height **as long as the certificate names the epoch/set it was signed under and the verifier checks that binding**. That last clause is the new obligation (§11).

### 4.7 What the L1 Inbox / zkVM guest must check (Family A)

Minimal public inputs: chain id, epoch id, validator-set commitment (root or hash), head block height H, block hash (or BlockID: block hash + parts hash), round, and the batch/state-root commitments. The full public-input contract is §9.1.

Witness and checks **[1]**:

1. For each signer: validator address/index, signature over the canonical vote bytes (type, height, round, block ID, timestamp, chain id).
2. Membership + weight: the signer must be in the epoch set with the weight recorded there (Merkle/SSZ proof, or a set supplied in-witness whose computed root is a public output the contract compares against L1 storage).
3. Quorum: sum of signing weight exceeds the threshold — exact comparison TBD, see §4.3.
4. Block binding: the signed BlockID equals the hash of the head block whose state root the execution proof produces.
5. Optional: verify the header chain from the batch's first block to H (hash linkage), while **only H's commit needs a signature quorum** — finality of H implies its ancestors by the protocol's own safety property, and the execution proof covers the state transitions. **[1]** This is what makes the certificate O(n) signatures **per batch**, not per block. It is the argument carried into [04-architecture-decision.md](04-architecture-decision.md) §2 and reviewed as Q-A2.

### 4.8 zkVM notes for Family A

- Ed25519 verification is accelerated in both zkVMs through patched `curve25519-dalek` crates ([RISC Zero precompiles](https://dev.risczero.com/api/zkvm/precompiles): *"curve25519-dalek 4.1.3, 4.1.2, 4.1.1, 4.1.0"*; [SP1 precompiles](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles): *"curve25519-dalek ... 4.1.3"*, *"curve25519-dalek-ng ... 4.1.1"*). Sources #34, #36.
- **Published cycle counts for Ed25519 verification in either zkVM were not found** on the official pages retrieved. **[4] UNVERIFIED** — measure before sizing batches. **What would verify it:** the measurement spike in §10.5.

---

## 5. Family B — HotStuff lineage (HotStuff, DiemBFT v4, Jolteon/Ditto, HotStuff-2, Carry-the-Tail)

### 5.0 Version anchors and retrieval limits (retrieved 2026-10-05)

| Instance | Primary source | Retrieval status |
|---|---|---|
| HotStuff | [arXiv:1803.05069](https://arxiv.org/abs/1803.05069), text read via [ar5iv](https://ar5iv.labs.arxiv.org/html/1803.05069) | Read. The original chained, threshold-signature protocol. |
| DiemBFT v4 | [Diem technical report, 2021-08-17](https://developers.diem.com/papers/diem-consensus-state-machine-replication-in-the-diem-blockchain/2021-08-17.pdf) | **PDF only; not retrievable with the tools available in the survey session.** All DiemBFT v4 statements are **[4] UNVERIFIED** unless corroborated by Jolteon/Ditto. What would verify it: reading the PDF manually. |
| Jolteon / Ditto | [arXiv:2106.10362](https://arxiv.org/abs/2106.10362), text read via ar5iv | Read. Peer-reviewed description of DiemBFT as 3-chain HotStuff; introduces a 2-chain variant and an asynchronous fallback. |
| HotStuff-2 | [IACR ePrint 2023/397](https://eprint.iacr.org/2023/397) | Abstract page retrieved; **PDF fetch blocked by Cloudflare 403**. Details are **[4] UNVERIFIED**. The entry is an "Extended Abstract ... two-phase commit regime within a view, and optimistic responsiveness", last revised 2023-04-17. |
| Carry-the-Tail | [arXiv:2508.12173](https://arxiv.org/abs/2508.12173) | Abstract retrieved. 2025 "drop-in mechanism for streamlined protocols in the HotStuff family" against tail-forking. |

### 5.1 The eleven attributes

| # | Attribute | Finding | Class |
|---|---|---|---|
| 1 | Safety assumptions | Fixed committee n = 3f+1, up to f Byzantine; safety always (under asynchrony). HotStuff-2 adds optimistic responsiveness. | [1] for HotStuff/Jolteon; [4] for HotStuff-2 details |
| 2 | Liveness assumptions | Partial synchrony: after GST, a correct leader in some view (pacemaker); HotStuff-2 claims optimistic responsiveness (commit as soon as the leader hears from 2f+1 replicas). | [1] / [4] for HotStuff-2 |
| 3 | Voting power and quorum thresholds | Fixed committee, equal-weight replicas in the papers: n = 3f+1, threshold **k = 2f+1**; QCs are (k,n)-threshold signatures over the block. | [1] |
| 4 | Locking and unlocking rules | A replica locks on the precommitQC: *"a replica becomes locked on the precommitQC at this point by setting its lockedQC to precommitQC"*. The new-view message carries the highest QC; the leader must extend the highest locked QC it can prove. HotStuff-2 replaces the three phases with two within a view. | [1] / [4] for HotStuff-2 |
| 5 | Finality / commit rule | HotStuff: *"it combines them into a commitQC. Once the leader has assembled a commitQC, it sends it in a decide message to all other replicas."* Jolteon/DiemBFT is a 2-chain rule; HotStuff-2 a two-phase regime. Exact predicates for HotStuff-2 are **[4] UNVERIFIED** (full paper not retrievable). | [1] / [4] |
| 6 | Equivocation, partition, selective delivery, withheld certificates | A withheld QC cannot invalidate a decision: safety is the standard quorum-intersection argument over 2f+1 of 3f+1. Leader equivocation is handled by the pacemaker (view change), **not** by slashing evidence inside the QC. A QC does **not** reveal which replicas signed (threshold signature), so accountability is weaker than Tendermint's per-validator votes. | [1] |
| 7 | Leader change and stalled-round recovery | New-view message carrying the highest QC; with threshold signatures this is O(n) messages. Jolteon deliberately trades this for a quadratic pacemaker: *"quadratic view-change (O(n) messages of O(n) size)"*. No correct leader is needed for safety; liveness after GST needs a correct leader in some view. | [1] |
| 8 | Dynamic membership and old certificates | HotStuff assumes a **fixed** set. DiemBFT/epoch reconfiguration is the natural place to look, but the primary text was not retrievable. **This is the weakest attribute of family B for Etna.** No surveyed source fixes how a superseded-epoch QC is judged later. | **[4] UNVERIFIED** |
| 9 | Costs as functions of n | Threshold-signature QC: leader ↔ replicas, **O(n) messages per view**, O(n²) worst case across timeouts. Certificate (QC) size: one threshold signature + identifiers (~200 B, §9.4). | [1] / [3] |
| 10 | Cadence and finality latency | Jolteon: 2-chain rule *"reducing the steady state block-commit latency by 30%"*. The paper implements and evaluates its systems, but absolute latency numbers at a named n/hardware were not extracted. | [2] relative only; **[4]** absolute |
| 11 | External verifier | QC = (view, block hash, threshold signature) + epoch/set binding. Cost: **1 threshold-signature verification** (2 BLS12-381 pairings) + set/epoch binding. Fallback if individual signatures are aggregated with a bitmap: n signature verifications. Cannot show: data availability, liveness, **who signed**, or any equivocation evidence. | [1] |
| 12 | zkVM suitability | Threshold BLS = 1 signature + 1 pubkey (96 B + 48 B per the Ethereum BLS container sizes) but requires a **DKG / trusted dealer and resharing** as the set changes — awkward under permissionless staking. Aggregate BLS over individual signatures avoids the DKG but needs proof-of-possession registration (D1). No published cycle costs for either path. | [1] + [4] |
| 13 | Modification risk | Swapping the threshold signature for an aggregate changes accountability and the dealer assumptions; changing 3-chain to 2-chain removes the third-phase safety argument (Jolteon pays a quadratic view change for it). Pipelining requires restating the pacing/liveness argument. | [3] |

### 5.2 Instance-level differences

| Instance | Commit shape | View change | Reconfiguration | Notes |
|---|---|---|---|---|
| **HotStuff** (arXiv:1803.05069) | 3 phases in a view; decide on commitQC | Pacemaker; new-view carries highest QC | Fixed set only | *"Throughout this paper, we use a threshold of k = 2f+1"* |
| **DiemBFT v4** (2021-08-17 report) | 3-chain HotStuff as described by Jolteon | Quadratic pacemaker | **Not retrieved** — the mechanism that matters most for R3/R4 is exactly this gap | **[4] UNVERIFIED** |
| **Jolteon / Ditto** (arXiv:2106.10362) | Jolteon: 2-chain; Ditto adds asynchronous fallback | Jolteon: quadratic view change, O(n) messages of O(n) size; Ditto replaces the pacemaker with an asynchronous fallback | Epoch reconfiguration not specified in the retrieved text | Quantifies the latency/vs-view-change trade |
| **HotStuff-2** (ePrint 2023/397) | Two phases inside a view; *"The main takeaway is that two phases are enough for BFT after all."* | Optimistic responsiveness claimed | Not retrieved | Exact predicate and proof **[4] UNVERIFIED** |
| **Carry-the-Tail** (arXiv:2508.12173) | Drop-in mechanism, not a new protocol | Addresses tail-forking after GST | Not addressed | *"maintains optimal, worst-case quadratic communication under a cascade of faulty leaders"* |

### 5.3 Rules, quoted

- HotStuff ([arXiv:1803.05069](https://arxiv.org/abs/1803.05069), via ar5iv, retrieved 2026-10-05; source #9): *"We consider a system consisting of a fixed set of n = 3f+1"*; *"HotStuff makes use of threshold signatures"*; *"In a (k,n)-threshold signature scheme, there is a single public key ... Throughout this paper, we use a threshold of k = 2f+1."*
- HotStuff locking/commit: *"it combines them into a precommitQC and broadcasts it"*; *"a replica becomes locked on the precommitQC at this point by setting its lockedQC to precommitQC"*; *"it combines them into a commitQC. Once the leader has assembled a commitQC, it sends it in a decide message to all other replicas."*
- HotStuff pacemaker: *"The mechanisms needed to achieve liveness are encapsulated within a Pacemaker, cleanly separated from the mechanisms needed for safety."*
- Jolteon ([arXiv:2106.10362](https://arxiv.org/abs/2106.10362); source #10): *"we design a 2-chain version of HotStuff, Jolteon, which leverages a quadratic view-change mechanism to reduce the latency of the standard 3-chain HotStuff"*; *"Jolteon preserves the structure of HotStuff and its linearity under good network conditions while reducing the steady state block-commit latency by 30% using a 2-chain commit rule. This decrease in latency comes at the cost of a quadratic view-change (O(n) messages of O(n) size)."*
- Ditto: *"Ditto replaces the pacemaker of HotStuff/DiemBFT (a quadratic module that deals with view synchronization) with an asynchronous fallback."*
- HotStuff-2 ([ePrint 2023/397](https://eprint.iacr.org/2023/397); source #11): *"it is possible to solve partially-synchronous BFT and simultaneously achieves O(n^2) worst-case communication, optimistically linear communication, a two-phase commit regime within a view, and optimistic responsiveness"*; *"The main takeaway is that two phases are enough for BFT after all."* **[4] UNVERIFIED:** the exact 2-chain commit predicate and the safety proof are in the full paper, which was not retrievable (PDF). Anyone modifying or implementing it must obtain the PDF and re-derive.
- Carry-the-Tail ([arXiv:2508.12173](https://arxiv.org/abs/2508.12173); source #12): *"the first deterministic atomic broadcast protocol in partial synchrony that, after GST, guarantees a constant fraction of commits by non-faulty leaders against tail-forking attacks, and maintains optimal, worst-case quadratic communication under a cascade of faulty leaders"*; it is *"a practical drop-in mechanism for streamlined protocols in the HotStuff family"*.

### 5.4 Assessment for Etna

**Strengths [1]:** linear communication with threshold signatures; very small QCs; HotStuff-2's two-phase rule and optimistic responsiveness; an active 2024–2026 line of work (Carry-the-Tail) addressing the exact failure mode — tail-forking / leader-induced stalls — that a 2 s cadence makes painful.

**Weaknesses:**

1. **Threshold trust setup.** A (2f+1, n) threshold key must be generated and reshared as the permissionless set changes. Under L1-authenticated, staking-weighted membership this is a substantial subsystem, and a resharing failure is a halt (acceptable under Mode A) or a safety risk if done wrong. **[1]**
2. **Reconfiguration evidence gap.** The retrieved primary sources do not specify epoch reconfiguration; DiemBFT v4's mechanism is behind an unfetchable PDF. For a design whose R3/R4 are the crux, this is the decisive practical gap. **[4]**
3. **Accountability.** A threshold QC hides the signer set; slashing/evidence (Mode B triggers) needs extra data that is not part of the QC by default. **[1]**

---

## 6. Family C — DAG-based BFT

### 6.0 Version anchors and fetch limitation (retrieved 2026-10-05)

| Instance | Source | Key verified facts / retrieval status |
|---|---|---|
| DAG-Rider | [arXiv:2102.08325](https://arxiv.org/abs/2102.08325) | Abstract retrieved; full text not extractable (ar5iv text exceeded the fetch limit). **[4] UNVERIFIED** for rule text. What would verify it: the paper PDF. |
| Narwhal / Tusk | [arXiv:2105.11827](https://arxiv.org/abs/2105.11827) (ar5iv text read; v4) | Certificate = acks; validity requires 2f+1 certificates of the previous round. |
| Bullshark | [arXiv:2201.05677](https://arxiv.org/abs/2201.05677) (ar5iv text read; v3) | Waves of 4 rounds; 2 rounds to commit a steady-state leader; no view change. |
| Shoal++ | [arXiv:2405.20488](https://arxiv.org/abs/2405.20488) (v2) | Average 4.5 message exchanges to commit vs 10.5 for prior DAG-BFT. This is the paper the brief calls "Shoal". |
| Mysticeti / Mysticeti-FPC | [arXiv:2310.14821v6](https://arxiv.org/abs/2310.14821v6) (v6, 24 Nov 2025; NDSS 2025, DOI 10.14722/ndss.2025.240929) | HTML read but **truncated before §III**; uncertified DAG; certificate pattern = 2f+1 support; 3 message rounds; Sui production numbers. |
| Starfish (2025) | [ePrint 2025/567](https://eprint.iacr.org/2025/567) | Uncertified-DAG liveness gap and desynchronization attacks; Push pacemaker; Mysticeti-L. |
| Beluga (2025) | [arXiv:2511.15517](https://arxiv.org/abs/2511.15517) | Pull-induction attack on Mysticeti's block synchronizer; up to 3x throughput and 25x lower latency under attack. |

**[4] Fetch limitation, recorded honestly.** The arXiv HTML for Mysticeti v6 exceeded the fetch budget and was truncated inside Section II; the **exact Mysticeti-C commit predicate in §III was not read**. What **is** verified verbatim: block validity (*"at least 2f+1 blocks from the previous round"* as references), the skip pattern, the certificate pattern (*"at least 2f+1 blocks at round r+1 support a block B ... We then say that B is certified"*), and the claim of committing *"within the known lower bound of 3 message rounds"*. **Anyone implementing must read §III of the paper (or the NDSS 2025 version, DOI 10.14722/ndss.2025.240929) before coding the commit rule.**

### 6.1 The eleven attributes

| # | Attribute | Finding | Class |
|---|---|---|---|
| 1 | Safety assumptions | n = 3f+1, up to f Byzantine (Mysticeti: *"in each epoch, n = 3f+1 validators"*; *"a computationally bound adversary can statically corrupt an unknown set of up to f validators"*). Safety under asynchrony for the certified designs. | [1] |
| 2 | Liveness assumptions | liveness after GST (Mysticeti states the GST/Δ model explicitly). Uncertified DAGs lacked rigorous liveness proofs until 2025 work; Starfish documents desynchronisation attacks where honest parties fail to commit leaders after GST. | [1] / [4] |
| 3 | Voting power and quorum thresholds | Narwhal: a valid block *"must ... contain certificates for at least 2f+1 blocks of round r−1"*; a certificate forms from 2f+1 acks. Bullshark: 2f+1 references per vertex, waves of 4 rounds. Mysticeti: certificate pattern = 2f+1 blocks in round r+1 supporting B. | [1] |
| 4 | Locking and unlocking rules | No lock/unlock rule in the Tendermint sense: ordering is a property of the DAG's causal structure. Committed leaders are totally ordered by the commit rule; equivocation is neutralised by certificate uniqueness rather than by locks. | [1] |
| 5 | Finality / commit rule | Bullshark: *"It takes two rounds to commit a steady-state leader."* Mysticeti: certificate pattern above; commit every block in 3 message rounds. **Exact Mysticeti-C predicate [4] UNVERIFIED** (§6.0). DAG-Rider rule text [4] UNVERIFIED. | [1] / [4] |
| 6 | Equivocation, partition, selective delivery, withheld certificates | Certified DAGs: reliable broadcast + certificates make equivocation a non-event. Mysticeti verbatim: *"At most one of these equivocating blocks can gather support from 2f+1 validators ... even if A equivocates and one of its blocks is certified, we process it as being correct"*. A withheld certificate cannot invalidate a decision (quorum intersection). | [1] |
| 7 | Leader change and stalled-round recovery | **No view change**: Bullshark *"does not require a view change or view synchronization mechanisms to overcome faulty or slow leaders"*; leaders are per-wave (predefined steady-state plus a fallback chosen from DAG randomness). A stalled leader delays its own commit, not DAG growth. Beluga/Starfish show the block-synchronisation layer, not the commit rule, is the attack surface. | [1] |
| 8 | Dynamic membership and old certificates | All surveyed papers are **per-epoch static**. Mysticeti says properties hold *"within a single epoch"* and defines equivocation recovery *"across epochs"*; no reconfiguration protocol is specified. **How an old certificate is judged later is unspecified** — same gap as family B, worse because the DAG's epoch boundary is also unspecified. | [1] / [4] |
| 9 | Costs as functions of n | Certified (Narwhal/Bullshark): a block carries 2f+1 certificates, each carrying 2f+1 signatures → **O(n²) signatures and O(n²) bytes per block**. Uncertified (Mysticeti): 1 signature per block + 2f+1 hash references → O(n) signatures, O(n²) hash references. | [3] from [1] rules |
| 10 | Cadence and finality latency | Measured, production: Sui switched from Bullshark (1.9 s P50) to Mysticeti-C (400 ms) *"on 106 independently run validators"*; the paper reports *"WAN latency of 0.5s for consensus commit"* and *"over 200k TPS"*; Bullshark reports *"125k TPS and 2 second latency with 50 honest parties"*. Hardware is not stated in the retrieved text. **None of it transfers to the Etna workload** (different permissioning, no zkVM proof, different n). | [2], transfer denied |
| 11 | External verifier | Certified: the entire commit structure (leader cert + 2f+1 support certs, each with 2f+1 signatures) → O(n²) signature verifications per committed leader. Uncertified: the supporting blocks themselves (2f+1 blocks with 1 signature each) + reference hashes → O(n) signatures + O(n²) hashes per committed block. What a certificate **cannot** show: the DAG is off-chain, so a verifier sees a commit proof, not the DAG; data availability needs the batch data; equivocation visibility needs the equivocating vertices published. | [3] / [1] |
| 12 | zkVM suitability | Signatures are Ed25519-family per validator; cost scales with the *support structure*, not just n. For uncertified DAGs the witness includes many block headers/hashes. **[4] UNVERIFIED**: no published zk proof of a DAG-BFT commit was found. | [1] / [4] |
| 13 | Modification risk | Collapsing the DAG into a single commit certificate changes the object whose safety was proven; the published safety arguments are about the DAG's implicit certification, not about a standalone certificate. | [3] |

### 6.2 Rules, quoted

- Narwhal ([arXiv:2105.11827](https://arxiv.org/abs/2105.11827), via ar5iv; source #14): *"Each block from a validator contains a round number, and must include a quorum of certificates from the previous round to be valid"*; *"Once certificates for round r−1 are accumulated from 2f+1 distinct validators, a validator moves the local round to r, creates, and broadcasts a block for the new round"*; *"If a block is valid the other validators store it and acknowledge it by signing its block digest, round number, and creator's identity."*
- Bullshark ([arXiv:2201.05677](https://arxiv.org/abs/2201.05677), via ar5iv; source #15): *"Every round in its DAG has at most n vertices (one for each party), each of which contains a block of transactions as well as references (edges) to at least 2f+1 vertices in the previous round."*; *"BullShark rounds are grouped in waves, each of which consists of 4 rounds."*; *"It takes two rounds to commit a steady-state leader."*; *"BullShark does not require a view change or view synchronization mechanisms to overcome faulty or slow leaders."*; measured: *"achieving 125k TPS and 2 second latency with 50 honest parties"*.
- Mysticeti ([arXiv:2310.14821v6](https://arxiv.org/abs/2310.14821v6), NDSS 2025; source #18): *"Once a block contains references to at least 2f+1 blocks from the previous round, the validator signs it and sends it to other validators."*; *"The certificate pattern ... where at least 2f+1 blocks at round r+1 support a block B ≡ (A,r,h). We then say that B is certified."*; *"we obtain certificates implicitly by interpreting the DAG, and the certification guarantees are identical to Narwhal"*; *"requires a single signature generation and verification per block, minimizing the CPU overhead"*; *"the first DAG-based Byzantine consensus protocol to achieve the lower bounds of latency of 3 message rounds"*; *"it does not require explicit certificates"*; production: *"switching from Bullshark (1.9s) to Mysticeti-C (400ms) on 106 independently run validators"*.
- Shoal++ ([arXiv:2405.20488](https://arxiv.org/abs/2405.20488); source #17): *"existing DAG-BFT protocols pay a steep latency premium, requiring on average 10.5 message exchanges to commit a transaction ... Shoal++, a novel DAG-based BFT consensus system that offers the throughput of DAGs while reducing commit latency to an average of 4.5 message exchanges"*; *"reducing latency by up to 60%"*.
- Starfish ([ePrint 2025/567](https://eprint.iacr.org/2025/567); source #19): *"Uncertified DAG-based BFT protocols, such as Mysticeti and Cordial Miners, achieve state-of-the-art latency by eliminating per-block quorum certificates. However, they have lacked rigorous liveness proofs, and recent work has demonstrated explicit desynchronization attacks where honest parties fail to commit leaders after Global Stabilization Time (GST)."*
- Beluga ([arXiv:2511.15517](https://arxiv.org/abs/2511.15517); source #20): *"We also uncover a new attack, where an adversary steers honest validators into redundant, uncoordinated pulls that exhaust bandwidth and stall progress"*; *"We integrate Beluga into Mysticeti, the consensus core of the Sui blockchain, and show on a geo-distributed AWS deployment that Beluga ... under attack, delivers up to 3x higher throughput and 25x lower latency than prior designs."*

### 6.3 Why family C is the hardest to settle on L1 (the zk problem)

A DAG-BFT "commit" is a statement about a partially ordered set of vertices, not about a single signed message. To authenticate a committed leader/block you must convince the verifier that the support pattern exists; the witness therefore includes the supporting vertices and *their* ancestors, and the verifier re-derives the DAG patterns. **[3]**

For a certified DAG (Narwhal/Bullshark) with n = 100 (f = 33): a leader certificate carries 67 signatures, and its 67 supporting vertices each carry 67 signatures → **≈4,489 signature verifications per committed leader** (4,489 × 64 B ≈ 287 KB of signatures alone, before the vertex bodies). For an uncertified DAG (Mysticeti) the same pattern costs 67 signatures but requires the supporting blocks' bodies (each with 67 hash references) in the witness to evaluate "support" — so the witness is hash-dominated rather than signature-dominated. **[3]** Neither has a published zk instantiation. **[4]**

**Counterpoint, stated fairly [1]:** the DAG is built anyway by the L2 validators, and the *batch* that the Inbox settles carries the transactions; a zkVM proving execution of the batch could, in principle, also replay the DAG structure from the witness. The question is whether DAG replay fits the 30-minute proving budget at realistic block sizes — **unmeasured [4]**.

---

## 7. Family D — checkpoint/attestation and Simplex-style designs

### 7.1 D1: Casper FFG / Gasper-style finality with BLS aggregate attestations

This is the materially different design: instead of voting on every block with per-validator signatures, validators attest to **checkpoints** once per epoch, and the finality evidence is a **single BLS aggregate signature plus a participation bitmap**.

**Version anchors (retrieved 2026-10-05):** Gasper [arXiv:2003.03052](https://arxiv.org/abs/2003.03052); Casper FFG [arXiv:1710.09437](https://arxiv.org/abs/1710.09437); Ethereum consensus specs on branch `master` — [altair/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/altair/beacon-chain.md), [altair/light-client/sync-protocol.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/altair/light-client/sync-protocol.md), [phase0/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/beacon-chain.md); [ethereum.org weak subjectivity](https://ethereum.org/en/developers/docs/consensus-mechanisms/pos/weak-subjectivity/); [IETF BLS draft-irtf-cfrg-bls-signature-05](https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-bls-signature-05). Sources #21–#27.

| # | Attribute | Finding | Class |
|---|---|---|---|
| 1 | Safety assumptions | Safety: < 1/3 of stake Byzantine, enforced by **slashing conditions**. The notion of "accountable safety" comes from Casper FFG: *"Slashing conditions: these are conditions that honest validators would never violate and violating validators can provably be caught"*. Liveness ("plausible liveness") needs 2/3 online. | [1] |
| 2 | Liveness assumptions | 2/3 of stake online; the LMD-GHOST fork choice has independent synchrony-flavoured assumptions and known reorg attacks. Recovery from a bad proposer is one slot. | [1] / [4] for the exact fork-choice assumption |
| 3 | Voting power and quorum thresholds | ≥ 2/3 by deposit for a supermajority link. Light client: the 2/3 rule is the spec line *"get_set_bit_count(sync_committee_bits) * 3 >= len(sync_committee_bits) * 2"* over a **512-member sync committee** (SYNC_COMMITTEE_SIZE = 512). | [1] |
| 4 | Locking and unlocking rules | No per-block locks. The FFG rule is justification/finalization over checkpoint pairs: *"A supermajority link is an ordered pair of checkpoints (a,b), also written a → b, such that at least 2/3 of validators (by deposit) have published votes with source a and target b."*; *"A checkpoint c is called justified if (1) it is the root, or (2) there exists a supermajority link c′ → c where checkpoint c′ is justified."*; *"A checkpoint c is called finalized if (1) it is the root or (2) it is justified and there is a supermajority link c → c′ where c′ is a direct child of c."* | [1] |
| 5 | Finality / commit rule | The justified → finalized pair quoted in row 4; verified verbatim in Casper FFG ([arXiv:1710.09437](https://arxiv.org/abs/1710.09437)). No equivalent single-block commit. | [1] |
| 6 | Equivocation, partition, selective delivery, withheld certificates | Equivocation is punished by the slashing conditions (double vote; surround vote — exact wording not retrieved here **[4] UNVERIFIED**). A withheld aggregate cannot invalidate a finalized checkpoint (quorum intersection), but a withheld *conflicting* justification can enable the known reorg-style attacks on the fork-choice/finality interaction. | [1] / [4] |
| 7 | Leader change and stalled-round recovery | No view change. Proposer per slot; fork choice follows the heaviest subtree. Slow finality (epochs), fast fork-choice. | [1] |
| 8 | Dynamic membership and old certificates | Native and continuous: activation/exit queues and per-epoch churn. The light-client design adds rotation: sync committees of **512** validators, the committee committed inside the beacon state and proven to the next committee. A certificate is judged under the committee/epoch it names; light-client validity conditions were only partially read **[4] UNVERIFIED**. | [1] / [4] |
| 9 | Costs as functions of n | Per validator: one attestation signature per epoch (not per block) plus aggregation traffic. Certificate: 1 aggregate signature + bitmap (+ committee commitment). | [1] |
| 10 | Cadence and finality latency | Checkpoint finality, not per-block finality: on Ethereum, epochs are 32 slots of 12 s and finality takes ~2 epochs (≈12.8 min) — the epoch/period constants were not re-verified in this session beyond SYNC_COMMITTEE_SIZE = 512 **[4]**. For Etna the epoch length is a free parameter (e.g. 64 × 2 s = 128 s), and checkpoint finality is a natural match for batch settlement. | [1] / [4] |
| 11 | External verifier | Verified fields from the light-client sync protocol: `attested_header`, `next_sync_committee` + branch, `finalized_header` + `finality_branch`, `sync_aggregate` (`sync_committee_bits` + `signature`), `signature_slot`. Verification calls *"bls.FastAggregateVerify(...)"*. Sizes: BLSPubkey is Bytes48 and BLSSignature is Bytes96 ([phase0/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/beacon-chain.md)); a 512-key committee is 24,576 B of pubkeys if supplied in-witness. Cannot show: everything Tendermint cannot, **plus** a 512-member committee is a **sample** of the full validator set, so safety inherits a sampling assumption unless the full set is used. | [1] / [4] |
| 12 | zkVM suitability | 1 aggregate verify = 2 pairings + (k−1) G1 additions for the aggregate pubkey, plus ~log2(state size) hashes for the branch. Both zkVMs patch the `bls12_381` crate (RISC Zero also patches `blst`); **no published pairing cycle counts were found**. | [1] / [4] |
| 13 | Modification risk | Customising FFG (epoch length, checkpoint definition, fork choice) invalidates the composition proofs in Gasper; the LMD-GHOST/FFG interaction is exactly where the published attacks live. Using BLS aggregates requires **proof of possession** at registration (IETF draft §3: *"These schemes differ in the ways that they defend against rogue key attacks"* — basic / message augmentation / proof of possession). | [1] |

**Why this is attractive for Etna [1].** The artifact shape is exactly what an L1 contract wants: one 96-byte signature, one 48-byte aggregate pubkey, a 64-byte bitmap, and a set/epoch commitment — and Ethereum L1 already prices the verification: [EIP-2537](https://eips.ethereum.org/EIPS/eip-2537) (**Final**) specifies BLS12_PAIRING_CHECK at *"32600*k + 37700"* gas. With k = 2, on-chain verification is ≈102,900 gas `derived` plus calldata (G1ADD 375, G2ADD 600 sourced from the same EIP). The open questions are (i) whether the zkVM can prove the pairing cheaply, and (ii) whether a permissionless TAIKO-staked set can be aggregated without a DKG (yes, with PoP; the aggregate is public).

### 7.2 D2: Simplex (Chan & Pass)

[IACR ePrint 2023/463](https://eprint.iacr.org/2023/463) (TCC 2023; source #29). Abstract retrieved verbatim: *"We next present a new and simple consensus protocol in the partially synchronous setting, tolerating f < n/3 byzantine faults ... As with the state-of-the-art protocols, our protocol assumes a (bare) PKI, a digital signature scheme, collision-resistant hash functions, and a random leader election oracle, which may be instantiated with a random oracle (or a CRS)."*

| # | Attribute | Finding | Class |
|---|---|---|---|
| 1 | Safety assumptions | f < n/3 Byzantine, partial synchrony, bare PKI, no threshold setup. | [2] (abstract) |
| 2 | Liveness assumptions | Presumed to mirror HotStuff/Tendermint-family properties (leader rotation via the random oracle). **Not verified.** | [4] UNVERIFIED |
| 3 | Voting power and quorum thresholds | 2f+1 per round (unverified rule). | [3] from [4] rule |
| 4 | Locking and unlocking rules | Presumed quorum intersection; **not verified at source**. | [4] UNVERIFIED |
| 5 | Finality / commit rule | The protocol is widely described as a 2-round "notarize then finalize" rule (2f+1 notarize votes, then 2f+1 finalize votes for the block notarized in the previous round). **UNVERIFIED at source:** the paper is PDF-only and not readable with the tools available. **What would verify it:** the ePrint PDF or the TCC proceedings version. | [4] UNVERIFIED |
| 6 | Equivocation, partition, selective delivery, withheld certificates | Presumed to mirror HotStuff/Tendermint-family properties. Not verified. | [4] UNVERIFIED |
| 7 | Leader change and stalled-round recovery | Random leader election oracle; per-round rotation presumed. Not verified. | [4] UNVERIFIED |
| 8 | Dynamic membership and old certificates | Per-epoch set presumed. Not verified; no reconfiguration text retrieved. | [4] UNVERIFIED |
| 9 | Costs as functions of n | If the 2-round rule is as described: per round, 2f+1 signatures on a block; the finality certificate is O(n) signatures over 1–2 blocks — the same verification profile as Tendermint with a 2-round (rather than 3-phase) structure and no DKG. | [3] from [4] rule |
| 10 | Cadence and finality latency | No absolute numbers retrieved. The paper's framework distinguishes **optimistic vs pessimistic confirmation time** — useful vocabulary for latency budgeting. | [4] UNVERIFIED |
| 11 | External verifier | Notarize + finalize vote sets (rule unverified) → O(n) verifications per round, quorum sum. | [4] UNVERIFIED |
| 12 | zkVM suitability | Same as Tendermint if individual signatures; no pairing required. | [1] |
| 13 | Modification risk | Nothing exists to modify: there is no production implementation to reuse, and the rule text is unverified. | [3] |

Included because it is the smallest published protocol that plausibly satisfies R6/R7 with a bare PKI, and because its published contribution includes a framework for **optimistic vs pessimistic confirmation time**.

### 7.3 D3: Streamlet (not deep-dived)

Chan & Shi, "Streamlet: Textbook Streamlined Blockchains", ACM AFT 2020, DOI [10.1145/3419614.3423256](https://dl.acm.org/doi/abs/10.1145/3419614.3423256); ePrint 2020/088 (source #30). Standard description: epochs with a deterministic leader, a block is notarized by 2/3 signatures, and a chain of three consecutive notarized blocks with increasing epoch numbers finalizes the middle block; it is a **synchronous** protocol (liveness needs synchrony, not just partial synchrony). **[4] UNVERIFIED** — none of this was verified against the primary text in the survey session. **Quarantine note:** the arXiv identifier first guessed for Streamlet (`2002.02798`) resolves to an unrelated paper; it must never be cited as Streamlet (§13.3).

---

## 8. Cross-family comparison

### 8.1 Safety, quorum and certificate shape

| Family | Fault threshold | Quorum | Finality object | Finality evidence size | Hides signers? |
|---|---|---|---|---|---|
| A Tendermint/CometBFT | < 1/3 voting power | > 2/3 prevotes (PoLC), > 2/3 precommits (commit) | Commit certificate at (H, R) | (2f+1) signatures + addresses + BlockID, ≈ 5.7–11.4 KB for n = 100–200 **[3] derived** | No — per-validator votes |
| B HotStuff / DiemBFT v4 / Jolteon / HotStuff-2 | f < n/3, n = 3f+1 | k = 2f+1 threshold shares | QC chain (3-chain HotStuff; 2-chain Jolteon/HotStuff-2) | 1–2 threshold signatures + identifiers, ~200 B | Yes — threshold signature |
| C Narwhal/Bullshark (certified) | f < n/3 | 2f+1 acks per certificate | Leader certificate + support pattern | O(n²) signatures per leader **[3] derived** | No |
| C Mysticeti (uncertified) | f < n/3 | 2f+1 support blocks | Implicit certificate in round r+1 | 2f+1 signatures + O(n²) hash references **[3] derived** | No |
| D1 Gasper/FFG + BLS | < 1/3 stake | ≥ 2/3 by deposit | Justified → finalized checkpoint pair | 1 aggregate sig (96 B) + bitmap (64 B) + committee pubkeys if needed (24,576 B for 512) | No, but aggregation hides individual contributions |
| D2 Simplex | f < n/3 | 2f+1 per round (unverified rule) | Notarize/finalize votes | O(n) signatures | No |

### 8.2 Measured cadence / latency evidence — what exists and what does not

| System | Number as published | Conditions as published | Hardware as published | Source | Class |
|---|---|---|---|---|---|
| Sui / Mysticeti-C (production) | P50 commit 400 ms (was 1.9 s with Bullshark) | 106 independently run validators | **not stated in the retrieved text** | [Mysticeti §I](https://arxiv.org/abs/2310.14821v6) | [2] — different workload |
| Mysticeti-C (paper experiments) | WAN commit latency 0.5 s, > 200k TPS | wide-area network deployment | **not stated in the retrieved text** | same | [2] — different workload |
| Bullshark (paper experiments) | 125k TPS, 2 s latency | 50 honest parties | **not stated in the retrieved text** | [arXiv:2201.05677](https://arxiv.org/abs/2201.05677) | [2] — different workload |
| Shoal++ | average 4.5 message exchanges to commit vs 10.5; up to 60% lower latency | not extracted in detail | **not stated in the retrieved text** | [arXiv:2405.20488](https://arxiv.org/abs/2405.20488) | [2] — relative metric only |
| Starfish / Beluga | Beluga: up to 3x higher throughput, 25x lower latency under attack; Starfish: desync attacks on uncertified DAGs | geo-distributed AWS deployment; Mysticeti integration | "geo-distributed AWS" (instance types not stated) | [ePrint 2025/567](https://eprint.iacr.org/2025/567), [arXiv:2511.15517](https://arxiv.org/abs/2511.15517) | [2] — different workload |
| CometBFT | blocks "~ every second (with default consensus parameters)"; timeout_commit default 1 s | default config, n not stated | not stated | [configuration.md](https://raw.githubusercontent.com/cometbft/cometbft/main/docs/core/configuration.md) | [2] for defaults; **[4]** for measurements at 2 s |
| HotStuff / Jolteon | Jolteon 2-chain "reducing the steady state block-commit latency by 30%" | their implementation; absolute numbers not extracted | not stated | [arXiv:2106.10362](https://arxiv.org/abs/2106.10362) | [2] relative only |
| **Etna target** (2 s blocks, permissionless TAIKO-staked set, zkVM-proven finality, n ≈ 100–200) | **no published number found** | — | — | — | **[4] UNVERIFIED** |

**Transfer statement (required by `GEN-08`).** No measurement for any protocol at the Etna target exists in the sources retrieved. Every number above is from a different deployment context. Any claim of "2 s cadence" for Etna is therefore an extrapolation, except for the generic statement that these protocols' timeouts can be configured to 2 s. The 2 s figure is a **design target (D1)**, not a measured result.

### 8.3 Dynamic membership and reconfiguration attack surface

| Family | Set-change mechanism in the source | Attack surface to design against |
|---|---|---|
| A | App-driven validator updates, effective at H+2 (quoted in §4.6) | Set substitution by the L2 app; stake-bleeding-style grinding is not applicable to explicit-quorum BFT, but *set churn* can be used to dodge slashing/accountability if transitions are not recorded on L1 |
| B | Fixed set in HotStuff; Diem epoch reconfiguration not retrievable **[4]** | Threshold key must be reshared on every set change; a stale-epoch QC must be judged by an explicit epoch rule |
| C | Per-epoch static set; reconfiguration unspecified **[4]** | Same as B, plus DAG structure from a previous epoch may be replayed |
| D1 | Continuous validator churn; sync-committee rotation committed in state | Rogue-key attack if aggregates are used without proof of possession; weak subjectivity / long-range (§8.4) |

### 8.4 Weak subjectivity and long-range attacks (honest treatment)

[ethereum.org weak subjectivity](https://ethereum.org/en/developers/docs/consensus-mechanisms/pos/weak-subjectivity/) (retrieved 2026-10-05; source #26) states the problem plainly:

- *"Subjectivity in blockchains refers to reliance upon social information to agree on the current state."*
- Attack vectors *"including long-range attacks whereby nodes that participated very early in the chain maintain an alternative fork that they release much later to their own advantage."*
- *"Alternatively, if 33% of validators withdraw their stake but continue to attest and produce blocks, they might generate an alternative fork that conflicts with the canonical chain. New nodes or nodes that have been offline for a long time might not be aware that these attacking validators have withdrawn their funds, so attackers could trick them into following an incorrect chain."*
- Mitigation: *"weak subjectivity checkpoints ... state roots that all nodes on the network agree belong in the canonical chain"*; *"The checkpoints act as 'revert limits' because blocks located before weak-subjectivity checkpoints cannot be changed."*

**Applied to Etna [1]:**

1. **The L1 contract is the weak-subjectivity checkpoint.** Because the Inbox lives on L1, its stored finalized state root is objective contract state, not social consensus. A new node or prover reads L1; no social input is needed for the current finalized root.
2. **The validator set is objective, but the epoch chain is not, by itself.** A long-range attacker can produce valid signatures from a historical TAIKO-staked set. The contract must therefore (a) track a monotonic finalized height, (b) accept only certificates whose epoch is the current epoch or a successor recorded by an L1 transition, and (c) never accept a certificate that conflicts with an already-finalized height. This makes the long-range attack a **contract-invariant** problem, not a consensus-proof problem.
3. **Withdrawal timing is a first-class parameter.** The "33% withdrew but still sign" attack is only prevented if the L1 staking contract enforces an unbonding delay longer than the maximum time between a validator's last possible attestation and the settlement of the batch it signed. Given proving latency up to 30 minutes, the unbonding delay must be hours-to-days, and the epoch set commitment must include stake **as of the epoch**. The exact parameter is open (OQ-10).
4. **Stake-bleeding is not the same threat.** [Stake-Bleeding Attacks on Proof-of-Stake Blockchains](https://eprint.iacr.org/2018/248) (ePrint 2018/248; source #28) describes *"a general attack on proof-of-stake (PoS) blockchains without checkpointing ... Our attack leverages transaction fees, the longest chain rule to completely dominate a blockchain."* Etna has checkpointing on L1 and explicit quorums, so the original attack does not transfer; what transfers is the general lesson that any *chain-based* component (e.g. a fork choice for ordering) can be ground down if it lacks an objective checkpoint.
5. **Weak subjectivity of the ordering rule.** If order is determined by the L2 PoS chain rather than by L1, an L2 node that has been offline still needs a trusted, recent L1-finalized root to avoid following a long-range L2 fork. The Inbox's stored root provides exactly that; clients must be specified to use it. **[1]**

---

## 9. What an external verifier must check (L1 contract and/or zkVM guest)

### 9.1 The public-input contract

For Mode A the Inbox should treat these as public inputs that the contract itself fixes — never the prover ([L1-05](spec/04-l1-integration.html#L1-05), [PRF-02](spec/05-proof-statement.html#PRF-02), [PRF-03](spec/05-proof-statement.html#PRF-03)):

| Public input | Source of truth | Why |
|---|---|---|
| chain id / domain separator | contract constant | Replay protection across chains and across the Inbox's own history ([GEN-05](spec/index.html#GEN-05)) |
| epoch id | L1 staking registry | Binds the certificate to one validator set |
| validator-set commitment (root/hash), and total stake | L1 staking registry, written once per epoch | Prevents prover-supplied sets (R3) |
| last finalized height + last finalized root | Inbox storage | Enforces monotonicity and no-conflict (Mode A invariant) |
| head height H, head block hash, head state root | certificate + execution proof output | Binds consensus evidence to execution |
| batch data hash | calldata | Binds the settled data to what was proven |

### 9.2 Exact data per family (what the verifier must see)

| Family | Data the verifier must see | Signature verifications | Other operations |
|---|---|---|---|
| A Tendermint/CometBFT | Commit/ExtendedCommit for height H: BlockID (block hash + parts hash), Height, Round, BlockIDFlag per validator, ValidatorAddress, Signature, Timestamp ([data_structures.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/core/data_structures.md)); plus the epoch set (pubkeys + weights) or proofs against its root | one per signer, s ≥ 2f+1 (≤ n) | voting-power sum, set membership, canonical-vote hashing |
| B HotStuff lineage | QC: view/height, block hash, threshold signature; for a 2-chain rule, the child QC (or a single QC if the rule is defined over the child) | 1 threshold verify (2 pairings), or s individual/aggregated verifies | epoch/set binding |
| C DAG (certified) | leader certificate + 2f+1 supporting certificates, each with its own 2f+1 acks | ≈ s² (s = 2f+1) | O(n²) hash/reference checks, DAG pattern evaluation |
| C DAG (uncertified, Mysticeti) | 2f+1 supporting blocks (bodies with 2f+1 references each) + their signatures, over the rounds the commit rule needs | ≈ s per committed block (plus ancestors pulled in) | O(s²) hash/reference checks |
| D1 Gasper/BLS | `attested_header` + `finalized_header` + `finality_branch` + `sync_aggregate(bits, signature)` + `signature_slot` + participating committee pubkeys or committee root | 1 FastAggregateVerify (2 pairings) | bitmap 2/3 check, Merkle branch (~log2 state size hashes), pubkey aggregation (s−1 G1 adds) |
| D2 Simplex | notarize + finalize vote sets (rule unverified) | O(n) per round | quorum sum |

### 9.3 The set-authentication pattern (non-negotiable)

A prover-supplied validator set is unsafe because the prover can choose a set it controls. Three workable patterns, all class **[1]**:

1. **Guest computes, contract compares.** The guest takes the set from the witness, computes its commitment, and exposes that commitment as a **public output**; the Inbox compares it with the epoch's set root in L1 storage and reverts on mismatch. The guest never decides the set; it only proves "the signatures are valid under *this* set". This is the pattern adopted in [04-architecture-decision.md](04-architecture-decision.md) §6 and [PRF-03](spec/05-proof-statement.html#PRF-03).
2. **Guest verifies a membership proof against an L1-known root.** The root is passed in as a public input by the contract; individual validators are Merkle/SSZ-proven. Same effect, more hashing in-guest.
3. **Set committed on L1 and read by the guest via a storage proof.** Strongest, most expensive; unnecessary if pattern 1 is used correctly.

Under all three, the epoch transition itself must be an L1 transaction (staking contract → Inbox), so that no certificate can be judged under two different sets. **[1]**

### 9.4 Cost drivers as functions of n (analytical)

Let s = number of signers (s ≥ 2f+1 ≈ 0.67n). Each Ed25519 signature is 64 B with a 32 B public key (RFC 8032 sizes; [RFC 8032](https://www.rfc-editor.org/rfc/rfc8032.txt), source #38, was retrieved and uses 32-octet keys and 64-octet signatures). BLS12-381 points are 48 B (G1) and 96 B (G2) per the Ethereum containers BLSPubkey = Bytes48 / BLSSignature = Bytes96 ([phase0/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/beacon-chain.md)). All rows below are **[3] derived**.

| Certificate style | Witness bytes | Verifications | n = 100 (s ≈ 67) | n = 150 (s ≈ 101) | n = 200 (s ≈ 133) |
|---|---|---|---|---|---|
| A: Ed25519 individual | s × 96 + bitmap | s Ed25519 | 6.4 KB, 67 verifies | 9.7 KB, 101 verifies | 12.8 KB, 133 verifies |
| A′: + Merkle paths to the set root | s × (96 + ~32·log2 n) | s Ed25519 + hashes | ~26 KB | ~62 KB | ~110 KB |
| B: threshold BLS QC | 96 + 48 + metadata | 2 pairings | ~200 B | ~200 B | ~200 B |
| B′: aggregate of individual BLS + bitmap | 96 + s×48 + bitmap | 2 pairings + (s−1) G1 adds | 3.3 KB | 4.9 KB | 6.5 KB |
| C certified DAG (support pattern) | s × (96 + 32·s) ≈ dominated by references | s² Ed25519 | ~4,489 verifies | ~10,201 verifies | ~17,689 verifies |
| C uncertified DAG | s × block bodies + s signatures | s Ed25519 + s² hashes | 67 verifies, ~4.5k hashes | 101 verifies, ~10k hashes | 133 verifies, ~17.7k hashes |
| D1 BLS committee of 512 | 96 + 64 + 512×48 (if pubkeys supplied) = 24.7 KB | 2 pairings | 24.7 KB | 24.7 KB | 24.7 KB |
| D1′ compressed (aggregate pubkey precomputed per epoch) | 96 + 48 + 64 = 208 B | 2 pairings | 208 B | 208 B | 208 B |

**Observations [3]:**

- For n ≤ ~150, **individual Ed25519 is competitive with BLS on witness size** (6.4 KB vs 3.3 KB) and loses only on verifier work (67 verifications vs 2 pairings). Whether that matters depends entirely on the measured cost ratio in the chosen zkVM — which is unpublished (§10.4). This is the single most important measurement to make before freezing the design.
- D1's 24.7 KB is dominated by the 512 committee public keys. If the committee's aggregate public key is precomputed per sync-committee period (Ethereum does not do this on-chain, but an L2 could), the artifact collapses to 208 B.
- Certified DAGs are two orders of magnitude worse on verifier work; that is a structural property of "2f+1 acknowledgements per block", not an implementation artifact.

### 9.5 What CANNOT be established from public certificates alone

| Not established | Why | Evidence that would be needed |
|---|---|---|
| Data availability of block bodies | A certificate commits to a BlockID/hash, not to data | The batch data itself (which the Inbox carries in the same transaction) plus DA sampling/publishing rules for blocks not in a batch |
| Off-chain safety (no future conflicting signature) | A certificate proves a quorum signed once; it does not prove they will never sign a conflict | The protocol's fault assumption + slashing/accountability; for threshold/aggregate QCs, signer identity is not recoverable |
| Equivocation visibility | One certificate shows at most one vote per validator | Two conflicting signed messages for the same (height, round, type) — Tendermint's JSet; impossible with a bare threshold signature |
| Liveness | No certificate proves future progress | Liveness monitoring, Mode B triggers, a published halt policy ([HALT-01](spec/06-recovery-exceptions.html#HALT-01)) |
| Set authenticity | Inherited from the certificate only if the epoch/set is bound and checked | L1 set registry + the comparison in §9.3 |
| DAG no-equivocation | The DAG's guarantees come from the vertices, not from a single signature | The full vertex set (or a proof over it) |

This table is the survey's input to the requirements document's §6.4 "explicit non-arguments" list, which forbids using "the proof verifies, therefore no hidden competing chain exists" and "a quorum signature verifies, therefore the history is unique" anywhere in the project.

### 9.6 Mode A contract invariants (independent of the zkVM)

These belong in the Inbox and are what actually makes "no recovery path invalidates a PoS-finalized block" true **[1]** (specified as [CONS-08](spec/02-consensus.html#CONS-08), [CONS-12](spec/02-consensus.html#CONS-12), [L1-06](spec/04-l1-integration.html#L1-06), [HALT-01](spec/06-recovery-exceptions.html#HALT-01)):

1. **Monotone finalization:** `lastFinalizedHeight` only increases; every accepted batch must extend `lastFinalizedRoot`.
2. **Uniqueness:** at most one finalized block hash per height; a conflicting certificate reverts.
3. **Epoch monotonicity:** a certificate is accepted only for the current epoch or a recorded successor; a certificate from a superseded epoch is rejected unless it is exactly the height at which that epoch transitioned.
4. **Prove-only-with-data (Mode A):** the entry point takes data + proof in one transaction; the legacy data-first path ([Inbox.propose](../../../contracts/layer1/core/impl/Inbox.sol#L270)) must not be able to create a finalizable artifact.
5. **Mode B cannot override:** any recovery entry point must revert if the height it targets is already finalized. This must be a tested invariant, not a convention.
6. **Safe halt:** on failure of any assumption (no valid certificate, set transition not finalized on L1), progress stops rather than falls back.

---

## 10. zkVM suitability (RISC Zero and SP1) — the evidence as retrieved

This section records only what the survey verified against official vendor documentation on 2026-10-05. The full treatment lives in [03-zkvm-feasibility.md](03-zkvm-feasibility.md) and [research/zkvm-feasibility-raw.md](research/zkvm-feasibility-raw.md); the consensus-relevant conclusion is the measurement spike in §10.5.

### 10.1 Version anchors (retrieved 2026-10-05)

| zkVM | Latest stable | Notes |
|---|---|---|
| RISC Zero | **v3.0.6**, published 2026-07-17 ([releases API](https://api.github.com/repos/risc0/risc0/releases?per_page=8); source #35) | Docs site header says *"Version: 3.0"* ([precompiles doc](https://dev.risczero.com/api/zkvm/precompiles); source #34). A **v5.0.0-rc.1** pre-release tag exists (created 2026-01-15, empty release body, marked prerelease). No v4.x tags appear in the 40 most recent tags. Treat the v5 line as not-yet-stable. |
| SP1 | **v6.8.1**, published 2026-09-24 ([releases API](https://api.github.com/repos/succinctlabs/sp1/releases?per_page=8); source #37) | Patch tags in the docs reference *"sp1-6.0.0"*/*"sp1-6.2.0"* minimum versions. |

### 10.2 What is accelerated, per the vendors' own documentation

RISC Zero ([precompiles doc](https://dev.risczero.com/api/zkvm/precompiles), retrieved 2026-10-05; source #34) states: *"RISC Zero's rv32im implementation includes a number of specialized extension circuits, including 'precompiles' for cryptographic and algebraic functions: SHA-256, RSA, elliptic curve, and modular multiplication operations."* It lists patched crates; SP1's list is at [precompiles doc](https://docs.succinct.xyz/docs/sp1/optimizing-programs/precompiles) (source #36). Versions **as printed by the vendors**:

| Scheme | RISC Zero patched crate (as printed) | SP1 patched crate (as printed) |
|---|---|---|
| Ed25519 | curve25519-dalek 4.1.3, 4.1.2, 4.1.1, 4.1.0 (via ed25519-dalek patch) | curve25519-dalek 4.1.3; curve25519-dalek-ng 4.1.1 |
| secp256k1 ECDSA | k256 0.13.4–0.13.1 (some versions need the "unstable" feature flag) | k256 13.4 (as printed); secp256k1 0.29.1, 0.30.0 |
| secp256r1 / P-256 | p256 0.13.2 | p256 13.2 |
| BN254 | substrate-bn 0.6.0 | substrate-bn 0.6.0 |
| BLS12-381 | bls12_381 0.8.0; **blst 0.3.14** (footnote: c-kzg *"requires a patched version of blst to enable full acceleration"*) | bls12_381 0.8.0 (two patches: crates-io and GitHub variants); kzg-rs is *"a pure Rust alternative to c-kzg ... relies on our patched bls12_381 crate"* |
| Keccak / SHA | tiny-keccak 2.0.2; sha2 0.10.8/0.10.7/0.10.6/0.9.9 | tiny-keccak 2.0.2; sha3 0.10.8/0.11.0; sha2 up to 0.11.0 |

**Caveats printed by the vendors themselves** (quoted, not paraphrased):

- RISC Zero: *"Certain versions of patches for some crates (e.g. k256, rsa) depend on more optimized precompiles that are still undergoing revision and review, and so users must opt-in ... by setting the 'unstable' feature flag"*. Also: *"These precompiles do not currently provide strict guarantees about constant-time execution and proving time."*
- RISC Zero: *"if you set the secp256k1 feature flag, it will use the secp256k1 crate instead, where we don't currently provide a patch."*
- SP1: the BLS12_381 patch has two incompatible variants (*"some teams use the 'latest' BLS12_381 on GitHub, and some use the one on crates.io"*), and keccak patching is feature-dependent (*"alloy-primitives selects its keccak256 backend by feature ... if source = registry...crates.io rather than the sp1-patches git source, the keccak patch is not active"*).

**What this does and does not prove [4].** The existence of a patched crate means the vendor has an accelerated path for that library's operations. It does **not** tell us which BLS12-381 operations are circuit precompiles (field arithmetic? group ops? the pairing?) or the cycle cost. RISC Zero's own list of circuit-accelerated primitives names "elliptic curve" and "modular multiplication", not pairings. Treat "BLS12-381 pairing is cheap in a zkVM" as **unverified** until measured. **What would verify it:** a kernel-level source read or the benchmark in §10.5.

### 10.3 Witness size and scaling

For the recommended Family A design the witness is dominated by s signatures + the set material; it does **not** grow with the number of blocks in the batch once the head certificate is the only consensus evidence (**[3]**, conditional on the head-certificate argument in §4.7 item 5).

### 10.4 Recursion and on-chain verification

- RISC Zero v3.0.1 release notes (2025-08-21) list: *"New much faster recursion witness generation that runs on GPU"* and *"New much faster Groth16 implementation that run on GPU"* ([releases API](https://api.github.com/repos/risc0/risc0/releases?per_page=8); source #35). This is direct evidence that recursion and a Groth16 wrapping path exist in the v3 line; **no gas or cycle figures are given** in the release notes.
- SP1's docs describe off-chain proving and reference patched crates; on-chain verification costs were **not** retrieved from a primary SP1 page in this session **[4]**. **What would verify them:** the SP1 verifier gas documentation or a measurement.
- L1 verification cost of a Groth16/PLONK proof on Ethereum in the current fork was **not** retrieved **[4]**. What **is** verified: [EIP-2537](https://eips.ethereum.org/EIPS/eip-2537) is **Final** and prices a BLS12-381 pairing check at 32600*k + 37700 gas, so a BLS aggregate can be verified *directly by the L1 contract* for ≈102,900 gas (k = 2) `derived` if the design chooses not to put that check inside the zkVM.

### 10.5 The measurement spike — decision rules before freezing the certificate format

**The gate.** The certificate format (Ed25519 per-vote verification vs one BLS aggregate) must not be frozen before the experiment below is run in **both** zkVMs at pinned versions (RISC Zero v3.0.6, SP1 v6.8.1). The survey records no numeric threshold for "dominates"; the decision rules below are marked **[3] proposed** where this consolidation makes them explicit, and they must be fixed *before* the run so the result cannot be reinterpreted afterwards. This is consistent with [04-architecture-decision.md](04-architecture-decision.md), which keeps Ed25519 individual vote signatures as the primary design and BLS aggregation as "an evaluated optimisation" — the spike decides the cryptography, not the family.

**The exact experiment (as recorded in the source, §9.6):**

| Step | Inputs | Measured outputs | What it decides |
|---|---|---|---|
| (a) | **150 Ed25519 verifications over distinct messages** in one guest | guest cycles, proving time, proof size | Whether per-vote Ed25519 verification fits the batch proving budget (the n ≈ 150 case, s ≈ 101) |
| (b) | **One BLS12-381 FastAggregateVerify with 100 participating keys**, plus the keccak/SSZ hashing of the epoch set | guest cycles, proving time, whether the pairing is circuit-accelerated at all | Whether a BLS aggregate certificate is cheaper *in-guest* than s Ed25519 verifications |
| (c) | Same as (b) with a **precomputed aggregate pubkey** | cycles, proving time | The cost of the D1′ 208 B artifact shape, without the (s−1) G1 additions |
| (d) | The wrapping path | **proof size and L1 verification gas** | The settlement cost per accepted batch |
| (e) | **End-to-end proving time for a batch of 150 blocks** (5 minutes of L2 history) with the execution proof included | wall-clock proving time at the pinned versions | Whether the whole statement fits the 30-minute budget (D6) |

**Decision rules (stated before the run):**

- **DR-1 [3] proposed.** If (a) shows Ed25519 verification is not the dominant in-guest cost of the batch at s ≈ 101, keep Family A's individual Ed25519 signatures. This preserves the native CometBFT vote format, avoids any DKG, and keeps the JSet fork-accountability lemma applicable. This is the architecture decision's default.
- **DR-2 [3] proposed.** If (a) shows per-vote Ed25519 verification dominating the proving budget, evaluate (b)/(c) before changing anything. The source states: *"If a future measurement shows Ed25519 verification dominating the proving budget, this ranking should flip to Family B"* — i.e. the certified cost ratio is the falsifier of the current recommendation, not an implementation preference.
- **DR-3 [3] proposed.** BLS is frozen only if the pairing is **proven** to be cheap enough in-guest (a circuit precompile, or measured cycles compatible with (e)), not merely because a patched crate exists. Crate names are not evidence (§10.2).
- **DR-4 [1] sourced alternative.** If the in-guest pairing is expensive but the aggregate is cheap on L1, the design may verify the aggregate **on L1** with [EIP-2537](https://eips.ethereum.org/EIPS/eip-2537) at 32600*k + 37700 gas (k = 2 → ≈102,900 gas `derived`) and pass only the verified result into the guest. Consequences, stated honestly: the certificate format becomes BLS (a vote-format change), proof-of-possession registration becomes mandatory (IETF draft §3), and the JSet/accountability proof must be replaced by separately collected evidence (§11.2). This alternative must be priced against (d).
- **Pre-commitment [3] proposed.** Before running the spike, record the numeric definition of "dominates" (the share of batch proving time attributable to signature verification) and the maximum acceptable in-guest verification budget. The survey supplies no such number; inventing one after seeing results would be exactly the failure mode `GEN-04`/`GEN-08` forbid.

**Note on the L1 alternative to the whole spike.** EIP-2537 makes the *BLS path* verifiable on L1 for ≈102,900 gas without any in-guest pairing work. The survey also lists [EIP-197](https://eips.ethereum.org/EIPS/eip-197) (alt_bn128 pairing, 80000*k + 100000 gas; source #32) and [EIP-7951](https://eips.ethereum.org/EIPS/eip-7951) (P256VERIFY at 0x100, 6900 gas, **Final**; source #33) as retrieved-but-not-load-bearing sources: they were captured during retrieval and are preserved here for completeness, but no surveyed design uses them. Any use of them would be new evidence and must be re-verified.

---

## 11. Modifications and which published proofs no longer apply

### 11.1 The three mandatory modifications (from the recommendation, §12.2)

| # | Mandatory modification | Published proof that no longer applies | What is needed instead | Status in the architecture decision |
|---|---|---|---|---|
| **M-1** | **Head-only finality certificate per batch.** The batch's consensus evidence is one commit certificate for the head block H (chain id, epoch, height, round, BlockID, >2/3 signatures) plus header-chain linkage from the batch's first block to H; execution continuity is the zkVM's job. | Nothing in the Tendermint safety proof is invalidated *if* the prefix argument holds; but the published proof is about one height at a time, not about "verify the head, assume the prefix". | A written prefix-uniqueness argument: finalizing H finalizes its ancestors under the parent-validity and lock rules, and — the case the survey explicitly leaves open — what happens if the batch's first block is **not** an ancestor of H. | Adopted in [04-architecture-decision.md](04-architecture-decision.md) §2; carried as open item **Q-A2** and review target. |
| **M-2** | **L1-authenticated epoch sets.** Epoch = fixed number of L2 blocks; the TAIKO staking contract writes the epoch's set root and total stake to L1; the Inbox compares the guest's public-output set commitment against it. | CometBFT's safety proof assumes a per-height validator set known to all; its H+2 update path is application-driven and has no epoch concept. | A per-epoch safety statement plus a **cross-epoch transition rule**: a certificate is valid under the set of its declared epoch; the contract accepts only certificates of the current/recorded-next epoch; and a proof that two different epochs cannot both finalize conflicting heights. This is a **new** proof obligation for Etna, independent of the family chosen. | Adopted as modifications M1/M2 in [04-architecture-decision.md](04-architecture-decision.md) §2.1; the lock-carry-over argument is **assumed-with-argument**, open item **F1**. |
| **M-3** | **Contract-level Mode A invariants** (monotone height, unique block per height, epoch monotonicity, prove-with-data only, Mode B cannot override, safe halt). | No consensus proof is invalidated, but these invariants — not the zk proof — are what make "no recovery invalidates a PoS-finalized block" true; treating the ZK proof as sufficient is the error the requirements document §6.5 names. | Tested contract invariants (§9.6) and the specification rules [CONS-08](spec/02-consensus.html#CONS-08), [CONS-12](spec/02-consensus.html#CONS-12), [L1-01](spec/04-l1-integration.html#L1-01), [L1-06](spec/04-l1-integration.html#L1-06), [HALT-01](spec/06-recovery-exceptions.html#HALT-01). | Adopted: "Safe halt" and "Mode B cannot override" are in the architecture decision's binding obligations §5.3. |

### 11.2 Full modification table (all modifications the survey considered)

| Modification | Published proof that no longer applies | What is needed instead |
|---|---|---|
| Replace per-validator Ed25519 precommits with a **BLS aggregate + bitmap** (Family A) | Fork-accountability/JSet reasoning (needs individual signed messages); also the "signer set is provable" part of the safety argument | The quorum-intersection safety proof survives **if** the aggregate provably authenticates exactly the bitmap's participants over the same message and the aggregate is verified with proof-of-possession-registered keys (IETF draft §3: basic / message augmentation / proof of possession schemes exist precisely to stop rogue-key attacks). Requires a new argument for slashing evidence: the aggregate cannot be opened to individual signatures, so evidence must be collected separately. |
| Change HotStuff's 3-phase rule to a **2-chain** rule | The original HotStuff safety proof's three-phase structure | Jolteon's proof (with a quadratic view change) or HotStuff-2's proof; Jolteon states the trade-off explicitly: *"reducing the steady state block-commit latency by 30% using a 2-chain commit rule. This decrease in latency comes at the cost of a quadratic view-change"*. |
| **Pipelining** blocks in flight | The unpipelined pacing/liveness argument (commit order vs view order) | A pipelined safety/liveness argument (the HotStuff paper argues pipelining is natural, but the safety proof must be restated for the pipeline depth and the pacemaker's interaction). |
| **Epoch-quantized, L1-authenticated membership** (all families) | All surveyed papers assume a fixed set per epoch; CometBFT's H+2 rule is the only source with an explicit activation delay | A per-epoch safety statement plus a cross-epoch transition rule: certificate valid under the set of its declared epoch; the contract accepts only certificates of the current/recorded-next epoch; and a proof that two different epochs cannot both finalize conflicting heights. This is a **new** proof obligation for Etna, independent of the family chosen. |
| Use CometBFT **vote extensions** to carry the L2 state root | Nothing directly (extensions are a supported feature), but the spec notes extensions of votes beyond the quorum minimum *"are not verified"*, and verification is application-defined | If the extension is load-bearing for finality, an argument that every extension contributing to a certificate was verified. Recommendation: keep it non-load-bearing; the state root belongs in the execution proof. |
| Swap LMD-GHOST for a simpler fork choice inside a D1-style design | Gasper's composition proof (fork choice + FFG safety/liveness) | A new composition proof; the known reorg/balancing attacks on the LMD-GHOST/FFG interaction are exactly the failure mode to re-analyse. |
| Use a **512-member committee** instead of the full validator set (D1) | Nothing published *for our setting*; Ethereum's light-client security relies on random sampling of the committee | A sampling argument (hypergeometric tail bound) that a < 1/3 stake adversary cannot control ≥ 1/3 of a randomly drawn committee except with negligible probability, plus a committee-rotation rule authenticated from L1. |
| **Modify the commit rule inside Family A** (e.g. relax the lock rule) | The lock/unlock safety proof quoted in §4.2 | A replacement proof. The survey's row-13 assessment for Family A is explicit: changing the commit rule invalidates the published safety proof. Not proposed. |

---

## 12. Ranking, recommendation and the runner-up

### 12.1 Ranking table (five criteria; scoring 5 = best)

The scores below are the survey's **analytical assessment [3]**, not measurements.

| Criterion | A Tendermint/CometBFT | B HotStuff-2 / Jolteon | C Mysticeti (DAG) | D1 Gasper-BLS | D2 Simplex |
|---|---|---|---|---|---|
| (i) Small, cheap-to-verify finality evidence | **5** (s ≈ 2f+1 Ed25519 sigs; no DKG; ~6–13 KB) | **4** (1–2 threshold sigs, ~200 B, but DKG) | **2** (O(n²) sigs certified; O(n²) hashes uncertified) | **4** (208 B–24.7 KB, 2 pairings) | **4** (O(n) sigs, 2 rounds; rule unverified) |
| (ii) Proven safety+liveness under partial synchrony **with dynamic membership** | **5** (published proof, explicit lock/unlock, H+2 activation in the same spec) | **3** (proof exists for a fixed set; reconfiguration text not retrievable) | **3** (Mysticeti proven in production, but 2025 work documents desync attacks on uncertified DAGs; epoch reconfiguration unspecified) | **3** (FFG safety well studied; composition with fork choice is where attacks live) | **3** (abstract claims a simple proof; rule text unverified) |
| (iii) 2-second cadence compatibility | **4** (timeout_commit configurable to 1 s and shorter; no published 2 s measurement at n ≥ 100) | **5** (2-chain + optimistic responsiveness) | **5** (400 ms measured at 106 validators) | **3** (checkpoint epochs; fast only if epoch is short, which stresses the gadget) | **5** (2 rounds) |
| (iv) Minimal protocol modification for Etna | **4** (needs L1 epoch sets + certificate epoch binding; commit rule unchanged) | **3** (same, plus threshold/DKG subsystem to build) | **2** (whole DAG stack plus a zk story that does not exist) | **3** (a new gadget + fork choice to design and prove) | **3** (protocol is small, but nothing exists to modify) |
| (v) Implementer complexity | **4** (mature implementation; integration + zk guest are the work) | **3** (no production HotStuff-2 implementation found; DKG/resharing) | **4** (Sui's implementation is production-grade; but no zk path) | **2** (many moving parts: fork choice, slashing, committees, light client) | **3** (no implementation to reuse) |
| **Total** | **22** | **18** | **16** | **15** | **18** |

### 12.2 Recommendation

**Adopt a Tendermint/CometBFT-style L2 PoS (Family A) as the Mode A baseline**, with three mandatory modifications:

1. **Head-only finality certificate per batch.** The batch's consensus evidence is one commit certificate for the head block H (chain id, epoch, height, round, BlockID, >2/3 signatures) plus header-chain linkage from the batch's first block to H; execution continuity is the zkVM's job. This keeps the consensus witness O(n) signatures per *batch*, not per block, and it is the cheapest certificate of any family surveyed once the DKG cost of Family B is priced in.
2. **L1-authenticated epoch sets.** Epoch = fixed number of L2 blocks; the TAIKO staking contract writes the epoch's set root and total stake to L1; the Inbox compares the guest's public-output set commitment against it. Long-range and set-substitution attacks become contract invariants (§8.4, §9.3).
3. **Contract-level Mode A invariants** (monotonic height, unique block per height, epoch monotonicity, prove-with-data only, Mode B cannot override). These, not the zk proof, are what make "no recovery invalidates a PoS-finalized block" true.

Keep **BLS aggregation as a measured optimization** (the artifact is smaller and the L1 verification is priced at ≈102,900 gas by EIP-2537), and keep **DAG-BFT out of v1** because its finality evidence is structurally expensive to prove and its liveness story is the subject of active 2025 attacks.

This recommendation is the one adopted in [04-architecture-decision.md](04-architecture-decision.md) §1–§2, with the same three modifications recorded there as M1–M3 and the same BLS status ("evaluated optimisation").

### 12.3 Steelman of the runner-up: HotStuff-2 / Jolteon (Family B)

Stated as the strongest counter-argument, preserved verbatim in substance from the survey:

> "Tendermint is the wrong shape for n ≥ 100 at 2 s. Its vote phase is O(n²) broadcasts per height and its commit rule needs two full voting rounds every 2 seconds; CometBFT's own defaults (3 s propose timeout, 1 s precommit, 1 s commit) are tuned for ~1 s blocks on permissioned sets, and no one has published a 2 s run at n ≥ 100 with a permissionless, stake-weighted set. HotStuff-2 was *designed* for this: linear communication with a threshold signature, two phases instead of three, and optimistic responsiveness (the leader can commit as soon as it hears from 2f+1 replicas, with no fixed timeout floor). Add Carry-the-Tail (2025) and you also neutralise tail-forking, the dominant practical source of leader-induced stalls. The DKG objection is an implementation cost, not a theoretical one: the validator set is already known per epoch from L1, so a resharing ceremony once per epoch is a bounded engineering task — and if you refuse the DKG, aggregated BLS over individual signatures still gives you a 200-byte certificate with 2 pairings. With a 30-minute proving budget, the only thing that matters is the size and verifiability of the artifact, and HotStuff-2's artifact is 30x smaller than Tendermint's."

**Why it does not win here (the survey's own rebuttal):** the artifact-size advantage is real but not decisive at these n (6–13 KB vs 200 B is noise next to the batch's execution witness); the DKG/resharing subsystem is a *new* liveness dependency that must itself be L1-authenticated under permissionless staking; and the primary source for HotStuff-2's exact rule and proof is an extended abstract whose full text could not be retrieved or verified in this survey. **If a future measurement shows Ed25519 verification dominating the proving budget, this ranking should flip to Family B.** That sentence is the falsifier, and it is why §10.5 is a gate rather than a formality.

### 12.4 Is Mode A feasible?

**Yes, conditionally [1]:** the L1 contract can enforce irreversible, monotone finalization of certificates whose signer sets are fixed by L1, and the safety of accepted certificates reduces to the protocol's < 1/3 assumption plus correctness of the set binding. Mode A does **not** require the zkVM to be cheap (30-minute proofs are fine) and does **not** require new cryptography. The residual risks are economic and operational (stake concentration, set-transition bugs, halt policy), and the unmeasured risk is proving cost (§10.4). Mode B is therefore not needed for safety; it is needed only if the L1-side set transition or the proving pipeline stalls beyond the halt tolerance.

The architecture decision reached the same conclusion after an independent research stream argued the opposite ("Mode A is not feasible as stated", [research/recovery-and-withholding-raw.md](research/recovery-and-withholding-raw.md) §3.3); the disagreement and its falsifier are preserved in [04-architecture-decision.md](04-architecture-decision.md) §5 and [DECISIONS.md](DECISIONS.md) D-3.

---

## 13. Caveats, source quality and quarantined sources

### 13.1 Unversioned CometBFT spec quotes must be re-checked

The CometBFT spec files quoted throughout §4 are on branch `main` and are **not versioned with the releases**. Every quote must be re-checked against the pinned release tag before it becomes a normative rule. CometBFT maintains four release lines simultaneously (v0.37.x, v0.38.x LTS, v0.39.x, v0.40.x) plus v1.0.1; the survey retrieved v0.40.0 as latest (2026-07-27) and v0.38.26 as newest by publication date (2026-08-13). **Line-by-line agreement with v0.40.0 is UNVERIFIED.**

### 13.2 No measurement at our target workload

**No benchmark of any protocol at the exact Etna target — 2 s blocks, permissionless TAIKO-staked set, zkVM-proven finality — exists in the retrieved sources.** Every performance number in this document is attributed to a different context, with hardware frequently unstated by the source. The measurement spike in §10.5 and a testnet cadence measurement with the real stake distribution are the only ways to close this.

### 13.3 Quarantined sources that must not be cited

| Quarantined item | Why it is quarantined | What would lift the quarantine |
|---|---|---|
| Search-engine snippet of a **Diem 3-chain proof line** | Snippets are not primary evidence; the DiemBFT v4 report itself is PDF-only and was not retrievable. It was deliberately not used as a quote. | Reading the DiemBFT v4 technical report (2021-08-17) or the Jolteon paper and quoting the primary text |
| Search-engine snippet of a **"Simplex 35/25/3.5Δ" comparison table** | Same: a snippet, not the paper. The Simplex ePrint is PDF-only and was not readable. | Reading ePrint 2023/463 (or the TCC 2023 proceedings version) and quoting the primary text |
| **arXiv `2002.02798`** | It resolves to an unrelated paper. It is the identifier the survey first guessed for Streamlet and **must never be cited as Streamlet**. | Nothing — this is a permanent quarantine. Use DOI 10.1145/3419614.3423256 or ePrint 2020/088 for Streamlet |
| **Nethermind "ZK Gas Benchmark Report 2025-12-29"** | Appeared in search results as a potential source of zkVM cycle/gas numbers, but its page did not render any text through the fetch tool (client-side rendered). It is not evidence until read. | Reading it manually and recording version, hardware, methodology; then it becomes a class [2] source under `GEN-08` |

### 13.4 Source-quality notes

- Several key papers (DiemBFT v4, HotStuff-2 full text, Simplex, Streamlet) are **PDF-only or paywalled**, and the survey environment could not fetch `application/pdf`. Where a claim depends on them it is marked **[4] UNVERIFIED**.
- The CometBFT spec files are on branch `main` and not versioned with releases; quotes must be re-checked against the pinned release tag (§13.1).
- Two search-engine snippets (the Diem 3-chain proof line and the "Simplex 35/25/3.5Δ" table) were deliberately not used as quotes and are quarantined (§13.3).
- The Nethermind report is a **promising** source for the §10.5 measurements and should be read manually; until then it must not be cited.

---

## 14. Sources

### 14.1 External sources (all retrieved **2026-10-05** unless noted)

| # | Source | Title | Version / date as printed |
|---|---|---|---|
| 1 | [consensus.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/consensus.md) | CometBFT consensus specification | branch `main` (unversioned) |
| 2 | [abci++_methods.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_methods.md) | CometBFT ABCI++ methods (ExtendVote/VerifyVoteExtension) | branch `main` |
| 3 | [abci++_app_requirements.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/abci/abci++_app_requirements.md) | CometBFT ABCI++ application requirements (validator updates, H+2) | branch `main` |
| 4 | [data_structures.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/core/data_structures.md) | CometBFT data structures (Commit, ExtendedCommit, CanonicalVote) | branch `main` |
| 5 | [proposer-selection.md](https://raw.githubusercontent.com/cometbft/cometbft/main/spec/consensus/proposer-selection.md) | CometBFT proposer selection procedure | branch `main` |
| 6 | [configuration.md](https://raw.githubusercontent.com/cometbft/cometbft/main/docs/core/configuration.md) | CometBFT configuration (timeouts) | branch `main` |
| 7 | [releases API](https://api.github.com/repos/cometbft/cometbft/releases?per_page=100) | CometBFT releases | v0.40.0 (2026-07-27), v0.38.26 (2026-08-13), v0.39.4 (2026-07-28), v1.0.1 present |
| 8 | [releases/latest](https://api.github.com/repos/cometbft/cometbft/releases/latest) | CometBFT latest release | v0.40.0, published 2026-07-27 |
| 9 | [arXiv:1803.05069](https://arxiv.org/abs/1803.05069) (text via [ar5iv](https://ar5iv.labs.arxiv.org/html/1803.05069)) | HotStuff: BFT Consensus with Linearity and Responsiveness | arXiv v1 (2018) |
| 10 | [arXiv:2106.10362](https://arxiv.org/abs/2106.10362) (text via [ar5iv](https://ar5iv.labs.arxiv.org/html/2106.10362)) | Jolteon and Ditto: Network-Adaptive Efficient Consensus with Asynchronous Fallback | arXiv:2106.10362 |
| 11 | [ePrint 2023/397](https://eprint.iacr.org/2023/397) | Extended Abstract: HotStuff-2: Optimal Two-Phase Responsive BFT (Malkhi, Nayak) | last revised 2023-04-17; PDF retrieval blocked (403) |
| 12 | [arXiv:2508.12173](https://arxiv.org/abs/2508.12173) | Carry the Tail in Consensus Protocols | arXiv 2025 |
| 13 | [DiemBFT v4 report](https://developers.diem.com/papers/diem-consensus-state-machine-replication-in-the-diem-blockchain/2021-08-17.pdf) | State Machine Replication in the Diem Blockchain | 2021-08-17; **PDF not retrievable** |
| 14 | [arXiv:2105.11827](https://arxiv.org/abs/2105.11827) | Narwhal and Tusk: A DAG-based Mempool and Efficient BFT Consensus | arXiv v4 |
| 15 | [arXiv:2201.05677](https://arxiv.org/abs/2201.05677) | Bullshark: DAG BFT Protocols Made Practical | arXiv v3 |
| 16 | [arXiv:2102.08325](https://arxiv.org/abs/2102.08325) | DAG-Rider | abstract only retrieved |
| 17 | [arXiv:2405.20488](https://arxiv.org/abs/2405.20488) | Shoal++: High Throughput DAG BFT Can Be Fast! | arXiv v2 |
| 18 | [arXiv:2310.14821v6](https://arxiv.org/abs/2310.14821v6) | Mysticeti: Reaching the Latency Limits with Uncertified DAGs | v6, 24 Nov 2025; NDSS 2025, DOI 10.14722/ndss.2025.240929 |
| 19 | [ePrint 2025/567](https://eprint.iacr.org/2025/567) | Starfish: ... (uncertified DAG liveness, Push pacemaker, Mysticeti-L) | ePrint 2025 |
| 20 | [arXiv:2511.15517](https://arxiv.org/abs/2511.15517) | Beluga: Block Synchronization for BFT Consensus Protocols | arXiv 2025 |
| 21 | [arXiv:2003.03052](https://arxiv.org/abs/2003.03052) | Combining GHOST and Casper (Gasper) | arXiv 2020 |
| 22 | [arXiv:1710.09437](https://arxiv.org/abs/1710.09437) | Casper the Friendly Finality Gadget | arXiv 2017 |
| 23 | [altair/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/altair/beacon-chain.md) | Ethereum consensus specs, Altair (SYNC_COMMITTEE_SIZE = 512) | branch `master` |
| 24 | [altair light-client sync-protocol.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/altair/light-client/sync-protocol.md) | Ethereum light client sync protocol (update fields, 2/3 check, FastAggregateVerify) | branch `master` |
| 25 | [phase0/beacon-chain.md](https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/beacon-chain.md) | Ethereum consensus specs, Phase0 (BLSPubkey = Bytes48, BLSSignature = Bytes96) | branch `master` |
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

Sources #5, #32 and #33 were retrieved by the survey but are not load-bearing for any recommendation above; they are preserved so that no citation is lost, and any future use must re-verify them.

### 14.2 Repository sources (pinned)

| Source | Revision / date | Use |
|---|---|---|
| [research/consensus-survey-raw.md](research/consensus-survey-raw.md) | this session, 2026-10-05, **unmodified** | the raw evidence file this document consolidates |
| [research/taiko-baseline-contracts.md](research/taiko-baseline-contracts.md) | commit `7718753c1cece7d7705afaf33e6f9680115086dd`, branch `etna-pos-zk`, 2026-10-05 | current contract surface; `Inbox.propose`/`prove` split, `init3()` void, permissionless proposing disabled |
| [01-requirements-and-threat-model.md](01-requirements-and-threat-model.md) | 2026-10-05 | vocabulary, status labels, assumptions A-*, fault boundary, acceptance matrix |
| [04-architecture-decision.md](04-architecture-decision.md) | 2026-10-05 | selected architecture (Family A; Ed25519 primary; Mode A) and modifications M1–M5 |
| [spec/index.html](spec/index.html) + pages | 2026-10-05 | normative rules; this survey links to rule ids, never restates rules |
| [DECISIONS.md](DECISIONS.md) | 2026-10-05 | D-0 rule-id scheme, D-3 Mode A dissent record |
| Prior Etna research | `a829f79723de9a09205660d9895418577cfe9aa9` (branch `etna/converged-spec`, read-only) | prior accepted Etna design and lessons |

---

## 15. Open questions, ordered by importance

Ordered by how much each one can change the design. Items marked **(survey OQ-n)** correspond to the raw file's §12 list; items marked **(derived)** were added by this consolidation and are flagged as such rather than presented as source findings.

1. **Ed25519 vs BLS in the zkVM — the certificate-format gate (survey OQ-2, §10.5).** No published cycle counts exist for Ed25519 verification, BLS12-381 pairing, or aggregate verification in RISC Zero 3.0.6 or SP1 6.8.1. **Closes with:** the spike in §10.5 (a)–(c), plus a pre-committed threshold for "dominates".
2. **CometBFT's exact quorum predicate (survey OQ-1, §4.3).** The spec never expands "+2/3"; the implementation commits on strictly more than 2/3 of voting power. The Inbox must match bit-for-bit, and the specification currently states ≥ 2/3 ([CONS-03](spec/02-consensus.html#CONS-03)). **Closes with:** reading the release-tag vote/commit verification code and reconciling with [CONS-03](spec/02-consensus.html#CONS-03).
3. **Whether a head-block certificate formally suffices for batch finality (survey OQ-10).** The survey argues it does, but a written argument is missing — including what happens if the batch's first block is not an ancestor of H. **Closes with:** the prefix-uniqueness argument and adversarial review (architecture decision Q-A2).
4. **Is BLS12-381 pairing actually circuit-accelerated in RISC Zero/SP1 (survey OQ-3, §10.2)?** Patched crates are not evidence of pairing acceleration; the docs name "elliptic curve" and "modular multiplication", not pairings. **Closes with:** a kernel-level source read or a benchmark.
5. **No 2 s / n ≥ 100 / permissionless measurement for any family (survey OQ-8).** Every latency number retrieved is from a different setting. **Closes with:** a testnet measurement with the real stake distribution.
6. **HotStuff-2's exact rule and proof (survey OQ-4).** The runner-up's predicate, liveness proof under a faulty leader and reconfiguration discussion are unverified; the ranking's falsifier depends on them. **Closes with:** obtaining the full paper (PDF, Cloudflare-blocked) or a version of record.
7. **DiemBFT v4's reconfiguration mechanism (survey OQ-5).** The closest thing to a production answer for chained-BFT set changes, and exactly the R3/R4 gap. **Closes with:** the technical report PDF.
8. **Mysticeti-C's exact commit predicate (survey OQ-6).** §III was truncated by the fetch limit; NDSS 2025 version should be read before any claim about its certificate content. Also unknown: whether the Starfish/Beluga desynchronisation findings are fixed in the currently deployed Sui version, and which version that is. **Closes with:** reading §III and the Sui deployment version.
9. **No published reconfiguration protocol for DAG-BFT under permissionless staking (survey OQ-7).** All surveyed DAG papers are per-epoch static; the cross-epoch rule is unspecified. **Closes with:** a primary source or a purpose-built design (which would need its own proof).
10. **Epoch length, churn limit and unbonding delay for TAIKO staking (survey OQ-9).** These economic parameters decide whether the "withdrew but still signing" attack is possible; no source fixes them. **Closes with:** an L1 staking-contract parameter derivation tied to the settlement pipeline (see [MEM](spec/03-membership-staking.html) rules).
11. **The cross-epoch transition safety statement (derived; architecture decision M2 / F1).** The survey's §11.2 modification table identifies it as a *new* proof obligation: certificates epoch-scoped and permanently valid, only current/recorded-next epochs accepted, and two epochs cannot finalize conflicting heights. The architecture decision marks the lock-carry-over argument **assumed-with-argument**, not proven. **Closes with:** a written argument plus independent review.
12. **On-chain zk proof verification cost today (survey OQ-11).** No primary source retrieved for Groth16/PLONK verifier gas on the current Ethereum fork; only the EIP-2537 pairing price is verified. **Closes with:** the verifier documentation/measurement for the chosen wrapping path (spike step (d)).
13. **Whether a 512-validator committee is acceptable for Etna (survey OQ-12).** This decides whether D1's sampling assumption is imported. **Closes with:** a sampling argument plus an L1 committee-rotation rule, or a decision to use the full stake-weighted set.
14. **Mode B's exact rules and the test that it cannot override a Mode A finalization (survey OQ-13).** A code-level invariant no source can supply. **Closes with:** the unselected fallback specification in [spec/06-recovery-exceptions.html](spec/06-recovery-exceptions.html) plus an invariant test.
15. **Vote extensions as a state-root carrier (survey OQ-14).** The spec says extensions beyond the quorum minimum are not verified; whether an extension is inside the canonical vote sign-bytes (and thus trustworthy to a zkVM) needs the release-tag data-structure and signing code. **Closes with:** reading that code; the default recommendation is to keep extensions non-load-bearing.
16. **CometBFT's O(n²) vote load at 2 s with n = 150–200 in a real, permissionless network (survey OQ-15).** The analytical estimate (~75 KB egress/validator/block) looks safe, but it ignores gossip inefficiency, block propagation and node churn. **Closes with:** a network measurement.
