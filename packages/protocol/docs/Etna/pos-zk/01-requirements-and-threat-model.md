# Etna PoS + ZK — Phase 1: Requirements, Assumptions and Threat Model

Status: **Phase-1 record, maintained in place** · Phase: 1 (requirements and threat model) · Owner: lead architect · Re-based: 2026-10-07 (increment 05 review, R5R1-NR-01)
Pinned baseline revision: `7718753c1` (branch `etna-pos-zk`, Taiko monorepo)
Prior Etna research pinned at: `a829f79723de9a09205660d9895418577cfe9aa9` (branch `etna/converged-spec`)
Date: 2026-10-05

This document fixes the vocabulary, the assumption set, the fault boundary and the acceptance
matrix for the rest of the project. It is **not** the specification; the specification is
`spec/index.html`. Where this document and the specification disagree, the specification wins
and this document must be corrected. It is maintained rather than frozen: the dispositions below are re-based on the current specification, in which narrow forced inclusion (`FI-10`–`FI-14`, increment 04) and the governance stall resolution (`GOV-04`, with `REC-01`–`REC-04`, increment 05) are live, and a statement that records a disposition since superseded is marked as history. *(R5R1-NR-01: the document is kept in step with the specification it defers to.)*

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
| D2 | Prefer **Mode A** (PoS finality is never invalidated). Only after an evidenced infeasibility argument plus independent review may **Mode B** be selected. **Mode B was selected by user decision D-7; D-15 withdrew the permissionless L1 recovery it carried and replaced it with the governance stall resolution of `GOV-04`; D-16 deferred that replacement (history), and increment 05 revived it as the live, timelocked, resume-only action (`GOV-04`, with `REC-01`–`REC-04`). The only rule-bound replacement of unsettled history above the last L1-accepted checkpoint is the executed `GOV-04`: it discards exactly the provisional range above the checkpoint and writes no checkpoint, so no rule accepts data or advances a checkpoint without a valid proof. Clearing a settlement stall still depends on governance queueing and executing an entry, with no protocol-level bound (A-GOV-2, F-GOV-1). The D-16 deferral and its `DEFERRED.md` §3 entry are history** *(R5R1-NR-01: re-based on the live `GOV-04`.)* | R5 fails / unauthorized relaxation |
| D3 | Preserve existing L1+L2 **SignalService, Bridge, ERC20/721/1155 Vault** addresses; upgrade in place | R3 fails |
| D4 | L2 PoS may determine binding order (departure from based sequencing). The result must be described honestly as a **PoS-sequenced validity rollup** | Misrepresentation |
| D5 | Proof-gated acceptance: a batch's data **and** its valid ZK proof are settled in one L1 transaction — the checkpoint advances only on a valid proof. **Relaxed by D-11 (2026-10-06):** a batch's data MAY be published and recorded in an **earlier** L1 transaction and referenced by the proof; publication advances no protocol state, so no data-first *admission* path exists. No data-first admission in any mode; the one rule that removes anything above the last L1-accepted checkpoint is the executed `GOV-04`, which discards the provisional range and manufactures no checkpoint, and no rule accepts data or advances a checkpoint without a valid proof (`GOV-04`, `REC-01`; increment 05) *(R5R1-NR-01: re-based; the former absolute-absence form is superseded.)* | R9 fails |
| D6 | Proving latency of **a few minutes up to 30 minutes** is normal operation. L2 keeps producing 2 s blocks and reaching the selected mode's PoS confirmation throughout | R4/R9 fail |
| D7 | Staking and slashable consensus collateral are denominated in the **existing TAIKO token**. Gas stays ETH. No replacement staking token | R1/R11 fail |

