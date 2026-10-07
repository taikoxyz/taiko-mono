# Increment 2 re-review — the derived instant and the block-height grid

**Reviewer:** r6-gov-generations (task-29), independent adversarial reviewer.
**Snapshot:** `7a995f179` (branch `etna-pos-zk`), working tree clean. **Angle:** attack the derived evaluation
instant I*(e) and the L1-block-height grid — the repair for round 1's High — in `spec/03` MEM-13 and
`spec/02` CONS-13/M7, against `increments/02-heartbeat-design.md` and D-17.
**Method:** the specification is authoritative; the delta's claims are claims. Citations: `NN:line` =
`spec/NN-*.html`; `R1-` = the round-1 increment reports (`inc2-*.md`).

**Counts: Critical 0 · High 0 · Medium 0 · Low 2.**
**The round-1 High is genuinely repaired, and I could not break the derived instant.** I*(e) is a pure
function of L1 state on every path I could construct — a late lowest-missing append, two appends in one
block, an append inside the epoch's coverable window, and the epoch boundary all give the same value for a
given e — and the coverage argument is exact integer arithmetic on the height grid: for a record at A and any
new window W', the first re-attestable boundary is `A < B ≤ A + W'`, and every version appended before B has
`I*(e) ≤ n < B ≤ A + W'`, so the old record still covers it. No incumbent can be locked out and no recorded
value can be lowered. The two Lows below are a predicate/statement inconsistency that is unreachable at the
intended deployment and a mis-sized disclosure of the change-timing Open; neither is an attack.
**The increment is safe to ship as written, with the two wording fixes recommended.**

---

## Finding R2-DI-01 — Low: the eligibility predicate is unguarded, so for an early-chain version (`w*(e) ≤ 1`) a never-attested entry passes it, contradicting (2b)

