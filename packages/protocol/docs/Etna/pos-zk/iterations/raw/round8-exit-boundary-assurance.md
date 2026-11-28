# Round 8 — raw adversarial review: the exit, the boundary and the guarantee class (final pass)

**Reviewer:** independent adversarial reviewer, round 8, angle `exit-boundary-assurance`.
**Snapshot reviewed:** `fb67df660` (branch `etna-pos-zk`), extracted with `git archive` so every citation is snapshot content (HEAD `71b4996f1` only adds `iterations/08-freeze.md`).
**Method.** MEM-15 (1)/(2a)/(2b), L1-13, L1-11, L1-08, MSG-03/MSG-04, ECON-02(5), pages 02/05/09/10, the index and the whole course were read against each other; the rollback was re-checked mechanically (every tombstoned rule id and parameter name scanned against live text with context inspection, and the round-7 findings' claimed closures re-verified line by line). Citations: `NN:line` = line in the stripped snapshot text; rule ids are anchors.

**Counts: Critical 0 · High 2 · Medium 3 · Low 2.** No Critical. Of the two Highs, **F1 is inside the fault model in the disclosure/guarantee sense** (a normative contradiction in the safety invariant, no adversary needed); F2 is a user-facing disclosure failure. One round-7 High (R7-CC-02) is **not actually closed** — its surviving instance is F1.

---

## F1 — CONS-12 still makes the v1 safety invariant "conditional on the stall-resolution rules" and says REC-02 "may discard that history"; the same rule's opening says no such event exists in v1

**Severity: High.** One-line rationale: the safety invariant is the last place in the normative core that stages the deferred stall resolution as a live transition, and it does so **inside the same rule** that was repaired in round 7 to state the opposite — an intra-rule contradiction about whether provisional history above the checkpoint is replaceable, which is the central v1 guarantee.

**Exact rule / missing rule.** `spec/02-consensus.html#CONS-12`. First paragraph (repaired in round 7): "The unconditional 'at most one block per height ever' claim is deleted because a history-discarding event, were it live, would deliberately discard provisional history above the restored checkpoint and increment the generation … **In v1 no such event exists**: the stall resolution that would increment the generation is deferred by D-16 and MUST NOT be implemented, so the generation never advances, no height is discarded or re-produced … This closes review round 7 finding R7-RB-06: the invariant no longer reads a discard as a live event." Later scope paragraph (unrepaired): "Above the last accepted checkpoint the invariant is **conditional on the stall-resolution rules**: a certificate at a height above that checkpoint is a claim on provisional history, and **the timelocked, resume-only action of REC-02 may discard that history by incrementing the generation**, without any certificate being forged or re-judged. At and below the last accepted checkpoint no path may change the history at all. (user decision D-15: the invariant is restated relative to the authenticated checkpoint and made conditional on the stall-resolution rules for history above it.)" The sentence is live HTML (not a comment) and carries a D-15 note, not a D-16 one. Against it: `spec/10#INV-01` ("in v1 no protocol path replaces it"), `spec/10#LIVE-02` ("in v1 no rule replaces history at all"), `spec/10#LIM-01` guarantee row, `spec/06#REC-01` and the REC-02 tombstone, `DEFERRED.md` §3. **Missing rule:** delete the conditional clause (or mark it dormant with a D-16 tombstone note), as was done for the other 24 mentions of REC-02/GOV-04/REC-04 on the page.

**Assumptions.** None. No adversary, no assumption failure.

**Concrete attack trace (no adversary).**
1. An implementer builds consensus from spec/02, which its own preamble says "states CONS-01–CONS-16 in full". CONS-12 tells it the invariant above the checkpoint is conditional on the stall-resolution rules and that REC-02's action may discard that history; CONS-15/REC-02 are tombstones that "MUST NOT be implemented". The implementer must either implement a forbidden transition or violate the text it is reading.
2. An interface or reviewer checking the guarantee class gets two answers to the one question D-16 was meant to settle — whether a PoS confirmation above the checkpoint can ever be replaced. REC-01/INV-01/LIM-01/LIVE-01/LIVE-02/the guarantee-class preamble say no path exists in v1; CONS-12 says the invariant is conditional on a path that discards.
3. A reviver of the deferred mechanism reads CONS-12 as the design's own statement that the invariant already assumes a discard, and that the generation handles it — reinstating exactly the mechanism whose round-6 Critical (G-3, the anchor-certificate generation) was why it was deferred.

**Inside / outside the claimed fault model.** Inside the specification's own guarantee model (no attacker, no assumption failure). It is not a safety break: the stale text describes a transition v1 cannot perform, so I could not construct an exploit from it; the harm is conformance and disclosure, exactly as in round 7's R7-CC-02, which rated this class High.

**Attacker resources and cost.** None.

**Requirement / fixed decision affected.** D-16 (deferral and MUST-NOT-IMPLEMENT tombstones); REC-01's boundary; **INV-01**; the v1 guarantee class; the round-7 closure claim (R7-CC-02 was reported and is listed as closed; the CONS-12 sentence it cited survives verbatim at `296f44b54`-era wording into `fb67df660`). Overlaps R7-RB-06.

**Evidence.** `spec/02-consensus.html#CONS-12` (both paragraphs, same rule); `spec/10#INV-01`, `#LIVE-02`, `#LIM-01`; `spec/06#REC-01` and the REC-02 tombstone; `iterations/raw/round7-core-consensus.md` R7-CC-02 (which cites this exact sentence as `02:420-425`); mechanical scan: 25 occurrences of REC-02/REC-03/REC-04/GOV-04 on page 02, exactly one without deferral context — this one.

---

## F2 — The course still describes the exit as "checkpoint + message path + delay": no withdrawal root, no k families, no veto and no proving-market dependency anywhere in `learn/`

**Severity: High.** One-line rationale: MSG-03(5) requires the k-family wait, the proving-market assumption with its falsifier, and the veto to be disclosed **wherever withdrawal timing is described**, and STATUS-11 binds learning pages to the labels and their disclosures; the course describes withdrawal timing in four places and mentions none of the three, so every user-facing account of the one guarantee v1 retains is wrong in the direction of more availability than exists.

**Exact rule / missing rule.** `spec/04#MSG-03`(5): "The design MUST disclose, wherever withdrawal timing is described and without burying it, the two user-visible costs … (i) an exit is proven only against a withdrawal root, which waits for k distinct backend families to each verify the checkpoint statement … the exit stays available during a stall whenever those proofs are produced and funded (L1-13(3),(5)) — the proving-market assumption and falsifier of MEM-15(2b); and (ii) an unexpired veto (MSG-04) can add up to T_VETO …". `spec/index.html#STATUS-11`: "[a]ny interface, document or **learning page** that shows a progress indicator must use these labels and must state which status is being shown … must state the two additional delays of STATUS-08". `spec/10#LIVE-01`, `#LIVE-05`, `#LIM-01` and the guarantee-class preamble all carry the proving-market condition. **Missing rule:** the course re-sync to the v1 exit.

**The stale text, verbatim (live, non-commented).**
- `learn/09-censorship-and-the-bridge.html:102` — "A withdrawal then needs `WITHDRAWAL_DELAY` measured from that checkpoint's `l1BlockNumber`, plus Ethereum finality where the claim rests on a reorgable L1 fact."; `:171` — "checkpoint must cover the signal, and `WITHDRAWAL_DELAY` …"; `:246` — "Check that `WITHDRAWAL_DELAY` has elapsed since the checkpoint's `l1BlockNumber` …"; `:272` — "From there the value can leave once `WITHDRAWAL_DELAY` has [elapsed]". The lesson's "minimum evidence that an L2→L1 message may be released" (its own `Check yourself` answer) omits the root, the k attestations, the veto and the proving market.
- `learn/02-life-of-a-transaction.html:210` — "Withdrawal | checkpoint + message path + `WITHDRAWAL_DELAY`".
- `learn/07-timing.html:84, 99, 217, 244` — "Withdrawal availability | accepted (or finalized) → withdrawal-eligible | plus `WITHDRAWAL_DELAY`"; "plus `WITHDRAWAL_DELAY` measured from that checkpoint's `l1BlockNumber`"; "Withdrawal-eligible | Checkpoint plus message path plus the delay (STATUS-08)".
- `learn/glossary.html` — "Withdrawal-eligible" defined as "an L1-accepted (or finalized) batch plus the message-authentication path and any required delay", with no root; the "Withdrawal delay (`D_WITHDRAW`)"/`WITHDRAWAL_DELAY` entries do not distinguish the root clock.
- Quantitative check: `grep -c "proving market|proving-market"` = **0** in every `learn/*.html`; `grep -c "withdrawal root|attestation"` = 0 in `learn/09`, `learn/02`, `learn/07`, and 1 in `learn/04` (the deferred heartbeat, correctly negated). So the disclosure appears in the specification and the index and nowhere in the course.

**Assumptions.** None.

**Concrete attack trace (no adversary).** A user is stalled and reads the failures lesson and the bridge lesson: they are told the value leaves once the withdrawal delay on the checkpoint has elapsed, and that the only additional delay is Ethereum finality. In reality the release reverts until k distinct families have each verified the checkpoint statement, the wait is unbounded if fewer than k families operate (L1-13(5)), a veto can add up to T_VETO, and the k−1 proofs must be produced by a funded market (MEM-15(2b)). The user cannot plan the exit, and an integrator building the release check from the course implements a path MSG-03 forbids. The error is in the direction of promising more than v1 guarantees, on the guarantee that is now the whole of v1's user protection.

**Inside / outside the claimed fault model.** N/A (documentation); inside the project's own disclosure model, which is the only protection a provisional/ halted chain gives (STATUS-11's failure-mode note).