Explicit non-relaxations (from the user): D7 may not be relaxed to substitute ETH staking. D5's
one-transaction requirement for **state advance** stands — the checkpoint advances only on a valid
proof in the accepting transaction. The sole recorded relaxation of D5 is decision D-11: data may be
published before the proof and referenced by it (the earlier draft of this line forbade even that, and
D-11 supersedes it). D5's ban on a data-first *admission* path is not relaxed, in any mode; no rule accepts data or advances a checkpoint without a valid proof, and the only rule that removes anything above the last L1-accepted checkpoint — the executed `GOV-04` — accepts no data, writes no checkpoint and is resume-only (increment 05). *(R5R1-NR-01: re-based; the former absolute-absence form is superseded.)*

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
| 4b | **PoS-certified / provisional** (selected Mode B) | Same certificate; above the last L1-accepted checkpoint the confirmation is explicitly **provisional**. The one rule-bound replacement is the executed stall resolution of `GOV-04` (live again by increment 05): DAO-queued under a trigger read from L1 state alone, stored timelock, consumed entry, full-range discard of everything strictly above the checkpoint, resume-only, writes no checkpoint; the permissionless recovery stays withdrawn (D-15) | a strong, economically-backed confirmation that is explicitly **not** irreversible | no *permissionless recovery* replaces it (the queue is a DAO transaction, D-15); value above the checkpoint is provisional and unprotected — it has no L1-provable claim (`MEM-15(4)`) and the execution discards it — and clearing a settlement stall depends on governance liveness with no protocol bound (A-GOV-2, F-GOV-1) *(R5R1-NR-01: re-based on the live `GOV-04`.)* |
| 5 | **proof-ready** | A completed ZK proof bound to this batch's data commitment exists off-chain | the batch can now be posted | superseded by a better proof of the same batch; a proof of a *different* batch is not a substitute |
| 6 | **accepted on L1** | The L1 Inbox accepted the batch in one transaction — its data carried in it or bound to an earlier live publication record under D-11, plus a valid proof — and advanced its checkpoint | the batch's data is public on Ethereum and the transition is L1-committed | only by L1 reorg below finality |
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
- **Users** — submit L2 transactions; bridge assets; may publish a transaction's data to L1, which advances no protocol state and **starts the live narrow inclusion obligation** of `FI-10`–`FI-14` (increment 04): from the record's due point every accepted batch must resolve the capped FIFO prefix of the due set, enforced in the proof — not a latency guarantee, conditional on an honest or rational producer and on arrivals within the forceable drain (F-FI-2, F-FI-5). Data that is never published carries no inclusion duty. *(R5R1-NR-01: re-based on the live narrow obligation.)*
- **L1 Ethereum** — settlement, DA, proof verification, bridge anchoring, governance.
- **DAO** — upgrades under the published upgrade rules, plus the protocol's **one** rule-bound runtime action: queueing a stall-resolution entry under `GOV-04` through the authority of `GOV-01` (the entry stores its own timelock and is executed permissionlessly once live and past that stored deadline; execution consumes the entry, discards only history strictly above the last L1-accepted checkpoint and writes no checkpoint). No DAO transaction is needed for ordinary progress, and no other DAO intervention exists in ordinary progress, failure or roles. *(R5R1-NR-01: `GOV-04` is live again by increment 05; the "no rule-bound failure action" form is superseded.)*

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
| A-GOV-1 | The DAO does not execute a malicious upgrade | safety | an upgrade can rewrite any rule; explicitly a **trust assumption** (R2), and a captured DAO is failure class F2 handled by `GOV-02`. The DAO's one rule-bound runtime action is queueing the stall-resolution entry of `GOV-04`: the trigger, the stored timelock, the consumed execution and the resume-only effect are fixed by the rule, so queueing cannot choose a height, state, range, subset or generation — but a captured or coerced governance can still act opportunistically within the rule (disclosed: `GOV-04`(i), `REC-03`). No other DAO failure action exists, and A-GOV-2 records what clearing a stall depends on *(R5R1-NR-01: the action is live by increment 05.)* |
| A-GOV-2 | **Clearing a settlement stall depends on governance queueing and executing the `GOV-04` action, with no protocol-level bound** (re-scoped by increment 05: the former "future protocol update" form was the D-16 deferral of a mechanism that is now live). The procedure is specified — trigger read from L1 state alone, DAO-queued entry, stored timelock, permissionless consumed execution, resume-only full-range discard of everything strictly above the last L1-accepted checkpoint, signed generation increment — but no rule obliges governance to queue or anyone to execute, so availability is a social-layer assumption (F-GOV-1), and a live governance can repeat the action once per DAO transaction plus one full stored window, voiding the then-current provisional range each time (F-GOV-3). What remains guaranteed is the exit of `MEM-15` for value at or below the last accepted checkpoint (subject to its funded proving market); value above the checkpoint is the unprotected class — it has no L1-provable claim (`MEM-15(4)`), the execution discards it, and no window covers it | liveness | a settlement stall persists for an unbounded time while governance is absent, slow or captured, and value above the last accepted checkpoint cannot leave; protocol penalties compensate nothing (`ECON-11`). Disclosed rather than mitigated (`LIM-01`, spec/10; F-GOV-1, F-GOV-3) *(R5R1-NR-01: re-scoped on the live `GOV-04`; governance liveness unbounded and churn are added as F-GOV-1 and F-GOV-3.)* |

