# Etna settlement and recovery model design

## Intent and scope

Build the first executable TLA+/TLC model under `formal/etna/`, extending that
directory for later Etna work rather than starting another project. The first
scope is the transaction ordering between `land`, recovery authorization,
`recover`, nonce invalidation and authorization expiry. This is a bounded
protocol model, not verification of deployed contracts or CometBFT.

Source: `packages/protocol/docs/etna/SPEC.md` at
`d18357214fab30ea512ae9858a11699806d72ba1`.

The user delegated selection of a small first scope. This scope is the author's
choice. Consensus internals and per-node L1 observations are deferred, not
implicitly verified.

## Approaches

- Model all Etna integration immediately: more coverage, but too many coupled
  assumptions and a large state space for a first model.
- Model CometBFT rounds first: relevant to consensus, but duplicates stock
  consensus and does not target Etna's own settlement transitions.
- Selected: model settlement/recovery transaction interleavings, with delayed
  authorization and delayed proof submission. Small, source-backed and directly
  extensible.

## State and actions

Contract state: checkpoint height `c`, generation, recovery nonce, and the fixed
start height of the current generation. Abstract time advances independently.
Keep one outstanding authorization and one delayed proof; TLC explores all
possible captured values and submission orderings. Authorization remains
available after execution so replay attempts remain representable.

Actions: authorize recovery, prepare a proof from the current checkpoint,
submit a fresh or delayed proof, execute recovery, invalidate a nonce, and tick.
One onchain transaction is atomic, as required by LAND-6.1-9/11 and
RECOV-8.3-16; transaction-internal partial writes and reentrancy are not checked.

`land` requires `origin <= p <= c < h`, an existing origin record allowed in
the current generation, and a proof bound to the current generation. A prepared
proof can remain usable after a competitor advances `c` into `(p,h)`; this
assumes its cuts match the checkpoint. Different block hashes, FI cursors, blob
availability, proof generation and cryptography are outside this first model.

`recover` checks expected generation, checkpoint and nonce and the inclusive
deadline, preserves the checkpoint, increments generation and nonce, and records
the new generation's fixed origin. Explicit invalidation increments the nonce.
Failed transactions do not mutate contract state. DAO authority and valid lists
are assumptions, not properties proven by this model.

## Properties and meaningful checks

Check types; no successful stale or expired recovery authorization; no landing
accepted with an old-generation proof; checkpoint preservation across recovery;
and the actual landing parent being the checkpoint at execution, not the proof
origin. Observation-only audit state records violations independently of the
optional guard switches.

Baseline configuration enables all guards. Negative controls disable one guard
at a time (checkpoint, nonce, deadline or proof generation) and must produce the
corresponding invariant violation. Reachability configurations negate witnesses
for recovery, overlapping landing, invalidation and expiry; TLC must exhibit
those paths, avoiding a vacuous green model.

Bounds are normalized grid heights (K=1), a few heights, generations, nonce and
time values. They do not stand for production deployment parameters. Successful
bounded exploration is not an unbounded proof or a liveness guarantee.

## Extension boundary

Keep the module and its small configurations as regressions. Later modules can
introduce L1 observations, committee schedules, signer state or consensus and
compose actions with explicit shared-state ownership. Composition requires
reviewing assumptions and invariants; existing green results do not establish
correctness of the enlarged system. Verifier-failure rollback deliberately
violates ordinary checkpoint monotonicity and needs a separate action/property
scope before inclusion.

## Delivery and verification

Deliver `.tla`, `.cfg`, a bounded runner, source-to-model mapping, and a report
with pinned tool versions, bounds and observed state counts. Run real TLC with
official artifacts; keep downloaded tools and state databases outside Git.
Use independent source/diff review and independent TLC execution. No production
implementation, GitHub publication, merge or deployment is part of this task.
