# S5 — Recovery repair: design decisions and the exact rule changes

Status: **design decided, not yet applied to the specification** · Date: 2026-10-05
Closes: round-4 findings R4-MB-01…R4-MB-09, the consensus angle's Critical and Highs, R4-PB-01/02/03/05/08.
Every change below is stated as a decision plus the rule that must carry it. Numbers stay `unmeasured`
until Phase B measures them.

## 1. Retire the discarded heights (fixes the reinstatement Critical)

**Decision.** Recovery completion records, on L1, a `resumeHeight` equal to the last discarded height plus
one. Discarded heights are **permanently retired**: they can never be certified or landed again, at any
generation, by anyone.

**Why this works where the generation counter did not.** The generation binds the *proof*; a branch that
descends from the restored checkpoint can be re-proven under a new generation, so the proof-level check
was a tautology. Retiring the *heights* makes the discarded branch unlandable by construction, because the
acceptance rule is about where a batch starts, not about which proof was used.

**Rule changes.** `REC-02`: the completion transition writes `resumeHeight`. `L1-06`: the contiguity
rule becomes `firstHeight == max(lastLandedHeight + 1, resumeHeight)`, so a batch that starts at or below
`resumeHeight` is rejected. `CONS-01`: correct validators must not sign a proposal whose height is below
`resumeHeight`. `REC-02`'s false claim that a late proof is void "because its predecessor no longer
exists" is deleted and replaced by the retirement rule. The `recoveryGeneration` counter stays, but only
as a cheap invalidation of in-flight proofs; the security property rests on retired heights.

**Bounded.** `resumeHeight - lastLandedHeight <= D_MAX`, so retirement is a small, bounded record.

## 2. Completion is an L1 event with a depth, and cancellation runs to its finality

**Decision.** Recovery takes effect only when the completion transaction is **Ethereum-final**. Any valid
batch accepted before that instant cancels the recovery and **slashes the bond to the treasury**. There is
no window in which a completed recovery and a batch at a retired height can both be true.

**Rule changes.** `REC-02`: a named completion transition, its caller (any account, same bond), the
requirement that L2 nodes act on it only at the Ethereum-final depth defined by SYS-02, and the exact
cancellation predicate. `L1-12`: the "re-landable with the same `dataCommitment`" sentence is corrected —
after a recovery the stale generation makes that proof unusable, and the data may be re-batched against
the restored checkpoint by any proposer.

## 3. Locks at retired heights are void

**Decision.** On completion, every lock at a retired height is void. A locked value at a retired height is
not a halt condition and is not evidence of equivocation.

**Rule changes.** `CONS-04(1)(a)`: qualified — a lock is released by the commit of *the locked value* at
that height **within the current generation**, or by a strictly later same-height PoLC. `CONS-04(2)` and
`CONS-15(2)`: explicit carve-out that a lock at a retired height is void. Without this, ≥ 1/3 of locked
power can wedge the new chain at the discarded height — reintroducing the unbounded halt D-7 exists to
avoid. `CONS-09(3)`: "resolved at that height" gets the operative release rule it currently lacks.

## 4. The bond must be at risk even when the recovery succeeds

**Decision.** The invoker pays a **non-refundable component** on every invocation, whether or not the
recovery completes, sized against the value a rollback can destroy; escalation counts **attempts**, not
completions. Refund only the remainder on success.

**Rule changes.** `REC-02`: `B_REC(e) = B_REC_BASE · 2^attempts`, split into a non-refundable
`B_REC_KEEP` (to the treasury) and a refundable balance returned on completion; `REC_COOLDOWN` after
every attempt. `ECON-06(6)`: the destination split. Sizing rule: `B_REC_KEEP >= value_at_risk(D_MAX)`,
where `value_at_risk` is the fees and bridge value inside the provisional range — **unmeasured**, and a
Phase B output.

## 5. A per-epoch configuration registry, and a defined configHash preimage

**Decision.** `configHash` for epoch *e* is fixed when the epoch's configuration entry is written and never
changes for that epoch; upgrades take effect for future epochs only. The preimage is a canonical,
domain-tagged encoding of an enumerated parameter list, so the binding is checkable rather than vacuous.

**Rule changes.** A new rule under `MEM`/parameter governance: the config registry, its append-only
semantics and its per-epoch immutability; `PRF-02`: the exact preimage field list and domain tag; the
guest check compares the journal's `configHash` against the registry value for the batch's epoch.
Closes R4-PB-02, R4-LIV-04 and part of R4-MB-02.

## 6. Generation-scoped uniqueness

**Decision.** `CONS-12` and `INV-01` are restated as: at most one block per height **per generation**
receives a valid certificate, and a retired height can never be re-certified. The unconditional
"at most one per height ever" claim is deleted because every completed recovery deliberately violates it.

## 7. The fee sweep interface is protocol-constructed, not caller-constructed

**Decision.** The sweep takes **no arguments that influence the destination.** The L2-side sweep builds the
bridge message itself from protocol constants: the canonical invocation selector, the reward-pool address
as `destOwner`, and `to` set to the pool. The pool is credited only from the recognized bridge path.
Bridge fee handling is stated correctly: the preserved Bridge requires `value + fee == msg.value`, so the
fee is **additional ETH**, not a deduction from the swept amount.

**Rule changes.** `ECON-02(7)`: full sweep specification (selector, sender, `destOwner`, `to`, data, fee
arithmetic, one-shot and replay rules, zero-balance no-op). `L1-11`: the pool accepts credit only via the
bridge invocation path; any other message is the sender's own loss, never the protocol's. Closes R4-PB-01.

## 8. Fee diversion is enforceable

**Decision.** A proposal that does not credit the fee vault with the fees its own execution collects is
**invalid**, and the guest checks the vault credit as part of execution.

**Rule changes.** `CONS-01` validity clause; `PRF-06` execution check on the fee-vault balance delta; a
matching entry in `ECON-04`'s offence catalogue. Closes R4-PB-08.

## 9. The allocation policy is written down

**Decision.** Define where the allocation policy is recorded, who may change it, the per-epoch formula for
`Alloc(e)`, and the pool identity **including the proving-share outflow**, so one inflow cannot be
allocated twice. Closes R4-PB-03.

## 10. What is not fixed here

- The **bond sizing** and the **value at risk** need Phase B numbers.
- The **off-chain profit** available from a rollback remains outside any protocol bound (disclosed).
- `REC-03`'s resistance analysis must be **rewritten around the repaired mechanism** and re-reviewed; the
  D2 selection stays blocked until that review is clean.
- `B_REC_KEEP`, `REC_COOLDOWN`, `attempts` window and the registry epoch semantics all need values.

## 11. Ordering

1. Apply §1, §3, §6 first — they are the safety fixes (retirement, locks, uniqueness).
2. Then §2, §4, §5, §7, §8, §9 — the mechanism and economic fixes.
3. Then rewrite `REC-03` around the repaired design, re-freeze, and re-run the D2 review.
