# Increment 02 — re-review: no regression

Snapshot `7a995f179`. Read: `iterations/raw/inc2-*.md` (all four round-1 reports), `spec/03` MEM-13 in
full, `increments/02-heartbeat-design.md`, `CONVERGENCE.md`, `DEFERRED.md`, `DECISIONS.md` D-17, then
every `spec/*.html` (12 pages), `learn/*.html` (13 pages), `09-parameters.html` and `index.html`.

**Severity counts: 0 Critical, 0 High, 0 Medium, 0 Low. I found nothing. The increment is CLEAN and
safe to ship.**

Every mechanical check that made v1 clean still passes, every round-1 finding is closed in the text,
the L1 block-height grid is propagated consistently through the specification, register, index and
course with no surviving pre-grid reading, no live rule reads `T_ROTATE`, `T_ROTATE_DELAY` or any
other tombstoned name, and the increment touched only the pages it had to.

---

## Mechanical checks (results)

| Check | Result |
|---|---|
| Links/anchors (spec + course, HTML) | **3,956 links, 0 broken** (files and fragments) |
| Markdown links (whole artifact incl. `increments/`) | **0 broken** |
| Tag balance (all 24 HTML files) | **0 issues** |
| Tombstone classifier (161 rule divs) | **17 tombstones**, unchanged set (`CONS-16`, `L1-14`, `FI-10..FI-14`, `FI-REMOVED-01`, `FI-PLANNED-01`, `PRF-15`, `REC-02..REC-04`, `ECON-13`, `GOV-04`, `LIVE-04`, `LIM-02`); `MEM-13` correctly live; all carry MUST-NOT/withdrawal language and a DEFERRED.md/D-16/history pointer |
| Live references to tombstoned names (spec + course) | 21 hits, **all benign** (historical `PRF-02` V1/V2 field list, MIG-02 `pruneCursor` slot arithmetic, `09`'s withdrawn `T_STALL`/`GOV-04` rows, `T_ROTATE`/`T_ROTATE_DELAY` in the index row/parameter map saying they stay withdrawn, `LIM-03`'s historical change log, `learn/limitations`'s coverage list) |
| Register orphan audit, both directions | 94 rows; the only rows without a rule-div consumer stay the five previously classified ones (`POINT_EVALUATION_PRECOMPILE_GAS`, `MIN_STAKE`→`S_min`, `REWARD_ASSET`, `DRAIN_DEADLINE`, `C_PUBLISH`); the two marked orphans unchanged (`value_at_risk(D_MAX)` disclosure-only, `PUB_RECORD_RETENTION` retained-but-unused); all **13** heartbeat names registered and consumed by live rules; `FREEZE_MAX` still registered and live-referenced |
| Heartbeat register units | `HEARTBEAT_WINDOW` = "L1 blocks"; `lastHeartbeatAt(v)` = "L1 block number"; `HEARTBEAT_ANCHOR_AGE` = "L1 blocks"; `HEARTBEAT_MIN_INTERVAL` explicitly "non-normative ... stays in wall-clock seconds ... no rule reads it" |
| Index rule index + parameter map | All 161 ids indexed; every deferred rule marked; `MEM-13` row reads "LIVE (revived by increment 02)" and describes the window, the anchor and the fixed evaluation window; `CONS-16` row stays a gated tombstone with `T_ROTATE`/`T_ROTATE_DELAY` "stay tombstoned with MUST-NOT-USE reasons in 09"; parameter-map row 12 states the heartbeat set is live on L1 block counts, the evaluation instant is derived with "no writer, keeper or oracle ... reads no past block's timestamp", and the rotation names remain withdrawn. Only `LIM-02` (a live rejected-alternatives rule) is unmarked |
| Course scan | Deferred-mechanism vocabulary: 2 benign hits (both `learn/05`: "the n-of-m aggregation ... is not part of v1"). **Review-process language: 0 hits** (round-1 R-INC2-03 closed). **No pre-grid reading survives**: `learn/glossary` ("a fixed number of L1 blocks ... the contract records the window's start L1 block, never the time the carrying transaction ..."), `learn/04` ("a window measured in L1 blocks rather than in seconds ... its spacing in real time moves with L1 block time and is unmeasured"), `learn/07` the same; no course sentence reads a heartbeat window or record as a timestamp |
| Scope of the increment | `git diff cea431c37..HEAD`: 20 files, 2,255+/273−; spec pages touched are `02`, `03`, `08`, `09`, `10`, `index`; course pages `03`, `04`, `07`, `08`, `10`, `glossary`, `limitations`; `increments/02` and `CONVERGENCE.md`; `spec/01`, `04`, `05`, `06`, `07` and `learn/01`, `02`, `05`, `06`, `09` untouched. `learn/03`'s three-line change is exactly the removal of the review-process sentences. No rule id added or removed (161) |

## Round-1 findings verified closed

- **F1 — caller-chosen commit instant.** Closed, and closed structurally: MEM-13(3) now derives the instant inside the evaluating call — `C(e) = max(e − LOOKAHEAD_EPOCHS, e_0)`, `L1_first(C(e)) = L1_0 + (C(e) − e_0) · EPOCH_LEN_L1`, `w*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW)`, `I*(e) = w*(e) · HEARTBEAT_WINDOW` — from the activation record, the target epoch and the parameter value in force, explicitly "no per-epoch record, no writer, no keeper, no oracle and no past-block read ... no transaction can write the value, and the mechanism adds no storage at all", and "caller-independent by construction: two calls in one block compute the same instant". The predicate is `lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW`, and the append's block, timestamp and position cannot compose the roster.
- **F2 — genesis roster.** Closed: CONS-14(1) states the activation entry's roster is "the active bonded set at that block, **unfiltered by MEM-13**", with the reason (no heartbeat can exist before the path does, so the predicate would leave `n = 0`), and MEM-13(3) states the predicate applies from the entry for `e_0 + 1` onward.
- **F3 — stale register rows in `spec/03`.** Closed: the heartbeat rows now say the heartbeat set is revived and the rotation tombstones stay withdrawn; the parameter table states "the heartbeat set and `HEARTBEAT_ANCHOR_AGE` are revived or added; the decay tombstones ... and the rotation tombstones (`T_ROTATE`, `T_ROTATE_DELAY`) stay withdrawn".
- **F4 — design delta "NOT APPLIED".** Closed: `increments/02-heartbeat-design.md` now reads "**Status: APPLIED — increment 02 was implemented in commits `e135656f4`, `75b960652` and `cea431c37`** ... **CONS-16** was **not** revived ... the CONS-16 rule text in §3 below is the gated proposal, not the shipped rule", and its grid section is aligned with the shipped rule.
- **F5 — boundary-halt wording.** Closed: MEM-09 states the empty-roster revert ("if no active entry is eligible the call MUST revert and MUST NOT append an empty or otherwise invalid version ... the append obligation is restored by a later successful call under the lowest-missing rule ... and MEM-09(5)'s boundary halt becomes reachable until then"), and MEM-13(3)/(7)(e) state the same in the same terms.
- **R-INCR2-01 — window change / re-labelling / incumbents.** Closed: the "never re-labels a window that has begun" promise is explicitly withdrawn and replaced by absolute-instant semantics; (2a)(d) compares block heights, never indices; `lastHeartbeatWindow(v)` is declared grid-relative and "MUST NOT be compared across grids"; clause (6) states the consequences for existing entries in both directions ("no change can make an incumbent unable to advance its record, can lower a recorded instant, or can empty the eligible roster by itself") and carries the **new Open "Change timing against an instant in flight"** with its falsifier ("such a change, at such a block, excluding such an entry from such a version") and what would close it (a registered delay or a per-epoch frozen grid, neither registered).
- **R-INCR2-02 — zero/unusable key.** Closed: `heartbeatKey(v)` "MUST be non-zero", `address(0)` rejected at bonding and rotation, with the reason that `ecrecover` returns `address(0)` for any unrecoverable signature, so the zero key would be a wildcard; the acceptance check (a) relies on the stored key being non-zero.
- **R-INCR2-03 — entry identifier uniqueness.** Closed: MEM-03(1)'s bonding address "carries at most one live entry, so `v` names exactly one entry".
- **R-INCR2-04 — key re-binding after retirement.** Closed: "retirement is permanent — a key that has ever been retired MUST NOT be re-bound to any entry, including the entry it was retired from", and a rejected rotation leaves the stored key, its rotation block and every heartbeat record untouched.
- **INC2-RD-01 — `CONVERGENCE.md`.** Closed: an "**Increment note (added after convergence)**" states that the record describes v1 as it converged in rounds 9–10, that increment 2 revived MEM-13 and did not revive CONS-16, and that "**three mechanisms remain deferred**".
- **INC2-RD-02 — F9's second consequence.** Closed: the all-ineligible append window is carried with the falsifier in `spec/02` (line 541), `spec/03` (clauses (6) and (7), and the MEM-12 row), and `spec/10` (lines 36, 321, 349): "commitSet() reverts, the append is missed and the MEM-09(5) boundary halt is reachable (MEM-13(3)/(7)(e)), a liveness failure v1 does not repair".
- **R-INC2-03 (mine) — course review-process language.** Closed: zero hits artifact-wide; `learn/03` now reads "The vote and the certificate both carry the recovery generation, matching the specification's encoding table."

## No regression in the converged artifact

- **Heartbeat rule is internally consistent.** The payload, acceptance, record, eligibility and sizing clauses agree on the unit (L1 blocks): acceptance names the carrying block's window, the record is the window's start block, the eligibility instant is derived from the activation record, and the register/index/course carry the same. The window-change semantics are stated for both directions with the residual as an Open, and F8 (carried, sharpened), F9 (new, including its second consequence) and the declared non-fix (presence is not participation) are all present and repeated in the assurance page, the consensus page's M7 row, the index row and the course.
- **CONS-16 stays gated and unread.** MEM-13's clauses (5) and (6) explicitly state the rotation "remains deferred by D-16 and tombstoned — its closing height has no L1 referent and it MUST NOT be implemented — so no rule of this page reads it"; the register rows for `T_ROTATE` and `T_ROTATE_DELAY` are withdrawn with MUST-NOT-USE reasons; no live rule reads either name.
- **The v1 baseline is otherwise untouched.** The re-review diff is confined to the pages the grid change must reach (spec 02/03/08/09/10/index, course 03/04/07/08/10/glossary/limitations, the increment delta and the convergence note); no v1 rule text changed semantics, no rule id changed, and the tombstone set, register shape, index structure and course structure are identical to the converged artifact.
- **Scope note (not a finding).** The window also adds `increments/04-forced-inclusion-design.md`, a design delta for a *future* increment, correctly marked "Status: design delta, NOT APPLIED", with no specification, register, index or course change following from it; its links resolve and it claims no normative status. `increments/02`'s own "APPLIED" status correctly distinguishes it from `increments/04`.

## Fault-model verdict

No finding, so no fault model is implicated. The increment adds no exploitable path that the round-1 reviews did not already test, and the artifact-wide mechanical consistency of the converged v1 is intact.

## Is the increment safe to ship?

**Yes.** I found nothing: the round-1 findings are closed in the text, the block-height grid is propagated without a pre-grid residue, the register/index/course move with the rule, and links, anchors and tags are clean. Round 2 is clean on this angle.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 0 | — |
