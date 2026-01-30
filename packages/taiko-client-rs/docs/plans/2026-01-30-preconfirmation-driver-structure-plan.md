# Preconfirmation Driver Structure Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the preconfirmation-driver crate structure (A+B scope) for clearer ownership of runner, RPC, subscription, storage, and sync logic without changing behavior or public APIs.

**Architecture:** Keep `lib.rs` exports stable while splitting large modules into focused submodules. Runner sync bootstrap moves under `runner/`, node RPC implementation moves under `rpc/`, and storage/sync/subscription internals split into smaller files with `mod.rs` re-exports.

**Tech Stack:** Rust, Tokio, Alloy, preconfirmation_net, preconfirmation_types.

**Note:** Execution will occur in the current working tree (per user request), not a fresh worktree.

### Task 1: Move driver sync helper under runner/

**Files:**

- Create: `crates/preconfirmation-driver/src/runner/mod.rs`
- Create: `crates/preconfirmation-driver/src/runner/driver_sync.rs`
- Delete: `crates/preconfirmation-driver/src/preconf_ingress_sync.rs`
- Modify: `crates/preconfirmation-driver/src/lib.rs`

**Step 1: Write the failing test**

Add a minimal module test to `crates/preconfirmation-driver/src/runner/mod.rs` that references
`driver_sync::driver_sync_module_marker`, and declare `mod driver_sync;` so the test fails until
the module exists.

```rust
#[cfg(test)]
mod tests {
    use super::driver_sync::driver_sync_module_marker;

    #[test]
    fn driver_sync_module_exists() {
        let _ = driver_sync_module_marker;
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-driver runner::tests::driver_sync_module_exists`
Expected: FAIL with "file not found for module `driver_sync`" or missing type error.

**Step 3: Write minimal implementation**

- Move contents of `crates/preconfirmation-driver/src/runner.rs` into
  `crates/preconfirmation-driver/src/runner/mod.rs`.
- Move contents of `crates/preconfirmation-driver/src/preconf_ingress_sync.rs` into
  `crates/preconfirmation-driver/src/runner/driver_sync.rs` and update paths to `super::` as needed.
- Add a test-only marker to `driver_sync.rs`:

```rust
#[cfg(test)]
pub(crate) const driver_sync_module_marker: () = ();
```

- Update `crates/preconfirmation-driver/src/lib.rs` to keep `pub mod runner;` and `pub mod` list
  consistent with `runner/mod.rs`.

**Step 4: Run test to verify it passes**

Run: `cargo test -p preconfirmation-driver runner::tests::driver_sync_module_exists`
Expected: PASS

**Step 5: Commit**

```bash
git add crates/preconfirmation-driver/src/runner/mod.rs \
  crates/preconfirmation-driver/src/runner/driver_sync.rs \
  crates/preconfirmation-driver/src/preconf_ingress_sync.rs \
  crates/preconfirmation-driver/src/lib.rs

git rm crates/preconfirmation-driver/src/preconf_ingress_sync.rs

git commit -m "chore(preconfirmation-driver): move driver sync under runner"
```

### Task 2: Move NodeRpcApiImpl into rpc/node_api.rs

**Files:**

- Create: `crates/preconfirmation-driver/src/rpc/node_api.rs`
- Modify: `crates/preconfirmation-driver/src/rpc/mod.rs`
- Modify: `crates/preconfirmation-driver/src/node.rs`

**Step 1: Write the failing test**

In `crates/preconfirmation-driver/src/rpc/mod.rs`, add a unit test that references
`node_api` (the module will be missing at first):

```rust
#[cfg(test)]
mod tests {
    use super::node_api;

    #[test]
    fn node_api_module_exists() {
        let _ = core::mem::size_of::<Option<fn()>>();
        let _ = &node_api::NodeRpcApiMarker;
    }
}
```

Then, in `crates/preconfirmation-driver/src/rpc/node_api.rs`, plan to add a test-only marker:

```rust
#[cfg(test)]
pub(crate) const NodeRpcApiMarker: () = ();
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-driver rpc::tests::node_api_module_exists`
Expected: FAIL with "file not found for module `node_api`" or missing symbol error.

**Step 3: Write minimal implementation**

