# Taiko Block Derivation

This document describes the block derivation process in Taiko's Shasta upgrade, detailing how Layer 2 (L2, aka Taiko) blocks are derived from Layer 1 (L1, aka Ethereum) proposals.

## TODO:

- [ ] L2 fund payment in anchor

## Overview

The Shasta block derivation process transforms L1 proposals into L2 blocks through a deterministic process executed by the Taiko driver. This involves subscribing to L1 events, extracting and decompressing proposal data from blobs, building blocks according to the manifest, and managing state synchronization through the Anchor contract.

## Event Subscription and Proposal Structure

The Taiko driver begins by subscribing to the `Proposed` event emitted by the L1 Inbox contract. This event signals that a new proposal has been accepted to the network and contains all the necessary information for block derivation.

```solidity
/// @notice Emitted when a new proposal is accepted.
/// @param proposal The proposal that was proposed.
/// @param coreState The core state at the time of proposal.
event Proposed(Proposal proposal, CoreState coreState);
```

The `Proposal` struct encapsulates all metadata required for L2 block derivation. Each field serves a specific purpose in the derivation process:

```solidity
struct Proposal {
        /// @notice Unique identifier for the proposal.
        uint48 id;
        /// @notice Address of the proposer.
        address proposer;
        /// @notice Provability bond for the proposal.
        uint48 provabilityBondGwei;
        /// @notice Liveness bond for the proposal, paid by the designated prover.
        uint48 livenessBondGwei;
        /// @notice The L1 block timestamp when the proposal was accepted.
        uint48 originTimestamp;
        /// @notice The L1 block number when the proposal was accepted.
        uint48 originBlockNumber;
        /// @notice Whether the proposal is from a forced inclusion.
        bool isForcedInclusion;
        /// @notice The proposal's chunk.
        LibBlobs.BlobSlice blobSlice;
}
```

## Blob Data Extraction and Manifest Decoding

The proposal's actual content resides in blob storage, referenced through the `BlobSlice` structure. This design leverages Ethereum's blob storage mechanism introduced in EIP-4844, providing cost-effective data availability for L2 operations.

### BlobSlice Structure

```solidity
/// @notice Represents a frame of data that is stored in multiple blobs. Note the size is
/// encoded as a bytes32 at the offset location.
struct BlobSlice {
    /// @notice The blobs containing the proposal's content.
    bytes32[] blobHashes;
    /// @notice The field-element offset of the proposal's content in the containing blobs.
    /// The byte-offset would be 32 * offset.
    uint24 offset;
    /// @notice The timestamp when the frame was created.
    uint48 timestamp;
}
```

All blobs must be created in the same Ethereum transaction.

### Data Extraction Process

The driver locates and processes blob data through the following steps:

1. **Blob Retrieval**: Using the timestamp field, the driver identifies and retrieves the associated blobs from the network.
2. **Check Number of Blobs**: If the `blobHashes` size exceeds `PROPOSAL_MAX_BLOBS`, the default manifest specification will be returned.
3. **Data Concatenation**: Multiple blobs are concatenated into a single continuous byte array for processing.
4. **Header Parsing**: The data header contains critical metadata:
   - Field element as `bytes32` at `offset`: Version number (currently `0x1` for Shasta)
   - Field element as `uint256` at `offset + 1`, denoted as `size`: Size of the compressed data in terms of field elements
5. **Version Validation**: If the version number is not `0x1`, the default manifest specification will be returned.
6. **Size Validation**: The `size` is validated against `PROPOSAL_MAX_FIELD_ELEMENTS_SIZE`. If the size exceeds this protocol constant, the default manifest specification will be returned.
7. **Decompression and Decoding**: For version `0x1`, the data undergoes:

   - Slice the concatenated blob field elements between `[offset, offset + size]` as a `bytes32[]`, convert it then to a `bytes` array, denoted as `compressedManifestBytes`
   - ZLIB decompress `compressedManifestBytes` to `rawManifestBytes`
   - RLP decode `rawManifestBytes` to reconstruct the structured `ProposalManifest` object

   If decompression or RLP decoding fails at any stage, the default manifest specification will be returned.

