# Increment 05 round 1 — the boundary and everything shipped

**Reviewer:** independent adversarial reviewer, increment 5 round 1, angle boundary-and-shipped. **Snapshot:** 1cd1dd6af, extracted with git archive.

**Counts: Critical 0 · High 0 · Medium 0 · Low 2.**

The resolution is boundary-clean against everything shipped: REC-01's guarantee at or below the checkpoint survives literally, the action writes no checkpoint or history object, exactly one rule-bound replacement path exists above the checkpoint, the heartbeat and forced-inclusion mechanisms are untouched, and the exit from the restored checkpoint stays permissionlessly attestable. The two Lows are register/delta bookkeeping on the flags carried into this round.

---

## F1 — Low: W_root and MARGIN are terms of a normative relation with no register rows of their own

**Severity: Low.** Rationale: the window relation T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN is a constructor-time assertion, and PARAM-01's discipline is one registered spelling per named term with its owner. Both terms do appear in the register, but only inside other rows: W_root is defined inline in the T_GOV_RESUME row (09:304), and the term set is registered as a measurement obligation in a grouping row (09:447, "The window relation's terms (W_root, WITHDRAWAL_DELAY, T_VETO, MARGIN) ...", Phase B, all symbolic and unmeasured). A reader cannot open a row for W_root or MARGIN the way every other parameter has one, and a budget or audit tool that enumerates rows will not see them.

**File + rule id.** spec/09-parameters.html rows T_GOV_RESUME (09:304) and the measurement-registry row (09:447); spec/06 REC-02's window row (the relation itself).

**Assumptions.** None. **Attack trace.** None (register discipline). **Fault-model verdict.** N/A. **Attacker cost.** None.

**Requirement affected.** PARAM-01's one-row-per-term discipline; F-GOV-2's measurability.

**Suggested repair.** Add rows for W_root and MARGIN (owner: REC-02/Phase B; unit: seconds; relation: the window inequality; tag: unmeasured), or state in the grouping row that these two terms are registered there and nowhere else. Either closes the discipline.

**Evidence.** grep: no "|ROW| W_root" or "|ROW| MARGIN"; occurrences at 09:304, 09:447, REC-02's window row, spec/10:347.

---

## F2 — Low: the delta still names one case twice (NoQueuedEntry vs EntryAlreadyExecuted)

**Severity: Low.** Rationale: the implemented spec resolves the case cleanly — none reverts NoQueuedEntry, executed reverts EntryAlreadyExecuted for every caller in every block with every calldata, live queued reverts EntryPending, void queued reverts EntryVoid — but the design delta keeps two tables that disagree: its state table lists all four errors including EntryAlreadyExecuted, while its later grouped table lists EntryPending, NoQueuedEntry and EntryVoid without EntryAlreadyExecuted, i.e. it groups executed with none under one name. The flag carried into this round is therefore closed in the artifact and open in the delta.

**File + rule id.** increments/05-governance-design.md, the two error tables (the four-error table vs the grouped table); spec/08's state table as the correct mapping.

**Assumptions.** None. **Attack trace.** None (documentation). **Fault-model verdict.** N/A. **Attacker cost.** None.

**Requirement affected.** Delta/spec naming consistency; the round's flag (a).

**Suggested repair.** Delete the grouped table's NoQueuedEntry for the executed case or mark it superseded, so the delta names the case once.

**Evidence.** delta line numbers of the two tables; spec/08's table (none -> NoQueuedEntry, executed -> EntryAlreadyExecuted).

---

## Seam checks against everything shipped (both sides read)

