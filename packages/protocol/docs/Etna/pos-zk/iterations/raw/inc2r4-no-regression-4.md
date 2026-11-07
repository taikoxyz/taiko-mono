# Increment 02 — round 4: no-regression (confirmation)

Snapshot `18621d858`. Read: `iterations/raw/inc2r3-*.md` (all four round-3 reports), `spec/03` MEM-13 and
MEM-09, `spec/02` CONS-13/CONS-14, `spec/09`, `spec/01` ROLE-01, `spec/10`, `index.html`,
`DEFERRED.md`, `DECISIONS.md` D-17, `increments/02-heartbeat-design.md`, then every `spec/*.html` and
`learn/*.html`.

**Severity counts: 0 Critical, 0 High, 0 Medium, 0 Low. I found nothing. The two-window launch fix is
real, it closes the capture in every launch order, it introduced no new defect, and the increment is
CLEAN and safe to ship.**

---

## The launch fix, verified against every launch order

The shipped rule (MEM-13(3), repeated in `09`, `index`, `01`, `10`, `DEFERRED.md`, D-17 and the
design delta): with `q = floor(L1_0 / HEARTBEAT_WINDOW)`, the two clamped epochs `e = e_0 + 1` and
`e = e_0 + 2` get `w*(e) = q + 2` and `I*(e) = (q + 2) · HEARTBEAT_WINDOW`; the predicate is
`lastHeartbeatSeq(v) > 0 **and** lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW`, so the counting window
is `[(q+1)W, (q+2)W)`; and "the entries for `e_0 + 1` and `e_0 + 2` MUST NOT be appended before that
counting window closes — that is, before the shifted instant `I*(e_0 + 1)`".

- **Every position of `L1_0` in its window.** `L1_0 ∈ [qW, (q+1)W)`, so `(q+1)W > L1_0` strictly in
  every case (equality would contradict `q = floor(L1_0/W)`): the counting window begins after the
  activation block, and it runs a full `W` blocks to `(q+2)W`. The activation window `[qW, (q+1)W)`
  can be arbitrarily short after `L1_0`; the counting window cannot. That is exactly the property
  `R3-LT-01` asked for, and it holds for any position of `T3` in its window, including the last block.
