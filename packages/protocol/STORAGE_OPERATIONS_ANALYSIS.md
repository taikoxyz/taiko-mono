# Storage Operations Analysis: Inbox Optimization

## Overview

This document analyzes the SSTORE and SLOAD operations in the `propose` and `prove` functions for both InboxBase and InboxWithSlotOptimization implementations.

## Storage Operation Counts

### InboxBase Implementation

#### `propose` Function

Per proposal created:

- **SSTOREs**: 2
  1. Store proposal hash: `proposalRingBuffer[slot].proposalHash = hash`
  2. Update core state: `coreStateHash = newHash`
- **SLOADs**: 0-1
  - 0 if not finalizing
  - 1 if finalizing (reading claim record for validation)

#### `prove` Function

Per claim proved:

- **SSTOREs**: 1
  - Store claim record: `proposalRingBuffer[slot].claimHashLookup[parentClaimHash] = claimRecordHash`
- **SLOADs**: 1
  - Read proposal hash for validation: `proposalRingBuffer[slot].proposalHash`

### InboxWithSlotOptimization Implementation

#### `propose` Function

Same as InboxBase (optimization doesn't affect propose):

- **SSTOREs**: 2
- **SLOADs**: 0-1

#### `prove` Function

Per claim proved:

**For first/only claim (common case):**

- **SSTOREs**: 1
  - Store to default slot: `proposalRingBuffer[slot].claimHashLookup[_DEFAULT_SLOT_HASH] = claimRecordHash`
- **SLOADs**: 2
  1. Read proposal hash for validation
  2. Check if default slot is empty

**For subsequent claims (less common):**

- **SSTOREs**: 1
  - Store to regular mapping: `proposalRingBuffer[slot].claimHashLookup[parentClaimHash] = claimRecordHash`
- **SLOADs**: 2
  1. Read proposal hash for validation
  2. Check default slot (finds it's not empty)

## Gas Cost Analysis

### Storage Operation Gas Costs (EIP-2929)

- **SSTORE** (cold slot, zero → non-zero): 20,000 gas
- **SSTORE** (warm slot, non-zero → non-zero): 2,900 gas
- **SLOAD** (cold slot): 2,100 gas
- **SLOAD** (warm slot): 100 gas

### Optimization Benefits

#### Scenario: Single Claim Per Proposal (Most Common)

**InboxBase:**

- SSTORE to `keccak256(parentClaimHash . keccak256(1 . baseSlot))`
- Cost: 20,000 gas (cold) or 2,900-20,000 gas (depends on parent hash collision)

**InboxOptimized:**

- SSTORE to `keccak256(bytes32(1) . keccak256(1 . baseSlot))`
- Cost: 2,900 gas (warm after first use in this ring buffer position)
- Extra SLOAD: +100 gas

**Net Savings:** Up to 17,000 gas per claim when ring buffer wraps around

### Storage Slot Calculation

#### InboxBase Storage Location

```solidity
// For claim record storage:
slot = keccak256(parentClaimHash . keccak256(1 . proposalRingBuffer[proposalId % ringBufferSize]))
```

- Different parent claim hashes → different storage slots
- Each new parent claim hash likely hits a cold slot (20,000 gas)

#### InboxOptimized Storage Location

```solidity
// For first/only claim:
slot = keccak256(bytes32(1) . keccak256(1 . proposalRingBuffer[proposalId % ringBufferSize]))
```

- Always same slot for each ring buffer position
- After warmup, always hits a warm slot (2,900 gas)

## Trade-offs

### Benefits

1. **Consistent warm storage**: Default slot stays warm, reducing SSTORE cost from 20,000 to 2,900 gas
2. **Predictable gas costs**: Same slot used regardless of parent claim hash
3. **Optimal for common case**: Most proposals have only one claim

### Costs

1. **Extra SLOAD**: One additional read operation (+100 gas when warm)
2. **Slightly higher cost for multiple claims**: Extra SLOAD without benefit
3. **Complexity**: Code is slightly more complex with conditional logic

## Conclusion

The optimization provides significant gas savings (up to 17,000 gas) for the common case of single-claim proposals by ensuring writes always go to warm storage slots. The trade-off of an extra SLOAD (100 gas) is minimal compared to the savings from avoiding cold storage writes.

### When Optimization is Most Effective

- Ring buffer has cycled at least once (all slots warm)
- Proposals typically have single claims
- Different proposals have different parent claim hashes (typical in sequential proving)

### Break-even Analysis

- Savings: ~17,000 gas per single-claim proposal
- Cost: ~100 gas extra SLOAD
- **Break-even**: Optimization pays off immediately for single-claim proposals after ring buffer warmup
