# Round 4 — Liveness, user exposure, censorship and migration (adversarial review)

**Role:** fresh independent adversarial reviewer, round 4. **Snapshot:** `fe7373a13`
(`docs(protocol): Mode B selected (D-7), fee-funded security (D-8), treasury penalties (D-9),
forced inclusion deferred (D-10)`). **Angle:** liveness, user exposure, censorship and migration.
**Targets:** `spec/10-assurance.html`, `spec/01-system-model.html`, `spec/08-migration-upgrades.html`,
`spec/04-l1-integration.html` (MSG-01..03, FI rules), `spec/06-recovery-exceptions.html` (REC/HALT/WH),
`spec/07-economics-slashing.html`, `spec/09-parameters.html`, `spec/index.html` (STATUS-04, STATUS-11),
`01-requirements-and-threat-model.md`, `learn/`.

**Method.** Rule text was read as written; every in-text "(review round N)" note was treated as a claim,
not evidence, and re-checked against the current text. Prior ledgers (`iterations/01-round.md`,
`02-round.md`, `03-round.md` and the round-3 raw findings) were read first so that closed findings are
not re-listed. Round-3 open items that are still present are re-reported only where the D-7 change makes
them live.

**Result: 0 Critical, 5 High, 4 Medium, 1 Low.** No two-conflicting-canonical-histories attack was found
in this angle, and no double execution of a bridge effect was found (see "Checked and holds"). The
strongest attack is **R4-LIV-04** (a benign configuration upgrade blanks provisional history above the
checkpoint, i.e. a governance transaction replaces history that REC-01(d) reserves to REC-02); it is
inside the claimed fault model and needs no adversary. **R4-LIV-01, R4-LIV-03, R4-LIV-04 and R4-LIV-05
are inside the fault model; R4-LIV-06 is a defect in the fault-model argument itself.**

---

## R4-LIV-01 — The mandated withdrawal-timing disclosure is stale Mode A text that promises "losing nothing"

**Severity: High.** One-line rationale: the one rule that fixes what users must be told about
withdrawals during a settlement halt still cites Mode A and requires the statement that the user loses
nothing, which REC-02, LIM-01 and ECON-11(3) all forbid.

**Exact rule.** `spec/04-l1-integration.html` MSG-03, lines 656–657: "The design MUST disclose, wherever
withdrawal timing is described, that a settlement halt delays withdrawals indefinitely while losing
nothing: under Mode A the funds are not forfeited, they are unavailable until settlement resumes
(LIM-01)."

**Conflict.**
- `spec/06-recovery-exceptions.html` REC-02, "User exposure" (line 368): "Every L2 outcome above the
  checkpoint: inclusions, ordering, balances, bridge messages not yet settled, and any economic position
  built on them. **No universal bound on economic loss exists** and none may be claimed."
- REC-02, "Transaction replay" (line 364): "unsettled withdrawals must be resubmitted" — a withdrawal in
  the replaced range is not merely delayed; it is erased and must be re-created from the restored state.
- `spec/07-economics-slashing.html` ECON-11(3) (lines 870–875): "No rule, document, interface, learning
  page or marketing text may state or imply a universal bound on user economic loss." "Losing nothing"
  is a universal bound of zero.
- `spec/10-assurance.html` LIM-01, "Guarantee class" and "Economic" rows (lines 229, 237) repeat the
  unbounded-exposure disclosure.
- `iterations/04-change-order.md` §1 requires every artifact that describes the recovery mode to change
  from the old posture; §7 requires the course to teach "what happens to a user's transactions when
  history is rolled back". MSG-03 was not changed.

**Assumptions and preconditions.** A user holds a withdrawal whose L2 source block is above the latest
L1-accepted checkpoint (the normal case for anything not yet settled); a settlement stall occurs; a
recovery completes.

**Concrete attack trace.** (1) A user starts a withdrawal of an L2 balance in block H > C (the latest
accepted checkpoint). (2) The bridge UI shows the withdrawal as pending and reproduces the MSG-03 text:
"delays withdrawals indefinitely while losing nothing". (3) The user relies on that — does not re-plan,
and settles an off-chain obligation against the pending withdrawal (OTC sale, loan repayment, treasury
operation). (4) A settlement stall persists past T_STALL; any account invokes REC-02; no valid batch
lands during T_RECOVERY_DELAY; the recovery completes and discards H. (5) The withdrawal never existed;
the L2 state is the checkpoint state; the counterparty of the off-chain obligation is unpaid and the
user was told the halt "loses nothing". No protocol penalty compensates (ECON-11(1)–(4)).

**Inside/outside the fault model.** Inside. No adversary is needed: a settlement stall is an accepted,
disclosed failure mode of this design, and the harm comes from the normative disclosure text itself.

**Attacker resources and cost.** None; the exposure is created by the interface text the rule mandates.

**Harm and the requirement/decision affected.** R14 (learning/interface consistency), the D-7 guarantee
class, ECON-11(3)'s prohibition on implying a universal loss bound, REC-02's user-exposure disclosure,
and STATUS-11's requirement that a replaceable confirmation not be presented as settled. A rule that
*mandates* a forbidden reassurance is worse than an omission: a conforming UI cannot satisfy both
MSG-03 and ECON-11(3).

