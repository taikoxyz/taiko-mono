# Preconfirmation RPC-Backed DriverClient Design

Date: 2026-02-01

## Goal

Replace the channel-based EmbeddedDriverClient wiring used by the preconfirmation runner with an RPC-backed DriverClient. The new client should:

- Use L2 safe for `event_sync_tip`.
- Use L2 latest for `preconf_tip`.
- Submit preconfirmation payloads directly to the in-process EventSyncer preconfirmation ingress.
- Keep existing P2P catch-up and gossip flow semantics unchanged.

## Non-Goals

- Changing preconfirmation validation rules or commitment ordering.
- Changing the driver EventSyncer ingestion model.
- Removing the existing PreconfirmationDriverNode type (it remains for other uses).

## Architecture

Add a new DriverClient implementation in `crates/preconfirmation-driver/src/driver_interface/` (e.g. `event_syncer.rs`). It mirrors the test-harness `EventSyncerDriverClient` pattern:

- Holds `Arc<EventSyncer<P>>` to submit preconfirmation payloads.
- Holds `InboxInstance<P>` to read L1 inbox state during `wait_event_sync`.
- Holds `RootProvider` (L2 provider) to query safe/latest tips.

Update the runner to build this DriverClient directly from the same RPC client used by `PreconfIngressSync`. The runner flow stays:

1. Start `PreconfIngressSync` (spawns EventSyncer).
2. Wait for `wait_preconf_ingress_ready()`.
3. Build the new DriverClient and pass it into `PreconfirmationClient::new`.
4. Call `sync_and_catchup()` and then run the P2P event loop.
5. Start optional preconfirmation RPC server.

## Data Flow

- Gossip commitments/txlists are validated and queued by `EventHandler` as before.
- `submit_if_ready()` calls `DriverClient::submit_preconfirmation()`; the RPC-backed client:
  - Builds `TaikoPayloadAttributes` from the `PreconfirmationInput`.
  - Calls `event_syncer.submit_preconfirmation_payload(PreconfPayload::new(payload))`.
- `PreconfirmationClient::sync_and_catchup()` calls:
  - `wait_event_sync()` (uses inbox + `event_syncer.subscribe_proposal_id()`),
  - `event_sync_tip()` (L2 safe),
  - `preconf_tip()` (L2 latest).

## RPC API Changes

Add a new RPC API impl to replace the watch-channel based `NodeRpcApiImpl` for the runner path:

- `canonical_proposal_id()` reads `event_syncer.last_canonical_proposal_id()` (or cached subscribe value).
- `preconf_tip()` calls the new DriverClient (L2 latest).
- `get_status()` uses the inbox `nextProposalId` plus canonical id to compute sync status (same logic as before).

## Error Handling

- EventSyncer failures are surfaced via existing `RunnerError` paths.
- `submit_preconfirmation_payload` errors map to `DriverApiError` and are bubbled through `DriverClient::submit_preconfirmation()`.
- Safe tip availability failures return `MissingSafeBlock`; no automatic fallback unless explicitly wrapped (optional future).

## Testing

- Add unit tests for the new DriverClient using a mocked provider (safe/latest queries) and a stub EventSyncer.
- Update or add a runner integration test to verify:
  - `event_sync_tip` uses L2 safe,
  - `preconf_tip` uses L2 latest,
  - preconfirmation submission enqueues into EventSyncer.
- Keep existing preconfirmation tests intact; no changes to P2P validation flow.

## Rollout Notes

- Keep `PreconfirmationDriverNode` unchanged for now to avoid breaking non-runner consumers.
- Document that the runner now uses the RPC-backed driver client rather than channel wiring.
