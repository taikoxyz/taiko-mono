# Review round 5 — frozen snapshot

**Snapshot:** `7759eb269` (branch `etna-pos-zk`, PR #22262)
**Date:** 2026-10-06
**Rounds used:** 5 of 8 · **Consecutive clean rounds:** 0
**Mode:** D-7 Mode B, with the recovery mechanism repaired after round 4

## What is new since round 4 (`fe7373a13`)

Round 4 found 4 Critical and 14 High. Since then:

1. **Two D2-blocking Criticals repaired.** The recovery authorization was a tautology; discarded
   heights are now **permanently retired** on L1 (`REC-02`, `REC-04`), and `resumeHeight` is
   **derived on L1 from a verified certificate bundle**, never claimed by the invoker. The fee
   sweep contradicted `PRF-06`; the predicate is now an exact in-guest reconciliation (F1–F4).
2. **D-11 — data may be published before the proof.** Publication record, proving deadline,
   referenced-vs-carried binding (the point-evaluation precompile is **not** transaction-scoped;
   only `BLOBHASH` is).
3. **D-12 — narrow forced inclusion ships in v1.** `FI-10`–`FI-14`, capped FIFO prefix with a
   no-permanent-halt argument, breach at the **due point**, enforced in `PRF-04(vi)`.
4. **D-13 — one proof object, n-of-m aggregated underneath.** `L1-13`, `L1-14`, `PRF-15`.
5. **D-14 — no rule removes weight.** The inactivity decay is withdrawn; eligibility for a future
   set version requires an **L1 heartbeat**. F5 resolved, F6 closed, **F8 Open**.
6. Plus: k-of-n withdrawal roots, a rule-triggered withdrawal veto, an L3 exit guarantee from the
   last settled state (`MEM-15`), and a corrected modular-reduction bias (`2^-254.9`).

The specification has **160 rule ids**; the tree has 0 broken links and every rule has an index row.
