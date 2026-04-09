# Ejector HTTP-Only Refactor Design

## Summary

Refactor `packages/ejector` to operate entirely over `L1_HTTP_URL` and `L2_HTTP_URL`, removing all WebSocket dependencies. Reuse the `event-scanner` library for L1 whitelist events over HTTP, and replace the L2 WebSocket block subscription with an HTTP polling path that is explicitly hardened for proxy-backed RPC endpoints where successive requests may hit different backend nodes.

The main success criterion is safety: small detection delay is acceptable, but transient backend inconsistency or lag behind a proxy must not cause false-positive operator ejection.

## Goals

- Remove `L1_WS_URL` and `L2_WS_URL` from config, startup, and runtime behavior.
- Follow L1 whitelist events over HTTP using `event-scanner`.
- Track L2 head changes and reorgs over HTTP without relying on push subscriptions.
- Preserve existing ejection business rules.
- Bias toward skipping ejection whenever the HTTP view is inconsistent or uncertain.

## Non-Goals

- No broader shared crate extraction in this refactor.
- No behavior change to the actual ejection thresholds or contract interactions.
- No persistence of scanner or poller progress across process restarts unless required by existing code.
- No attempt to fully unify `ejector` with `taiko-client-rs` abstractions beyond reusing the `event-scanner` pattern and library.

## Current State

`packages/ejector` currently mixes transports:

- L1 HTTP is used for reads and ejection transactions.
- L1 WebSocket is used for `OperatorAdded` event subscription.
- L2 HTTP is used for sync checks and some reorg-related reads.
- L2 WebSocket is used for `subscribe_blocks()` and drives the main liveness loop.

This design is brittle for HTTP proxy deployments because the current logic assumes a mostly stable backend view and treats missing WebSocket activity as a strong signal. After the refactor, all transport assumptions must be safe under backend switching and small head inconsistencies.

## Proposed Architecture

### 1. HTTP-only configuration

Remove:

- `l1_ws_url`
- `l2_ws_url`

Keep:

- `l1_http_url`
- `l2_http_url`

Update CLI parsing, tests, and startup wiring so the monitor receives only HTTP endpoints.

### 2. L1 whitelist event ingestion via `event-scanner`

Replace the current `operator_added_listener` WebSocket loop with an HTTP-backed scanner built using the same `event-scanner` and `robust-provider` pattern used in `../taiko-client-rs`.

Behavior:

- Build an `EventFilter` for `OperatorAdded` and `OperatorRemoved` on `IPreconfWhitelist`.
- Start from a bounded replay window near the current head.
- Consume scanner messages until `Notification::SwitchingToLive`, then continue in live-follow mode.
- For each matching log:
  - Ignore removed logs.
  - Decode the event.
  - Update `OperatorCache` idempotently.
  - Maintain metrics for known operators.

Safety rules:

- Duplicate or replayed logs must not corrupt the cache.
- Scanner reconnects or proxy backend switches must be treated as normal; replayed logs are acceptable.
- Event application must be monotonic in effect even if the same log appears more than once.

### 3. L2 block tracking via custom HTTP poller

Replace `subscribe_blocks()` with a poll loop that:

1. Polls `eth_blockNumber` on `L2_HTTP_URL`.
2. Compares the returned head with the last stable observed head.
3. Fetches new block headers with `get_block_by_number` for any forward range that needs to be processed.
4. Feeds each fetched header into the existing `ChainReorgTracker`.
5. Updates watchdog state only when forward progress is confirmed.

The poller should expose three logical outcomes to the rest of the monitor:

- `StableProgress`: one or more new canonical headers were ingested.
- `NoProgress`: no new trustworthy head was observed.
- `UncertainBackend`: the HTTP responses are inconsistent, incomplete, or otherwise not trustworthy enough for ejection decisions.

Recommended handling details:

- Poll interval can be modest because a small delay is acceptable.
- If the head jumps forward by more than one block, fetch intermediate headers in order when feasible.
- If a header is unavailable, malformed, or has an unexpected parent relationship, treat that interval as `UncertainBackend`.
- A lower head after a higher head is not by itself a rollback signal; it is a backend inconsistency signal.

### 4. Watchdog semantics

The watchdog must stop interpreting transport silence as an eject signal. Instead, ejection should only be considered when all of the following are true:

- No `StableProgress` has been observed for the full eject timeout window.
- The current interval is not flagged as `UncertainBackend`.
- L2 sync checks do not indicate the node is syncing.
- L1 sync checks do not indicate the node is syncing.
- Recent chain reset grace-period logic does not suppress ejection.

If the L2 poller reports `UncertainBackend`, the watchdog should:

- Skip eject for that interval.
- Avoid advancing any state that would make the system look more certain than it is.
- Prefer resetting or soft-resyncing the poller state over inferring operator fault.

