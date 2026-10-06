# Etna PoS + ZK — Phase 1: Requirements, Assumptions and Threat Model

Status: **draft for review** · Phase: 1 (requirements and threat model) · Owner: lead architect
Pinned baseline revision: `7718753c1` (branch `etna-pos-zk`, Taiko monorepo)
Prior Etna research pinned at: `a829f79723de9a09205660d9895418577cfe9aa9` (branch `etna/converged-spec`)
Date: 2026-10-05

This document fixes the vocabulary, the assumption set, the fault boundary and the acceptance
matrix for the rest of the project. It is **not** the specification; the specification is
`spec/index.html`. Where this document and the specification disagree, the specification wins
and this document must be corrected.

---

## 1. Scope and fixed constraints

The project redesigns Taiko as **Etna PoS + ZK**: a permissionless L2 proof-of-stake chain whose
PoS validators (not L1 proposers) determine transaction order, whose committed history is settled
on Ethereum by a ZK proof, and whose settled batches always carry their own data.

The following are **fixed decisions** taken by the user. They are constraints, not options, and
this project does not reopen them for convenience.

| ID | Fixed decision | Consequence if violated |
|----|----------------|-------------------------|
| D1 | One L2 block every **2 s** under stated operating assumptions | R4 fails |
| D2 | Prefer **Mode A** (PoS finality is never invalidated). Only after an evidenced infeasibility argument plus independent review may **Mode B** (permissionless L1 recovery of *unsettled* history) be selected | R5 fails / unauthorized relaxation |
| D3 | Preserve existing L1+L2 **SignalService, Bridge, ERC20/721/1155 Vault** addresses; upgrade in place | R3 fails |
| D4 | L2 PoS may determine binding order (departure from based sequencing). The result must be described honestly as a **PoS-sequenced validity rollup** | Misrepresentation |
| D5 | Proof-gated acceptance: a batch's data **and** its valid ZK proof are settled in one L1 transaction — the checkpoint advances only on a valid proof. **Relaxed by D-11 (2026-10-06):** a batch's data MAY be published and recorded in an **earlier** L1 transaction and referenced by the proof; publication advances no protocol state, so no data-first *admission* path exists. No data-first admission in any mode, including recovery | R9 fails |
| D6 | Proving latency of **a few minutes up to 30 minutes** is normal operation. L2 keeps producing 2 s blocks and reaching the selected mode's PoS confirmation throughout | R4/R9 fail |
| D7 | Staking and slashable consensus collateral are denominated in the **existing TAIKO token**. Gas stays ETH. No replacement staking token | R1/R11 fail |

Explicit non-relaxations (from the user): D7 may not be relaxed to substitute ETH staking. D5's
one-transaction requirement for **state advance** stands — the checkpoint advances only on a valid
proof in the accepting transaction. The sole recorded relaxation of D5 is decision D-11: data may be
published before the proof and referenced by it (the earlier draft of this line forbade even that, and
D-11 supersedes it). D5's ban on a data-first *admission* path is not relaxed, in any mode including
recovery.

**Out of scope:** contract/client/consensus/proving implementation, deployments, live operations,
benchmarks produced by us. Interface sketches, pseudocode, traces and mathematical arguments are
in scope. The static website is a design deliverable, not software.

---

## 2. Vocabulary and status labels

These eight labels are the only statuses a block, batch or user claim may hold (STATUS-08 attaches to a withdrawal claim rather than to a block). Each has an exact evidence
set, a guarantee, a revocation condition and an audience. Learning material and the specification
must use exactly these names.

