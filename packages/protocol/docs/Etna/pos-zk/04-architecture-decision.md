# Phase 3 — Architecture decision

Author: lead architect · Date: 2026-10-05 · Baseline `7718753c1` · Prior Etna pinned at `a829f79723de9a09205660d9895418577cfe9aa9`
Inputs: `01-requirements-and-threat-model.md`, `02-consensus-survey.md`, `03-zkvm-feasibility.md`,
`research/mode-a-feasibility-analysis.md`, `research/recovery-and-withholding-raw.md`,
`research/prior-etna-digest.md`, `research/taiko-baseline-contracts.md`, `research/zkvm-feasibility-raw.md`,
`research/consensus-survey-raw.md`, `research/economics-raw.md`.

This document records the architecture selection and the D2 mode decision. Normative rules live in
`spec/index.html`; this document explains **why** they are what they are and what was rejected.

---

## 1. Selection summary

| Question | Decision |
|----------|----------|
| Consensus family | **Tendermint / CometBFT-class BFT**, one block per height, single-slot finality, lock + proof-of-lock-change (PoLC) rules retained unchanged |
| Vote/certificate cryptography | **Ed25519 individual vote signatures (CometBFT-native)** for the primary design; BLS12-381 aggregation kept as an evaluated optimisation (§4.3) |
| Membership | Permissionless, self-bonded **TAIKO** on **L1**; validator-set roots committed by an L1 staking contract; epoch-scoped sets |
| Data + proof | **Atomic in one L1 transaction** (D5), with two sound data paths: calldata+keccak (contract-computed) and blob+KZG-opening (in-guest polynomial evaluation, on-chain point-evaluation precompile) |
| Proof shape | **One combined guest** proving consensus evidence *and* execution; composition rejected as the default |
| Recovery mode (D2) | **Mode A selected** — safety-first, halt rather than rollback. Mode B is specified but **not selected** (§5) |
| Sequencing | **PoS-sequenced validity rollup** (D4), named honestly throughout both deliverables |

---

## 2. Why this consensus family

The survey evaluated three materially different families (Tendermint/CometBFT, HotStuff lineage
incl. HotStuff-2/Carry-the-Tail, DAG-based BFT incl. Narwhal/Bullshark/Mysticeti) plus a
checkpoint/attestation design. The decisive criteria for *this* workload, in order:

1. **The finality evidence must be small, self-contained, and cheap to verify inside a zkVM**,
   because it is verified by the guest on every accepted batch.
2. **Published safety and liveness proofs must transfer with minimal modification**, because the
   project forbids inventing a new handoff/timeout/quorum collection.
3. **The lock rule must be the canonical answer to the withheld-certificate problem**, which is a
   hard requirement here (§6 of the requirements document).
4. **Dynamic membership must be expressible as an authenticated handoff**, because the authoritative
   set comes from L1 (D7, R7).

Tendermint/CometBFT wins on (2) and (3): its *Proof of Safety*, the lock/PoLC rule, and the
fork-accountability lemma are published, quoted in `research/recovery-and-withholding-raw.md` §1.1
from the CometBFT spec (pinned commit `709fd12b…`), and its commit certificate is exactly a
"≥2/3 of stake precommitted this block at (height, round)" object. It also wins on (1) for a
chain-based reason worth stating explicitly:

> **Only one certificate per batch needs verifying.** The batch's blocks are linked by a header hash
> chain back to the previously L1-accepted checkpoint, and the *head* block's commit certificate is
> verified in-guest. Under CometBFT's safety theorem — a validator precommits a block only if it
> validated the block and its parent relation, and ≥2/3 precommits imply ≥1/3 honest locked
> validators — the uniqueness of the *head* extends to the whole prefix. This is the same reasoning a
> light client uses. Verifying every ancestor's certificate would multiply in-guest signature work by
> the batch length for no additional security. The premise (correct validators follow the
> parent-validity and lock rules) is stated as such, and violations are objectively slashable.

DAG-based BFT is rejected for (1): its finality evidence is a set of certificates over a DAG, so the
guest must verify many certificates and their causal relations, and the survey's §5.3 records the
same conclusion. HotStuff-2 retains the highest QC that the leader may not know, which the survey and
the recovery research both flag as a non-responsiveness risk; it is the runner-up, not the choice.

