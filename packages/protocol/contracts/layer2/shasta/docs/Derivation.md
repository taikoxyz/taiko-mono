# Block Derivation in Shasta Fork

This document describes the block derivation process in Taiko's Shasta upgrade, detailing how Layer 2 blocks are derived from Layer 1 proposals.

## Overview

The Shasta block derivation process transforms Layer 1 proposals into Layer 2 blocks through a deterministic process executed by the Taiko driver. This involves subscribing to L1 events, extracting and decompressing proposal data from blobs, building blocks according to the manifest, and managing state synchronization through the Anchor contract.

## 1. Event Subscription and Proposal Structure

The Taiko driver begins by subscribing to the `Proposed` event emitted by the Layer 1 Inbox contract. This event signals that a new proposal has been submitted to the network and contains all the necessary information for block derivation.

```solidity
/// @notice Emitted when a new proposal is proposed.
/// @param proposal The proposal that was proposed.
event Proposed(Proposal proposal, CoreState coreState);
```

The Proposal struct encapsulates all metadata required for L2 block derivation. Each field serves a specific purpose in the derivation process:

```solidity
  /// @notice Represents a proposal for L2 blocks.
  struct Proposal {
      /// @notice Unique identifier for the proposal.
      uint48 id;
      /// @notice Address of the proposer. This is needed on L1 to handle provability bond
      /// and proving fee.
      address proposer;
      /// @notice Provability bond for the proposal, paid by the proposer on L1.
      uint48 provabilityBondGwei;
      /// @notice Liveness bond for the proposal, paid by the proposer on L1 and potentially
      /// also by the designated prover on L2.
      uint48 livenessBondGwei;
      /// @notice The L1 block timestamp when the proposal was made. This is needed on L2 to
      /// verify each block's timestamp in the proposal's content.
      uint48 originTimestamp;
      /// @notice The L1 block number when the proposal was made. This is needed on L2 to verify
      /// each block's anchor block number in the proposal's content.
      uint48 originBlockNumber;
      /// @notice Whether the proposal is a forced inclusion.
      bool isForcedInclusion;
      /// @notice The proposal's chunk.
      LibBlobs.BlobSlice blobSlice;
  }

```

## 2. Blob Data Extraction and Manifest Decoding

The proposal's actual content resides in blob storage, referenced through the BlobSlice structure. This design leverages Ethereum's blob storage mechanism introduced in EIP-4844, providing cost-effective data availability for Layer 2 operations.

### BlobSlice Structure

```solidity
  /// @notice Represents a frame of data that is stored in multiple blobs. Note the size is
  /// encoded as a bytes32 at the offset location.
  struct BlobSlice {
      /// @notice The blobs containing the proposal's content.
      bytes32[] blobHashes;
      /// @notice The offset of the proposal's content in the containing blobs.
      uint32 offset;
      /// @notice The timestamp when the frame was created.
      uint48 timestamp;
  }

```

### Data Extraction Process

The driver locates and processes blob data through the following steps:

1. **Blob Retrieval**: Using the timestamp field, the driver identifies and retrieves the associated blobs from the network.
2. **Data Concatenation**: Multiple blobs are concatenated into a single continuous byte array for processing.
3. **Header Parsing**: The data header contains critical metadata:
   - Bytes `[offset, offset+16)`: Version number (currently 0x1 for Shasta)
   - Bytes `[offset+16, offset+32)`: Size of the compressed data (uint128)
4. **Size Validation**: The extracted size is validated against `MAX_PROPOSAL_SLICE_BYTES`. If the size exceeds this protocol constant, the maximum value is used to prevent resource exhaustion attacks.
5. **Decompression and Decoding**: For version 0x1, the data undergoes:
   - ZLIB decompression to reduce data size
   - RLP decoding to reconstruct the structured ProposalManifest object

### Error Handling

If decompression or RLP decoding fails at any stage, the system gracefully falls back to a default manifest rather than failing the entire block derivation process. This ensures network resilience against malformed proposals.

### ProposalManifest Structure

