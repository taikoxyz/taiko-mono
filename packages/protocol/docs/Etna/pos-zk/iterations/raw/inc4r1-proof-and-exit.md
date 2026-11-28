# Increment 04 round 1 — enforcement and the boundary with the shipped design

**Reviewer:** independent adversarial reviewer, increment 4 round 1, angle proof-and-exit.
**Snapshot reviewed:** 169480a56, extracted with git archive. Bases: increments/04-forced-inclusion-design.md, increments/04-coordination.md, DECISIONS.md D-12/D-16/D-18, CONVERGENCE.md, and the implemented spec/04, spec/05, spec/08, spec/09, spec/01 and the index.

**Counts: Critical 0 · High 1 · Medium 0 · Low 2.**

The enforcement seam is sound: PRF-04(vi) is a real check with the right public inputs, L1-04's no-gate property survives, and the exit is structurally untouched. The High is at the other seam this round was told to check — the capacity relation's input against the shipped V3 config preimage. The exit/boundary side produced no High.

---

## F1 — FI-12(5)(ii) commits L2_BLOCK_GAS_LIMIT through the historical V2 config preimage, contradicting the owner decision that says the claim is wrong, the live V3 enumeration, and the register row

**Severity: High.** Rationale: a live rule asserts a commitment that does not exist; 04-coordination.md section 3 says in terms that this claim "is WRONG and must not be implemented"; and the two implementation readings it invites are both bad — use the historical paramVersion = 2 preimage for a new epoch, which PRF-02(5) forbids and which would make the guest's V3 configHash recomputation fail for every epoch after activation (a settlement-wide halt), or treat the capacity relation's input as committed when it is not, leaving its provenance unstated in the rule that consumes it.

**File + rule id.** spec/04-l1-integration.html, FI-12(5)(ii): "no rule registered here constrains the L2 gas-limit schedule, and **while the per-epoch configuration of PARAM-04 commits L2_BLOCK_GAS_LIMIT through the paramVersion = 2 preimage of PRF-02(5)**, that commitment only records the value." Against it: (a) 04-coordination.md section 3 — "FI-12(5)(ii)'s claim that PARAM-04 commits it through the paramVersion = 2 preimage of PRF-02(5) is **WRONG and must not be implemented**", and the decision requires the rule to say the value is bound by the anchored view and that no preimage changes; (b) spec/09, L2_BLOCK_GAS_LIMIT row (09:326) — "read from the anchored L1 view the proof already fixes: it is **NOT committed through any config preimage and no preimage enumeration changes** (04-coordination.md section 3)"; (c) spec/05 PRF-02(5) — version 2's added field is "withdrawn by D-16 and tombstoned with a MUST-NOT-USE reason in 09", V2 "remains the preimage only for an epoch already entered under it and **MUST NOT be used for a new epoch**", and the live version 3 field list does not contain L2_BLOCK_GAS_LIMIT.

**Assumptions.** None.

**Attack trace (no adversary).** An implementer takes the clause at face value and wires the capacity relation's input to the per-epoch configHash preimage. Epochs entered after the increment are V3, which has no such field: the implementer must either reintroduce it (a new paramVersion and domain tag under PARAM-04 — a change to a live commitment the owner explicitly declined) or read it from somewhere the rule no longer names. If the field is restored under the V2 tag for new epochs, the guest's PRF-02(5) recomputation (V3 for new epochs) cannot equal the journal's configHash and no proof for a post-increment epoch verifies. If it is left unbound, the relation FI_MAX_PER_BATCH × FI_MAX_TX_PER_RECORD × FI_RECORD_GAS_MAX <= MAX_BATCH_BLOCKS × L2_BLOCK_GAS_LIMIT has an input whose source no rule names.

**Fault-model verdict.** Inside the fault model only as an implementation hazard (a diligent implementer following the owner decision implements it correctly); the text itself is what is wrong.

**Attacker cost.** None (no adversary needed).

**Requirement affected.** The owner decision in 04-coordination.md section 3; PRF-02(5)'s closed enumerations and PARAM-04's append-only, future-epochs-only rule; GEN-03; F-FI-1's premise statement.

**Evidence.** spec/04 FI-12(5)(ii); 04-coordination.md section 3 and its review checklist; spec/09 rows 09:326 (L2_BLOCK_GAS_LIMIT) and 09:328 (FI capacity relation); spec/05 PRF-02(5) version list and closure rule.

---

## F2 — L1-08's error list omits ForcedViewStale, which FI-11(3)(e) requires land to reject with

**Severity: Low.** Rationale: the rule names the error, the interface declares the other three FI rejection errors, and the implementer's own open question was exactly whether view-freshness needs its own surface; as landed, the required rejection has no declared selector.

