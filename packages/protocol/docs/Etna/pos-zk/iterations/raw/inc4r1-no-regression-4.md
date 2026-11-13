# Increment 04 — round 1: no-regression

Snapshot `169480a56`. Read: `increments/04-forced-inclusion-design.md`, `increments/04-coordination.md`,
`DECISIONS.md` D-12/D-16/D-18, `CONVERGENCE.md`, `DEFERRED.md`, `PLAN.md`, then every `spec/*.html`, all
14 `learn/*.html` pages, `09-parameters.html` and `index.html`. (The working tree has since moved to
`066ec452d`, which corrects the design delta's RC-4 and one line of `spec/05`; neither finding below is
affected — `spec/04` and `spec/09` are unchanged since the freeze.)

**Severity counts: 0 Critical, 1 High, 1 Medium, 0 Low. The increment is not clean as written; both
findings are one-sentence repairs at the seam between the revived obligation and the shipped design, and
after them the increment is safe to ship.**

---

## R4-NR-01 — High — FI-12(5)(ii) still asserts that `PARAM-04` commits `L2_BLOCK_GAS_LIMIT` through the `paramVersion = 2` preimage, the exact claim the owner decision declares "WRONG and must not be implemented".

*Rationale: the design delta, the coordination decision, the register's PARAM-04 row and the register's `L2_BLOCK_GAS_LIMIT` row all say the capacity relation reads the value from the anchored L1 view and that **no preimage changes**; the live rule that implements the relation still says the opposite. An implementer follows the specification page, so the two readings cannot both be implemented: one adds or extends a config-preimage field that the owner decision forbids and that the live V3 enumeration does not contain, the other reads the anchored view.*

- **File + rule id.** `spec/04-l1-integration.html`, **FI-12(5)(ii)** (line 734): "no rule registered here
  constrains the L2 gas-limit schedule, and **while the per-epoch configuration of `PARAM-04` commits
  `L2_BLOCK_GAS_LIMIT` through the `paramVersion = 2` preimage of PRF-02(5), that commitment only records
  the value**."
