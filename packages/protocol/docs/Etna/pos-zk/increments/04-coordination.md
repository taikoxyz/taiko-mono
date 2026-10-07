# Increment 4 - coordination decisions

Raised by the register/index/disclosure implementer before its edits landed. These are owner calls;
the reconciliation pass applies them after all three implementers finish.

## 1. The deferral count convention

**Decision: adopt the design delta's convention.** After increment 4 the deferred set is **three**,
counted by mechanism with its own rule id:

1. the heartbeat rotation (`CONS-16`, gated on an L1-verifiable `h_close` referent);
2. the governance stall resolution;
3. aggregation.

Narrow forced inclusion leaves the set. The earlier phrasing - 'three remain: forced inclusion, the stall
resolution, aggregation' - counted the heartbeat mechanism as revived and treated its rotation as a
residue rather than a mechanism. That is defensible but imprecise: `CONS-16` is a distinct rule with its
own gate and its own blocker, and a reader asking 'what is still not built' should see it named.
**DEFERRED.md's cross-cutting note, the index's deferral lists and spec/10 must all say three with this
membership**, and the heartbeat's revival record keeps its own statement that the rotation within it
remains deferred.

## 2. The settlement record's migration slot

**Decision: the per-height settlement pair `(settledCount, anchoredL1Block)` is carried inside the
per-height checkpoint record of L1-07**, where two `uint64` fields complete the 32-byte word already
holding `l1BlockNumber` and `lastAcceptedBatchTime`. It does **not** get its own mapping.
Consequences to state in spec/08: the pair consumes **no additional gap slot**, so MIG-02's declaration
count stays at 15 and its free count stays 28; the register's clock stays one packed word
(`nextSeq`/`pruneCursor`); and the storage-shape note must say that no per-height mapping was added.
The alternative - a separate mapping - would raise the declaration count to 16 and make the migration
budget in the migration announcement wrong, so it is rejected.

## 3. `L2_BLOCK_GAS_LIMIT` and the config preimage

**Decision: the capacity relation reads `L2_BLOCK_GAS_LIMIT` from the anchored L1 view; it is NOT
committed through the config preimage, and FI-12(5)(ii)'s claim that `PARAM-04` commits it through the
`paramVersion = 2` preimage of PRF-02(5) is WRONG and must not be implemented.**

Reason: V2 is historical. It is valid only for epochs already entered under it and MUST NOT be used for
a new epoch; the live preimage is V3, whose field list does not include `L2_BLOCK_GAS_LIMIT`. Committing
it there would require a new `paramVersion` and a new preimage - a change to a live commitment, taken to
serve one arithmetic input. That is not warranted, because the guest does not need it committed: the
capacity relation is evaluated against the anchored L1 view the proof already fixes, so the value is
bound by that view. The rule must say so explicitly, and must say that no preimage changes.
So: `spec/09` un-withdraws `L2_BLOCK_GAS_LIMIT` as the capacity relation's live input with its relation
and unmeasured tag; `PARAM-04`'s field list stays owned by `PRF-02(5)` and is unchanged; and FI-12's
capacity clause reads the value from the anchored view rather than from the preimage.

## For the review round

Round 1 of increment 4 must check all three: that the deferral count reads three with the membership
above everywhere; that the settlement pair genuinely consumes no additional gap slot and that the
migration budget arithmetic still balances; and that no rule commits `L2_BLOCK_GAS_LIMIT` through any
config preimage and that the capacity relation's input is bound by the anchored view.