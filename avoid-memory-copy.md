# Memory Deep Copy Analysis for Inbox.sol

## Overview
This document identifies all structure memory deep copies in `Inbox.sol` and provides suggestions to avoid them for gas optimization.

---

## 1. `_finalize()` - Line 883-954

### Current Deep Copies

#### a) CoreState deep copy (Line 885)
```solidity
CoreState memory coreState = _input.coreState;
```

**Location**: `Inbox.sol:885`

**Suggestion**: Use calldata reference instead
```solidity
// Change function signature to avoid copy
function _finalize(ProposeInput calldata _input) private returns (CoreState memory) {
    CoreState memory coreState;
    // Initialize only the fields that will be modified
    coreState.lastFinalizedProposalId = _input.coreState.lastFinalizedProposalId;
    coreState.nextProposalId = _input.coreState.nextProposalId;
    coreState.lastFinalizedTransitionHash = _input.coreState.lastFinalizedTransitionHash;
    coreState.bondInstructionsHash = _input.coreState.bondInstructionsHash;
    coreState.lastProposalBlockId = _input.coreState.lastProposalBlockId;
    coreState.lastCheckpointTimestamp = _input.coreState.lastCheckpointTimestamp;
    // ...
}
```

**Impact**: HIGH - CoreState contains multiple fields and is copied on every finalization

---

#### b) TransitionRecord deep copy (Line 914)
```solidity
TransitionRecord memory transitionRecord = _input.transitionRecords[i];
```

**Location**: `Inbox.sol:914`

**Suggestion**: Use storage/calldata reference to avoid copy
```solidity
// Access array element directly without copying
bytes32 recordHash = _hashTransitionRecord(_input.transitionRecords[i]);
require(recordHash == hashAndDeadline.recordHash, TransitionRecordHashMismatchWithStorage());

// Update state using direct access
coreState.lastFinalizedTransitionHash = _input.transitionRecords[i].transitionHash;

// Only copy bondInstructions array when needed
LibBonds.BondInstruction[] memory bondInstructions = _input.transitionRecords[i].bondInstructions;
for (uint256 j; j < bondInstructions.length; ++j) {
    coreState.bondInstructionsHash = LibBonds.aggregateBondInstruction(
        coreState.bondInstructionsHash, bondInstructions[j]
    );
}
```

**Impact**: HIGH - Happens in a loop, potentially multiple times per finalization

---

#### c) TransitionRecordHashAndDeadline deep copy (Line 897-900)
```solidity
TransitionRecordHashAndDeadline memory hashAndDeadline =
    _getTransitionRecordHashAndDeadline(
        proposalId, coreState.lastFinalizedTransitionHash
    );
```

**Location**: `Inbox.sol:897-900`

**Suggestion**: Decompose the struct and return individual values
```solidity
// Change function signature
function _getTransitionRecordHashAndDeadline(
    uint48 _proposalId,
    bytes32 _parentTransitionHash
)
    internal
    view
    virtual
    returns (bytes26 recordHash_, uint48 finalizationDeadline_)
{
    bytes32 compositeKey = _composeTransitionKey(_proposalId, _parentTransitionHash);
    TransitionRecordHashAndDeadline storage hashAndDeadline = _transitionRecordHashAndDeadline[compositeKey];
    return (hashAndDeadline.recordHash, hashAndDeadline.finalizationDeadline);
}

// Usage in _finalize
(bytes26 recordHash, uint48 finalizationDeadline) = _getTransitionRecordHashAndDeadline(
    proposalId, coreState.lastFinalizedTransitionHash
);

if (i >= transitionCount) {
    if (recordHash == 0) break;
    if (currentTimestamp >= finalizationDeadline) {
        revert TransitionRecordNotProvided();
    }
    break;
}
```

**Impact**: MEDIUM - Small struct (26 + 6 = 32 bytes packed), but occurs in loop

---

## 2. `_syncCheckpointIfNeeded()` - Line 961-983

### Current Deep Copy

