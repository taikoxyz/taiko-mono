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

## 4. Owner ratification of two in-text repairs of the design delta

The rules implementer did not copy two clauses of `04-forced-inclusion-design.md` literally, because as written
they are unsatisfiable. **Both readings are ratified**; the DELTA is what must be corrected, not the rule.

### 4a. `FI-12(2)`: the resolved count, not the live count

The delta wrote `R = min(W, FI_MAX_PER_BATCH)` with `W` the live count. But `d(A)` counts **dead** records
(`FI-10(5)`) and `FI-11(3)(a)` demands `c' >= min(d(A), c + FI_MAX_PER_BATCH)` **unconditionally**, so the
delta's form makes any window containing a dead record **unsatisfiable**: no proof could land, and the
frontier would be pinned by expiry positions - the obligation would be dead in exactly the case expiry
exists to discharge.

**Ratified:** `R = min(d(A) - c, FI_MAX_PER_BATCH)` is the resolved count (the window), and `W` is the
**live** positions in `[c, c + R)` (the work and gas count). Then `c' = c + R` meets the advance condition
with equality and dead positions cost no gas. **The delta's clause must be corrected to this form**, and the
reason recorded there, so a future reader does not restore the unsatisfiable one.

### 4b. `FI-11(2)(3)`: the floor cannot be a rejection threshold

The delta's literal 'reject unless `R >= FI_MIN_DRAIN`' is a **deadlock** when fewer than `FI_MIN_DRAIN`
positions are outstanding - the obligation would become unsatisfiable precisely when little is owed.

**Ratified:** the clause requires `R >= 1` whenever the outstanding obligation at `A` is non-empty; the
capacity condition then turns it into `R >= min(W, FI_MIN_DRAIN) >= 1` whenever a live record is
outstanding. `FI_MIN_DRAIN` remains the registered floor `1 <= FI_MIN_DRAIN <= FI_MAX_PER_BATCH`, whose
purpose is to remove the reachable cap-of-zero. This also settles item 1 of this file: **the register row
must be reworded to match the clause**, since the row currently claims the floor itself drives the
advance.

### 4c. `FI-12(1)(i)/(ii)`: the unnamed per-block bound

Ratified as read: `FI_MAX_PER_BATCH * itemGasBound` is `cap(batch)`, the only reading under which the
delta's 'in both cases `cap(batch) = FI_MAX_PER_BATCH`' holds. Stated explicitly in the rule.

### 4d. Left to the review round (not owner calls)

View-freshness rejections map to the single `ForcedViewStale` rather than the delta's five-error list
gaining `ForcedViewNotFinal`/`ForcedViewRegression`; `forcedSettlementAt(uint64)` is the settlement-record
read the delta names the pair for but gives no view; and `pruneCursor` has no view function. Round 1 of
increment 4 should decide whether any of the three needs its own surface.

## 5. Seam left visible by the byte-class enumeration (F1) - to close with the per-block duty fix

The enumerated byte-invalid classes are the four that are genuinely decidable from the record's published
byte string, the registered constants and the chain id alone: (A) the byte string fails to decode so no
transaction can be recovered; (B) a chain id that does not match; (C) a signature that does not recover
to a sender; (D) a declared gas limit below the intrinsic gas of the transaction's own data. Classes
(2)(iv)-(v) - nonce and balance at the turn pre-state - are deliberately NOT in the void limb, because
they are not byte-decidable; they remain the discharge ground of `(1)(a)`. That split is correct.

**The seam:** `FI-13(2)` as shipped contains no literal intrinsic-gas floor and no literal
signature-recovery requirement. Both classes are still byte-decidable, which is why they belong in the
void limb - but the consequence is that a below-intrinsic-gas transaction still SATISFIES `(2)`'s
forceability predicate, so `CONS-01(v)`'s per-block duty ('forceable at that pre-state under
`FI-13(2)`') would demand that a block carry it, although no valid block can. That is the same defect
class as the round-3 Critical: **the per-block duty and the block's own validity disagree about the same
transaction.**

**Decision:** tighten `FI-13(2)(ii)` with the intrinsic-gas floor and state the signature-recovery
requirement in `(2)(iv)-(v)` as shipped, so the forceability predicate matches what a valid block can
contain; the per-block duty then inherits the corrected predicate and the two agree by construction. This
must land in the same pass as the `CONS-01(v)` turn-scoping fix, because both change the same
predicate, and it touches `spec/02`, `spec/04`, `spec/05` and the delta.

**Round 4 must verify:** that a below-intrinsic-gas transaction is neither forceable under `(2)` nor
demanded by the per-block duty; that a transaction whose signature does not recover is likewise neither;
and that no transaction exists which `(2)` calls forceable but which no valid block can carry.