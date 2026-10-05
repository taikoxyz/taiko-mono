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

