# Increment 5 round 2 — confirmation after the round-1 repairs

**Reviewer:** r6-gov-generations (task-69), independent adversarial reviewer.
**Snapshot:** `f29e33cc1` (working tree clean at claim). **Charge:** re-attack the entry lifecycle end to end,
re-check the single generation write and the two-case rule, and verify every round-1 repair by measurement —
the D-19 reproduction, the `TimelockNotElapsed` naming, the `W_root`/`MARGIN` rows, and the rebased
requirements baseline. **Method:** the delta is authoritative and the specification carries the applied rules;
all quotations/counts below are measured (tags stripped, entities unescaped, whitespace collapsed; "nospace"
removes all whitespace; "emphasis-stripped" also removes `*` and backticks).

**Counts: Critical 0 · High 0 · Medium 1 · Low 0.**
**Verdict: this is the second consecutive round with no Critical and no High — the increment is clean at the
bar and safe to ship.** Every round-1 repair is real and measured: D-19 is contained character-for-character
in §11 (with commentary that adds no decision); `TimelockNotElapsed` is one name in the rule, REC-02 and the
delta; `W_root` and `MARGIN` now have their own rows with units and an explicit distinctness note against
`MARGIN_D`/`MARGIN_V`; the requirements baseline carries all five added threats and zero "no recovery path".
The entry lifecycle is total — every state/action pair has exactly one named outcome — the generation has one
writer, the deadline is immutable and the executed state terminal. One Medium remains, and it is a
claim-versus-rule mismatch rather than a mechanism hole: the rule's own preamble and the delta's G-3 step
claim a **full-range discard** that makes the discarded branch **unlandable**, while the operative generation
checks constrain only the batch's **head** certificate, votes and header, so the provisional range can be
re-landed as the ancestors of a new head carrying the new generation.

---

## Finding R5R2-C-01 — Medium: "full-range discard / unlandable branch" is claimed but not enforced; the generation rule constrains only the head

**Severity: Medium.** One-line rationale: `GOV-04`'s preamble says the action performs "a full-range
**discard** of everything strictly above the latest L1-accepted checkpoint, and a signed generation increment
that makes the **discarded branch unlandable**", and the delta derives the unlandability from the premise
that a discarded block "would have to be the **head** of a batch extending the checkpoint"; but
`CONS-05(2)(a)` requires only the head certificate, the contributing votes and the **head header** to carry
the current generation, every other header legitimately carries the generation it was produced under
(`CONS-10(7)`: the generation is part of the header bytes), and no rule invalidates a block whose header
carries an older generation or forbids it inside a batch. A batch whose intermediate blocks are the
provisional range (headers `g`) and whose head is a new block produced under `g+1` therefore satisfies every
operative check and settles the "discarded" range. The enforced effect is narrower than the words: a
superseded certificate cannot serve as the **head** certificate of an extending batch — which is what the
rule's own attack list says ("a certificate of the discarded branch re-landed because the generation was not
signed (forbidden by (h) and CONS-05(2))") — while the range itself is not discarded and can be resumed and
landed by extending it.
**File + rule id.** `08:GOV-04` preamble (the quoted sentence) and its "what replaces what" summary;
`08:GOV-04(h)`; `02:CONS-05(2)(a)` ("… every contributing vote's generation equals it, and the **head
header's** generation equals it"); `02:CONS-10(7)` (`recovery_generation` is part of the header bytes of
**that** block); `05:PRF-05(ii)(a)` (the head certificate's three-way agreement) and
`05:PRF-04(i)`/`CONS-01(vii)` (the same, head only); `delta:8-13` (scope), `delta:581-620` §5.2 step 4
("To be re-landed it would have to be the head of a batch extending the checkpoint") and `delta:727`
("certificates of the current provisional range become void").
**Missing rule / correction:** state the effect exactly — the resolution resumes on the same chain, leaves
the checkpoint untouched, invalidates a superseded certificate **as a batch's finality evidence (head)
certificate**, and leaves the range above the checkpoint as valid chain history that a later batch may settle
by extending it under the new generation; or, if the full-range discard is intended, add the missing
**range-wide** generation rule (every header in an extending batch carries the current generation, or the
range above the checkpoint is not admissible as a batch's ancestors until a new head is produced from the
checkpoint) — which would be a substantive rule change and should be an owner decision.
**Assumptions.** None: the batch is constructed from the physical chain (the provisional range descends from
the checkpoint's head `H` by parent hash, so `PRF-04(v)`'s linkage holds), its head is produced under the
new generation, and the discarded tip's certificate is simply not presented.
**Attack trace.** (1) A stall is resolved (generation `g → g+1`; the checkpoint stays at `H`). (2) An honest
or captured producer builds a new block on the existing chain tip (all of whose headers carry `g`) and signs
it under `g+1`. (3) A prover presents a batch extending the checkpoint whose range is the provisional range
plus that head: the head certificate, the votes and the head header all carry `g+1` (CONS-05(2)(a) ✓), the
header chain links from `prevBlockHash` (`H`) ✓, and for an epoch-opening batch the anchor certificate is
`B_anchor`'s own `g` under CONS-05(2)(b) ✓. (4) The batch lands; the "discarded" range is settled. Nothing
in the rules forbids this, and no rule requires an intermediate header to carry `g+1`.
**Fault-model verdict.** Inside. No adversary is needed; the case arises from ordinary production after a
resolution. No rule is broken by the producer or the prover, and the guest's checks are all satisfied — the
defect is that the rule text claims a stronger effect than the checks enforce, which can make a validator
that reads the preamble reject a batch the rules make provable (a client divergence) and misstates the
action's power in the trust-model disclosure (governance appears able to erase above-checkpoint history,
which it cannot).
**Attacker cost.** None beyond ordinary block production.
**Requirement affected.** GOV-04's preamble/summary; delta §5.2(4) (the G-3 derivation's step 4); the
"resume-only" characterisation; REC-01's provisional-above-the-checkpoint statement.
**Evidence.** `08:GOV-04` preamble and (h); `02:CONS-05(2)(a)`, `02:CONS-10(7)`; `05:PRF-05(ii)(a)`;
delta §5.2(4) and line 727.

