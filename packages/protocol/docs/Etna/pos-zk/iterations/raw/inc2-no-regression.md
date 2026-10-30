# Increment 02 — angle: no regression in the converged artifact

Snapshot `cea431c37` (increment 02 implemented). Read: `increments/02-heartbeat-design.md`,
`DECISIONS.md` D-17, `CONVERGENCE.md`, `DEFERRED.md`, `PLAN.md`, all four `iterations/raw/round9-*.md`
and `round10-*.md`, then every `spec/*.html` (12 pages), `learn/*.html` (13 pages),
`09-parameters.html` and `index.html`.

**Severity counts: 0 Critical, 0 High, 0 Medium, 3 Low. No attack found. The increment is safe to ship.**

Every mechanical check that made v1 clean passes, the v1 rules are untouched except for the
heartbeat-cross-reference edits the increment requires, the register and index move with it, and the
course teaches the heartbeat honestly without teaching the deferred rotation. The three Lows are
documentation-status drift outside the normative surface: a pre-increment convergence record that was
not updated, the design delta's own "NOT APPLIED" header, and two review-process sentences left in one
course page.

---

## R-INC2-01 — Low — `CONVERGENCE.md` still says "Four mechanisms are deferred and tombstoned", including heartbeat eligibility, and its "what converged" summary omits the revived mechanism.

*Rationale: the record was written before increment 02 (commit `41ac93016`, 07:49) and the increment did not update it; at this snapshot it contradicts D-17, DEFERRED.md, the specification index and the live MEM-13 rule.*

- **File + rule id.** `CONVERGENCE.md` lines 38–41 ("**Four mechanisms are deferred and tombstoned** ... narrow forced inclusion, **heartbeat eligibility**, the governance stall resolution, and aggregation") and line 25 ("v1 ships the core" list without heartbeat eligibility). Against: `DECISIONS.md` D-17 ("revives **MEM-13** ... It does **not** revive **CONS-16**"), `DEFERRED.md` line 5 ("**Three mechanisms remain deferred**; heartbeat eligibility was revived in part by increment 02"), `spec/index.html` line 42 ("three mechanisms remain deferred ... while heartbeat eligibility (D-14) was revived by increment 02 as MEM-13 (live ...)") and `spec/index.html` line 357, and `spec/03` MEM-13 being a live rule.
- **Assumptions.** None; the drift is textual and needs no adversary.
- **Attack trace (drift trace).** A reader who takes the convergence record as the statement of what shipped concludes heartbeat eligibility is deferred and not normative; the spec, register, index, D-17 and DEFERRED.md all say the opposite. No rule or parameter depends on this document, so no implementation follows from it — the defect is that the artifact's status record contradicts its own specification.
- **Fault-model verdict.** No fault model involved; documentation consistency only.
- **Attacker cost.** None.
- **Requirement affected.** The round charge ("no page contradicts another"); D-17's disclosure duty.
- **Evidence.** `CONVERGENCE.md` (3554 bytes, added at `41ac93016`, unchanged by the increment commits); `DEFERRED.md` §2 and line 5; `spec/index.html` lines 42–43, 357; `DECISIONS.md` D-17. Fix: one sentence ("three remain deferred; heartbeat eligibility was revived by increment 02 and is live as MEM-13").

---

## R-INC2-02 — Low — `increments/02-heartbeat-design.md` still carries "Status: design delta, NOT APPLIED" and describes CONS-16 as revived-in-text, while the increment is applied and D-17 leaves CONS-16 a tombstone.

*Rationale: the design delta is the document the review is built from; its status line and its Scope now contradict the shipped artifact and the decision that supersedes it.*

- **File + rule id.** `increments/02-heartbeat-design.md` line 3 ("**Status: design delta, NOT APPLIED.** No specification, register, index, course or decision file has been edited by this pass") and its Scope paragraph ("This increment revives **MEM-13** ... **revives CONS-16** (the L1-time-keyed rotation that consumes it) as a *specified but gated* rule"). Against: the three increment commits (`e135656f4`, `75b960652`, `cea431c37`), D-17 ("It does **not** revive **CONS-16**: the L1-time-keyed rotation stays deferred and tombstoned ... CONS-16 therefore MUST NOT be implemented ... until an L1-verifiable referent for `h_close` exists, and its tombstone and its `DEFERRED.md` pointer stay intact"), and `spec/02` CONS-16, which is a tombstone with no revived rule text.
- **Assumptions.** None.
- **Attack trace (drift trace).** A reviewer or implementer opening the design delta first is told nothing was applied and that the rotation was revived in text; both statements are false at this snapshot. The document's own normative conclusion (§0 item 3, §9: the rule "MUST NOT be implemented until the gate is closed") and D-17 agree, so the practical instruction is not inverted — the status and scope framing are stale.
- **Fault-model verdict.** No fault model; documentation status only.
- **Attacker cost.** None.
- **Requirement affected.** The round charge ("verify the increment is applied consistently"); PLAN.md's "one rule, one place" discipline.
- **Evidence.** `increments/02-heartbeat-design.md` lines 3–10 and §3 heading ("Revived CONS-16 — exact rule text (specified, gated)"); `DECISIONS.md` D-17; `spec/02-consensus.html` CONS-16 tombstone; `spec/index.html` CONS-16 row. Fix: a status line recording that MEM-13 shipped, that CONS-16 was not revived in text, and that the exact CONS-16 rule text in §3 is the gated proposal rather than the shipped rule.

