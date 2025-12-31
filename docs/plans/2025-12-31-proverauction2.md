# ProverAuction2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement `ProverAuction2` with a bounded active prover pool and weighted selection, plus minimal tests.

**Architecture:** Keep the auction/bond model from `ProverAuction`, but store an active prover pool (bounded size). `getCurrentProver()` selects a prover deterministically per block using weights derived from fees (lower fee = higher weight). Bids add/replace provers based on fee rules; slashing and exits remove provers and set withdrawal delays.

**Tech Stack:** Solidity (0.8.26), Foundry tests, OpenZeppelin SafeERC20, EssentialContract base.

### Task 1: Add failing tests for ProverAuction2

**Files:**
- Create: `packages/protocol/test/layer1/core/ProverAuction2.t.sol`

**Step 1: Write the failing test**

Include tests for:
- Pool full replacement (new bid evicts worst)
- requestExit removes active prover
- Weighted selection determinism
- Slashing ejects below threshold

**Step 2: Run test to verify it fails**

Run: `cd packages/protocol && FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/core/ProverAuction2.t.sol'`

Expected: FAIL with missing `ProverAuction2` / `IProverAuction2` imports.

**Step 3: Commit**

Run: `git add packages/protocol/test/layer1/core/ProverAuction2.t.sol && git commit -m "test: add ProverAuction2 coverage"`

### Task 2: Add the ProverAuction2 interface

**Files:**
- Create: `packages/protocol/contracts/layer1/core/iface/IProverAuction2.sol`

**Step 1: Write minimal implementation**

Expose:
- `getActiveProvers()`
- `getProverStatus(address)`
- `getMaxActiveProvers()`

**Step 2: Run test to verify it fails**

Run: `cd packages/protocol && FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/core/ProverAuction2.t.sol'`

Expected: FAIL because `ProverAuction2` is not implemented.

**Step 3: Commit**

Run: `git add packages/protocol/contracts/layer1/core/iface/IProverAuction2.sol && git commit -m "feat: add IProverAuction2 interface"`

### Task 3: Implement ProverAuction2

**Files:**
- Create: `packages/protocol/contracts/layer1/core/impl/ProverAuction2.sol`

**Step 1: Write minimal implementation**

Key changes vs `ProverAuction`:
- Storage: `_activeProvers`, `_proverInfo`, `_poolEmptySince`, `_lastPoolFee`
- `bid`: add prover or evict worst when pool full; self-bid lowers fee
- `getCurrentProver`: weighted selection using `maxFee - fee + 1`
- `requestExit` / `slashProver`: remove prover, set withdrawableAt
- `getMaxBidFee`: vacancy-time cap when empty; worst-fee cap when non-empty
- `getActiveProvers`, `getProverStatus`, `getMaxActiveProvers`

**Step 2: Run test to verify it passes**

Run: `cd packages/protocol && FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/core/ProverAuction2.t.sol'`

Expected: PASS

**Step 3: Commit**

Run: `git add packages/protocol/contracts/layer1/core/impl/ProverAuction2.sol && git commit -m "feat: add ProverAuction2 multi-prover auction"`

### Task 4: Add storage layout generation entry

**Files:**
- Modify: `packages/protocol/script/gen-layouts.sh`
- Create: `packages/protocol/contracts/layer1/core/impl/ProverAuction2_Layout.sol` (generated)

**Step 1: Update script**

Add to `contracts_layer1` array: `"contracts/layer1/core/impl/ProverAuction2.sol:ProverAuction2"`

**Step 2: Generate layouts**

Run: `cd packages/protocol && ./script/gen-layouts.sh layer1`

**Step 3: Commit**

Run: `git add packages/protocol/script/gen-layouts.sh packages/protocol/contracts/layer1/core/impl/ProverAuction2_Layout.sol && git commit -m "chore: add ProverAuction2 storage layout"`