**Severity: Low.** One-line rationale: (2b) states normatively that an entry with no accepted heartbeat "is
ineligible until its first accepted heartbeat", but (3)'s predicate is `lastHeartbeatAt(v) ≥ I*(e) −
HEARTBEAT_WINDOW` with no `lastHeartbeatSeq(v) > 0` guard — and a never-attested entry has
`lastHeartbeatAt(v) = 0`, so whenever `I*(e) ≤ HEARTBEAT_WINDOW` (equivalently `w*(e) ≤ 1`, i.e.
`L1_first(C(e)) < 2 · HEARTBEAT_WINDOW`) the predicate is satisfied and the entry is admitted without ever
attesting; the guard already exists one clause away in (2a)(d) and is simply missing from the eligibility
formula.
**File + rule id.** `03:539` (2b: "An entry with no accepted heartbeat has `lastHeartbeatAt(v) = 0`,
`lastHeartbeatWindow(v)` unset and `lastHeartbeatSeq(v) = 0`, and **is ineligible until its first accepted
heartbeat**") versus `03:541` (3: "Entry v is eligible for set version k … **if and only if**
`lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW`"); the same pattern appears in MEM-09(1) `03:475`
("active … and eligible (MEM-13(3)) at the epoch's fixed evaluation instant"). **Missing rule:** qualify the
predicate — `lastHeartbeatSeq(v) > 0 AND lastHeartbeatAt(v) ≥ I*(e) − HEARTBEAT_WINDOW` — mirroring (2a)(d).
**Assumptions.** A version whose derived window index is ≤ 1, i.e. `L1_first(C(e)) < 2 · HEARTBEAT_WINDOW`.
On the intended migration `L1_0` is an Ethereum mainnet block number (order 10⁷) and
`HEARTBEAT_WINDOW ≈ EPOCH_LEN_L1 + inclusion + margin` (order 10²), so `w*` is order 10⁵ and the condition is
**unreachable there**; it is reachable on a fresh L1 (devnet/testnet, anvil at block 0), after a restart at a
low L1 height, or if the registered window is ever set near or above the activation block number.
**Attack trace.** Not an attack: the failure is a roster that admits entries which never attested — exactly
the unfiltered genesis roster the F2 exemption grants deliberately, but extended to later versions. On such a
chain an operator that never registers or signs keeps its slots until the block height passes `2W`; the
mechanism's purpose is silently void for the first versions. No stake, safety or exit consequence.
**Fault-model verdict.** Inside (specification inconsistency; no adversary; deployment-conditional).
**Attacker cost.** None. **Requirement affected.** MEM-13(2b)/(3); the F2 genesis-exemption's *only* genesis
scoping (`03:541`: "the predicate applies to the entry for `e_0 + 1` and every later entry"); the
increment's claim that the first committed version after the genesis is filtered.
**Evidence.** `03:539`, `03:541`, `03:475`; `02:441`.

---

## Finding R2-DI-02 — Low: the change-timing Open under-sizes its own residual, and the one remaining caller influence on I*(e) is not named

**Severity: Low.** One-line rationale: the Open correctly discloses that a `HEARTBEAT_WINDOW` change can cost
an incumbent a version, but its "**that one version**" is too narrow — with a backlog of missing entries, a
single block can append every backlog version whose evaluation instant lies between the new and the old
coverage, excluding the entry from the whole run — and it does not name the *other* residual: while a change
is pending, the append caller's ordering relative to it selects whether I*(e) is computed under `W_old` or
`W_new`, the only remaining way an account can influence the instant.
**File + rule id.** `03:545` (6), Open: "A change to `HEARTBEAT_WINDOW` that lands after the first boundary
of the new grid strictly following some active entry's record, and before the append that evaluates an epoch
whose coverable start precedes the change, can exclude that entry from **that one version** although the
cadence of the old grid would have kept it eligible; the rule neither delays the new value nor freezes a
per-epoch grid." And `03:541` (3): "`I*(e)` is recomputed inside the evaluating call from the L1-side
schedule and **the value in force at that block**".
- *Run instead of one version.* An entry with record A re-attests from `R = max(T_change, B)`,
  `B = (⌊A/W'⌋+1)·W' ≤ A + W'`. Any version whose append happens before R is evaluated with the old record
  and the new value: it is excluded iff `I*(e) > A + W'`. The versions that the *old* grid would have
  covered and the new one does not are those with `I*(e) ∈ (A + W', A + W_old]` — an interval of length
  `W_old − W'` that contains about `(W_old − W') / EPOCH_LEN_L1` epoch starts. With `W'` reduced and a
  backlog outstanding (the very state the increment's recovery story is about), every one of those missing
  entries can be appended in one block, before the incumbent's re-attestation transaction is included, so the
  exclusion is a contiguous run of versions, not one. The rule's disposition ("neither delays the new value
  nor freezes a per-epoch grid") is a legitimate choice; the *statement* of what it costs should match the
  mechanism ("one or more versions whose evaluation instants fall between the new and the old coverage, up to
  the whole backlog drained in that interval").
- *The caller's ordering at the change.* I*(e) reads "the value in force at that block", so with a
  `HEARTBEAT_WINDOW` change pending in the mempool an append caller can choose to land its call before or
  after the change transaction and thereby pick the grid that evaluates the version; the two grids admit
  different rosters. This is a binary, bounded version of the composition F1 removed (it needs a pending
  change, and the two candidate grids differ by one parameter value), but it is a caller influence on I*(e)
  and the Open does not mention it. A cheap fix in the same clause: state that an append's grid is the one in
  force at the append's block *and* that a pending change may therefore select between two grids, or require
  changes to take effect at an L1-side epoch boundary so no append straddles one.
**Assumptions.** A `HEARTBEAT_WINDOW` decrease (or a change while a backlog exists); a block producer that
orders the backlog appends before an incumbent's re-attestation. No cryptographic or assumption failure.
**Attack trace.** (1) A halt or missed appends leave `p` epochs missing. (2) A governance change lowers W.
(3) The first block after the change drains the backlog via `p` `commitSet` calls, before the incumbent's
heartbeat transaction is included. (4) Every drained version whose `I*(e)` exceeds the incumbent's new-grid
coverage excludes it while admitting entries that attested under the new grid — a composition shift over the
epochs the chain is about to enter. (5) The incumbent re-enters at the first append after it re-attests; the
effect is bounded to the drained run and requires ordering control (F8's class, not a new one), so this is a
disclosure-precision defect, not a break.
**Fault-model verdict.** Inside (disclosure/scope of a disclosed residual; the ordering half leans on F8's
already-disclosed block-producer delay). **Attacker cost.** One block of ordering control plus one governance
change; the new entrants' bonds (`S_min`, refundable) if the shift needs compliant entrants.
**Requirement affected.** MEM-13(6)'s Open completeness; the clause (3) caller-independence claim ("no
transaction can write the value"); the increment's "attack the derived instant" property.
**Evidence.** `03:541`, `03:545`; `09:213` (register row); `10:352` (F8).

---

## Verification of the charged questions

**Is I*(e) a function of L1 state alone in every path?** **Yes, in every ordinary path.** `I*(e) =
⌊L1_first(C(e)) / W⌋ · W` with `C(e) = max(e − LOOKAHEAD_EPOCHS, e_0)` and `L1_first(c) = L1_0 + (c − e_0) ·
EPOCH_LEN_L1` (`03:541`), computed inside the call from the activation record, the target epoch and the
parameter in force — no stored per-epoch instant, no writer, no keeper, no oracle, no past-block read
(`03:475`, `02:441`). Checked path by path:
- *Late lowest-missing append.* The append block n ≥ L1_first(C(e)) enters nowhere in the formula; a version
  appended five epochs late has the same I*(e) as one appended on time. ✓
- *Two appends in one block.* Each call takes the then-lowest missing epoch, so it computes its own
  `(e, I*(e))`; there is no shared state to race on and no ordering that changes either value. ✓
- *An append inside the epoch's coverable window.* I*(e) is the start of the window containing
  `L1_first(C(e))`, which may have begun before the append block; the append block itself never enters. ✓
- *The epoch boundary.* Consecutive versions differ by `I*(e+1) − I*(e) ∈ {0, W}` (because
  `EPOCH_LEN_L1 < HEARTBEAT_WINDOW` by the registered relation): two consecutive versions may share one
  evaluation window, or advance by exactly one. Both are derived, never chosen. ✓
- *The one exception* is R2-DI-02's ordering-at-a-pending-change; it is bounded to the change block and
  disclosed in substance by the Open (though not in those words).

**Can any account influence it by choosing a block, waiting, or ordering transactions?** Choosing a block or
waiting: no — nothing in the formula reads the block, its timestamp, `msg.sender` or any caller input.
Ordering: only against a pending `HEARTBEAT_WINDOW` change (R2-DI-02), which is the sole residual. The
caller also cannot choose *which* epoch it appends: MEM-09(1) appends the lowest missing epoch and rejects an
entry for an epoch later than `e + 2`, so the target epoch — and hence I*(e) — is the contract's
(`03:471-475`, `03:481`).

**Is the coverage argument exact on a monotone height grid?** **Yes.** For a record at height A and a change
to W', the first boundary of the new grid strictly after A is `B = (⌊A/W'⌋ + 1)·W'`, with `A < B ≤ A + W'`
because `⌊A/W'⌋·W' ≤ A`. The entry may re-attest from any block whose window starts above A — i.e. from B, or
from the change block if the change lands after B (its window's start is then ≥ B > A) — so re-attestation is
always possible no later than `A + W'`, which is exactly the last instant the old record covers under W'
(`I*(e) ≤ A + W'`). Conversely, any version appended at `n < B` has `I*(e) ≤ L1_first(C(e)) ≤ n < B ≤ A +
W'`, so the old record still satisfies the predicate: a re-gridding can never exclude an incumbent before it
can act. Raising W' lengthens the covered interval, lowering it shortens it, and neither can lower a recorded
height (`(2a)(d)` compares absolute block numbers, not indices — the round-1 lockout is gone:
`03:536`, `03:539`, `03:546`). The worked case is stated in `03:545` and I re-derived it independently. ✓

**Does `hbWindow = hbWindowOf(block.number)` interact badly with the lookahead?** No. Acceptance names the
carrier's window (`03:534`); the record it writes is that window's start block (`03:539`); evaluation reads
the record against the derived I*(e) (`03:541`). The two grids are the same grid and both are block-height
based, so the lookahead's arithmetic (activation record, EPOCH_LEN_L1) and the window arithmetic never
convert through a clock. The predicate is satisfiable by construction: a version's I*(e) ≤ L1_first(C(e)) ≤
the append block, so a heartbeat accepted in window `w*(e)` — which begins at I*(e), at or before
L1_first(C(e)) — is available to every entry before its append. An entry that attests once per window is
eligible at every evaluation instant, which is the registered relation's promise (`03:545`); I verified the
arithmetic (the most recent window start at or before the append is ≥ I*(e) − W + 1). ✓

**Can the MEM-13(6) change-timing Open become a roster takeover rather than a one-version exclusion?** It can
become a *run* of versions (R2-DI-02), not a takeover: the incumbent re-enters at the first append after it
re-attests, it is never removed from the ledger or its stake, and the effect requires a parameter change plus
a drained backlog plus ordering control (F8's class). It is not permanent and not a share change inside any
committed version.

**Does the wall-clock variability of the window create a liveness or griefing path the seconds grid did not
have?** No, and it removes one. The grid and the epoch schedule share the L1-block clock, so the derived
instant, the acceptance window and the anchor bound (`≤ 256` blocks, the `blockhash` horizon) are all block
counts and need no clock conversion (`03:545`, `09:216`). L1 block intervals vary (missed slots), so the
*wall-clock* cadence of the duty varies — disclosed as cost (g) (`03:546`) — but the variation cannot
increase the duty's frequency: a block producer can only skip blocks, which *lengthens* a window in real time
and reduces the number of windows per hour; and a slowdown moves the epoch schedule and the grid together, so
neither I*(e) nor the predicate drifts. The seconds grid, by contrast, needed a stored per-epoch timestamp an
L1 contract cannot read (`03:531`).

**Round-1 fixes still in force (checked).** Absolute-instant acceptance guard `03:536` ("`hbWindow ·
HEARTBEAT_WINDOW > lastHeartbeatAt(v)`, with `HEARTBEAT_WINDOW` the value in force at the including block …
never on window indices"); non-zero key `03:528`, `03:135`, `03:113`, `09:217`; permanent retirement
`03:528` ("retirement is permanent — a key that has ever been retired MUST NOT be re-bound to any entry,
including the entry it was retired from"); one live entry per bonding address `03:135` ("an L1 account may
have at most one live entry — activating, active, exit-requested or unbonding — at a time, so a bond from an
account with a live entry MUST revert, and the signed payload of MEM-13(2), which binds that address as v,
therefore names exactly one entry"), with the payload using that address (`03:529`) and the register row
saying the same (`03:710`, `09:217`).

**Consistency of the derived instant elsewhere.** `02:441` (CONS-13(2)) states the roster is the active set
filtered "at the version's fixed evaluation instant … `I*(e) = ⌊L1_first(C(e)) / HEARTBEAT_WINDOW⌋ ·
HEARTBEAT_WINDOW` … computed from the activation record's block numbers — evaluated once inside the commit
call and never re-opened, with the call's own block and timestamp unable to change which entries the
predicate admits"; the M7 row `02:541` matches; MEM-09(1) `03:475` matches; the register row `09:213`
carries the height grid and the withdrawal of the never-re-labels claim; CONS-16/`T_ROTATE`/`T_ROTATE_DELAY`
remain tombstones and unread (`03:545`, `02:16`, `02:505-510`, `02:541`, `09:210-211`). The genesis
exemption (F2) is stated in `03:541` and CONS-14(1), and the first filtered version is `e_0 + 1` with
`I*(e_0+1)` = the window containing `L1_0` — no impossibility, because an entry can attest in that window
after activation and before the append, and a missed append is restorable (R2-DI-01 is the low-height
caveat).

**One nuance worth stating (not a finding).** The append clears the *entry-absence* boundary halt; it does
not make the appended roster reachable. Because the eligibility evidence is frozen at I*(e) — that is the
price of caller-independence — a missing version whose evaluation window precedes a stopped cohort's last
heartbeat will always yield an unreachable roster, and waiting cannot change it; the chain can therefore enter
the epoch and immediately halt on quorum. LIVE-05's attestation row (`10:321-323`) and MEM-13(5)
(`03:545`) disclose the quorum case and the immutability of committed rosters, and `02:463`'s "the halt
ends when that append is made" is about the boundary halt, so the artifact is consistent — but the increment's
recovery benefit is real only for cohorts that stopped before the version's evaluation window, and that is
worth one sentence in the disclosure.

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 2 | R2-DI-01 (unguarded eligibility predicate vs (2b); unreachable at the intended deployment, reachable on a low-height L1) · R2-DI-02 (the change-timing Open's "that one version" under-sizes a backlog-drain run, and the ordering-at-a-pending-change influence on I*(e) is unnamed) |

**Strongest attack: none.** I tried hardest to break the derived instant and the height grid and could not:
I*(e) is caller-independent on every ordinary path (late append, two appends in one block, same-window
append, epoch boundary), the coverage argument is exact integer arithmetic with the re-attestation boundary
`A < B ≤ A + W'`, the acceptance window and the evaluation window share one block-height grid so the
lookahead introduces no drift, and the wall-clock variability only reduces the duty's real-time frequency.
The round-1 High (R-INCR2-01) is properly repaired in both directions, and the round-1 fixes for the zero
key, permanent retirement and the one-live-entry identifier are in force.

**Is the increment safe to ship?** **Yes.** Neither Low is an attack or a safety, liveness or accounting
break: R2-DI-01 is a one-clause guard (`lastHeartbeatSeq(v) > 0`) that matters only on a chain whose
coverable L1 height is below `2 · HEARTBEAT_WINDOW`, and R2-DI-02 is a wording correction to an already-Open
residual plus one sentence naming the ordering case. I would ship the increment with those two edits and
record them as review closes.
