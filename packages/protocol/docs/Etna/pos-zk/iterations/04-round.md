# Iteration 04 — adversarial review round 4 (the D2-required review of the Mode B selection)

**Frozen snapshot:** `fe7373a13` (2026-10-05) · **Rounds used:** 4 of 8 · **Convergence count: 0**

Four fresh reviewers, all five angles, one of them assigned specifically to the D2-mandated independent
review of the Mode B selection and of the REC-03 resistance analysis.

| Angle | Critical | High | Medium | Low |
|-------|----------|------|--------|-----|
| Mode B selection / resistance analysis (**D2-required**) | 2 | 4 | 3 | 0 |
| Consensus safety × recovery | 1 | 2 | 2 | 1 |
| Liveness / exposure / migration | 0 | 5 | 4 | 1 |
| Proof / data / economics | (reported below) | | | |
| **Total so far** | **3** | **11** | **9** | **2** |

## Verdict: the Mode B selection is NOT established. The design is blocked on it.

**R4-MB-01 (Critical, procedural).** D2 step 5 requires the resistance claim to be quantified and says
that inability to establish it is a **blocker, not a disclosure item**. REC-03 quantifies nothing (every
recovery parameter is unmeasured), is premise-contained — under A-DA-2/A-L1-1 the trigger cannot fire,
and the trigger *is* those assumptions failing — and the specification converted the blocker into LIM-01
disclosure rows, which step 5 forbids. The selection therefore cannot be treated as settled.

**R4-MB-02 and the consensus angle's Critical share one root cause: the recovery authorization is a
tautology.** No signed object carries the recovery generation — the vote and commit-certificate fields
have none, and CONS-08(3) makes certificates valid forever. The generation binds the *proof*, not the
*history*, and the check compares the journal against a value the contract took from the same journal.
Consequence: a discarded-but-certified branch can be re-proven under the new generation and landed
against the restored checkpoint, so history that a recovery discarded can be reinstated by one
permissionless prover at the cost of gas. REC-02's claim that a late proof is void because "its
predecessor no longer exists" is simply false for a branch that descends from the restored checkpoint.
There is also no completion entry point and no L1 depth for the completion transaction, so between
inclusion and finality the same race can be run against a *completed* recovery: L1 then holds a
checkpoint that REC-01/STATUS-06 forbid revoking while L1-06 forbids lowering it — either resolution
breaks a stated rule.

## Other Critical/High findings (all inside the fault model)

- **Locks survive recovery (High).** CONS-04 releases a lock only by the commit at that height or a later
  same-height PoLC; after a recovery the new chain restarts rounds at 0, so ≥ 1/3 locked power can wedge
  the chain at the discarded height — converting the bounded rollback into the unbounded halt D-7 was
  chosen to avoid.
- **CONS-12 / INV-01 are false as stated (High).** They claim at most one valid certificate per height
  ever; every completed recovery deliberately violates that. Only a generation-scoped uniqueness claim
  is true, and it is not written.
- **The bond is free on success (High).** It is refunded in full when a recovery completes and slashed
  only on cancellation, and escalation counts only *completed* recoveries, so a successful manipulation
  costs gas and a temporary lock-up. There is no slashable stake at risk, so the economic argument does
  not apply to it.
- **The landing market is unpriced (High).** `land` may succeed with `rewardPaid = 0` and the only
  specified reward inflow is the L2-fee sweep, so an empty pool reaches the trigger with **no adversary
  at all** — and recovery cannot fix an economics stall. REC-03's premise "proving is permissionless and
  rewarded" is contradicted by the specification's own rules.
- **T_STALL has no inclusion-delay term (High).** Bought L1 congestion, not censorship, can push a batch
  past the threshold; the falsifier list does not mention it.
- **A routine upgrade can blank provisional history (High).** `configHash` binds recovery parameters and
  has no per-epoch registry, so retuning an unmeasured parameter makes every in-flight proof fail and
  only recovery can clear the range — governance as an unaccounted recovery path.
- **The trigger clock never resets** (High): after a completed recovery the predicate can be satisfied
  with no new failure.
- **"No selective rollback" is false as an outcome claim** (High): discarded transactions are not
  replayed and inclusion is not guaranteed, so an attacker can re-establish its own effects and not the
  counterparty's.
- **Recovery's state, bond custody, entry point and cancellation windows are unowned and unbudgeted**,
  contradicting MIG-02's "complete" slot list (High).
- **Stale Mode A text remains** in README, `01-requirements-and-threat-model.md`, spec/07, spec/04
  (L1-04/L1-06/L1-12/DA-06) and MSG-03, which still mandates withdrawal text promising that a halt
  "loses nothing" — forbidden by ECON-11(3) (High/Medium).
- **Recovery's reach is overstated** for halts it cannot clear: it changes no validator set, so an
  unavailable-quorum halt persists (Medium).

## Fix directions (not yet applied)

1. **Bind the generation to the history, not the proof**: put `(configHash, recoveryGeneration)` into the
   signed vote and header bytes, or record an L1 discarded-branch anchor as a public input. Without one
   of these, REC-01/REC-02 cannot be implemented as written.
2. **Define recovery completion as an L1 event with a depth**, and extend cancellation to any batch
   accepted before that event is Ethereum-final; or freeze landing for the window and amend L1-04.
3. **Void all locks at heights above the restored checkpoint on completion**, with an explicit
   CONS-04(2)/CONS-15(2) carve-out, and qualify CONS-04(1)(a) with the locked value.
4. **Make the bond at risk**: a non-refundable component, or a slashable TAIKO component, sized against
   the value a rollback can destroy; escalate on *attempts*, not completions.
5. **Price landing** so the trigger cannot be reached by rational inaction, and add the empty-pool case
   to the falsifier list.
6. **Add a per-epoch configuration registry** so an upgrade cannot strand in-flight proofs.
7. **Restate CONS-12/INV-01 as generation-scoped**, and sweep every remaining Mode A guarantee claim.

## What this means

The architecture-level answer (permissionless TAIKO-staked PoS + ZK settlement with atomic data and
proof) still stands, and no reviewer has produced two conflicting *certificates* inside the fault model.
But **the recovery design that D-7 selected does not work as specified**, and its own required review
says so. The honest status is **blocked on the recovery design**, not converged. This is written down
rather than disclosed as a limitation, because D2 step 5 forbids the latter.
