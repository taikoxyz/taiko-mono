# Increment 2 - ship record (heartbeat eligibility)

**Verdict: increment 2 has met the convergence bar and ships.**

The bar, set before the fact in `PLAN.md`: two consecutive review rounds with no Critical and no High. For an increment the bar applies to the increment.

| Round | Critical | High | Medium | Low | Verdict |
|---|---|---|---|---|---|
| 1 | 0 | **2** | 2 | 5 | not clean |
| 2 | **0** | **0** | 2 | 6 | clean |
| 3 | **0** | **0** | 1 | 2 | clean |
| 4 | **0** | **0** | 0 | 2 | clean, on the fixed artifact |

Rounds 2 and 3 are the two consecutive clean rounds. Round 3 nevertheless produced a Medium that
changed the rules - the launch transition's counting window was full in duration only - so the clean
pair certified the pre-fix artifact. Round 4 therefore re-confirmed the fixed artifact and came back
clean at every severity. Shipping on rounds 2 and 3 alone would have been a technicality.

Every reviewer in rounds 3 and 4 answered that the increment is safe to ship, and three of the eight
reports in those rounds found nothing at all.

## What ships

**MEM-13, heartbeat eligibility.** An ECDSA heartbeat key registered at bonding, distinct from the
Ed25519 consensus key, owner-rotatable forward-only, permanently retired once rotated away and never
re-bindable. The payload binds a versioned domain tag, the chain id, the entry, a window index, a
strictly increasing sequence and a recent L1 anchor block number and hash.

**The window is an interval of L1 block numbers**, not wall-clock seconds. Acceptance requires the
named window to be the carrying block's window, and the recorded eligibility point is that window's
**start block** - never the carrier's timestamp, so a signature cannot be replayed or refreshed by
submitting it later.

**The evaluation instant is derived, not stored.** For the version committed for epoch e, with
C(e) = max(e - LOOKAHEAD_EPOCHS, e_0) and L1_first(C(e)) = L1_0 + (C(e) - e_0) * EPOCH_LEN_L1, the
instant is I*(e) = floor(L1_first(C(e)) / HEARTBEAT_WINDOW) * HEARTBEAT_WINDOW, computed inside
commitSet() from the activation record. No writer, no keeper, no oracle, no past-block timestamp read,
and the same value for two calls in one block: nothing a caller can time.

**The predicate is guarded:** eligible if and only if `lastHeartbeatSeq(v) > 0` **and**
`lastHeartbeatAt(v) >= I*(e) - HEARTBEAT_WINDOW`. Ineligible entries are excluded from R_k, TotalVP_k
and n_k - never decayed, slashed or removed - and re-attesting restores eligibility. If no active
entry is eligible, commitSet() reverts and the append is missed.

**The launch transition** shifts the instant two windows for exactly the two epochs whose clamp
resolves to e_0, so the counting window starts at or after the activation block with full length
wherever the activation block falls, and those entries MUST NOT be appended before it closes. A
prepared entry can no longer win a block race and fix the first two filtered rosters. The cost is
disclosed: the first two filtered appends are gated by up to two windows, and the launch halt is
guaranteed and runs between W - E + 1 and 2W - E blocks plus finality - up to two recovery cycles.

## What does not ship, and the honest limits

**CONS-16, the rotation, stays deferred and tombstoned.** Its precondition h_close - the highest height
produced in a stalled epoch - is an L2 fact that L1 cannot pin; a completer would supply it as an
unverifiable claim that re-judges a produced height and makes its certificate unverifiable. So a
quorum-loss halt inside an unreachable epoch still clears only if the committed cohort returns to
vote, or by a future protocol update. That gap stays disclosed.

**Falsifiers carried, not smoothed over:** F8 (an adversary able to censor, delay past the window or
price out honest L1 heartbeats excludes honest validators at no slashable cost and can raise its own
share), F9 (the bounded pre-signing horizon), the change-timing Open (a pending HEARTBEAT_WINDOW
change can exclude a contiguous run of versions, and is the sole remaining caller influence), and the
wall-clock variability of the window (the duty is one attestation per HEARTBEAT_WINDOW L1 blocks, not
per fixed duration - unmeasured).

**The declared non-fix:** a declaration of presence is not proof of participation. A cohort that keeps
heartbeating keeps its weight. This rule changes who is selectable; it never changes what a committed
version requires.

## What this increment demonstrated

The process works on a new mechanism, not only on the original design. Its first round produced two
Highs - a caller-timed commit that would have let an adversary hold 100% of an epoch's quorum
denominator with sub-third stake, and a parameter-change trap that could reach a halt v1 cannot
clear. Both were caught in the increment's FIRST round, because reviewers were charged with attacking
the boundary between the new mechanism and the converged v1 - which is where the defects live.

Three times an agent improved on the lead's instruction rather than executing it: one showed that
shifting the launch instant without coupling the append opening leaves the capture open; one refused
to propagate a false arithmetic claim the lead had written into its brief; and one found and fixed
three further passages beyond the four it was given. That is now the standing expectation.