### ProposalManifest Structure

The decoded `ProposalManifest` contains the complete specification for one or more L2 blocks to be derived:

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

- **Block Count Limit**: The number of blocks cannot exceed `PROPOSAL_MAX_BLOCKS`. If exceeded or the count is zero, keep only the first `PROPOSAL_MAX_BLOCKS` blocks.
- **Transaction Limit**: Each block cannot contain more than `BLOCK_MAX_TRANSACTIONS` transactions. If exceeded, keep only the first `BLOCK_MAX_TRANSACTIONS` transactions.

### Default Manifest Specification

The default manifest serves as a fallback mechanism, ensuring the protocol can continue operating even when blobs contain invalid proposal manifests. It contains a single empty block with the following properties:

```solidity
assert(defaultManifest.blocks.length == 1);
assert(defaultManifest.blocks[0].anchorBlockNumber == 0);
assert(defaultManifest.blocks[0].gasIssuancePerSecond == 0);
assert(defaultManifest.blocks[0].transactions.length == 0);
```

This design ensures that even a malformed proposal manifest result in a valid, though empty, L2 block, preventing network stalls.

## Anchor Transaction and State

The Anchor contract offers a `setState` function that must be called by a protocol-specific EOA as the very first transaction in each and every L2 block without reverting. The parameters for the `setState` function are thus part of the L2 transaction's calldata and can be handled by Taiko Node's Ethereum equivilant transaction processing logic without custom code. This offers greater flexibility than out-of-transaction system calls where inputs are restricted to data from the parent block's header or the current block's header fields.

In the Anchor contract, the `State` is defined as:

```solidity
struct State {
    uint48 anchorBlockNumber;
    bytes32 bondOperationsHash;
}
```

The `setState` function takes the following parameters, which are derived from the proposal and/or its manifest and validated against the parent L2 block's anchor `State` object (`parentState`):

```solidity
function setState(
    uint48 _anchorBlockNumber,
    bytes32 _anchorBlockHash,
    bytes32 _anchorStateRoot,
    bytes32 _bondOperationsHash,
    LibBondOperation.BondOperation[] calldata _bondOperations
)
    external;
```

### `_anchorBlockNumber`

This value is determined as follows:

```solidity
if (
    manifest.anchorBlockNumber == 0 ||
    manifest.anchorBlockNumber <= parentState.anchorBlockNumber ||
    manifest.anchorBlockNumber >= proposal.originBlockNumber ||
    manifest.anchorBlockNumber + ANCHOR_BLOCK_MAX_ORIGIN_OFFSET <= proposal.originBlockNumber
) {
    if (proposal.isForcedInclusion) return 0;
    else return (proposal.originBlockNumber - ANCHOR_BLOCK_MAX_ORIGIN_OFFSET).max(1)
} else {
    return manifest.anchorBlockNumber;
}
```

### `_anchorBlockHash`

This value is determined as:

```solidity
return _anchorBlockNumber == 0 ?
    bytes32(0) :
    IBlockHashProvider(anchorContract).getBlockHash(_anchorBlockNumber);
```

### `_anchorStateRoot`

TBD

### `_bondOperationsHash`

If `_anchorBlockNumber` is zero, this value must be zero. Otherwise, it must be a value that satisfies the following:

- There must be an `IInbox.CoreState` object that contains `_bondOperationsHash`
- The hash of this `IInbox.CoreState` object must match the `coreStateHash()` in the L1 block at `_anchorBlockNumber`

### `_bondOperations`

If `_anchorBlockNumber` is zero, then this array must be empty. Otherwise, it must contain all the `BondOperation` objects emitted in `BondOperationCreated` events from the Inbox between `parentState.anchorBlockNumber` and `_anchorBlockNumber` on L1.

## Pre-execution Header Fields

_[Section to be completed based on Q&A answers]_

## Transaction Execution

_[Section to be completed based on Q&A answers]_

---

## Guidelines for Claude Code

- all constant values must be defined somewhere in solidity code.
