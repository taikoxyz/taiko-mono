# Increment 2 — register, index and disclosure review

**Angle.** The register, index and disclosures for increment 02 (MEM-13 heartbeat eligibility revived;
CONS-16 stays a gated tombstone). Targets: `spec/09-parameters.html`, `spec/index.html`,
`spec/10-assurance.html`, `spec/08-migration-upgrades.html`, cross-checked against `spec/03` (MEM-13
and the per-entry state), `spec/02` (CONS-13/CONS-16), `spec/04`, `spec/06`, `DEFERRED.md`,
`DECISIONS.md` D-17, `CONVERGENCE.md` and `learn/`.

**Snapshot.** `cea431c37`; the working tree is at the same commit. Also read:
`increments/02-heartbeat-design.md` (the authoritative design delta, including its §7 required-change
list and Appendix A/B), `DEFERRED.md`, D-17.

**Result: 0 Critical, 0 High, 0 Medium, 2 Low.** The register and the increment's disclosures are
substantially correct: every revived name is registered with a unit, an owner rule and a tag; the new
anchor names are registered; the withdrawn rotation/decay names keep their MUST-NOT-USE reasons and are
read by no live rule; the migration claim is exact; and the assurance rows are accurate. The two Lows are
documentation-grade: one stale present-tense deferral count in the convergence record (which the design
delta deliberately did not edit but did not mark), and the new falsifier F9 carried only in its
pre-signing half in the assurance/index summaries. **The increment is safe to ship**; neither Low is
inside the fault model and neither overstates a guarantee.

---

## INC2-RD-01 — Low — `CONVERGENCE.md` still states, in the present tense and with no historical marker, that four mechanisms are deferred and tombstoned (including heartbeat eligibility), while the live register says three and records the revival.