**File + rule id.** spec/04-l1-integration.html, L1-08 interface: the declared FI errors are ForcedFrontierRegression, ForcedFrontierBeyondRegister, ForcedCapacityInsufficient and ForcedRecordMissing (04:409-412); there is no ForcedViewStale. FI-11(3)(e) requires land to "reject a stale view (**ForcedViewStale**), MUST reject a frontier below the predecessor's settledCount (ForcedFrontierRegression), and MUST reject settledAfter > nextSeq(A) (ForcedFrontierBeyondRegister)".

**Assumptions.** None. **Attack trace.** None adversarial; an implementer must invent a selector or a generic revert, and an integrator reading the interface cannot learn that a stale anchored view is a distinct rejection from a frontier regression — different remedies for the submitter (re-derive the view vs fix the frontier).

**Fault-model verdict.** N/A (interface completeness). **Attacker cost.** None.

**Requirement affected.** L1-08 interface completeness; FI-11(3)(e)'s stated rejection.

**Evidence.** spec/04 FI-11(3)(e); L1-08 error declarations (04:409-412); 04-coordination.md section 4d.

---

## F3 — The activation initialisation still sets the deleted dueHead/dueTail/dueCount fields

**Severity: Low.** Rationale: the migration record states these fields are deleted and free bytes, not v1 state, while the activation step still instructs the contract to initialise them; an implementer following the initialisation introduces state the register shape does not have.

**File + rule id.** spec/08-migration-upgrades.html (MIG-02 initialisation, 08:451): "at T3 the contract MUST initialise nextSeq = 0 **and dueHead = dueTail = dueCount = 0** with empty publications and publicationOrder maps". Against it: the MIG-02 state-plan row (08:993) — "Increment 04: the revived FI register needs nextSeq and pruneCursor in the one packed clock at slot 277 (**dueHead/dueTail/dueCount are deleted and free bytes, not slots**)"; and FI-10(1) — "The FI family adds no register, no queue, no escrow, no bond and no fee."

**Assumptions.** None. **Attack trace.** None; a stale initialiser for a withdrawn due-queue design. **Fault-model verdict.** N/A. **Attacker cost.** None.

**Requirement affected.** MIG-02's state plan and register-shape consistency between 08 and FI-10(1).

**Evidence.** spec/08 08:451 and 08:993; spec/04 FI-10(1), FI-14(3).

---

## Verification of the claims charged to this round (confirmed, with evidence)

