# Taiko Block Derivation

This document describes the block derivation process in Taiko's Shasta upgrade, detailing how Layer 2 (L2, aka Taiko) blocks are derived from Layer 1 (L1, aka Ethereum) proposals.

## TODO:

- [ ] L2 fund payment in anchor

## Data Referencing Conventions

Throughout this document, we use the following conventions to clearly identify data types, instances, and fields:

### Type Notation

- **Structs/Types**: Written with capitalized first letter (e.g., `Proposal`, `CoreState`, `BlockManifest`)
- **Instances**: Written with camelCase prefix to indicate the specific object:
  - `proposal`: The `IInbox.Proposal` instance emitted in the `Proposed` event
  - `coreState`: The `IInbox.CoreState` instance emitted in the `Proposed` event
  - `proposalManifest`: The final `ProposalManifest` object obtained from the Data Extraction Process
  - `blockManifest[i]`: The i-th `BlockManifest` in `proposalManifest.blocks` array
  - `parentState`: The parent L2 block's anchor `State` object from `ShastaAnchor`

### Field Access

- Object fields are accessed using dot notation: `proposal.id`, `blockManifest[i].timestamp`
- Array elements use bracket notation: `proposalManifest.blocks[i]`, `blockManifest[i].transactions[j]`

### Source References

- Contract locations: `ContractName` (e.g., `ShastaAnchor`, `IInbox`)
- Library references: `LibraryName` (e.g., `LibManifest`, `LibBlobs`, `LibBondOperation`)

## Protocol Constants

All protocol constants are defined in `LibManifest.sol` at `/contracts/layer2/based/libs/LibManifest.sol`:

| Constant                           | Value   | Description                                                         |
| ---------------------------------- | ------- | ------------------------------------------------------------------- |
| `FIELD_ELEMENT_BYTE_SIZE`          | 32      | Size of a field element in bytes                                    |
| `BLOB_FIELD_ELEMENT_SIZE`          | 4096    | Number of field elements per blob                                   |
| `BLOB_BYTE_SIZE`                   | 131,072 | Total size of a blob in bytes (4096 × 32)                           |
| `PROPOSAL_MAX_FIELD_ELEMENTS_SIZE` | 24,576  | Maximum field elements for a proposal (6 × 4096)                    |
| `PROPOSAL_MAX_BLOBS`               | 10      | Maximum number of blobs per proposal                                |
| `PROPOSAL_MAX_BLOCKS`              | 384     | Maximum blocks per proposal (covers an Ethereum epoch at 1s blocks) |
| `BLOCK_MAX_TRANSACTIONS`           | 4096    | Maximum transactions per block                                      |
| `ANCHOR_BLOCK_MAX_ORIGIN_OFFSET`   | 128     | Maximum L1 block offset for anchor selection                        |

Additional constants from `ShastaAnchor.sol`:

| Constant           | Value     | Description                                |
| ------------------ | --------- | ------------------------------------------ |
| `ANCHOR_GAS_LIMIT` | 1,000,000 | Gas limit for anchor transaction execution |

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

The proposal's actual content resides in blob storage, referenced through the `LibBlobs.BlobSlice` structure. This design leverages Ethereum's blob storage mechanism introduced in EIP-4844, providing cost-effective data availability for L2 operations.

### BlobSlice Structure

```solidity
/// @notice Represents a frame of data that is stored in multiple blobs. Note the size is
/// encoded as a bytes32 at the offset location.
/// @dev Defined in LibBlobs.sol
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

1. **Blob Retrieval**: Using `proposal.blobSlice.timestamp`, the driver identifies and retrieves the associated blobs from the network.
2. **Check Number of Blobs**: If `proposal.blobSlice.blobHashes.length` exceeds `PROPOSAL_MAX_BLOBS` (10), the default manifest specification will be returned.
3. **Data Concatenation**: Multiple blobs are concatenated into a single continuous byte array for processing.
4. **Header Parsing**: The data header contains critical metadata:
   - Field element as `bytes32` at `proposal.blobSlice.offset`: Version number (currently `0x1` for Shasta)
   - Field element as `uint256` at `proposal.blobSlice.offset + 1`, denoted as `size`: Size of the compressed data in terms of field elements
5. **Version Validation**: If the version number is not `0x1`, the default manifest specification will be returned.
6. **Size Validation**: The `size` is validated against `PROPOSAL_MAX_FIELD_ELEMENTS_SIZE` (24,576). If the size exceeds this protocol constant, the default manifest specification will be returned.
7. **Decompression and Decoding**: For version `0x1`, the data undergoes:

   - Slice the concatenated blob field elements between `[proposal.blobSlice.offset, proposal.blobSlice.offset + size]` as a `bytes32[]`, convert it then to a `bytes` array, denoted as `compressedManifestBytes`
   - ZLIB decompress `compressedManifestBytes` to `rawManifestBytes`
   - RLP decode `rawManifestBytes` to reconstruct the structured `proposalManifest` object

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

- **Block Count Limit**: `proposalManifest.blocks.length` cannot exceed `PROPOSAL_MAX_BLOCKS` (384). If exceeded or the count is zero, keep only the first `PROPOSAL_MAX_BLOCKS` blocks.
- **Transaction Limit**: Each `blockManifest[i].transactions.length` cannot contain more than `BLOCK_MAX_TRANSACTIONS` (4096) transactions. If exceeded, keep only the first `BLOCK_MAX_TRANSACTIONS` transactions.

### Default Manifest Specification

The default manifest serves as a fallback mechanism, ensuring the protocol can continue operating even when blobs contain invalid proposal manifests. It contains a single empty block with the following properties:

```solidity
assert(proposalManifest.blocks.length == 1);
assert(proposalManifest.blocks[0].anchorBlockNumber == 0);
assert(proposalManifest.blocks[0].gasIssuancePerSecond == 0);
assert(proposalManifest.blocks[0].transactions.length == 0);
```

This design ensures that even a malformed proposal manifest result in a valid, though empty, L2 block, preventing network stalls.

## Anchor Transaction and State

The Anchor contract (`ShastaAnchor`) offers a `updateState` function that must be called by a protocol-specific EOA as the very first transaction in each and every L2 block without reverting. The parameters for the `updateState` function are thus part of the L2 transaction's calldata and can be handled by Taiko Node's Ethereum equivalent transaction processing logic without custom code. This offers greater flexibility than out-of-transaction system calls where inputs are restricted to data from the parent block's header or the current block's header fields.

In the `ShastaAnchor` contract, the `State` struct is defined as:

```solidity
    // Proposal level fields (set once per proposal on first block)
    uint48 proposalId; // Unique identifier for the current proposal
    uint16 blockCount; // Total number of blocks in the proposal
    address proposer; // Address that initiated the proposal
    address designatedProver; // Address authorized to prove this proposal (address(0) if none)
    bytes32 bondOperationsHash; // Cumulative hash of all bond operations processed so far

    // Block level fields (updated for each block in the proposal)
    uint16 blockIndex; // Current block being processed (0-indexed, < blockCount)
    uint48 anchorBlockNumber; // Latest L1 block number anchored
