# Review round 7 - frozen snapshot

**Snapshot:** `296f44b54` - **Rounds used:** 7 of 8 - **Consecutive clean:** 0

## The design is now the v1 core (D-16 / Option A)

**Shipped:** L1-anchored PoS sequencing with TAIKO stake; validity-proof settlement with data bound carried or referenced through a publication record (D-11) including the proving deadline; the checkpoint boundary (nothing at or below the latest L1-accepted checkpoint is ever rewritten; above it is provisional); the exit from the last settled state (MEM-15, with its clause (2a) resolution: a root for the last accepted checkpoint is k attestations of its existing statement, permissionless, needing no new L2 block and no settlement progress); k-of-n withdrawal roots at one verification per attestation; the rule-triggered withdrawal veto; the signed recovery generation scoping certificates, locks and uniqueness.

**Deferred and tombstoned (D-16, see DEFERRED.md):** narrow forced inclusion (FI-10..FI-14, CONS-01(v)); heartbeat eligibility (MEM-13, CONS-16, the heartbeat parameters); the governance stall resolution (GOV-04, REC-02..REC-04 as a recovery path); aggregation (PRF-15, L1-14).

**Disclosed as absent in v1:** any inclusion obligation (the censorship gap); any recovery path of any kind, so a settlement stall halts the chain and clearing it needs a future protocol update whose procedure is not specified; multi-backend settlement soundness (one proof from one registered backend).

## What round 7 must decide

Six rounds produced 2-4 Criticals each, and every one of them sat in a mechanism that is now deferred. **The core has been re-attacked in six rounds and has never broken.** This round asks the question that matters: is the smaller design, as written, implementable and sound - and are its absences disclosed everywhere they matter?

Round 7 also verifies the rollback itself: that no rule still reads a tombstoned mechanism, that every deferred guarantee is disclosed where it used to be promised, and that the course teaches what the specification now says.