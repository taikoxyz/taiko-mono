# Design: Skip Reorged Proposal Logs in `process_log_batch`

## Summary

`crates/driver/src/sync/event.rs` currently retries every `process_log_batch` proposal-processing failure with exponential backoff. When the scanner yields a proposal log whose emitting L1 block has been reorged out of the canonical chain, that retry never converges. The downstream proposal-processing path continues to fail because the original `block_hash` no longer resolves, so the batch stalls indefinitely.

This design adds a narrow permanent-failure classifier at the `process_log_batch` layer. After a failed proposal-processing attempt, the driver re-checks whether the source L1 block for that log still exists. If the block is gone, the log is treated as orphaned by reorg, the driver emits a warn-level skip plus a dedicated counter/metric, and processing continues with the next log in the batch. All other failures remain retryable under the existing backoff policy.

## Goals

- Stop endless retries for proposal logs whose source L1 block has been reorged away.
- Keep the change local to `process_log_batch`.
- Preserve existing retry behavior for transient RPC, derivation, and engine failures.
- Emit operator-visible telemetry for skipped orphaned logs.

## Non-Goals

- No scanner reset or higher-level event-sync restart logic.
- No changes to preconfirmation ingress behavior.
- No broad reclassification of unrelated derivation failures as permanent.

## Constraints And Invariants

- `WLP-INV-009`: event-driven reorg handling and preconf branch handling remain distinct. This change stays within the event path and does not alter preconf flows.
- `WLP-INV-002` and `WLP-INV-005`: confirmed-sync gating remains unchanged.
- `WLP-INV-003` and `WLP-INV-004`: stale-boundary and confirmed-history protections remain unchanged because this change only affects retry handling for canonical L1 proposal logs.
- The permanent skip decision must be based on proof that the source L1 block is gone, not on fragile matching of downstream error strings or error variants.

## Recommended Approach

Add a helper in `crates/driver/src/sync/event.rs` that classifies whether a failed proposal log is permanently orphaned:

- Input: RPC client plus the original `Log`.
- Permanent orphaned result:
  - `log.block_hash` is present, and
  - `l1_provider.get_block_by_hash(block_hash)` returns `Ok(None)`.
- Not orphaned:
  - the block lookup returns `Ok(Some(_))`.
- Transient / unclassified:
  - the lookup itself returns `Err(_)`.

`process_log_batch` continues to use exponential backoff, but each failed attempt gains a branch:

1. Try `router.produce(ProductionInput::L1ProposalLog(log.clone()))`.
2. On success, keep the existing success path.
3. On failure, re-check the source L1 block.
4. If the block is gone, stop retrying that log, emit a warn-level skip, increment a dedicated counter, and continue the surrounding `for log in logs` loop.
5. If the block still exists or the classification lookup errors, return the original failure into the retry loop and preserve current retry behavior.

This keeps the permanent-failure rule narrow and resilient to internal error-shape changes, including failures that currently surface through finalized proposal lookups.

## Components

### `crates/driver/src/sync/event.rs`

- Add a small helper for orphaned-log classification.
- Update `process_log_batch` so the retry boundary distinguishes:
  - retryable failures;
  - permanently orphaned logs that should be skipped.
- Keep the scope limited to canonical proposal log processing.

### `crates/driver/src/metrics.rs`

- Add a counter for orphaned proposal logs skipped due to missing source L1 blocks.
- Keep the metric specific to confirmed orphaned-log skips, not generic processing failures.

## Logging And Metrics

When a log is skipped as orphaned, emit a warn-level log with:

- `block_number`
- `block_hash`
- `transaction_hash`
- the original processing error

Add a dedicated counter/metric for this case so operators can distinguish:

- transient retries that are still progressing;
- permanently orphaned logs skipped after reorg detection.

No stronger escalation is required.

## Error Handling

- `Ok(None)` from `get_block_by_hash` is the only permanent-skip proof.
- `Ok(Some(_))` means the source block still exists, so the original processing failure remains retryable.
- `Err(_)` from the re-check is treated as transient and does not override the original retry policy.
- Logs missing `block_hash` are not newly classified as permanent by this design; they continue through the existing error path.

## Testing

Add targeted tests covering:

1. Helper-level classification

   - `get_block_by_hash -> Ok(None)` => orphaned/permanent.
   - `get_block_by_hash -> Ok(Some(_))` => not orphaned.
   - `get_block_by_hash -> Err(_)` => transient / not classified permanent.

2. `process_log_batch` continuation behavior
   - first log fails processing and is classified orphaned;
   - the log is skipped rather than retried forever;
   - a later log in the same batch is still processed.

If full batch-level testing is awkward with current seams, helper-level tests are still required, and at least one event-sync test should prove that a skipped orphaned log does not stall the batch.

## Risks

- The additional L1 lookup occurs only on failure paths, so steady-state overhead is minimal.
- A temporary provider inconsistency that incorrectly returns `None` would cause a skip; treating only `Ok(None)` as permanent keeps the rule narrow, but the behavior still depends on provider correctness.
- This design intentionally does not solve broader scanner replay or resubscription concerns because those are outside the requested scope.

## Implementation Notes

- Prefer a helper name that makes the permanence criterion explicit, such as `is_permanently_orphaned_proposal_log`.
- Preserve existing doc-comment coverage requirements for all new production symbols.
- After implementation, verification should include `just fmt`, `just clippy`, and the most targeted feasible tests for the changed event-sync behavior.
