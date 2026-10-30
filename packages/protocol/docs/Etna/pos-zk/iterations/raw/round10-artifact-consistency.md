# Round 10 — angle: the whole artifact after the residue (confirmation)

Snapshot `cd8386c2c`. Read: `iterations/10-freeze.md`, `DEFERRED.md`, all four `iterations/raw/round9-*.md`,
then every `spec/*.html` (12 pages), `learn/*.html` (13 pages), the register in `09-parameters.html`,
`index.html` and the top-level `*.md`.

**Severity counts: 0 Critical, 0 High, 0 Medium, 0 Low. I found nothing. Round 10 is clean, and the round-9
residue introduced no new defect.**

Every check was mechanical, not a reading pass: an artifact-wide link/anchor resolver, a stack-based
tag-balance parser for all 24 HTML files, a tombstone classifier over all 161 rule divs, a sentence-level scan
of every tombstoned rule/parameter/record name inside live rules and page prose across spec and course, a
register orphan audit in both directions, an index rule-index and parameter-map diff, and a course vocabulary
scan. The only hits are the same benign ones round 9 judged, listed at the end so this report is auditable.

---

## Mechanical checks (results)

| Check | Result |
|---|---|
| Internal links/anchors (HTML) | **3,751 links, 0 broken** — 0 missing files, 0 missing fragments |
| Markdown links (whole artifact) | **0 broken** (round-9 R9-AC-02's three research links are fixed) |
| Tag balance (all 24 HTML files) | **0 issues** (round-9 R9-AC-01's stray `</p>` in `spec/08` is fixed) |
| Tombstone classifier (161 rule divs) | 18 classified; all carry MUST-NOT or explicit withdrawal language; all carry a DEFERRED.md / D-16 / history pointer |
| Live references to tombstoned names (spec + 13 course pages) | 24 hits, **all benign** (see below); no live rule consumes a tombstoned name |
| Register orphan audit, both directions | No live rule reads a withdrawn row; the only rows without a live-rule consumer are explicitly classified (see below) |
| Index rule index | All 161 ids indexed; every deferred rule's row marked "DEFERRED by D-16 (tombstone)" |
| Index parameter map | Matches the register; `FREEZE_MAX` present; every withdrawn set marked |
| Course vocabulary scan (13 pages) | 3 hits, all benign; no deferred mechanism taught in the present tense |

**The 24 benign token hits**, each re-examined on this snapshot: `MEM-13` inside `MEM-12`/`LIVE-05`/`LIM-01` where the rule cites the tombstone's *v1 disclosure* ("MEM-13 states this, and the stake/exit asymmetry, in one place" — and the MEM-13 tombstone does state it); `PRF-02`'s historical V2 field list ("was version 1's field list with exactly one field added"); `09`'s historical descriptions inside withdrawn rows (`T_STALL`, `GOV-04`); `MIG-02`'s `pruneCursor` slot-arithmetic sentence; the index `T_ROTATE` map entry that immediately marks both names withdrawn; `LIM-03`'s historical change log; `learn/05` ("aggregation ... is not part of v1") and `learn/limitations`'s coverage list naming `FI-REMOVED-01`.

**Register rows without a rule-div consumer** (both directions still pass because each is classified): `value_at_risk(D_MAX)` — "a disclosure-only exposure statistic"; `PUB_RECORD_RETENTION` — "Retained-but-unused state in v1 ... no live rule reads this parameter"; `POINT_EVALUATION_PRECOMPILE_GAS` — "consumed by value only", naming DA-03(ii)/PRF-07(b)(iii); `MIN_STAKE` — deprecated in favour of `S_min`, which the row now carries; `REWARD_ASSET`, `DRAIN_DEADLINE`, `C_PUBLISH` — consumed by the parameter tables of `07`/`08`. The one deferred rule whose index row is not literally marked is `LIM-02`, a live rejected-alternatives rule whose row legitimately contains "withdrawn or deferred" dispositions.

---

## Round-9 residue verified present (no regressions)

- **Bounded, resumable freeze cascade.** `spec/07` ECON-02(5)(d) lines 231–236: "The cascade is bounded and resumable ... MUST freeze at most `FREEZE_MAX` epochs in one call"; line 250: a backlog of `p` drains in `ceil(p / FREEZE_MAX)` permissionless calls, "each bounded and callable by any address"; line 180: "a claim whose epoch lies beyond the call's bounded prefix MUST revert with no effect"; line 245: an inflow credit "freezes the whole pending set when that set holds at most `FREEZE_MAX` epochs, and otherwise the authenticated message MUST revert and stay retriable under MSG-02's per-message status model" (`MSG-02` defines the `RETRIABLE` status, so the reference is sound); line 250 applies L1-04's loop discipline; line 266 shows the close-time-amount property survives. `spec/09` line 139 registers **`FREEZE_MAX ≥ 1`**, owner ECON-02(5)(d), unmeasured with its measurement named in PARAM-03, and "a call MUST NOT freeze an epoch out of order or skip one"; line 131 and `spec/index.html` line 553 repeat the bound; the index parameter map and the rule index both contain `FREEZE_MAX`.
- **CONS-02 store prohibition restored.** `spec/02` CONS-02: "The store MUST NOT be cleared, truncated, rewritten or restarted from empty by any rule — a restart, a resync or a revived stall resolution included ... were it revived it would not be an exception, because a resolution's scoping change only disregards superseded-generation entries for new signing and never erases the record."
- **CONS-05's tuple carries the generation.** `spec/02` CONS-05: "C = (chain_id, epoch, **recovery_generation**, H, R, B, set_root(epoch), signers, signatures) — the tuple of the encoding table"; the encoding table's `CommitCertificate` row carries `recovery_generation:u64`, and CONS-10(1)/(7) + CONS-08 agree.
- **spec/08 markup and sentence.** 0 tag issues; the previously truncated sentence now reads "...the capped rule needs only head, tail, count and the next position; and pruning after `PUB_RECORD_RETENTION` would be a permissionless advance of `pruneCursor`, but v1 has no prune entry point ...". Round-9 R9-AC-03 is also fixed: the slot clauses now say "the **withdrawn** capped FIFO prefix **would have** drained (D-16; no v1 rule drains it)" and "the FIFO head the withdrawn capped prefix would have drained from".
- **Exit dependency stated as funding AND retrievable inputs.** `spec/03` MEM-15(2b); `spec/04` MSG-03 lines 769 and 774 ("the stall statement names both dependencies of MEM-15(2b), funding and retrievable inputs"); `spec/index.html` STATUS-08 and the index rows at lines 54, 294, 431, 444, 513, 529; the front-running race is disclosed at `spec/04` line 456 and `spec/07` line 282 in the same form as the landing race.
- **All round-9 findings closed:** R9-CC-01 (tuple), R9-CC-02 (store), R9-CC-03 (cohort-return escape in the index row and `learn/08` line 136), R9-EBA F1 (FREEZE_MAX), F2 (both dependencies), F3 (front-running), R9-AC-01 (markup), R9-AC-02 (links), R9-AC-03 (MIG-02 purpose clauses).
- **No regression elsewhere:** 161 rule ids unchanged; the four deferred mechanisms remain tombstoned with MUST-NOT-USE reasons and DEFERRED.md pointers; no disclosure promises a guarantee v1 does not provide (no inclusion obligation, no recovery path of any kind, single-backend settlement soundness are stated consistently in spec, register, index and course).

## Fault-model verdict

No finding, so no fault-model question arises. Nothing in the artifact is exploitable by the changes reviewed, and no live rule reads a tombstoned rule, parameter or record.

## Would I build on this specification?

**Yes.** The artifact is internally consistent end to end on this snapshot: links, anchors and tags are clean; tombstones and the register agree in both directions; the index mirrors both; the course teaches the v1 design including the exit, its funded proving market and its retrievable-input dependency; and the round-9 residue is real, complete and regression-free. I found nothing to report.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 0 | — |