#### Checkpoint deep copy (Line 962)
```solidity
ICheckpointStore.Checkpoint memory _checkpoint
```

**Location**: `Inbox.sol:962` (function parameter)

**Suggestion**: Change to calldata and access fields directly
```solidity
function _syncCheckpointIfNeeded(
    ICheckpointStore.Checkpoint calldata _checkpoint,  // Changed from memory
    bytes32 _expectedCheckpointHash,
    CoreState memory _coreState
)
    private
{
    if (_checkpoint.blockHash != 0) {
        bytes32 checkpointHash = _hashCheckpoint(_checkpoint);
        require(checkpointHash == _expectedCheckpointHash, CheckpointMismatch());

        _checkpointStore.saveCheckpoint(_checkpoint);  // May need to adjust if saveCheckpoint expects memory
        _coreState.lastCheckpointTimestamp = uint48(block.timestamp);
    } else {
        require(
            block.timestamp < _coreState.lastCheckpointTimestamp + _minCheckpointDelay,
            CheckpointNotProvided()
        );
    }
}
```

**Impact**: LOW-MEDIUM - Depends on Checkpoint struct size, only called when finalization succeeds

---

## 3. `propose()` - Line 201-260

### Current Deep Copies

#### a) ProposeInput deep copy (Line 204)
```solidity
ProposeInput memory input = _decodeProposeInput(_data);
```

**Location**: `Inbox.sol:204`

**Suggestion**: Decode to calldata or avoid intermediate copy
```solidity
// Option 1: Change decoder to return calldata reference (not possible with abi.decode)
// Option 2: Use inline access pattern
function propose(bytes calldata _lookahead, bytes calldata _data) external nonReentrant {
    unchecked {
        ProposeInput calldata input = abi.decode(_data, (ProposeInput));  // Won't work - abi.decode returns memory

        // Alternative: Manually decode key fields without full struct copy
        // This requires custom decoding logic
    }
}
```

**Note**: Due to ABI decoding limitations, this is difficult to optimize without custom decoding. Consider keeping as-is unless profiling shows significant impact.

**Impact**: HIGH - Large struct containing arrays, happens on every propose call

---

#### b) CoreState deep copy (Line 212)
```solidity
CoreState memory coreState = _finalize(input);
```

**Location**: `Inbox.sol:212`

**Suggestion**: Already returned from `_finalize`, but could be optimized by having `_finalize` work in-place on input.coreState

```solidity
// Inside _finalize, instead of copying:
function _finalize(ProposeInput memory _input) private returns (CoreState memory) {
    // Modify _input.coreState directly
    // ...
    return _input.coreState;  // Return reference to already-modified struct
}
```

**Impact**: MEDIUM - CoreState copy returned from _finalize

---

#### c) ConsumptionResult deep copy (Line 222-223)
```solidity
ConsumptionResult memory result =
    _consumeForcedInclusions(msg.sender, input.numForcedInclusions);
```

**Location**: `Inbox.sol:222-223`

**Suggestion**: Return directly in place or use return values
```solidity
// Option 1: Return tuple instead of struct
function _consumeForcedInclusions(
    address _feeRecipient,
    uint256 _numForcedInclusionsRequested
)
    private
    returns (IInbox.DerivationSource[] memory sources_, bool allowsPermissionless_)
{
    // ... implementation
    return (sources_, allowsPermissionless_);
}

// Usage:
(IInbox.DerivationSource[] memory sources, bool allowsPermissionless) =
    _consumeForcedInclusions(msg.sender, input.numForcedInclusions);
```

**Impact**: MEDIUM - Contains a dynamic array, happens on every propose call

---

#### d) Derivation deep copy (Line 240-245)
```solidity
Derivation memory derivation = Derivation({
    originBlockNumber: uint48(parentBlockNumber),
    originBlockHash: blockhash(parentBlockNumber),
    basefeeSharingPctg: _basefeeSharingPctg,
    sources: result.sources
});
```

**Location**: `Inbox.sol:240-245`

