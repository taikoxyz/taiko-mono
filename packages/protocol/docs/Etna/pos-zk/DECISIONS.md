# Decision log — Etna PoS + ZK

Rules for this log: decisions are appended in order and never silently edited. A superseded
decision is marked **SUPERSEDED by D-<n>** and kept. Arguments, alternatives and dissent are
preserved so that a reader can audit *why* a rule exists.

Legend: **D-<n>** = project decision (not to be confused with the user's fixed decisions D1–D7).

---

## Delegation and model policy

**Policy (written before research started).**

- Bounded, low-reasoning-cost work (document extraction, source extraction, comparison tables,
  citation checks, terminology/consistency checks) is delegated to cheap, isolated sub-agents with
  narrow briefs and a single write target.
- Security-critical reasoning (consensus invariants, dynamic membership, proof statements,
  cross-mechanism arguments, disputed findings, final synthesis) is kept on the strongest available
  reasoning model, and is written by the lead or reviewed line-by-line by the lead.
- Independent adversarial reviewers are asked for verdicts, not confirmations; each reviewer is
  given the frozen snapshot, not the mitigation narrative.
- Every delegated artifact is verified against its sources before acceptance; a sub-agent's
  confidence is not evidence.

**Actual assignments** are recorded per phase below, including the model where the harness reports
it and the limitation where it does not.

---

## Decision entries

### D-0 — Project setup (2026-10-05)

- Baseline pinned to `7718753c1` (branch `etna-pos-zk`); working tree clean at start.
- Deliverables confined to `packages/protocol/docs/Etna/pos-zk/`.
- Prior accepted Etna research is read-only from branch `etna/converged-spec` at
  `a829f79723de9a09205660d9895418577cfe9aa9`.
- Normative rule identifiers use the scheme defined in `spec/index.html` §"Rule index"
  (prefixes: `GEN`, `STATUS`, `CONS`, `MEM`, `DA`, `L1`, `PRF`, `ECON`, `FI`, `REC`, `GOV`,
  `MIG`, `PARAM`, `INV`, `LIVE`). Each rule is stated exactly once; every other artifact links
  to it.

*(Further entries are appended by the phases below.)*

---

## Phase record

| Phase | Artifact | Status |
|-------|----------|--------|
| 0 — Baseline | `00-baseline-and-lessons.md` | in progress |
| 1 — Requirements & threat model | `01-requirements-and-threat-model.md` | draft written |
| 2 — Parallel research | `02-consensus-survey.md`, `03-zkvm-feasibility.md` | in progress |
| 3 — Architecture selection | `04-architecture-decision.md` | pending |
| 4 — Complete draft | `spec/index.html` + pages | pending |
| 5 — Learning site | `learn/index.html` + lessons | pending |
| 6 — Adversarial review | `iterations/NN-round.md` | pending |
| 7 — Revision | updated spec + learn + ledger | pending |
| 8 — Final verdict | README verdict + final report | pending |

---

### D-1 — Consensus family: Tendermint/CometBFT-class BFT (2026-10-05)

**Question.** Which established consensus protocol should carry a permissionless L2 PoS chain at a
2-second cadence whose finality evidence must be verified inside a zkVM?

**Inputs.** `research/consensus-survey-raw.md`, `research/recovery-and-withholding-raw.md` §1,
`research/zkvm-feasibility-raw.md` §3.

**Positions considered.** (a) Tendermint/CometBFT; (b) the HotStuff lineage (HotStuff-2 /
Carry-the-Tail); (c) DAG-based BFT (Narwhal/Bullshark/Mysticeti); (d) a checkpoint/attestation design
with BLS aggregates. The survey scored them 22 / 18 / 16 / 15 out of 25.

**Decision.** Tendermint/CometBFT-class BFT: one block per height, single-slot finality, the published
lock / proof-of-lock-change rule retained unchanged, Ed25519 vote signatures, **one head commit
certificate verified per batch**, validator sets derived from L1-committed TAIKO stake, and
epoch-scoped certificates that remain valid forever.

**Rationale.** Decisive criteria: finality evidence small and cheap to verify in-guest; published
safety and liveness proofs that transfer with minimal modification; the lock rule as the canonical
answer to the withheld-certificate problem; dynamic membership expressible as an authenticated handoff.
The independent survey's recommendation and the lead's parallel analysis agreed.

**Modifications, with proof status:** M1 L1-derived sets; M2 epoch handoff and lock carry-over (the
delicate one — review target F1); M3 forced inclusion as a proposal-validity rule; M4 adaptive timeouts
expressed in seconds; M5 removal of commit slack. See `04-architecture-decision.md` §2.1.

**Dissent.** None at Phase 3; DAG-BFT is retained as a v2 candidate in LIM-02.

---

### D-2 — One combined guest; blob binding without in-guest MSM or pairings (2026-10-05)

**Findings that forced the decision.** In-guest BLS12-381 MSM and pairings are UNVERIFIED on both
backends (SP1 exposes no pairing syscall at all), and a keccak commitment to data is **not** the
protocol's KZG commitment, so a naive blob path is unsound: a proposer could publish different bytes
under a versioned hash the proof never touched.

**Decision.** (i) One combined guest proving consensus evidence, execution and data binding; composed
proofs rejected as the default. (ii) The blob path binds through `BLOBHASH` equality in the same
transaction, an on-chain KZG opening verified by the EIP-4844 point-evaluation precompile at a
Fiat–Shamir challenge point derived **on-chain**, and an in-guest Lagrange evaluation of the executed
blob field elements at that same point. The calldata path — the contract hashing the exact calldata —
is retained unconditionally because it needs no probabilistic argument.

**Status.** Binding argument **Proven** with named premises (KZG binding, random-oracle Fiat–Shamir,
canonical field elements, correct in-guest field arithmetic); in-guest cost **unmeasured**
(implementation gate). See `spec/05-proof-statement.html` PRF-07.

---

### D-3 — D2 mode: **Mode A selected**, with a recorded dissent (2026-10-05)

**Procedure.** D2 step 1 was performed first (`research/mode-a-feasibility-analysis.md`). An
independent research stream was then explicitly asked to *break* Mode A.

**Dissent (recorded, not edited away).** `research/recovery-and-withholding-raw.md` §3.3 concluded
**"Mode A is not feasible as stated"**, with the counterexample *certified-but-unavailable data*: a
quorum signs a block whose data exists only in node memory; the holders vanish; under D5 no proof can be
built; Mode A forbids discarding the block, so settlement halts, possibly permanently. Secondary
concerns: 2 s one-slot finality versus permissionless global membership, and a halt preventing exits.

**Lead assessment — disagrees with the verdict, agrees the counterexample is real.** The counterexample
is disclosed in the specification. It is not evidence of Mode A infeasibility, because D2 step 1 states
that a safe halt outside the stated liveness assumptions is permitted and that its existence alone is
not evidence of infeasibility. Every requirement Mode A must satisfy is either a **safety** requirement
(satisfied: CometBFT safety under < 1/3, epoch-scoped permanent certificates) or an **explicitly
conditional liveness** requirement (R6 states its own conditionality; R4 reads "under explicit,
justified assumptions"). The counterexample is precisely a failure of the stated availability
assumption A-CONS-5 / A-DA-2. Two further points: Mode B does not remove the cause, only the symptom —
it requires a *new* honest quorum and the L1 checkpoint's data, so if participation is permanently gone
it restores nothing while adding the recovery surface that D2 step 5 makes a blocker; and the failure
class already exists in the current production design (`Inbox.sol:246-258`, the June 2026
forced-inclusion void, an owner-only `init3()`), which shows it must be disclosed and mitigated, not
that it is disqualifying.

**Decision.** **Mode A selected.** Binding obligations: `L1-FINAL-ONLY`, `CONS-EPOCH-CERT`,
`L1-ADMIT-NO-EXPIRY`, `UPG-PRESERVE`, `DA-BACKLOG-CAP`, `HALT-RESTART`, `WITHDRAWAL-DELAY`.
Mode B is specified in `spec/06-recovery-exceptions.html` REC-02, and its D2-step-5 blocker is recorded
in REC-03 as an **open blocker**, not a disclosure item.

**Carried into review as question Q-A1:** is the availability counterexample reachable *inside* the
stated assumptions — i.e. is the premise vacuous rather than conditional? If yes, this decision must be
reopened under D2 step 2. Independent review of this reasoning is scheduled in `iterations/01-round.md`.

---

### D-4 — Membership and economics: self-bonded TAIKO on L1, no delegation in v1 (2026-10-05)

**Findings that constrain the decision.** TAIKO has a fixed supply with no mint path and no burn path on
L1 today; `getVotes` is not a stake oracle because `renounceVotingPower()` zeroes votes while the
balance stays intact; no staking exists and the Inbox bond mechanism is switched off (`minBond = 0`,
`livenessBond = 0`), so **no TAIKO is at risk in the system today**; provers are unpaid and proving is
whitelisted; the withdrawal delay must be derived from the whole settlement pipeline, not from proving
latency; slashing must follow stake at offence time; the convex correlated penalty makes the safety
threshold and the confiscation threshold coincide; per-address caps do not bound concentration.

**Decision.** An L1 staking contract holding the existing TAIKO; effective stake defines voting power;
epoch set roots committed with one-epoch lookahead; **no delegation in v1**; unbonding delay derived
from the settlement pipeline; convex correlated penalties; slashed-stake destination left as an
**explicit human decision** (ECON-06) rather than chosen silently.

---

### D-5 — Migration: in-place upgrade, no replacement addresses (2026-10-05)

**Decision.** Preserve the D3 surfaces by upgrading implementations in place, respecting the frozen slot
prefix and per-contract append-only gaps documented in `research/taiko-baseline-contracts.md` §7;
remove operational privileges (`ProverWhitelist`, `ProposerChecker` gating, owner-only `init3()`, the
golden-touch anchor path as an ordering authority) while retaining DAO upgrade authority; and treat the
removal of data-first submission as a structural change rather than a configuration change.

---

## Open questions carried into the review rounds

| ID | Question | Closed by |
|----|----------|-----------|
| Q-A1 | Is the Mode A availability counterexample reachable *inside* the stated assumptions? | review round 1 (consensus/liveness reviewer) |
| Q-A2 | Is the "one certificate per batch" argument sound for the whole prefix? | review round 1 |
| Q-A3 | Does the blob binding survive a grinding prover and a malicious contract caller? | review round 1 |
| Q-A4 | Can a sub-threshold coalition force a permanent halt more cheaply than the protocol's deterrence covers? | review round 1 (economics) |
| Q-A5 | Are all D5/D7/D3 obligations preserved by the migration rules? | review round 1 (compliance) |
| F1 | Epoch-handoff lock carry-over argument | review round 1 |
| F2 | In-guest blob evaluation cost | measurement gate |
| F3 | 2 s cadence under a permissionless global set | measurement gate |
| F4 | Throughput inequality inputs (cycles per L2 gas; proven cycles/s per machine) | measurement gate |

---

## Phase record (updated)

| Phase | Artifact | Status |
|-------|----------|--------|
| 0 — Baseline | `00-baseline-and-lessons.md` + `research/taiko-baseline-contracts.md` | consolidation running |
| 1 — Requirements & threat model | `01-requirements-and-threat-model.md` | draft written |
| 2 — Parallel research | raw files complete; `02`/`03` consolidations running | in progress |
| 3 — Architecture selection | `04-architecture-decision.md` | **written; Mode A selected** |
| 4 — Complete draft | `spec/*.html` | in progress |
| 5 — Learning site | `learn/*` | pending |
| 6 — Adversarial review | `iterations/NN-round.md` | pending |
| 7 — Revision | updated spec + learn + ledger | pending |
| 8 — Final verdict | README verdict + final report | pending |

---

### D-6 — User decision: **forced inclusion is removed from the specification** (2026-10-05)

**Authorization.** The user explicitly directed that forced inclusion may be removed from the
specification entirely. This is a **user-authorized relaxation of hard requirement R10**, which reads
"Specify censorship resistance and forced inclusion without introducing an override that violates D2".
The user is the requirement owner; the relaxation is recorded here rather than absorbed silently, and
it changes the scope of the final verdict.

**What is removed.** FI-01 … FI-05 (request format and fee, inclusion duty and L1 backstop, escape
hatch, the no-reorder guarantee, griefing controls), the L1 forced-inclusion queue and its escrow, the
`forcedInclusionCommitment` public input and its guest check, the forced-inclusion duty in proposal
validity, the forced-inclusion fee terms in the reward budget, all forced-inclusion parameters, and the
censorship offence in the penalty catalogue.

**What replaces it: nothing on L1.** The protocol provides **no per-transaction inclusion guarantee**
and no L1 escape path by which a user can force a transaction into L2.

**What remains, stated honestly as a conditional statistical property, not a guarantee.**

1. Proposer selection is hash-based and weighted (CONS-06), so a coalition holding less than one third
   of the voting power is selected as proposer for strictly fewer than one third of slots in
   expectation, and a transaction that reaches honest proposers is included by the first honest
   proposer that has room for it.
2. That resistance is conditional on the network assumption A-CONS-2: it holds only while a censored
   transaction can still reach honest validators. **A network-level adversary that isolates a user from
   every honest proposer can exclude that user's transactions indefinitely, and with forced inclusion
   removed the protocol offers no remedy.**
3. Because withdrawals are initiated by an L2 transaction, sustained L2 censorship can therefore also
   prevent a user from **starting** a withdrawal. This is a disclosed consequence, not a bug, and it
   must be stated in the specification, the learning course and any user-facing material.

**Effect on the requirement matrix.** R10 is restated as: *"State censorship resistance honestly. The
protocol provides statistical resistance from proposer rotation and gossip under A-CONS-2 and provides
no L1 forced-inclusion path; no override that violates D2 may be introduced."* R10 is thereby
**satisfied in its relaxed form and not satisfied in its original form**; the final report must say so.

**Effect on findings.** Round-2 Criticals R2-LIV-01, R2-LIV-03 and R2-LIV-04 were all forced-inclusion
defects and are closed by removal. The round-2 Highs that depended on the forced-inclusion backstop are
closed with them. R2A-01 (epoch-lookahead gate) is unaffected and is fixed by a two-epoch lookahead.


---

### D-7 — User decision: **Mode B selected** — permissionless L1 recovery of unsettled history (2026-10-05)

**Instruction.** "I have to choose roll back, otherwise the chain will dead." This selects the fallback
authorised in D2. It is a **material design change**: the guarantee attached to a PoS confirmation above
the last Ethereum-finalized checkpoint becomes **provisional**, and the protocol gains a permissionless
mechanism that can discard that history.

**D2 procedure, completed.** (1) Mode A was investigated first and its obligations and constraints were
written down. (2) The specific requirement it cannot satisfy is now concrete: D2 permits a safe halt, but
the requirement set also demands a chain that keeps serving users, and an availability failure under
Mode A produces an **unbounded halt** whose only remedies are outside the protocol. (3) The attempted
safe-recovery constructions were enumerated in `research/mode-a-feasibility-analysis.md`; each either
requires discarding unsettled history (this decision) or leaves the halt in place. (4) This entry records
the selection; the resistance analysis required by D2 step 5 is written as rule `REC-03` in
`spec/06-recovery-exceptions.html`, and an independent review of that analysis is required before the
selection is treated as settled — it is scheduled for review round 4.

**What does not change.** Ethereum-finalized checkpoints and every already-accepted batch remain valid;
D5 holds unchanged and recovery may not introduce a data-first path; the recovery path is permissionless
and bonded with no operator, no DAO rescue and no discretion over the restored checkpoint or the
validator set.

**Consequence that must be stated everywhere.** A confirmation above the last accepted checkpoint may be
replaced. Every user-facing artifact must say so. The status label becomes **PoS-certified /
provisional**, and no artifact may call such a confirmation irreversible.

### D-8 — User decision: **security is funded from L2 fees** (2026-10-05)

L2 execution and priority fees are the funding source for validator rewards and proving costs. The
specification must define the path from an L2 fee vault to the L1 reward pool, using the preserved
Bridge for the transfer, with the honest consequences: rewards are delayed by the settlement pipeline,
an empty pool pays nothing, and a failure to bridge stops rewards rather than creating a claim on
future revenue. Every term remains unmeasured until the economics spike.

### D-9 — User decision: **slashed stake goes to the treasury** (2026-10-05)

No burn. The penalty destination is the protocol treasury, with a reporter bounty paid as a fraction
strictly less than the total penalty so that self-reporting is never profitable. The earlier "burn"
option is removed from the specification and from the course.

### D-10 — User decision: **forced inclusion is deferred to a protocol update** (2026-10-05)

Forced inclusion is **not** part of the first version, to keep it simple, and is added later by an
upgrade. The specification must therefore contain two things: the honest statement that v1 has no
forced-inclusion path (rule `FI-REMOVED-01`), and a **planned-update clause** stating what the upgrade
must preserve when it adds forced inclusion — no reordering or revocation of past history, no data-first
path, no privileged operator, and the same atomic data-and-proof rule. Until that upgrade ships, R10
remains satisfied only in its relaxed form.



## D-11 — Data may be published before the proof (relaxes D5)

**Decision (design owner, 2026-10-06):** a batch's data MAY be published to blobs in an
earlier L1 transaction; a later proof MAY reference blobs published in a previous
transaction, or blobs carried in the same transaction. **Data sitting in blobs has no
effect on the protocol's L1 state** — it becomes relevant only when a proof references it.
Therefore there is no "data-first path" in the sense D5 forbade: the protocol state still
advances only on a valid proof.

**Why this is right.** D5 required data and proof in one transaction, which made a certified
batch's data exist only in L2 gossip until landing: a window of roughly the proving envelope
(30-60 minutes at nominal) in which the chain cannot be reconstructed from L1 alone, where
data can be withheld, and where forced inclusion has nothing on L1 to anchor to. Posting data
first collapses that window to the time between certification and publication, and since
publication is permissionless, withholding then requires that *no* observer publish — a far
stronger condition than a single proposer declining to land a batch.

**What this changes downstream** (to be specified): the data-binding rule becomes a reference
to recorded blob hashes rather than to the accepting transaction's own blobs, so publication
must be recorded on L1 while the blobs are still retrievable; the June-2026 failure mode
(blobs expiring before they are proven) is controlled by a proving deadline well inside blob
retention, whose consequence must be defined; forced inclusion becomes anchorable again and
D-6/D-10 must be revisited; and Mode B's trigger window shrinks but does not vanish.

**Status:** decided; specification changes pending.



## D-12 — Narrow forced inclusion ships in v1 (supersedes D-6 and D-10)

**Decision (design owner, 2026-10-06):** v1 includes a **narrow forced-inclusion rule**, not a
general inclusion list. Any account may publish a transaction's data to L1; the protocol then
requires that published-but-unproven data be **proven within the deadline or discarded and
re-published**, which bounds the time a censoring proposer can keep a user's transaction out
of the chain while the chain otherwise runs.

**Why it became possible.** D-6 removed forced inclusion and D-10 deferred it because, under
the old D5, a batch's data existed only off-chain until landing, so an inclusion guarantee had
nothing on L1 to anchor to. D-11 puts the data on L1 before the proof, which supplies the
anchor.

**Constraints on the rule (must be respected in the specification):**
- The obligation is an **upper bound on exclusion, never a lower bound on inclusion**: the rule
  fixes a deadline by which forced data must be proven, not a requirement that every batch
  include it.
- Inclusion is a **capped FIFO prefix** of the due set, so a backlog drains over successive
  batches instead of halting the chain — the failure mode that produced review round 1's
  critical finding (due-set versus per-batch cap) must not return.
- The enforcement point is the **proof**, not an admission gate on `land`: the guest checks
  the batch's execution against the due set it can derive from L1 state.
- It does **not** give the protocol a pause or a discretion: no owner, DAO or operator may
  suppress, reorder or extend forced data.

**Status:** decided; specification changes pending, and expected to reopen the forced-inclusion
machinery that D-6 deleted.



## D-13 — One proof object per batch, aggregated n-of-m underneath

**Decision (design owner, 2026-10-06):** the protocol accepts **exactly one proof per batch**,
and underneath, that one proof is an **n-of-m aggregated proof**, which the protocol treats as
a single proof. Verification cost on L1 stays one verification; the redundancy lives inside the
aggregation, off-chain.

**What this buys.** Settlement stops being "soundness of the weakest approved backend". A
forged or unsound checkpoint now requires every one of the n independent implementations inside
the aggregation to accept a false statement, while the on-chain cost is unchanged — the cost
that a plain k-of-n requirement would have multiplied on every batch.

**What the specification must define:**
- **The aggregation program is itself a registered, rotatable image** and a single point of
  trust for the inner checks; its rotation path matters more, not less, and must be bounded
  rather than DAO-cycle-slow.
- **The aggregation proof's public input must expose which backend families contributed** (a
  bitmap or a commitment to the family set), so the **Inbox enforces the required count for the
  purpose**: settlement needs at least 1, a **withdrawal root needs at least k**. This replaces
  "k separate proofs verified on L1" in L1-13 with "one proof attesting at least k distinct
  families", unifying settlement and withdrawal roots under one verification path.
- **Every inner proof proves the same journal** under the same GEN-05 encoding; PRF-01 is
  unchanged and the statement is not weakened by aggregation.
- **The aggregation program must verify each inner proof** against its own registered
  verifier, and must not be able to claim a family it did not verify; the L1 count check exists
  because the program is trusted, not because it is assumed honest.
- **Cost moves to the prover**: the aggregator's work grows with m, and S1 must measure
  aggregation cost (verifying inner proofs inside a circuit is expensive) before n and m are
  fixed. The Phase B plan's S1 gate must gain an aggregation line.

**Status:** decided; specification changes pending. Supersedes the plain k-of-n-on-L1
construction added earlier the same day.


### Correction to D-11's implementation note (found by the D-11 agent, 2026-10-06)

The lead's brief asserted that "the EIP-4844 point-evaluation precompile only operates on blobs
carried by the executing transaction, so a proof referencing a previously published blob cannot
use it". **That is false.** What is transaction-scoped is the **BLOBHASH opcode**, which returns
zero for a blob the executing transaction does not carry. The precompile at `0x0A` is not: its
192-byte input is `(versioned_hash, z, y, commitment, proof)`, and it checks
`kzg_to_versioned_hash(commitment) == versioned_hash` and verifies the KZG opening of the
**supplied** commitment at `z`. Verified against the execution-specs reference implementation
and the EIP-4844 text.

**Consequence — better than the design the brief anticipated.** The reference landing path keeps
the **full DA-03 opening check**: replace `blobhash(i)` with the *recorded* versioned hash from
the publication record, then require `kzg_to_versioned_hash(commitment_i) == recordedVh_i` and
`verify_kzg_proof(commitment_i, z_i, y_i, proof_i)`, with `z_i` still derived on-chain from the
landing statement's transcript. The recorded versioned hash is trustworthy because the consensus
layer already verified the publication transaction's `blob_versioned_hashes` against the actual
blob sidecars. **Content binding is not weakened**; what is lost is same-transaction equality and
same-transaction availability of the bytes — the latter covered by the archive duty and the
proving deadline.

**The variant the brief anticipated is unsound and is recorded as rejected**: a recorded hash
plus only an in-guest evaluation ties the bytes to nothing, because the guest computes that
evaluation from the very bytes it already executed. A precompile-less reference path would
require the guest to recompute each blob's KZG commitment (MSM) or verify the opening (pairings)
in-guest, and both are recorded as UNVERIFIED on both backends.



## D-14 — Liveness by L1 heartbeat eligibility; no rule removes weight (resolves F5, closes F6)

**Decision (design owner, 2026-10-06):** the inactivity decay is **withdrawn**. No rule reduces a
validator's weight. Instead, eligibility for a future epoch's set version requires an **L1
liveness attestation (heartbeat)** within a window: a validator that stops attesting is simply
**not selected** into the next committed set version. Its stake, weight and standing are
untouched, and re-attesting restores eligibility for the following boundary.

**Why B over the bounded-decay option.** Decay bounds the F5 hazard but does not remove it, and
— decisively — it cannot repair the failure it was commissioned for: participation evidence is
written by `land`, so a full stall writes none, every validator's record goes stale together,
decay becomes uniform, and ratios are preserved. It therefore covered **attrition only**, and
only up to a third offline (the safety guard blocks removal beyond that). A ransom attack is a
cohort going silent *at a moment*, which is exactly the case decay is blind to.

**Mechanism.**
- A validator registers an **ECDSA (secp256k1) heartbeat key on L1 at bonding time**, distinct
  from its Ed25519 consensus vote key, because L1 has no Ed25519 precompile and `ecrecover` is
  cheap. Both keys bind to the same entry.
- `lastHeartbeatAt(v)` is recorded on L1; anyone may submit a heartbeat, and a relayer MAY batch
  many signatures in one transaction — the protocol does not care who pays.
- A validator is **eligible** for the set version committed for epoch *e* iff it attested within
  `HEARTBEAT_WINDOW` ending at that version's commit point (the existing two-epoch lookahead).
  Ineligible entries are **excluded from the root**, never decayed.
- `CONS-16`'s L1-time rotation draws the restart epoch's set from eligible validators, so a
  stalled chain resumes with a set that is demonstrably reachable.
- No confiscation, no slashing, no weight change: D7 and D-9 are untouched.

**Safety.** No rule removes weight within a set version, so a coalition below one third cannot
gain share by rule and `A-CONS-1`'s per-set-version framing stands unmodified. Excluding an
honest validator requires **censoring its own L1 heartbeat**, a far stronger assumption than an
L2 stall.

**Liveness.** A cohort that stops attesting is excluded at the next boundary; the remaining
eligible weight becomes the whole of `W'`, so the quorum predicate is reachable and production
resumes.

**Honest costs, to be stated in the specification.** A periodic L1 transaction per validator per
window; a second key per validator and its registration; an operational lapse becomes an outage
(a validator that forgets to attest loses its slot until it re-enters); and if the honest
majority's L1 heartbeats can be censored, exclusion returns — recorded as the new falsifier.

**Status:** decided; specification changes in flight.



## D-15 — v1 has no permissionless recovery; a governance stall-resolution rule replaces it

**Decision (design owner, 2026-10-06):** Mode B's permissionless bonded recovery
(`REC-02`/`REC-03`/`REC-04`) is **withdrawn from v1** and replaced by a **timelocked,
resume-only governance action**. Users are protected by the existing exit guarantee, not by a
recovery mechanism.

**Why.** Recovery failed independent review three times: round 4 found the authorization was a
tautology; the repair introduced an invoker-claimed retirement endpoint; the repair of that failed
on bundle maximality (any account can complete with a one-certificate bundle and wedge the chain
permanently) and on L1's inability to verify the evidence at all (no Ed25519 precompile, no
per-signer weights stored). Each repair was correct against the previous finding and opened a new
one. The remaining path needs proof-based completion plus maximality plus anchor recency — new
mechanism with no review history, and the part of the design with the worst evidence behind it.