**Weak subjectivity.** Any PoS chain with dynamic membership needs a freshness assumption for
syncing. If the design needs one, the exact trust and freshness requirement is stated in the
specification; a "trusted checkpoint provider" is never introduced silently.

---

## 5. Fault boundary

The protocol claims nothing outside the assumptions above. Three failure classes must be kept
distinct in **all** deliverables:

| Class | Meaning | Protocol behaviour |
|-------|---------|--------------------|
| **F1 — liveness-assumption failure, safety intact** | e.g. quorum offline, partition, prover outage, blob expiry, L1 congestion | Actively correct behaviour: halt, backpressure, replace provers, wait. Never rewrite history at or below the last L1-accepted checkpoint. A cohort that stops participating halts production with no production-time bound; a settlement stall is clearable only by the executed `GOV-04` action, which no rule obliges governance to use and which depends on governance liveness (A-GOV-2, F-GOV-1), and the discard leaves everything at or below the checkpoint untouched. Value at or below the checkpoint remains withdrawable (`MEM-15`) *(R5R1-NR-01: re-based; the one route out is the live `GOV-04`.)* |
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
4. Other participants initiate a leader change or a validator change; no participant can initiate a recovery action: the permissionless recovery was withdrawn by D-15 and stays withdrawn, and the only replacement is the DAO-queued `GOV-04` entry, whose trigger is a settlement stall read from L1 state alone — a withheld certificate is not a trigger — and which no account can queue (increment 05) *(R5R1-NR-01: re-based on the live `GOV-04`.)*.
5. The attacker reveals the certificate after the alternative path has progressed.