**Evidence.** MSG-03 (`spec/04-l1-integration.html`:649–660, sentence at 656–657); REC-02 rows
(`spec/06-recovery-exceptions.html`:364, 368); ECON-11(3) (`spec/07-economics-slashing.html`:870–875);
LIM-01 (`spec/10-assurance.html`:229, 237); `iterations/04-change-order.md` §1, §7.

---

## R4-LIV-02 — Stale Mode A guarantee class survives in the requirements matrix and a normative-looking economics summary

**Severity: Medium.** One-line rationale: two deliverables that users and compliance checks read still
state that recovery may never invalidate a "PoS-finalized" block and that STATUS-04 is "Mode B only",
contradicting the selected mode's label and guarantee.

**Exact rules/statements.**
- `spec/07-economics-slashing.html`:30–32, in the page's "Fixed decisions applied here" box: "No
  recovery, timeout or penalty may invalidate a PoS-finalized block (D2, REC-01); penalties debit stake,
  they never rewrite history." Under D-7 a completed recovery does exactly this above the last
  L1-accepted checkpoint; STATUS-04 (index:195–225) says the confirmation "MAY BE REPLACED"; change order
  04 §2 renamed it "PoS-certified / provisional" and forbade calling it final.
- `01-requirements-and-threat-model.md`:54–55: status 4a is "**PoS-finalized** (Mode A) … permanently …
  **never** in Mode A" and 4b is "**PoS-certified / provisional** (**Mode B only**)". Mode B is selected;
  STATUS-04 is provisional in all cases (change order 04 §2), and there is no "Mode A-only" status for a
  PoS certificate above the checkpoint.
- `01-requirements-and-threat-model.md`:146: F1 behaviour "Never rewrite finalized history (Mode A)";
  :27: D2 still reads "Prefer **Mode A** … Only after an evidenced infeasibility argument plus independent
  review may **Mode B** … be selected", while D-7 has completed that procedure.

**Missing rule.** No artifact-level sweep re-based D2's narrative, the status table and the F-class table
on D-7; change order 04 §1 required exactly such a sweep.

**Assumptions and preconditions.** None; text-level.