**What is kept.** `REC-01`'s boundary is unchanged and remains the safety property: nothing at or
below the latest L1-accepted checkpoint is ever rewritten, and a confirmation above it is
**provisional**. `MEM-15`'s exit — a withdrawal proven against the last accepted checkpoint with no
new L2 blocks, no quorum and no validator — is unchanged and is what makes a slower fallback
tolerable.

**The replacement — `GOV-04` (stall resolution).**
- **Trigger:** settlement stalls, `block.timestamp − lastAcceptedBatchTime ≥ T_STALL_GOV`.
- **Effect:** resume from the latest L1-accepted checkpoint, discarding **everything above it** —
  not a certified subset. So `resumeHeight = lastLandedHeight + 1`: the boundary is fixed by L1
  state alone, and there is no bundle, no certificate, no maximality question and nothing for L1 to
  verify beyond its own record.
- **Timelock:** `T_GOV_RESUME`, long enough that every user can exit via `MEM-15` before it
  executes. Governance cannot shorten it for a queue entry already posted.
- **Resume-only.** Governance may not choose a state, a checkpoint or a height; all three are fixed
  by the rule from L1 state. Nothing at or below the accepted checkpoint may be touched.
- **Void on progress:** if the checkpoint advances before execution, the action is void, and any
  account may cancel the queued entry.