1. **PRF-04(vi) enforces FI-11/FI-12/FI-13 with the right inputs.** It recomputes the anchored view from the re-executed anchor facts, sets A to the greatest anchored view the range commits to and requires equality with the journal (anchoredL1Block); verifies the required prefix against the anchored register state through storage proofs and rejects witness-supplied due lists, frontiers or sets (DA-04); takes c from the predecessor checkpoint's recorded settledCount and d(A) by the bounded binary search of FI-10(3)-(5); recomputes the forcedBoundary commitment from A, c, d(A), c' and the ordered forced-opening list and requires equality with the journal (PRF-13, L1-05 row 36); recomputes W, R and the capacity condition from the batch's own headers; requires every position in [c, c+R) resolved by exactly one of executed/void/dead (FI-13(1)); recomputes c' = c+R and requires a record at every position in [c, c'); requires the unconditional advance c' >= min(d(A), c + FI_MAX_PER_BATCH) with the waiver deleted, c' <= nextSeq(A), c' >= c, and the contract-side FI-11(3)(e) rejections. The register's record contents are witnessed but "verified against the anchored L1 state root" (L1-05 row 36), so the guest does not trust a witness list. Nothing lets a submitter land a proof the register contradicts: every FI input is either re-derived from anchored state or recomputed into a commitment the journal must equal.
2. **L1-04's no-gate property survives and the capacity condition is a validity condition.** FI-11(1) is explicit: land MUST NOT reject because the register is non-empty, MUST NOT require a coverage list, frontier or due-set claim from the submitter, MUST NOT treat the register as a structural bound of L1-04, and the settlement record is written as an effect of acceptance, never a precondition for it; FI-12(1) puts the capacity condition inside proof validity, and the enforcement is the rejected proof with no new offence (ECON-04(6)/ECON-13(4) stay tombstoned). L1-04's structural-bound list is unchanged. The one consequence is intended and disclosed: a batch that does not carry the forced work cannot produce a valid proof, so it is unlandable until it does — that is the obligation, and FI-12(5)'s no-halt argument covers it under the registered relation and the F-FI-1 schedule premise (Open, correctly tagged unmeasured).
3. **No FI state is read by the exit, and the obligation cannot delay or block it.** The non-interaction is a rule at spec/04 (04:739, the delta section 5 text): no obligation, frontier condition, resolution mode, capacity condition or prune may attach to a withdrawal root's formation, attestWithdrawalRoot, the k-family verification, the MSG-04 veto or exit eligibility; the withdrawal path MUST NOT read the register, the frontier, forcedBoundary or any FI record, and MUST NOT be gated, delayed, accelerated or conditioned by them. I checked the paths themselves: no FI name or register view appears in L1-13, MSG-03, MSG-04 or MEM-15, and the withdrawal path reads stored signals and stored checkpoints (MEM-15(1), L1-13(2)-(3)) only. The freeze a due record imposes is settlement-side and bounded by T_PROVE_DEADLINE; if no batch lands, the exit is available from the last settled state (L1-13(3), D-15's fallback). The reverse direction is closed too: no rule reads an exit to judge the obligation. The prune cannot open a hole here — deletion-only behind pruneCursor <= settledCount of the latest accepted settlement record, returning nothing and advancing no frontier, and a pruned position is already settled (FI-14(3), FI-13(1) "not a pruned slot").
4. **Both owner ratifications are implemented as ratified.** FI-12(2): "let R = min(d(A) - c, FI_MAX_PER_BATCH) — the resolved count ... and let W be the number of positions in [c, c + R) whose record is live at A — the work count", with the note that transcribing R = min(W, cap) would contradict the unconditional advance whenever a dead record sits in the window. The floor is a computation, not a rejection threshold: PRF-04(vi) requires "R >= 1 whenever the outstanding obligation at A is non-empty", FI-12(1) forces cap(batch) = FI_MAX_PER_BATCH whenever the obligation is non-empty, and FI-12(5)(iii) gives R >= min(d(A) - c, FI_MIN_DRAIN) >= 1, with 1 <= FI_MIN_DRAIN <= FI_MAX_PER_BATCH as the registered floor.
5. **The settlement pair rides the checkpoint entry and the migration budget is intact.** The pair (settledCount, anchoredL1Block) is written atomically by the accepting land (L1-03(6), FI-10(5)); forcedSettlementAt(uint64) is declared in L1-08 (04:403); the MIG-02 row keeps "15 slots (258-269, 275-277); 28 gap slots remain", with increment 04's note that nextSeq and pruneCursor fit the one packed clock at slot 277 and the deleted fields free bytes, not slots (08:993, 08:366).
6. **L2_BLOCK_GAS_LIMIT has no config-preimage owner except in FI-12(5)(ii).** spec/09's row is correct ("NOT committed through any config preimage and no preimage enumeration changes"), PRF-02(5) keeps V3 as the only live enumeration, and I found no other rule committing the value — the single contradiction is F1.
7. **Nothing outside the increment moved.** REC-01's text and the checkpoint boundary are untouched; the exit and its attestation reward are untouched; D-8/D-9's key and membership rules and D-11's publication binding are unchanged (the increment adds FI reads only on the settlement side); no FI rule references the MEM-13 heartbeat rules; and FI-14(2) deletes the preserved stall-resolution clauses rather than carrying a dormant read of a deferred name (REC-02/REC-04, GOV-04 stay tombstones). The deferral count is stated as three with the agreed membership (CONS-16's rotation, the governance stall resolution, aggregation) in the register, index and disclosure surfaces.

## On the three interface questions left to this round

- forcedSettlementAt — correctly provided (04:403); without it the settlement pair is unreadable off-chain, and the view writes nothing.
- pruneCursor view — not required by any rule: the invariant is internal (pruneCursor <= settledCount of the latest accepted settlement record, checked where it is used), and nextSeq() plus publicationAtPosition() cover the register reads the rules need. A read-only view would be a monitoring convenience only; I would not add a normative requirement for it.
- View-freshness errors — the single ForcedViewStale is the right level (splitting it into NotFinal/Regression adds no safety, and the submitter's remedy is the same: re-derive the view), but it must be declared in L1-08 (F2).

## Verdict

**Not safe to ship as-is, on one sentence.** Critical 0, High 1 (F1), Medium 0, Low 2 (F2, F3). F1 is a live rule asserting a config commitment the owner decision explicitly rejected and the live V3 enumeration does not contain; replace it with 09's wording (the value is bound by the anchored L1 view the proof already fixes, no preimage changes) and the increment's enforcement/boundary story is clean: the guest check is real and correctly input-bound, the no-gate property survives, and the exit cannot be delayed, blocked or conditioned by any FI state. F2 and F3 are one-line interface and migration edits. With F1 applied the increment is safe to ship; without it I would not ship a rule that can be read to require the historical preimage for new epochs.
