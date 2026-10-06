# Phase 3 — Architecture decision

Author: lead architect · Date: 2026-10-05 · Baseline `7718753c1` · Prior Etna pinned at `a829f79723de9a09205660d9895418577cfe9aa9`
Inputs: `01-requirements-and-threat-model.md`, `02-consensus-survey.md`, `03-zkvm-feasibility.md`,
`research/mode-a-feasibility-analysis.md`, `research/recovery-and-withholding-raw.md`,
`research/prior-etna-digest.md`, `research/taiko-baseline-contracts.md`, `research/zkvm-feasibility-raw.md`,
`research/consensus-survey-raw.md`, `research/economics-raw.md`.

This document records the architecture selection and the D2 mode decision, as amended by user decisions
D-7 (Mode B selected; §5), D-8 (security funded from L2 fees), D-9 (slashed stake to the treasury) and
D-10 (forced inclusion deferred), and then by D-11 (data may be published before the proof; it relaxed
D5), D-12 (narrow forced inclusion ships in v1; it supersedes D-6 and D-10) and D-13 (one aggregated
proof object per batch). Normative rules live in `spec/index.html`; this document explains
**why** they are what they are and what was rejected.

---

## 1. Selection summary

| Question | Decision |
|----------|----------|
| Consensus family | **Tendermint / CometBFT-class BFT**, one block per height, single-slot finality, lock + proof-of-lock-change (PoLC) rules retained unchanged |
| Vote/certificate cryptography | **Ed25519 individual vote signatures (CometBFT-native)** for the primary design; BLS12-381 aggregation kept as an evaluated optimisation (§8) |
| Membership | Permissionless, self-bonded **TAIKO** on **L1**; validator-set roots committed by an L1 staking contract; epoch-scoped sets |
| Data + proof | **Proof-gated acceptance in one L1 transaction** (D5 as relaxed by D-11): the checkpoint advances only on a valid proof, and the batch's data is either carried by the accepting transaction or bound to a live publication record published earlier. Two sound data paths: calldata+keccak (contract-computed) and blob+KZG-opening (in-guest polynomial evaluation, on-chain point-evaluation precompile; recorded versioned hashes on the referenced path) |
| Proof shape | **One combined guest** proving consensus evidence *and* execution; composition rejected as the default |
| Recovery mode (D2, amended by D-7) | **Mode B selected** *(user decision D-7, after the D2 procedure was completed)* — permissionless, bonded, delayed recovery of history strictly above the last latest L1-accepted checkpoint, cancelled by honest progress and never applied below that boundary (§5). Mode A was investigated first and rejected as the selection because an availability failure under it produces an unbounded halt the requirement set does not accept |
| Security funding (D-8) | **L2 execution and priority fees**, collected in the L2 fee vault and swept permissionlessly through the preserved Bridge to the single L1 reward pool; fees are revenue when they arrive at the pool, not when collected, and an empty pool pays nothing (`ECON-02` clause 7; *user decision D-8*) |
| Penalty destination (D-9) | **Protocol treasury, with no burn**, and a reporter bounty strictly below the total penalty so self-reporting is never profitable (`ECON-06`; *user decision D-9*) |
| Forced inclusion (D-12 supersedes D-10) | **Narrow forced inclusion ships in v1**: any account may publish a transaction's data, and a due record must be resolved by the capped FIFO prefix of the due set, included in a proven batch or discharged as void on objective grounds, enforced at the proof (`FI-10`–`FI-14`). It is an upper bound on exclusion, never a lower bound on inclusion. The **general inclusion list** remains deferred to a later protocol update, which must preserve the D2, D5 and permissionlessness invariants (`FI-REMOVED-01`, `FI-PLANNED-01`; *user decisions D-12 and D-10*) |
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
| M2 | **Epoch handoff**: the first block of epoch *e+1* must descend from the last block finalized in epoch *e*; **no lock state crosses the boundary**. | This is the delicate modification. CometBFT's validator-update path is application-driven and assumes the update is visible to all. Our argument: cross-height continuity is exactly the parent-validity condition (`CONS-01`(iii)), enforced at the boundary by the anchor duty of `CONS-09`(1)–(2); and a certificate is judged **under the set of its own epoch and remains valid forever** (`CONS-EPOCH-CERT`), so the closing epoch's decision is not re-judged by the new set and a conflicting history requires ≥1/3 equivocation across the boundary, which is objectively slashable. This argument is **assumed-with-argument**, not proven here, and is a named review target (§7 F1). *This closes review round 3 finding R3A-03: the retracted cross-height lock carry-over is removed, and the protection it names is parent validity plus epoch-scoped permanent certificates.* |
| M3 | **Reinstated in narrow form** *(user decision D-12: narrow forced inclusion ships in v1; D-12 supersedes D-6 and D-10, and D-11 supplies the L1 anchor)*: proposal validity again carries an inclusion condition — the capped FIFO prefix of the due set over **published** data (`CONS-01`(v)) — enforced at the proof and never as an admission gate (`FI-10`–`FI-14`). The general inclusion list remains deferred. | No new CometBFT proof applies: the narrow rule is an added validity condition on the block, and its non-halt argument is `FI-12`'s counting argument over the batch's own gas capacity, conditional on the registered capacity relation and its named falsifiers. For unpublished transactions, inclusion resistance remains the conditional statistical property of proposer rotation (`CONS-06`, `LIVE-04`). A later widening must preserve the D2, D5 and permissionlessness invariants (`FI-PLANNED-01`). |
| M4 | **Cadence and timeouts** are expressed in seconds with an adaptive timeout ladder. | CometBFT's liveness proof needs eventual synchrony and a correct proposer; both are preserved. No wall clock is read by any *validity* rule (`GEN-06`). |
| M5 | **Removal of `timeout_commit` slack** beyond the cadence budget. | Only affects timing, not the safety proof. |
| M6 | **Proposer selection** is hash-based weighted selection over the epoch set (`pos = keccak256(abi.encode(DOMAIN_PROPOSER, chainId, epoch, H, R)) mod W`, the proposer the owner of the half-open cumulative-weight interval containing `pos`, lower index winning ties; `CONS-06` owns the formula, the tag and the encoding) instead of CometBFT's proposer-priority state machine. | Chosen during specification writing because the priority recurrence could not be quoted from a source retrieved in this session, and because the first form — a cumulative-weight residue rotation in *weight units* — left the whole epoch inside the highest-weight validator's interval and made one minimum-bond key the proposer of every height, able to halt the chain or capture ordering. Safety is unaffected: leader identity does not enter the safety invariant (`CONS-12`). The fairness claim is **Assumed**, not supplied by the hash assumption: hashing gives a residue uniform on `[0, W)` only under a random-oracle assumption that `A-CRYPTO-3` (collision resistance) does not provide, and the claim that each validator holds exactly its weight share of residues is an expectation over the epoch's heights and rounds, not a finite-window bound. Review target: confirm the residue-share counting argument. <em>This closes review round 1 finding CS-02: the superseded residue rotation is replaced by hash-based weighted selection and the fairness step is stated as Assumed.</em> |

