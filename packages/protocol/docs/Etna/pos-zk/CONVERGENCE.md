# Convergence record

**Verdict: the v1 design is CONVERGED.**

Convergence was defined before the fact, in `PLAN.md`: **two consecutive review rounds, each with no Critical and no High.**
It is now met:

| Round | Critical | High | Medium | Low | Size |
|---|---|---|---|---|---|
| 4 | 4 | 14 | 12 | 4 | full design, Mode B |
| 5 | 4 | 19 | 12 | 4 | full design, Mode B repaired |
| 6 | 2 | 11 | 13 | 6 | full design |
| 7 | 2 | 10 | 12 | 6 | core + deferred register (D-16) |
| 8 | 0 | 3 | 7 | 15 | core, first pass |
| **9** | **0** | **0** | 1 | 8 | **CLEAN** |
| **10** | **0** | **0** | 0 | 2 | **CLEAN - confirmed** |

Every reviewer in rounds 9 and 10 answered that they would build on the specification, and two of
the eight reports found nothing at all. The two Lows in round 10 are copy-edit grade and are being
closed without a further round: a course field table that omits `recovery_generation`, and a
prefix-effect sentence in ECON-02(5)(d) that reads over the pending prefix and needs four words
changed. Neither touches a mechanism.

## What converged

**v1 ships the core.** L1-anchored PoS sequencing with TAIKO stake on L1; validity-proof settlement
with the batch data bound by the accepting transaction, carried or referenced through a publication
record (D-11), including the proving deadline; the checkpoint **boundary** (nothing at or below the
latest L1-accepted checkpoint is ever rewritten; above it is provisional); the **exit** from the last
settled state with both dependencies named and falsified; k-of-n withdrawal roots as k attestations
from distinct backend families, funded best-effort and never gated by payment; the rule-triggered
self-expiring withdrawal veto; a **constant** signed recovery generation scoping certificates, locks,
signing uniqueness and conflicts.

**Three absences are disclosed rather than papered over:** no inclusion obligation (the censorship
gap), **no recovery path of any kind** (a settlement stall halts the chain; clearing it needs a future
protocol update whose procedure is not yet specified), and single-backend settlement soundness.

**Four mechanisms are deferred and tombstoned**, each with its blockers and revive criteria in
`DEFERRED.md`: narrow forced inclusion, heartbeat eligibility, the governance stall resolution, and
aggregation. Every tombstone carries a MUST-NOT-USE reason; no live rule reads one.

> **Increment note (added after convergence).** This record states what v1 was when it converged in
> rounds 9 and 10, and v1 remains converged in every respect increment 2 did not change. Increment 2
> revived **MEM-13** heartbeat eligibility as a live rule and did **not** revive **CONS-16**, which
> remains deferred and tombstoned (D-17). The deferred set is counted **by mechanism with its own rule id**,
> and increment 4 has since moved forced inclusion out of it, so the current set is **three: CONS-16's
> rotation, the governance stall resolution and aggregation** - see the second note below - while the
> four-mechanism sentence
> above is the converged-state record, not the current one.
>
> **Increment 2 has since SHIPPED** (rounds 2-4 of its own review; see `increments/02-ship-record.md`).
> It reached the same bar v1 did - two consecutive rounds with no Critical and no High - and round 4
> re-confirmed the artifact after round 3's Medium changed the rules. `MEM-13` heartbeat eligibility is
> now a live rule: an L1 heartbeat key, an L1-block-number window grid, a **derived and caller-independent**
> evaluation instant, a guarded predicate, exclusion that never reduces weight, and a launch transition
> whose counting window starts at or after the activation block with full length. **CONS-16 remains
> deferred**, so the recovery gap and the F8/F9 falsifiers stand.
>
> **Increment 4 - narrow forced inclusion - has since SHIPPED** (see `increments/04-ship-record.md`). It
> reached the same bar: **two consecutive clean rounds** (rounds 5 and 6, after four rounds that produced
> six Criticals - every one the class of two clauses individually true and jointly false, and every one
> created by a repair rather than by the design). Round 5's Medium changed rule text, so round 6
> re-confirmed the fixed artifact rather than shipping on the pair as it stood.
> Until then the sentences above describing forced inclusion as merely designed are the increment-2-era
> record, not the current state. **And of the three absences recorded at convergence, the first is now
> addressed and shipped**: a narrow inclusion obligation (FI-10..FI-14) is now live in the specification,
> so "no inclusion obligation" describes v1 as it converged, not the current draft. **The other two stand
> unchanged**: there is still **no recovery path of any kind**, and settlement soundness still rests on a
> single proof backend. The **deferred set is now two mechanisms plus the rotation within increment 2**:
> aggregation (increment 3, gated on Phase B's S1 measurement) and the governance stall resolution
> (increment 5, last), with `CONS-16`'s rotation still gated on an L1-verifiable h_close. **Increment 3** remains gated on Phase B's S1 measurement - its
> aggregation parameters cannot be set before that cost is measured - and **increment 5**, the governance
> stall resolution, is last.

## What convergence does NOT mean

1. **Not that the design is implemented.** No code exists. The specification is the deliverable.
2. **Not that the parameters are known.** Every unmeasured parameter remains a tagged placeholder.
   Phase B's measurements gate any implementation and none has been run.
3. **Not that the disclosed Open items closed.** The route and family inventory, the exit's
   proving-market assumption, the `t_observed(e)` anchor (ECON-07 marks its consequence
   MUST-close-before-launch), and the S1 costs are launch gates, not rule defects.
4. **Not that the deferred work is done.** It is parked, with its blockers named - which is the
   difference between deferred and forgotten.

## The honest residue of the process

Of the five Criticals in rounds 4 to 6, **three were introduced by repairs the lead directed** - the
fee-sweep fix, the claimed retirement endpoint, and the anchor-age gate. All three were caught by
review rather than by the repair that caused them, which is why the plan now requires every repair
to be re-checked against what it changed, and why the deferred mechanisms must not return without
their own review cycles.