# Catch-up Boundary Error Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fail tip catch-up when the chain does not reach the required driver sync boundary, instead of silently returning an empty result.

**Architecture:** Add a small boundary validation helper in `tip_catchup.rs` and use it in `backfill_from_peer_head` to return a `PreconfirmationClientError::Catchup` error. Add a focused unit test for the boundary mismatch case.

**Tech Stack:** Rust, Tokio tests, `preconfirmation-client` crate.

### Task 1: Add failing unit test for boundary mismatch

**Files:**

- Modify: `crates/preconfirmation-client/src/sync/tip_catchup.rs`
- Test: `crates/preconfirmation-client/src/sync/tip_catchup.rs`

**Step 1: Write the failing test**

```rust
#[test]
fn catchup_boundary_mismatch_returns_error() {
    let stop_block = U256::from(10u64);
    let boundary_block = Some(U256::from(9u64));

    let err = ensure_catchup_boundary(true, stop_block, boundary_block)
        .expect_err("must error");
    assert!(err.to_string().contains("catch-up chain did not reach"));
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p preconfirmation-client catchup_boundary_mismatch_returns_error`

Expected: FAIL with `must error`.

### Task 2: Implement boundary validation and wire it into backfill

**Files:**

- Modify: `crates/preconfirmation-client/src/sync/tip_catchup.rs`

**Step 1: Write minimal implementation**

```rust
fn ensure_catchup_boundary(
    require_boundary: bool,
    stop_block: U256,
    boundary_block: Option<U256>,
) -> Result<()> {
    if !require_boundary || boundary_block == Some(stop_block) {
        return Ok(());
    }

    Err(PreconfirmationClientError::Catchup(format!(
        "catch-up chain did not reach the driver sync boundary: expected {stop_block}, got {boundary_block:?}"
    )))
}
```

**Step 2: Replace the silent return in `backfill_from_peer_head`**

```rust
if let Err(err) = ensure_catchup_boundary(require_boundary, stop_block, boundary_block) {
    warn!(
        stop_block = %stop_block,
        boundary_block = ?boundary_block,
        "catch-up chain did not reach the driver sync boundary"
    );
    return Err(err);
}
```

**Step 3: Run test to verify it passes**

Run: `cargo test -p preconfirmation-client catchup_boundary_mismatch_returns_error`

Expected: PASS.

**Step 4: Commit**

```bash
git add crates/preconfirmation-client/src/sync/tip_catchup.rs
git commit -m "fix: error on missing catch-up boundary"
```
