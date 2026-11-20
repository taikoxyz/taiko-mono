# Increment 5 - ship record (the governance stall resolution)

**Verdict: increment 5 has met the convergence bar and ships.**

The bar, set in `PLAN.md` before the fact: two consecutive review rounds with no Critical and no High.

| Round | Critical | High | Medium | Low | Verdict |
|---|---|---|---|---|---|
| 1 | **0** | **0** | 4 | 7 | clean |
| 2 | **0** | **0** | 1 | 6 | clean - confirmed |

Round 1 was the first OPENING round in this programme in which a new mechanism produced no Critical and
no High - and it is the mechanism that rewrites history if it is wrong. For contrast, the same four
angles in increment 4's opening round produced four Criticals. The difference is not luck: this design
was re-derived against the converged specification rather than restored from its tombstone, and the three
Criticals that deferred it were closed BY DESIGN before a reviewer saw it.

## What ships

**A timelocked, resume-only stall resolution (`GOV-04`, with `REC-02`/`REC-03`/`REC-04`).** A queued
entry advances the signed recovery generation **exactly once** when it executes, and the action
**resumes settlement; it does not erase**. It leaves the checkpoint and everything at or below it
untouched, invalidates a superseded certificate **only as a batch's head evidence**, and leaves the
range above the latest accepted checkpoint as **valid history that can be extended under the new
generation** - no rule invalidates a block for the generation in its own header.

**The entry state machine** is `none`/`queued`/`executed`, with `execute()` requiring `queued`,
`executed` terminal, and every caller and ordering having exactly one named outcome. There is **one
writer of the generation**, exactly one increment per executed entry, and the stored deadline is written
once and immovable. A reorged-out execution returns the entry to `queued` and the generation to its
prior value, so nothing is double-counted. A void entry is cancellable or replaceable and can never
block a later one.

**The generation rule is two-case**, which is what makes the first post-resolution epoch-opening batch
provable: the head certificate, the contributing votes and the head header of a batch extending the
checkpoint carry the **current** generation, while a certificate at or below the checkpoint - including
`B_anchor`'s - carries **that block's own header** generation, pinned to L1 by `prevBlockHash`, and
MUST NOT be compared with the current one. `cert_hash` must recompute into `epoch_anchor`. Two checks,
two different objects.

**Nothing that shipped earlier is reopened.** v1's boundary: `REC-01` survives literally at or below the
checkpoint, naming exactly ONE replacement path above it. Increment 2: no rule reads a heartbeat record,
and the resumed epoch's set is the checkpoint's set. Increment 4: `FI-14(2)` holds - the action may
neither create, suppress nor re-deadline a publication record, and the frontier, prune cursor, deadlines
and `forcedBoundary` are untouched. The exit stays available from the last settled state, and the
restored checkpoint's root stays permissionlessly attestable before, during and after execution.

## What it does not do, stated with it

**The window is a notice window.** `T_GOV_RESUME` is the notice window, and an exit window only for
signals **already messaged at or below** the last accepted checkpoint, as a registered relation over
`W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN` (unmeasured, constructor-asserted, conditional on
`MEM-15(2b)`).

**Value above the checkpoint is unprotected** - and for a narrower reason than erasure: the user's
signals are not carried into the settlement the resumed chain produces, so they are resubmitted, with no
compensation. The rule says this plainly rather than implying governance can erase the range.

**It creates no offence and moves no money.** The recovery-completion reward and the recovery bond names
stay withdrawn; no offence is created or revived.

**Falsifiers, with their classes:** F-GOV-1 Open (governance liveness, no protocol bound), F-GOV-2 Open
(the unmeasured window relation and `MEM-15(2b)`), F-GOV-3 Disclosed (governance churn - the churn rule
is consumption-only, because the progress-earned candidate deadlocks the certified-but-unprovable case
and L1 cannot decide `h_close`), F-GOV-4 Disclosed (future-entry parameter discretion), F-GOV-5 and
F-GOV-6 Open (implementation-verified).

**One obligation is deliberately open:** `MIG-02` slot 268 must carry a stored `govResumeExecutableAt`
written once at queue time and read by `execute()`. The packing and the declaration count are the
**migration audit's explicit obligation** and are NOT assumed to fit - the register says so, and the
migration budget is labelled pre-increment pending that audit.

## What changed after the confirmation round - stated, not glossed

Two reviewers verified that the post-round-2 corrections left every **operative check** unchanged. The
one Medium (`R5R2-C-01`) corrected an OVERSTATEMENT in the rule's preamble: it claimed a full-range
discard and an unlandable branch, while the enforced checks constrain only the batch's head evidence.
The correction makes the claim match the checks - the checks themselves were not altered, and no MUST
was added, removed or weakened. The remaining post-round corrections were documentation and course text.
That is a lighter basis than v1 and increment 2 had (where the post-clean-round fix changed a
predicate), and it is named here rather than left for a reader to infer.

## What this increment demonstrated

Increment 4 produced six Criticals, every one created by a repair, in an artifact whose mechanism was
sound from the start. Increment 5 produced none - and the reason is visible in what was done differently:
the mechanism was **re-derived against the converged specification** rather than restored, the three
Criticals that had deferred it were closed **by design** (a consuming state machine, a withdrawn claim
instead of a defended one, and a two-case generation rule), and the delta was written with the
**falsifier classes and the honest limits** alongside the guarantees. The reviews still found plenty
- four Mediums and seven Lows in round 1 - but every one of them was documentation, register or course
text, and none was a defect in the mechanism.