**Rule / artifact.** `CONVERGENCE.md` line 39: "**Four mechanisms are deferred and tombstoned**, each
with its blockers and revive criteria in `DEFERRED.md`: narrow forced inclusion, **heartbeat
eligibility**, the governance stall resolution, and aggregation." The document opens with
"**Verdict: the v1 design is CONVERGED.**" and carries no line saying it records the pre-increment
convergence; `00`-level readers see it as current. The live list is `DEFERRED.md` line 5 ("**Three
mechanisms remain deferred**; heartbeat eligibility was revived in part by increment 02 …") and §2 is a
revival record. `increments/02-heartbeat-design.md` §7.8 states the deliberate choice: "CONVERGENCE.md and
iterations/*freeze* are **historical records and are not edited**; the live list is DEFERRED.md."

**Assumptions.** The design delta's §7.8 choice is authoritative; the lead's increment check is that the
deferral count reads three "everywhere"; `CONVERGENCE.md` is a top-level artifact a reader may consult
without reading the increment.

**Attack trace (reader-facing, no adversary).** A reader who opens `CONVERGENCE.md` (the document that
says the design converged) learns that heartbeat eligibility is deferred and tombstoned — the
pre-increment state. Nothing in the file points at increment 02 or at `DEFERRED.md` §2, and its
"Four mechanisms" sentence is the only present-tense deferral count in a non-historical artifact that
still says four (the spec/index/assurance/08 sites either say three or explicitly narrate D-16 four →
increment 02 revives one → three). Direction of error: the artifact *understates* what is live, so no
guarantee is overstated; the cost is a stale statement of record.

**Fault-model verdict.** Not applicable (documentation consistency; no rule, no guarantee, no attacker).

**Attacker cost.** None.

**Requirement affected.** D-17; DEFERRED.md as the live register; the increment's disclosure duty; GEN-03
(one statement, one place) as applied to status counts.

**Evidence.** `CONVERGENCE.md` lines 3, 39–41; `DEFERRED.md` lines 5–7 and §2; `spec/index.html` lines
42–43, 356–357, 594; `spec/10-assurance.html` lines 31, 423–424; `spec/06-recovery-exceptions.html`
lines 241–244; `increments/02-heartbeat-design.md` §7.8. Suggested fix: a one-line header in
`CONVERGENCE.md` ("point-in-time record of rounds 9–10; the live deferred list is `DEFERRED.md`, and
increment 02 revived MEM-13") rather than editing the record's content.

---

## INC2-RD-02 — Low — the new falsifier F9 is carried in the assurance and index only in its pre-signing half; its second consequence (an all-ineligible append window makes `commitSet()` revert and the MEM-09(5) boundary halt reachable) is absent from the assurance's halt table and from every F9 gloss there and in the index.

**Rule / artifact.** The design delta defines F9 with two consequences
(`increments/02-heartbeat-design.md` §6.2): "The pre-signing horizon is bounded, not closed … **the same
term makes the all-ineligible append window of §6.1(5) reachable**", Status Open. The implemented rule
states both: `spec/03` MEM-13(3) ("If no active entry is eligible, `commitSet()` MUST revert … the
append obligation is missed … the boundary consequences are MEM-09(5)'s and are not softened here") and
MEM-13(7)(e) ("the append deadline is missed, and the boundary halt of MEM-09(5) becomes reachable").
The assurance page's F9 mentions state only the first half — `spec/10` line 321 ("the exclusion is
bounded not closed (falsifier F9)"), line 353 ("The pre-signing residual (F9) bounds how long a key that
stops signing can cover a following window"), line 348 ("bounded by falsifier F9") — and the LIVE-05
table's list of halt causes (lines 320–324: settlement stall, quorum loss by attrition, a simultaneous
stop, a missing/unfinal epoch-set entry, unavailable data) has **no row for a window in which no active
entry is eligible**, although LIVE-05 states it enumerates "for each way validators can stop the chain …
exactly what a user can still do and what the protocol does not bound". The index's MEM-13 row
(`spec/index.html` line 428) says only "If no active entry is eligible, `commitSet()` reverts" and then
glosses "F9 (the bounded, not closed, pre-signing residual)". The consequence *is* taught:
`learn/04-staking-and-epochs.html` lines 163–164, 190, 231–232 and `learn/limitations.html` line 161.

**Assumptions.** The increment's disclosure review covers the assurance's F5–F9 accuracy and the halt
table's completeness; the rule text and the course are the normative/teaching disclosures of record.

**Attack trace (reader-facing, no adversary).** A reader of the assurance page's limitation register
learns that an operational lapse costs slots and that the pre-signing residual is bounded; they do not
learn there that the *same* freshness term can leave a window with no eligible entry at all, making the
append revert and the boundary halt reachable — a chain-wide consequence, not an individual lapse, and
one the design delta explicitly folds into F9. The failure direction is under-disclosure of a limitation
of the new mechanism; nothing promised exceeds what the rules deliver.

**Fault-model verdict.** Not applicable (disclosure completeness; the normative rule and the course state
the consequence, so no guarantee is overstated).

**Attacker cost.** None.

**Requirement affected.** The increment's F9 disclosure duty; LIVE-05's "for each way validators can stop
the chain" claim; MEM-13(7)(e); DEFERRED.md §2 ("F9" as a named residual).

**Evidence.** `spec/10-assurance.html` lines 318–324 (halt table), 348, 353; `spec/index.html` line 428;
`spec/03-membership-staking.html` MEM-13(3) and (7)(e); `learn/04-staking-and-epochs.html` lines
163–164, 190, 231–232; `increments/02-heartbeat-design.md` §6.2 and §7.5. Suggested fix: add the
all-ineligible append as a cause row (or extend the "missing epoch-set entry" row) in the LIVE-05 table,
and one clause in the index's F9 gloss.

---

## Verified and holds

1. **Every revived heartbeat name is registered with a unit, an owner rule and a tag.** `spec/09` lines
   213–225: `HEARTBEAT_WINDOW` (seconds; relation; MEM-13(2)(3)(6)), `HEARTBEAT_MIN_INTERVAL` (seconds;
   non-normative, contract does not enforce; MEM-13(2)(6)), `HEARTBEAT_BATCH_CAP` (signatures per
   transaction; relation; MEM-13(2)(2a)), `HEARTBEAT_ANCHOR_AGE` (L1 blocks; relation incl. the ≤ 256
   `blockhash` bound; MEM-13(2a)(e)(6)), `heartbeatKey(v)` (ECDSA key + rotation block; MEM-13(1)),
   `lastHeartbeatAt(v)` (unix seconds; MEM-13(2b)(3)), `lastHeartbeatWindow(v)` (window index;
   MEM-13(2a)(c)–(d)(2b)), `lastHeartbeatSeq(v)` (sequence number; MEM-13(2a)(c)(2b)), `hbWindow`
   (payload record content; MEM-13(2)(2a)(b)), `hbSeq` (payload record content; MEM-13(2)(2a)(c)),
   `DOMAIN_HEARTBEAT` (domain tag `"ETNA_HEARTBEAT_V2"`; MEM-13(2)), and **the new names**
   `hbAnchorBlock` (L1 block number; MEM-13(2)(2a)(e)) and `hbAnchor` (L1 block hash; MEM-13(2)(2a)(e)(2b)),
   each with a status tag ("unmeasured", "record (not tunable)", "payload record content (not tunable)",
   "decided (domain tag)"). The glossary row 33 is restated live with the accurate caveats (F8/F9, the
   declared non-fix, the gated rotation, "a chain stalled inside a committed epoch is not resumed by this
   rule"); the change-order note (line 96) moves the heartbeat set out of the withdrawn block and names
   the three new rows; the measurement row is reinstated (line 266) and the withdrawn-measurement note
   says three mechanisms remain deferred (line 270). `spec/03`'s own non-normative roster (lines
   707–716) matches, name for name, and `spec/index.html` line 558 lists the same live set.
2. **`T_ROTATE`, `T_ROTATE_DELAY`, `T_INACTIVE`, `D_LAPSE_MAX` and `lastObserved(v)` stay
   withdrawn, with MUST-NOT-USE reasons, and no live rule reads them.** `spec/09` lines 207–212 carry
   each withdrawal with its reason (D-14 for the decay set, D-16 for the rotation set; `lastObserved`'s
   retirement is tied to `lastHeartbeatAt(v)`); `spec/03` lines 717–720 repeat them in the roster and
   line 683 keeps them withdrawn; `spec/index.html` line 415 keeps CONS-16 a tombstone and line 558
   keeps the two rotation names in the withdrawn block; `spec/10` line 351 states the gate and the
   withdrawal. A scan of the specification and the course for these five names finds only tombstones,
   withdrawal rows and statements that they stay withdrawn — MEM-13(6) names `T_ROTATE`/`T_ROTATE_DELAY`
   solely to say they remain withdrawn with the rotation, and CONS-13/CONS-16 read no deferred name
   (`spec/02` lines 441, 460, 505). `learn/` contains none of the five names.
3. **The deferral count is three in every live artifact** (the one stale present-tense site is INC2-RD-01,
   a historical record): `DEFERRED.md` line 5 and §2; `spec/index.html` lines 42–43, 356–357, 594 and
   the prohibition line 585 ("… that heartbeat eligibility is still absent (increment 02: it is live and
   changes which entries future set versions commit, repairing no committed version)"); `spec/10` lines
   31 and 423–424; `spec/06` lines 241–244 ("three of the four add-on mechanisms remain deferred … and
   the fourth, heartbeat eligibility … not a recovery path"); `spec/08` line 37; `spec/09` line 270;
   `DEFERRED.md`'s cross-cutting header.
4. **The migration claim is true.** `spec/08` line 374: the heartbeat adds "per entry, `heartbeatKey(v)`
   with its rotation block and `lastHeartbeatAt(v)`, `lastHeartbeatWindow(v)` and
   `lastHeartbeatSeq(v)` (packable into one slot with the timestamp) — **new staking-contract per-entry
   state only**, outside the frozen Inbox budget: no new global state is needed for the anchor check
   (`blockhash` is read at submission), **no Inbox, SignalService, Bridge or vault slot is touched, and no
   proof public input, journal field or config-hash preimage element is added**", with the bonding
   interface carrying the key and the runbook item at line 504. This matches the artifact diffs: `spec/05`
   is untouched by the increment (PRF-02's journal and the version-3 config preimage are unchanged),
   `spec/04`'s only change is one prose sentence in L1-07 ("the eligibility filter is not an Inbox rule …
   no proof statement, witness or Inbox storage shape changes"), and `spec/03`'s interface sketch carries
   `bond(amount, ed25519PubKey, heartbeatKey)` and `rotateHeartbeatKey` with the owner-only,
   forward-only, non-resetting rules. The per-entry state is coherent across MEM-03(1), MEM-07, MEM-13(1)
   and (2b), the 09 rows and the 08 budget; no rule reads a heartbeat record outside MEM-13.
5. **The assurance rows are accurate.** F5 (line 349) is resolved with the live rule — the withdrawn decay
   cannot shift a committed version's shares, and MEM-13 touches no committed weight; F6 (line 350) is
   closed — the liveness record is now the affirmative, owner-keyed `lastHeartbeatAt(v)`, written during a
   settlement stall, so the uniform-staleness problem does not arise and `lastObserved(v)` stays retired;
   F7 (line 351) is Open and sharpened — the `h_close` referent is missing, CONS-16 MUST NOT be
   implemented and `T_ROTATE`/`T_ROTATE_DELAY` stay withdrawn; F8 (line 352) is Open and sharpened —
   L1-heartbeat censorship excludes honest validators from future versions and can raise the adversary's
   share, it never breaks safety, and it leans on A-L1-1; the operational-lapse row (line 353) states the
   slot-not-stake cost, re-attestation, and the F9 residual. LIVE-05 (lines 308–328) and the halt table do
   not overpromise: a version already committed is not repaired, the rotation stays gated, the exit's
   proving-market dependency and its falsifier are named, and no production-time bound is claimed. The
   only gap is F9's second half (INC2-RD-02).
6. **D-17 is appended, not a rewrite**, and states exactly the lead's decision: MEM-13 live, CONS-16 not
   revived and gated on F7, the bounded pre-signing horizon, D-14/D-16 left as written.
   `DEFERRED.md` §2 is a revival record with the F7/F8/F9 dispositions and the CONS-16 revive criterion.
   `spec/06`, `spec/01` and the course are consistent: heartbeat eligibility is live but is a
   future-version selection filter, never a history-replacing path or a recovery route.

## Fault-model verdict and ship decision

Neither finding is inside the fault model: both are documentation-consistency defects with no rule
misread, no guarantee overstated, and no attacker action. **No Critical or High exists in this increment
from the register/index/disclosure angle, and the increment is safe to ship**; INC2-RD-01 and
INC2-RD-02 are one-line fixes that can land without a further design round.