- **Disclosed:** the guarantee class states that clearing a stall depends on **governance liveness**,
  with no protocol-level bound. This is a social-layer assumption and is recorded as one.

**The generation fix that makes this sound.** Under a full-range discard, the discarded branch's
certificates must not be re-landable. The round-4 finding was that the generation bound the proof
and not the history. The fix is now affordable because there is no recovery bundle to carry: **the
recovery generation is a field of the signed vote and header bytes**, the governance action
increments it, and validators sign the new generation. Old certificates carry the old generation and
are void at the acceptance rule. This replaces the retirement-range machinery entirely.

**Withdrawn with it:** the recovery bond and its escalation, the completion transition and its
cancellation predicate, the certificate bundle and its verification, the recovery reward and its
allocation share, the recovery anchor, the `max(lastLandedHeight + 1, resumeHeight)` contiguity form,
and every parameter that existed only to size them.

**Status:** decided; specification changes in flight. This supersedes D-7.



## D-16 — v1 ships the core; the add-on mechanisms are deferred to a register (Option A)

**Decision (design owner, 2026-10-06):** v1 ships the **core** only. Four mechanisms are **deferred**
to a later protocol update, each with its guarantee explicitly disclosed as absent. A durable
**deferred-work register** (`DEFERRED.md`) records each one, its findings and its revive criteria so
none of the work is lost.