---

## 3. Membership and staking (D7)

- Stake custody is an **L1 staking contract holding the existing TAIKO ERC-20**
  (`0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` on L1 mainnet). No new token, no ETH bonds.
- Voting power is proportional to **effective stake** = bonded amount that has completed activation.
- Validator-set roots are committed **before** the epoch that uses them (**two-epoch lookahead**,
  `MEM-09`(1), `CONS-13`(3)), so L2 never waits on an L1 transaction inside an epoch. *This closes
  review round 2 finding R2A-01: keying the commit to the closing height stalled production at every
  boundary, so the set root for epoch *e+2* is committed during epoch *e*.*
- v1 supports **no delegation**: self-bonded operator keys only. Rationale and rejected alternatives
  are recorded in the specification's economics page; the decisive reasons are attribution of
  equivocation evidence and avoidance of delegator/operator alignment games.
- Exit is an objective unbonding queue whose delay is derived from the whole settlement pipeline,
  not from proving time alone.

---

## 4. Data availability and proof-gated submission (D5 as relaxed by D-11)

The current Inbox exposes separate `propose()` (`Inbox.sol:270`) and `prove()` (`Inbox.sol:321`)
paths — a data-first *admission* design that D5 forbids, because `propose()` advances proposal state
before any proof. The baseline research also found the *observed* cost of that design: `init3()`
(`Inbox.sol:246-258`) is a one-time owner function that voids forced inclusions whose blob references
**expired from the retention window** after the June 2026 incident, and `Inbox.sol:601-603` records that
permissionless proposing is temporarily disabled. **D-11 separates the two questions:** *publishing* a
batch's bytes before its proof is permitted, because a publication record advances no checkpoint and
confers no status; what remains forbidden is a data-first *admission* path, in which any protocol state
advances on data alone. The June-2026 expiry class is controlled by the publication deadline
(`DA-09`), not by forbidding publication.

