# Increment 2 round 4 — the two-window launch transition

**Reviewer:** r6-gov-generations (task-37), independent adversarial reviewer.
**Snapshot:** `18621d858` (branch `etna-pos-zk`), working tree clean. **Angle:** attack the two-window launch
transition — the round-3 Medium's repair — in `spec/03` MEM-13(3), `spec/02` CONS-14(1)/(2), `spec/09` and
`spec/08` MIG-03.
**Method:** the specification is authoritative; the round-3 reports' claims are claims. Citations: `NN:line`
= `spec/NN-*.html`; `R3-LT-01` = my round-3 finding.

**Counts: Critical 0 · High 0 · Medium 0 · Low 1.**
**Verdict: the launch fix is real and complete.** The counting window
`[(q+1)·W, (q+2)·W)` (with `q = ⌊L1_0/W⌋`, `W = HEARTBEAT_WINDOW`) starts strictly after `L1_0` and lies
entirely after activation **for every position of `L1_0` in its window** — first block, last block, and
exactly on a boundary — so every live entry has a full `W`-block window in which to attest before any
filtered roster can be fixed, and no launch order can compose the rosters of `e_0+1`/`e_0+2` without
full-window censorship (F8). The instant remains derived, unstored and caller-independent, coverage holds
with equality, and the unshifted definition resumes at `e_0+3` never stricter. The one Low is arithmetic
precision in the *disclosed cost*: the first-boundary halt is now **guaranteed** whenever
`EPOCH_LEN_L1 < HEARTBEAT_WINDOW`, whereas MEM-13(3)/CONS-14(2)/MIG-03 phrase it conditionally ("can open",
"if the L2 reaches the first boundary before the entry … is appended") and size it as "one full window
longer" than a round-2 halt that may not have existed; I give the exact bounds below. **The increment is safe
to ship**, with that one sentence corrected.

---

## Finding R4-LT-01 — Low: the launch-halt disclosure is conditional and relative, but the halt is now guaranteed and its bounds are absolute

**Severity: Low.** One-line rationale: with the gate at `(q+2)·W` and the first L1-side epoch boundary at
`L1_0 + EPOCH_LEN_L1`, the gate always opens strictly after that boundary (because
`HEARTBEAT_WINDOW > EPOCH_LEN_L1`), so the first-boundary halt of CONS-13(5) is *unavoidable* whenever the L2
keeps pace — not "reached when the append … is missed" — and its length is
`2W − (L1_0 mod W) − EPOCH_LEN_L1` blocks (plus Ethereum finality), i.e. between `W − EPOCH_LEN_L1 + 1` and
`2W − EPOCH_LEN_L1` blocks, not "up to one full window longer" than a halt the round-2 transition might not
have produced at all; the second boundary can halt as well, and the aggregate launch delay is therefore up to
one append-gate delay *plus* finality *plus* a second recovery cycle, which the disclosure does not state.
**File + rule id.**
- `03:541` (MEM-13(3)): "**The cost is disclosed:** the counting window lies one window later than the
  activation window the round-2 repair used, so the first two filtered appends are gated by up to two
  `HEARTBEAT_WINDOW`s rather than one, and **the missing-entry halt of CONS-13(5), reached when the append
  for the first boundary is missed**, is up to one full window longer; because the register bounds
  `HEARTBEAT_WINDOW` only from below (PARAM-01), that added window's wall-clock length is bounded by no
  rule."
- `02:476` (CONS-14(2)): "the launch-transition shift **can** open those appends up to two heartbeat windows
  after `L1_0` and so after the L1-side start of an epoch they govern"; and `08:141` (MIG-03): "**if** the L2
  reaches the first boundary before the entry for epoch 1 is appended and Ethereum-final, the missing-entry
  halt of CONS-13(5) applies, can run up to one full window longer than that earlier transition's halt, and
  clears on the permissionless lowest-missing append".
- **The arithmetic.** Let `P = L1_0 = qW + r` with `0 ≤ r ≤ W−1`, and `E = EPOCH_LEN_L1` with
  `E < W` (the register relation `W ≥ E + ⌈T_L1_include/L1_BLOCK_INTERVAL⌉ + margin`, `09:213`). The gate opens
  at `G = (q+2)W = P + 2W − r`; the first boundary is `B1 = P + E`;
  `G − B1 = 2W − r − E ≥ W + 1 − E > 0` because `r ≤ W−1`. So `G ≥ B1 + 2` in the worst alignment and
  `G − B1 ≤ 2W − E`: the append for `e_0+1` can never be made before the epoch is entered, and the halt is
  guaranteed, lasting `2W − r − E` blocks plus the append's Ethereum finality (the L2-side entry into
  `e_0+1` cannot precede the L1 clock reaching `B1`, by MEM-09(5)). The second boundary
  `B2 = P + 2E` is also passed by the gate whenever `2(W − E) > r`, and even when it is not, the finality
  lag makes the second entry late in most alignments — so the launch may require two recovery cycles, not one.