**Evidence.** Six review rounds, zero clean. Every Critical in rounds 4, 5 and 6 sits in a mechanism
layered on the core, while the core itself - consensus safety per set version, the proof statement,
the fee reconciliation, the data binding, locks, uniqueness and the checkpoint boundary - has been
re-attacked in every round and has not broken. Three repairs introduced defects of the same class as
the finding they closed. The remaining two rounds cannot supply a review cycle to four new mechanisms.

**Kept in v1.**
- L1-anchored PoS sequencing with TAIKO stake on L1 (D1, D4, D7).
- Validity-proof settlement with the batch data bound to the accepting transaction, carried or
  referenced through a publication record (D-11), including the proving deadline.
- The checkpoint **boundary**: nothing at or below the latest L1-accepted checkpoint is ever
  rewritten; a confirmation above it is provisional.
- The **exit** from the last settled state (MEM-15), once its contradiction with the
  withdrawal-root path is resolved.
- k-of-n withdrawal roots attested by distinct backend families, and the rule-triggered,
  self-expiring withdrawal veto. Without aggregation, a root is k attestations verified on L1.
- The signed **recovery generation** as the mechanism that scopes certificates, locks and
  uniqueness.

**Deferred, with disclosure.**
1. **Narrow forced inclusion (D-12)** - the FI machinery. v1 has no inclusion obligation; a proposer
   that excludes a transaction is not in breach. Disclosed as the censorship gap, which is the
   R10 relaxation already recorded.