**Attacker resources and cost.** None.

**Requirement / fixed decision affected.** D-16; MSG-03(5)'s MUST-disclose; STATUS-11; `GEN-01`/`GEN-02`; `learn/index.html`'s own contract ("If this course ever claims more than the specification does, treat that as a bug in the course"); the freeze's round-8 claim that "the course no longer teaches any deferred mechanism in the present tense" (true but not the whole obligation — the course must also teach what v1 *does* guarantee).

**Evidence.** The lines above (raw line numbers in the snapshot); zero `proving market` matches in `learn/**`; `spec/04#MSG-03`(5); `spec/index.html#STATUS-08`, `#STATUS-11`; `spec/03#MEM-15`(2b).

---

## F3 — The attestation reward's "split" is required by three rules but has no representation in the policy record, no registered identifier, and no enforcement point in the ledger it is drawn from

**Severity: Medium.** One-line rationale: the round-8 fix gives the k−1 attach proofs a payer, but the payer's amount is defined as "the split … fixed by that recorded policy" while the policy is defined as exactly two shares, the register gives the split no identifier or value, and L1-11 keeps one balance with no sub-accounting — so a security-relevant value is left to invention and the stated split cannot be enforced.

**Exact rule / missing rule.**
- `spec/07#ECON-02` clause 5(e): "The policy is **two** non-negative integer shares in parts per million, `ALLOC_VAL_PPM` and `ALLOC_PRV_PPM` … **The split of the share between landing work and attestation work is fixed by that recorded policy** and is unmeasured (09); it MUST NOT be set by the Inbox or by an attestation submitter, and no new rate is introduced."
- `spec/04#L1-13`(5): "the recorded allocation policy **MUST name withdrawal-root attestations among the proving work that share covers**"; `spec/04#L1-11`: "The attestation reward … is **fixed by the recorded allocation policy** of ECON-02 clause 5 that funds withdrawal-root attestations (L1-13(5))".
- `spec/09` `ALLOC_VAL_PPM, ALLOC_PRV_PPM` row: "the split between landing and attestation work is fixed by that policy and is unmeasured, and the attestation payout `attestRewardPaid` is drawn from the L1-11 ledger the transferred share credits" — no identifier, unit, value or formula for the split, although `PARAM-01` requires every protocol parameter to have "its identifier, unit, proposed value or formula, the derivation or source, and a tag".
- `spec/04#L1-11`: a single ledger; `rewardPaid = min(REWARD_QUOTE, ledger_before + msg.value)` on a landing and `ledger_after = ledger_before − attestRewardPaid` on an attestation, both permitted debits, no sub-balance, no ordering rule, no per-epoch cap on attestation payouts. **Missing rule:** the policy field that carries the split (name, unit, value/formula, tag) and either sub-ledger accounting or an ordering/reservation rule that makes the stated split true on-chain.