**Suggestion**: Build inline in event emission or avoid intermediate storage
```solidity
// Build and hash in one step
bytes32 derivationHash = _hashDerivation(Derivation({
    originBlockNumber: uint48(parentBlockNumber),
    originBlockHash: blockhash(parentBlockNumber),
    basefeeSharingPctg: _basefeeSharingPctg,
    sources: result.sources
}));

// Then construct Proposal using the hash
Proposal memory proposal = Proposal({
    id: coreState.nextProposalId++,
    timestamp: uint48(block.timestamp),
    endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
    proposer: msg.sender,
    coreStateHash: _hashCoreState(coreState),
    derivationHash: derivationHash
});

// For event emission, reconstruct if needed, or pass components directly
```

**Impact**: MEDIUM - Contains sources array which can be large

---

#### e) Proposal deep copy (Line 248-255)
```solidity
Proposal memory proposal = Proposal({
    id: coreState.nextProposalId++,
    timestamp: uint48(block.timestamp),
    endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
    proposer: msg.sender,
    coreStateHash: _hashCoreState(coreState),
    derivationHash: _hashDerivation(derivation)
});
```

**Location**: `Inbox.sol:248-255`

**Suggestion**: This is a struct initialization, not a copy. No optimization needed, but avoid passing it around unnecessarily.

**Impact**: LOW - Struct initialization is necessary

---

## 4. `prove()` - Line 268-289

### Current Deep Copy

#### ProveInput deep copy (Line 270)
```solidity
ProveInput memory input = _decodeProveInput(_data);
```

**Location**: `Inbox.sol:270`

**Suggestion**: Same as ProposeInput - limited optimization due to ABI decoding
```solidity
// Consider custom decoding if profiling shows this is a bottleneck
// ABI decode always returns memory, so this is hard to avoid
```

**Impact**: HIGH - Contains multiple arrays (proposals, transitions, metadata)

---

## 5. `_buildTransitionRecord()` - Line 546-561

### Current Deep Copy Issues

The function receives memory parameters and creates a new TransitionRecord. While not a "deep copy" per se, it does involve memory allocation.

**Location**: `Inbox.sol:546-561`

**Suggestion**: Build record inline where needed, or accept storage/calldata references
```solidity
function _buildTransitionRecord(
    Proposal calldata _proposal,  // Change to calldata
    Transition calldata _transition,  // Change to calldata
    TransitionMetadata calldata _metadata  // Change to calldata
)
    internal
    view
    returns (TransitionRecord memory record)
{
    record.span = 1;
    record.bondInstructions = LibBondInstruction.calculateBondInstructions(
        _provingWindow, _extendedProvingWindow, _proposal, _metadata
    );
    record.transitionHash = _hashTransition(_transition);
    record.checkpointHash = _hashCheckpoint(_transition.checkpoint);
}
```

**Impact**: MEDIUM - Called for each transition being proven

---

## 6. `_setTransitionRecordHashAndDeadline()` - Line 437-460

### Current Deep Copy

#### TransitionRecordHashAndDeadline struct creation (Line 446-447)
```solidity
(bytes26 transitionRecordHash, TransitionRecordHashAndDeadline memory hashAndDeadline) =
    _computeTransitionRecordHashAndDeadline(_transitionRecord);
```

**Location**: `Inbox.sol:446-447`

**Suggestion**: Return values separately instead of in a struct
```solidity
function _computeTransitionRecordHashAndDeadline(TransitionRecord memory _transitionRecord)
    internal
    view
    returns (bytes26 recordHash_, uint48 finalizationDeadline_)
{
    unchecked {
        recordHash_ = _hashTransitionRecord(_transitionRecord);
        finalizationDeadline_ = uint48(block.timestamp + _finalizationGracePeriod);
    }
}

// Usage:
(bytes26 transitionRecordHash, uint48 finalizationDeadline) =
    _computeTransitionRecordHashAndDeadline(_transitionRecord);

_storeTransitionRecord(
    _proposalId, _transition.parentTransitionHash, transitionRecordHash, finalizationDeadline
);
```

**Impact**: LOW - Small struct, but happens for each proof