2. **Heartbeat eligibility (D-14)** - membership has no liveness gate. A cohort that stops
   participating halts production until an upgrade, and `A-CONS-1` is unchanged.
3. **The governance stall resolution (D-15)** - v1 has **no recovery path of any kind**: permissionless
   or governance-mediated. A settlement stall halts the chain; funds are safe and the exit works, but
   clearing the stall requires a **future protocol update whose procedure is not yet specified**.
   That last clause is the honest disclosure, and it is the price of dropping D-15.
4. **Aggregation (D-13)** - settlement accepts one proof from one registered backend, so soundness is
   that of the weakest approved backend. Disclosed; withdrawal roots keep the k-family requirement.

**Status:** decided; rollback in flight.



## D-17 — Heartbeat eligibility revived with a bounded pre-signing horizon; the rotation stays deferred

*Increment 02. Append-only: D-14 and D-16 stay as written; this entry records what changed.*

**Decision (design owner, 2026-10-07):** increment 02 revives **MEM-13** (L1 heartbeat eligibility) as a
live rule. It does **not** revive **CONS-16**: the L1-time-keyed rotation stays deferred and tombstoned,
because its precondition has no L1 referent and a completer would supply the closing height as an
unverifiable claim (**F7**, carried and sharpened). The increment ships MEM-13 alone; the pre-signing
horizon is handled by the bounded `HEARTBEAT_ANCHOR_AGE` term of the new payload, not by a per-window
challenge.

