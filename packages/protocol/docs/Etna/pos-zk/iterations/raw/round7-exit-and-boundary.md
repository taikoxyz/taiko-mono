# Round 7 — raw adversarial review: the exit and the boundary

**Reviewer:** fresh independent adversarial reviewer, round 7, angle `exit-and-boundary`.
**Snapshot reviewed:** `296f44b54` (branch `etna-pos-zk`). Files were extracted from the snapshot itself (`git archive 296f44b54`) because `997723ce6` adds post-snapshot edits to `spec/04` and `spec/05`; every citation below is to snapshot content.
**Method.** MEM-15 (new clause (2a)), L1-13/L1-14, MSG-03/MSG-04, L1-08–L1-11, MIG-05 and pages 02/05/09/10 were read against each other and against the interface sketch; the D-16 rollback was verified mechanically (every anchored rule id and every tombstoned parameter name scanned against live text, with the surrounding context inspected). Citations: `NN:line` = raw line in the snapshot file; rule ids are anchors.

**Counts: Critical 1 · High 2 · Medium 3 · Low 2.** One Critical is inside the fault model and is a defect in the very clause that claims to resolve the round-6 exit contradiction. The boundary itself (nothing at or below the accepted checkpoint is rewritten by the exit, the veto, an upgrade or a reorg) **holds** — see "Checked, and holds". The deferral rollback is **incomplete in the course and in the economics/offence pages**, not in the core state machine.

---

## F1 — MEM-15(2a)/L1-13(3) claim the exit needs no prover and only "L1 state that already exists", but a root is k−1 fresh validity proofs, produced off-chain from the witness and paid by no rule; the exit can therefore be unavailable while every assumption holds

**Severity: Critical.** One-line rationale: clause (2a) is the D-16 repair of round-6's exit contradiction, and it resolves the *epoch-boundary* half only — it asserts "No step of this requires … the cooperation of any validator, proposer, **prover**, relayer or operator: the inputs are L1 state that already exists", while L1-13(4) says a root costs "**k−1 additional proofs** beyond the accepting one" and L1-13(5) admits "**no funding rule for them exists in this specification**"; a validity proof of an already-accepted statement cannot be derived from L1 state (it needs the execution witness and the pre-state), is produced by a prover, and is paid by nobody — so the v1 user-protection guarantee can fail with no assumption broken.

**Exact rule / the contradiction.**
- `spec/03-membership-staking.html#MEM-15`(1) (03:344 ff.): the path "MUST remain executable on L1 with (i) no new L2 blocks, (ii) no L2 consensus participation, quorum or validator set, (iii) **no cooperation from any validator, proposer, prover, relayer or operator**, and (iv) no dependence on any L2 liveness assumption beyond the L1 facts already written when that checkpoint was accepted."
- `MEM-15`(2a): "that root attests a checkpoint statement that already exists on L1 … it is formed by k attestations of that statement, contributed by distinct registered backend families and verified on L1 … **No step of this requires** a new L2 block, settlement progress, L2 consensus participation, quorum or validator set, **or the cooperation of any validator, proposer, prover, relayer or operator: the inputs are L1 state that already exists**, and submission is permissionless — any account may carry the attestations."
- `spec/04-l1-integration.html#L1-13`(3) (04:412 ff.): "`attestWithdrawalRoot(height, programImageId, proof)` … the call MUST verify the proof against the recorded statementHash under a route whose image is in that epoch's accepted set … **The attestation MUST depend only on L1 state that already exists at the accepted checkpoint.** It MUST NOT require a new L2 block, a new batch, a new checkpoint, an epoch boundary or any settlement progress … the latest L1-accepted checkpoint **MUST be attestable by this path at any time while the chain is halted**."
- `L1-13`(4): "One root costs k on-chain verifications and **k−1 additional proofs beyond the accepting one**." `L1-13`(1): a root is "a checkpoint … that carries valid proofs of its own accepted statement from k distinct registered backend families, with k = K_PROOF_BACKENDS, **2 ≤ k ≤ n**".
- `L1-13`(5): "The attach proofs are paid by whoever submits them and **no funding rule for them exists in this specification**, so the exit path's liveness **also depends on those proofs being economic** (Open; the natural funding source is the proving share of ECON-02, which is owned elsewhere)."
- `spec/04#L1-11` (04:440 ff.): the prover reward ledger "MUST be debited only by the `rewardPaid` of a successful `land(data, proof)` and by **nothing else** — never for validator payouts, gas, refunds or **any other purpose** — and no entry point, payout or upgrade may spend it outside that path." A root attestation is not a landing, so the "natural funding source" named by L1-13(5) cannot legally reach it.
- `spec/10-assurance.html#LIVE-01` (10:177): the exit is "Independent of every clause above, and therefore **not conditional on (L1), (L2), (L4) or (L6)**" — L4 is literally "for every committed batch, at least one adequately-resourced **prover** completes its proof inside the envelope". `LIVE-05` (10:309(i)): "this part **needs only Ethereum's liveness, not the L2's**". `spec/04#MSG-03`(5) disclosure: "the exit **stays available during a stall**".
- `spec/04#L1-09` (04:399 ff.): a route's verifier "MUST be a deployed contract … that **implements the statement of PRF-01** and has been audited to it"; each family's attestation is therefore a proof of PRF-01's statement (consensus evidence + execution + data binding + generation) in that family's proof system — a fresh proving job, not a signature and not a re-verification of the accepting proof.