### 4.1 Two sound data paths; the proof, not the bytes, is atomic with acceptance

| Path | Binding mechanism | Soundness |
|------|-------------------|-----------|
| **Calldata** | The Inbox hashes the exact calldata slice itself and passes the digest as a public input. | Contract-computed; no guest trust; no proof-side assumption. |
| **Blob** | (i) the blob's versioned hash — read with `BLOBHASH(i)` when the accepting transaction carries the blob, or the **recorded** versioned hash of a live publication when the proof references one (D-11); (ii) on-chain KZG point-evaluation precompile (`0x0A`, 50 000 gas, EIP-4844) checks an opening of the published blob at a Fiat–Shamir challenge point *z* against the blob's versioned hash; (iii) the guest proves that the polynomial evaluation of the witness data it actually executed at *z* equals the value *y* the precompile accepted. | Two commitments to the same object: the protocol's KZG commitment (what L1 DA addresses) and the guest's data commitment. The equality at a random point makes disagreement succeed with probability ≈ deg/|F| ≈ 2^-243 per attempt; the challenge is derived on-chain from all public inputs, so the prover cannot choose *z* after choosing its data. |

The blob path deliberately **avoids in-guest MSM and in-guest pairings**, which the zkVM research
found unverified for both backends: the guest performs field arithmetic and a Lagrange evaluation
(≈ *O*(4096) field operations per blob) using accelerated big-integer primitives, and the pairing
happens on L1 in the precompile. This is the single most important design consequence of
`03-zkvm-feasibility.md`; it is marked **unmeasured** for cost and **proven-with-premises** for
binding.

### 4.2 Consequences accepted

- Blob data MAY be published before the proof (D-11) and referenced by it, so long as the record is
  live and inside its proving deadline; the June-2026 "blob pointer expired while unproven" failure
  class is controlled by that deadline rather than by forbidding publication.