The decoded ProposalManifest contains the complete specification for one or more L2 blocks to be derived:

```solidity
/// @notice Represents a signed Ethereum transaction
/// @dev Follows EIP-2718 typed transaction format with EIP-1559 support
struct SignedTransaction {
    uint8 txType;
    uint64 chainId;
    uint64 nonce;
    uint256 maxPriorityFeePerGas;
    uint256 maxFeePerGas;
    uint64 gasLimit;
    address to;
    uint256 value;
    bytes data;
    bytes accessList;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

/// @notice Represents a block manifest
struct BlockManifest {
    /// @notice The timestamp of the block.
    uint48 timestamp;
    /// @notice The anchor block number. This field can be zero, if so, this block will use the
    /// most recent anchor in a previous block.
    uint48 anchorBlockNumber;
    /// @notice The gas issuance per second for this block. This number can be zero to indicate
    /// that the gas issuance should be the same as the previous block.
    uint32 gasIssuancePerSecond;
    /// @notice The transactions for this block.
    SignedTransaction[] transactions;
}

/// @notice Represents a proposal manifest
struct ProposalManifest {
    BlockManifest[] blocks;
}

```

### Manifest Validation

The system enforces several constraints to ensure manifest validity:

- **Block Limit**: The number of blocks cannot exceed `MAX_BLOCKS_PER_PROPOSAL`
- **Transaction Limit**: Each block cannot contain more than `MAX_TRANSACTIONS_PER_BLOCK` transactions
- **Anchor Requirement**: At least one block must specify a non-zero `anchorBlockNumber`

When any validation check fails, the system returns a default manifest to maintain protocol continuity.

### Default Manifest Specification

The default manifest serves as a fallback mechanism, ensuring the protocol can continue operating even when invalid proposals are submitted. It contains a single empty block with the following properties:

```solidity
assert(defaultManifest.blocks.length == 1);
assert(defaultManifest.blocks[0].anchorBlockNumber == 0);
assert(defaultManifest.blocks[0].gasIssuancePerSecond == 0);
assert(defaultManifest.blocks[0].transactions.length == 0);
```

This design ensures that even malformed proposals result in valid, though empty, L2 blocks, preventing network stalls.

## 3. Anchor State Management and Block Construction

The Anchor contract serves as the synchronization point between Layer 1 and Layer 2, maintaining critical state information needed for block derivation. Each L2 block must update the Anchor state to reflect its position in the proposal sequence and maintain consistency with L1.

### Current State Retrieval

Before constructing a new block, the driver queries the Anchor contract's `getState()` function to retrieve the current synchronization state:

```solidity
/// @notice State structure containing L2 synchronization data
/// @dev Packed struct to optimize storage usage
struct State {
    /// @notice The ID of the proposal this state belongs to
    uint48 proposalId;
    /// @notice The total number of blocks in the batch
    uint16 numBlocks;
    /// @notice The index of this block within the batch
    uint16 blockIndex;
    /// @notice Gas issuance rate per second for L2 gas management
    uint32 gasIssuancePerSecond;
    /// @notice The number of the anchor block
    uint48 anchorBlockNumber;
    /// @notice The hash of the anchor block
    bytes32 anchorBlockHash;
    /// @notice The state root of the anchor block
    bytes32 anchorStateRoot;
    /// @notice The hash of the bond operations for the current proposal
    bytes32 bondOperationsHash;
}

```

### Base Fee Calculation

The driver calculates the base fee for the new block using the current state's `gasIssuancePerSecond`. This calculation occurs before the new state is applied, ensuring that gas issuance changes only affect subsequent blocks, providing predictable gas pricing.

### New State Construction

For the `i-th` block in the proposal manifest, the driver constructs a new state following these rules:

### Proposal Tracking

The proposal ID increments sequentially and must match the ID from the corresponding `Proposed` event:

```solidity
newState.proposalId = currentState.proposalId + 1;
newState.numBlocks = proposalManifest.blocks.length;
newState.blockIndex = i;

```

### Gas Issuance Rate Adjustment

