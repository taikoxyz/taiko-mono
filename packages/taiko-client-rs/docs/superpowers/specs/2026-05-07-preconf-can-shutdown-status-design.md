# Preconfirmation canShutdown Status Design

## Goal

Mirror taiko-client PR #21648 in `taiko-client-rs` with the smallest strict-parity change needed for preStop-style probes:

- expose `canShutdown` on the whitelist preconfirmation `GET /status` JSON response;
- return `canShutdown = false` while this node's P2P signer is the current epoch operator or the imminent next epoch operator during the handover window;
- return `canShutdown = true` when the sequencing window is uninitialized or the current slot is outside this node's current/next windows;
- allow unauthenticated reads of `/`, `/healthz`, and `/status` when a preconfirmation JWT secret is configured;
- keep `/preconfBlocks` and `/ws` authenticated when a JWT secret is configured.

The implementation must stay focused in `crates/whitelist-preconfirmation-driver` unless a tiny protocol helper is needed to avoid duplicating contract call wrappers.

## Context

The Rust equivalent of the Go preconfirmation block server is the whitelist preconfirmation REST/WS server:

- `crates/whitelist-preconfirmation-driver/src/api/server/router.rs` defines `/`, `/healthz`, `/status`, `/preconfBlocks`, and `/ws`.
- `crates/whitelist-preconfirmation-driver/src/api/server/auth.rs` currently applies JWT validation to every non-OPTIONS route when a secret is configured.
- `crates/whitelist-preconfirmation-driver/src/api/types.rs` defines the internal and REST status response shapes.
- `crates/whitelist-preconfirmation-driver/src/api/service/status.rs` builds the current status snapshot.

The existing `SharedOperatorSet` is not enough for `canShutdown`: it only tracks all registered sequencer addresses. It does not identify whether this node is current or imminent, so using it would make shutdown decisions too coarse.

Relevant invariants:

- `WLP-INV-002`: do not weaken the existing ingress readiness gate.
- `WLP-INV-003` and `WLP-INV-004`: do not let status/probe changes affect stale preconf rejection or confirmed block safety.
- `WLP-INV-010`: keep Rust behavior aligned with protocol and taiko-client assumptions.

## Design

Add a small sequencing-window helper inside `crates/whitelist-preconfirmation-driver`.

The helper stores a bounded three-epoch ring of:

- epoch number;
- current operator address;
- next operator address;
- validity bit.

Given this node's P2P signer address, `slots_per_epoch`, and a fixed handover skip, it derives two sets of half-open global-slot ranges:

- current range: `[epoch * slots_per_epoch, epoch * slots_per_epoch + threshold)`;
- next range: `[epoch * slots_per_epoch + threshold, (epoch + 1) * slots_per_epoch)`;
- `threshold = slots_per_epoch - handover_skip_slots`.

Adjacent or overlapping ranges are merged, matching Go's range model. `can_shutdown(global_slot)` returns `false` if `global_slot` falls inside either current or next range, and `true` otherwise. If no window has been initialized, it returns `true`.

Keep the first implementation minimal:

- use the existing beacon metadata for `current_slot`, `current_epoch`, and `slots_per_epoch`;
- use the existing generated `PreconfWhitelist` binding to fetch `getOperatorForCurrentEpoch()` and `getOperatorForNextEpoch()`;
- refresh the local window inside `get_status_snapshot` when the tracker is uninitialized or the beacon `current_epoch` changed;
- reuse the last successfully cached window if a status-time refresh fails;
- do not introduce a new public CLI flag unless implementation proves there is already a Rust handover setting to reuse.

The Go default handover skip is four slots. Rust should use the same constant in the helper unless an existing local constant already represents the same protocol value.

## API Changes

Extend the internal status model:

- `WhitelistStatus.can_shutdown: bool`

Extend the REST status response:

- `ApiStatus.can_shutdown: bool`, serialized as `canShutdown`.

Keep existing status fields unchanged:

- `highestUnsafeL2PayloadBlockId`;
- `endOfSequencingBlockHash`.

The unauthenticated probe routes are exactly:

- `GET /`;
- `GET /healthz`;
- `GET /status`.

When JWT is configured, all other routes remain authenticated, including:

- `POST /preconfBlocks`;
- `GET /ws`;
- unknown fallback routes.

## Non-Goals

- Do not rewrite the lookahead resolver or event scanner.
- Do not replace the existing `SharedOperatorSet` validation model.
- Do not change preconfirmation ingress readiness, stale-boundary handling, cache import, or P2P gossip semantics.
- Do not make `/preconfBlocks` shutdown/window enforcement stricter in this PR unless a direct existing parity hook is already present and safe to reuse.
- Do not modify generated bindings.

## Error Handling

`GET /status` should continue returning existing status data when possible.

For `canShutdown` specifically:

- if the local sequencing window is not initialized, return `true`;
- if the beacon client is unavailable, return `true`;
- if a refresh attempt fails, log the error and use the last successfully cached window;
- if no successful window exists after a refresh failure, return `true`.

This matches the Go PR's uninitialized-state behavior: no loaded duties means there is nothing known to protect from shutdown.

## Testing

Add focused tests only:

- unit tests for range merge, current/next range derivation, and `can_shutdown` boundaries;
- status serialization test proving `canShutdown` is emitted in camelCase;
- server auth tests proving `/`, `/healthz`, and `/status` bypass JWT while `/preconfBlocks` and `/ws` still require JWT when a secret is configured.

During implementation, use targeted crate tests while iterating. Before declaring implementation complete, run the repository-required final verification: `just fmt && just clippy-fix && just test`.