- Move `NodeRpcApiImpl` from `crates/preconfirmation-driver/src/node.rs` to
  `crates/preconfirmation-driver/src/rpc/node_api.rs`.
- Keep the struct `pub(crate)` and add `#[cfg(test)] pub(crate) const NodeRpcApiMarker: () = ();` for the test.
- Update `crates/preconfirmation-driver/src/rpc/mod.rs` to `mod node_api;`.
- Update `crates/preconfirmation-driver/src/node.rs` to use `rpc::node_api::NodeRpcApiImpl`.

**Step 4: Run test to verify it passes**

Run: `cargo test -p preconfirmation-driver rpc::tests::node_api_module_exists`
Expected: PASS

**Step 5: Commit**

```bash
git add crates/preconfirmation-driver/src/rpc/node_api.rs \
  crates/preconfirmation-driver/src/rpc/mod.rs \
  crates/preconfirmation-driver/src/node.rs

git commit -m "chore(preconfirmation-driver): move node RPC impl into rpc module"
```

### Task 3: Split subscription module into event_handler + submission

**Files:**

- Create: `crates/preconfirmation-driver/src/subscription/event_handler.rs`
- Create: `crates/preconfirmation-driver/src/subscription/submission.rs`
- Modify: `crates/preconfirmation-driver/src/subscription/mod.rs`

**Step 1: Write the failing test**

Add a test in `crates/preconfirmation-driver/src/subscription/mod.rs` that references
`event_handler::event_handler_module_marker` and `submission::submission_module_marker`,
expecting it to fail until the modules exist.

```rust
#[cfg(test)]
mod tests {
    use super::event_handler::event_handler_module_marker;
    use super::submission::submission_module_marker;

    #[test]
    fn subscription_submodules_exist() {
        let _ = event_handler_module_marker;
        let _ = submission_module_marker;
    }
}
```

In `submission.rs`, plan to add:

```rust
#[cfg(test)]
pub(crate) const submission_module_marker: () = ();
```

In `event_handler.rs`, plan to add:

```rust
#[cfg(test)]
pub(crate) const event_handler_module_marker: () = ();
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-driver subscription::tests::subscription_submodules_exist`
Expected: FAIL with module missing errors.

**Step 3: Write minimal implementation**

- Move `PreconfirmationEvent` and `EventHandler` into `event_handler.rs`.
- Move submission helpers (`try_submit_contiguous_from`, `submit_if_ready`, etc.) into
  `submission.rs` and call them from the handler.
- Update `mod.rs` to `mod event_handler; mod submission;` and re-export
  `PreconfirmationEvent` + `EventHandler`.

**Step 4: Run test to verify it passes**

Run: `cargo test -p preconfirmation-driver subscription::tests::subscription_submodules_exist`
Expected: PASS

**Step 5: Commit**

```bash
git add crates/preconfirmation-driver/src/subscription/mod.rs \
  crates/preconfirmation-driver/src/subscription/event_handler.rs \
  crates/preconfirmation-driver/src/subscription/submission.rs

git commit -m "chore(preconfirmation-driver): split subscription module"
```

### Task 4: Split storage into store + awaiting

**Files:**

- Create: `crates/preconfirmation-driver/src/storage/store.rs`
- Create: `crates/preconfirmation-driver/src/storage/awaiting.rs`
- Modify: `crates/preconfirmation-driver/src/storage/mod.rs`

**Step 1: Write the failing test**

Add a test in `crates/preconfirmation-driver/src/storage/mod.rs` that references
`awaiting::awaiting_module_marker` before the module exists.

```rust
#[cfg(test)]
mod tests {
    use super::awaiting::awaiting_module_marker;

    #[test]
    fn awaiting_buffer_module_exists() {
        let _ = awaiting_module_marker;
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-driver storage::tests::awaiting_buffer_module_exists`
Expected: FAIL with module missing errors.

**Step 3: Write minimal implementation**

- Move `CommitmentsAwaitingTxList` and its impls into `awaiting.rs` and add:

```rust
#[cfg(test)]
pub(crate) const awaiting_module_marker: () = ();
```

- Move `CommitmentStore` and `InMemoryCommitmentStore` into `store.rs`.
- Keep `mod.rs` as the re-export surface: `mod awaiting; mod store; pub use store::*;` and
  `pub(crate) use awaiting::CommitmentsAwaitingTxList;`.

