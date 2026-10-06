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