- If a prover fails, another prover completes the proof for the **same** data commitment against the
  same live publication record, or re-publishes the data under a fresh record; the data is
  retrievable from L1 (the record's blobs) or from the L2 network until the record's deadline.

---

## 5. D2 decision — Mode B selected (user decision D-7)

### 5.1 The procedure, completed

1. Mode A's obligations and the structural constraints it imposes were written first
   (`research/mode-a-feasibility-analysis.md`).
2. An independent research stream was asked to *break* Mode A and returned the verdict
   **"Mode A is not feasible as stated"** (`research/recovery-and-withholding-raw.md` §3.3), whose
   strongest counterexample is "certified-but-unavailable data": a quorum signs block *B* whose data
   lives only in node memory; the holders vanish; with no holder able to publish, no proof can be built; Mode A forbids
   discarding *B*, so settlement halts.
3. The lead's earlier assessment, recorded as D-3 and preserved here, **disagreed** with that verdict:
   the counterexample is a failure of a conditional liveness assumption, and D2 step 1 permits a safe
   halt outside the stated assumptions.
4. D-7 completes the procedure and records the selection. The requirement Mode A cannot satisfy is now
   concrete (`§5.2`), and the safe-recovery constructions that were attempted
   (`research/mode-a-feasibility-analysis.md`) either discard unsettled history (this selection) or
   leave the halt in place. The resistance analysis required by D2 step 5 is written as `REC-03` in
   `spec/06-recovery-exceptions.html`.

### 5.2 What Mode A could not satisfy

The counterexample is real and is disclosed in the specification. The decisive point is not whether it
is reachable *inside* the stated assumptions, but what the requirement set accepts as an end state: D2
permits a safe halt, while the requirement set also demands a chain that keeps serving users. An
availability failure under Mode A produces an **unbounded halt** whose only remedies are outside the
protocol — no rule, contract or timeout can restart settlement without a new honest quorum and the
data — and Mode A offers no in-protocol way out. That is the requirement Mode A cannot satisfy. The D-3
assessment is retained, not edited away: it remains the record of why the counterexample alone was not
treated as a disproof of Mode A, and D-7 is the decision that the resulting unbounded halt is
unacceptable regardless.

### 5.3 The mechanism, exactly as specified

Mode B is normative in `spec/06-recovery-exceptions.html` (`REC-02`), within the boundary of
`REC-01`:

- **Permissionless and bonded.** Any account may invoke it; there is no operator, no DAO rescue and no
  validator quorum. The bond `B_REC(e) = B_REC_BASE · 2^n` escalates with the number of **attempts** in
  the preceding `REC_WINDOW`; it splits at invocation into a non-refundable component `B_REC_KEEP`,
  transferred to the protocol treasury on every attempt and sized to the cost of a spurious trigger
  (`B_REC_KEEP >= C_SPURIOUS = C_GAS_REC + C_REORG + C_DISRUPTION`), and a refundable balance returned
  only when the recovery completes; cancellation sends the whole bond to the protocol treasury
  (`ECON-06`(6)). A completed recovery also pays the invoker the fee-funded completion reward
  `REC_REWARD = min(REC_REWARD_CAP, floor(ALLOC_REC_PPM · pool_now / 1_000_000))` — bounded by the reward
  pool's realised balance and `0` when the pool cannot pay, while the recovery still completes
  (`ECON-02` clause 5(f)).
- **Delayed, and cancelled by honest progress.** The recovery takes effect only after
  `T_RECOVERY_DELAY`; during that window the acceptance of **any** valid batch extending the current
  checkpoint cancels it. Late certificates and late proofs are void for canonical purposes above the
  restored checkpoint, but a late certificate remains admissible as evidence.
- **Strictly above the latest L1-accepted checkpoint.** Nothing at or below that checkpoint may
  be changed by any path, and recovery restores the checkpoint rather than choosing a branch; it changes
  no configuration value and no validator set, and it is not a batch, accepts no data and creates no
  data-first admission path (D5 as relaxed by D-11: publication is permitted and advances no state; the checkpoint still advances only on a valid proof).
- **One objective trigger only.** A settlement stall: no batch extending the current L1 checkpoint
  accepted for `T_STALL = T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY + T_RECOVERY_MARGIN`,
  which must be strictly larger than the D6 envelope. A participant's local view, a halt, a missing
  certificate, a slow proof and an over-depth cap are not triggers.
- **Bound into the proof statement.** `configHash` and `recoveryGeneration` are public inputs, and
  the guest rejects a stale generation, so an alternative history is never accepted on execution
  validity alone (`PRF-01` (W4), `PRF-02`(5)–(6)).

Every timing, bond and depth term is **unmeasured** and is registered with its derivation in
`spec/09-parameters.html`.

### 5.4 What does not change

Mode A's binding obligations remain normative, with the recovery boundary added: `L1-FINAL-ONLY` (L2
consumes only Ethereum-final L1 facts) · `CONS-EPOCH-CERT` (epoch-scoped, permanently valid
certificates) · `L1-ADMIT-NO-EXPIRY` (no permissioned gate, no expiring range) · `UPG-PRESERVE`
(upgrades accept previously finalized history and are never a substitute for recovery, `GOV-03`(e)) ·
`DA-BACKLOG-CAP` (consensus-enforced unsettled-depth cap) · `HALT-RESTART` (resume only from
reconstructible finalized state, or from the checkpoint a completed recovery restored) ·
`WITHDRAWAL-DELAY` (derived from the whole pipeline). Ethereum-finalized checkpoints and every
already-accepted batch remain valid: recovery never revokes a batch accepted on L1 (`STATUS-06`).

### 5.5 Resistance analysis and review status

`REC-03` states what it would take to induce the trigger, why a sub-threshold coalition cannot
induce it inside the L2 fault model, the conditions under which it could (L1-level censorship, the absence of any
prover), and what cannot be bounded (off-chain profit, platform-level censorship). It is an argument,
not a proof, and **it requires independent review before the D-7 selection is treated as settled**; the
review must attempt to break it, and its named falsifiers — proving ceasing to be permissionless in
practice, `T_RECOVERY_DELAY` shorter than the time an honest prover needs to land a batch, or a bond
refundable on cancellation — withdraw the argument and reopen the selection under the D2 procedure.
Review round 4 owns that attempt (§7, Q-B1).

### 5.6 Related user decisions carried by the specification

- **D-8 — security is funded from L2 fees.** L2 execution and priority fees are collected in the L2 fee
  vault and swept permissionlessly through the preserved Bridge to the single L1 reward pool. Fees are
  revenue when they arrive at the pool, not when collected; there is no direct L1 claim, no escrow and
  no accounting entry against future settlement. The honest consequences are normative: rewards lag the
  settlement pipeline, an empty pool pays nothing, and a failed bridge stops rewards rather than
  creating a receivable (`ECON-02` clause 7). *(user decision D-8.)*
