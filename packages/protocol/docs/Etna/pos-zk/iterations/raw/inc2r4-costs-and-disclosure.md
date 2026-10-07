# Increment 2 round 4 — the disclosed costs and the register: confirmation

**Angle.** The two-window launch gate, the added halt window and the one-sided bound on
`HEARTBEAT_WINDOW` — stated everywhere the launch transition or the boundary halt is described, and with
arithmetic that is right rather than approximate; no page still saying one window; the register's unit,
relation, launch clause and `unmeasured` tag with no new row or parameter; the plain course note accurate
and free of finding ids; and no disclosure promising more than the rules deliver.

**Snapshot.** `18621d858`; working tree at the same commit. Primary sources read: `spec/03` MEM-13(3) and
MEM-09(1), `spec/02` CONS-14(1)/(3) and CONS-13, `spec/09` (glossary row, `HEARTBEAT_WINDOW`,
`lastHeartbeatSeq(v)`), `spec/08` (transitional cost and the MIG-03 announcement), `spec/01`, `spec/10`,
`spec/index.html`, `DEFERRED.md`, `DECISIONS.md`, the design delta and the course.

**Result: no findings. 0 Critical, 0 High, 0 Medium, 0 Low. I found nothing.** The two-window repair is
real, closes the R3-LT-01 capture in every launch order, and its arithmetic and disclosed costs are
correct and carried in every artifact that describes the launch transition or the halt. The round-3
Medium/Lows are closed (register paraphrases carry the `lastHeartbeatSeq(v) > 0` conjunct; spec/01, the
index, spec/10, DEFERRED.md, DECISIONS.md and the delta carry the shift, the guard and the cost; three
course pages carry the plain epoch-0 note). **The increment is safe to ship.**

---

## The arithmetic is right, not approximate

With `q = floor(L1_0 / W)` and `r = L1_0 − qW ∈ [0, W)`:

1. **The instant and the counting window.** `w*(e) = q + 2`, `I*(e) = (q + 2)W`; the predicate's
   one-window slack admits the counting window `[(q + 1)W, (q + 2)W)`. Since `L1_0 < (q + 1)W`,
   `(q + 1)W` is the **first window boundary strictly after `L1_0`**, so the counting window starts at or
   after activation and has the **full length `W` for every `r`** — this is exactly the R3-LT-01 fix
   (one window left the usable window as short as `W − r`, down to a single block when `L1_0` landed at
   the end of its window).