**Step 4: Run test to verify it passes**

Run: `cargo test -p preconfirmation-driver storage::tests::awaiting_buffer_module_exists`
Expected: PASS

**Step 5: Commit**

```bash
git add crates/preconfirmation-driver/src/storage/mod.rs \
  crates/preconfirmation-driver/src/storage/store.rs \
  crates/preconfirmation-driver/src/storage/awaiting.rs

git commit -m "chore(preconfirmation-driver): split storage module"
```

### Task 5: Split sync into catchup + txlist_fetch

**Files:**

- Create: `crates/preconfirmation-driver/src/sync/catchup.rs`
- Create: `crates/preconfirmation-driver/src/sync/txlist_fetch.rs`
- Modify: `crates/preconfirmation-driver/src/sync/mod.rs`

**Step 1: Write the failing test**

Add a test in `crates/preconfirmation-driver/src/sync/mod.rs` that references
`catchup::catchup_module_marker` and a marker in `txlist_fetch.rs`.

```rust
#[cfg(test)]
mod tests {
    use super::catchup::catchup_module_marker;
    use super::txlist_fetch::txlist_fetch_module_marker;

    #[test]
    fn sync_submodules_exist() {
        let _ = catchup_module_marker;
        let _ = txlist_fetch_module_marker;
    }
}
```

In `txlist_fetch.rs`, plan to add:

```rust
#[cfg(test)]
pub(crate) const txlist_fetch_module_marker: () = ();
```

In `catchup.rs`, plan to add:

```rust
#[cfg(test)]
pub(crate) const catchup_module_marker: () = ();
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-driver sync::tests::sync_submodules_exist`
Expected: FAIL with module missing errors.

**Step 3: Write minimal implementation**

- Move `TipCatchup` and chain-building logic into `catchup.rs`.
- Move txlist concurrency/fetch helpers into `txlist_fetch.rs`.
- Update `mod.rs` to `mod catchup; mod txlist_fetch; pub use catchup::TipCatchup;`.

**Step 4: Run test to verify it passes**

Run: `cargo test -p preconfirmation-driver sync::tests::sync_submodules_exist`
Expected: PASS

**Step 5: Commit**

```bash
git add crates/preconfirmation-driver/src/sync/mod.rs \
  crates/preconfirmation-driver/src/sync/catchup.rs \
  crates/preconfirmation-driver/src/sync/txlist_fetch.rs

git commit -m "chore(preconfirmation-driver): split sync module"
```

### Task 6: Update README module tree

**Files:**

- Modify: `crates/preconfirmation-driver/README.md`

**Step 1: Write the failing test**

Add a doc test snippet that references `runner::DriverSync` (if it is not exposed, use
`runner` module listing in README and add a short note) or a simple rustdoc code fence
and run `cargo test --doc` to fail until the README is updated.

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-driver --doc`
Expected: FAIL due to missing/incorrect module tree in README.

**Step 3: Write minimal implementation**

Update the "Module Structure" block in `crates/preconfirmation-driver/README.md` to
reflect the new `runner/`, `rpc/node_api.rs`, `subscription/`, `storage/`, and `sync/`
submodules.

**Step 4: Run test to verify it passes**

Run: `cargo test -p preconfirmation-driver --doc`
Expected: PASS

**Step 5: Commit**

```bash
git add crates/preconfirmation-driver/README.md

git commit -m "docs(preconfirmation-driver): update module layout"
```

### Task 7: Full formatting, lint, and integration test pass

**Files:**

- Modify: (format/lint changes across `crates/preconfirmation-driver/`)

**Step 1: Write the failing test**

No new tests; skip.

**Step 2: Run test to verify it fails**

No-op.

**Step 3: Write minimal implementation**

Run:

```bash
just fmt
just clippy-fix
PROTOCOL_DIR=/Users/davidcai/Workspace/taiko-mono-shasta/packages/protocol just test
```

**Step 4: Run tests to verify they pass**

Expected: all formatting, clippy, and integration tests pass.

**Step 5: Commit**

```bash
git add -A

git commit -m "chore(preconfirmation-driver): refactor module layout"
```