| # | Label | Evidence held | Guarantee | Revocable? |
|---|-------|---------------|-----------|------------|
| 1 | **proposed** | A block/proposal object received from a leader | none (it may be invalid) | dropped freely |
| 2 | **locally execution-valid** | The receiver executed the block against a known parent state and all consensus rules passed | this node will not build on an invalid block | dropped if the parent is displaced |
| 3 | **voted** | The receiver (a validator) signed a vote for this block at its height/view | a vote is a commitment: it constrains the voter's future votes by the lock rule | never (voting is irreversible for the voter) |
| 4a | **PoS-finalized** (Mode A) | A published quorum certificate over (chain, epoch, height, block hash) meeting the stake threshold, plus a data-availability check by the node | under <1/3 Byzantine stake and the stated synchrony assumptions this block is on the unique canonical chain, permanently | **never** in Mode A |
| 4b | **PoS-certified / provisional** (Mode B only) | Same certificate, but the protocol discloses that a recovery event may supersede it before L1 acceptance | a strong, economically-backed confirmation that is explicitly **not** irreversible | yes, only via the published recovery rules |
| 5 | **proof-ready** | A completed ZK proof bound to this batch's data commitment exists off-chain | the batch can now be posted | superseded by a better proof of the same batch; a proof of a *different* batch is not a substitute |
| 6 | **accepted on L1** | The L1 Inbox accepted (data, proof) in one transaction and advanced its checkpoint | the batch's data is public on Ethereum and the transition is L1-committed | only by L1 reorg below finality |
| 7 | **Ethereum-finalized** | The accepting L1 transaction is in a finalized Ethereum block | irreversible except by a catastrophic Ethereum consensus failure | effectively no |
| 8 | **withdrawal-eligible** | Status 6 or 7 plus the mode's delay/bonding rules and message-authentication path satisfied | the user may exit funds through the existing Bridge/Vault surface | bounded by the rules of R7/R11 |

Statuses 1–3 are **local**; 4a/4b and 6 are **public protocol** states; 7 is an **L1** state.
A node must never treat "I received a valid block" as availability for anyone else, and must
never treat "no certificate arrived within T" as "no certificate exists".

---

## 3. System model

**Participants.**
- **Validators** — permissionless; stake TAIKO; propose/vote; produce consensus evidence.
- **Provers** — permissionless; convert committed L2 history into ZK proofs; paid for accepted proofs.
- **Full nodes / archive nodes** — execute, serve data, hold witnesses.
- **Users** — submit L2 transactions; bridge assets; force-include via L1.
- **L1 Ethereum** — settlement, DA, proof verification, bridge anchoring, governance.
- **DAO** — upgrades only (R2). Never a runtime dependency for progress.

**Channels.** L2 P2P (gossip + directed), L2↔L1 (L1 transactions; L1→L2 observation of L1 state),
and the shared bridge/signal surface.

**Time.** Consensus rounds and validator-set versions are logical identifiers; all timing
parameters are expressed in **seconds** or **L1 block numbers** (R12). No parameter may depend on
Ethereum proposer lookahead or a fixed L1 slot duration.

**Target cadence.** One L2 block per 2 s. For arithmetic in this project, 30 min = 900 L2 blocks.

---

## 4. Assumptions

Each assumption has an ID, is either **safety- or liveness-relevant**, and is **not** a claim that
the assumption holds — it is a claim that *if* it fails, a named consequence follows.

### 4.1 Cryptographic

| ID | Assumption | Kind | Consequence of failure |
|----|-----------|------|------------------------|
| A-CRYPTO-1 | The zkVM (RISC Zero and/or SP1 at pinned versions) is **sound**: no accepting proof of a false statement | safety | forged batches; bridge theft. Not recoverable by protocol design |
| A-CRYPTO-2 | Used signature schemes are unforgeable (validator signature scheme; and any aggregate/threshold scheme is sound under its own assumption, e.g. BLS with proofs of possession) | safety | forged finality certificates |
| A-CRYPTO-3 | Keccak-256/SHA-256 collision resistance; Merkle/MPT binding; KZG binding for blob commitments (as used by EIP-4844) | safety | conflicting commitments for one datum |
| A-CRYPTO-4 | Validator keys are not compromised below the Byzantine threshold; adaptive corruption is bounded by the same stake threshold | safety | safety loss regardless of protocol |
| A-CRYPTO-5 | Trusted-setup material, if any (e.g. a wrapped SNARK or a KZG ceremony) is honestly generated | safety | see A-CRYPTO-1 |