**Missing rule.** Either (a) one rule funds or compels the k−1 attestation proofs (an obligation or a paid path that L1-11 permits), or (b) the exit is restated as *permissionless but prover-dependent*, with the honest disclosure that a missing or unpaid proving market delays it indefinitely, and MEM-15(1)(iii)–(iv), (2a), LIVE-01's independence clause and MSG-03(5)'s "stays available" sentence are scoped accordingly; or (c) the shipped configuration is k = 1 (see the implementability note), in which case the accepting proof already recorded at acceptance *is* the root and no attestation is needed — but L1-13(1)'s "2 ≤ k" must then be changed by the recorded change order L1-13(7) requires, with the LIM-01 single-backend disclosure.

**Assumptions.** None broken. The failure needs only self-interest: producing a validity proof of an old batch costs real money and no rule pays for it, so a rational prover does not do it. The same conclusion follows from any prover outage or from data/state ageing: the proof needs the witness (the batch's blocks and its pre-state) and, for blob-path batches, the publication's blobs, whose retrievability is bounded (DA-05's window, ~18 days) — none of which is "L1 state that already exists".

**Concrete attack trace (no adversary needed).**
1. A user's withdrawal signal lands at height h ≤ the latest accepted checkpoint C; the accepting proof was produced by family A (recorded as the first family attestation). k = 2 (the minimum L1-13(1) permits).
2. Settlement stalls (any cause: no prover for new batches, L1 fee market, data loss) or simply time passes. The chain halts; C is frozen. L1-13(3) says C "MUST be attestable … at any time while the chain is halted".
3. A root for C now needs one more proof, from family B, of C's recorded statementHash. Producing it requires B's program image, a prover, the batch's data and the pre-state at prevHeight. No rule pays for it (L1-11's ledger pays only `land`); the user may not be able to produce it themselves (no proving hardware, no witness); a public-goods prover has no protocol obligation.
4. No root forms, so MSG-03/STATUS-08 do not permit the release; the delay WITHDRAWAL_DELAY is irrelevant because the eligibility condition is never met. The exit is unavailable for as long as the proving market declines to work for free — unbounded, and exactly in the stall scenario clause (2a) was written for.
5. A sub-threshold coalition does not even need to act: no rule requires anyone to prove, and the *accepting* families have no duty to re-prove. If a coalition does act, the cheapest denial is to be the only available prover and decline — or to censor the attestation transactions at L1 (A-L1-1), which is outside the model but unnecessary here.

**Inside / outside the claimed fault model.** **Inside.** No assumption (A-CONS-1, A-CONS-2, A-DA-2, A-L1-1) has to fail: the mechanism requires an unpaid action and the rules admit the gap in the same clause. It is not a safety break and no funds are lost (the value stays in the preserved Bridge/vaults and the checkpoint is never rewritten), but the hard requirement "MUST remain executable … with no cooperation from any … prover" is false in a reachable state, and the exit is the whole of v1's user protection.

**Attacker resources and cost.** None for the failure itself; a griefer's cost is zero (do nothing, or decline to prove). Censoring attestations costs ordinary L1 inclusion, but is unnecessary.

**Requirement / fixed decision affected.** D-16's shipped core ("the exit from the last settled state (MEM-15, with its clause (2a) resolution: a root for the last accepted checkpoint is k attestations of its existing statement, **permissionless, needing no new L2 block and no settlement progress**)"); MEM-15(1)(iii)–(iv); L1-13(3); LIVE-01's independence claim; MSG-03(5)'s disclosure; A-GOV-2's re-scoped guarantee ("the exit of MEM-15 is the guarantee that remains"); LIM-01's guarantee-class row.

**Evidence.** 03:344 ff. (MEM-15(1),(2a),(4),(5) and the "Proven Open" tag); 04:412 ff. (L1-13(1),(3),(4),(5),(7)); 04:440 ff. (L1-11); 04:757 ff. (MSG-03, disclosure at "Withdrawal disclosure"); 04:399 ff. (L1-09); 10:177 ff. (LIVE-01), 10:288 ff. (LIVE-05 rows and (i)); 09 `K_PROOF_BACKENDS`, `W_ROOT_WAIT_MAX`; DEFERRED.md §4 (aggregation deferred, "the withdrawal-root path requires k distinct backend families to each verify *this same statement*").

---

## F2 — The course still teaches the deferred mechanisms as live and omits the withdrawal root from the exit path: the D-16 absence is not disclosed where it used to be promised

**Severity: High.** One-line rationale: the freeze states round 7 verifies "that the course teaches what the specification now says", but no course page carries a single `D-16` marker, four pages still present the deferred heartbeat / stall resolution / recovery as v1 mechanisms, and the integrator lesson teaches a withdrawal path with no root at all — the one mechanism that is now the whole of v1's user protection.

**Exact rule / missing rule.** D-16 defers MEM-13/CONS-16 (heartbeat), GOV-04/REC-02–REC-04 (stall resolution), FI-10–FI-14, PRF-15/L1-14/aggregation; `GEN-01`/`GEN-02` bind every deliverable; `learn/index.html` states the course's contract ("If this course ever claims more than the specification does, treat that as a bug in the course"); `STATUS-11` and `MSG-03`(5) impose the disclosure duties; `spec/10#LIVE-04`(1) and `LIM-01` state the v1 absences the course must carry. **Missing:** the course sweep for D-16.

**The stale text, verbatim (all visible, non-commented).**
- `learn/04-staking-and-epochs.html:50,122-163` — teaches the ECDSA heartbeat key, "Anyone may submit a heartbeat transaction", "Set versions are built from **eligible** entries … ineligible entries are excluded from the root", and "The L1-time rotation (CONS-16) draws a stalled chain's restart set from eligible validators, so the halt lasts only while no reachable set can be drawn." D-16 defers MEM-13/CONS-16 and the spec says the opposite: `spec/03` (03:638, 733) "v1 has no liveness gate … MUST NOT be implemented", and `LIVE-05` "No production-time bound in v1".
- `learn/06-data-and-proof-together.html:269-277, 332, 362, 396-400` — "When a recovery completes, it restores the last checkpoint … the completion transition records `resumeHeight`, and a batch must start at `max(lastLandedHeight + 1, resumeHeight)` … the retired height is what makes the discarded range unlandable." This is the withdrawn D-15 recovery *and* the withdrawn retired-height form; v1 has neither (REC-02/REC-04 tombstones; `L1-06` "No height is permanently retired, and there is no retirement record").
- `learn/08-when-things-go-wrong.html:40, 62, 68, 82-94, 136-138` — "a stall halts the chain and a **timelocked, resume-only governance decision restarts it** from the last accepted checkpoint"; "no batch extending the current L1 checkpoint has been accepted for `T_STALL_GOV`"; "governance may queue a restart under a timelock `T_GOV_RESUME`"; "When the restart executes, everything above the accepted checkpoint is discarded." GOV-04 and both parameters are D-16 tombstones; the spec says there is no recovery path of any kind and a stall is cleared only by a future protocol update (10:170-176, 299).
- `learn/09-censorship-and-the-bridge.html:49, 68-74` — "A restart is not an inclusion remedy. A timelocked, resume-only governance decision can restart the chain…" (deferred mechanism taught as live).
- `learn/glossary.html:132, 145, 152, 156, 160` — live definitions of "Heartbeat (L1 liveness attestation)", "Recovery generation … advanced by exactly one when a restart executes", "Settlement stall (`T_STALL_GOV`)", "Stall resolution (`GOV-04`)", "Timelock (`T_GOV_RESUME`)". All five are tombstones that "MUST NOT be implemented" and whose parameter names "MUST NOT be used by any rule, client, parameter or migration text" (09).
- `learn/09:99, 163, 220, 235, 242` and `learn/02`, `learn/07` — the withdrawal path is taught as "checkpoint + message path + `WITHDRAWAL_DELAY` measured from the checkpoint's `l1BlockNumber`", with **no withdrawal root, no k families, no attestation and no veto**. MSG-03/L1-13 require a root (otherwise "an ordinary checkpoint that is not a withdrawal root MUST NOT anchor any value release"), and MSG-03(5) requires the k-family cost and the veto to be disclosed wherever withdrawal timing is described. An integrator following `learn/09`'s "minimum evidence that an L2→L1 message may be released" builds a release path that the specification forbids.

**Assumptions.** None.

**Concrete attack trace (no adversary).** A user or integrator reads the failures lesson during a stall: it tells them governance can queue a timelocked restart, gives the parameter names, and explains that locks from the discarded range do not bind the new generation. None of it exists in v1. Meanwhile the bridge lesson tells them their withdrawal is releasable on checkpoint + delay, while the contract will revert for lack of a root. Both errors are in the direction of *more* protection than v1 provides, on the two guarantees the round is about.

**Inside / outside the claimed fault model.** N/A (documentation); inside the project's own disclosure model, which is the only protection the design offers (STATUS-11's failure-mode note).