**Client reality.** CometBFT's *native* commit format uses Ed25519 signatures over per-validator
canonical vote bytes (including each validator's own timestamp), which is why we keep individual
Ed25519 signatures rather than aggregate BLS: it avoids modifying the vote format at all. Both
zkVMs accelerate Ed25519 and SHA-256/Keccak (`03-zkvm-feasibility.md` §3.1), so the guest verifies
*n* accelerated Ed25519 signatures for the head certificate, plus *n* set-membership proofs against
the L1-authenticated validator-set root.

### 2.1 Modifications, and which proofs stop applying

| # | Modification | Status of the published proof |
|---|--------------|------------------------------|
| M1 | The validator set for epoch *e* is **derived from L1-committed TAIKO stake**, not from application logic in `EndBlock`. | CometBFT's safety proof assumes a per-height validator set known to all. Supplied argument: the set for epoch *e* is a deterministic function of L1 state fixed before the epoch starts, so all correct nodes agree on it; the L1 Inbox re-derives the same commitment when verifying the proof, so a prover cannot choose it (`PRF-03`). |
| M2 | **Epoch handoff**: the first block of epoch *e+1* must commit to the last finalized block of epoch *e*; locks carry across the boundary. | This is the delicate modification. CometBFT's validator-update path is application-driven and assumes the update is visible to all. Our argument: a certificate is judged **under the set of its own epoch and remains valid forever** (`CONS-EPOCH-CERT`); correct validators in *e+1* treat the last block finalized in *e* as locked and will not precommit a conflicting block at that height; therefore a conflicting history requires ≥1/3 equivocation across the boundary, which is objectively slashable. This argument is **assumed-with-argument**, not proven here, and is a named review target (§7 F2). |
| M3 | **Forced inclusion as a validity rule**: a proposal that omits a due forced inclusion is invalid and correct validators reject it. | Safety is unaffected (it only restricts which blocks can gather votes). Liveness for forced inclusion follows from hash-based weighted proposer selection (`CONS-06`): a sub-threshold cartel holds fewer than 1/3 of proposer slots *in expectation*, and honest proposers include due inclusions. The slot-share step is the **Assumed** fairness claim of M6, not the hash assumption. |
| M4 | **Cadence and timeouts** are expressed in seconds with an adaptive timeout ladder. | CometBFT's liveness proof needs eventual synchrony and a correct proposer; both are preserved. No wall clock is read by any *validity* rule (`GEN-06`). |
| M5 | **Removal of `timeout_commit` slack** beyond the cadence budget. | Only affects timing, not the safety proof. |
| M6 | **Proposer selection** is hash-based weighted selection over the epoch set (`pos = keccak256(abi.encode(DOMAIN_PROPOSER, chainId, epoch, H, R)) mod W`, the proposer the owner of the half-open cumulative-weight interval containing `pos`, lower index winning ties; `CONS-06` owns the formula, the tag and the encoding) instead of CometBFT's proposer-priority state machine. | Chosen during specification writing because the priority recurrence could not be quoted from a source retrieved in this session, and because the first form — a cumulative-weight residue rotation in *weight units* — left the whole epoch inside the highest-weight validator's interval and made one minimum-bond key the proposer of every height, able to halt the chain or capture ordering. Safety is unaffected: leader identity does not enter the safety invariant (`CONS-12`). The fairness claim is **Assumed**, not supplied by the hash assumption: hashing gives a residue uniform on `[0, W)` only under a random-oracle assumption that `A-CRYPTO-3` (collision resistance) does not provide, and the claim that each validator holds exactly its weight share of residues is an expectation over the epoch's heights and rounds, not a finite-window bound. Review target: confirm the residue-share counting argument. <em>This closes review round 1 finding CS-02: the superseded residue rotation is replaced by hash-based weighted selection and the fairness step is stated as Assumed.</em> |

---

## 3. Membership and staking (D7)

- Stake custody is an **L1 staking contract holding the existing TAIKO ERC-20**
  (`0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` on L1 mainnet). No new token, no ETH bonds.
- Voting power is proportional to **effective stake** = bonded amount that has completed activation.
- Validator-set roots are committed **before** the epoch that uses them (one-epoch lookahead), so L2
  never waits on an L1 transaction inside an epoch.
- v1 supports **no delegation**: self-bonded operator keys only. Rationale and rejected alternatives
  are recorded in the specification's economics page; the decisive reasons are attribution of
  equivocation evidence and avoidance of delegator/operator alignment games.
- Exit is an objective unbonding queue whose delay is derived from the whole settlement pipeline,
  not from proving time alone.

---

## 4. Data availability and atomic submission (D5)

The current Inbox exposes separate `propose()` (`Inbox.sol:270`) and `prove()` (`Inbox.sol:321`)
paths — a data-first design that D5 forbids. The baseline research also found the *observed* cost of
that design: `init3()` (`Inbox.sol:246-258`) is a one-time owner function that voids forced
inclusions whose blob references **expired from the retention window** after the June 2026 incident,
and `Inbox.sol:601-603` records that permissionless proposing is temporarily disabled.

### 4.1 Two sound data paths, both atomic with the proof

| Path | Binding mechanism | Soundness |
|------|-------------------|-----------|
| **Calldata** | The Inbox hashes the exact calldata slice itself and passes the digest as a public input. | Contract-computed; no guest trust; no proof-side assumption. |
| **Blob** | (i) `BLOBHASH(i)` of the same transaction; (ii) on-chain KZG point-evaluation precompile (`0x0A`, 50 000 gas, EIP-4844) checks an opening of the published blob at a Fiat–Shamir challenge point *z* against the blob's versioned hash; (iii) the guest proves that the polynomial evaluation of the witness data it actually executed at *z* equals the value *y* the precompile accepted. | Two commitments to the same object: the protocol's KZG commitment (what L1 DA addresses) and the guest's data commitment. The equality at a random point makes disagreement succeed with probability ≈ deg/|F| ≈ 2^-243 per attempt; the challenge is derived on-chain from all public inputs, so the prover cannot choose *z* after choosing its data. |

The blob path deliberately **avoids in-guest MSM and in-guest pairings**, which the zkVM research
found unverified for both backends: the guest performs field arithmetic and a Lagrange evaluation
(≈ *O*(4096) field operations per blob) using accelerated big-integer primitives, and the pairing
happens on L1 in the precompile. This is the single most important design consequence of
`03-zkvm-feasibility.md`; it is marked **unmeasured** for cost and **proven-with-premises** for
binding.

### 4.2 Consequences accepted

- Blob data is *published with the proof*, never before it, so the June-2026 "blob pointer expired
  while unproven" failure class cannot recur for pending batches.
- If a prover fails, another prover completes the proof for the **same** data commitment; no
  data-first re-publication is needed because the data is retrievable from the L2 network until the
  batch lands.

---

## 5. D2 decision — Mode A selected (with a recorded dissent)

### 5.1 The procedure

1. Mode A's obligations and the structural constraints it imposes were written first
   (`research/mode-a-feasibility-analysis.md`).
2. An independent research stream was asked to *break* Mode A and returned the verdict
   **"Mode A is not feasible as stated"** (`research/recovery-and-withholding-raw.md` §3.3), whose
   strongest counterexample is "certified-but-unavailable data": a quorum signs block *B* whose data
   lives only in node memory; the holders vanish; under D5 no proof can be built; Mode A forbids
   discarding *B*, so settlement halts.
3. The lead's assessment **disagrees with that verdict**, for the reason recorded below, and the
   disagreement is preserved rather than edited away.

### 5.2 The disagreement, stated exactly

The counterexample is real, and the protocol must disclose it. It is **not**, however, evidence that
Mode A is infeasible, because D2 step 1 states: *"A safe halt outside the stated liveness assumptions
is permitted; its existence alone is not evidence that Mode A is infeasible."*

The counterexample is precisely a failure of a **liveness** assumption — that correct validators hold
and serve the data they voted for, and that at least one adequately-resourced prover exists. Every
requirement that Mode A must satisfy is either a safety requirement or an explicitly **conditional**
liveness requirement:

| Requirement | Conditional? | Satisfied under Mode A? |
|-------------|--------------|-------------------------|
| R5 consensus safety and confirmation guarantees | safety | Yes — CometBFT safety under <1/3 Byzantine; certificates are epoch-scoped and permanent |
| R6 liveness | explicitly conditional in its own text | Yes, under stated assumptions; the specification states exactly where liveness ends |
| R4 2 s cadence | "under explicit, justified assumptions" | Yes, under the stated participation/synchrony assumption |
| D5, D6, R8, R9, R10, R11 | no liveness demand beyond stated assumptions | Yes |
| D1/D2 instruction | — | A safe halt is explicitly permitted |

Two further points support the assessment. First, **Mode B does not remove the counterexample's
cause, only its symptom**: recovery requires a *new* honest quorum and the L1 checkpoint's data; if
participation is permanently gone, recovery restores nothing, while it *does* introduce a
permissionless mechanism that can rewrite unsettled history — the exact surface D2 step 5 makes a
blocker. Second, **the failure mode is already present in the current, production Taiko design**
(the June 2026 forced-inclusion void at `Inbox.sol:246-258`), which shows the class is real and must
be *disclosed and mitigated*, not that it is disqualifying.

**Therefore: Mode A is selected.** The dissent, the counterexample, and the mitigation obligations
are recorded in `DECISIONS.md` D-3 and carried into adversarial review as review question Q-A1
(§7). If a reviewer shows the counterexample is *reachable inside* the stated liveness assumptions
(i.e. that the availability premise is vacuous rather than conditional), the selection must be
revisited under D2 step 2 — that is the falsifier, and it is stated in the specification.

### 5.3 Mode A's binding obligations (become normative rules)

`L1-FINAL-ONLY` (L2 consumes only Ethereum-final L1 facts) · `CONS-EPOCH-CERT` (epoch-scoped,
permanently valid certificates) · `L1-ADMIT-NO-EXPIRY` (no permissioned gate, no expiring range) ·
`UPG-PRESERVE` (upgrades accept previously finalized history) · `DA-BACKLOG-CAP` (consensus-enforced
unsettled-depth cap) · `HALT-RESTART` (resume only from reconstructible finalized state) ·
`WITHDRAWAL-DELAY` (derived from the whole pipeline).

### 5.4 Mode B — specified, not selected

Mode B is specified in `spec/06-recovery-exceptions.html` so that (a) the authorized fallback is
concrete rather than hand-waving, (b) the trigger conditions that would make it necessary are
enumerated, and (c) Mode A is not designed in a way that makes the fallback unimplementable. It is
**never** described as satisfying Mode A's irreversible-finality promise, and its D2-step-5 blocker
(cheap triggering of recovery that replaces honestly confirmed history) is recorded as unresolved in
the specification.

---

## 6. Proof architecture

- **One combined guest** proving consensus evidence and execution. Composition is rejected as the
  default because latency is not binding under D6, one trusted computing base and one verifier route
  reduce the dominant long-run risk (stale-version acceptance), and recursive composition
  re-introduces the exact bug class that a recent SP1 advisory was about (`03-zkvm-feasibility.md`
  §9).
- Public inputs are **derived from L1 state** wherever they define authority: chain id, predecessor
  checkpoint, epoch, validator-set root, quorum threshold, data commitment, new state root, and the
  Fiat–Shamir challenge. A prover-supplied witness never defines the validator set (`PRF-03`).
- Both RISC Zero and SP1 must implement the same statement. Acceptance policy, version pinning and
  upgrade rules are normative (`PRF-08`, `PRF-10`).

---

## 7. Open items and falsifiers carried forward

| ID | Item | Closed by |
|----|------|-----------|
| F1 | Epoch-handoff lock-preservation argument (M2) | independent review; explicit argument in `CONS` rules |
| F2 | In-guest cost of the blob-path polynomial evaluation | measurement gate (implementation); not needed for calldata path |
| F3 | 2 s cadence under a permissionless global set | measurement gate + stated assumptions |
| F4 | Proving throughput formula inputs (cycles per L2 gas; proven cycles/s per machine) | measurement gate |
| Q-A1 | Is the Mode A availability counterexample reachable *inside* the stated assumptions? | adversarial review round 1 |
| Q-A2 | Is the "one certificate per batch" argument sound for the whole prefix? | adversarial review round 1 |
| Q-A3 | Does the blob binding (FS challenge + on-chain opening + in-guest evaluation) hold against a grinding prover? | adversarial review round 1 |

---

## 8. Rejected alternatives (summary; full list in the specification)

- **DAG-based BFT** — finality evidence too large to verify economically in-guest.
- **HotStuff-2 / Carry-the-Tail** — runner-up; highest-QC-unseen non-responsiveness and a
  two-certificate commit rule complicate "certificate = finality" for light-client-style checking.
- **BLS aggregate certificates as the default** — would modify the vote format and require in-guest
  pairings (unverified on both backends). Retained as an optimisation to be measured.
- **Delegated stake in v1** — evidence attribution and alignment games.
- **Mode B** — not selected; see §5.
- **A new consensus design** — explicitly forbidden by the brief's preference for an established
  protocol.
- **Reusing the prior Etna seat/sortition committee** — a different security model (bonded seats,
  not stake-weighted PoS); reusing it would misrepresent seat share as stake.