**What is live.** Eligibility for a set version requires an accepted heartbeat inside the heartbeat
window containing that version's commit point. The payload binds a versioned domain tag
(`DOMAIN_HEARTBEAT`, `"ETNA_HEARTBEAT_V2"`), the chain id, the entry, a window index, a strictly
increasing sequence number, an L1 anchor block number and the anchor block hash; acceptance requires the
named window to be current and unrecorded, the sequence to advance, and the anchor to be a real L1 block
no more than `HEARTBEAT_ANCHOR_AGE` blocks old. The recorded eligibility instant is the named window's
start, never the carrier's time, so a signature cannot be replayed or refreshed by submitting it later.
The key is an ECDSA heartbeat key registered at bonding, distinct from the Ed25519 consensus key,
owner-rotatable forward-only, and never a consensus key. Ineligible entries are excluded from `R_k`,
`TotalVP_k` and `n_k` — never decayed, slashed or removed — and re-attesting restores eligibility at
the next commit point. If no active entry is eligible when an append is due, `commitSet()` reverts and
the append is missed. No rule removes weight: D-14 is unchanged, and the boundary, the exit, D-8/D-9 and
D-11 are not reopened.

**The pre-signing horizon.** It is bounded by the `HEARTBEAT_ANCHOR_AGE` term of the new payload, not
closed by a per-window challenge: full closure would add one permissionless transaction per window and
make a single censored transaction exclude the whole roster. The residual — a signature made within the
anchor age before the window it names can be accepted in that window — is the named falsifier **F9**.
**F8** is carried and sharpened: an adversary able to censor, delay past the window, or price out honest
L1 heartbeats excludes honest validators from future set versions at no slashable cost and can raise its
own share of those versions; the protocol does not detect or resist it. The declared non-fix is stated
wherever the mechanism is summarised: a declaration of presence is not proof of participation, so a
cohort that keeps heartbeating keeps its weight, and the rule changes who is selectable, never what a
committed version requires. The new terms (`HEARTBEAT_WINDOW`, `HEARTBEAT_ANCHOR_AGE`,
`HEARTBEAT_BATCH_CAP`) remain `unmeasured` with stated relations, never values.

**Why CONS-16 is not revived.** `h_close(e)` — the highest height any validator produced in a stalled
epoch — is an L2 fact. L1 state holds neither the L2 tip nor the highest produced height,
`lastLandedHeight` is only a lower bound, and the completion record's value would be a claim by the
completer; a false claim re-judges a produced height, makes its certificate unverifiable against the
boundary record and strands value above the latest accepted checkpoint, which is the class of
history-replacing transition `REC-01(a)` forbids. CONS-16 therefore MUST NOT be implemented — by any
client, contract, parameter, interface, migration script or later text — until an L1-verifiable referent
for `h_close` exists, and its tombstone and its `DEFERRED.md` pointer stay intact. While the gate is
open, `REC-01`'s text is literally unchanged and `DEFERRED.md` §2 records what a revival would need.

**Status:** decided; specification, register, index and course changes in flight. The increment ships
only after its own review round is clean.