The protocol enforces gradual gas issuance adjustments to prevent economic attacks. The maximum change per block is limited to 0.01% (0.0001) of the current rate:

```solidity
uint maxChange = currentState.gasIssuancePerSecond * 0.0001;
uint lowerBound = currentState.gasIssuancePerSecond - maxChange;
uint upperBound = currentState.gasIssuancePerSecond + maxChange;

BlockManifest memory block = proposalManifest.blocks[i];

if (block.gasIssuancePerSecond >= lowerBound &&
    block.gasIssuancePerSecond <= upperBound) {
    newState.gasIssuancePerSecond = block.gasIssuancePerSecond;
} else {
    newState.gasIssuancePerSecond = currentState.gasIssuancePerSecond;
}

```

This bounded adjustment mechanism ensures smooth gas price transitions while allowing the protocol to adapt to changing network conditions.

### Anchor Block Update

The anchor block represents the L1 block whose state is accessible to L2 contracts. The protocol ensures anchor blocks are recent and valid through the following logic:

```solidity
BlockManifest memory block = proposalManifest.blocks[i];

if (block.anchorBlockNumber <= currentState.anchorBlockNumber) {
    // Reuse existing anchor if proposed anchor is not newer
    newState.anchorBlockNumber = currentState.anchorBlockNumber;
    newState.anchorBlockHash = currentState.anchorBlockHash;
    newState.anchorStateRoot = currentState.anchorStateRoot;
} else {
    // Apply recency constraint: anchor must be within 256 blocks
    uint minAnchorBlockNumber = proposal.originBlockNumber - 256;
    anchorBlockNumber = block.anchorBlockNumber >= minAnchorBlockNumber ?
        minAnchorBlockNumber :
        block.anchorBlockNumber;

    newState.anchorBlockNumber = anchorBlockNumber;
    newState.anchorBlockHash = _newAnchorBlockHashProvision;
    newState.anchorStateRoot = _newAnchorStateRootProvision;
}

```

The driver must provide `_newAnchorBlockHashProvision` and `_newAnchorStateRootProvision` corresponding to the selected anchor block. These values undergo cryptographic verification during the proving phase to ensure L1-L2 state consistency.

## 4. Bond Operations Processing

The Shasta protocol implements a sophisticated bond mechanism to incentivize timely proof submission and penalize malicious behavior. Bond operations facilitate the transfer of economic incentives between L1 and L2.

### Bond Operation Flow

The driver monitors `BondRequest` events emitted by the L1 Inbox contract and collects all bond operations that occurred between the current and new anchor blocks. These operations specify how bonds should be distributed on L2 based on proving behavior on L1.

### Bond Operation Aggregation

Bond operations are processed sequentially and their effects are aggregated into a single hash for verification:

```solidity
uint256 length = bondOperations.length;
bytes32 newBondOperationsHash = currentState.bondOperationsHash;

for (uint256 i; i < length; ++i) {
    LibBondOperation.BondOperation memory op = bondOperations[i];

    // Credit bond to receiver on L2
    bondManager.creditBond(op.receiver, op.credit);

    // Update aggregated hash
    newBondOperationsHash = LibBondOperation.aggregateBondOperation(
        newBondOperationsHash, op
    );
}

// Verify hash matches L1 state
assert(bondOperationsHash == newBondOperationsHash);
newState.bondOperationsHash = newBondOperationsHash;

```

### State Verification

The driver retrieves the L1 Inbox's `CoreState` from the anchor block's world state. The `bondOperationsHash` in this state must match the locally computed hash, ensuring L1 and L2 remain synchronized regarding bond distributions.

## 5. State Commitment and Block Finalization

After constructing and verifying all state fields, the driver commits the new state to the Anchor contract by calling the `setState` function. This atomic operation:

1. Persists the new synchronization state
2. Processes all bond operations
3. Establishes the foundation for the next block in the sequence

The successful state update marks the completion of block derivation for the current block. The driver then proceeds to process the next block in the proposal or awaits the next `Proposed` event.

## 6. Transaction Filtering and Block Assembly

TBD
