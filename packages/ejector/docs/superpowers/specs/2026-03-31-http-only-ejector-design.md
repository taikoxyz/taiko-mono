# HTTP-Only Ejector Design

**Date:** 2026-03-31

**Goal**

Refactor `packages/ejector` so it can operate using only L1/L2 HTTP RPC endpoints while preserving current watchdog-triggered ejection behavior and current reorg-triggered ejection behavior as closely as possible.

## Current State

`ejector` currently depends on WebSocket subscriptions in two places:

- L1 operator-cache updates use `OperatorAdded_filter().subscribe()` against `l1_ws_url`.
- L2 head/reorg monitoring uses `subscribe_blocks()` against `l2_ws_url`.

It already uses HTTP for:

- startup contract reads and cache bootstrap
- ejection transactions
- sync-status checks
- anchor queries

The current design mixes watchdog policy with transport-specific stream handling in `src/monitor.rs`.

## Constraints

- L1 and L2 connectivity must work with HTTP-only endpoints.
- Detection latency is best-effort rather than low-latency pubsub parity.
- Reorg-triggered ejection must preserve current behavior rather than being relaxed or disabled.
- Existing safety checks must remain fail-closed when chain state is ambiguous.

## Recommended Approach

Use `event-scanner` for the L1 log-following path and implement a dedicated HTTP block poller for the L2 head/reorg path.

This is preferable to polling both sides directly with raw `alloy` because:

- `event-scanner` already provides the right semantics for HTTP-backed log replay and live follow.
- L2 monitoring is fundamentally block-oriented rather than log-oriented, so forcing it through `event-scanner` would be a poor fit.
- The split keeps the refactor focused while still removing all WebSocket requirements.

## Architecture

### 1. L1 Operator Scanner

Introduce a small helper responsible for keeping the operator cache in sync from the preconfirmation whitelist contract over HTTP.

Responsibilities:

- build an HTTP-backed `event-scanner`
- subscribe to whitelist events relevant to cache correctness
- trigger cache refreshes after event batches
- retry with backoff on scanner failures

Expected event coverage:

- `OperatorAdded`
- `OperatorRemoved`

`EjecterUpdated` does not affect proposer/sequencer cache correctness and should remain out of scope unless later requirements expand.

### 2. L2 Head Poller

Introduce a dedicated HTTP poller that replaces the current L2 block subscription loop.

Responsibilities:

- poll `latest` head on a fixed interval
- fetch missing blocks when height advances
- feed blocks into `ChainReorgTracker`
- reconstruct reorgs from fetched block ancestry
- preserve the current watchdog timestamps and reconnect/backoff behavior

This component should expose processed block events to the existing decision logic rather than duplicating ejection policy.

### 3. Monitor As Coordinator

Keep `Monitor` as the orchestrator for:

- watchdog timing
- operator-cache ownership
- reorg-ejection policy
- anchor-based re-anchoring checks
- sync-status safety checks
- transaction submission

Transport and polling details should move into focused helpers so `Monitor` consumes normalized updates instead of directly managing subscriptions.

## Detailed Data Flow

### Startup

1. Parse only HTTP endpoint config for L1 and L2.
2. Build HTTP providers for L1 and L2.
3. Bootstrap the operator cache from on-chain contract state using the existing `initialize_eject_metrics()` path.
4. Start the L1 operator scanner task.
5. Start the L2 head poller task.
6. Start the watchdog task.

### L1 Operator Cache Refresh

On any scanner batch containing relevant whitelist logs:

1. Ignore per-log cache mutation as the primary state source.
2. Refresh the full active operator set from contract state.
3. Replace the in-memory cache atomically.

Refresh-from-state is the preferred design because it is simpler and more robust than replaying cache mutations from logs across reconnects, duplicates, and removed logs.

To guard against missed log delivery or provider issues, the scanner should also trigger a periodic full refresh on a slower cadence.

### L2 Head Tracking

On each poll tick:

1. Read the latest block number.
2. If unchanged, do nothing except maintain normal timing state.
3. If advanced, fetch each missing block in ascending order.
4. Apply each fetched block to `ChainReorgTracker`.
5. Reuse existing logic for:
   - duplicate suppression
   - rollback detection
   - chain reset grace periods
   - reorg depth thresholds
   - anchor-based re-anchoring detection
   - sync-status-based skip behavior
   - culprit coinbase to operator resolution

