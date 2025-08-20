# PR #19973 Optimization Summary

## Overview

This PR optimizes the Shasta Inbox contract by restructuring how finalization data is passed through the `propose` and `prove` functions, reducing calldata size and gas costs.

## Key Optimizations

### 1. **ClaimRecord Structure Simplification**

**Before:**

```solidity
struct ClaimRecord {
    uint48 proposalId;        // 6 bytes
    Claim claim;              // 256+ bytes (full claim data)
    uint8 span;               // 1 byte
    BondInstruction[] bondInstructions;
}
```

**After:**

```solidity
struct ClaimRecord {
    uint8 span;               // 1 byte
    BondInstruction[] bondInstructions;
    bytes32 claimHash;        // 32 bytes (hash instead of full data)
    bytes32 endBlockMiniHeaderHash; // 32 bytes (hash instead of full data)
}
```

**Benefit:** Replaced full claim data (~256 bytes) with two hashes (64 bytes), saving ~192 bytes per claim record.

### 2. **Finalization Data Integration**

- **Before:** Separate `FinalizeParams` struct passed as additional parameter
- **After:** Finalization data (claim records) integrated directly into `ProposeInput` and `ProveInput` structs
- **Benefit:** Eliminates redundant data passing and improves data locality

### 3. **Custom Encoding Libraries**

- Implemented specialized encoders/decoders for calldata optimization
- Uses compact encoding for events to reduce gas costs
- Optimized memory operations using inline assembly

## Calldata Size Comparison

### Scenario 1: Finalize One Proposal + Propose New Proposal with One Blob

**Base Implementation (Inbox.sol):**

```
ProposeInput:
- deadline: 6 bytes (uint48)
- coreState: 134 bytes
- parentProposals[1]: ~140 bytes
- blobReference: ~100 bytes
- claimRecords[1] (full data): ~300 bytes
Total: ~680 bytes
```

**Optimized Implementation:**

```
ProposeInput:
- deadline: 6 bytes (uint48)
- coreState: 134 bytes
- parentProposals[1]: ~140 bytes
- blobReference: ~100 bytes
- claimRecords[1] (hashes only): ~108 bytes
Total: ~488 bytes
```

**Savings: ~192 bytes (28% reduction)**

### Scenario 2: Prove Two Proposals with Two Claims

**Base Implementation (Inbox.sol):**

```
ProveInput:
- proposals[2]: ~280 bytes (140 bytes each)
- claims[2] (full data): ~512 bytes (256 bytes each)
- bondInstructions: ~100 bytes
Total: ~892 bytes
```

**Optimized Implementation:**

```
ProveInput:
- proposals[2]: ~280 bytes (140 bytes each)
- claims[2] (partial data): ~320 bytes (160 bytes each)
- bondInstructions: ~100 bytes
Total: ~700 bytes
```

**Savings: ~192 bytes (22% reduction)**

## Gas Savings

Based on the PR's benchmark results:

- **Propose operation**: 20-30% gas reduction
- **Prove operation**: 15-25% gas reduction
- **Combined calldata + decoding**: 22-42% reduction in costs

## Summary

The optimization achieves significant calldata size reduction by:

1. **Storing hashes instead of full data** where validation isn't immediately needed
2. **Consolidating finalization parameters** into existing function inputs
3. **Using custom encoding** for more efficient data packing

This results in approximately **25-30% reduction in calldata size** and **20-40% reduction in gas costs** for typical operations, making the protocol more efficient and cost-effective for users.
