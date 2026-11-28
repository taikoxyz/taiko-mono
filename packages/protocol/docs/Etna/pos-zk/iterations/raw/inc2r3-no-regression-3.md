# Increment 02 — round 3: no-regression (confirmation)

Snapshot `bb06395d3`. Read: `iterations/raw/inc2r2-*.md` (all four round-2 reports), `spec/03` MEM-13 in
full, `spec/02` CONS-13/CONS-14, `spec/08` MIG-03, `spec/09`, `spec/01` ROLE-01, `DEFERRED.md` §2,
`DECISIONS.md` D-17, `increments/02-heartbeat-design.md`, then every `spec/*.html` and `learn/*.html`.

**Severity counts: 0 Critical, 0 High, 0 Medium, 0 Low. I found nothing. The round-2 repairs are real,
they introduced no new defect, and the increment is CLEAN and safe to ship (two consecutive clean
rounds).**

---

## Round-3 repairs verified

- **The predicate carries the non-zero-sequence guard (R2-DI-01).** `spec/03` MEM-13(3): "Entry v is
  eligible for set version k ... **if and only if `lastHeartbeatSeq(v) > 0` and `lastHeartbeatAt(v) ≥
  I*(e) − HEARTBEAT_WINDOW`**", with the explanation "An entry with no accepted heartbeat is ineligible
  regardless of the arithmetic: `lastHeartbeatSeq(v) = 0` fails the guard even though
  `lastHeartbeatAt(v) = 0` would satisfy the inequality whenever `I*(e) ≤ HEARTBEAT_WINDOW`, so a
  never-attested entry cannot enter a roster on a low-height L1". The predicate's guard and (2a)(d)'s
  guard are now the same condition.
- **The genesis capture is closed (INC2R2 F1).** MEM-13(3) carries a "Launch transition": for the two
  clamped epochs `e = e_0 + 1` and `e = e_0 + 2`, `w*(e) = floor(L1_first(e_0) / HEARTBEAT_WINDOW) + 1`
  and `I*(e) = (floor(L1_first(e_0) / HEARTBEAT_WINDOW) + 1) · HEARTBEAT_WINDOW`, and "the entries for
  `e_0 + 1` and `e_0 + 2` MUST NOT be appended before the shifted instant `I*(e_0 + 1)`, so the window
  containing `L_0` ... is a full attestation window that closes before any filtered roster can be
  fixed"; the shift is confined to the clamped epochs ("from `e_0 + 3` the clamp advances and the
  unshifted definition resumes", and the stated `HEARTBEAT_WINDOW ≥ EPOCH_LEN_L1` relation shows the
  shift can never make a later version stricter). CONS-14(1) carries the normative launch duty and the
  same shifted instant for `e_0 + 1`; `spec/09`'s `HEARTBEAT_WINDOW` row repeats the shift and the
  append prohibition ("the register row carries the launch-transition shift for the two clamped epochs");
  `spec/08` MIG-03's T3 announcement carries the operational form ("Every entry that is to be
  selectable for the first filtered set version MUST have an accepted heartbeat naming the heartbeat
  window containing `L1_0` before the first `commitSet()` that appends a filtered version ... no filtered
  roster can be composed by being first to attest or first to append").
- **MEM-13(3)'s false "in the future when appended" is replaced by the invariant (INC2R2 F2).** The text
  now reads "`L1_first(C(e))` ... **at or before every block in which the append may be made** — a late or
  refilled lowest-missing append only moves it further into the past, which broadens eligibility and
  excludes no one — so it is computed from L1 state by arithmetic and never read from a past block", with
  the note that this replaces the false claim. The phrase no longer occurs anywhere.
- **CONS-14(1)'s genesis justification is the policy one (INC2R2 F3).** "The exemption is a policy
  choice, **not a claim that the records are unset**: the staking contract reports a non-zero epoch-0 set
  root and carries the heartbeat key path before activation (08, T3), and no rule of this page disables
  heartbeat acceptance before T3, so pre-activation acceptance is neither required nor relied upon. The
  reason is the policy one: no heartbeat can be required of an entry whose key path and window schedule
  are not yet established when the roster is fixed ... and applying the eligibility predicate to the
  entry for `e_0` would leave `n = 0` — an invalid activation under clause (4)."
