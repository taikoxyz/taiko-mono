# Preconfirmation Node Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the standalone preconfirmation client with an embedded preconfirmation node that hosts the driver in-process and exposes a user-facing JSON-RPC API.

**Architecture:** Rename the crate to `preconfirmation-node`, introduce `EmbeddedDriverClient` to submit payloads directly into the driver event syncer, add a JSON-RPC server for user interactions, and orchestrate everything inside a new `PreconfirmationNode` entry point. The driver’s standalone JSON-RPC is kept behind an opt-in feature for the CLI only.

**Tech Stack:** Rust, tokio, jsonrpsee (HTTP server), alloy types

---

### Task 1: Rename `preconfirmation-client` crate to `preconfirmation-node`

**Files:**

- Modify: `crates/preconfirmation-client/Cargo.toml`
- Modify: root `Cargo.toml`
- Modify: any `Cargo.toml` that depends on `preconfirmation-client`
- Modify: `README.md`, `AGENTS.md`, examples/tests imports

**Step 1: Write failing test (crate name expected)**

Create `crates/preconfirmation-client/tests/preconfirmation_node_crate.rs`:

```rust
#[test]
fn preconfirmation_node_crate_is_available() {
    let _ = preconfirmation_node::PreconfirmationClientConfig::default();
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-client --test preconfirmation_node_crate`

Expected: FAIL (crate `preconfirmation_node` not found)

**Step 3: Rename crate and update workspace references**

- Update `crates/preconfirmation-client/Cargo.toml` package name to `preconfirmation-node`.
- Update workspace member paths and any dependency entries referencing `preconfirmation-client`.
- Update code imports to `preconfirmation_node` where needed.
- Move/rename crate directory to `crates/preconfirmation-node`.

**Step 4: Re-run test to verify it passes**

Run: `cargo test -p preconfirmation-node --test preconfirmation_node_crate`

Expected: PASS

**Step 5: Commit**

Skip commit (per user request: no git add/commit).

---

### Task 2: Add `EmbeddedDriverClient` (direct driver integration)

**Files:**

- Create: `crates/preconfirmation-node/src/driver_interface/embedded.rs`
- Modify: `crates/preconfirmation-node/src/driver_interface/mod.rs`
- Modify: `crates/preconfirmation-node/src/driver_interface/traits.rs`
- Modify: `crates/preconfirmation-node/src/error.rs`

**Step 1: Write failing test**

Add to `crates/preconfirmation-node/src/driver_interface/mod.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::DriverClient;

    #[test]
    fn embedded_driver_client_is_driver_client() {
        fn assert_trait<T: DriverClient>() {}
        assert_trait::<super::embedded::EmbeddedDriverClient>();
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-node driver_interface`

Expected: FAIL (module `embedded` not found)

**Step 3: Implement `EmbeddedDriverClient`**

- Create `embedded.rs` using the driver `EventSyncer` + RPC client for payload build.
- Ensure `DriverClient` is implemented for `Arc<T>` in `traits.rs`.
- Add/adjust error variants in `error.rs` for embedded driver failures.

**Step 4: Re-run test to verify it passes**

Run: `cargo test -p preconfirmation-node driver_interface`

Expected: PASS

**Step 5: Commit**

Skip commit (per user request).

---

### Task 3: Add user-facing RPC API + types

**Files:**

- Create: `crates/preconfirmation-node/src/rpc/mod.rs`
- Create: `crates/preconfirmation-node/src/rpc/types.rs`
- Create: `crates/preconfirmation-node/src/rpc/api.rs`
- Create: `crates/preconfirmation-node/src/rpc/server.rs`

**Step 1: Write failing test**

Create `crates/preconfirmation-node/tests/rpc_api.rs`:

```rust
#[test]
fn rpc_api_trait_is_generated() {
    fn assert_trait<T: preconfirmation_node::rpc::PreconfRpcApiServer>() {}
    assert_trait::<preconfirmation_node::rpc::PreconfRpcApiImpl>();
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-node --test rpc_api`

Expected: FAIL (rpc module missing)

**Step 3: Implement RPC types + API + server**

- Define request/response structs in `types.rs`.
- Implement JSON-RPC trait + handler in `api.rs` using `jsonrpsee`.
- Implement HTTP server wrapper in `server.rs` with start/stop.

**Step 4: Re-run test to verify it passes**

Run: `cargo test -p preconfirmation-node --test rpc_api`

Expected: PASS

**Step 5: Commit**

Skip commit (per user request).

---

### Task 4: Add `PreconfirmationNode` orchestrator

**Files:**

- Create: `crates/preconfirmation-node/src/node.rs`
- Modify: `crates/preconfirmation-node/src/lib.rs`
- Modify: `crates/preconfirmation-node/src/error.rs`

**Step 1: Write failing test**

Create `crates/preconfirmation-node/tests/node_compiles.rs`:

```rust
#[test]
fn node_types_exist() {
    let _ = std::mem::size_of::<preconfirmation_node::PreconfirmationNodeConfig>();
    let _ = std::mem::size_of::<preconfirmation_node::PreconfirmationNode>();
    let _ = preconfirmation_node::RpcServerConfig::default();
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-node --test node_compiles`

Expected: FAIL (node types missing)

**Step 3: Implement node orchestration**

- Create `PreconfirmationNodeConfig` and `PreconfirmationNode` in `node.rs`.
- Wire driver + embedded client + preconfirmation client + RPC server.
- Add RPC server error variant in `error.rs`.
- Export node types from `lib.rs`.

**Step 4: Re-run test to verify it passes**

Run: `cargo test -p preconfirmation-node --test node_compiles`

Expected: PASS

**Step 5: Commit**

Skip commit (per user request).

---

### Task 5: Driver updates for embedded usage + standalone RPC feature gating

**Files:**

- Modify: `crates/driver/Cargo.toml`
- Modify: `crates/driver/src/driver.rs`
- Modify: `crates/driver/src/lib.rs`
- Modify: `crates/driver/src/sync/event.rs`
- Modify: `crates/driver/tests/driver_rpc_server.rs`
- Modify: `bin/client/Cargo.toml`
- Modify: `crates/test-harness/src/preconfirmation/driver.rs`

**Step 1: Add standalone RPC feature gate**

Add `standalone-rpc` feature in `crates/driver/Cargo.toml`:

```toml
[features]
default = []
standalone-rpc = ["dep:jsonrpsee", "dep:tower", "dep:reth-ipc"]
```

**Step 2: Gate JSON-RPC modules and tests**

- Wrap `mod jsonrpc` in `driver/src/lib.rs` with `#[cfg(feature = "standalone-rpc")]`.
- Gate `DriverRpcApi` impl in `driver/src/sync/event.rs`.
- Add `#![cfg(feature = "standalone-rpc")]` to `driver/tests/driver_rpc_server.rs`.

**Step 3: Update driver to expose EventSyncer**

- Store `EventSyncer` in `Driver` struct.
- Add `event_syncer()` accessor.
- Gate JSON-RPC server startup in `Driver::run` behind feature.

**Step 4: Update CLI to enable standalone RPC**

- In `bin/client/Cargo.toml`, enable driver with `features = ["standalone-rpc"]`.

**Step 5: Update test harness for embedded driver**

- Replace JSON-RPC driver client usage in `RealDriverSetup` with embedded driver client.
- Update `StartingBlockInfo` to include `gas_limit` instead of `parent_gas_limit`.

**Step 6: Commit**

Skip commit (per user request).
