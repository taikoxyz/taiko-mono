# Finalized Forkchoice Propagation and Execution-Rewind Recovery

**Status:** Design approved; written specification pending review
**Date:** 2026-08-07
**Scope:** `packages/taiko-client-rs`

## Context

The Hoodi Rust-driver Reth node exposed two independent driver defects during the same incident.

First, whitelist preconfirmation insertion currently calls the payload applier without a finalized
block hash. Canonical proposal processing can advance finality, but its known-canonical fast path
returns after updating origin metadata and does not issue a forkchoice update. Reth therefore can
keep its finalized head stale while accepting thousands of unsafe blocks. The affected Alethia-Reth
revision retains one changeset-cache entry per block above finalized, so stale driver finality
amplifies memory growth into an OOM.

Second, an execution-layer restart can discard its unpersisted canonical tail while Alethia-Reth
custom origin and batch mappings still reference blocks in that tail. The running Rust driver then
loads the stale mapped parent, receives `BlockUnavailable`, and retries the same proposal forever.
The safe beacon-checkpoint and resume-head selection path runs only at driver startup, so it is not
re-entered until the driver restarts.

On 2026-08-07, Reth moved from block 16,211,455 back to 16,211,327, an exact 128-block rewind. The
driver retried `BlockUnavailable(16211429)` 1,105 times for the same proposal from 08:18:54Z until
the pod was deleted at 12:40:46Z. Restarting the driver reran beacon sync, selected a new checkpoint
resume head, and restored progress.

## Goals

1. Propagate a recent proof-finalized L2 checkpoint through both preconfirmation and canonical
   forkchoice updates.
2. Cover the known-canonical proposal fast path, where no payload is submitted.
3. Escape the proposal retry loop when the execution engine has demonstrably rewound below a
   required L2 parent.
4. Reuse the existing startup beacon-sync recovery path instead of introducing another recovery
   state machine.
5. Preserve proposal canonicality, L1 reorg, confirmed-boundary, and preconfirmation ordering
   invariants.

## Non-goals

- Fixing Alethia-Reth changeset-cache ownership, custom-table persistence, or startup
  reconciliation.
- Adding a periodic finality task or a second driver supervisor loop.
- Changing Kubernetes CPU or memory resources, probes, or restart policy.
- Treating every missing block, RPC failure, or EL restart as a confirmed execution rewind.
- Changing protocol finalization semantics.

## Design

### 1. Finalized checkpoint sources

Use one checkpoint value type across production paths:

```text
FinalizedCheckpoint {
    proposal_id: u64,
    block_hash: B256,
}
```

Both paths read `Inbox.getCoreState()` and use the returned `lastFinalizedProposalId` and
`lastFinalizedBlockHash` directly. This avoids resolving the finalized block through Alethia-Reth
custom batch tables, which may legitimately be absent after checkpoint sync.

Canonical proposal processing reads CoreState at the proposal log's L1 block and stores the pair in
the proposal bundle metadata. This event-scoped snapshot preserves replay ordering: a checkpoint
from a newer L1 block must not be attached to an older canonical proposal because it could place
safe/finalized ahead of the forkchoice head.

Preconfirmation processing uses a small shared cache sourced from CoreState at a finalized L1
block. It uses a three-minute TTL, matching the Go driver's checkpoint-cache cadence:

- the first lookup refreshes synchronously;
- a fresh value is returned immediately;
- a stale value is returned immediately while one background refresh runs;
- concurrent stale readers do not start duplicate refreshes;
- a failed refresh retains the last valid value;
- proposal IDs may advance but never regress;
- a zero hash is rejected;
- the same proposal ID with a different hash is rejected and logged.

There is no timer-driven task. Refresh work is triggered only by canonical or preconfirmation
production activity.

On a cold-cache refresh failure, preconfirmation receives no checkpoint, keeps its current
availability behavior, and submits without a finalized hash; a later production input retries the
refresh. A canonical CoreState lookup retains its existing error propagation because its snapshot
is part of deriving that proposal.

### 2. Forkchoice propagation

Preconfirmation production obtains the cached checkpoint before applying a payload. When present,
the existing payload-promotion forkchoice state uses the new block as head and the checkpoint hash
as both safe and finalized. When absent, it preserves the current `None` behavior.

Canonical payload production uses the event-scoped checkpoint in bundle metadata instead of
resolving finality through `last_block_id_by_batch_id`. All blocks in one proposal use the same
checkpoint snapshot. The checkpoint proposal ID must not exceed the proposal being processed.