---

## The four round-1 repairs, verified by measurement

| Repair | Measurement | Verdict |
|--------|-------------|---------|
| D-19 reproduced in §11 | D-19 (heading included) is a contiguous substring of §11: `8,657` nospace emphasis-stripped characters contained in §11's `9,876` (the non-emphasis-stripped figures are the delta's own quoted `8,992`); the ~1,200 characters outside the quoted block are the correction note ("R5R1-G-02: the previous §11 claimed …"), the "decision of record is D-19" sentence and the block markers — **no additional or altered decision** | ✓ closed |
| `TimelockNotElapsed` one name | present in `08:GOV-04` (3), `06:REC-02` (2) and the delta (4); the other `Timelock` hits are the generic "(f) Timelock" heading/label; no second name for the same revert anywhere in `spec/`, `learn/` or the delta; it is not in `04`'s L1-08, exactly like the other six entry errors, whose only home is the rule's table | ✓ closed |
| `W_root` / `MARGIN` rows | dedicated table rows exist: label `W_root` | "seconds" | "Unset — no value is proposed; a symbolic term of the constructor-asserted window relation … It is the `W_root` term of `T_GOV_RESUME ≥ W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN` … now has its own registered row"; label `MARGIN` | "seconds" | "Unset — no value is proposed; a stated, unmeasured margin, not a measured quantity … **It is distinct from the HALT-03 margins `MARGIN_D` and `MARGIN_V`**" | ✓ closed — GOV-04(g)'s assertion now has evaluable, distinct operands |
| Requirements baseline | `01-requirements-and-threat-model.md`: "governance liveness" 5, "unprotected"/"above the checkpoint" 3/5, "churn" 4, "arrivals" 4, "enumeration residual" 4, "F-FI-8" 3, "F-GOV" 13, and **0** occurrences of "no recovery path" | ✓ all five added threats visible, rebased wording in place |

## The entry lifecycle, re-attacked end to end

The applied rule's table (`08:GOV-04(d)`) has four rows (`none`, live `queued`, void `queued`,
`executed`) and, with the clauses, an outcome for every caller/ordering; "No other transition exists" and no
path writes the generation outside the successful `execute()` row. Each attack in the angle maps to exactly
one named outcome:

| Caller / ordering | Outcome | Reachable? |
|---|---|---|
| `queue()` in `none` | allowed iff the trigger holds → `queued`, four fields written | yes |
| `queue()` while live `queued` | reverts `EntryPending` | yes |
| `queue()` while void `queued` | allowed iff the trigger holds; replaces the void entry with a **new** entry (fresh fields, fresh stored deadline) | yes |
| `queue()` in `executed` | allowed iff the trigger holds; starts a **fresh** entry (the disclosed consumption-only churn, F-GOV-3) | yes |
| `execute()` in `none` | reverts `NoQueuedEntry` | yes |
| `execute()` on void `queued` | reverts `EntryVoid` | yes |
| `execute()` on live `queued` before the deadline | reverts `TimelockNotElapsed` | yes |
| `execute()` on live `queued` at/after the deadline | consumes the entry: generation **+1 exactly once**, state `executed`, event | yes |
| `execute()` in `executed` (re-execute) | reverts `EntryAlreadyExecuted` for every caller, every block, every calldata | yes |
| `cancel()` on void `queued` | allowed for any account → `none`, fields cleared | yes |
| `cancel()` on live `queued` | reverts `EntryNotVoid` | yes |
| `cancel()` in `none` or `executed` (incl. cancel-after-execute) | reverts `NothingToCancel` | yes |