**Attacker resources and cost.** None.

**Requirement / fixed decision affected.** D-16 (deferral must be disclosed, not implemented); D-15; `GEN-01`/`GEN-02`; `STATUS-11`; `MSG-03`(5); `LIM-01` ("none may be silently dropped when the design is summarised to users"); the freeze's round-7 verification clause.

**Evidence.** The lines above (raw line numbers in the snapshot files); `grep -c "D-16"` = 0 in every `learn/*.html`; `spec/10` 170-176, 288-311, 334, 360, 364-370; `DEFERRED.md` §§1–4; `learn/index.html` ("a bug in the course").

---

## F3 — ECON-04 clause (6) and ECON-13 keep the forced-inclusion breach as a live offence while LIVE-04(1) states that the same act is not a breach in v1

**Severity: High.** One-line rationale: v1's offence catalogue contains an offence that v1's own inclusion rule says does not exist, and the offence reads tombstoned rule ids and parameter names; implemented literally it slashes a proposer for lawful behaviour.

**Exact rule / missing rule.** `spec/07-economics-slashing.html#ECON-04` (07:387 ff.; row at 07:459): "**Forced-inclusion breach** — a signed proposal whose block, at its own anchored L1 view A, omits a published, unproven record that is due at A (`record.l1BlockNumber + FI_INCLUSION_DELAY ≤ A`) and inside the required capped FIFO prefix … the predicate of FI-10 and FI-11 as the per-block clause CONS-01(v) states it". `spec/07#ECON-13` (07:1050 ff.) restates the breach and its economics. All of `FI-10`–`FI-14`, `CONS-01`(v) and the FI parameters are D-16 tombstones that "MUST NOT be implemented" / "MUST NOT be used by any rule, client, parameter or migration text" (09; DEFERRED.md §1). Live rule: `spec/10#LIVE-04`(1) (10:239-246): "v1 has no inclusion obligation … **a proposer that excludes published data is not in breach, and there is no due set, prefix, deadline discharge or omission offence (CONS-01, ECON-04)**"; `spec/03` (03:638) and `spec/04` (04:14) repeat that there is no inclusion obligation. **Missing rule:** ECON-04 clause (6) and ECON-13's breach section must be tombstones, and the offence catalogue's closure claim ("Only behaviour on the list consumes bonded stake", 07) must match LIVE-04.