---

## 7. `_emitProposedEvent()` - Line 864-875

### Current Deep Copy

#### ProposedEventPayload creation (Line 871-873)
```solidity
ProposedEventPayload memory payload = ProposedEventPayload({
    proposal: _proposal, derivation: _derivation, coreState: _coreState
});
```

**Location**: `Inbox.sol:871-873`

**Suggestion**: Encode directly without intermediate struct
```solidity
function _emitProposedEvent(
    Proposal memory _proposal,
    Derivation memory _derivation,
    CoreState memory _coreState
)
    private
{
    emit Proposed(abi.encode(_proposal, _derivation, _coreState));
}
```

**Impact**: MEDIUM - Three large structs copied into payload, happens on every propose

---

## 8. `_storeTransitionRecord()` - Line 469-493

### Current Deep Copy

#### TransitionRecordHashAndDeadline parameter (Line 473)
```solidity
TransitionRecordHashAndDeadline memory _hashAndDeadline
```

**Location**: `Inbox.sol:473`

**Suggestion**: Pass individual fields instead
```solidity
function _storeTransitionRecord(
    uint48 _proposalId,
    bytes32 _parentTransitionHash,
    bytes26 _recordHash,
    uint48 _finalizationDeadline  // Separate parameter instead of struct
)
    internal
    virtual
{
    bytes32 compositeKey = _composeTransitionKey(_proposalId, _parentTransitionHash);
    TransitionRecordHashAndDeadline storage entry =
        _transitionRecordHashAndDeadline[compositeKey];
    bytes26 recordHash = entry.recordHash;

    if (recordHash == 0) {
        entry.recordHash = _recordHash;
        entry.finalizationDeadline = _finalizationDeadline;
    } else if (recordHash == _recordHash) {
        emit TransitionDuplicateDetected();
    } else {
        emit TransitionConflictDetected();
        conflictingTransitionDetected = true;
        entry.finalizationDeadline = type(uint48).max;
    }
}
```

**Impact**: LOW - Small struct, but passed as parameter unnecessarily

---

## Summary of Recommendations by Priority

### HIGH PRIORITY (Significant gas savings)
1. **Line 885**: CoreState copy in `_finalize()` - Optimize by modifying in place
2. **Line 914**: TransitionRecord copy in loop in `_finalize()` - Use direct array access
3. **Line 204**: ProposeInput deep copy - Consider custom decoding
4. **Line 270**: ProveInput deep copy - Consider custom decoding

### MEDIUM PRIORITY (Moderate gas savings)
5. **Line 222**: ConsumptionResult copy - Return tuple instead of struct
6. **Line 240**: Derivation copy - Build inline or avoid intermediate storage
7. **Line 897**: TransitionRecordHashAndDeadline copy in loop - Return separate values
8. **Line 871**: ProposedEventPayload copy - Encode directly

### LOW PRIORITY (Minor gas savings)
9. **Line 962**: Checkpoint parameter - Change to calldata
10. **Line 446**: TransitionRecordHashAndDeadline creation - Return separate values
11. **Line 473**: TransitionRecordHashAndDeadline parameter - Pass individual fields
12. **Line 546**: Function parameters - Change to calldata

---

## General Optimization Patterns

### Pattern 1: Calldata References
When possible, use `calldata` instead of `memory` for function parameters that are not modified.

### Pattern 2: Return Multiple Values
Instead of returning structs, return multiple values using tuples to avoid struct copy overhead.

### Pattern 3: Direct Array Access
Access array elements directly without copying to local variables when only a few fields are needed.

### Pattern 4: In-Place Modification
Modify structs in place rather than copying, modifying, and returning.

### Pattern 5: Struct Decomposition
Break apart small structs into individual variables when they're only used for a few operations.

---

## Testing Recommendations

After implementing optimizations:
1. Run gas profiling to measure actual savings
2. Ensure all tests pass with no behavioral changes
3. Profile both single-proposal and batch operations
4. Test edge cases (max finalization count, max forced inclusions, etc.)
