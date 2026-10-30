# Increment 2 round 3 — the launch transition

**Reviewer:** r6-gov-generations (task-33), independent adversarial reviewer.
**Snapshot:** `bb06395d3` (branch `etna-pos-zk`), working tree clean. **Angle:** attack the launch transition —
the shift of `I*(e)` for the two clamped epochs `e_0 + 1` and `e_0 + 2` and the coupled append gate — in
`spec/03` MEM-13(3), `spec/02` CONS-14(1)/(2), `spec/09` and `spec/08` MIG-03.
**Method:** the specification is authoritative; the round-2 reports' claims are claims. Citations: `NN:line`
= `spec/NN-*.html`; `R2-` = the round-2 increment reports (`inc2r2-*.md`).

**Counts: Critical 0 · High 0 · Medium 1 · Low 0.**
**Verdict: every repair charged to this round is real, and the launch transition is a genuine improvement —
but its headline guarantee ("a full attestation window") is not established by the rules.** The window it
gives is full in *duration* only: it begins at `qW = ⌊L1_0/W⌋·W`, which is at or before `L1_0`, while entries
can act only from `L1_0` unless heartbeat acceptance happens to be live before T3 — a property
CONS-14(1) explicitly does **not** rely on. The usable attestation window is therefore
`[L1_0, (q+1)W)`, whose length `W − (L1_0 mod W)` can be **one block**, and no rule bounds the activation
block's position inside its window. In that alignment the first attester/appender capture the round-2 Medium
identified survives, narrowed but not closed (R3-LT-01). No Critical or High; the increment is otherwise
sound and safe to ship once that one line is fixed or the launch is scheduled early in a window.

---

## Finding R3-LT-01 — Medium: the launch transition's guarantee depends on the activation block's position in its heartbeat window, which no rule constrains