- **No ordering advantage.** The gate is a condition on the call ("a call that would append before the
  shifted instant MUST revert rather than append — a condition on the call, not on any entry: it applies
  to every appender alike and names no entry and no caller, so it cannot be opened early and cannot be
  aimed at a validator", MEM-09(1)). Attestations in the counting window are all in before any filtered
  append can be made, so being first to attest or first to call composes nothing.
- **Coverage.** A heartbeat accepted in the counting window records `lastHeartbeatAt(v) = (q+1)W`, which
  satisfies the predicate with equality; an entry with no accepted heartbeat fails the sequence guard
  regardless. The shift is transitional only (from `e_0 + 3` the unshifted definition resumes), is
  derived in-call like the unshifted value, and never makes a later version stricter:
  `I*(e_0+3) = floor((L1_0 + EPOCH_LEN_L1)/W)·W ≤ (q+2)W` under the registered
  `HEARTBEAT_WINDOW > EPOCH_LEN_L1`, so a later threshold is at or below the launch threshold.
- **Cost, stated rather than inferred.** MEM-13(3): "the first two filtered appends are gated by up to
  two `HEARTBEAT_WINDOW`s rather than one, and the missing-entry halt of CONS-13(5) ... is up to one
  full window longer; because the register bounds `HEARTBEAT_WINDOW` only from below, that added
  window's wall-clock length is bounded by no rule." CONS-14(3) re-bases the first-boundary deadline to
  the launch-transition opening and states the same cost; `10` repeats it ("up to two windows in L1
  blocks, and unbounded in wall clock"); `08`'s T3 announcement carries the operator duty.
- **Considered and dismissed (not a finding): the append-deadline wording.** MEM-09(1) states the
  general obligation "the entry for the next uncovered epoch MUST be appended no later than one
  `EPOCH_LEN_L1` after it becomes coverable — in steady state", which for the two clamped epochs is
  arithmetically earlier than the gate `(q+2)W > L1_0 + W > L1_0 + EPOCH_LEN_L1`. This is not a
  contradiction on the artifact: (i) CONS-14(3) is the launch-specific rule and says the entries for
  epochs 1 and 2 "MUST be committed **as early as the launch-transition opening** of MEM-13(3) permits",
  explicitly recording that "the first-boundary deadline is **re-based to the launch-transition
  opening**"; (ii) MEM-09(1)'s own eligibility paragraph cross-references the same shift and the
  revert-not-append gate; (iii) the obligation has no enforcement and its consequence (the boundary halt)
  is the disclosed cost. Reported here only so the reasoning is on the record.

## Round-3 findings verified closed

- **R3-LT-01 (Medium) — the counting window depended on `L1_0`'s position in its window.** Closed by the
  two-window shift: the counting window now starts at the first grid boundary after `L1_0` and has full
  length `W`; the register row, index, `01`, `10`, `DEFERRED.md`, D-17 and the design delta all carry
  it, and the added window of delay and halt length is stated everywhere it is implied.
- **F1 (Low) — `09`'s eligibility paraphrase omitted the guard.** Closed: the register row now reads
  "an entry with no accepted heartbeat (`lastHeartbeatSeq(v) = 0`) is ineligible regardless of that
  arithmetic (R2-DI-01: the paraphrase carries the sequence conjunct ...)"; the index row carries
  "`lastHeartbeatSeq(v) > 0`" explicitly.
- **The round-3 Lows on the launch cost and the course note.** Closed: the cost is stated in blocks at
  MEM-13(3)/CONS-13(5)/CONS-14(3)/`09`/`10`/`08`, and the three course pages carry a plain epoch-0 note
  that is accurate and does not restate the derivation ("For the first two versions after activation, the
  judging window is fixed one full window after activation, so everyone has the same full window in which
  to attest" — `learn/04`, with the same fact in `learn/07`'s timeline row and `learn/glossary`'s
  heartbeat entry).

## Mechanical checks (results)

| Check | Result |
|---|---|
| Links/anchors (spec + course, HTML) | **3,995 links, 0 broken** files or fragments |
| Markdown links (whole artifact) | **0 broken** |
| Tag balance (all 24 HTML files) | **0 issues** |
| Tombstone classifier (161 rule divs) | **17 tombstones**, unchanged set; `MEM-13` live; all carry MUST-NOT/withdrawal language and a pointer (`FI-PLANNED-01` correctly carries none) |
| Live references to tombstoned names (spec + course) | **21 hits, all benign** — identical set to rounds 2–3 (historical `PRF-02` V1/V2, MIG-02 `pruneCursor` slot arithmetic, `09`'s withdrawn `GOV-04`/`T_STALL_GOV` rows, `T_ROTATE`/`T_ROTATE_DELAY` in index rows marked withdrawn, `LIM-03` history, `learn/limitations`'s coverage list) |
| Register orphan audit, both directions | 94 rows; the only rows without a rule-div consumer remain the five previously classified ones; the two marked orphans unchanged; all 13 heartbeat names registered and live-consumed |
| Index rule index + parameter map | All 161 ids indexed; every deferred rule marked (only the live `LIM-02` unmarked); the `MEM-13` row carries the guard and the two-window launch transition with its counting window and gate; `CONS-16` stays a gated tombstone |
| Course scan | Deferred-mechanism vocabulary: 2 benign hits (both `learn/05`). **Review-process language: 0 hits.** **No surviving pre-repair or one-window reading**: no "shifted forward by one", "one full heartbeat window" (as the launch shift), "in the future when appended", or "restored by re-attesting at a later commit point" anywhere; the only "commit point" sentences near heartbeat/eligibility say the instant is *not* the commit point (`08`, `02`) or correctly say the roster is drawn at the commit call (`02`, `learn/glossary`) |
| Scope since round 3 | `git diff bb06395d3..HEAD`: 17 files, 571+/31−; spec `01`, `02`, `03`, `08`, `09`, `10`, `index` (2–10 lines each); course `04`, `07`, `glossary` (2 lines each: the epoch-0 note); `DEFERRED.md`/`DECISIONS.md` one-line addenda; the increment delta and the round-3 reports. **No v1 rule changed semantics and no rule id was added or removed (161).** |

## No regression since round 3

The artifact is unchanged wherever the launch fix did not have to reach: the tombstone set, register
shape, index structure, rule-id set, course content and all v1 rules are as round 3 left them. CONS-16
remains a tombstone; `T_ROTATE` and `T_ROTATE_DELAY` remain withdrawn and unread by any live rule.

## Fault-model verdict

No finding, so no fault model is implicated. The two-window shift removes the last ordering influence on
the launch rostes without adding an exploitable path; the residual liveness costs are disclosed.

## Is the increment safe to ship?

**Yes.** The launch fix is real and closes the capture for every position of the activation block in its
window, the round-3 findings are closed in the text, and the mechanical checks are clean. This is the
second consecutive clean round on this angle.

## Counts

| Severity | Count | Ids |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 0 | — |