- **Missing rule / correction:** state the halt absolutely — "the append for `e_0+1` opens strictly after the
  first L1-side epoch boundary (since `HEARTBEAT_WINDOW > EPOCH_LEN_L1`), so the first-boundary halt is
  reached whenever the L2 keeps pace and lasts `2·HEARTBEAT_WINDOW − (L1_0 mod HEARTBEAT_WINDOW) −
  EPOCH_LEN_L1` blocks before the append, between `HEARTBEAT_WINDOW − EPOCH_LEN_L1 + 1` and
  `2·HEARTBEAT_WINDOW − EPOCH_LEN_L1` blocks, plus Ethereum finality; the same gate can also delay the entry
  for `e_0+2` past its boundary. The aggregate launch delay is therefore bounded in blocks by the gate plus
  finality plus a second cycle, and unbounded in wall-clock time because the register bounds
  `HEARTBEAT_WINDOW` only from below."
**Assumptions.** None beyond the registered relation `EPOCH_LEN_L1 < HEARTBEAT_WINDOW` and the two-epoch
schedule; no adversary. The disclosure gap does not change any behavior — the halt is bounded, clears under
the permissionless lowest-missing append (`02:476`, `08:141`), and touches no stake, exit, safety or history
property.
**Fault-model verdict.** Inside (disclosure precision; no adversary, no assumption failure).
**Attacker cost.** None. **Requirement affected.** MEM-13(3)'s cost disclosure; CONS-14(2); MIG-03's launch
announcement; the round-4 question "is the disclosed halt arithmetic exactly right?".
**Evidence.** `03:541`; `02:476`; `08:141`; `09:213`; MEM-09(5) `03:511-518`.

---

## Verification of the charged questions

**Does the counting window `[(q+1)W, (q+2)W)` have full length W for every position of `L1_0` in its
window?** **Yes, for every position.** With `q = ⌊L1_0/W⌋`, `L1_0 ∈ [qW, (q+1)W)` always, so
`(q+1)W > L1_0` strictly and the counting window begins strictly after activation and ends at the gate. Its
length is `W` by construction, and every block of it is chronologically after activation, so the whole
window is available to every live entry. The extremes:
- *First block* (`L1_0 = qW + 1`): the window starts at `(q+1)W = L1_0 + W − 1`, i.e. one block short of a
  full window *after activation* but a full `W`-block window in its own right — every entry has all `W`
  blocks of it. ✓
- *Last block* (`L1_0 = (q+1)W − 1`): the window starts at `L1_0 + 1`; the entry has the full `W`. ✓
- *Exactly on a boundary* (`L1_0 = qW`): `q = L1_0/W`, the window starts at `L1_0 + W`; full `W`. ✓
In each case the round-2 one-window repair's failure mode — a counting window `[qW, (q+1)W)` that began
before `L1_0` and could leave a one-block usable tail — is gone. ✓ **R3-LT-01 is closed.**

**Can a prepared or adversarial entry still win a race to fix the rosters of `e_0+1` and `e_0+2` in any
launch order?** **No, except through full-window censorship, which is F8's disclosed class.** The gate makes
the first permitted append block `(q+2)W = ` the counting window's close, and eligibility for those two
versions is `lastHeartbeatSeq(v) > 0 AND lastHeartbeatAt(v) ≥ (q+1)W`, i.e. *any* accepted heartbeat in the
counting window or later. The roster is therefore a function of who attested during a full window, and the
appender's identity, order and block cannot remove an entry:
- *Adversary first / honest first / both in one block:* all entries that attested by the close are eligible,
  whoever calls first; attesting first buys nothing and calling first buys nothing. ✓
- *Uncoordinated launch:* nobody attests in the window ⇒ no eligible entry at the close ⇒ `commitSet()`
  reverts, the append is missed, and the first-boundary halt (R4-LT-01) clears as soon as one entry attests
  (any record ≥ `(q+2)W ≥ (q+1)W` qualifies) and the append lands. Disclosed at `02:476`/`08:141`. ✓
- *Devnet or low-height restart:* `q = 0`, counting window `[W, 2W)` — full and entirely after a low `L1_0`;
  the R2-DI-01 guard keeps never-attested entries out, so the old low-height unfiltered admission stays
  closed. ✓
- *Delayed append:* any call at or after the gate evaluates the same `I*(e)`, so a later call can only add
  entries that have since attested and cannot remove one whose activity is unchanged (`03:541`); activity
  changes (owner exit, slashing) are owner/protocol acts, not a caller lever. ✓