2. **The gate.** The entries for `e_0 + 1` and `e_0 + 2` MUST NOT be appended before the counting
   window closes, i.e. before `I*(e_0 + 1)`; the condition is a function of the epoch, `L1_0` and `W`
   only — a condition on the **call**, identical for every appender, naming no entry and no caller. The
   rules state it in MEM-13(3), MEM-09(1) ("a call that would append before the shifted instant MUST
   revert rather than append"), CONS-14(1)/(3) and the register row.
3. **Coverage.** A heartbeat accepted in the counting window records
   `lastHeartbeatAt(v) = (q + 1)W = I* − W`, so the predicate holds **with equality** for both shifted
   epochs. The unshifted instant for `e_0 + 3` is `U = floor((L1_0 + EPOCH_LEN_L1)/W)·W`; because
   `EPOCH_LEN_L1 < W`, `r + EPOCH_LEN_L1 < 2W`, hence `U ≤ (q + 2)W = I*`, so the launch threshold
   `I* − W` is **at or above** `e_0 + 3`'s threshold `U − W`: "a lower later threshold admitting,
   never excluding" is correct, and the shift's effect ends at `e_0 + 3` as stated.
4. **The costs.** `I* − L1_0 = 2W − r ∈ (W, 2W]`, so "the first two filtered appends are gated by **up to
   two** `HEARTBEAT_WINDOW`s" is exact (the bound is attained at `r = 0`); the halt window is exactly
   **one full window longer** than the one-window shift it replaces; and because the registered relation is
   a **lower bound only** (`HEARTBEAT_WINDOW ≥ EPOCH_LEN_L1 + ceil(T_L1_include(p)/L1_BLOCK_INTERVAL) +
   margin`, no upper bound) and `r` is unconstrained, "unbounded in wall clock" is correct.

## The costs are stated everywhere the launch transition or the halt is described

MEM-13(3) (spec/03 line 541) and MEM-09(1) (line 475); CONS-14(1) (the duty, the counting window and "the
first two filtered appends are gated by up to two windows and the launch halt is up to one full window
longer, as MEM-13(3) and MIG-03 state") and CONS-14(3) ("can open those appends up to two heartbeat
windows after `L1_0` … the shift's cost is disclosed at MEM-13(3)"), and the CONS-13 roster description
(line 441); the `spec/09` `HEARTBEAT_WINDOW` row ("Cost, disclosed: … gated by up to two
`HEARTBEAT_WINDOW`s rather than one, and the missing-entry halt of CONS-13(5) is up to one full window
longer; because the relation recorded in this row bounds `HEARTBEAT_WINDOW` only from below, that added
window's wall-clock length is bounded by no rule") and the glossary row (33); `spec/08` line 141 ("the
first two filtered appends are delayed by up to two `HEARTBEAT_WINDOW`s — one full window more than the
round-2 transition disclosed — and … the missing-entry halt of CONS-13(5) applies and clears on the
permissionless lowest-missing append") and line 504 (the announcement must carry the cost, including the
one-sided bound); `spec/01` line 378; `spec/10` line 323 ("at the launch transition the first two
filtered appends cannot open before the shifted evaluation instant … so this bound carries up to one full
extra `HEARTBEAT_WINDOW`: up to two windows in L1 blocks, and unbounded in wall clock because the register
bounds `HEARTBEAT_WINDOW` only from below"); the index line 428; `DEFERRED.md` line 43; `DECISIONS.md`
line 617; and the design delta (lines 132 and 297). A scan of the specification for "one heartbeat
window", "one full heartbeat", "a single heartbeat window" and "up to one window" returns **nothing** —
the remaining "one-window" uses are the predicate's one-window **slack**, which is the correct term, and
"one full window more than the round-2 transition" is a correct comparison, not a current-cost claim.

## The register is a paraphrase of MEM-13(3), with no new row or parameter

`spec/09` line 213 (`HEARTBEAT_WINDOW`, unit **L1 blocks**) carries the two-window formula
(`w*(e) = floor(L1_first(e_0)/W) + 2`, `I*(e) = (floor(L1_first(e_0)/W) + 2)·W`, `L1_first(e_0) = L1_0`),
the counting window and the full-length property, the gate ("MUST NOT be appended before that shifted
instant, the close of that counting window"), the resumption from `e_0 + 3`, the cost with the one-sided
bound, and the `unmeasured` tag; the blocks-to-blocks relation is intact. The round-4 diff to `spec/09`
changes three **existing** rows only — the glossary row, `HEARTBEAT_WINDOW` and `lastHeartbeatSeq(v)`
(which now states that "eligibility requires `lastHeartbeatSeq(v) > 0`, so an entry with no accepted
heartbeat is ineligible regardless of `lastHeartbeatAt(v)`") — so no row and no parameter was invented.
The `lastHeartbeatSeq(v) > 0` conjunct is also in MEM-13(3), MEM-09(1)'s roster filter, the 09 glossary
row, `spec/01` line 378, the index line 428, `spec/10` and both addenda.

## The course note is accurate and plain

`learn/04-staking-and-epochs.html` line 49, `learn/07-timing.html` line 73 and
`learn/glossary.html` line 129 each carry the same sentence: "For the first two versions after
activation, the judging window is fixed one full window after activation, so everyone has the same full
window in which to attest." In window-index terms the judging (counting) window is the window after the
activation window, and its start is `W − r` blocks after `L1_0` — so the sentence is accurate for its
purpose (a full post-activation attestation window exists) and it names no finding id; a scan of
`learn/` for `R3-LT`, `INC2R`, `R2-DI` and "finding" finds none in these notes.

## No disclosure promises more than the rules deliver

- The gate is stated as a property of the **call** ("applies to every appender alike and names no entry or
  caller", MEM-13(3), `spec/01`, `spec/10`, the index), which is what the arithmetic gives: the
  condition is `block.number ≥ I*(e)`, with `I*` a pure function of `L1_0` and `W`.
- The cost is disclosed in the same breath as the guarantee wherever the transition is described, and the
  one-sided bound is named as the reason the wall-clock cost is unbounded — no artifact claims a
  wall-clock bound.
- The halt's recovery remains exact: the append still clears the entry-absence halt
  (`CONS-13(5)`, `spec/10` line 323), and a committed roster is still not made reachable
  (MEM-13(3)/(5), `spec/08` line 809) — the added window changes only how long the gate can hold, not
  what the append can or cannot fix.
- The direction of the `e_0 + 3` comparison is stated as "admitting, never excluding", which is the
  direction the arithmetic supports (a later, lower threshold).

## Considered and dismissed (not findings)

1. **"One full window after activation" in the course note.** The start of the counting window is
   `W − r` blocks after `L1_0` (anywhere in `(0, W]`), while the *gate* opens one window later still.
   The note is a plain-language statement of the window-index shift and its point (a full window for
   everyone); the exact block offsets, the two-window gate and the halt are carried in the specification
   and the announcement. Accurate for its purpose, not a defect.
2. **MEM-09(1)'s generic append deadline versus the launch gate** (carried from round 3).
   `CONS-14(3)` governs the launch ("as early as the launch-transition opening of MEM-13(3) permits … can
   open those appends up to two heartbeat windows after `L1_0` and so after the L1-side start of an epoch
   they govern"), and the only behavior available is to wait — an early append MUST revert. The missed
   deadline's consequence (the boundary halt) is disclosed and recoverable. A wording tension with a
   stated consequence, not a rule defect.
3. **The summaries' "a lower later threshold admitting, never excluding"** (`spec/01`, the index,
   `spec/10`) is verified for `e_0 + 3` (the only epoch whose threshold the shift could affect); later
   epochs are unshifted in both worlds, so nothing is claimed about them. Correct as written.

## Ship decision

**Clean at the bar and clean at every severity: 0 Critical, 0 High, 0 Medium, 0 Low.** The two-window
launch transition closes the last-order capture (a late `L1_0` no longer shortens the counting window),
its costs are disclosed with correct arithmetic in every artifact that describes the transition or the
halt, the register carries the clause without inventing a row or parameter, and the course note is plain
and accurate. **The increment is safe to ship.**