Required conclusions: under A-CONS-1/A-CONS-2, two conflicting histories cannot **both** obtain
the mode's irreversible guarantee — the argument must combine **locks, view changes and
reconfiguration**, not just signature counting. No rule rewrites history at or below the last L1-accepted checkpoint, and the only rule-bound replacement above it is the executed `GOV-04`, which discards the whole provisional range and writes no checkpoint; a late certificate cannot force one. The eligibility/checkpoint rules — including the **signing** of the recovery generation (`GOV-04`(h), `L1-05` row 31, `PRF-02`/`PRF-05`) — must handle late conflicting evidence consistently (increment 05) *(R5R1-NR-01: re-based; the signed generation is live.)*

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
- cheap attacker-triggered halt instead of a history replacement: the permissionless recovery was withdrawn by D-15 and stays withdrawn, and the only replacement is the executed `GOV-04` — a DAO-queued, timelocked, consumed, resume-only action that a sub-threshold coalition cannot make true (the trigger reads L1 state alone and `T_STALL_GOV > T_PROOF_ENVELOPE + T_SETTLE_PIPELINE`) but which no rule obliges governance to use. The exposure is an **unbounded halt**: a sub-threshold coalition, or a cohort that simply stops participating, can halt the chain with no production-time bound, and a settlement stall is cleared only if governance queues and someone executes an entry; disclosed, not priced *(R5R1-NR-01: added — governance liveness unbounded (F-GOV-1); the "no rule of v1 restores it" form is superseded by the live `GOV-04`.)*;
- forced-inclusion exploitation (using inclusion to stall or to grief) — a live surface since increment 04: the narrow obligation of `FI-10`–`FI-14` is enforced in the proof (no gate, no new slashable offence), its walk is per transaction and total (every position resolves in a bounded number of batches, so a published record cannot pin the frontier) and only the account's own signed transactions move its nonce, so the failure modes are the named falsifiers F-FI-1–F-FI-8 (carried in `LIVE-04`/`LIM-01`, spec/10) *(R5R1-NR-01: re-based on the live narrow obligation; the arrivals-exceeding-drain falsifier and the enumeration residual are added as their own entries below.)*;
- governance liveness with no protocol bound: clearing a settlement stall depends on governance queueing and executing a `GOV-04` entry; a governance that is absent, slow or captured leaves the stall in place, and a captured or coerced governance can act opportunistically within the rule. Named rule: `GOV-04`(i) and `REC-03`; **F-GOV-1**, carried Open in `LIM-01` (spec/10). *(R5R1-NR-01: added threat — governance liveness unbounded.)*
- the unprotected class above the last accepted checkpoint: value, inclusions, ordering and bridge messages above the checkpoint have no L1-provable claim (`MEM-15(4)`), are discarded by an executed resolution, and are **not** covered by the notice window, which is scoped to a signal already at or below the last accepted checkpoint at queue time; transactions are not replayed and protocol penalties compensate nothing (`ECON-11`). Named rules: `GOV-04`(f) ("what the window is not"), `REC-02`/`REC-03`. *(R5R1-NR-01: added threat — the unprotected class.)*
- governance churn: execution consumes the entry, but a live governance can queue a fresh entry once per DAO transaction plus one full stored window, incrementing the generation and voiding the in-flight certificates and proofs of the then-current provisional range each time. The churn rule is consumption-only and the residue is disclosed, not constrained: **F-GOV-3** (`GOV-04`(i), `REC-02`, `REC-03`). *(R5R1-NR-01: added threat — governance churn.)*
- arrivals exceeding the forceable drain: **F-FI-2** is open and unfixed — the live narrow obligation's guarantee holds only while the arrival rate of livable publication records stays within the drain it can force, no per-publisher live-record bound is adopted (a condition on `publish()` would change `DA-07`(1)'s "any account MUST be able to publish"), and the queue and a record's wait can grow without bound (`LIVE-04`, `LIM-01`, spec/10). *(R5R1-NR-01: added threat — the arrivals-exceeding-drain falsifier.)*
- the enumeration residual: **F-FI-8** — the forceability predicate decides the record's own bytes and the turn pre-state; an execution-validity rule a valid block enforces that depends on neither can leave a transaction the predicate calls forceable — and the per-block duty of `FI-11`(4) demands — one no valid block can carry, so the walk demands an execution that cannot happen and the position cannot resolve until the record is dead or the transaction is superseded (carried Open in `LIVE-04`/`LIM-01`, spec/10). *(R5R1-NR-01: added threat — the enumeration residual.)*
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
**authenticated checkpoint** and the consensus assumptions, and that the only rule-bound replacement of an accepted continuation above the checkpoint is the executed stall resolution of `GOV-04` — full-range, resume-only, writes no checkpoint — while nothing at or below the checkpoint is ever replaced (increment 05; the D-16 "no history-replacement path" form is history) *(R5R1-NR-01: re-based on the live `GOV-04`.)*

---

## 7. Requirements acceptance matrix