```

The `updateState` function takes the following parameters, which are derived from `proposal`, `proposalManifest`, and validated against the parent L2 block's anchor `State` object (`parentState`):

```solidity
function updateState(
        // Proposal level fields - define the overall batch
        uint48 _proposalId,
        uint16 _blockCount,
        address _proposer,
        bytes calldata _proverAuth,
        bytes32 _bondOperationsHash,
        LibBondOperation.BondOperation[] calldata _bondOperations,
        // Block level fields - specific to this block in the proposal
        uint16 _blockIndex,
        uint48 _anchorBlockNumber,
        bytes32 _anchorBlockHash,
        bytes32 _anchorStateRoot
)
    external;
```

### `_proposalId`

This value must be identical to `proposal.id`

### `_anchorBlockNumber`

This value is determined for `blockManifest[i]` as follows:

```solidity
if (
    blockManifest[i].anchorBlockNumber == 0 ||
    blockManifest[i].anchorBlockNumber <= parentState.anchorBlockNumber ||
    blockManifest[i].anchorBlockNumber >= proposal.originBlockNumber ||
    blockManifest[i].anchorBlockNumber + ANCHOR_BLOCK_MAX_ORIGIN_OFFSET <= proposal.originBlockNumber
) {
    if (proposal.isForcedInclusion) return 0;
    else return max(proposal.originBlockNumber - ANCHOR_BLOCK_MAX_ORIGIN_OFFSET, 1)
} else {
    return blockManifest[i].anchorBlockNumber;
}
```

Note: `ANCHOR_BLOCK_MAX_ORIGIN_OFFSET` = 128

### `_anchorBlockHash`

This value is determined as:

```solidity
return _anchorBlockNumber == 0 ?
    bytes32(0) :
    IBlockHashProvider(syncedBlockManager).getBlockHash(_anchorBlockNumber);
```

Where `syncedBlockManager` is the `ISyncedBlockManager` contract instance from `ShastaAnchor`.

### `_anchorStateRoot`

TBD

### `_bondOperationsHash`

If `_anchorBlockNumber` is zero, this value must be zero. Otherwise, it must be a value that satisfies the following:

- There must be an `IInbox.CoreState` instance with field `bondOperationsHash` equal to `_bondOperationsHash`
- The hash of this `IInbox.CoreState` instance must match the `coreStateHash()` stored in the L1 signal service at block `_anchorBlockNumber`

### `_bondOperations`

If `_anchorBlockNumber` is zero, then this array must be empty. Otherwise, it must contain all the `LibBondOperation.BondOperation` instances emitted in `IInbox.BondRequest` events from the `IInbox` contract between `parentState.anchorBlockNumber` and `_anchorBlockNumber` on L1.

Each `LibBondOperation.BondOperation` contains:

- `proposalId`: The proposal ID associated with the bond
- `receiver`: The address receiving the bond credit
- `credit`: The amount of bond credit in wei

### Additional `updateState` Parameters

#### `_blockCount`

For the first block in a proposal (`_blockIndex == 0`), this must equal `proposalManifest.blocks.length`. For subsequent blocks, it must match the value from the first block.

#### `_proposer`

Must be identical to `proposal.proposer`.

#### `_proverAuth`

A `ProverAuth` struct containing authentication data for designating a prover. If the proposer wants to designate themselves as the prover, they must provide a valid ECDSA signature. The struct contains:

- `proposalId`: Must match `proposal.id`
- `proposer`: Must match `proposal.proposer`
- `signature`: ECDSA signature of `keccak256(abi.encode(proposalId, proposer))`

If all fields are zero/empty, no prover is designated.

#### `_blockIndex`

The current block being processed within the proposal (0-indexed). Must be less than `_blockCount` and follow sequential ordering from the parent block.

## Pre-execution Header Fields

_[Section to be completed based on Q&A answers]_

## Transaction Execution

_[Section to be completed based on Q&A answers]_

---