**Assumptions.** None for the contradiction; the economic consequence assumes ordinary self-interested submissions.

**Concrete attack trace.** Two implementers read "the split is fixed by the recorded policy" and choose differently (a fixed ETH quote per attestation; a ppm of the proving share; per family; per height), so the same policy record yields different payouts and the S1/launch calibration is not comparable. With a single ledger: (a) attestations submitted first (for many heights/families, each with a genuine proof) consume the balance and landers receive 0 — land already lands with `rewardPaid = 0`, so settlement can stall; (b) landers consume it first and attestations pay 0 — the MEM-15(2b) falsifier state, in which the exit is not funded even though the rules say the share "funds both kinds of proving work". Neither direction violates a MUST, because the split has no enforcement point.

**Inside / outside the claimed fault model.** Inside for (a)/(b): ordinary permissionless calls, no adversary beyond self-interest; the falsifier discloses the *consequence* of (b) but not that the rule cannot enforce the split that is supposed to prevent it. No safety break and no fund loss.

**Attacker resources and cost.** The proving cost of the attestations/landings it submits (real work), and gas; for (a) the attacker's cost is the same proving work the honest side would do — the harm is misallocation, not theft.

**Requirement / fixed decision affected.** D-16's shipped exit; `PARAM-01`; `L1-11`'s conservation identity; ECON-02(5)(e)'s "one inflow cannot be allocated twice" and "the share funds both kinds of proving work".