- **The change-timing Open is sized and its caller influence named (R2-DI-02).** MEM-13(6) now states the
  affected set as "not one version: every version evaluated before the entry re-attests whose evaluation
  instant falls in `(A + W', A + W_old]` ... a backlog drained in a single block loses a **contiguous
  run** of versions, about `(W_old − W') / EPOCH_LEN_L1` of them", and names the residual caller
  influence ("while a change is pending, an append caller's ordering relative to it selects whether the
  version is evaluated under `W_old` or `W_new`; this is binary, it is bounded to the pending change, it
  cannot name an arbitrary instant"). Clause (3) states the same exception ("the one bounded exception is
  an append ordered against a pending change ... the sole remaining caller influence on `I*(e)`").
- **The withdrawn caller-dependent reading is gone (INC2R2 UD-01/UD-02).** `spec/01` ROLE-01 now states
  the per-window cadence against the derived instant `I*(e)` ("the start of the L1 heartbeat window in
  which the epoch's coverable start falls, computed inside `commitSet()` from the activation record");
  `spec/08` MIG-03's T3 runbook says the instant is "derived from the L1 block at which the epoch's
  coverable start falls ... **not from the version's commit point**"; `DEFERRED.md` §2 and `DECISIONS.md`
  D-17 each carry a **reviewed addendum** that preserves the historical paragraph, withdraws the
  `t_root(e)`/commit-point wording, records the shipped predicate (including the sequence guard), the
  block-height grid and the `MEM-13(6)` Open with the height-grid cost — the append-only discipline is
  respected (the addendum corrects, it does not silently edit).

## Mechanical checks (results)

| Check | Result |
|---|---|
| Links/anchors (spec + course, HTML) | **3,981 links, 0 broken** files or fragments |
| Markdown links (whole artifact) | **0 broken** |
| Tag balance (all 24 HTML files) | **0 issues** |
| Tombstone classifier (161 rule divs) | **17 tombstones**, unchanged set; `MEM-13` live; all carry MUST-NOT/withdrawal language and a pointer (`FI-PLANNED-01` is the planned-update clause and correctly carries none) |
| Live references to tombstoned names (spec + course) | **21 hits, all benign** — identical to round 2: historical `PRF-02` V1/V2 field list, MIG-02 `pruneCursor` slot arithmetic, `09`'s withdrawn `GOV-04`/`T_STALL_GOV` rows, `T_ROTATE`/`T_ROTATE_DELAY` in the index row/map (marked withdrawn), `LIM-03`'s change log, `learn/limitations`'s coverage list |
| Register orphan audit, both directions | 94 rows; the only rows without a rule-div consumer remain the five previously classified ones; the two marked orphans unchanged; all **13** heartbeat names registered and consumed by live rules |
| Index rule index + parameter map | All 161 ids indexed; every deferred rule marked (only the live `LIM-02` unmarked); `MEM-13` row LIVE with the derived instant; `CONS-16` row a gated tombstone; the heartbeat map row states the block-height grid, the derived instant ("no writer, keeper or oracle ... reads no past block's timestamp") and that `T_ROTATE`/`T_ROTATE_DELAY` remain withdrawn |
| Course scan | Deferred-mechanism vocabulary: 2 benign hits (both `learn/05`: "the n-of-m aggregation ... is not part of v1"). **Review-process language: 0 hits.** **No surviving pre-repair reading**: the only "commit point" sentences near heartbeat/eligibility say the instant is *not* the commit point (`spec/08`), restate the withdrawal (`spec/01`, `spec/02`), or correctly say the roster is drawn from entries active and eligible *at the commit call* (`spec/02` line 441, `learn/glossary` lines 148/158); "in the future when appended" and "restored by re-attesting at a later commit point" no longer occur anywhere |
| Scope since round 2 | `git diff 7a995f179..HEAD`: 14 files, 651+/37−; spec pages touched are `01`, `02`, `03`, `08`, `09`, `10`, `index` (2–10 lines each), plus `DEFERRED.md`/`DECISIONS.md` one-line addenda, the increment delta and the round-2 reports. **No v1 rule changed semantics, no rule id added or removed (161), and no course page needed a change.** |

## No regression since round 2

The artifact is identical to the round-2 clean state wherever the repairs did not have to reach:
the tombstone set, register shape, index structure, rule-id set and course content are unchanged; the
grid, guard and launch-transition edits are confined to the owner rule (MEM-13), its two consumers
(CONS-14, MIG-03), the descriptions that restated the predicate (ROLE-01, 09, index, assurance) and the
register/decision addenda. CONS-16 remains a tombstone and `T_ROTATE`/`T_ROTATE_DELAY` remain
withdrawn and unread by any live rule.

## Fault-model verdict

No finding, so no fault model is implicated. The guard, the shift and the invariant close the round-2
admission/ordering defects without adding an exploitable path.

## Is the increment safe to ship?

**Yes.** The three round-3 repairs are real and correctly propagated, all round-2 findings are closed in
the text (including the two Mediums), the mechanical checks are clean, and nothing regressed. This is the
second consecutive clean round on this angle.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 0 | — |