Design response column is completed by Phase 3/4; evidence tags are **Proven** (argument +
named premises), **Assumed** (justification + consequence of failure), **Open** (evidence or
decision needed). Numbers are tagged **derived**, **sourced**, or **unmeasured**.

| ID | Requirement (abridged) | Design response | Evidence | Status |
|----|------------------------|-----------------|----------|--------|
| R1 | All operational roles permissionless, objective entry/exit, no whitelist; staking per D7 | *(Phase 4)* | *(Phase 4)* | Open |
| R2 | DAO governs upgrades only, plus the one rule-bound runtime action of `GOV-04` (queueing a stall-resolution entry whose trigger, stored timelock, consumed execution and resume-only effect the rule fixes); no other DAO intervention in ordinary progress, failure or roles *(R5R1-NR-01: `GOV-04` is live again by increment 05.)* | *(Phase 4)* | *(Phase 4)* | Open |
| R3 | Preserve D3 shared-contract addresses with a concrete migration plan | *(Phase 4)* | *(Phase 4)* | Open |
| R4 | 2 s L2 block production under explicit assumptions; cadence distinguished from every confirmation and settlement latency | *(Phase 4)* | *(Phase 4)* | Open |
| R5 | Consensus safety and the selected mode's confirmation guarantees across leader change, set change and proof delays; Mode A preferred, Mode B selected by D-7. The permissionless recovery stays withdrawn (D-15); the replacement is live again by increment 05 as the timelocked, resume-only `GOV-04` with `REC-01`–`REC-04`, and its resistance analysis is `REC-03` (conditional on P1–P4, falsifiers F-GOV-1–F-GOV-6, its own review owed). Above the last L1-accepted checkpoint a confirmation stays provisional and value is unprotected; v1 ships the safe halt with the checkpoint boundary and the exit *(R5R1-NR-01: re-based.)* | *(Phase 3)* | *(Phase 3)* | Open |
| R6 | Conditional liveness under explicit network/honest-stake/DA/L1 assumptions; exact conditions where liveness ends | *(Phase 4)* | *(Phase 4)* | Open |
| R7 | Complete proof statement for execution + the selected mode's consensus/finality rules, including the **signed** recovery generation that scopes certificates, locks and uniqueness — a field of the vote and block-header bytes and a signed journal input, with the two-case rule for certificates at or below the checkpoint versus above it (`GOV-04`(h), `L1-05` row 31, `PRF-02`/`PRF-05`; increment 05). Credible on RISC Zero **and** SP1. Aggregation remains deferred (D-16/D-13) and is not part of the v1 statement *(R5R1-NR-01: the signed generation is live, not merely "kept".)* | *(Phase 2/4)* | *(Phase 2/4)* | Open |
| R8 | Sufficient data on Ethereum (blobs/calldata) bound to the accepted proof; no private witness/committee certificate as a substitute | *(Phase 4)* | *(Phase 4)* | Open |
| R9 | D5's proof-gated acceptance for every accepted batch, as relaxed by D-11 (data may be published and recorded earlier; the checkpoint still advances only on a valid proof), including during prover failure; no rule accepts data or advances a checkpoint without a proof, and the only rule that removes anything above the checkpoint — the executed `GOV-04` — accepts no data and writes no checkpoint *(R5R1-NR-01: re-based.)* | *(Phase 4)* | *(Phase 4)* | Open |
| R10 | Censorship resistance and forced inclusion, without an override that violates D2 — **restated by D-6/D-10/D-12/D-16 and re-based on increments 04 and 05**: state censorship resistance honestly. **Published data has the narrow inclusion obligation** of `FI-10`–`FI-14` (revived by increment 04): from a record's due point every accepted batch must resolve the capped FIFO prefix of the due set in positions per batch, enforced in the proof, with the per-transaction *executed* / *void* / *dead* walk and its totality and anti-void properties; it is **not a latency guarantee** and is conditional on at least one honest or rational producer (F-FI-5) and on arrivals within the forceable drain (F-FI-2, open). **Unpublished data still has no inclusion obligation**, and there is **no general inclusion list** (D-10): no queue of arbitrary transactions, no escrow, no forced-inclusion fee and no L1 entry point for unpublished data. Resistance for unpublished data is only the conditional statistical property of proposer rotation and gossip under A-CONS-2; a network-level adversary able to isolate a user — or to censor L1 inclusion itself (A-L1-1) — can exclude that user indefinitely and can prevent the user from starting a withdrawal, with no protocol remedy. The falsifiers the live obligation carries — F-FI-1, F-FI-2, F-FI-3, F-FI-4, F-FI-5, F-FI-6, F-FI-7 and F-FI-8 (the enumeration residual) — are carried Open or disclosed in `LIVE-04`/`LIM-01` (spec/10). No override that violates D2 may be introduced *(R5R1-NR-01: the published half is re-based on increment 04; the unpublished and general-list absences remain.)* | stated by `LIVE-04` (spec/10) and `FI-10`–`FI-14` (spec/04); the general inclusion list stays absent and is recorded in `DEFERRED.md` §1 with tombstoned ids in spec/04 | Proven (statement honesty) / Assumed (A-CONS-2, A-L1-1, F-FI-5) | Satisfied **only in its relaxed form**: the narrow obligation over published data is live, the general inclusion list is explicitly not satisfied, and unpublished data has no inclusion duty |
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
   rollback-depth/duration/user-exposure limits. No universal bound on economic loss may be invented. *(Addressed by increment 05: `GOV-04`(a)–(j) specify the trigger, the DAO queue and the permissionless execution, the stored delay and the checkpoint boundary; `REC-02`/`REC-04` state the late-certificate/proof and replay treatment (`MSG-02` unchanged); the rollback depth is the whole provisional range above the checkpoint, and the user-exposure limits are stated as `REC-03`'s residuals 1–6 with no universal bound on economic loss.)*
5. Mode B must additionally show that, **within the stated normal-operation assumptions**, an
   ordinary malicious leader or sub-threshold coalition cannot cheaply trigger a recovery that
   replaces honestly confirmed history — with quantified attacker resources, penalties and
   rollback exposure. Inability to establish this is a **blocker**, not a disclosure item. *(Addressed by increment 05: `REC-03` claims that, under P1–P4, a sub-threshold coalition cannot make the stall-resolution trigger true — the trigger never becomes true while finalization, publication and proving remain live — and names its falsifiers F-GOV-1–F-GOV-6; the analysis is conditional and its own independent review is owed, so the item is addressed rather than settled.)*

*History and current disposition. D-16 deferred the Mode B obligations 4 and 5: the permissionless recovery was withdrawn by D-15, and its replacement, the governance stall resolution of `GOV-04`, was deferred by D-16 at that time (history). Increment 05 revived that replacement as a live rule: obligation 4's trigger, invoker (DAO queueing, permissionless execution), stored delay, checkpoint boundary, late certificate/proof treatment and replay references are specified in `GOV-04`(a)–(j) and `REC-01`–`REC-04`; obligation 5's resistance analysis is `REC-03`, conditional on P1–P4 and carrying the falsifiers F-GOV-1–F-GOV-6, with its own independent review owed. What remains a disclosure is the re-scoped v1 assumption A-GOV-2: clearing a stall depends on governance liveness, with no protocol bound (F-GOV-1), and the churn residue F-GOV-3 is disclosed rather than constrained.* *(R5R1-NR-01: the D-16 deferral of obligations 4 and 5 is history; increment 05 revived both.)*

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
with the proofs that no longer apply), the selected recovery mode and the record of its disposition under the D2 procedure (D-15 withdrew the permissionless recovery; D-16 deferred the governance replacement, and increment 05 revived that replacement as the live, timelocked, resume-only `GOV-04`, whose availability depends on governance liveness with no protocol bound — A-GOV-2, F-GOV-1), and the architecture decision log entry with tradeoffs. *(R5R1-NR-01: re-based.)*
