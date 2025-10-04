# Field Coverage Analysis for Shasta Protocol Libraries

**Analysis Date:** 2025-10-04
**Scope:** All encoding, decoding, and hashing functions in `packages/protocol/contracts/layer1/shasta/libs/`

## Executive Summary

This analysis reviews all struct field coverage across encoding, decoding, and hashing libraries to ensure data integrity.

**Status:** 🚨 **CRITICAL BUG FOUND**

### Issues Found:
1. ✅ **FIXED**: `LibProposedEventEncoder` missing `lastCheckpointTimestamp` (PR #20364)
2. 🚨 **NEW**: `LibProposeInputDecoder` missing `lastCheckpointTimestamp` in CoreState encoding/decoding

---

## Detailed Analysis

### CoreState Struct (6 fields)

```solidity
struct CoreState {
    uint48 nextProposalId;
    uint48 lastProposalBlockId;
    uint48 lastFinalizedProposalId;
    uint48 lastCheckpointTimestamp;      // ← Added in PR #20315
    bytes32 lastFinalizedTransitionHash;
    bytes32 bondInstructionsHash;
}
```

#### Coverage Matrix:

| Library | nextProposalId | lastProposalBlockId | lastFinalizedProposalId | lastCheckpointTimestamp | lastFinalizedTransitionHash | bondInstructionsHash | Status |
|---------|----------------|---------------------|-------------------------|-------------------------|----------------------------|---------------------|--------|
| **LibHashOptimized** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ COMPLETE |
| **LibHashSimple** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ COMPLETE (uses `abi.encode`) |
| **LibProposedEventEncoder** | ✅ | ✅ | ✅ | ✅ (FIXED) | ✅ | ✅ | ✅ FIXED (PR #20364) |
| **LibProposeInputDecoder** | ✅ | ✅ | ✅ | ❌ **MISSING** | ✅ | ✅ | 🚨 **INCOMPLETE** |

---

### Proposal Struct (6 fields)

```solidity
struct Proposal {
    uint48 id;
    uint48 timestamp;
    uint48 endOfSubmissionWindowTimestamp;
    address proposer;
    bytes32 coreStateHash;
    bytes32 derivationHash;
}
```

#### Coverage Matrix:

| Library | All Fields | Status |
|---------|-----------|--------|
| **LibHashOptimized** | ✅ | ✅ COMPLETE |
| **LibHashSimple** | ✅ | ✅ COMPLETE |
| **LibProposedEventEncoder** | ✅ | ✅ COMPLETE |
| **LibProposeInputDecoder** | ✅ | ✅ COMPLETE |
| **LibProveInputDecoder** | ✅ | ✅ COMPLETE |

---

### Transition Struct (3 fields)

```solidity
struct Transition {
    bytes32 proposalHash;
    bytes32 parentTransitionHash;
    ICheckpointStore.Checkpoint checkpoint;
}
```

#### Coverage Matrix:

| Library | All Fields | Status |
|---------|-----------|--------|
| **LibHashOptimized** | ✅ | ✅ COMPLETE |
| **LibHashSimple** | ✅ | ✅ COMPLETE |
| **LibProvedEventEncoder** | ✅ | ✅ COMPLETE |
| **LibProveInputDecoder** | ✅ | ✅ COMPLETE |

---

### TransitionRecord Struct (4 fields)

```solidity
struct TransitionRecord {
    uint8 span;
    LibBonds.BondInstruction[] bondInstructions;
    bytes32 transitionHash;
    bytes32 checkpointHash;
}
```

#### Coverage Matrix:

| Library | All Fields | Status |
|---------|-----------|--------|
| **LibHashOptimized** | ✅ | ✅ COMPLETE |
| **LibHashSimple** | ✅ | ✅ COMPLETE |
| **LibProvedEventEncoder** | ✅ | ✅ COMPLETE |
| **LibProposeInputDecoder** | ✅ | ✅ COMPLETE |

---

### TransitionMetadata Struct (2 fields)

```solidity
struct TransitionMetadata {
    address designatedProver;
    address actualProver;
}
```

#### Coverage Matrix:

| Library | All Fields | Status |
|---------|-----------|--------|
| **LibHashOptimized** | ✅ | ✅ COMPLETE |
| **LibHashSimple** | ✅ | ✅ COMPLETE |
| **LibProvedEventEncoder** | ✅ | ✅ COMPLETE |
| **LibProveInputDecoder** | ✅ | ✅ COMPLETE |

---

### Derivation Struct (4 fields)

```solidity
struct Derivation {
    uint48 originBlockNumber;
    bytes32 originBlockHash;
    uint8 basefeeSharingPctg;
    DerivationSource[] sources;
}
```

#### Coverage Matrix:

| Library | All Fields | Status |
|---------|-----------|--------|
| **LibHashOptimized** | ✅ | ✅ COMPLETE |
| **LibHashSimple** | ✅ | ✅ COMPLETE |
| **LibProposedEventEncoder** | ✅ | ✅ COMPLETE |

---

### Checkpoint Struct (3 fields)

```solidity
struct Checkpoint {
    uint48 blockNumber;
    bytes32 blockHash;
    bytes32 stateRoot;
}
```

#### Coverage Matrix:

| Library | All Fields | Status |
|---------|-----------|--------|
| **LibHashOptimized** | ✅ | ✅ COMPLETE |
| **LibHashSimple** | ✅ | ✅ COMPLETE |
| **LibProvedEventEncoder** | ✅ | ✅ COMPLETE |
| **LibProposeInputDecoder** | ✅ | ✅ COMPLETE |
| **LibProveInputDecoder** | ✅ | ✅ COMPLETE |

---

## 🚨 Critical Issue Details

### Issue: `LibProposeInputDecoder` Missing `lastCheckpointTimestamp`

**Location:** `packages/protocol/contracts/layer1/shasta/libs/LibProposeInputDecoder.sol`

**Lines Affected:**
- **encode()**: Lines 38-42 (CoreState encoding)
- **decode()**: Lines 93-97 (CoreState decoding)
- **_calculateProposeDataSize()**: Line 266 (size calculation comment)

**Impact:**
- `ProposeInput` data will have corrupted `CoreState` when encoded/decoded
- The `lastCheckpointTimestamp` field will be lost during serialization
- This affects the `propose()` function input data integrity
- Could cause checkpoint rate-limiting to fail

**Expected Fields (6):**
```solidity
// Current (5 fields) - WRONG
ptr = P.packUint48(ptr, _input.coreState.nextProposalId);
ptr = P.packUint48(ptr, _input.coreState.lastProposalBlockId);
ptr = P.packUint48(ptr, _input.coreState.lastFinalizedProposalId);
// MISSING: lastCheckpointTimestamp
ptr = P.packBytes32(ptr, _input.coreState.lastFinalizedTransitionHash);
ptr = P.packBytes32(ptr, _input.coreState.bondInstructionsHash);
```

**Should be (6 fields):**
```solidity
ptr = P.packUint48(ptr, _input.coreState.nextProposalId);
ptr = P.packUint48(ptr, _input.coreState.lastProposalBlockId);
ptr = P.packUint48(ptr, _input.coreState.lastFinalizedProposalId);
ptr = P.packUint48(ptr, _input.coreState.lastCheckpointTimestamp);  // ← ADD THIS
ptr = P.packBytes32(ptr, _input.coreState.lastFinalizedTransitionHash);
ptr = P.packBytes32(ptr, _input.coreState.bondInstructionsHash);
```

**Size Impact:**
- Current size calculation: 82 bytes for CoreState
- Correct size: 88 bytes (82 + 6 bytes for uint48)
- Buffer size needs update from 101 to 107 bytes base

---

## Recommendations

### Immediate Actions:

1. ✅ **DONE**: Fix `LibProposedEventEncoder` (PR #20364)
2. 🔥 **URGENT**: Fix `LibProposeInputDecoder` to include `lastCheckpointTimestamp`
3. 🔥 **URGENT**: Add comprehensive tests for `LibProposeInputDecoder` encoding/decoding
4. 🔥 **URGENT**: Run full integration tests to ensure no data corruption

### Future Prevention:

1. **Code Generation**: Consider generating encoders/decoders from struct definitions
2. **CI Checks**: Add automated struct field coverage validation
3. **Documentation**: Maintain a struct field checklist for all libraries
4. **Test Coverage**: Ensure every encoder has tests that verify ALL struct fields
5. **Review Process**: Add checklist item for struct modifications to update all encoders/decoders/hashers

---

## Test Coverage Recommendations

For `LibProposeInputDecoder`, add tests similar to `LibProposedEventEncoder`:

```solidity
function test_encode_decode_coreState_with_lastCheckpointTimestamp() public pure {
    // Test with non-zero lastCheckpointTimestamp
}

function test_encode_decode_coreState_maxValues() public pure {
    // Test with type(uint48).max for lastCheckpointTimestamp
}

function testFuzz_encodeDecodeCoreState(uint48 _lastCheckpointTimestamp, ...) public pure {
    // Fuzz test including lastCheckpointTimestamp
}
```

---

## References

- PR #20315: Added `minCheckpointDelay` and `lastCheckpointTimestamp`
- PR #20364: Fixed `LibProposedEventEncoder` (this issue)
- Issue #20363: Original bug report for `LibProposedEventEncoder`

---

**Report Generated By:** Claude Code
**Analysis Method:** Systematic struct field enumeration and cross-library comparison