**Assumptions.** None.

**Concrete attack trace.** Not an attack: an implementer building the closed offence catalogue from ECON-04 implements clause (6)'s predicate. Because the FI machinery and its parameters are gone, the implementer must invent the due set, the prefix and `FI_INCLUSION_DELAY` — the fields the specification declares non-existent. A proposer that lawfully excludes published data (LIVE-04 says this is lawful) is then slashed under a rule the specification withdrew, i.e. stake is confiscated for conforming behaviour. Even if no one implements it, v1's catalogue and v1's inclusion rule contradict each other in the normative text.

**Inside / outside the claimed fault model.** Inside (a plain contradiction; the harm requires a defective implementation, but the rule text is the cause).

**Attacker resources and cost.** N/A (a reporter could trigger the implemented offence; the loss is the proposer's stake).

**Requirement / fixed decision affected.** D-16 (forced inclusion deferred and MUST NOT be implemented); D-12's supersession; `GEN-03` (one rule, one place); `PARAM-01` (tombstoned names MUST NOT be used by any rule text); `LIVE-04`(1); the offence catalogue's own closure claim.

**Evidence.** 07:387 ff., 459 ff. (`ECON-04` clause (6)), 1050 ff. (`ECON-13`); 10:239-250 (`LIVE-04`(1)); 09 (FI tombstones: `FI_INCLUSION_DELAY`, `FI_MAX_PER_BATCH`, …); DEFERRED.md §1.

---

## F4 — ECON-02 clause 5(e) and the economics parameter summary still require and register the tombstoned aggregation split, and the same clause overstates what the proving share can fund

**Severity: Medium.** One-line rationale: a live normative clause (the allocation policy) reads `AGG_PROVER_PPM`, `M_AGG_MAX`, `K_SETTLE_BACKENDS`, `L1-14`(3) and `PRF-15`(5) — all D-16 tombstones — and its claim that `ProvingShare` "funds all off-chain proving work" is false for the only payments L1-11 permits, which matters to F1.

**Exact rule / missing rule.** `spec/07#ECON-02` clause 5(e) (07:240): "the recorded allocation policy **MUST also fix the share `AGG_PROVER_PPM`** of `ProvingShare(e)` assigned to the aggregation that produced the epoch's proof objects … The aggregator's inner-proof count is bounded by `M_AGG_MAX` (at most `N_PROOF_BACKENDS`) … the per-purpose required counts are `K_SETTLE_BACKENDS` (= 1) … and `K_PROOF_BACKENDS` … enforced inside the one accepted object (`L1-14`(3), `PRF-15`(5))". `spec/07` clause 5(a) (07:180): "`ProvingShare(e)` … **funds all off-chain proving work**, including the aggregation of the one proof object per batch (clause 5(e), D-13)". The economics parameter summary (07:1353) still registers `AGG_PROVER_PPM`. Register: 09 tombstones `AGG_PROVER_PPM`, `M_AGG_MAX`, `K_SETTLE_BACKENDS`, `T_AGG_ROTATE_MAX` ("MUST NOT be used by any rule, client, parameter or migration text"); `L1-14` is "DEFERRED … MUST NOT be implemented". **Missing rule:** clause 5(e)'s aggregation paragraph and the summary row must be tombstones; the funding statement must be scoped to the one payout L1-11 allows (`land`), because the same clause is cited by L1-13(5) as "the natural funding source" for root attestations that L1-11 cannot pay.

**Assumptions.** None.

**Concrete attack trace.** Not an attack: an implementer records the allocation policy with a third internal share (`AGG_PROVER_PPM`) for a mechanism that must not exist, or, reading clause 5(a), assumes attestation proofs are funded and does not build any incentive for them — compounding F1.

**Inside / outside the claimed fault model.** N/A (consistency).

**Attacker resources and cost.** N/A.

**Requirement / fixed decision affected.** D-16/`PARAM-01`; `L1-13`(5)'s funding statement; `L1-11`'s closed ledger.

**Evidence.** 07:180, 240, 1353; 09 (`AGG_PROVER_PPM`, `M_AGG_MAX`, `K_SETTLE_BACKENDS`, `T_AGG_ROTATE_MAX` tombstones; change-order-06 paragraph at 09:96); 04:423 (`L1-14` "DEFERRED (D-16)"), 04:440 ff. (`L1-11`).

---

## F5 — STATUS-08 still defines the withdrawal root as an epoch-boundary checkpoint with an "up to one epoch" wait, contradicting L1-13(1)/(3) and MSG-03

**Severity: Medium.** One-line rationale: the normative status label every interface must use still encodes the pre-D-16 epoch-boundary restriction, so an interface will tell a halted user their exit is not available until an epoch boundary that may never come — the exact round-6 failure the new clause (2a) claims to have fixed.

**Exact rule / missing rule.** `spec/index.html#STATUS-08` (index:272): "a withdrawal root at a height not below the signal's height — **an epoch-boundary checkpoint** carrying attestations from at least `K_PROOF_BACKENDS` distinct registered backend families … the two user-visible delays (**up to one epoch** plus the slowest attestation, and up to `T_VETO`)". Live rules: `L1-13`(1) (04:412): "The intended formation point is the epoch-boundary checkpoint … but nothing in this rule may hold an exit for a new epoch: see (3), where **any already-accepted checkpoint, and in particular the latest one, is attestable**"; `L1-13`(3): "the latest L1-accepted checkpoint MUST be attestable by this path at any time while the chain is halted"; `MSG-03` (04:757 ff.): "the root can be attested for the latest L1-accepted checkpoint from L1 state that already exists: **no new L2 blocks and no settlement progress are required**". 09's `K_PROOF_BACKENDS` row repeats "the required count for an **epoch-boundary** withdrawal root". **Missing rule:** STATUS-08 and the register row must drop the epoch-boundary conjunct and the "up to one epoch" wait (the wait is for the attestations), consistent with L1-13(1)/(3).

**Assumptions.** None.

**Concrete attack trace.** Not an attack: a bridge UI implementing STATUS-11 with the STATUS-08 definition computes eligibility as "wait for the next epoch-boundary root". On a halted chain no later epoch boundary can be settled, so the UI reports the exit as unavailable indefinitely — while L1-13(3) makes it available now. The user is denied an exit the protocol offers; the misstatement is in the specification, not the UI.

**Inside / outside the claimed fault model.** Inside (the halt case is the one the guarantee exists for).

**Attacker resources and cost.** None.

**Requirement / fixed decision affected.** D-16's exit; `STATUS-11` (interfaces must use the labels exactly); `GEN-03`; `MSG-03`(5)'s disclosure obligation.

**Evidence.** index:272 (STATUS-08); 04:412 ff. (L1-13(1),(3)); 04:757 ff. (MSG-03); 09:191 (`K_PROOF_BACKENDS` row).

---

## F6 — MEM-15(2a)/L1-13(3)'s "MUST depend only on L1 state that already exists" is a MUST the contract cannot enforce and a validity proof cannot satisfy

**Severity: Medium.** One-line rationale: the clause that resolves the exit contradiction imposes on the attestation a property that is neither checkable on L1 (the contract sees a proof and a statement hash, not the prover's inputs) nor true of any proof of execution (which needs the witness), so an implementer must either ignore a MUST or implement something impossible.

**Exact rule / missing rule.** `L1-13`(3): "**The attestation MUST depend only on L1 state that already exists at the accepted checkpoint.**" and "the evidence it verifies is the accepted statement itself"; `MEM-15`(2a): "the inputs are L1 state that already exists". What `attestWithdrawalRoot(height, programImageId, proof)` (L1-08) actually does is verify a zk proof against a recorded `statementHash` (L1-13(3)); it cannot constrain what the prover read. And a proof of PRF-01's statement (consensus evidence + execution from `prevStateRoot` + data binding) cannot be produced from L1 state alone: it needs the certificate (public), the batch data and the pre-state/witness (off-chain, ROOT-03/A-CONS-5/A-DA-2). **Missing rule:** restate the clause as what is true and checkable — the *contract's* verification uses only L1 state (the recorded statement hash, the route registry and the epoch's accepted set), while the *proof* may be supplied by anyone and its production is off-chain — and drop or scope the "depends only on L1 state" MUST on the attestation.

**Assumptions.** None.

**Concrete attack trace.** Not an attack: two implementers read the MUST differently (one adds an attestation of "no external input" they cannot produce; one deletes the clause), and an auditor cannot check it from the contract. It is the same class as round-5 R5T-D2-04 (a normative rule that cannot be implemented as written), now attached to the exit.

**Inside / outside the claimed fault model.** N/A (implementability).

**Attacker resources and cost.** N/A.

**Requirement / fixed decision affected.** D-16's exit; L1-13(3)'s own claim; the implementability verdict for this round.

**Evidence.** 04:412 ff. (L1-13(3)); 04:L1-08 sketch (`attestWithdrawalRoot`, `withdrawRootAt`); 03:344 ff. (MEM-15(2a)); 04:399 ff. (L1-09 verifier bar); 04:757 ff. (MSG-03).

---

## F7 — Residual tombstone reads in live normative text (a list, each with its owner)

**Severity: Low.** One-line rationale: these do not change v1's guarantees, but they are exactly the "rule still reads a tombstoned name" class the round must clear, and each can mislead an implementer about whether a case can occur.

1. `spec/02-consensus.html#CONS-01`(iii), `#CONS-05` and `#CONS-10`(6), and `spec/05#PRF-05`/PRF-04 describe "**after an executed stall resolution** … `resumeHeight = lastLandedHeight + 1`" as a reachable case and cite `REC-04`/`HALT-02`. Under D-16 no rule executes a stall resolution; `REC-04` and `resumeHeight` are tombstones. The statements are conditional and harmless in effect (the same contiguity holds) but they keep a deferred transition in live normative text.
2. `spec/09-parameters.html` `K_PROOF_BACKENDS` (09:191): "enforced by the Inbox **over the aggregation public input**", citing `L1-14`(3) — `L1-14` is a tombstone and no aggregation object exists; the row also keeps "epoch-boundary" (see F5).
3. `spec/09` `W_ROOT_WAIT_MAX` (09:196): "`E_EPOCH + T_PROOF_MAX_PERMITTED` … the maximum additional wait for a withdrawal root" — under L1-13(3) the epoch term is no longer part of the wait; the value is conservative but the derivation is stale. `T_ROTATE_DELAY` is still referenced in the 09 narrative (09:96/433) although CONS-16 is deferred.
4. Round-4/5 tags that assert a debt already paid: `MEM-15`'s "Proven Open" tag still says "The reconciliation of MSG-03's 'a settlement halt delays withdrawals — indefinitely' sentence with this rule **is owed by page 04**", although page 04 no longer contains that sentence and has been rewritten around the root (F5 aside).

**Requirement / fixed decision affected.** `PARAM-01`/`GEN-03`; D-16; the freeze's rollback verification.

**Evidence.** 02 (`CONS-01`(iii), `CONS-05`, `CONS-10`(6)); 05 (`PRF-05`); 09:96, 191, 196, 433; 03:345.

---

## F8 — The required interface exposes no per-height/per-family attestation view, so a compliant caller cannot discover which attestations are missing

**Severity: Low.** One-line rationale: `withdrawRootAt` returns `(designated, familyCount, statementHash)` but there is no view of *which* families have attested, so every additional attestation submission risks a `FamilyAlreadyAttested` revert and a client cannot determine what is needed to make a stalled user's exit possible — delivery friction on the only user-protection path.

**Exact rule / missing rule.** `spec/04#L1-08` (04:412 ff. sketch): `attestWithdrawalRoot(uint64, bytes32, bytes)`, `withdrawRootAt(uint64)`, `contestProof`, `withdrawalVeto`; `L1-13`(3) requires `FamilyAlreadyAttested` and records the family; `STATUS-11` requires interfaces to expose "whether a withdrawal root exists for a height". **Missing rule:** a view returning the attesting families (or a per-family boolean) for a height, so the obligation L1-13(3) imposes can be discharged without guesswork. Not a guarantee defect; a completeness gap in the interface the exit depends on.

**Assumptions.** Implementation time only.

**Inside / outside the claimed fault model.** N/A.

**Attacker resources and cost.** N/A (gas wasted on reverts; no safety effect).

**Requirement / fixed decision affected.** L1-08's completeness claim; STATUS-11; D-16's exit.

**Evidence.** 04:412 ff. (L1-08 sketch, L1-13(3)); index `STATUS-11`.

---

## Checked, and holds (the boundary and the pieces of (2a) that do work)

- **The structural half of MEM-15(2a) is real and fixes round-6 F2.** A root can be designated for *any* already-accepted checkpoint, including the latest one (L1-13(1),(3)), the signal's height condition is "a root at a height ≥ the signal's height" (L1-13(2)), the delay is measured from the root record's own `l1BlockNumber` (L1-13(2), MSG-03) so it runs on L1 while the chain is halted, and the first attestation is the accepting route's family recorded at acceptance (L1-09, L1-13(3)). On the *structural* reading the round-6 "exit waits for a new epoch" contradiction is closed. F1 is the residue: the k−1 further attestations.
- **The k-family outage case is disclosed.** L1-13(5) states the wait is unbounded when fewer than k families operate, `L1-09`'s inventory is an Open launch gate ("fewer than k deployed, audited families … means withdrawals cannot open at all"), and L1-13(7) forbids a silent k = 1 (a recorded change order plus LIM-01 disclosure is required). I found no rule that promises otherwise; the defect is the *proof-production* gap (F1), not the family-availability gap.
- **A signal above the checkpoint has no path, and the specification says so.** MEM-15(4), LIVE-05 row "Data for a finalized block is unavailable", LIM-01's exit-scope row (10:352) and STATUS-11 all state that value above the latest accepted checkpoint cannot leave while production is halted, and MSG-03(5) discloses that a settlement halt now stops settlement indefinitely with no v1 recovery path. The course is the outlier (F2).
- **The veto cannot make the exit unavailable or violate the boundary.** MSG-04 is trigger-gated by an In-Contract-verified proof contradiction, one-shot per contradiction, self-expiring at `startedAt + T_VETO`, not extendable, gates only L2→L1 value release and never `land`, root attestation or the L1→L2 direction; an already-proven withdrawal is delayed, never cancelled (MSG-04(1),(3),(4)). Its unboundedness across *distinct* contradictions is disclosed and requires a real soundness failure.
- **The boundary is not violated by the exit, an upgrade or a reorg.** The attach path "MUST NOT write a checkpoint, MUST NOT move L1-06's pointer" and a root is always at or below the current checkpoint (L1-13(2),(3)); an upgrade/retirement "MUST NOT remove an attestation already recorded" (L1-13(3)), MIG-05 makes per-epoch image sets never-deleted and forbids retirement from invalidating a checkpoint or settled batch, and PRF-10 keeps old images accepting old history; a reorg below finality removes the accepting transaction and every later attestation together (a suffix), so no mixed "root without checkpoint" state can exist, and MSG-03 requires STATUS-07 where the claim rests on a reorgable L1 fact.
- **The deferral rollback holds in the core specification pages.** A mechanical scan of every anchored rule id and of every tombstoned parameter name found no live-read leakage in pages 01–06, 08, 10 or the index beyond F3/F4/F5/F7; REC-02/03/04 and L1-14 are explicit tombstone sections, HALT-02/03/04 are re-scoped to "no recovery path in v1", and 09 tombstones the FI, aggregation and heartbeat parameter sets with MUST-NOT-USE reasons.

## Implementability verdict (asked for by this round)

**The v1 core state machine is implementable; the exit is not, as written.** L1-01–L1-14 minus the deferred pieces describe a buildable system: verify-first `land`, the publication record and deadline, the checkpoint record, the rollback-free boundary, the k-attestation root contract, the veto, and the staking/consensus side. Three things block "as written":
1. **F1**: the exit's guarantee cannot be delivered without either a funding/obligation rule for the k−1 attestation proofs or an honest restatement (or the k = 1 change order). As written, MEM-15(1)/(2a), LIVE-01 and MSG-03(5) promise something the mechanism and its economics do not provide.
2. **F6**: the "attestation MUST depend only on L1 state that already exists" MUST is not implementable or checkable and must be rewritten.
3. **F3/F4/F5/F7/F8 + F2**: the tombstone sweep must be completed in the offence catalogue, the economics page and its parameter summary, STATUS-08/K_PROOF_BACKENDS, the residual consensus/proof-statement clauses, and the whole course.
I found no blocker in the boundary itself, in the exit's on-chain structure (given proofs), in the veto, or in the migration/upgrade preservation rules.