**Addendum (increment 2 second review, INC2R2-UD-02).** The entry above stands as the historical record; this addendum records the correction. Its "What is live" paragraph states the withdrawn reading — "an accepted heartbeat inside the heartbeat window containing that version's commit point" — and the withdrawn restoration — "re-attesting restores eligibility at the next commit point". The shipped predicate is `MEM-13(3)`: `lastHeartbeatSeq(v) > 0` **and** `lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW` — an entry with no accepted heartbeat is ineligible regardless of the arithmetic (R2-DI-01) — where, for the version committed for epoch `e`, with `C(e) = max(e − LOOKAHEAD_EPOCHS, e_0)` and `L1_first(C(e)) = L1_0 + (C(e) − e_0) · EPOCH_LEN_L1`, `I*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW`, computed inside `commitSet()` from the activation record on an L1 **block-height** grid (window `w` is `[w · HEARTBEAT_WINDOW, (w+1) · HEARTBEAT_WINDOW)`; acceptance requires the named window to be the including block's window; `lastHeartbeatAt(v)` is the named window's start block, never a carrier timestamp), so the commit block, its timestamp and its position select no roster. Re-attestation restores eligibility for every version whose evaluation window is the window the new heartbeat names or the one immediately after it — including an append that is still pending, because `I*(e)` does not move (`MEM-13(4)`). Two limits the entry above does not carry are recorded with it: the change-timing Open of `MEM-13(6)` (a `HEARTBEAT_WINDOW` change landing after the first boundary of the new grid strictly following an active entry's record `A` can exclude that entry from one or more versions — a **contiguous run**, every version evaluated before the entry re-attests whose evaluation instant falls in `(A + W', A + W_old]`, about `(W_old − W') / EPOCH_LEN_L1` of them when a backlog is drained in a single block — and the Open names the sole remaining caller influence on `I*(e)`: while a change is pending, an append caller's ordering relative to it selects whether the version is evaluated under the old or the new value, bounded to the pending change and of F8's ordering class; falsifier and closing options there) and the wall-clock-variability cost of the height grid (the duty is one attestation per `HEARTBEAT_WINDOW` L1 blocks, so the cadence in seconds is variable and `unmeasured`; `MEM-13(7)(g)`). D-14 and D-16 are untouched; D-14's original mechanism bullet — eligibility within a `HEARTBEAT_WINDOW` ending at that version's commit point — is preserved with them as history and is superseded by the derived instant recorded here. *(INC2R2-UD-02: the correction is recorded by addendum and the original text above is preserved. R2-DI-01/R2-DI-02: the predicate carries the non-zero-sequence guard, and the change-timing Open is the contiguous run with the pending-change ordering influence named.)*

**Further addendum (increment 02, third review round, R3-LT-01).** The addendum above records the derived instant `I*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW) · HEARTBEAT_WINDOW` and the sequence guard, but not the launch transition; this further addendum records the correction and leaves the entry and the addendum above as history. For exactly the two epochs whose clamp resolves to `e_0` — `e = e_0 + 1` and `e = e_0 + 2`, the first two filtered versions — the instant is shifted forward by two full heartbeat windows: `w*(e) = floor(L1_0 / HEARTBEAT_WINDOW) + 2` and `I*(e) = (floor(L1_0 / HEARTBEAT_WINDOW) + 2) · HEARTBEAT_WINDOW`; the predicate's one-window slack therefore admits the counting window `[(floor(L1_0 / HEARTBEAT_WINDOW) + 1) · HEARTBEAT_WINDOW, (floor(L1_0 / HEARTBEAT_WINDOW) + 2) · HEARTBEAT_WINDOW)`, which starts at or after `L1_0` with the full length `HEARTBEAT_WINDOW` whichever block of its window `L1_0` falls in, so a prepared entry cannot win a one-block race and fix the first two filtered rosters. The entries for those two epochs MUST NOT be appended before that counting window closes — the gate applies to every appender alike and names no entry or caller — and from `e_0 + 3` the unshifted definition resumes, a lower later threshold admitting, never excluding. The cost is recorded: the first two filtered appends are gated by up to two heartbeat windows rather than one, and the missing-entry halt of `CONS-13(5)` gains up to one full window, up to two windows in blocks in total, unbounded in wall clock because the register bounds `HEARTBEAT_WINDOW` only from below (`PARAM-01`). At low heights the guard is load-bearing: eligibility is `lastHeartbeatSeq(v) > 0` **and** `lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW`, and a never-attested entry whose record is `0` is ineligible regardless of the arithmetic (R2-DI-01). *(R3-LT-01: the further correction is appended here; D-14, D-16 and the entry above are untouched.)* The relative statement above is also an inevitability, and its size is absolute: the gate opens at `(floor(L1_0 / HEARTBEAT_WINDOW) + 2) · HEARTBEAT_WINDOW` while the first L1-side epoch boundary is `L1_0 + EPOCH_LEN_L1`, and with `EPOCH_LEN_L1 < HEARTBEAT_WINDOW` their difference `2 · HEARTBEAT_WINDOW − (L1_0 mod HEARTBEAT_WINDOW) − EPOCH_LEN_L1` is at least `HEARTBEAT_WINDOW + 1 − EPOCH_LEN_L1 > 0`, so the append for `e_0 + 1` can never be made before that epoch is entered — the halt is guaranteed whenever the L2 keeps pace — and it runs between `HEARTBEAT_WINDOW − EPOCH_LEN_L1 + 1` and `2 · HEARTBEAT_WINDOW − EPOCH_LEN_L1` blocks before the append, plus Ethereum finality. The gate can also pass the second boundary `L1_0 + 2 · EPOCH_LEN_L1` whenever `2 · (HEARTBEAT_WINDOW − EPOCH_LEN_L1) > (L1_0 mod HEARTBEAT_WINDOW)`, and the finality lag can make the entry for `e_0 + 2` late in most alignments, so the launch may need two recovery cycles rather than one. *(R4-LT-01: appended to this record — the launch halt is guaranteed and sized in blocks beside the kept relative comparison.)*

## D-18 — Narrow forced inclusion revived in one unit, with an unconditional frontier, a non-steerable void predicate and expiry as proof-side discharge

*Increment 04. Append-only: D-12 and D-16 stay as written; this entry records what changed.*

**Decision (design owner, 2026-10-07):** increment 04 revives **narrow forced inclusion (D-12)** as the
**FI-10–FI-14** family, re-derived against the converged v1 rather than restored from its tombstone. It is
**in review**: it ships only after its own review round, and the bar is the one v1 and increment 02 met —
**two consecutive rounds with no Critical and no High**. The general inclusion list (`FI-PLANNED-01`)
stays absent, only the FI family's names (FI-10–FI-14 and FI-REMOVED-01) leave their tombstones and
every other tombstone stays exactly as D-16 left it, and no v1 decision is reopened.

**One unit of account.** The obligation is registered **positions per batch**. `FI_MAX_PER_BATCH` is used
in exactly one unit in all four places it appears — the obligation, the cap, the capacity relation and the
frontier bound — and `CONS-01(v)` is demoted to a per-block **order and non-omission** duty with **no
per-block count and no per-block gas quota**. The new registered parameter **`FI_MIN_DRAIN`**
(`1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH`) removes the reachable cap-of-zero: a batch with a live outstanding
record must resolve at least one position, so `R = 0` is unreachable. The four blockers recorded in
`DEFERRED.md` §1 are disposed of in `increments/04-forced-inclusion-design.md`: the frontier waiver is
deleted, the units are unified, the environment half of the void predicate is removed, and expiry gains its
proof-side ground with the prune made deletion-only.

**An unconditional, monotone frontier.** A record is **due** at
`l1BlockNumber + FI_INCLUSION_DELAY ≤ A` and **dead** at `l1BlockNumber + T_PROVE_DEADLINE ≤ A`; its
deadline is **derived, never stored**, and the record carries **no mutable status field**. A batch must
satisfy `c' ≥ min(d(A), c + FI_MAX_PER_BATCH)` **with no exception** — the preserved "unless the window is
shorter" waiver is deleted, not narrowed — together with `c' ≤ nextSeq(A)`, `c' ≥ c`, and the walk that
resolves every position in `[c, c')` as **executed**, **void** or **dead**. Void is a function of the
record's immutable bytes, the registered constants and two facts a producer cannot move — the sender's nonce
and free balance, checked against the transaction's own declared maximum charge — so **base fee and block
gas limit are removed** from the predicate and no block producer can manufacture a void ground. Expiry is an
objective **proof-side discharge**: dead-at-`A` needs one stored number, no bytes, no execution and no L1
call. The register appends; the prune is **deletion only**, behind the settlement frontier through a stored
prune cursor, never returns a frontier, never writes a settlement record, is never read by `land`, and no
rule may lower the frontier. D-12's text is kept wherever it is consistent and superseded only where its
preserved rules were defective: the waiver, the status flag, the per-block unit, the environment predicate
and the prune's return value.

**Enforcement is in the proof, never a gate.** `land` gains no rejection that depends on the register;
L1-04's no-gate property survives, and the capacity condition is part of proof validity rather than an
admission rule. No forced-inclusion state is read by the withdrawal root, its attestation, the veto or exit
eligibility. **No new slashable offence is created**: the forced-inclusion offence rows in ECON-04/ECON-13
stay tombstoned exactly as D-16 left them, a validator that signs a block violating FI-11(4) is not subject
to a new offence, and the rejected proof is the whole enforcement. No fee, escrow, bond or refund is
introduced, a forced transaction pays its own L2 gas, and D-8/D-9's funding shares and destinations are
untouched.

**This is not a latency guarantee.** What the mechanism bounds is **exclusion per unit of the censor's L1
spending**, conditional on at least one honest or rational batch producer and on an L1 that includes the
user's publication. A pure censor that refuses the front record halts its own frontier rather than censoring
it; a publishing censor can front-run re-publications at roughly one L1 publication per deadline window; an
L1-censored publication still cannot be forced. **F-FI-2 (arrivals exceeding the drain) is left open and
unfixed**: no per-publisher live-record bound is adopted, because a condition on `publish()` is outside what
D-12 authorises and would change DA-07(1)'s "any account MUST be able to publish". The guarantee's condition
is therefore stated wherever it is summarised: it holds only while arrivals stay within the drain the
obligation can force. The other falsifiers travel disclosed: **F-FI-1** (the capacity relation constrains a
value, and no registered rule maintains the L2 gas-limit schedule premise), **F-FI-3** (a voided record may
become forceable later; re-publication is the remedy), **F-FI-4** (a record can age out to dead instead of
being included), **F-FI-5** (the producer and L1 condition) and **F-FI-6** (the deliberate-delay anchor-age
residual, closed inside the envelope by the registered relations). Every `FI_*` value, the capacity
relation and the schedule premise remain unmeasured.

**Status:** decided; specification, register, index and course changes in flight. The increment ships only
after its own review rounds are clean.

**Addendum (increment 04 review round 1, R4R1-M-01).** The entry above stands as the historical record; this
addendum records the correction. The owner's ruling (2026-10-07) is **per-transaction resolvability**: a
position resolves when walking the record's transactions in the record's own order each one either
**executes** or is **discharged** — it cannot execute at the state its turn reaches, because its declared
nonce is not the sender's nonce there or the sender's free balance there is below
`gasLimit × maxFeePerGas + value` — with at least one executing; a live record all of whose transactions are
discharged is **void** (as is an over-bound record), and a record past its deadline is **dead**. The
correction closes review round 1's Critical R4R1-M-01, the chain-wide settlement freeze: a record-level
ground that resolved a position only when **all** of a record's transactions executed, or when **none** of
them was forceable, or when the record was dead, left a record with one forceable and one never-forceable
transaction resolved by none of the three modes while it was live; because every position in the computed
window `[c, c + R)` was mandatory, every batch's proof was invalid — no new checkpoint and no new withdrawal
root — and one fresh poison per `T_PROVE_DEADLINE` kept settlement frozen chain-wide indefinitely for the
cost of one permissionless L1 publication. **Totality is a rule property:** every position resolves in a
bounded number of batches — the frontier advances at least one position per accepted batch and a record's
transactions are finite — so no published record can pin the frontier; and the **anti-void property is
preserved**: execution follows the record's own order and only that account's own signed transactions can
move its nonce or free balance, so a producer cannot manufacture a discharge ground for someone else's
transaction. **The record-level grounds are superseded and MUST NOT be restored**: the requirement that
**all** of a record's transactions execute, the form "a record none of whose transactions is forceable at
any block's pre-state in the batch is void", and the F-FI-3 sentence "a record voided in this batch may
become forceable later" — restoring any of them restores the Critical. F-FI-3 is restated: a discharged
transaction may become executable later only through the sender's own further signed transactions, and the
remedy for a record whose transactions were discharged is re-publication (DA-09(2)). D-12 and D-16 are
untouched. *(R4R1-M-01: the correction is recorded by addendum; the entry above, D-12 and D-16 are preserved
as history, and the record-level ground MUST NOT be restored.)*

**Further addendum (increment 04, completed ruling R4R1-M-01).** The entry and the addendum above stand as
the historical record; this further addendum records the completed ruling in the terms the specification now
carries. The walk of `FI-13(1)` is **per transaction, in the record's own order**: each transaction either
executes or is **discharged** at its turn, and its turn's **pre-state is computed in the batch's own
execution** — after the record's own preceding transactions have executed and after every transaction the
batch executes before that point. The discharge condition is the **exact complement of the forceability
condition of `FI-13(2)(v)`** and uses **BALANCE**, not "free balance": the transaction is discharged iff its
declared nonce does not equal the sender's nonce at that pre-state, or the sender's balance there is below
`gasLimit × maxFeePerGas + value`; a transaction that can execute at its turn and does not appear is neither
executed nor discharged, and the position is unresolved. **Void gains its immutable half**: a **live** record
containing a transaction that can never be executed from the record's own bytes — for example a chain id
that does not match `FI-13(2)(iii)` — is void, because such a transaction can neither execute nor be
discharged; the over-bound and all-discharged grounds stand. The modes are applied in the rule's stated
precedence so that they partition the positions: **dead** is tested first and unconditionally — a record
that is dead at `A` is dead whatever its size, contents or discharge state — and, for a record live at `A`,
the over-bound and byte-invalid limbs of void are tested before executed, so a live over-bound record is
void even if one of its transactions appears in the executed payload.
**Totality and the anti-void property are rule
properties**: every position resolves in a bounded number of batches, so no published record can pin the
frontier or halt settlement, and a record whose remaining transactions cannot execute is fully discharged
rather than left unresolved; only that account's own signed transactions move its nonce or balance, so a
producer cannot manufacture a discharge ground for someone else's transaction. This corrects the addendum
above's "sender's free balance" wording to BALANCE. D-12 and D-16 are untouched. *(R4R1-M-01: the completed
per-transaction ruling is appended here; the entry and the addendum above are preserved as history.)*