- **D-9 — slashed stake goes to the treasury.** No burn. The penalties are paid to the protocol
  treasury, and the reporter bounty is strictly below the total penalty so self-reporting is never
  profitable (`ECON-06`). *(user decision D-9.)*
- **D-12 — narrow forced inclusion ships in v1, superseding D-6 and D-10.** Any account may publish
  a transaction's data; from its due point the record must be resolved by the capped FIFO prefix of
  the due set, included in a proven batch or discharged as void on objective grounds, enforced at the
  proof (`FI-10`–`FI-14`). It is an upper bound on exclusion, never a lower bound on inclusion. The
  **general inclusion list** — arbitrary unpublished transactions, a queue, escrow or fee — remains
  deferred: the later upgrade must preserve the D2, D5 and permissionlessness invariants, including no
  reordering or revocation of past history and no privileged operator (`FI-PLANNED-01`). R10 is
  satisfied in its narrowed form. *(user decisions D-12 and D-10; D-11 supplies the L1 anchor.)*

---

## 6. Proof architecture

- **One combined guest** proving consensus evidence and execution. Composition is rejected as the
  default because latency is not binding under D6, one trusted computing base and one verifier route
  reduce the dominant long-run risk (stale-version acceptance), and recursive composition
  re-introduces the exact bug class that a recent SP1 advisory was about (`03-zkvm-feasibility.md`
  §9).
- Public inputs are **derived from L1 state** wherever they define authority: chain id, predecessor
  checkpoint, epoch, validator-set root, quorum threshold, configuration hash, recovery generation, data
  commitment, new state root, and the Fiat–Shamir challenge. A prover-supplied witness never defines the
  validator set (`PRF-03`), and the configuration hash and recovery generation are L1-derived and
  checked in-guest (`PRF-02`(5)–(6)), so an alternative history is never accepted on execution validity
  alone. *(user decision D-7: the statement carries the recovery authorization.)*
- Both RISC Zero and SP1 must implement the same statement. Acceptance policy, version pinning and
  upgrade rules are normative (`PRF-08`, `PRF-10`).

---

## 7. Open items and falsifiers carried forward

| ID | Item | Closed by |
|----|------|-----------|
| F1 | Epoch-handoff argument (M2): parent validity plus epoch-scoped certificates, with no cross-height lock carry-over | independent review; explicit argument in `CONS` rules (review round 3, R3A-03) |
| F2 | In-guest cost of the blob-path polynomial evaluation | measurement gate (implementation); not needed for calldata path |
| F3 | 2 s cadence under a permissionless global set | measurement gate + stated assumptions |
| F4 | Proving throughput formula inputs (cycles per L2 gas; proven cycles/s per machine) | measurement gate |
| Q-A1 | Is the Mode A availability counterexample reachable *inside* the stated assumptions? | **closed by D-7**: the selection no longer depends on the answer — the requirement set does not accept the resulting unbounded halt either way |
| Q-B1 | Does the `REC-03` resistance analysis survive independent review? Falsifiers: proving not permissionless in practice; `T_RECOVERY_DELAY` shorter than an honest prover needs to land a batch; a bond refundable on cancellation | adversarial review round 4, which must attempt to break it; *user decision D-7: the selection is not settled until that review attempts to break the analysis* |
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
- **Mode A (halt without rollback)** — rejected at D-7: D2 permits a safe halt, but an availability
  failure under Mode A produces an unbounded halt whose only remedies are outside the protocol, and the
  requirement set demands a chain that keeps serving users. Mode B is selected; see §5.
- **Burning slashed stake** — rejected by D-9: the penalty destination is the protocol treasury, with a
  reporter bounty strictly below the total penalty (`ECON-06`).
- **A general inclusion list in v1** — deferred by D-10 and D-12, not adopted: what ships is the
  narrow obligation over *published* data (`FI-10`–`FI-14`), and the later upgrade that adds a general
  list must preserve the D2, D5 and permissionlessness invariants (`FI-PLANNED-01`).
- **A new consensus design** — explicitly forbidden by the brief's preference for an established
  protocol.
- **Reusing the prior Etna seat/sortition committee** — a different security model (bonded seats,
  not stake-weighted PoS); reusing it would misrepresent seat share as stake.
