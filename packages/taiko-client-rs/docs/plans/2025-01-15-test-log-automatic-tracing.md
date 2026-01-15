# Use test-log for Automatic Test Tracing

## Problem

Many test files manually call `init_tracing("info");` as the first line. This is:

- Repetitive boilerplate
- Easy to forget
- Inconsistent (some tests have it, some don't)

## Solution

Use the `test-log` crate to automatically enable tracing for all tests. This is the Rust community best practice.

## Changes

### Before

```rust
use test_harness::init_tracing;

#[tokio::test]
async fn my_test() {
    init_tracing("info");
    // test code
}
```

### After

```rust
#[test_log::test(tokio::test)]
async fn my_test() {
    // test code - tracing automatically enabled
}
```

## Implementation Steps

### 1. Add `test-log` to workspace dependencies

File: `Cargo.toml` (workspace root)

```toml
[workspace.dependencies]
test-log = { version = "0.2", features = ["trace"] }
```

### 2. Add to crate dev-dependencies

Files to modify:

- `crates/driver/Cargo.toml`
- `crates/preconfirmation-client/Cargo.toml`
- `crates/proposer/Cargo.toml`
- `crates/test-harness/Cargo.toml`

Add:

```toml
[dev-dependencies]
test-log = { workspace = true }
```

### 3. Update test files

For each test file:

1. Replace `#[tokio::test]` with `#[test_log::test(tokio::test)]`
2. Replace `#[tokio::test(flavor = "multi_thread")]` with `#[test_log::test(tokio::test(flavor = "multi_thread"))]`
3. Remove `init_tracing("info");` calls
4. Remove `use test_harness::init_tracing;` imports

Files to update:

- `crates/driver/tests/driver_rpc_server.rs`
- `crates/driver/tests/dual_driver_e2e.rs`
- `crates/driver/tests/preconf_e2e.rs`
- `crates/driver/tests/proposer_driver_e2e.rs`
- `crates/driver/tests/shasta_event_sync.rs`
- `crates/preconfirmation-client/tests/catchup_e2e.rs`
- `crates/preconfirmation-client/tests/contiguous_multi_block.rs`
- `crates/preconfirmation-client/tests/dual_driver_e2e.rs`
- `crates/preconfirmation-client/tests/head_gossip_e2e.rs`
- `crates/preconfirmation-client/tests/out_of_order_arrival.rs`
- `crates/preconfirmation-client/tests/p2p_integration.rs`
- `crates/proposer/tests/shasta_propose.rs`
- `crates/test-harness/tests/dual_l2_env.rs`

### 4. Keep `init_tracing` function

The `init_tracing` function in `test-harness/src/lib.rs` should be kept because:

- `ShastaEnv::load_from_env()` still calls it
- Maintains backward compatibility

## Benefits

1. Zero boilerplate - no manual `init_tracing` calls needed
2. Consistent tracing across all tests
3. Community best practice
4. Tracing level controlled via `RUST_LOG` environment variable