**Severity: Medium (rationale).** The repair was introduced to close the round-2 Medium F1 ("the clamp sends
the versions for `e_0 + 1` and `e_0 + 2` to the activation window, so the first attester can obtain both
rosters before an honest cohort has any heartbeat"). It does close the ordering race *at the gate*: no
filtered roster can be fixed before `(q+1)W`, so being first to append no longer composes a roster. But the
protection is only as good as the *available* part of that window. The counting window is
`[qW, (q+1)W)`; entries can register keys and attest only once the staking contract is live, which the
specification ties to T3 at block `L1_0` and explicitly declines to extend backwards ("pre-activation
acceptance is neither required nor relied upon"); so the window actually available to validators is
`[L1_0, (q+1)W)`, of length `W − (L1_0 mod W) ∈ [1, W]`. When `L1_0` is late in its window, an entry that
wins the ordering of one or two blocks can be the only eligible entry at the gate and the rosters of
`e_0 + 1` and `e_0 + 2` exclude every honest entry that missed it — the exact harm F1 named, in a one-block
window. Not Critical and not High: no stake, exit or safety property is affected, no two histories arise,
and the excluded entries return at `e_0 + 3`; but the defect is real, deployment-dependent, and the fix is
one line.

**File + rule id.**
- `03:541` (MEM-13(3), Launch transition): "the entries for `e_0 + 1` and `e_0 + 2` MUST NOT be appended
  before the shifted instant `I*(e_0 + 1)`, so **the window containing `L1_0` — the window immediately before
  the shifted instant, which the predicate's one-window slack admits — is a full attestation window** that
  closes before any filtered roster can be fixed. Being the first to attest or the first to call
  `commitSet()` therefore cannot compose a filtered roster: when the first append opens, every entry that
  attested **in it** is already eligible." The predicate it relies on is
  `lastHeartbeatSeq(v) > 0 AND lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW` with `I*(e) = (q+1)·W`, i.e.
  `lastHeartbeatAt(v) ≥ q·W`: an attestation anywhere in `[qW, (q+1)W)` — or later — qualifies.
- `02:471` (CONS-14(1)): "`L1_0` — the L1 block at which epoch `e_0` begins, **which for the migration
  specified here is the L1 block in which the activation transaction is included**"; and `02:473`: "the
  staking contract … carries the heartbeat key path before activation (08, T3), and **no rule of this page
  disables heartbeat acceptance before T3, so pre-activation acceptance is neither required nor relied
  upon**."
- `02:473`, *Launch duty*: "A validator … **MUST therefore have an accepted heartbeat naming the window
  containing `L1_0`** … before the first `commitSet()` that appends a filtered version."
- `08:141` (MIG-03): "the first two filtered appends are delayed by up to one `HEARTBEAT_WINDOW`; if the L2
  reaches the first boundary before the entry for epoch 1 is appended and Ethereum-final, the missing-entry
  halt of CONS-13(5) applies and clears on the permissionless append"; `08:504` repeats the duty.
- `09:213`: the register relation for `HEARTBEAT_WINDOW` is a **lower** bound only
  (`≥ EPOCH_LEN_L1 + ceil(T_L1_include / L1_BLOCK_INTERVAL) + margin`); no rule relates the activation block
  to its window, and none bounds `W` above.
- **Missing rule:** one of — (i) the launch counting window must *start at or after* `L1_0`, e.g.
  `I*_clamped = (⌊L1_0/W⌋ + 2)·W`, so the counting window `[(q+1)W, (q+2)W)` is entirely after activation and
  every entry has a guaranteed full window (at the cost of one further window of append delay, which
  `02:476`, `08:141` already disclose and which the lowest-missing append recovers); or (ii) heartbeat
  acceptance MUST be live from the staking contract's pre-activation deployment, so window `q` is usable from
  `qW` (CONS-14(1)'s "neither required nor relied upon" becomes "required"); or (iii) a normative
  launch-scheduling relation, e.g. the activation transaction MUST be included within the first
  `W − (ceil(T_L1_include/L1_BLOCK_INTERVAL) + margin)` blocks of a heartbeat window.

**Assumptions.** The activation lands late in its heartbeat window (equivalently, few blocks of the window
remain after `L1_0`), and heartbeat acceptance is not live before T3 — the default the rules establish by not
requiring it. A competing entry or coalition has its key ready and can win the ordering of one block
(`F8`'s class). No cryptographic or liveness assumption fails.

**Concrete attack trace.**
1. The migration is scheduled so that T3 lands in the last block of a heartbeat window:
   `L1_0 = (q+1)W − 1`. Nothing in the specification prevents this; `L1_0` is simply the block in which the
   activation transaction is included (`02:471`).
2. Entries may act only from `L1_0` (pre-activation acceptance is not relied upon). The usable attestation
   window is therefore the single block `L1_0` plus the gate block `(q+1)W`.
3. An adversary (or any single prepared entry) lands a heartbeat in `L1_0` after the activation transaction,
   or in block `(q+1)W` ordered before the first `commitSet` call, and calls `commitSet()` at `(q+1)W` — the
   first block the gate permits.
4. Eligibility for `e_0 + 1` and `e_0 + 2` is `lastHeartbeatAt ≥ qW`; entries whose heartbeats were ordered
   after the append call in the same block, or that land in `(q+1)W + 1`, are excluded from both rosters.
   The two versions — 60 minutes of chain under the 30-minute cadence — are composed of the entries that won
   the one-block ordering; the adversary's share of their `TotalVP` rises.
5. The excluded entries become eligible again for `e_0 + 3`: `I*(e_0+3) = ⌊L1_first(e_0+1)/W⌋·W ≤ (q+1)W`
   (because `EPOCH_LEN_L1 < W`), so its threshold is at most `qW` and any later attestation qualifies. The
   exclusion is bounded to the two clamped versions, which is why this is Medium and not High.
6. *Uncoordinated variant:* if no entry attests in the usable window, the gate's first call finds no eligible
   entry, `commitSet()` reverts, the append is missed, and the first boundary halt is reached — recoverable by
   one attestation plus one append, as `02:476`/`08:141` disclose. The halt's duration is up to
   `W − (L1_0 mod W)` blocks and, since the register bounds `W` only from below, its wall-clock length is
   unbounded by the rules (a secondary consequence of the same missing scheduling constraint, not a separate
   finding).

**Fault-model verdict.** Inside: no assumption fails and no cryptographic primitive is touched. It needs the
deployment's activation timing (which a hostile deployer controls and a careless one may hit) plus
block-ordering control of one block — F8's disclosed class, not a new capability. It is a narrowed survival
of round-2 F1, not a new defect class.
**Attacker cost.** One heartbeat transaction plus one `commitSet` call and the ordering of a single block; no
stake, no censorship budget, no parameter or key compromise.
**Requirement affected.** MEM-13(3)'s launch-transition guarantee and the *Launch duty* of CONS-14(1);
CONS-14(2)'s first-boundary treatment; MIG-03's announcement; the round's decision that the launch
transition closes F1. No fixed decision (D-14, D-16, the boundary, the exit) is touched.
**Evidence.** `03:541`; `02:471`, `02:473`, `02:476`; `08:141`, `08:504`; `09:213`;
`inc2r2-boundary-and-genesis.md` F1.

---

## Verification of the charged questions

**Does the shift plus the coupled append opening remove the ordering race in every launch order?** It
removes the *pre-existing* race and closes the cases in which a roster could be fixed before the activation
window closed; it does not remove the race when the window's usable part is short (R3-LT-01). Case by case:
- *Adversary first / honest first.* The gate makes the order of attestations inside the window irrelevant to
  *when* a roster is fixed (nothing before `(q+1)W`), and every entry that attested by then is included, so
  neither side can compose a roster out of thin air. The residual is only *which entries managed to attest*
  inside the usable window. ✓ with R3-LT-01.
- *Both in one block.* At `L1_0` the heartbeat transaction must be ordered after T3 for the staking contract
  to be live; a block producer can order it either way, so in a one-block window the ordering decides
  eligibility — the F8-class residual R3-LT-01 describes. ✓ with R3-LT-01.
- *Uncoordinated launch.* No attestation in the usable window ⇒ no eligible entry at the gate ⇒
  `commitSet()` reverts, the append is missed, the first boundary halt is reached, and it clears as soon as
  one entry attests (any record ≥ `(q+1)W ≥ qW` qualifies) and the append is made. Disclosed at `02:476`
  and `08:141`; recoverable, no protocol update. ✓
- *Restart at a low L1 height.* `q = 0`, `I*_clamped = W`, so the gate is block `W`; if
  `EPOCH_LEN_L1 < W` the L2 may reach `h_first(e_0+1)` first and halt until the gate opens, then recover by
  the lowest-missing append. The launch halt's length is up to `W − (L1_0 mod W)` blocks; disclosed in
  substance, unbounded in wall-clock terms because `W` has only a lower relation. ✓ (secondary point of
  R3-LT-01).
- *Devnet / fresh chain.* Same as above, with `q = 0`; the round-2 R2-DI-01 guard now ensures a
  never-attested entry cannot enter a roster even when `I*(e) ≤ HEARTBEAT_WINDOW`, so the low-height case no
  longer admits an unfiltered roster — only the short-window effect of R3-LT-01 remains. ✓

**Is the shifted instant still caller-independent and derived with nothing stored?** Yes. The shift is a pure
function of `L1_0` and the `HEARTBEAT_WINDOW` in force at the evaluating block — the same two inputs as the
unshifted value, read from the activation record and the parameter, with no per-epoch write, no writer, no
keeper and no past-block read (`03:541`, `02:473`). The one residual caller influence is the already-Open
pending-change ordering (MEM-13(6)), which applies equally before and after the launch and is now sized and
named. The append block itself, its timestamp and its position select nothing. ✓

**Does coverage hold for the shifted epochs, and does the unshifted definition resume at `e_0 + 3` without
making later versions stricter or looser?** Coverage holds exactly: an attestation accepted in the
activation window records its start `qW`, and the predicate needs `≥ I*_clamped − W = qW` — equality, so one
attestation in that window suffices, and any later record also qualifies. From `e_0 + 3`:
`I*(e_0+3) = ⌊(L1_0 + EPOCH_LEN_L1)/W⌋·W ≤ (q+1)W = I*_clamped` because `L1_0 < (q+1)W` and
`EPOCH_LEN_L1 < W`, so its threshold `I*(e_0+3) − W ≤ qW` — **never stricter** than the launch versions;
I verified the claim in `03:541`. It *can* be **one window looser** (`I*(e_0+3) = qW` when
`L1_0 + EPOCH_LEN_L1 < (q+1)W`, the common case), i.e. the evaluation instant dips by one window at the
`e_0+2 → e_0+3` boundary and then increases monotonically. That is harmless: the looser threshold admits
entries whose last record is in `[qW − W, …)`, which can only be *pre-activation* records (window `q−1`), and
those exist only if pre-activation acceptance is live — the case CONS-14(1) does not rely on; in every case
it admits entries rather than excluding them, so it cannot make an honest entry lose a version. ✓

**Can the launch gate be used to deny or delay honest validators beyond the disclosed one-window cost?** The
gate itself is symmetric (a rule on `commitSet`, not on any party) and delays *roster composition* by at most
one window: the appends for `e_0+1` and `e_0+2` open at `(q+1)W`, which is at most `W` blocks after `L1_0`;
`02:476` and `08:141` disclose that the shift can open them after the L1-side start of the epochs they
govern, and the missing-entry recovery is named. The *one* way the cost exceeds "one window of delay" is
R3-LT-01: with a short usable window an honest entry can lose its place in those two versions entirely, and
the launch halt's length scales with `W − (L1_0 mod W)` — bounded by one window in blocks, unbounded in
wall-clock terms because the register does not bound `W` above. No party can *invoke* the gate to deny a
specific validator (it is not per-entry), and re-attestation restores eligibility from `e_0+3` onward. ✓ with
R3-LT-01.

**Can the transition be re-entered or replayed?** No. It applies to exactly the epochs whose clamp resolves
to `e_0` — `C(e_0+1) = max(e_0−1, e_0) = e_0` and `C(e_0+2) = e_0`, while `C(e_0+3) = e_0+1` — so it is a pure
function of the epoch index and the activation record, with no state to re-enter (`03:541`). The activation
record is written once by the activation transaction, and no rule rewrites `L1_0`, `e_0` or
`EPOCH_LEN_L1` (`02:470-473`; MIG-01/MIG-04's privilege removal; L1-06's prohibition on any function
lowering or replacing the boundary). Each epoch's mapping entry is appended once under MEM-09(1)'s
append-only, lowest-missing rule, so no version can be re-evaluated under the shifted clause after it is
committed (`03:475`, `03:493`). There is no caller input to replay. ✓

## Round-2 repairs verified (all real; no new defect found)

- **R2-DI-01 (predicate guard)** — `03:541`: "if and only if `lastHeartbeatSeq(v) > 0` **and**
  `lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW`", with the explicit note that a never-attested entry fails
  the guard "even though `lastHeartbeatAt(v) = 0` would satisfy the inequality whenever `I*(e) ≤
  HEARTBEAT_WINDOW`". Consistent with (2b) `03:539`. ✓
- **R2-DI-02 (Open sizing)** — `03:545`'s Open now states the affected set as a **contiguous run**
  ("every version evaluated before the entry re-attests whose evaluation instant falls in
  `(A + W', A + W_old]` … about `(W_old − W')/EPOCH_LEN_L1` of them … bounded by the backlog actually
  drained"), names the pending-change ordering as "the one remaining caller influence on `I*(e)`", bounds it
  to the pending change and F8's class, and states what would close it. ✓
- **R2 F2 (the false "in the future when appended")** — `03:541`: the reference block is "at or before every
  block in which the append may be made — a late or refilled lowest-missing append only moves it further into
  the past, which broadens eligibility and excludes no one"; no reading reverts a late refill. ✓
- **R2 F3 (CONS-14(1)'s justification)** — `02:473`: "the exemption is a policy choice, **not a claim that
  the records are unset** … the stated reason is now the policy exemption — no attestation history can be
  required of the activation entry", with the T3 consistency (non-zero epoch-0 root, heartbeat key path
  present before activation) stated. ✓
- **R2 F1 (launch race)** — the shift and the gate are real, derived and confined to the two clamped
  epochs; the remaining gap is R3-LT-01. ✓ narrowed.
- **INC2R2-UD-01/02 (withdrawn caller-dependent reading; register and decision record)** — `01`'s validator
  duty now describes the heartbeat as naming the window the carrying transaction lands in and the evaluation
  as the derived coverable-start window; `08:504` carries the cadence and launch duties; `D-17` carries an
  addendum recording the correction, the derived instant, the guard, the contiguous-run Open and the
  pending-change influence, with the historical text preserved; `09:213` carries the height grid, the
  absolute-instant comparison and the withdrawal of the never-re-labels claim. ✓
- **No regression:** CONS-16 remains a tombstone and `T_ROTATE`/`T_ROTATE_DELAY` remain withdrawn and unread
  (`02:16`, `02:505-510`, `02:541`, `03:545`, `09:210-211`); the boundary, MEM-15 exit, D-8/D-9/D-11 and
  D-14 are untouched; the round-2 mechanical sweep found no stale live reference, and I re-checked the launch
  path's citations rather than the claim. ✓

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 1 | R3-LT-01 (the launch transition's "full attestation window" begins before `L1_0`; the usable part can be one block, and no rule bounds `L1_0`'s position in its window — the round-2 F1 capture survives, narrowed, for `e_0+1`/`e_0+2`) |
| Low | 0 | — |

**Strongest attack:** R3-LT-01. Schedule T3 into the last block of a heartbeat window, so `L1_0 = (q+1)W − 1`;
because the rules do not require pre-T3 heartbeat acceptance and do not constrain the activation's position
in its window, the entries' usable attestation window is one block. A prepared entry wins the ordering of
that block (or of the gate block) and appends at `(q+1)W`, fixing the rosters of `e_0+1` and `e_0+2` without
the honest entries that missed the block — exactly the harm the shift was introduced to stop, now confined
to two versions and one-block timing. The fix is one line: make the launch counting window begin at or after
`L1_0` (e.g. `(⌊L1_0/W⌋ + 2)·W`), or require heartbeat acceptance to be live before T3, or state a
launch-scheduling relation. The secondary consequence (the launch halt's length is up to
`W − (L1_0 mod W)` blocks and the register bounds `W` only from below) is disclosed in substance at
`02:476`/`08:141` and would be bounded by the same scheduling rule.

**Is the increment safe to ship?** Yes at the safety, fund, exit and history level — nothing in this round
touches a fixed decision in a way that loses funds or forks the chain, and every round-2 repair is real. The
increment therefore meets the round's convergence bar (no Critical, no High). I recommend fixing R3-LT-01
(one line in MEM-13(3)/CONS-14(1), or a launch-scheduling clause in MIG-03) before the launch rather than
after, because it is a launch-time property that costs nothing to close and a one-block attestation window
is not something the deployment can detect from the rules as written.
