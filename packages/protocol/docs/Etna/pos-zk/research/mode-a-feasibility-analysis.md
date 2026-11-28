# Mode A feasibility analysis (D2 step 1–2 input)

Author: lead architect · Date: 2026-10-05 · Status: **draft for independent review**
Pinned baseline: `7718753c1` · Companion: `01-requirements-and-threat-model.md`, `04-architecture-decision.md`

This note performs D2's ordered decision procedure *before* any architecture is frozen. It asks one
question only: **can Mode A satisfy every other hard requirement under explicit assumptions?**
It deliberately tries to falsify Mode A. A safe halt outside the stated liveness assumptions is
permitted by D2 step 1 and is therefore **not** by itself evidence of infeasibility.

---

## 1. What Mode A obliges the protocol to do

**M-A1 (no revocation).** No recovery mechanism, timeout rule, validator rotation, L1 admission
rule, or normal upgrade may invalidate a block that received legitimate PoS finality.

**M-A2 (uniqueness under assumptions).** Under the stated consensus assumptions, a
PoS-finalized block lies on exactly one canonical history, and that history is a prefix of every
later finalized history.

**M-A3 (safe halt).** When the information or participation needed to continue *without violating
M-A1* cannot be obtained, honest participants **stop**. They do not choose between two histories,
and they do not "recover" by discarding finalized blocks.

**M-A4 (no disguised recovery).** No emergency operator, no DAO rescue, no data-first path, and no
economic mechanism may achieve the effect of M-A3's violation under another name.

**What Mode A does *not* promise:** liveness outside its assumptions; that a finalized block is
quickly provable, quickly settled, or quickly withdrawable; that data for a finalized block is
retrievable forever; or that users cannot lose money when liveness assumptions fail.

---

## 2. The requirement set Mode A must still satisfy

D1 (2 s cadence) · D3 (shared addresses) · D4 (PoS sequencing) · D5 (atomic data+proof, no
exceptions) · D6 (minutes-to-30-min proving is normal; sustained throughput; safe failure handling)
· D7 (TAIKO staking) · R1 permissionless roles · R2 DAO = upgrades only · R5 safety + confirmation
guarantees · R6 conditional liveness · R8 public data bound to proof · R9 D5 everywhere ·
R10 forced inclusion without a D2-violating override · R11 objective misconduct evidence ·
R12 no L1 lookahead dependence.

Mode A is infeasible **only if** one of these requirements provably cannot hold while M-A1…M-A4
hold. Below, each candidate infeasibility argument is stated in its strongest form and then tested.

---

## 3. Candidate infeasibility arguments

### C1 — "Data withheld after finality ⇒ the chain can never advance ⇒ Mode A is unusable"

*Strongest form.* A proposer finalizes block N with a quorum but withholds the block body. Honest
validators voted, so they hold the body, but they are all later taken offline / the node set turns
over. The next proposer cannot execute block N+1 (no parent state), so production stops; settlement
never happens; users are locked out forever. A rollback to N−1 would fix it; Mode A forbids it.

*Analysis.* This is a genuine failure, but it is a **liveness** failure caused by the failure of
assumption A-CONS-5 (correct validators hold and serve the data they voted for) plus A-DA-2. Note
who holds what: a block can only be finalized if ≥2/3 of stake signed, and correct signers voted
only after receiving and validating the block. Under A-CONS-1 (<1/3 Byzantine), ≥1/3 of stake is
correct and holds the body. The chain is recoverable by any single surviving holder — including a
non-validator full node that mirrored the data. Mode A's answer is: **halt until data is
recovered**, and additionally *design so this is unlikely and detectable*: erasure-coded
dissemination, retention duties with objective penalties, public retention windows, and an explicit
retention assumption recorded as a liveness premise (not hidden).

*Verdict.* Does **not** falsify Mode A. It falsifies the assumption, and the requirement set only
demands conditional liveness (R6). Recorded consequence: outside A-CONS-5 the protocol halts
permanently unless data is restored; this is disclosed, not repaired by rollback.

### C2 — "Validator exodus ⇒ quorum lost ⇒ need to reset the chain"

*Strongest form.* Validators exit (price collapse, regulation, key loss), fewer than 2/3 of stake
remains online, and no new stake arrives. Liveness dies; the only fix is to restart from an older
checkpoint with a fresh validator set — which discards finalized blocks.