No state is unreachable (`none` is the initial state; `queued` from `queue()`; void `queued` from progress;
`executed` from `execute()`) and none is unnamed. **Single write:** the only path is the live-`queued` →
`executed` transition in the same transaction that sets `executed`; the specification repeats "by exactly
one … and by nothing else" in 01, 04, 05, 08 and 09. **Deadline:** written once at queue time, read by
`execute()`; no upgrade, initialiser, parameter change, governance call or client may move/shorten/extend/
recompute it, and a `T_GOV_RESUME` change applies only to entries queued after it. **Re-open:** no upgrade
may set an executed entry back to `queued`/`none`, and none may reset, lower or skip the generation.
**Reorg:** the execution and the state carry with L1 (SM-6): a reorged-out execution returns the entry to
`queued` with its stored deadline and the generation to its prior value; a reorged-out acceptance un-voids a
live entry; no partial state and no duplicated or lost increment.

## The two-case generation rule, re-walked

- **First post-resolution epoch-opening batch.** `B_anchor` is the block at `prevHeight = lastLandedHeight`
  (at or below the checkpoint by construction), pinned by `prevBlockHash`; its header carries `g`, and its
  certificate is judged under **its own header generation**, never compared with `g+1`
  (`CONS-05(2)(b)`, `PRF-05(ii)(a)`); the batch's own head certificate, votes and head header carry `g+1`
  (`CONS-05(2)(a)`, `PRF-04(i)`). Two different objects, both satisfiable in one proof. Repeated
  resolutions do not change `B_anchor`'s immutable header bytes, so the anchor case is judged under the same
  `g` however many resolutions run; an L1 reorg carries the generation with it. **Holds.**
- **A batch spanning the resolved boundary.** The head-only scope of `CONS-05(2)(a)` is what leaves the
  range landable as ancestors — R5R2-C-01. The *certificate-generation comparison cannot be made against the
  wrong object* in a guest implementation: the two cases are stated as disjoint (`(a)` for a batch extending
  the checkpoint, `(b)` for a block at or below it), `(b)` says explicitly "MUST NOT be compared with the
  generation the Inbox holds", and `PRF-05(ii)(a)` repeats the anchor's own-header rule; a guest that
  compared the anchor against the journal's generation would contradict the text on its face. **Holds.**

## Plainly, and what would falsify it

**No input, ordering or block content leaves a position unresolvable, and nothing advances the generation
twice**, within the stated premises: the lifecycle is total with one named outcome per caller/ordering, the
generation has one writer and one increment per executed entry (a reorged-out execution never took effect),
the void/replace/cancel lattice cannot strand or block an entry, the stored deadline and the executed state
are outside every writer's reach, and the two-case rule makes the first post-resolution epoch-opening batch
provable and keeps it provable under repetition and reorg. **What would falsify this conclusion:** (i)
F-GOV-1 — governance never queues or never executes (the stall persists; no rule can bound it); (ii) F-GOV-2 —
the window relation's unmeasured terms or an unfunded proving market/unretained inputs (`MEM-15(2b)`) break
the exit-window guarantee the relation is supposed to size; (iii) F-GOV-5/F-GOV-6 as carried; and (iv) the
R5R2-C-01 question if the owner *intends* the discard to be enforced — then a range-wide generation rule is
missing and "unlandable" would need to be made true rather than reworded.

## Summary for the lead

| Severity | Count | Findings |
|----------|-------|----------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 1 | R5R2-C-01 (the rule's preamble and the delta's G-3 step claim a full-range discard/unlandable branch; the operative generation checks constrain only the head certificate/votes/header, so the provisional range can be re-landed as ancestors of a new head — reword, or add the range-wide rule if the discard is intended) |
| Low | 0 | — |

**Strongest attack: R5R2-C-01** — not against the mechanism's safety but against the accuracy of what it
claims: after a resolution the provisional range is not discarded and is not unlandable; it is settled by
extending it with a head produced under the new generation. It is one sentence to reword (or one owner
decision to add a range-wide rule).

**Is the increment safe to ship?** **Yes — 0 Critical and 0 High for the second consecutive round.** All four
round-1 repairs are verified by measurement, the entry lifecycle is total, the generation write is single and
reorg-safe, and the two-case rule is sound for the first post-resolution epoch-opening batch. Fix R5R2-C-01's
wording (or make the discard real) in the same pass; nothing else was found.