- The only way to exclude an honest entry from those two versions is to prevent its heartbeat throughout a
  full `W`-block window — censor, delay past the window, or price it out: exactly F8, one transaction per
  entry per window, disclosed (`03:546`). ✓

**Is the shifted instant still derived with nothing stored and no caller influence?** Yes.
`w*(e) = q + 2` and `I*(e) = (q+2)·W` are a pure function of `L1_0` (activation record) and the
`HEARTBEAT_WINDOW` in force at the evaluating block; no per-epoch record, no writer, no keeper, no oracle,
no past-block read, no storage added (`03:541`, `02:473`). The one bounded exception remains the
pending-change ordering Open, named in MEM-13(3) and sized in MEM-13(6). ✓

**Does coverage hold for the shifted epochs?** Yes, with equality: a heartbeat accepted in the counting window
records `lastHeartbeatAt(v) = (q+1)·W`, and the predicate needs `≥ I*(e) − W = (q+2)W − W = (q+1)W` ✓; a
heartbeat accepted later records more. One accepted attestation anywhere in the counting window suffices, and
the launch duty at CONS-14(1) correctly requires exactly that window ("the heartbeat window immediately after
the one containing `L1_0` … an accepted heartbeat naming that window … before the first `commitSet()` that
appends a filtered version"), consistent with the predicate. ✓

**From `e_0+3`, is the unshifted definition ever stricter in a way that excludes anyone?** No.
`C(e_0+3) = e_0+1`, so `I*(e_0+3) = ⌊(L1_0 + E)/W⌋·W ≤ (q+2)W` because `L1_0 < (q+1)W` and `E < W`, hence
its threshold `I*(e_0+3) − W ≤ (q+1)W` — at or below the launch threshold, so it can only admit. It can be
*looser* by up to two windows (`I*(e_0+3) ∈ {qW, (q+1)W}`, threshold `(q−1)W` or `qW`), which admits entries
whose only record is in the activation window and excludes no one; the filter tightens again as `I*` advances
from `e_0+4`. An entry excluded from the first two versions is selectable from `e_0+3` (its record
`(q+1)W ≥` either threshold). ✓

**Can the gate be used to deny or delay honest validators beyond the disclosed two-window cost?** The gate is
a condition on the call, identical for every appender, and the append delay after `L1_0` is
`2W − (L1_0 mod W) ∈ (W, 2W]` blocks — "up to two `HEARTBEAT_WINDOW`s" ✓ exact. It cannot target an entry or
be invoked selectively, and eligibility returns from `e_0+3`. The only way the cost exceeds a delay is
R4-LT-01's guaranteed first-boundary halt (and the possible second one), whose *magnitude* is disclosed but
whose *inevitability* and the second-boundary case are not. ✓ with R4-LT-01.

**Can the transition be re-entered or replayed?** No: it applies exactly to the epochs whose clamp resolves
to `e_0` (`C(e_0+1) = C(e_0+2) = e_0`, `C(e_0+3) = e_0+1`), the activation record is written once and no
rule rewrites `L1_0`, `e_0` or `EPOCH_LEN_L1` (`02:470-473`; L1-06; MIG-01/MIG-04), each epoch's mapping
entry is appended once under MEM-09(1)'s append-only lowest-missing rule, and there is no caller input to
replay. ✓

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 1 | R4-LT-01 (the launch-halt disclosure is conditional and relative, but the first-boundary halt is now guaranteed and bounded absolutely; the second boundary can halt too) |

**Strongest attack: none.** I tried hardest on the two-window repair: the counting window is strictly after
`L1_0` and full-length for every alignment of `L1_0` in its window (first block, last block, exact boundary),
the gate makes the roster a function of a full window of attestations so no launch order composes it, the
instant is derived and unstored, coverage holds with equality, `e_0+3` is never stricter, the gate is
symmetric and non-targetable, and the transition cannot be re-entered or replayed. The single Low is
disclosure arithmetic about a cost whose *upper bound* ("up to two windows in blocks, unbounded wall clock")
is exactly right — the halt is simply stated as conditional when it is in fact guaranteed, and its absolute
bounds are not given.

**Is the increment safe to ship?** **Yes.** No Critical, no High, and the one Low changes no behavior: the
launch halt it describes is bounded, clears under the permissionless lowest-missing append, and touches no
stake, exit, safety or history property. Fixing R4-LT-01 is one sentence in MEM-13(3) (and its two carriers)
and can be done in the same pass as the launch checklist. With that, I would ship increment 2: MEM-13 is
live, CONS-16 and `T_ROTATE`/`T_ROTATE_DELAY` remain tombstones and are read by no live rule, and the
launch transition now does what it was introduced to do.