*Analysis.* D2 step 1 explicitly permits a safe halt outside the stated liveness assumptions, and
this scenario is exactly that (A-CONS-2 / A-ECO-1 / A-ECO-2 failure). A restart that discards
finalized blocks is a Mode B behaviour; adopting it *because* a halt is possible is precisely what
D2 forbids. Note that new participants may join at any time (R1) and continue the chain from the
**tip** — not from an older checkpoint — provided the tip's data is available.

*Verdict.* Does not falsify Mode A.

### C3 — "A PoS-finalized batch may be unprovable ⇒ its proof never lands ⇒ settlement is stuck forever, so the finalized prefix must be discardable"

*Strongest form.* If the finalized chain can contain a block whose ZK proof can never be produced
(because the block depends on an L1 fact that later changed, or because the execution is outside
what the guest can prove), then the L1 checkpoint stalls permanently *for all later blocks too*,
since L1 accepts only extensions of its checkpoint. Then the chain is unusable and only a rollback
can restore it.

*Analysis.* Two distinct sub-cases, and they have different answers.

1. **Unprovable because of an L1 fact that is not yet Ethereum-final.** This is a real design
   hazard, and Mode A must eliminate it structurally rather than hope: **only Ethereum-final L1
   facts may enter L2 consensused state** (rule candidate `L1-FINAL-ONLY`). If L2 execution or
   message authentication consumes an L1 block hash or state root that can still be reorged, then a
   legitimately finalized L2 block can become unprovable against canonical L1 — and Mode A would
   have no legal response. With the rule in place, the proof of a finalized block is always
   constructible from Ethereum-final data plus L2 data. Cost: L1→L2 message latency is bounded
   below by Ethereum finality (≈2 epochs, order of 13 min); this is a latency cost, not a safety
   cost, and it is compatible with R12 (the parameter is expressed in L1 block numbers/seconds, not
   in proposer lookahead). D1 explicitly does not require L1→L2 latency to be 2 s.
2. **Unprovable because provers are unavailable.** Proof production is permissionless and
   rewarded; a batch's proof can be produced by anyone with the (public) data. Under A-DA-2 the
   protocol resumes; outside A-DA-2 it halts safely at the L1 checkpoint while L2 continues until
   the backlog rule binds. Discarding finalized history is not required.

*Verdict.* Does not falsify Mode A, but it **forces a normative rule** (L1-final-only facts) and a
disclosed latency cost. If that rule cannot be implemented (because some required L1 fact cannot be
read at finality depth), Mode A would be in serious difficulty — this is a named falsifier to
check in review (§6).

### C4 — "L1 rejects a legitimate extension ⇒ PoS finality conflicts with L1 admission"

*Strongest form.* If L1 admission rules (proof windows, proposer permissioning, bond requirements,
epoch checks) can reject a batch that extends the L1 checkpoint, the L2 chain and L1 diverge and
PoS-finalized blocks can never settle — a de-facto safety conflict resolvable only by rollback.

*Analysis.* L1 accepts only (data, proof) pairs that (i) verify and (ii) extend L1's current
checkpoint. Under M-A2, every L1-accepted checkpoint is itself a PoS-finalized block on the unique
chain, so any legitimate extension of the tip is *accepted* once its data and proof arrive.
Admission must therefore not contain discretionary gates (no permissioned proposer/prover, no
"only the original proposer may submit", no expiry that forbids a later, correct submission of the
*same* batch by a different prover). Sequencing rules that let L1 accept *older* ranges
(skipping settled ones) are permitted because they do not invalidate anything: the L1 checkpoint
simply advances later. **Careful exception:** an admission rule that requires strictly sequential
submission and *expires* an unproven range would create an unrecoverable gap — such a rule must be
absent, or must be paired with a re-submission path for the same range. This is a design
constraint on R9/R10/R11, not a Mode A defect.

*Verdict.* Does not falsify Mode A; yields admission rules `L1-ADMIT-*`.

### C5 — "Long-range attack / weak subjectivity ⇒ Mode A needs a trusted checkpoint, i.e. a privileged operator"

*Strongest form.* A permissionless PoS chain cannot be synced from genesis without a trust
assumption; the fix is a checkpoint provider, which is a privileged role and violates R1/R2.

*Analysis.* Every PoS chain with dynamic membership has this property; Ethereum itself relies on
weak subjectivity. The requirement is to state the trust and freshness requirement exactly, and to
prefer the strongest available checkpoint: **the L1 checkpoint is the natural weak-subjectivity
checkpoint**, because it is Ethereum-committed and publicly auditable, and because the L1 checkpoint
is exactly what L1 will accept as a predecessor. A new node therefore needs: (a) an L1 view, which
it must have anyway to verify settlement, and (b) a freshness bound relating the L1 checkpoint to
the present. No third-party checkpoint provider is required, and no privileged role is introduced.
Users who want maximum safety can wait for L1 acceptance (status 6) rather than trusting a
checkpoint at all.