**Concrete attack trace.** An implementer or auditor derives the admission/rollback rules from the
requirements matrix (the document the README's requirement table points at for R5/R10): status 4a is
"permanent", 4b does not exist in the selected mode, and F1 says history is never rewritten. The same
reader then finds REC-02 discarding a STATUS-04 range and concludes the specification violates R5, or
"fixes" the recovery to preserve it. Either reading contradicts one of the two artifacts.

**Inside/outside.** Inside (documentation contradiction; no adversary).

**Attacker resources and cost.** None.

**Harm.** R13/R14, D-7's guarantee class, GEN-03 (one rule stated once), and the compliance instrument
used to judge R5/R10.

**Evidence.** `spec/07-economics-slashing.html`:30–32 (and :862, where ECON-11(1) repeats
"No penalty reverses a PoS-finalized block"); `01-requirements-and-threat-model.md`:27, 54–55, 146;
`spec/index.html`:195–225; `iterations/04-change-order.md` §1–§2.

---

## R4-LIV-03 — Recovery has no specified entry point, no custody rule and no budgeted state; MIG-02's "complete" slot list contradicts L1-05 row 31 and REC-02

**Severity: High.** One-line rationale: the selected recovery is normative in every economic respect but
has no named contract/function, no bond custody, no concurrency or trigger-check semantics, and none of
its L1 state (generation, pending invocation, REC_WINDOW history, cooldown) appears in the frozen
migration change list that forbids unlisted Inbox state.

**Exact rules / missing rules.**
- `spec/06-recovery-exceptions.html` REC-02, "Who may invoke" (line 358): "Any account,
  permissionlessly, by posting the bond `B_REC(e) = B_REC_BASE · 2^n` **in ETH on L1, paid at
  invocation** … The invocation is an L1 transaction containing only the claim and the bond." No
  contract or function is named (contrast L1-01, which fixes `land(data, proof)` exactly, and
  `spec/04-l1-integration.html`:42–54, which calls a second name for it "a defect").
- REC-02 "Bond outcome" (line 360): the bond is held and then returned or sent to the treasury — but no
  rule says which contract holds it, whether the Inbox may receive and custody ETH, or what happens if
  the Inbox implementation is upgraded (08's rule that a pending recovery "must survive the upgrade
  unchanged" presupposes a defined record).
- `spec/04-l1-integration.html` L1-05 row 31 (line 164): `recoveryGeneration` is "a monotonically
  increasing counter held in the Inbox's own storage with the accepted predecessor checkpoint".
- `spec/08-migration-upgrades.html` MIG-02 (line 232): "The complete change list is the table below;
  any change not in it requires a new decision recorded in the decision log"; the table (lines 257–271)
  enumerates exactly ten Inbox declarations, slots 258–267 — `migrationState`, genesis fields,
  `acceptedProgramImage`, `retiredAtEpoch`, `lastLandedHeight`(+3 packed), `checkpoints`,
  `checkpointRouteVersion`, `proverReward`, `verifierRoutes` — and the text claims "the budget now
  enumerates **every required object** … with its holder and slot cost" (lines 304–308). No slot holds
  `recoveryGeneration`, the pending invocation (invoker, invoked-at, bond), the completed-recovery
  record needed for `n` in `B_REC_BASE · 2^n` over `REC_WINDOW`, or the `REC_COOLDOWN` timestamp.
- Missing semantics: is the objective trigger checked when the invocation is accepted ("no early
  declaration", REC-02 line 357), or is an early invocation merely priced by the risk of cancellation?
  May a second invocation be posted while one is pending, and whose bond is slashed/returned then? Is the
  invocation's deadline snapshotted so an upgrade cannot move it (08:169–181 and GOV-03(e) require the
  pending recovery to be carried "unchanged" but define no record)?
- Missing rule for clients: HALT-02(d) requires a node to "adopt" the restored checkpoint, but no rule
  fixes how a completed recovery is observed (event or storage read), at what L1 finality depth a node
  may rewind L2 state, or what happens if the completion transaction is reorganised out after a node has
  rewound. SYS-02 restricts *consensused* consumption of L1 facts; a rewind is a local destructive
  action and is not covered.

**Assumptions and preconditions.** Any implementation of REC-02; the D-7 selection.

**Concrete attack trace.** (a) An implementer follows MIG-02 literally and cannot store the generation
counter, so `land(data, proof)` cannot supply the L1-derived `recoveryGeneration` required by PRF-02(5)
and L1-05 row 31 — the batch-acceptance gate that stops an alternative history from landing does not
exist. (b) Or the implementer invents a slot not in the change list; the "complete list" audit then fails
and a later migration may declare the layout non-conforming. (c) An invoker sees a batch about to land
within T_RECOVERY_DELAY but the invocation record/deadline is not observable by rule, so the
cancellation race cannot be run deterministically by independent provers, weakening the only defence
REC-03 claims (honest progress cancels). (d) A node rewinds on a non-final L1 completion; the completion
is reorged out; the provisional blocks were never on L1 (D5) and the node has destroyed the only copy it
held, while L2 peers must be trusted (STATUS-09) to restore them.

**Inside/outside.** Inside; text/interface-level, no adversary.

**Attacker resources and cost.** None for (a)–(c); (d) needs only an ordinary L1 reorg below finality.

**Harm.** R13 (implementable without inventing rules), R9 (the recovery path's state), R5/D-7 (the
generation check is the mechanism that makes recovery safe), and MIG-02's own normative completeness
claim. This is the same defect class as round-2 E-R2-03 (slot budget omitting required state), reopened
by D-7.

**Evidence.** REC-02 rows at `spec/06-recovery-exceptions.html`:357–360, 367; L1-05 row 31
(`spec/04-l1-integration.html`:164); MIG-02 (`spec/08-migration-upgrades.html`:232, 257–271, 304–308);
GOV-03(e) and the in-flight-recovery paragraph (08:169–181, 618–625); HALT-02 (06:111–134);
PRF-02(5) (`spec/05-proof-statement.html`:177–188); `spec/09-parameters.html`:146–149.

---

## R4-LIV-04 — A benign configuration upgrade blanks all provisional history above the checkpoint, i.e. a governance transaction substitutes for recovery

**Severity: High.** One-line rationale: `configHash` is a single L1-stored value that covers the
recovery parameters, has no per-epoch registry and no budgeted historical mapping, so any routine
parameter upgrade changes it and makes every in-flight proof for an unsettled batch fail — replacing
history that REC-01(d)/GOV-03(e) reserve to REC-02, without bond, delay or cancellation.

**Exact rules.**
- `spec/05-proof-statement.html` PRF-02 journal (lines 106–111): "`configHash` … binds the exact
  configuration under which the batch was certified and executed (epoch schedule and `L`, quorum
  predicate, DA-mode rules, parameter version and **the recovery parameters**)".
- PRF-02 constraint (5) (lines 177–188): "`configHash` and `recoveryGeneration` are read by the L1
  contract from its own storage … and are never supplied by the prover"; L1-05 row 23
  (`spec/04-l1-integration.html`:156) makes it an L1-derived public input.
- `spec/08-migration-upgrades.html` MIG-02 (lines 298–302): protocol parameters are constructor
  immutables of the settlement implementation and "they change only by upgrade". MIG-05 (lines 519–526)
  gives program images a per-epoch, never-deleted registry, but there is no analogous rule, mapping or
  slot for `configHash`.
- `spec/06-recovery-exceptions.html` REC-01(d) (lines 56–59): a history above the checkpoint "may be
  replaced only by REC-02, never by a governance transaction"; GOV-03(b)/(e) (08:618–625) require that
  no batch becomes unprovable because of an upgrade and that an upgrade never substitute for recovery;
  INV-01 (10:34) states "no timeout, rotation, admission rule, governance upgrade, operator action or
  failure of a liveness assumption may replace history".

**Missing rule.** Either (i) `configHash` is epoch-keyed and additive (an upgrade MUST keep accepting
the `configHash` in force for each unsettled epoch, with the registry budgeted as MIG-05's image
registry is), or (ii) a configuration-changing upgrade MUST be epoch-gated and MUST NOT change the
configuration under which an unsettled certificate was produced. Neither exists.

**Assumptions and preconditions.** A batch is certified under `configHash = C1` for heights above the
checkpoint; its proof is in flight (D6 allows 30 minutes, and provers may be queued); the DAO executes a
routine parameter upgrade — e.g. retunes `T_RECOVERY_DELAY`, `B_REC_BASE` or `REWARD_QUOTE`, every one
of which is unmeasured and expected to change after the economics spike. A-GOV-1 (honest DAO) is assumed;
no malicious governance is needed.

**Concrete attack trace.** (1) Checkpoint `C`; blocks `C+1..H` reach STATUS-04 under `C1`; users act on
them (trades, bridge messages, withdrawals started). (2) A proof for `C+1..H` is being produced, or is
already produced but not yet mined. (3) The DAO upgrades the Inbox to retune a recovery parameter; the
Inbox now supplies `C2`. (4) The in-flight proof carries `C1`, fails the guest check, and the batch is
unlandable; `land` also refuses any other range because L1-06 requires continuity from `C`. (5) The
only rule that can restore progress is now REC-02 — the upgrade has done by configuration what REC-01(d)
says only recovery may do, without the objective trigger, the bond, the delay or the cancellation by
honest progress, and without the STATUS-11 replacement disclosure having been triggered by any recovery.
Every user outcome in `C+1..H` is discarded.

**Inside/outside the fault model.** Inside. No adversary, no failed assumption: a benign upgrade plus an
ordinary proving pipeline. (It is also reachable maliciously, but that is not needed.)

**Attacker resources and cost.** One DAO upgrade bundle (gas), or none at all if the upgrade is
otherwise scheduled.

**Harm and the requirement/decision affected.** REC-01(d), GOV-03(b)/(e), INV-01, R2 (DAO governs
upgrades only — an upgrade must not be a history-replacement path), R13; D-7's rule that only REC-02
replaces provisional history.

**Evidence.** PRF-02 (`spec/05-proof-statement.html`:106–111, 177–188); L1-05 rows 23 and 31
(`spec/04-l1-integration.html`:156, 164); MIG-02/MIG-05 (`spec/08-migration-upgrades.html`:298–302,
519–526); REC-01(d) (`spec/06-recovery-exceptions.html`:56–59); GOV-03 (`spec/08-migration-upgrades.html`:
618–625); INV-01 (`spec/10-assurance.html`:34).

---

## R4-LIV-05 — "Not a free option" is contradicted by REC-02: the bond is refunded in full on completion, so a successful rollback is not priced

**Severity: High.** One-line rationale: REC-03/LIM-01/learn present the bond as the price of a
manipulation, but a completed recovery returns the bond in full; the escalation and cooldown price only
*cancelled* attempts, temporary lock-up and frequency, never the successful rollback that the analysis is
about.

**Exact rules.**
- `spec/06-recovery-exceptions.html` REC-03 (line 402): "Recovery is therefore a manipulation primitive
  with a price, **not a free option**." Its falsifier (c) (line 405) is "the bond were refundable **on
  cancellation**".
- REC-02, "Bond outcome" (line 360): "[the bond] is **returned in full when the recovery completes**, and
  transferred to the protocol treasury when the recovery is cancelled by honest progress."
- `spec/07-economics-slashing.html` ECON-06(6) (lines 535–545) confirms: "when a recovery completes, the
  bond is returned in full to the address that posted it"; the treasury receives only cancellations.
- `spec/10-assurance.html` LIM-01 (lines 238–239): "the bond, delay and cancellation price the attempt
  but do not make it impossible" and "they bound the **price** and the frequency of attempts".
- `learn/limitations.html`:129–135: "a penalty that sends the bond to the protocol treasury rather than
  back to the invoker … The attempt is never free."

**Assumptions and preconditions.** The trigger has fired (by REC-03's own account this requires
suppressing every prover or L1-level interference) and no valid batch is accepted during
`T_RECOVERY_DELAY` — which is exactly the condition that produced the stall, so an invoker who waits for
the objective trigger expects completion, not cancellation.

**Concrete attack trace.** Adversary holds a provisional position worth `V` that a completed recovery
destroys (e.g. an unfavourable DEX fill or a bridge message about to release). They wait until the
objective trigger holds (or exploit a prover outage, R4-LIV-06), post `B_REC` in ETH, keep no batch from
landing for `T_RECOVERY_DELAY`, and complete. Cost: two L1 transactions plus gas plus the temporary
lock-up of `B_REC`; `B_REC` is returned. Benefit: `V`. Repetition is gated only by `REC_COOLDOWN` and
the `2^n` deposit size, both unmeasured, and REC-02 itself concedes "Repetition is expensive but is
neither forbidden nor bounded by these rules alone" (line 367). The only state in which the bond is
actually lost is a cancelled attempt, i.e. a *failed* manipulation.

**Inside/outside the fault model.** The pricing defect is inside (it is a contradiction between two
normative rules and their disclosure). The *inducement* precondition is outside the L2 fault model per
REC-03, but that does not rescue the claim: REC-03's conclusion is specifically that the mechanism is
"priced", and by its own mechanism a successful use is not.

**Attacker resources and cost.** `B_REC` (returned) + L1 gas + the cost of inducing/holding the stall;
no slashable TAIKO, so A-ECO-1 does not apply to this actor at all.

**Harm and the requirement/decision affected.** LIM-01's completeness and honesty ("manipulation
primitive with a price"), the learn page's user-facing claim, and Q-B1: D-7 makes the selection
conditional on REC-03 surviving review, and this part of REC-03 does not survive as written. R13.

**Evidence.** REC-02 (`spec/06-recovery-exceptions.html`:360, 367); REC-03 (06:384–418, quotes at
402, 405); ECON-06(6) (`spec/07-economics-slashing.html`:535–545); LIM-01 (`spec/10-assurance.html`:
238–239); `learn/limitations.html`:129–135; `spec/09-parameters.html`:145–148.

---

## R4-LIV-06 — REC-03 does not establish that the trigger cannot be induced inside the fault model: an unpaid/outbid prover is not an attack, and T_STALL has no inclusion-delay term

**Severity: High.** One-line rationale: the load-bearing premise "proving is permissionless and
rewarded" is contradicted elsewhere in the same specification (an empty pool pays nothing, and
`land` may pay zero), and `T_STALL` contains no L1 inclusion-delay or congestion term and no inequality
against A-L1-1's bounded-inclusion assumption, so "induce the trigger" is not equivalent to "censor L1 or
suppress every prover".

**Exact rules.**
- REC-03 (06:385–402): premises are A-CONS-1, A-CONS-2, A-DA-2, A-L1-1; "(4) proving is permissionless
  and **rewarded** (L1-10) … Therefore batches keep landing, T_STALL never elapses, and a sub-threshold
  coalition **cannot induce the trigger**. … To induce the trigger an attacker must suppress every prover
  or censor the landing transaction at L1 — both outside the L2 fault model."
- `spec/04-l1-integration.html` L1-11 (lines 360–361): "`land(data, proof)` MUST NOT require a non-zero
  `rewardPaid`: if the reward ledger is empty, the batch still lands with `rewardPaid = 0`."
- `spec/07-economics-slashing.html` ECON-02 clause 7(ii): "An empty pool pays nothing"; `REWARD_QUOTE`
  and the sweep's delivered amount are unmeasured. `spec/09-parameters.html`:119–121 still registers the
  funding mechanism as **Open** ("until it exists the pool has no inflow and pays nothing"; "until it
  exists Alloc(e) = 0 and no validator reward can be paid"), while 07's clause 7 now specifies it — the
  register and the owner rule disagree on whether D-8's path exists.
- `spec/01-system-model.html` C3 (line 115) and A-L1-1 (`01-requirements`:127): L1 provides
  "censorship-resistant inclusion of valid transactions within a bounded time", but T_STALL
  (06:357) = `T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY + T_RECOVERY_MARGIN` and
  `T_SETTLE_PIPELINE` is unmeasured with no stated inequality against that bound.

**Missing rule/argument.** REC-03 must either (i) state and justify the inequality
`T_STALL ≥ (pessimistic L1 inclusion delay the protocol admits) + (prover response time)`, or (ii) add
"bought L1 inclusion delay / fee-market congestion", "a rational prover when the reward pool is empty
or below cost", and "a prover that is outbid" to its falsifier list and treat them as conditions of the
argument. Neither exists; D-8's user decision did not make rewards guaranteed, it only named a funding
source.

**Assumptions and preconditions.** No Byzantine L2 quorum is required, so A-CONS-1 holds; A-DA-2 holds
(data is served); A-L1-1 holds (the honest transactions are eventually included). What fails is the
implicit premise that someone is *paid* to land within T_STALL.

**Concrete attack trace.** (1) The reward pool is empty or below the prover's cost (L1-11 explicitly
allows this; 09 says the mechanism that would fill it is Open). (2) Batches stop being landed — no
censorship, no Byzantine quorum, no data problem: every prover is behaving rationally and the honest
validators cannot land (only any account may land; nobody is obliged to). (3) For T_STALL no batch
extends the checkpoint. (4) Any account invokes recovery; no batch can land to cancel it (there is no
paid prover); it completes and discards all provisional history. The adversary in the strong form
replaces step (1) with bought L1 inclusion delay: pay enough priority fees for T_STALL that the honest
`land` transaction misses its calibrated pipeline, without ever preventing its eventual inclusion
(A-L1-1 is untouched).

**Inside/outside the fault model.** The *claim* under attack is REC-03's in-model impossibility claim, so
this is a defect in the fault-model argument. The trace needs no fault-model violation: an empty reward
pool is a configuration the spec permits, and bought delay is not censorship.

**Attacker resources and cost.** Zero in the empty-pool variant; in the congestion variant the cost is
`T_STALL` worth of L1 priority fees plus `B_REC` (returned), against the value of the reverted outcome.
Since the bond is refunded (R4-LIV-05), the cost of a *successful* manipulation is only the stall's
price.

**Harm and the requirement/decision affected.** Q-B1/D-7: the selection is not settled until REC-03
survives review; REC-03 as written overstates its conclusion and omits falsifiers. R6 (conditional
liveness stated exactly), R13.

**Evidence.** REC-03 (`spec/06-recovery-exceptions.html`:384–418); REC-02 T_STALL (06:357); L1-11
(`spec/04-l1-integration.html`:353–383); ECON-02 clause 7 (`spec/07-economics-slashing.html`:218–272);
`spec/09-parameters.html`:119–121, 125, 143–149; A-L1-1 (`01-requirements-and-threat-model.md`:127).

---

## R4-LIV-07 — L1-04/L1-06/L1-12/DA-06 still carry Mode A's "may not discard finalized history" and are not scoped to REC-01/REC-02 (round-3 R3-LIV-05 remains open and is now live)

**Severity: Medium.** One-line rationale: the round-3 finding that Mode B contradicts the unconditional
Mode A MUSTs was recorded open and was not closed by change order 04; L1-12's "MUST be re-landable" is
now affirmatively wrong under REC-02.

**Exact rules.**
- `spec/04-l1-integration.html` L1-04 (lines 105–110): "Under Mode A the protocol may halt but may not
  discard finalized history … This rule is required **by** Mode A, not merely compatible with it …
  (Mode A obligation)". The rule's own failure mode ("a validly PoS-finalized extension of the L1
  checkpoint becomes permanently unacceptable") is precisely what REC-02 does by design above the
  restored checkpoint.
- L1-06 (lines 216–218): "a rewrite of L2-finalized history through the L1 anchor, forbidden by Mode A
  (`REC-01`)".
- L1-12 (line 387): "The batch remains PoS-finalized in **Mode A**, and MUST be re-landable with the same
  `dataCommitment` under L1-04." After a completed recovery the same batch carries a stale
  `recoveryGeneration` and MUST be rejected (REC-02 "Late proofs", 06:363; PRF-02(6);
  L1-05 row 31) — the unconditional MUST is false in the selected mode.
- DA-06 (lines 535, 547): "Mode A forbids discarding it".

**Missing rule.** A single scoping clause (in REC-01 or L1-04) stating which Mode A obligations survive
Mode B, and that the admission obligation is "any account may land any range that extends the *current*
checkpoint", with the generation check as its only new admission condition — or, alternatively, explicit
deletion of the Mode A rationale from the four rules. Round-3 R3-LIV-05 asked for exactly this and is
still listed open in `iterations/03-round.md`:93.

**Assumptions and preconditions.** An implementer derives admission and re-landing rules from page 04;
a recovery has completed (or is being code-reviewed).

**Concrete attack trace.** (a) After an L1 reorg below finality, a prover reads L1-12 and resubmits the
old `(data, proof)`; the generation is now `g+1`, so a conforming `land` rejects it — the prover cannot
tell whether the implementation or the rule is wrong. (b) A reviewer reads L1-04's "(Mode A obligation)"
and concludes the `recoveryGeneration` gate is a Mode A violation; removing it re-opens the landing of an
alternative history (the exact thing D-7's statement binding exists to stop).

**Inside/outside.** Inside; text-level, no adversary.

**Attacker resources and cost.** None.

**Harm.** R13, D-7/REC-01(d), R9. Severity is kept at Medium (as round 3 assessed) because the generation
check itself is stated in REC-02/PRF-02 and an implementer can resolve the conflict by reading them; the
defect is that page 04 was not re-based and now contradicts the selected mode.

**Evidence.** `spec/04-l1-integration.html`:98–110, 207–218, 385–396, 530–550;
`spec/06-recovery-exceptions.html`:56–59, 356, 363; `spec/05-proof-statement.html`:177–199;
`iterations/03-round.md`:93; `iterations/raw/round3-liveness-da-recovery-30min.md`:111–124.

---

## R4-LIV-08 — REC-02's replay key does not exist in the preserved surface, and "deposits remain credited" is inaccurate; the real no-double-execution argument is unstated

**Severity: Medium.** One-line rationale: the one rule about post-rollback bridge safety asserts a
`(chainId, domain, height, commitment)` key that appears in no preserved encoding (and telling an
implementer to introduce it would break MSG-02), and its "deposits remain credited" reassurance is false
for any credit that lived in the discarded range.

**Exact rules.**
- `spec/06-recovery-exceptions.html` REC-02, "Transaction replay" (line 364): "Replay protection must
  hold across the recovery: message authentication, bridge execution and withdrawal claims are keyed by
  `(chainId, domain, height, commitment)` so that an effect executed before the rollback cannot be
  executed twice afterwards, and an effect that never executed can be submitted again. Deposits already
  executed on L1 remain credited; unsettled withdrawals must be resubmitted."
- `spec/04-l1-integration.html` MSG-02 (lines 631–647): the frozen keys are
  `keccak256(abi.encodePacked("SIGNAL", chainId, app, signal))` and
  `keccak256(abi.encode("TAIKO_MESSAGE", message))` with per-message status
  `NEW/RETRIABLE/DONE/FAILED/RECALLED`; "changing either encoding MUST be treated as a migration that
  invalidates every cached received-signal entry and every unproven message." No `height` or
  `commitment` component exists in either key.

**Analysis (positive result).** No double execution of a bridge effect is possible: every L1-side bridge
release (`processMessage`, withdrawal claim) requires a SignalService checkpoint written by a successful
`land(data, proof)` (MSG-03), i.e. an accepted batch at or below the recovery floor, and recovery never
revokes an accepted batch (STATUS-06). An L1→L2 credit in a discarded range is erased together with the
range's L2 state, so re-processing the same message is the sanctioned "never executed" case, and the
L1-side deposit is neither duplicated nor lost. The specification should say exactly this; instead it
states a key that does not exist and whose introduction would violate MSG-02.

**Assumptions and preconditions.** A recovery replaces a range containing an L1→L2 credit and/or an
unsettled L2→L1 withdrawal; preserved Bridge/SignalService encodings unchanged.

**Concrete attack trace.** (a) An implementer adds `height`/`commitment` to the replay key to conform to
REC-02; the slot derivation changes and every cached received signal and unproven message is orphaned
(the failure mode MSG-02 itself describes). (b) A user reads "deposits already executed on L1 remain
credited", treats the L2 credit in a block above the checkpoint as durable, and lends against it; the
recovery erases the credit, the user must replay the deposit message on the restored chain, and the
off-chain loan is unbacked in the interim. No protocol penalty compensates (ECON-11).

**Inside/outside.** Inside; text-level, no adversary.

**Attacker resources and cost.** None.

**Harm.** R13/R14, MSG-02's frozen-encoding rule, and the user-facing accuracy of REC-02's exposure
statement.

**Evidence.** REC-02 (06:364); MSG-02 (`spec/04-l1-integration.html`:631–647); MSG-03 (04:649–660);
STATUS-06 (`spec/index.html`:235–245); MIG-03(5) (08:404–411, whose "processed at most once" claim is
correct for the same reason REC-02 omits).

---

## R4-LIV-09 — Recovery's reach is overstated where it cannot help; the halt conditions it cannot clear are stated only in LIVE-01

**Severity: Medium.** One-line rationale: HALT-01 calls recovery the "sanctioned remedy" for a missing
epoch-set entry, and REC-02's scenario table says a completed recovery lets "a new quorum continue" after
an unavailable-quorum halt, while LIVE-01 says the opposite for both and REC-02 itself changes no
validator set.

**Exact rules.**
- `spec/06-recovery-exceptions.html` HALT-01 (lines 96–103): "A halt caused by a missing epoch-set entry
  (d) or by an unlandable batch is answered by retrying and by continuing to serve; if settlement
  nevertheless stalls past T_STALL, the permissionless recovery path of REC-02 is the sanctioned remedy".
- REC-02 "No discretion" (line 361): "the validator set is the one the L1 staking contract already fixes
  for that epoch, and no configuration value may be changed by recovery"; the scenario table (line 426):
  "Unavailable validator quorum … a completed recovery restores the latest L1-accepted checkpoint **so a
  new quorum can continue**".
- `spec/10-assurance.html` LIVE-01 (lines 123–136): "(L1) fails → the chain halts rather than forks …
  (L6) fails → the chain cannot enter the next epoch, and **recovery cannot manufacture the missing L1
  set commitment**, so that halt persists until the entry is appended and Ethereum-final"; LIM-01
  (line 232): "a missing epoch-set entry or a failed recovery still has no in-protocol bound".
- `learn/limitations.html`:117–119 states the honest version ("the validator set is unavailable, or the
  stake assumption has failed — … a halt can be permanent").

**Missing rule/honesty.** HALT-01 and the scenario table should say that recovery cannot clear (d), an
unavailable quorum or a failed assumption, and that invoking it there discards the provisional range
without restoring liveness. LIM-01's "Liveness" row should add the unavailable-quorum case to its "no
in-protocol bound" list (it is the row's own subject, "A minority outage halts the chain").

**Assumptions and preconditions.** ≥1/3 of the epoch's voting power is offline/partitioned (a documented
failure mode, LIM-01 line 233) for longer than `T_STALL + T_RECOVERY_DELAY`; or the epoch-set entry is
missing as in HALT-01(d).

**Concrete attack trace.** (1) Quorum outage at height `H`; blocks up to `H` are STATUS-04 and provable
in principle, but no new blocks can be certified. (2) No batch extends the checkpoint for `T_STALL`, so
the objective trigger holds — nothing in REC-02 excludes this cause. (3) Any account invokes and
completes the recovery: no batch can land to cancel it (production is halted), and the bond is returned
(R4-LIV-05). (4) All provisional history above the checkpoint is discarded; the outage persists; the
chain is exactly as halted as before but with its finalized-but-unsettled range destroyed. If the
outage ends later, the range it destroyed was settleable all along (its certificates and data were
intact). The spec calls this "the sanctioned remedy" and "a new quorum can continue".

**Inside/outside.** Inside; no adversary, no assumption beyond the documented outage.

**Attacker resources and cost.** One invocation + gas (bond returned); or zero, since any account may do
it and the trigger is objective.

**Harm.** R6 ("exact conditions where liveness ends" — LIVE-01 states them, HALT-01 and the REC-02
scenario contradict them), R13, LIM-01 completeness; user exposure above the checkpoint destroyed for no
liveness gain.

**Evidence.** HALT-01 (06:79–109); REC-02 (06:346–382, rows at 361, 426); LIVE-01 and LIM-01
(`spec/10-assurance.html`:102–139, 232–233); `learn/limitations.html`:113–121.

---

## R4-LIV-10 — Register and citation defects around the recovery parameters and STATUS-11's boundary

**Severity: Low.** One-line rationale: the parameter register contradicts REC-02 on the bond asset,
leaves the escalation's index undefined, turns one of REC-03's falsifiers into a MUST, and no rule fixes
how an interface determines "above the last L1-accepted checkpoint" or surfaces a pending recovery.

**Exact defects.**
1. `spec/09-parameters.html`:146 registers the bond as "ETH (posted on L1 at invocation …)" but tags it
   "unmeasured / **bond asset unfixed**" and says "neither the bond asset nor its value is measured",
   while REC-02 (06:358, 360) fixes the asset as ETH under D-7. PARAM-01 makes this table the single
   naming/value authority.
2. `B_REC(e) = B_REC_BASE · 2^n`: the index `e` is undefined in REC-02 (06:358) and 09:146
   (`n` is defined; `e` is not). The natural candidate, `recoveryGeneration`, is a different object.
3. `spec/09-parameters.html`:145 states "REC-03 falsifier (b) requires that the delay **MUST NOT** be
   shorter than the time an honest prover needs to land a batch." REC-03 states the opposite direction:
   if (b) holds the argument is withdrawn; converting a falsifier into a normative MUST invents a
   requirement whose input ("the time an honest prover needs") is unmeasured.
4. STATUS-11 (`spec/index.html`:279–293) requires every interface that shows a confirmation above the
   last L1-accepted checkpoint to say it can be replaced and to name REC-02, but no rule fixes how an
   interface determines which checkpoint that is (the Inbox's current pointer vs an Ethereum-final view,
   SYS-02) or requires a *pending* recovery (bond posted, delay running) to be visible. The cancellation
   defence depends on timely landing, and the deadline is not required to be observable.

**Trace.** An implementer keys the bond custody on "asset unfixed" and chooses TAIKO (violating D-7's
asset separation for the anti-spam deposit); or an interface evaluates the boundary against an L1 view
that is reorged and mislabels a provisional confirmation as settled; or a prover cannot see the recovery
deadline it is racing.

**Inside/outside.** Inside; text-level.

**Harm.** R13/R14, D-7, STATUS-11's enforceability.

**Evidence.** `spec/09-parameters.html`:145–149; REC-02 (06:357–360); REC-03 (06:403–406);
STATUS-11 (`spec/index.html`:279–293); SYS-02 (`spec/01-system-model.html`:179–233).

---

## Q-B1 verdict (D-7 requires round 4 to attempt to break REC-03)

REC-03's in-model impossibility claim does **not** survive as written. Its premise (4) ("proving is …
rewarded") is an economic assumption contradicted by L1-11 (`rewardPaid = 0` permitted) and by
ECON-02 clause 7 ("an empty pool pays nothing"), and the 09 register still calls D-8's funding path Open;
its claim that inducing the trigger requires L1 censorship or the suppression of every prover ignores
bought inclusion delay, which is not censorship, and `T_STALL` has no inclusion-delay term or inequality
against A-L1-1's bounded-inclusion assumption (R4-LIV-06). Its falsifier (c) is aimed at the wrong
refund: the bond is refunded **on completion**, not on cancellation, so a successful manipulation is not
priced by it (R4-LIV-05). The two claims that do survive re-attack are: (i) a sub-threshold coalition
cannot *by validators' votes* force the trigger while at least one adequately-resourced, adequately
incentivised prover lands within `T_STALL`; and (ii) recovery is never a selective rollback and never an
inclusion remedy. On the D2/D-7 procedure, the selection's stated falsifiers should be extended with
"the reward pool is empty or below prover cost" and "an adversary buys inclusion delay" — both currently
fall between "inside A-L1-1" and "L1 censorship" with no rule assigning them.

## Checked and holds (not re-listed)

- **No double execution of a bridge effect.** Every L1-side release is anchored to an accepted checkpoint
  at or below the recovery floor (MSG-03, STATUS-06); an L2-side credit in a discarded range is erased
  with the range and re-processing is the sanctioned replay case. REC-02's stated key is wrong
  (R4-LIV-08), but the property holds.
- **Recovery is not presented as an inclusion remedy.** LIVE-04 (10:175–212) and
  `learn/09-censorship-and-the-bridge.html`:39–50 state it explicitly; FI-REMOVED-01 and FI-PLANNED-01
  keep the no-forced-inclusion statement. The only residue is the "sanctioned remedy" phrasing of
  HALT-01 for settlement stalls (R4-LIV-09).
- **A recovery in flight across a later upgrade is addressed.** `spec/08-migration-upgrades.html`:169–181,
  GOV-03(e) (08:618–625) and the migration risk table (08:671) forbid an upgrade from cancelling,
  accelerating or substituting for a pending recovery and require the checkpoint and generation to
  survive; the missing piece is the *record itself* (R4-LIV-03), not the obligation.
- **Migration cannot overlap a recovery.** The state machine has no transition out of `ETNA_ACTIVE` and
  REC-02 exists only from T3 (08:156, 169–172); the T1–T3 window is DAO-dependent and disclosed
  (08:669).
- **HALT-02's restart rules** (no double signing, no replayed messages, adopt the highest canonical
  checkpoint, a discarded block is not finalized) are consistent with REC-01/REC-02 and were not
  broken.
- **STATUS-04/STATUS-11 disclosure mechanics.** A block at or below the latest L1-accepted checkpoint is
  covered by an accepted batch and is therefore STATUS-06, so STATUS-04 is above the checkpoint by
  construction; the label rule and the replacement-disclosure obligation are coherent. The remaining
  gaps are the boundary-determination/pending-recovery points in R4-LIV-10.
- **Round-3 R3-LIV-04's LIM-01 rows** (cap violation unpunishable, predictable/purchasable proposer
  slots, unpunishable cross-round divergence) are present at `spec/10-assurance.html`:228, 234–235 and
  hold; nothing in this round re-opens them.
- **The D-7 floor discrepancy** (D-7's narrative says "above the last Ethereum-finalized checkpoint";
  REC-01/REC-02 use the latest L1-accepted checkpoint) is a *stronger* floor than the narrative and is
  explicitly reconciled in REC-01 (06:42–47). It is not a violation of the fixed decision; it is worth a
  one-line note in DECISIONS.md only.
