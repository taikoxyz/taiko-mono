# Review round 6 - frozen snapshot

**Snapshot:** `7917ba264` (branch etna-pos-zk, PR #22262)
**Rounds used:** 6 of 8 - **Consecutive clean rounds:** 0

## Feature set is FROZEN for this round: repairs only, no new mechanisms

Since round 5 (4 Critical, 19 High, 12 Medium, 4 Low) the following changed:

1. **D-15 - the permissionless recovery is withdrawn entirely.** The bond, escalation, cooldown, completion reward, certificate bundle, maximality proof, retirement record, recovery anchor and the retired-height lock carve-out are gone. In their place: `GOV-04`, a timelocked, resume-only governance stall resolution with void-on-progress and a permissionless bondless cancellation, and one **generation counter carried in the SIGNED vote and header bytes** (the fix for round 4's 'generation binds the proof, not the history'). Locks, signing uniqueness and conflict detection are all generation-scoped - one mechanism, not three.
2. **Round-5 Criticals repaired.** D-12's cap is restated in enforcement units (`FI_MAX_TX_PER_RECORD`, `itemGasBound`), `FI_ANCHOR_MAX_AGE` bounds anchored-view staleness, `publish` verifies recorded hashes against `BLOBHASH` element-wise, `settledAfter` is bounded. D-14's heartbeat signs a window index and sequence; eligibility is recorded from the named window, never the carrying transaction's timestamp.
3. **Cumulative sweeps.** The course, the register and the index were swept for withdrawn mechanisms; the register audit now passes in both directions with every withdrawn row carrying a MUST-NOT-USE reason.

**161 rule ids**; 0 broken links or anchors; every id has an index row.

## What a reviewer should attack

The two mechanisms added today (`GOV-04`, the signed generation binding) have **never been reviewed**, and the round-5 repairs have not been re-attacked.