---

## R-INC2-03 — Low — `learn/03-consensus.html` carries review-process language ("This closes round-10 finding R10-CC-01") on two pages-worth of course text.

*Rationale: the course is reader-facing teaching material; the charge explicitly asks for a review-process-language scan, and the rest of the course is free of it.*

- **File + rule id.** `learn/03-consensus.html` lines 129 and 176: "This closes round-10 finding R10-CC-01: the vote and the certificate both carry the recovery generation, matching the specification's encoding table" and "... the certificate tuple and its validity condition carry the recovery generation too." No other course page contains "review round", "finding R…", or a review-round number; the two instances are the only ones.
- **Assumptions.** None.
- **Attack trace (drift trace).** A reader of the course is shown an internal review identifier and a claim about what a review round closed, which is process bookkeeping rather than design teaching; it also dates the page to an internal round that readers cannot look up.
- **Fault-model verdict.** No fault model; editorial surface only.
- **Attacker cost.** None.
- **Requirement affected.** The round charge ("course scan … for review-process language").
- **Evidence.** `learn/03-consensus.html` lines 129, 176; artifact-wide course scan for review-process patterns finds no others. Fix: delete the two "This closes round-10 finding R10-CC-01:" clauses, keeping the design sentences.

---

## Verified clean (the checks behind the ship verdict)