### 4.2 Consensus and network

| ID | Assumption | Kind | Consequence of failure |
|----|-----------|------|------------------------|
| A-CONS-1 | Byzantine stake **< 1/3** of the stake that counts toward quorum in the relevant validator-set version | safety | two conflicting finalized histories can exist; ZK verification cannot repair this (§6.5) |
| A-CONS-2 | During normal operation, message delivery among correct validators completes within the protocol's round budget often enough to make progress; after a global stabilization time (GST), delivery is timely forever (partial synchrony) | liveness | extended halts; **not** safety loss |
| A-CONS-3 | The advisory synchrony bound used to size timeouts holds "often enough"; violation degrades liveness only | liveness | view-change churn, slower confirmation |
| A-CONS-4 | Validator-set transitions are deterministic functions of L1-committed state, so all correct nodes agree on set version *k* for a given epoch | safety | set-substitution; certificate judged under the wrong set |
| A-CONS-5 | Correct validators hold and can serve the block data they voted for, for at least the retention window | liveness (and DA) | finalized-but-unavailable data; safe halt |
| A-CONS-6 | New joiners can obtain a weak-subjectivity checkpoint no older than the published freshness window, from a source they trust | safety (long-range) | long-range attack; a node follows a fabricated history |

### 4.3 Data availability and proving

| ID | Assumption | Kind | Consequence of failure |
|----|-----------|------|------------------------|
| A-DA-1 | Every accepted batch's data is retrievable from Ethereum for at least the retention window (blobs expire; calldata does not) | liveness / auditability | inability to re-prove or audit; **must be designed around, not assumed away** |
| A-DA-2 | At least one honest, adequately-resourced prover completes each committed batch's proof within the assumed envelope | liveness | settlement stalls; L2 keeps producing until the backlog rule binds |
| A-DA-3 | Blob data is retrievable via Ethereum's data-availability mechanisms for the blob retention period; longer-lived copies are held off-chain or in calldata | liveness | witness loss for old batches |
| A-DA-4 | The L2 execution witness for a batch can be reconstructed by an independent prover from public L2 data and state | liveness | prover centralization (one prover becomes the only one able to prove) |

### 4.4 L1 and economics

| ID | Assumption | Kind | Consequence of failure |
|----|-----------|------|------------------------|
| A-L1-1 | Ethereum provides liveness (censorship-resistant inclusion of valid transactions within a bounded time) and safety (no finality reversal) at the assumptions of Ethereum consensus | both | L2 halts (liveness) or settled history is rewritten (safety, out of protocol control) |
| A-L1-2 | Ethereum's blob/DA and proof-verification features used by the design are available with the semantics verified in §7.3 of the spec | liveness | cannot launch / must use the stated fallback |
| A-ECO-1 | The market value of slashed TAIKO plus the loss of future rewards exceeds the profit from any attack the protocol claims to deter, **at the relevant time** | safety (economic) | attacks become profitable; the protocol must state the exposure honestly rather than claim deterrence |
| A-ECO-2 | TAIKO is obtainable and transferable enough that entry is genuinely permissionless | liveness (R1) | effective permissioning by market access |
| A-GOV-1 | The DAO does not execute a malicious upgrade | safety | an upgrade can rewrite any rule; explicitly a **trust assumption** (R2) |

**Weak subjectivity.** Any PoS chain with dynamic membership needs a freshness assumption for
syncing. If the design needs one, the exact trust and freshness requirement is stated in the
specification; a "trusted checkpoint provider" is never introduced silently.

---

## 5. Fault boundary

The protocol claims nothing outside the assumptions above. Three failure classes must be kept
distinct in **all** deliverables:

| Class | Meaning | Protocol behaviour |
|-------|---------|--------------------|
| **F1 — liveness-assumption failure, safety intact** | e.g. quorum offline, partition, prover outage, blob expiry, L1 congestion | Actively correct behaviour: halt, backpressure, replace provers, wait. Never rewrite finalized history (Mode A) |
| **F2 — safety-assumption failure** | ≥1/3 Byzantine stake, key compromise, zkVM soundness break, or a governance upgrade that changes the rules | The protocol's safety claims **do not apply**. Conflicting certificates may both verify; ZK verification does not repair failed consensus assumptions. Detection and disclosure, not prevention, is the honest response |
| **F3 — implementation-assumption failure** | a specific client/prover/contract bug | out of scope for this design project, but the specification must not make F3 undetectable (auditability, evidence encoding, escape hatches that do not weaken Mode A) |

A **safe halt** is a first-class outcome, not a defect: when F1 persists and no rule-legal action
exists, correct participants stop rather than choose between two histories.

---

## 6. Threat model

### 6.1 Attacker capabilities considered

T-1 adaptive network adversary (delay/reorder/drop/partition, selective delivery) · T-2 Byzantine
validators below the stake threshold · T-3 Byzantine leader/proposer · T-4 withholding of any
message class · T-5 stake acquisition and concentration, incl. borrowing/delegation · T-6 bribery
and MEV-driven reordering · T-7 L1 censorship of specific transactions (incl. proofs or data) ·
T-8 L1 reorg below finality · T-9 prover cartel / denial of proving · T-10 governance capture ·
T-11 long-range / weak-subjectivity attacker · T-12 data-unavailability attacker (blob withholding)
· T-13 griefing/DoS on permissionless entry and exit · T-14 replay of signed messages across
domains/epochs · T-15 false accusation of misconduct.

### 6.2 Mandatory adversarial schedule (withholding)

Every mode must answer this schedule, and the answer must be a *proof sketch*, not a quorum-signature
check:

1. A leader selectively distributes a block to a subset.
2. Honest validators vote according to their **local** views.
3. The attacker privately holds a finality-related certificate.
4. Other participants initiate a leader change, validator change, or recovery.
5. The attacker reveals the certificate after the alternative path has progressed.

Required conclusions: under A-CONS-1/A-CONS-2, two conflicting histories cannot **both** obtain
the mode's irreversible guarantee — the argument must combine **locks, view changes and
reconfiguration**, not just signature counting. In Mode B, the exact recovery exception is
exposed, and the eligibility/checkpoint rules must handle late conflicting evidence consistently.

### 6.3 Attack catalogue to be addressed in the specification

Each of these must have a named normative rule or an explicit "accepted limitation" entry:

- equivocation by a leader or validator; conflicting certificates at one height;
- partition with accidental/attack-induced symmetric splits;
- long-range attack and weak-subjectivity freshness;
- **withheld certificates** (the published-later certificate problem);
- a halt after PoS finality but before proof submission;
- an unavailable validator quorum; unavailable data for a finalized block;
- fresh permissionless participants attempting to restart the chain from a checkpoint;
- expired/withdrawn validator keys voting or being counted;
- L1 censorship of data, proof, or publication (forced-data) transactions;
- L1 reorganization around an accepted batch;
- proof delay exceeding exit/freshness windows; one or more prover failures after 30 min;
- backlog growth beyond the retention window;
- cheap attacker-triggered recovery that replaces honestly confirmed history (Mode B);
- forced-inclusion exploitation (using inclusion to stall or to grief);
- bridge accounting, replay protection, and message authentication after a fork;
- TAIKO price collapse, borrowing, delegation concentration, exit races.

### 6.4 Explicit non-arguments

The following are **not** acceptable evidence anywhere in this project:

- "An elapsed timeout proves no certificate exists."
- "L1 rejected the stale predecessor, therefore the earlier PoS confirmation was safe."
- "The proof verifies, therefore no hidden competing chain exists."
- "A quorum signature verifies, therefore the history is unique."
- "Mere non-receipt of a P2P message proves misconduct."
- "Per-address caps prevent monopolization."
- "The DAO/emergency key would fix it."