### Reorg Reconstruction

HTTP polling can miss intermediate notifications, so the poller must reconstruct head progression from fetched block data rather than assuming a single latest block is enough.

Required behavior:

- if the head advanced by `N` blocks, fetch all blocks in the gap
- if the new chain conflicts with the tracked local chain, walk ancestors until a common parent is found
- apply the reconstructed canonical sequence in order
- if ancestry cannot be reconstructed within the retained local history window, treat the chain view as uncertain and fail closed

Fail-closed means:

- do not eject based on partial reorg evidence
- reset local head-tracking state as needed
- enter the same grace-style safety path used for other uncertain conditions

## Config Changes

Remove:

- `l1_ws_url`
- `l2_ws_url`

Keep:

- `l1_http_url`
- `l2_http_url`

Add only if needed during implementation:

- `l1_event_poll_interval_ms`
- `l2_block_poll_interval_ms`
- `l1_full_refresh_interval_secs`

If defaults are sufficient, prefer hardcoded internal constants first and add config later only if testing or operations prove it necessary.

## File-Level Plan

### Files To Modify

- `bin/ejector/src/main.rs`
  - remove WS URL parsing and monitor wiring
- `src/config.rs`
  - remove WS config fields and update tests
- `src/monitor.rs`
  - replace inline WS loops with helper-driven HTTP tasks
  - keep watchdog and ejection policy logic
- `Cargo.toml`
  - add `event-scanner`
  - add any supporting provider dependencies needed for HTTP-backed scanner wiring

### Files To Add

- `src/l1_operator_scanner.rs`
  - scanner setup, filtering, backoff, full refresh triggers
- `src/l2_head_poller.rs`
  - block polling, gap fetch, ancestry reconstruction, normalized head/reorg events

These helper names are descriptive placeholders and can be adjusted if implementation reveals a better fit with existing module structure.

## Error Handling

### L1 Scanner Errors

- retry with bounded exponential backoff
- keep serving from the last known cache
- surface scanner health in logs and metrics
- allow periodic full refresh to repair stale cache state

### L2 Polling Errors

- retry with bounded exponential backoff
- avoid advancing head state from incomplete fetches
- mark uncertainty when ancestry reconstruction fails
- skip ejection during uncertain periods

### Provider Ambiguity

If the provider returns inconsistent or incomplete data, prefer skipping ejection over risking a false positive. Preserving behavior means preserving policy when data is trustworthy, not forcing action when the chain view is uncertain.

## Testing Strategy

### Config Tests

Update config parsing tests to remove WS fields and validate HTTP-only startup.

### L1 Scanner Tests

- HTTP-backed scanner reaches live mode
- `OperatorAdded` triggers cache refresh
- `OperatorRemoved` triggers cache refresh
- scanner retry path preserves old cache until refresh succeeds

### L2 Poller Tests

- latest head unchanged produces no synthetic progress
- multi-block gap fetch replays blocks in order
- ancestry divergence is detected as reorg
- deep or uncertain ancestry gaps fail closed
- current reorg threshold and anchor skip logic still gate ejection correctly

### Monitor Integration Tests

Add focused integration-style tests around normalized poller/scanner outputs if unit coverage alone does not prove parity with current behavior.

## Rollout Notes

Operationally, HTTP-only mode will likely have slightly higher detection latency than WS subscriptions. This is acceptable under the stated best-effort requirement, provided the system remains conservative under ambiguity and preserves the same ejection decisions once sufficient data is observed.

## Non-Goals

- changing operator ejection policy
- redesigning watchdog semantics
- adding new contract-driven behaviors unrelated to cache correctness
- introducing a generic scanner abstraction for unrelated packages

## Success Criteria

The design is successful when:

- `ejector` no longer requires any WebSocket endpoint configuration
- L1 operator cache stays correct using HTTP-only event following plus refresh
- L2 watchdog and reorg-ejection logic behave the same under normal observable conditions
- ambiguous HTTP-only gaps fail closed rather than causing false operator ejections