### 5. Reorg detection over HTTP

Reorg-triggered ejection remains based on `ChainReorgTracker`, anchor checks, and existing thresholds, but the evidence source changes from WS headers to polled HTTP headers.

Rules:

- Reorg detection must come from parent/hash relationships between fetched headers, not from raw block-number movement.
- If the poller cannot build a reliable header chain for a period, it should suppress reorg-based eject decisions.
- Existing anchor-based re-anchoring checks remain in place and continue to override reorg ejection when re-anchoring is detected.
- Failure to read anchor state should continue to bias toward skipping reorg-based eject if sync uncertainty is present.

## Proxy-backed HTTP Safety Model

Because `L1_HTTP_URL` and `L2_HTTP_URL` may point to a proxy with multiple backend nodes, the system must assume:

- successive requests may hit different nodes,
- those nodes may be temporarily at different heights,
- some requests may observe stale or incomplete history,
- a backend swap can look like a head decrease or missing block.

To avoid false positives:

- head decreases are treated as uncertainty, not immediate rollback;
- missing intermediate blocks are treated as uncertainty, not malice;
- inconsistent parent links from fetched headers trigger safe resync, not ejection;
- repeated RPC failures trigger skip-and-retry behavior, not fallback to blame;
- only confirmed forward canonical progress resets the liveness timer.

This intentionally sacrifices aggressiveness under RPC instability in exchange for safety.

## Component-Level Changes

### `src/config.rs`

- Remove `l1_ws_url` and `l2_ws_url`.
- Update tests to reflect HTTP-only CLI arguments.

### `bin/ejector/src/main.rs`

- Stop parsing WS URLs.
- Pass only HTTP URLs into `Monitor::new`.

### `src/monitor.rs`

- Replace the current L1 WebSocket event listener task with an HTTP `event-scanner` task.
- Replace the current L2 WebSocket connect / subscribe / reconnect loop with the HTTP poller state machine.
- Introduce a small params struct for monitor construction if argument count would otherwise grow or remain too large.
- Preserve existing sync checks, chain-reset grace logic, reorg thresholds, anchor-based re-anchoring checks, and ejection calls.
- Shift watchdog state updates so only confirmed HTTP progress counts as progress.

### `Cargo.toml`

- Add `event-scanner`.
- Add `robust-provider` with HTTP subscription support if needed by the chosen integration path.
- Add any small supporting dependency required for stream handling if not already present.

## Testing Plan

### Config and startup

- Update config parsing tests for HTTP-only inputs.
- Verify startup rejects malformed HTTP URLs and no longer expects WS URLs.

### L1 scanner behavior

- Duplicate `OperatorAdded` log does not create duplicate cache effects.
- `OperatorRemoved` replay is idempotent.
- Scanner replay after reconnect produces the correct final cache state.

### L2 poller behavior

- Forward head progression ingests headers and resets the liveness timer.
- Head decreases are classified as backend uncertainty and do not trigger ejection.
- Missing intermediate header causes safe uncertainty handling.
- Inconsistent parent linkage causes safe tracker reset / resync behavior.
- Reorg detection still works when a valid alternate canonical chain is observed via HTTP.

### Watchdog safety

- Prolonged `NoProgress` with healthy sync state can still trigger eject.
- `UncertainBackend` suppresses eject even when the timeout window is exceeded.
- Syncing L1/L2 nodes still suppress eject.
- Chain-reset grace period still suppresses eject.

## Risks and Mitigations

### Risk: scanner replay window too short

Mitigation:

- Use a bounded historical window from recent head and rely on existing initialization from on-chain state to seed the cache.
- Keep cache updates idempotent so a slightly larger replay window is safe.

### Risk: proxy backend switching causes persistent apparent regressions

Mitigation:

- Treat regressions as uncertainty rather than evidence of faults.
- Require confirmed canonical forward progress before resetting the timer.

### Risk: L2 polling misses transient heads

Mitigation:

- This is acceptable because the requirement tolerates small detection delay.
- Ejection is based on prolonged lack of progress, not exact observation of every block.

## Recommended Implementation Order

1. Remove WS config and startup wiring.
2. Add L1 HTTP event-scanner path and tests.
3. Add L2 HTTP poller with explicit uncertainty states.
4. Rewire watchdog to consume the new poller semantics.
5. Add proxy-instability and false-positive prevention tests.

## Acceptance Criteria

- `packages/ejector` runs with only `L1_HTTP_URL` and `L2_HTTP_URL`.
- No WebSocket connection attempts remain in runtime code.
- L1 whitelist event handling works over HTTP.
- L2 reorg and liveness handling work over HTTP.
- Proxy/backend inconsistency biases toward skipping eject rather than false-positive eject.
- Existing eject behavior still occurs when there is confirmed prolonged lack of progress and sync-state checks allow it.
