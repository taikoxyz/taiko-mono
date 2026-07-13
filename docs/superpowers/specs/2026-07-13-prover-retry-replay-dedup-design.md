# Prover Retry Exhaustion and Replay Deduplication Design

## Problem

PR #21951 rolls the proposal scan cursors back after proposal handling or downstream retries fail. Two gaps remain:

1. `ProofSubmitter.RequestProof` polls in an unbounded inner retry loop, so unexpected Raiko and L1 RPC failures do not reach the prover's bounded `withRetry` policy and its rollback callback.
2. Lowering `lastHandledProposalID` causes every later proposal in the rewound L1 range to be dispatched again, duplicating proof requests and assignment-expiration timers.

## Goals

- Preserve indefinite polling for normal proof lifecycle states.
- Allow unexpected proof-request failures to exhaust the existing bounded prover retry policy and trigger rollback.
- Re-dispatch only proposals whose previous processing attempt exhausted its retries.
- Continue advancing both scan cursors across already-dispatched proposals during a recovery scan.
- Preserve shutdown behavior: cancellation must not create new rollback work.
- Avoid an unbounded per-proposal success registry.

## Non-Goals

- Replacing the periodic L1 rescan with a new durable retry queue.
- Changing CLI retry or polling defaults.
- Changing Raiko proof generation or proof-buffer semantics.
- Persisting retry state across process restarts; restart recovery remains based on the existing L1 scan.

## Design

### Retry ownership

`ProofSubmitter.RequestProof` retains its inner polling loop for errors that represent normal, unfinished work:

- `proofProducer.ErrProofInProgress`
- `proofProducer.ErrRetry`
- `ErrProposalOutOfAllowedRange`

Unexpected failures, including L1 RPC errors, Raiko transport failures, malformed responses, and proof-buffer insertion errors, are returned from the inner loop immediately by wrapping them with `backoff.Permanent`. The error then reaches the prover's existing bounded `withRetry` call. Each outer attempt reconstructs the request state; after `BackOffMaxRetries` failures, the existing callback marks the proposal for replay and rewinds its cursors.

Context cancellation remains terminal and does not trigger rollback because the callback checks the prover context before mutating state.

### Replay deduplication

`SharedState` gains two pieces of dispatch state:

- A monotonic `lastDispatchedProposalID` high-water mark.
- A concurrent set containing proposal IDs whose attempts exhausted retries and must be dispatched again.

The existing `lastHandledProposalID` remains the scan cursor and may move backward during recovery. The new dispatch high-water mark never moves backward.

Rollback receives the failed proposal ID rather than the already-decremented cursor value. While holding the proposal cursor lock, it:

1. Adds the failed proposal ID to the retry set.
2. Lowers `lastHandledProposalID` to `failedProposalID - 1`.
3. Lowers the L1 cursor to the failed proposal's block.

During proposal iteration, the handler distinguishes three cases:

1. An event at or below the current scan cursor that is not marked for retry is skipped immediately.
2. A proposal above `lastDispatchedProposalID`, or one explicitly marked for retry, performs the normal eligibility check and dispatch flow.
3. A proposal above the rewound scan cursor but at or below `lastDispatchedProposalID` only advances the scan cursors. It does not create another timer, goroutine, or proof request.

The retry marker is consumed only after synchronous prerequisites such as L2 header availability, L1 reorg validation, and L1 header lookup succeed. This ensures a transient synchronous failure does not accidentally convert a required replay into a cursor-only event.

Because the proposal scan and rollback remain serialized by `proposalCursorMu`, the handler can re-advance the scan cursor across a deterministic snapshot while concurrent terminal failures wait to register their retry markers.

## Error Handling

- Expected proof polling states continue retrying at `ProofPollingInterval` until success or shutdown.
- Unexpected proof-request errors are retried by `Prover.withRetry` using `BackOffRetryInterval` and `BackOffMaxRetries`.
- Retry exhaustion marks the exact failed proposal and rewinds the scan.
- Invalid proposal metadata still prevents rollback and is logged by the callback caller.
- Shutdown cancellation skips rollback and leaves no new retry marker.

## Testing

Tests will be written before implementation and will cover:

- Expected proof polling errors remain in the inner polling loop and can later succeed.
- An unexpected error exits the inner polling loop so the outer bounded retry can exhaust.
- The real prover request path invokes rollback after repeated unexpected proof-request errors.
- Rolling back proposal N marks only N for redispatch.
- A recovery scan redispatches N while later proposals only re-advance cursors.
- Replayed later unassigned proposals do not schedule duplicate expiration timers.
- Multiple failed proposal IDs are independently redispatched in a single recovery scan.
- Cancellation does not add retry markers or lower cursors.
- Targeted tests pass with the Go race detector.

## Compatibility and Operations

No configuration, database, protocol, or contract changes are required. The only operational behavior change is that persistent unexpected proof-request failures become bounded and recoverable, while expected long-running proof polling remains unbounded until success or shutdown.