### 6.5 What ZK cannot repair

If ≥1/3 of stake (A-CONS-1) violates the consensus assumptions, **two conflicting finality
certificates can both be cryptographically valid**. The ZK proof attests that each certificate is
internally consistent with a stated validator set and quorum rule; it cannot attest that no other
certificate exists. The specification must state that any claim of uniqueness is relative to an
**authenticated checkpoint** and the consensus assumptions, and Mode B must describe how L1
prevents conflicting accepted continuations.

---

## 7. Requirements acceptance matrix

Design response column is completed by Phase 3/4; evidence tags are **Proven** (argument +
named premises), **Assumed** (justification + consequence of failure), **Open** (evidence or
decision needed). Numbers are tagged **derived**, **sourced**, or **unmeasured**.

| ID | Requirement (abridged) | Design response | Evidence | Status |
|----|------------------------|-----------------|----------|--------|
| R1 | All operational roles permissionless, objective entry/exit, no whitelist; staking per D7 | *(Phase 4)* | *(Phase 4)* | Open |
| R2 | DAO governs upgrades only; no DAO intervention in ordinary progress/failure/roles | *(Phase 4)* | *(Phase 4)* | Open |
| R3 | Preserve D3 shared-contract addresses with a concrete migration plan | *(Phase 4)* | *(Phase 4)* | Open |
| R4 | 2 s L2 block production under explicit assumptions; cadence distinguished from every confirmation and settlement latency | *(Phase 4)* | *(Phase 4)* | Open |
| R5 | Consensus safety + selected mode's confirmation guarantees across leader change, set change, proof delays, recovery; A preferred, B only per D2 | *(Phase 3)* | *(Phase 3)* | Open |
| R6 | Conditional liveness under explicit network/honest-stake/DA/L1 assumptions; exact conditions where liveness ends | *(Phase 4)* | *(Phase 4)* | Open |
| R7 | Complete proof statement for execution + selected mode's consensus/finality/recovery rules; credible on RISC Zero **and** SP1 | *(Phase 2/4)* | *(Phase 2/4)* | Open |
| R8 | Sufficient data on Ethereum (blobs/calldata) bound to the accepted proof; no private witness/committee certificate as a substitute | *(Phase 4)* | *(Phase 4)* | Open |
| R9 | D5 atomicity for every accepted batch, incl. during recovery and prover failure; no bypass | *(Phase 4)* | *(Phase 4)* | Open |
| R10 | Censorship resistance and forced inclusion, without an override that violates D2 — **restated by decisions D-6/D-12**: state censorship resistance honestly. v1 carries a **narrow forced-inclusion obligation over published data** — a due record must be resolved by the capped FIFO prefix of the due set, or discharged as void on objective grounds, enforced at the proof and never as an admission gate — and it is an **upper bound on exclusion, never a lower bound on inclusion**. The **general inclusion list** (arbitrary unpublished transactions, with a queue, escrow or fee) remains deferred; for unpublished data the protocol provides only statistical resistance from proposer rotation and gossip under A-CONS-2, and a network-level adversary able to isolate a user — or to censor L1 inclusion itself (A-L1-1) — can exclude that user indefinitely and can prevent the user from starting a withdrawal, with no protocol remedy. No override that violates D2 may be introduced | enforced by `LIVE-04` (spec/10) and `FI-10`–`FI-14` (spec/04); the deferred general list is `FI-PLANNED-01` | Proven (statement honesty) / Assumed (A-CONS-2, A-L1-1) | Satisfied **in its narrowed form**; the general inclusion list is explicitly not satisfied (D-12 supersedes D-6/D-10) |
| R11 | Objective misconduct evidence, collateral, payouts, exit delays, false-accusation handling; no "non-receipt = misconduct" | *(Phase 4)* | *(Phase 4)* | Open |
| R12 | No dependence on L1 proposer lookahead or fixed L1 slot duration; seconds or L1 block numbers | *(Phase 4)* | *(Phase 4)* | Open |
| R13 | Every security-relevant transition/message/proof input/exceptional path specified enough to implement without inventing rules | *(Phase 4)* | *(Phase 4)* | Open |
| R14 | Learning website consistent with the specification, incl. assumptions, unresolved questions, accepted limitations | *(Phase 5/7)* | *(Phase 5/7)* | Open |