*Verdict.* Does not falsify Mode A; yields the weak-subjectivity rule set and an honest disclosure
that very old checkpoints must not be used.

### C6 — "An ordinary leader can cheaply stall the chain, and the only way out is L1 recovery"

*Strongest form.* A single malicious leader (or a small coalition) withholds proposals or
certificates, forcing repeated view changes; if the timeout rules are exploitable, the attacker can
stall indefinitely at negligible cost, and honest participants will demand a recovery mechanism.

*Analysis.* View changes and leader rotation handle a single faulty leader under A-CONS-2/A-CONS-3;
the cost of stalling is bounded by the requirement that a correct leader is eventually elected
(round-robin or a verifiable random function over the epoch's set) and by timeouts that are
functions of the *observed* message delays. The residual risk is a *sub-threshold* coalition that
can delay but not finalize conflicting history: it can reduce liveness, never break M-A1/M-A2.
Crucially, the attacker cannot use stalling to *replace* confirmed history, because no such
mechanism exists in Mode A — which is the strongest possible answer to D2 step 5. This does not
mean stalling is cheap; the specification must quantify the stall cost (missed rewards + evidence-
based penalties where objective evidence exists) and must not claim more than that.

*Verdict.* Does not falsify Mode A, and Mode A is *strictly better* than Mode B on this axis
(Mode B introduces the attack surface that D2 step 5 makes a blocker).

### C7 — "D6's sustained-throughput requirement cannot be met with a halt-on-backlog rule"

*Strongest form.* If proving cannot keep up with 2 s block production, the backlog grows without
bound; halting to protect the backlog is a liveness failure that makes the chain unusable, so an
L1 recovery that rewinds the backlog is needed.

*Analysis.* D6 requires processing capacity to keep pace, and permits safe backpressure/halt when
it does not. It does **not** require the protocol to discard committed history to recover
throughput. Discarding unsettled history would not even restore throughput: the data still exists
and still must be proven before its state can be settled; a rollback re-proposes the *same* work.
So Mode B is not a throughput fix. The right answers are: batch sizing that guarantees each batch
completes inside the latency envelope; parallel and pipelined proving; permissionless prover
competition; and an explicit backlog rule that stops *new commitments* before the retention window
is exceeded. All of these are Mode A compatible.

*Verdict.* Does not falsify Mode A; and it removes "throughput" as a justification for Mode B.

### C8 — "Users need fast finality guarantees that a halt-capable mode cannot give"

*Strongest form.* Mode A's halt means users can lose access to funds indefinitely; a rollback-based
mode at least guarantees eventual access via L1.

*Analysis.* Mode B's recovery also requires a *new* honest quorum to exist on L1's terms; if the
failure was a permanent loss of participation, Mode B recovers nothing either, while it *does*
introduce a new class of cheap attacks (see D2 step 5). Moreover Mode B's rollback can destroy
*accepted* user outcomes (inclusion, ordering, bridge messages) that Mode A preserves. The honest
comparison is therefore: Mode A trades unbounded-latency-but-safe against Mode B's
bounded-latency-but-revocable. D2 chooses the former unless it is infeasible.

*Verdict.* Does not falsify Mode A.

---

## 4. Structural constraints Mode A imposes (these become normative rules if Mode A is selected)

| ID (candidate) | Rule | Why Mode A needs it |
|----------------|------|---------------------|
| `L1-FINAL-ONLY` | L2 consensused state may consume only Ethereum-final L1 facts (block hashes/state roots at a configured finality depth, or L1-committed checkpoints). | Otherwise a finalized L2 block can become unprovable ⇒ C3. |
| `CONS-EPOCH-CERT` | A finality certificate is judged against the validator set of its own epoch and remains valid forever; validator rotation never re-judges past certificates. | Otherwise a normal change invalidates finality (violates M-A1). |
| `L1-ADMIT-NO-EXPIRY` | Any prover may submit the *same* batch (same data commitment) later; no admission rule may expire a range into unrecoverability; no permissioned proposer/prover gate. | Otherwise C4 becomes unrecoverable. |
| `UPG-PRESERVE` | A consensus/proof-program upgrade must accept every history finalized under the previous rules as valid; version changes are additive. | Otherwise an upgrade invalidates finality (violates M-A1). |
| `DA-BACKLOG-CAP` | Correct validators stop voting for new blocks when unsettled depth would exceed the retention/DA window; the cap is a consensus rule, not an operator policy. | Protects C1/C7 without rollback. |
| `HALT-RESTART` | On halt, honest participants resume only from the highest finalized block whose data and certificate they can reconstruct; they never adopt an alternative history for the same heights. | M-A3. |
| `WITHDRAWAL-DELAY` | Withdrawal/message-authentication delays are derived from the full settlement pipeline (proof latency + L1 inclusion + Ethereum finality + evidence windows). | D6 economic timing; avoids a delay that a slow proof can outrun. |

---

## 5. Attack surface specific to "no recovery"

Mode A's advantage (D2 step 5) is that the mechanism "replace honestly confirmed history" does not
exist, so it cannot be triggered cheaply, repeatedly, or in a race with honest continuation. The
residual attacks are all **liveness** attacks, and they must be quantified honestly:

- **Stall via leader withholding** — bounded by view-change timeouts and leader rotation; cost to
  attacker = missed rewards for its staked share over the stall duration + objective evidence where
  available. Repeated stalling is observable and rotatable.
- **Stall via certificate withholding** — a coalition that withholds a valid certificate can force
  a view change; it cannot make honest validators adopt a conflicting branch, because the lock rule
  prevents it. The "reveal later" attack in §6 of the requirements cannot produce two irreversible
  histories under A-CONS-1.
- **Stall via data withholding after finality** — C1; mitigated by dissemination and retention
  duties, not by rollback.
- **Griefing the backlog rule** — a prover cartel refusing to prove reduces settlement; proving is
  permissionless and rewarded, and the backlog rule stops *new* commitments only at the cap, so the
  attack costs the attacker forgone fees and does not create a recovery trigger (Mode A has none).
- **Griefing permissionless entry/exit** — bounded by objective, first-come activation queues and
  by not making exit depend on anyone's discretion.

---

## 6. Falsifiers to check in review (what would overturn this analysis)

1. `L1-FINAL-ONLY` is unimplementable: some L1 fact required by shared-contract message
   authentication, forced inclusion, or bridge accounting cannot be read at Ethereum-final depth
   within the L2's own rules. *(Check against the migration and bridge analysis.)*
2. `CONS-EPOCH-CERT` cannot be enforced for a design where the L1 checkpoint and the L2 epoch
   schedule can disagree without either halting or discarding finalized history.
3. The 2 s cadence cannot coexist with the consensus round structure and the epoch/handoff rules
   without a halt-on-normal-jitter behaviour that violates D1 in practice.
4. Per-batch proving for the chosen batch size cannot be shown to fit the envelope even in
   principle (e.g. the consensus evidence for a batch is not constant-size, or the proof statement
   cannot be bounded).
5. A requirement exists that *inherently* demands rewriting finalized history (none has been found
   in this analysis; a candidate would be a hard requirement for bounded withdrawal latency under
   total validator loss).
6. The economic analysis shows that a sub-threshold coalition can profitably force a permanent
   halt (e.g. by exiting with stake and destroying data), making Mode A's guarantee worthless in
   practice while Mode B's revocation would restore value. *(Note: this is an argument about
   economics, not about safety, and must be quantified, not asserted.)*

Each falsifier is carried into Phase 6 review as an explicit question to the independent reviewers.

---

## 7. Preliminary verdict (to be confirmed by independent review)

> **Mode A is feasible and should be selected**, conditional on: (i) rule `L1-FINAL-ONLY`;
> (ii) epoch-scoped, permanently-valid finality certificates; (iii) admission rules with no
> permissioned gate and no expiry into unrecoverability; (iv) upgrade rules that preserve finalized
> history; (v) a consensus-enforced backlog cap; and (vi) honest disclosure that failure of
> A-CONS-5/A-DA-2 causes an unbounded halt rather than a rollback.

No requirement in the matrix requires rewriting finalized history. The known cost is that Mode A
tolerates arbitrarily long halts outside its liveness assumptions, which D2 step 1 explicitly
permits.

**Mode B status:** not selected, but specified at the level needed to (a) show the fallback exists,
(b) identify precisely which conditions would have to change for it to become necessary, and
(c) avoid designing Mode A in a way that makes the authorized fallback unimplementable. Mode B is
**not** described as satisfying Mode A's irreversible-finality promise.