1. **REC-01 survives literally, and exactly one replacement path exists.** REC-01: "No contract function, client rule, timeout, validator rotation, admission rule, governance proposal executed through the ordinary upgrade path, operational procedure, or recovery invocation may change the canonical history at or below the latest L1-accepted checkpoint"; above it, "history is provisional and may be replaced only by the executed stall-resolution action of GOV-04 (analysed in REC-02)". The increment note says "the one named replacement path above the checkpoint is the revived, rule-bound stall resolution", with the permissionless recovery withdrawn, aggregation deferred, forced inclusion an inclusion rule that replaces no history, and the heartbeat a selection filter. Count: exactly one. PASS.
2. **The action writes nothing at or below the checkpoint and no history object.** REC-02's boundary row: execution "discards only history strictly above the latest L1-accepted checkpoint ... and writes no checkpoint, height, state root, set or resume record. The checkpoint after execution is exactly that record, untouched; nothing at or below it is read, written, re-judged or discarded." The entry fields written are the entry's own (state, deadline) plus the generation. PASS.
3. **Increment 2 untouched.** No row of REC-02 reads a heartbeat record or changes roster composition; the resumed chain's set is the checkpoint's set, which is L1 state the action does not touch; the generation rule concerns vote and header generations only, and MEM-13's predicate reads none of them. REC-01 classifies the heartbeat as "a selection filter on future set versions, not a path that replaces history". PASS.
4. **Increment 4 untouched, FI-14's non-interaction holds.** REC-02's D5/D-11 row: the action "may neither create, suppress nor re-deadline a publication record; the live forced-inclusion obligation survives it unchanged (FI-14(2))". spec/04 states the same from its side: the resolution "leaves the record untouched", the no-gate/no-expiry admission rule is unchanged, and the linkage is the ordinary one (REC-04). The settlement frontier c is the checkpoint's own settledCount, and the checkpoint is untouched, so c, the register, the prune cursor, deadlines and forcedBoundary are not reset; the discarded range above the checkpoint is the sanctioned replacement, not an FI read. PASS.
5. **The exit survives execution.** REC-02's window row: for a signal at or below the checkpoint at queue time, the exit of MEM-15 "from that checkpoint — including the root of L1-13, attestable for any already-accepted checkpoint with no new L2 block and no settlement progress, its delay on the L1 clock from the root's own record — remains available before, during and after execution", required length T_GOV_RESUME >= W_root + WITHDRAWAL_DELAY + T_VETO + MARGIN, conditional on MEM-15(2b). Class-A value is protected and class-C value above the checkpoint is stated unprotected with resubmission and no compensation. PASS.
6. **The three states and the single writer.** none/queued/executed with no cancelled state; queue allowed from none, executed, or a void queued entry; a second queue while a live entry is queued reverts; execute() reverts unless exactly queued, before the stored deadline, or on a void entry; on success it increments the generation by exactly one and sets executed atomically, writing nothing else; in executed every later execute() reverts for every caller in every block with every calldata; a void entry is cancellable or replaceable, so it cannot block a later entry. Void-on-progress sets void when the checkpoint advances. The generation has exactly one writer. PASS.
7. **The two-case generation rule.** A batch extending the checkpoint carries the current generation; a certificate at or below the checkpoint carries that block's own header generation and MUST NOT be compared with the current one; B_anchor's certificate is judged under B_anchor's own header generation while the head certificate carries the new one, and the anchor value is pinned by prevBlockHash, not witness-supplied. No generation is stored in the checkpoint record. PASS.
8. **Slot 268's obligation.** spec/08 states "268's packed group, whose re-derived layout is the migration audit's explicit open obligation above" and elsewhere enumerates slot 268 among the migration slots without asserting a layout; I found no place that assumes the group's shape, and the obligation is stated where the budget is described. PASS (the two remaining mentions are slot enumerations, not layout claims).

## Verdict

**Clean at the bar: Critical 0, High 0, Medium 0, Low 2.** The resolution interacts with the boundary, the heartbeat, forced inclusion and the exit exactly as the increment claims: nothing at or below the latest accepted checkpoint is read, written or rewritten; exactly one rule-bound replacement path exists above it; FI-14's non-interaction is stated from both sides; the exit remains available from the restored checkpoint with no new L2 block or settlement progress; and the generation rule is two-case with a single writer. **Safe to ship:** yes — F1 and F2 are registration/documentation edits (two rows, one table), not rule changes, and neither touches the mechanism.
