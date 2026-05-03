# Rust Preconfirmation Reorg Head L1 Origin Fix

## Context

PR `taikoxyz/taiko-mono#21627` fixes a Go `taiko-client` issue where proposal reorg handling rewinds the in-memory unsafe preconfirmation marker but leaves the execution engine's `head_l1_origin` pointer at a block from an orphaned proposal. Preconfirmation guards then reject otherwise valid new unsafe blocks because `block_number <= head_l1_origin`.

`taiko-client-rs` has the same stale-boundary rule in the shared driver event/preconfirmation path:

- `EventSyncer::submit_preconfirmation_payload_with_timeout` rejects stale preconfirmation payloads before enqueue.
- The preconfirmation ingress loop repeats the same `block_number <= head_l1_origin` check while holding the router lock.
- `whitelist-preconfirmation-driver` uses this event syncer for local build requests and P2P imports.

The Rust issue should be fixed at the event-sync reorg boundary, not in whitelist gossip, status reporting, or cache behavior.

## Goals

- Reset the execution engine's `head_l1_origin` when Rust event sync proves that a proposal log came from an orphaned L1 block.
- Keep the fix behaviorally aligned with PR `#21627`: use the current canonical proposal target and its mapped final L2 block as the rollback boundary.
- Preserve strict stale-boundary enforcement: preconfirmation data at or below the corrected `head_l1_origin` remains stale.
- Keep the change minimal and isolated to the shared `driver` event-sync path.

## Non-Goals

- Do not change `whitelist-preconfirmation-driver` gossip, request/response, cache, or `/status` semantics.
- Do not add a new operator-facing config flag.
- Do not relax preconfirmation stale-drop checks.
- Do not explicitly rewind the L2 canonical head or issue an extra forkchoice update from event reorg handling.

## Affected Invariants

- `WLP-INV-003`: preconfirmation payloads where `block_number <= head_l1_origin` must remain stale.
- `WLP-INV-004`: preconfirmation processing must not reorg event-confirmed blocks.
- `WLP-INV-005`: confirmed-sync readiness still depends on `last_block_id_by_batch_id` plus `head_l1_origin`.
- `WLP-INV-009`: event-driven reorg handling and preconfirmation branch handling stay distinct.

## Proposed Design

Add a private reconciliation helper in `crates/driver/src/sync/event.rs`, near the existing orphaned-log detection code. The helper runs only after `is_permanently_orphaned_proposal_log` returns `Ok(true)` inside `process_log_batch`.

The helper performs these steps:

1. Read `Inbox.getCoreState()` and derive `target_proposal_id = nextProposalId.saturating_sub(1)`.
2. Resolve the rollback block:
   - `target_proposal_id == 0` resolves to L2 block `0`.
   - `target_proposal_id > 0` resolves with `rpc.last_block_id_by_batch_id(target_proposal_id)`.
3. Read the current execution-engine `head_l1_origin`.
4. If `head_l1_origin` is present and greater than the rollback block, call `rpc.set_head_l1_origin(rollback_block)`.
5. Log the proposal id, previous head, rollback block, and orphaned log identity when a reset happens.

The call site then continues skipping the orphaned proposal log as it does today.

## Error Handling

The reconciliation is best-effort and non-fatal. If core-state lookup, rollback-block lookup, current-head lookup, or `set_head_l1_origin` fails, log a warning and continue processing the batch.

This matches the operational behavior of the Go fix: a failed reset can delay preconfirmation unblocking until normal event sync catches up, but it should not turn an already-proven orphaned log into a driver crash.

If `target_proposal_id > 0` and `last_block_id_by_batch_id` returns `None`, log a warning and skip the reset. Do not fall back to unsafe latest state.

If `head_l1_origin` is `None`, do not write a value. The genesis/missing-head behavior remains owned by existing startup and confirmed-sync logic.

## Testing

Add focused tests in `crates/driver/src/sync/event.rs`:

- A pure decision test verifies reset is required only when the current head is greater than the rollback block.
- A target-resolution test verifies target `0` maps to rollback block `0`.
- A target-resolution test verifies target `> 0` uses `last_block_id_by_batch_id` and treats a missing mapping as no reset.
- Existing orphaned-log processing tests should continue to show that skipped orphaned logs do not stop later canonical logs in the same batch.
- Do not introduce a broad RPC mock framework for this fix; keep tests on pure helper decisions and existing event-sync behavior.

Implementation verification after code changes:

```sh
just fmt && just clippy-fix && just test
```

## Implementation Notes

- The change belongs in `driver`, because `whitelist-preconfirmation-driver` reaches the stale checks through the shared `EventSyncer`.
- The helper should use existing `Client` methods: `head_l1_origin`, `last_block_id_by_batch_id`, and `set_head_l1_origin`.
- Avoid making `confirmed_sync_snapshot` write state; readiness checks should remain read-only.
- Avoid making preconfirmation submission paths self-heal stale heads; preconfirmation ingress should keep enforcing the boundary it is given.