**Evidence.** `spec/04#L1-11` (attestation identity and the two permitted debits); `spec/04#L1-13`(5); `spec/07#ECON-02` clause 5(e); `spec/09` `ALLOC_VAL_PPM, ALLOC_PRV_PPM` row; `spec/09#PARAM-01`.

---

## F4 — The (2b) falsifier names only the unfunded market, while the same clause requires the witness; the exit's data/witness dependency is not named as one of its dependencies

**Severity: Medium.** One-line rationale: the exit's assumption is stated as "a funded proving market produces the k−1 attestation proofs", but (2a) itself says those proofs need "the recorded certificate, the batch's data and the pre-state witness"; a fully funded market with no retained witness (expired blobs, no archive at the height) still leaves the user unable to exit, and no rule of the exit names that second dependency or lists it with the falsifier.

**Exact rule / missing rule.** `spec/03#MEM-15`(2a): "the k−1 further proofs are not derivable from L1 state: producing each one is off-chain proving work that needs **the recorded certificate, the batch's data and the pre-state witness**". (2b): "The availability of this exit rests on one economic assumption … **a funded proving market produces the k−1 attestation proofs** … its falsifier is named: **an unfunded or absent proving market** leaves a user … unable to exit — no witness-holder is paid to produce the k−1 proofs". `MEM-15`(1): "Beyond Ethereum's own liveness (A-L1-1), **the one dependency the exit does carry is the funded proving market**". `spec/10#LIVE-01`: "Not conditional on (L1), (L2) or (L6) … It is not independent of proving, however: (L4) is the prover-completion assumption, the exit's k−1 attestation proofs are funded proving work … and the exit therefore depends on the funded proving market". The witness inputs are governed by ROLE-03/DA-05 (RETRIEVABILITY_WINDOW, unmeasured ARCHIVE_REQUIREMENT), A-CONS-5 and A-DA-2, but the exit's own assumption/falsifier and LIVE-01's dependency list do not name them; L3 ("correct validators hold and can serve the data of the blocks they voted for, at least until settlement or the retention window ends") is excluded from LIVE-01's independent set, so the dependency is implicit at best. **Missing rule:** state the exit's second dependency with the first (a retained witness for some accepted checkpoint at or above the signal's height) and extend the falsifier.

**Assumptions.** A settlement stall outlives blob retention (EIP-4844's 4096 epochs, ≈18 days, DA-05) or the affected heights' archives are unavailable; then a funded market cannot produce proofs. The general retention assumption is disclosed elsewhere (A-CONS-5, A-DA-2, DA-05/DA-06, ROLE-03), so this is a scoping/disclosure defect, not an undisclosed assumption.

**Concrete attack trace (no adversary).** A settlement stall lasts past the retrievability window. The proving market is funded and willing. The batch data for the checkpoints above the user's signal height is no longer retrievable (blobs expired, no archive serves the height, ARCHIVE_REQUIREMENT unmeasured) and the pre-state witness is gone. No k−1 proofs can be produced, no root forms, and MEM-15's release condition is never met — with the funded market the guarantee class names, and without any adversary. The user reads MEM-15(1)/(2b) and LIVE-01 and concludes the only remaining risk is funding.

**Inside / outside the claimed fault model.** Inside (a long halt is v1's disclosed position; retention is an assumption the design already names, but not as part of this guarantee). No funds are lost; the exit is delayed indefinitely.

**Attacker resources and cost.** None.

**Requirement / fixed decision affected.** D-16's exit guarantee class; `MEM-15`(1)/(2b); `LIVE-01`; `STATUS-08`/`MSG-03`(5)'s disclosure of "the exit stays available … whenever those proofs are produced and funded" — "produced" silently assumes a witness exists.

**Evidence.** `MEM-15`(1),(2a),(2b) (03 text lines 338, 340, 341); `spec/10#LIVE-01` (10 lines 191-205) and its L3 clause (10 lines 173-174); `spec/04#DA-05`/`#DA-06` and `spec/03#ROLE-03`; A-CONS-5/A-DA-2.

---

## F5 — Two un-relaxed D5 premises survive (MEM-05(5) and the register's blob-quantisation row), although D-11 superseded exactly that wording

**Severity: Medium.** One-line rationale: both clauses argue from "data and proof in one L1 transaction / no data-first window", which D-11 removed and which the index's own D5 row says is superseded; one of them is the stated derivation of a registered bound.

**Exact rule / missing rule.**
- `spec/03#MEM-05`(5): "**D5 lands a batch's data and its proof in one L1 transaction, so there is no data-first window** in which a third party could inspect a published batch and object before settlement. Detection therefore cannot rely on 'the data sat on L1 for N hours before the proof arrived'". Under D-11 such a window exists by design (bounded by `T_PROVE_DEADLINE`) and is the publication register's purpose; the clause's conclusion about evidence timing may still hold for other reasons, but its stated ground is false.
- `spec/09` "Blob-quantisation bound on batch length" row (09 line 176): "**because D5 requires a batch's data and its proof in one L1 transaction (L1-01)**, the per-L1-block blob ceiling is a ceiling on K and on `MAX_BATCH_BLOCKS`", closing with "the single-transaction requirement is D5 (L1-01, L1-05 row 7)" — no D-11 qualification. The ceiling itself survives through DA-07 (the whole claimed range's blobs in one publication), but the registered derivation cites a superseded requirement. `spec/index.html` fixed-decision D5 row: "the original 'no data-first/proof-later path' wording **is superseded in that one respect**".
- **Missing rule:** re-base both on D-11 (the window and its proving-deadline bound; the publication transaction's blob ceiling).

**Assumptions.** None.

**Concrete attack trace.** Not an attack: a parameter reviewer recomputes the blob ceiling from D5's one-transaction form and rejects the referenced-publication path as non-conforming; a reader of MEM-05(5) concludes published-but-unproven data is never observable on L1 before settlement, contradicting DA-10's register and ECON-13's publication rules.

**Inside / outside the claimed fault model.** N/A (textual).

**Attacker resources and cost.** N/A.

**Requirement / fixed decision affected.** D-11/`GEN-02`; `PARAM-01` (a derivation must be the rule's); the round-6 finding F6, never picked up by round 7.

**Evidence.** `spec/03#MEM-05`(5) (03 line 299); `spec/09` blob row (09 line 176); `spec/index.html` D5 row; `spec/04#DA-07`,`#DA-09`,`#DA-10`.

---

## F6 — The delay's anchor differs between MEM-15(1) and its owning rule

**Severity: Low.** One-line rationale: `MEM-15`(1) measures `WITHDRAWAL_DELAY` "from the checkpoint's `l1BlockNumber`" (the latest accepted checkpoint) while `L1-13`(2)/`MSG-03`/`STATUS-08` measure it from the **root** checkpoint record's `l1BlockNumber`; the two differ whenever a user's root is an earlier checkpoint than the latest accepted one.

**Exact rule.** `MEM-15`(1): "It is subject to `WITHDRAWAL_DELAY`, measured from the checkpoint's `l1BlockNumber` on the L1 clock (MSG-03), to the formation and submission of a withdrawal root **for that checkpoint** as clause (2a) states". `L1-13`(2): "measured from the root checkpoint record's own `l1BlockNumber` (L1-07)"; `MSG-03`: "measured from that root checkpoint record's own `l1BlockNumber` — never from the attestation transaction"; `STATUS-08`: "from the root's `l1BlockNumber`". `L1-13`(2) also allows "any withdrawal root at a height ≥ h", so the root need not be the latest checkpoint. **Missing rule:** MEM-15(1) should name the root record, as its cited owner does.

**Assumptions.** None.

**Concrete attack trace.** Not an attack: a wallet implementing MEM-15's wording shows an earlier release time (clock from the latest checkpoint) than MSG-03 permits (clock from the root's record) when the root is older — a display/user-timing discrepancy, not a release bypass, since the release path itself is MSG-03's.

**Inside / outside the claimed fault model.** N/A.

**Attacker resources and cost.** N/A.

**Requirement / fixed decision affected.** `GEN-03` (one rule, one place); `STATUS-08`/`STATUS-11` disclosure; D-16's exit.

**Evidence.** `spec/03#MEM-15`(1),(2a); `spec/04#L1-13`(2), `#MSG-03`; `spec/index.html#STATUS-08`.

---

## F7 — DEFERRED.md's cross-cutting note is stale: it still calls the exit contradiction and the un-relaxed-D5 rows "the load-bearing ones for v1"

**Severity: Low.** One-line rationale: the register's own summary of what outlives the deferrals describes defects that round 8 repaired (the exit contradiction) or that are residual wording (F5), so a reader of the deferral register is told v1 still carries load-bearing defects it no longer carries.

**Exact rule / missing rule.** `DEFERRED.md`, "Cross-cutting items that outlive all four": "The load-bearing ones for v1 are **the exit contradiction (`G-2`/`F1`/`F2`)** and **the un-relaxed-D5 premises still present in a few rows**." After MEM-15(2a)/(2b) + L1-13(5)/L1-11 + the guarantee-class sweep, the exit contradiction is repaired (its residual is F3/F4); the D5 premises are F5's two rows. Also, the same section says "The learning site must be re-synced whenever a deferred mechanism returns, because it teaches the design as it stands" — the course is currently *not* in sync with the v1 exit (F2), which that sentence would not catch. **Missing rule:** update the note to the current residual list.

**Assumptions.** None.

**Attacker resources and cost.** N/A.

**Requirement / fixed decision affected.** The freeze's closure bookkeeping; D-16's "disclosed, not silently dropped" discipline.

**Evidence.** `DEFERRED.md` opening and "Cross-cutting items" section; `spec/03#MEM-15`(2b); `spec/10` guarantee-class preamble.

---

## Verification of the claims charged to this angle (explicit verdicts)

1. **A k-attestation root for the LATEST accepted checkpoint is formable with no new L2 block, no settlement progress, no quorum and no permission — YES, structurally.** `L1-13`(1) widens the formation point to "any already-accepted checkpoint, and in particular the latest"; (3) makes `attestWithdrawalRoot` permissionless, keyed on the recorded `statementHash` and the epoch's accepted image set, "MUST NOT require a new L2 block, a new batch, a new checkpoint, an epoch boundary or any settlement progress"; the accepting route counts as the first family attestation; `L1-13`(2) needs a root at a height ≥ the signal's, and the latest checkpoint always satisfies that. The call does not gate on funding. Residual: the k−1 proofs and their inputs (F3, F4).
2. **Funded (`attestRewardPaid` from the proving share via L1-11, best-effort, never gating) — YES, the payer exists and is stated; the amount's representation is not.** `L1-13`(5), `L1-11` (attestation identity, two permitted debits, "MUST NOT require a non-zero `attestRewardPaid`"), `ECON-02`(5)(e) and 09's `ALLOC_*` row name the proving share, the claim path and the submitting account. Residual: F3 (the split has no field/identifier/enforcement) and the disclosed falsifier.
3. **Cannot be blocked by the veto or the delay — YES.** `MSG-04`(4): the veto "MUST NOT gate … root attestation (L1-13)" and gates only L2→L1 value release; it self-expires, cannot be extended, delays but never cancels a proven withdrawal; repeated windows require a fresh on-chain-verified contradiction. `L1-13`(2)/`MSG-03`: the delay runs from the root record's L1 block and therefore runs during a halt; a root formed late has already accrued delay.
4. **The (2b) falsifier is the right one and appears everywhere the exit is promised — PARTLY.** Right about funding; **incomplete** as to the witness (F4). It appears with the exit in `MEM-15`(1)/(2b), `L1-13`(5), `MSG-03`, `STATUS-08`, `STATUS-11`, `LIVE-01`, `LIVE-05`, `LIM-01` (guarantee and exit-scope rows), the guarantee-class preamble and the index — but **nowhere in the course** (F2).
5. **The boundary survives the exit, the veto, an upgrade and a reorg — YES.** The attach path "MUST NOT write a checkpoint, MUST NOT move L1-06's pointer", a root is always at or below the current checkpoint (`L1-13`(2),(3)); the veto rewrites and recalls nothing (`MSG-04`(1),(4)); an upgrade/retirement "MUST NOT remove an attestation already recorded" and PRF-10 preserves the recorded statement, while `MIG-05` makes per-epoch image sets never-deleted and forbids retirement from invalidating a checkpoint or a settled batch; a reorg below finality removes the accepting transaction and every later attestation as one suffix, and `MSG-03` requires STATUS-07 where the claim rests on a reorgable L1 fact.
6. **LIVE-01's re-scoped independence claim — YES as re-scoped, with the F4 caveat.** "Not conditional on (L1), (L2) or (L6)" is true for an already-accepted checkpoint's root and release, and the rule now states the proving dependency explicitly ("It is not independent of proving … depends on the funded proving market that MEM-15(2b) assumes"). Its named dependency list omits the witness/data-retention dependency (F4), which its own L3 clause covers only implicitly by exclusion.
7. **No live rule reads a tombstoned name — one exception.** A mechanical scan of every tombstoned rule id and parameter name against live text found exactly one genuine live read: the CONS-12 sentence (F1). The remaining hits are historical ledger entries (`LIM-03`'s change-order-04 record naming REC-03), tombstone lists in 09, correctly negated course text, and a spec/05 reference to REC-04 that is explicitly marked "a D-16 tombstone". The absences themselves (forced inclusion, heartbeat, stall resolution, aggregation) are disclosed in the guarantee-class preamble, `LIVE-04`/`LIVE-05`, `LIM-01`, the index and `DEFERRED.md`, and the course no longer teaches any of the four in the present tense.

## Implementability verdict

**v1 is implementable as written, with two repairs before it is unambiguous.** The core machinery this angle covers is coherent and buildable: the checkpoint record and boundary, the k-attestation root with its one-verification-per-attestation interface, the L1-11 identities (both debits bounded, both best-effort, neither gating), the veto with its objective trigger and self-expiry, the release rule and its disclosures, and the migration/upgrade preservation bars. Two items are not implementable as written: **F3** (the allocation policy must carry an attestation split that neither the policy definition nor the register defines, and the ledger has no way to enforce the stated split) and **F1** (a normative safety invariant that contradicts itself and stages a forbidden mechanism — an implementer cannot satisfy both halves). F2 is a delivery blocker for user-facing material rather than for code; F4, F5, F6 and F7 are disclosure and wording repairs.