**Further addendum (increment 04, review round 3, R4R3-T-02).** The entry and the addenda above stand as
the historical record; this further addendum records the correction, which is the wording `FI-13(2)`–`(3)`
now carries. The entry's "two facts a producer cannot move — the sender's nonce and free balance" and the
addendum above's "a discharged transaction may become executable later only through the sender's own
further signed transactions" are **superseded**, and so is the balance half of the same claim in the
addenda above — "only that account's own signed transactions can move its nonce or free balance" and "only
that account's own signed transactions move its nonce or balance". Only the **nonce** is
producer-immovable: only that account's own signed transactions can move it. The **balance** can be moved
by **anyone**, the producer included, which is why the discharge is evaluated **at the transaction's
turn** — the pre-state `FI-13(1)(a)` pins by position — and why an incoming credit can only ever make a
transaction **executable**, never discharged: where a third-party credit lands relative to the turn of a
transaction that is unaffordable there without it decides whether the transaction is forceable at that turn
and must execute or is discharged as unaffordable at its turn. That credit-ordering edge remains the
disclosed residual **F-FI-3**, not a new ground; a discharged transaction may become executable later
through the sender's own further signed transactions or through such a credit, and re-publication
(`DA-09(2)`) is the remedy. The discharge term's name is **BALANCE**, the sender's balance, not "free
balance": the reward pool's `free_before(e)` is a different term. D-12 and D-16 are untouched.
*(R4R3-T-02: the correction is appended here; the entry and the addenda above are preserved as history,
and each superseded form is quoted and corrected beside this note rather than edited in place.)*