### 7.1 Decision-procedure obligations (D2)

1. Investigate **Mode A first**; state its safety and liveness assumptions. A safe halt outside the
   stated liveness assumptions is permitted and is **not** evidence of Mode A infeasibility.
2. Before selecting Mode B: document the specific requirement Mode A cannot satisfy, the attempted
   safe-recovery constructions, and an argument or concrete counterexample. Missing research,
   unmeasured performance, elapsed time or review-budget exhaustion **do not** count.
3. Obtain independent review of that argument; record the verdict and architecture selection in
   `DECISIONS.md`. The fallback is already authorized; no new permission request is required when
   the condition is substantiated.
4. If Mode B is selected: define objective triggers, who may invoke, delays, checkpoint and
   configuration boundaries, late certificate/proof treatment, transaction replay, and derive
   rollback-depth/duration/user-exposure limits. No universal bound on economic loss may be invented.
5. Mode B must additionally show that, **within the stated normal-operation assumptions**, an
   ordinary malicious leader or sub-threshold coalition cannot cheaply trigger a recovery that
   replaces honestly confirmed history — with quantified attacker resources, penalties and
   rollback exposure. Inability to establish this is a **blocker**, not a disclosure item.

---

## 8. Review and convergence protocol (project-internal)

- At most **8** full review rounds; each round freezes a tagged specification snapshot and uses
  **≥3 independent adversarial reviewers** covering: (i) consensus safety / hidden certificates /
  reconfiguration; (ii) proof soundness / bridge funds / stake custody / accounting;
  (iii) liveness, DA, censorship, recovery, 30-min pipeline; (iv) economics, TAIKO concentration,
  permissionless entry; (v) atomic submission + shared-address preservation.
- A separate judge deduplicates findings and assigns severity with a rationale.
- Findings carry: exact rule or missing rule, preconditions, concrete attack trace, inside/outside
  the fault model, attacker resources and cost, harm, affected requirements, evidence or a worked
  counterexample.
- Convergence requires: two consecutive full rounds with no new Critical/High; all prior
  Critical/High resolved; every Medium mitigated or explicitly accepted with written rationale;
  no accepted finding violating D2/D3/D5/D6/D7 or any hard requirement; traceable arguments for
  every requirement; no unresolved normative choice forcing an implementer to invent a
  security-relevant rule; consensus/proving feasibility appropriately evidenced; learning site
  matching the final specification.
- A Mode A→B switch resets the consecutive-clean-round count without resetting the 8-round budget.

---

## 9. Inputs to Phase 3 (architecture decision)

Phase 3 must consume: (a) the consensus survey (≥3 materially different families),
(b) the zkVM feasibility study (RISC Zero and SP1, pinned versions), (c) the current-Taiko
baseline including the fact that **today's Inbox exposes separate `propose()` and `prove()`
entry points, i.e. a data-first *admission* path that D5 forbids — it advances proposal state before a
proof, which is what produced the June 2026 expiry class
(`packages/protocol/contracts/layer1/core/impl/Inbox.sol:270,321`); D-11's permission to publish data
before the proof is different in kind, because a publication advances no protocol state**,
(d) the prior-Etna lessons digest, and (e) this document.

The Phase 3 outputs are: the selected consensus protocol (established-first, modifications named
with the proofs that no longer apply), the selected recovery mode with the D2 record, and the
architecture decision log entry with tradeoffs.