- **Links and anchors.** 3,880 internal `href` targets across the 12 spec pages and 13 course pages: **0 broken files and 0 broken anchors**; all Markdown links in the artifact resolve (including the new `increments/` and `CONVERGENCE.md`/`PLAN.md` cross-references).
- **Tag balance.** All 24 HTML files parsed with a stack checker: **0 issues** (v1's clean state is preserved; the increment's edits to 03, 06, 08, 09, 10 and the index introduced no imbalance).
- **Tombstone classifier.** 161 rule divs, unchanged count; **17 tombstones** — `CONS-16`, `L1-14`, `FI-10..FI-14`, `FI-REMOVED-01`, `FI-PLANNED-01`, `PRF-15`, `REC-02..REC-04`, `ECON-13`, `GOV-04`, `LIVE-04`, `LIM-02`. `MEM-13` correctly leaves the tombstone set (it is a live rule); every tombstone still carries a MUST-NOT or explicit withdrawal statement and a DEFERRED.md / D-16 / history pointer (`FI-PLANNED-01` is the planned-update clause and correctly carries none).
- **No live rule reads a tombstoned name.** Sentence-level scan of the full deferred set (FI-*, `CONS-16`, `GOV-04`, `REC-02..04`, `PRF-15`, `L1-14`, **`T_ROTATE`, `T_ROTATE_DELAY`**, `T_STALL_GOV`, `T_GOV_RESUME`, `govResume*`, `L2_BLOCK_GAS_LIMIT`, the aggregation set, `dueHead`/`pruneCursor`, `T_INACTIVE`, `D_LAPSE_MAX`, `lastObserved`) across spec and course. **`T_ROTATE` and `T_ROTATE_DELAY` are read by no live rule**: their only occurrences are the 09 withdrawn rows ("MUST NOT be used"), the index rule row for CONS-16 and the parameter-map row ("remain withdrawn by D-16 with the deferred rotation ... MUST NOT be used by any rule, client, parameter or migration text"). Every other hit is tombstone prose, a historical field list (PRF-02's V1/V2), the MIG-02 `pruneCursor` slot arithmetic, or the `09` withdrawal table.
- **Register both directions.** 94 parsed rows. The revived heartbeat set is registered **and** referenced by live rules: `HEARTBEAT_WINDOW`, `HEARTBEAT_ANCHOR_AGE`, `HEARTBEAT_BATCH_CAP`, `HEARTBEAT_MIN_INTERVAL` (explicitly "a registered non-normative operational cadence bound the contract does not enforce"), `heartbeatKey(v)`, `lastHeartbeatAt(v)`, `lastHeartbeatWindow(v)`, `lastHeartbeatSeq(v)`, `hbWindow`, `hbSeq`, `hbAnchorBlock`, `hbAnchor`, `DOMAIN_HEARTBEAT` — all 13 present in 09 and consumed by live rules. `FREEZE_MAX` is registered in 09 and referenced by the live ECON-02 freeze cascade. The only rows without a rule-div consumer remain the five previously classified ones (`POINT_EVALUATION_PRECOMPILE_GAS` value-only, `MIN_STAKE` deprecated in favour of `S_min`, `REWARD_ASSET`, `DRAIN_DEADLINE`, `C_PUBLISH` table-consumed), and the two explicitly marked orphans are unchanged (`value_at_risk(D_MAX)` disclosure-only, `PUB_RECORD_RETENTION` retained-but-unused).
- **Index rule index and parameter map.** All 161 ids indexed; every deferred rule's row marked; the `CONS-16` row now states "DEFERRED by D-16 (tombstone) ... F7, sharpened: the closing height `h_close` itself has no L1 referent ... Increment 02 revives MEM-13 alone, so the rotation stays gated ... `T_ROTATE` and `T_ROTATE_DELAY` stay tombstoned with MUST-NOT-USE reasons in 09". `MEM-13`'s row reads "LIVE (revived by increment 02)". The parameter map's heartbeat/rotation row is correct: heartbeat set live, `HEARTBEAT_MIN_INTERVAL` non-normative, `T_ROTATE`/`T_ROTATE_DELAY` withdrawn. The only unmarked "tombstone-like" row remains `LIM-02`, the live rejected-alternatives rule. The index's verdict (lines 42–43, 51, 93, 119, 357) consistently says three mechanisms remain deferred and heartbeat eligibility is live.
- **Course scan.** Deferred-mechanism vocabulary: 2 benign hits, both `learn/05` ("the n-of-m aggregation ... is not part of v1"). The **deferred rotation is not taught**: the "rotation" occurrences are proposer rotation, key rotation, or "validator rotation cannot re-judge a past decision" — no `CONS-16`, no L1-time rotation, no early epoch close. The **heartbeat is taught honestly**: eligibility is live and renews selection into future set versions; committed versions are unchanged ("this changes who is in the next set, not how much participation a committed set needs", `learn/04`); "a heartbeat is a declaration of presence on L1, **not proof of participation**" (`learn/04` line 174 and `learn/08` line 136); **F8** is named and explained (`learn/04` lines 183, 380, 388; `learn/limitations` line 161) and **F9** is named and explained (`learn/04` line 187; `learn/limitations` line 161); no stale "v1 has no liveness gate" claim survives anywhere ("Membership has a liveness gate, and it does not compel participation", `learn/limitations` line 149).
- **The v1 rules are untouched except where the increment must touch them.** The whole increment is 507 insertions / 246 deletions over 21 files (`git diff cd8386c2c..HEAD`). `spec/01` (3 lines), `02` (12), `04` (2), `07` (7), `08` (15), `09` (39), `10` (51), `index` (45) add heartbeat/eligibility cross-references, the M7 split, the empty-roster revert note and the round-10 residue fixes; `spec/03` (93) is the MEM-13 revival plus its interface rows; `spec/06` rewrites only the sentences that listed heartbeat eligibility as deferred, explicitly leaving REC-01's guarantee unchanged ("the revived mechanism is a selection filter on future set versions; no replacement path is added and REC-01's guarantee is unchanged"). `spec/05-proof-statement.html`, `learn/02`, `learn/05`, `learn/06` and `learn/09` are untouched; the rule-id set is identical (161) and no rule was added or removed.
- **The revived rule is coherent with its design delta and with v1.** `spec/03` MEM-13 as shipped matches the delta's normative surface: ECDSA heartbeat key registered at bonding, non-consensus, owner-only forward-only rotation that does not reset `lastHeartbeatAt`/`lastHeartbeatWindow`/`lastHeartbeatSeq`; the V2 payload (`ETNA_HEARTBEAT_V2`) binding chain id, entry, `hbWindow`, `hbSeq`, `hbAnchorBlock`, `hbAnchor`; acceptance rejecting non-current windows, non-advancing sequences, recorded windows and stale/forged/zero anchors; the recorded instant is the named window's start; eligibility `lastHeartbeatAt(v) ≥ t_root(e) − HEARTBEAT_WINDOW` evaluated in the `commitSet()` call; ineligible entries excluded from `R_k`, `TotalVP_k` and `n_k` and never decayed; `commitSet()` reverts when no active entry is eligible, making the boundary halt reachable; re-attestation restores eligibility; F8 carried and sharpened, F9 new, and the declared non-fix (a cohort that keeps signing keeps its weight) stated at MEM-13(7)(f). MEM-09 states the same filter and revert; MEM-02/03/05/07/08/14 and L1-07's note keep their v1 semantics with only the eligibility cross-reference added.
- **No contradiction found in the spec, register, index or course** on what is live: v1 core + the MEM-13 eligibility filter; three mechanisms remain deferred; CONS-16 gated by F7 with no L1 referent for `h_close`; `T_ROTATE`/`T_ROTATE_DELAY` withdrawn.

## Fault-model verdict

No finding, so no fault model is implicated. Nothing in the increment adds an exploitable path, and the mechanical consistency of the converged artifact is intact.

## Is the increment safe to ship?

**Yes.** The normative surface (spec, register, index, course) is internally consistent with D-17 and with the v1 convergence baseline, no live rule reads a tombstoned name or parameter, and the three Lows are status/editorial drift in supporting documents (`CONVERGENCE.md`, the design delta header, one course page). I would ship the increment and close R-INC2-01 to R-INC2-03 as documentation edits.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 3 | R-INC2-01, R-INC2-02, R-INC2-03 |
