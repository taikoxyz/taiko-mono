# Engine Mode Gas Limit Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix engine-mode proposals to correctly subtract anchor gas from manifest gas_limit, matching driver validation expectations.

**Architecture:** When `use_engine_mode` is enabled, the proposer takes `gas_limit` from the parent L2 block header and passes it to the transaction builder. The driver validation expects manifest gas limits to exclude `ANCHOR_V3_V4_GAS_LIMIT`. The fix subtracts anchor gas in `proposer.rs` when creating `EnginePayloadParams`, with a genesis block check (block 0 doesn't subtract).

**Tech Stack:** Rust, alethia-reth-consensus

---

## Task 1: Add ANCHOR_V3_V4_GAS_LIMIT Import

**Files:**

- Modify: `crates/proposer/src/proposer.rs:23-27`

**Step 1: Add the constant import**

Add `ANCHOR_V3_V4_GAS_LIMIT` to the existing `alethia_reth_consensus` import or add a new import line.

Current imports (lines 3-5):

```rust
use alethia_reth_consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
```

Change to:

```rust
use alethia_reth_consensus::{
    eip4396::{SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee},
    validation::ANCHOR_V3_V4_GAS_LIMIT,
};
```

**Step 2: Verify the code compiles**

Run: `cargo check -p proposer`
Expected: Compilation succeeds with no errors

**Step 3: Commit**

```bash
git add crates/proposer/src/proposer.rs
git commit -m "refactor(proposer): import ANCHOR_V3_V4_GAS_LIMIT constant"
```

---

## Task 2: Add effective_gas_limit Helper Function

**Files:**

- Modify: `crates/proposer/src/proposer.rs`

**Step 1: Add the helper function**

Add this function after the `EnginePayloadParams` struct (after line 56):

```rust
/// Compute the effective gas limit for the manifest by removing the anchor transaction gas.
/// Genesis block (parent_block_number == 0) uses the full gas limit since there's no anchor.
fn effective_gas_limit(parent_block_number: u64, parent_gas_limit: u64) -> u64 {
    if parent_block_number == 0 {
        parent_gas_limit
    } else {
        parent_gas_limit.saturating_sub(ANCHOR_V3_V4_GAS_LIMIT)
    }
}
```

**Step 2: Verify the code compiles**

Run: `cargo check -p proposer`
Expected: Compilation succeeds (warning about unused function is OK)

**Step 3: Commit**

```bash
git add crates/proposer/src/proposer.rs
git commit -m "feat(proposer): add effective_gas_limit helper for manifest gas calculation"
```

---

## Task 3: Use effective_gas_limit in build_payload_attributes

**Files:**

- Modify: `crates/proposer/src/proposer.rs:366-370`

**Step 1: Update EnginePayloadParams creation**

Current code (lines 366-370):

```rust
        let engine_params = EnginePayloadParams {
            anchor_block_number,
            timestamp,
            gas_limit: parent.header.gas_limit,
        };
```

Change to:

```rust
        let engine_params = EnginePayloadParams {
            anchor_block_number,
            timestamp,
            gas_limit: effective_gas_limit(parent.header.number, parent.header.gas_limit),
        };
```

**Step 2: Verify the code compiles**

Run: `cargo check -p proposer`
Expected: Compilation succeeds with no errors or warnings

**Step 3: Commit**

```bash
git add crates/proposer/src/proposer.rs
git commit -m "fix(proposer): subtract anchor gas from engine-mode manifest gas_limit

When use_engine_mode is enabled, the manifest gas_limit now correctly
excludes ANCHOR_V3_V4_GAS_LIMIT to match driver validation expectations.
Genesis blocks (parent number 0) use the full gas limit."
```

---

## Task 4: Add Unit Test for effective_gas_limit

**Files:**

- Modify: `crates/proposer/src/proposer.rs` (add test module at end of file)

**Step 1: Add test module**

Add at the end of `proposer.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_effective_gas_limit_genesis() {
        // Genesis block should not subtract anchor gas
        let gas_limit = effective_gas_limit(0, 30_000_000);
        assert_eq!(gas_limit, 30_000_000);
    }

    #[test]
    fn test_effective_gas_limit_non_genesis() {
        // Non-genesis blocks should subtract anchor gas
        let gas_limit = effective_gas_limit(1, 30_000_000);
        assert_eq!(gas_limit, 30_000_000 - ANCHOR_V3_V4_GAS_LIMIT);
    }

    #[test]
    fn test_effective_gas_limit_saturating() {
        // Should not underflow if gas_limit is less than anchor gas
        let gas_limit = effective_gas_limit(1, 100);
        assert_eq!(gas_limit, 0);
    }
}
```

**Step 2: Run the tests**

Run: `cargo test -p proposer effective_gas_limit`
Expected: All 3 tests pass

**Step 3: Commit**

```bash
git add crates/proposer/src/proposer.rs
git commit -m "test(proposer): add unit tests for effective_gas_limit"
```

---

## Task 5: Run Full Test Suite

**Files:** None (verification only)

**Step 1: Run all proposer tests**

Run: `cargo test -p proposer`
Expected: All tests pass

**Step 2: Run the integration tests**

Run: `cargo test -p proposer --test shasta_propose`
Expected: Both `propose_shasta_batches` and `propose_shasta_batches_engine_mode` pass

---

## Summary

After completing these tasks:

1. Engine-mode proposals will have `manifest.gas_limit = parent.gas_limit - ANCHOR_V3_V4_GAS_LIMIT`
2. Genesis block edge case is handled (no subtraction)
3. Unit tests verify the helper function behavior
4. Existing integration tests verify the full flow still works
