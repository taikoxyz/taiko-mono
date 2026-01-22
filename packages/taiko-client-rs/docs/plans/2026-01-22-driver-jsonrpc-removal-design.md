# Driver JSON-RPC Removal Design

**Date:** 2026-01-22

## Goal

Remove the driver JSON-RPC server surface (HTTP+JWT and IPC) and the deprecated JSON-RPC driver client in `preconfirmation-driver`, leaving only embedded channel-based integration.

## Non-Goals

- No backward compatibility for external driver JSON-RPC consumers.
- No changes to the preconfirmation node's user-facing RPC server.
- No protocol or payload format changes.

## Current State

- `crates/driver` exposes `DriverRpcServer` (HTTP+JWT) and `DriverIpcServer` (IPC) in `jsonrpc`.
- `DriverConfig` includes `rpc_listen_addr`, `rpc_jwt_secret`, `rpc_ipc_path` and `Driver::run` conditionally starts HTTP/IPC servers.
- `crates/preconfirmation-driver` contains a deprecated JSON-RPC driver client (`driver_interface/jsonrpc.rs`) supporting HTTP+JWT or IPC.
- Embedded integration uses `EmbeddedDriverClient` and `DriverChannels` for in-process communication.

## Proposed Changes

1. **Remove driver JSON-RPC server**

   - Delete `crates/driver/src/jsonrpc` module.
   - Remove `DriverRpcServer`, `DriverIpcServer`, and `DriverRpcApi` exports and usages.
   - Simplify `Driver::run` to remove RPC server startup/shutdown paths.
   - Remove `DriverConfig` RPC fields and any config parsing or flags tied to them.
   - Remove JSON-RPC-specific errors, metrics, and tests.

2. **Remove deprecated JSON-RPC driver client**
   - Delete `crates/preconfirmation-driver/src/driver_interface/jsonrpc.rs`.
   - Remove any tests or docs referencing this client.
   - Keep `EmbeddedDriverClient` and channel-based integration as the only supported path.

## Affected Areas

- `crates/driver/src/lib.rs`
- `crates/driver/src/driver.rs`
- `crates/driver/src/config.rs`
- `crates/driver/src/error.rs` (RPC/JWT/IPC error variants)
- `crates/driver/src/metrics.rs` (RPC-specific metrics)
- `crates/driver/tests/*` (RPC server tests)
- `crates/preconfirmation-driver/src/driver_interface/` (remove `jsonrpc.rs`)
- `crates/preconfirmation-driver/README.md` (remove JSON-RPC client references)
- `bin/client` or other CLI config surfaces (remove RPC flags if present)

## Data Flow After Change

- Preconfirmation inputs flow through `EmbeddedDriverClient` -> `DriverChannels` -> driver sync pipeline.
- No network sockets are bound by the driver for JSON-RPC.
- Driver lifecycle logs no longer mention HTTP/IPC RPC servers.

## Risks

- Any external tools/scripts relying on driver JSON-RPC will break.
- Any undocumented tests/configs referencing `rpc_*` settings must be removed.

## Testing

- Remove JSON-RPC server tests.
- Keep embedded integration tests for preconfirmation driver.
- Run `just fmt` and `just clippy` if code changes land; for doc-only updates, skip and document.