- **Assumptions.** None; the contradiction is textual.
- **Attack trace (drift trace, implementer consequence).** (1) An implementer reading FI-12(5)(ii) derives
  that the live capacity input is committed per epoch through the V2 preimage and either (a) reads the
  committed field, which the live V3 enumeration no longer contains, or (b) "restores" the field — a change
  to a live commitment, which `04-coordination.md` §3 forbids and which requires a new `paramVersion` and
  domain tag under PRF-02(5). (2) A prover/guest implementation following it folds a value the registry
  does not carry, so the `configHash` recomputation and the capacity test can disagree with the contract's;
  the rule that was supposed to prevent exactly this ("the rule must say so explicitly, and must say that
  no preimage changes") is the one place still saying otherwise. (3) The design delta's own ratified
  correction RC-4 records the claim as "wrong and MUST NOT be implemented" — so the artifact currently
  contains the correction and the uncorrected rule side by side.
- **Fault-model verdict.** No fault model needed; it is a live-rule contradiction with a fixed owner
  decision at the obligation/settlement seam.
- **Attacker cost.** None.
- **Requirement affected.** `04-coordination.md` §3 (owner decision); PRF-02(5)'s live V3 enumeration;
  PARAM-04's append-only commitment; `09`'s PARAM-04 and `L2_BLOCK_GAS_LIMIT` rows; FI-12's own
  consistency with FI-11/FI-12(4).
- **Evidence.** `spec/04-l1-integration.html` FI-12(5)(ii) (line 734). Against it:
  `spec/09-parameters.html` PARAM-04 row ("`L2_BLOCK_GAS_LIMIT` is live again as the FI capacity
  relation's registered input, but it is **not committed through any preimage** — the relation reads it
  from the anchored L1 view the proof already fixes, and no enumeration changes"); the register's
  `L2_BLOCK_GAS_LIMIT` row ("Live input again by increment 04, read from the anchored L1 view the proof
  already fixes: it is NOT committed through any config preimage and no preimage enumeration changes
  (04-coordination.md §3)"); `spec/05` PRF-02(5) (V2 is historical and "MUST NOT be used for a new epoch";
  V3 is the only live enumeration and does not contain the field); `increments/04-coordination.md` §3
  ("FI-12(5)(ii)'s claim ... is WRONG and must not be implemented"); and the design delta's ratified
  correction **RC-4** ("That is wrong and MUST NOT be implemented: V2 is historical ... Corrected: the
  capacity relation reads the value from the anchored L1 view"). Fix: replace the clause with the delta's
  RC-4 wording.

---

## R4-NR-02 — Medium — the register's PARAM-01 preamble still declares the forced-inclusion parameter names deferred and tombstoned with MUST-NOT-USE, contradicting the live rows on the same page.

*Rationale: the preamble is an instruction to implementers ("no rule, client, parameter or migration text may consume them"); it names `L2_BLOCK_GAS_LIMIT` and `FI_MAX_PER_BATCH` — both live rows on the same page — and it contradicts the page's own increment-04 notice. A reader who stops at the preamble concludes the revived parameters are tombstoned.*

- **File + rule id.** `spec/09-parameters.html`, **PARAM-01 preamble** (line 20): "The forced-inclusion names
  are deferred with the mechanism (D-16): `FI_INCLUSION_DELAY`, `FI_RECORD_GAS_MAX`,
  `FI_MAX_TX_PER_RECORD`, `FI_ANCHOR_MAX_AGE`, `L2_BLOCK_GAS_LIMIT`, `FI_MAX_PER_BATCH`,
  `FI_ITEM_MAX_BYTES`, `FI_PREFIX_CAP` and the capacity relations are **tombstoned below with a
  MUST-NOT-USE reason**, because the narrow forced-inclusion rule they served is deferred by D-16
  (`DEFERRED.md` §1); **no rule, client, parameter or migration text may consume them**, and they remain in
  the table only so the names cannot be reintroduced silently. *(decision D-16: the forced-inclusion
  parameter set is withdrawn with the deferred mechanism.)*"
- **Assumptions.** None.
- **Attack trace (drift trace, implementer consequence).** An implementer or reviewer reading the register
  from the top is told the FI names MUST NOT be consumed while FI-10–FI-14 are live rules that consume
  `FI_MAX_PER_BATCH`, `FI_MIN_DRAIN`, `FI_INCLUSION_DELAY`, `FI_RECORD_GAS_MAX`,
  `FI_MAX_TX_PER_RECORD`, `FI_ITEM_MAX_BYTES`, `FI_ANCHOR_MAX_AGE`, `L2_BLOCK_GAS_LIMIT` and the
  capacity relations. Register discipline (one name, one status, both directions) is broken on the page
  that owns it.
- **Fault-model verdict.** No fault model; register documentation contradiction.
- **Attacker cost.** None.
- **Requirement affected.** PARAM-01's register discipline; the increment-04 coordination decision on the
  deferral set; the both-directions register check.
- **Evidence.** The preamble text above; against it, the same page: line 96 ("the forced-inclusion set ...
  **are live again** as the registration of FI-10–FI-14, with the new `FI_MIN_DRAIN` and the four envelope
  relations ... increment 04"), line 271 ("increment 04 reinstates the forced-inclusion row, so three
  mechanisms remain deferred"), the live rows for `FI_MAX_PER_BATCH`, `FI_MIN_DRAIN`,
  `FI_ITEM_MAX_BYTES`, `FI_INCLUSION_DELAY`, `FI_RECORD_GAS_MAX`, `FI_MAX_TX_PER_RECORD`,
  `FI_ANCHOR_MAX_AGE`, `L2_BLOCK_GAS_LIMIT` and the FI relations row, with `FI_PREFIX_CAP` the only row
  left as a withdrawn spelling; and `index.html`'s parameter map, which lists the FI set as live again.
  Fix: replace the paragraph with the increment-04 status (the FI set is live; only the withdrawn spelling
  `FI_PREFIX_CAP` stays a name tombstone).

---

## Verified clean (the checks behind "no regression")

- **Mechanical checks.** 4,425 internal links/anchors across the 12 spec pages and 14 course pages:
  **0 broken**; all Markdown links resolve (including the new lesson, the delta and the coordination file);
  **tag balance 0 issues** across all **25** HTML files (the new course page included); the tombstone
  classifier over **161** rule divs now finds **8** tombstones — `CONS-16`, `L1-14`, `PRF-15`,
  `REC-02..REC-04`, `GOV-04` and the live rejected-alternatives rule `LIM-02` — with `FI-10..FI-14`
  correctly moved out; every tombstone keeps a MUST-NOT/withdrawal statement and a pointer; the token scan
  for the still-tombstoned names (`CONS-16`, `T_ROTATE`, `T_ROTATE_DELAY`, `GOV-04`, `REC-02..04`,
  `T_STALL_GOV`, `T_GOV_RESUME`, `govResume*`, `PRF-15`, `L1-14`, the aggregation set) finds only the
  19 known-benign historical/withdrawal sentences; the register orphan audit leaves only the two known
  classified rows (`POINT_EVALUATION_PRECOMPILE_GAS` value-only, `DRAIN_DEADLINE` table-consumed) and
  `FI_PREFIX_CAP` is read by no live rule; the index rule index has every id and marks every deferred rule
  (only the live `LIM-02` unmarked) and its parameter map lists the FI set as live with `FI_MIN_DRAIN`;
  the course has **0 review-process language** and no surviving "forced inclusion is deferred" claim (the
  one `learn/09` sentence states the opposite correctly: "a proof-enforced obligation over published data
  that is not a latency guarantee, no general inclusion list").
- **The two owner ratifications are implemented as ratified.** FI-12(2) reads "`R = min(d(A) − c,
  FI_MAX_PER_BATCH)` — the resolved count ... and `W` = the number of positions in `[c, c + R)` whose
  record is live at A — the work count", so a window holding a dead record is satisfiable; FI-11(2)(3)
  requires "`R ≥ 1` whenever the outstanding obligation at A is non-empty (because the capacity condition
  forces `cap(batch) = FI_MAX_PER_BATCH ≥ FI_MIN_DRAIN`, this is `R ≥ min(W, FI_MIN_DRAIN) ≥ 1` whenever a
  live record is outstanding)", with `1 ≤ FI_MIN_DRAIN ≤ FI_MAX_PER_BATCH` registered and the row reworded;
  FI-12(1)(i)/(ii) states the per-block bound explicitly.
- **The FI mechanics are as briefed.** The frontier advance is unconditional ("(a) `c' ≥ min(d(A), c +
  FI_MAX_PER_BATCH)` — unconditional; the exception of the preserved text is deleted and MUST NOT reappear
  in any form"), with the upper bound, the `[c, c')` walk and `ForcedRecordMissing`; FI-13's three modes
  (executed / void / dead) resolve every position, with dead derived from the stored `l1BlockNumber` and
  the registered deadline and no mutable status; FI-13(2) states the predicate has no other input and
  explicitly excludes "the including block's base fee, its gas limit, its remaining gas, and the producer's
  ordering", leaving the record's immutable bytes, registered constants and two producer-immovable state
  facts (nonce, free balance); pruning is deletion-only behind a stored cursor, returns no frontier and is
  never read by `land`; enforcement is in the proof (PRF-04(vi), `spec/05`) with L1-04's no-gate property
  preserved; there is **no new slashable offence** (ECON-04(6) and ECON-13(4) stay tombstones — "the
  obligation is live and creates no offence" — and no bounty is payable for it).
- **No FI state is read by the exit paths.** `L1-13`, `MSG-03`, `MSG-04` (the veto) and `MEM-15` each
  contain **zero** FI/forced references; the settlement pair `(settledCount, anchoredL1Block)` rides the
  per-height L1-07 checkpoint record with no per-height mapping, and `MIG-02`'s budget is unchanged
  ("15 of the 43 sourced gap slots ... are consumed and 28 remain").
- **The deferral set is three with the stated membership** everywhere checked: `DEFERRED.md` ("**Three
  deferred items remain** ... the heartbeat rotation (`CONS-16`), the governance stall resolution and
  aggregation"), `index.html` ("three mechanisms remain deferred — the heartbeat's rotation ... the
  governance stall resolution and aggregation"), `spec/10` and `spec/09` line 271.
- **F-FI-2 is disclosed wherever the guarantee is summarised**, in the ratified terms: "exclusion per unit
  of the censor's L1 spending", "conditional on at least one honest or rational batch producer and on L1
  including the user's publication", "**not a latency guarantee**" (`learn/09` line 133, the new
  `learn/11` line 164, `spec/index` and `spec/10` line 353).
- **Scope and no regression.** The increment-4 span is 29 files / 1,155+/489−, confined to the pages the
  revival must reach (spec 01, 02, 04, 05, 06, 07, 08, 09, 10, index; the course's new lesson and the
  pages that promised "no inclusion obligation"); `spec/03` was not touched, the rule-id set is unchanged
  (161), and the increment-2 heartbeat rules and the converged v1 rules keep their semantics — the only
  remaining cross-reads are the two findings above. The three interface questions are genuinely left open
  (`forcedSettlementAt(uint64)` and `prunePublications(uint32)` are in the L1-08 sketch with
  `forcedSettlementAt` as the settlement read, `pruneCursor` has no view, and view-freshness maps to the
  single `ForcedViewStale`), recorded in `04-coordination.md` §4d for this round.

## Fault-model verdict

No finding needs a fault model or an adversary: R4-NR-01 is a live rule asserting a commitment the owner
decision forbids, and R4-NR-02 is a register preamble contradicting its own rows. Both are documentation
repairs at the obligation/settlement seam; neither weakens the obligation's arithmetic or the proof-side
enforcement.

## Is the increment safe to ship?

**Not as written** — fix R4-NR-01 (one clause, the delta's RC-4 wording) and R4-NR-02 (one paragraph)
first. Both stand at the current working tree (`spec/04` and `spec/09` are unchanged since the freeze).
After those two edits the increment is safe to ship: everything else I checked is consistent, and the
mechanical surface is clean.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 1 | R4-NR-01 |
| Medium | 1 | R4-NR-02 |
| Low | 0 | — |