The known-canonical proposal fast path performs no payload insertion, but it must still send a
no-payload `forkchoiceUpdated` call after validating the canonical proposal. Its head is the
detected canonical proposal tip; safe and finalized are the event-scoped checkpoint. Origin
metadata is updated only as already permitted by the canonical-path invariants.

The engine abstraction gains only the minimal no-payload forkchoice operation needed by this fast
path. It reuses the existing `VALID` status validation and does not introduce payload attributes.

### 3. Execution-rewind escape

Give a missing L1 source block a distinct derivation error so it cannot enter execution-rewind
classification. A missing L2 parent remains retryable initially. Before retrying it, event sync
reads the current execution head and records consecutive rewind observations. It promotes the
failure to `SyncError::ExecutionEngineRewound` only when all of the following hold:

1. derivation failed to load the required parent block;
2. the execution head query succeeded; and
3. the required block number is above the current execution head; and
4. the same missing block has produced that result on three consecutive attempts.

The error records both `missing_block` and `execution_head`. If the head cannot be queried, or it is
not below the missing block, the consecutive observation count resets and existing retry and
proposal-canonicality behavior remains unchanged. A different missing block starts a new count.
Permanently orphaned L1 proposal logs are still skipped before rewind classification.

`ExecutionEngineRewound` exits the event-sync task instead of entering `RetryIf` again. The existing
whitelist runner already propagates event-sync termination, shuts down its network sidecars, and
returns an error from the command. Under Kubernetes, the driver container then restarts and executes
the existing sequence:

```text
beacon checkpoint sync -> safe resume-head resolution -> fresh derivation pipeline -> event sync
```

This intentionally uses process restart as the recovery boundary. An in-process supervisor would
need to reset ingress tasks, router state, processed-log caches, and derivation state, duplicating
the startup lifecycle for no additional Kubernetes availability benefit.

## Error handling and safety

- Finalized checkpoint refresh failures never discard a previously validated checkpoint.
- Preconfirmation checkpoints never regress within one process.
- A preconfirmation checkpoint is sourced from finalized L1 state, not an unsafe latest-state
  observation.
- A canonical checkpoint is tied to the proposal's L1 block and cannot be newer than its
  forkchoice head.
- The rewind escape cannot trigger merely because an L1 block is temporarily unavailable.
- A confirmed execution rewind fails visibly and restarts the driver rather than remaining Ready
  while silently retrying one proposal.
- Existing deterministic engine-verdict and finalized-L1 canonicality rules remain unchanged.
- No recovery path crosses below the confirmed/finalized boundary selected by startup beacon sync.

## Test strategy

Add focused tests for:

1. preconfirmation checkpoint cold load, fresh hit, stale-while-refresh, singleflight refresh,
   refresh failure, zero hash rejection, and monotonic non-regression;
2. preconfirmation payload promotion with and without a cached finalized hash;
3. canonical payload production using the event-scoped CoreState hash directly, including
   rejection of a checkpoint ahead of the proposal;
4. known-canonical proposal processing issuing one no-payload forkchoice update;
5. the same missing derivation parent above the execution head escaping after three consecutive
   classified attempts;
6. a missing block at or below the head remaining on the existing retry path;
7. an execution-head query failure remaining retryable;
8. a missing L1 source block never entering execution-rewind classification;
9. an orphaned proposal log being skipped rather than classified as a rewind; and
10. event-sync failure propagation through the whitelist runner.

The implementation plan must preserve RED/GREEN evidence for the finalized-propagation and
execution-rewind regression seams independently. Final verification is:

```text
just fmt
just clippy-fix
just test
```

from `packages/taiko-client-rs`, plus a final merge-base diff review.

## Documentation impact

Update the following invariant references when code anchors move:

- `docs/agents/whitelist-preconfirmation-invariants.md`
- `docs/agents/event-scan-reorg-and-preconf-flow.md`
- `docs/agents/alethia-reth-custom-tables-and-beacon-sync-gaps.md`
- `docs/agents/reference-map.md`

The documentation must keep the two remediations distinct:

- finalized propagation prevents stale-finality resource amplification;
- rewind escape restores availability after a separately triggered EL rollback.

## Rejected alternatives

### Strict Go parity only

Updating finalized only during preconfirmation insertion would leave the canonical known-block fast
path uncovered and would preserve dependence on potentially missing custom batch mappings.

### Independent periodic finality loop

A timer would advance finality during completely idle production periods, but adds task lifecycle,
shutdown, and engine-call concurrency for little benefit. Event-driven three-minute refresh is
sufficient for the observed workload.

### In-process rewind supervisor

Looping beacon and event stages inside the same process could avoid a container restart, but requires
careful teardown and reconstruction of ingress and network state. Exiting through the existing
runner is smaller, observable, and already supervised in the deployed environment.
