# Block Derivation in Taiko

This document details the process of deriving blocks from on-chain proposals in Taiko's Shasta fork.

## Terminology

In the Shasta fork, the term _Proposal_ is used instead of _Batch_ to denote the unit of on-chain submission for block construction data. The term _Finalization_ replaces _Verification_ to describe the state where a proposal's post-state is confirmed as final.

## Metadata

To construct a block, a detailed collection of data, referred to as the block's metadata, is required. This metadata is divided into two primary categories: proposal-level metadata and block-level metadata. The proposal-level metadata is common to all blocks within the proposal, while block-level metadata is specific to each individual block.

### Proposal-level Metadata

| Metadata Component  | Description                                            | Value Assigned |
| ------------------- | ------------------------------------------------------ | -------------- |
| id                  | A unique, sequential identifier for the proposal       | Y              |
| proposer            | The address that proposed the proposal                 | Y              |
| originTimestamp     | The timestamp when the proposal was proposed           | Y              |
| originBlockNumber   | The L1 block number in which the proposal was proposed | Y              |
| proverAuth          | An ABI-encoded ProverAuth object                       |                |
| numBlocks           | The total number of blocks in this proposal            |                |
| basefeeSharingPctg  | The percentage of base fee paid to coinbase            | Y              |
| isEnforcedInclusion | Indicates if the proposal is a forced inclusion        | Y              |

### Block-level Metadata

| Metadata Component   | Description                                           | Value Assigned |
| -------------------- | ----------------------------------------------------- | -------------- |
| timestamp            | The timestamp of the block                            |                |
| coinbase             | The coinbase address for the block                    |                |
| anchorBlockNumber    | The L1 block number to which this block anchors       |                |
| gasIssuancePerSecond | The gas issuance rate per second for the next block   |                |
| transactions         | The list of transactions included in the block        |                |
| index                | The zero-based index of the block within the proposal | Y              |

The process of constructing blocks involves first preparing the necessary metadata for each block. This metadata is then used to assemble the actual L2 block. Throughout this document, we will refer to this metadata as `metadata`, with individual fields denoted as `metadata.someField`.

## Metadata Preparation

This process begins with a subscription to the inbox's Proposed event. In this event, a `proposal` object is emitted. The following is how the proposal is defined in the protocol's L1 contract:

```solidity
/// @notice Represents a proposal for L2 blocks.
struct Proposal {
    /// @notice Unique identifier for the proposal.
    uint48 id;
    /// @notice Address of the proposer.
    address proposer;
    /// @notice The L1 block timestamp when the proposal was accepted.
    uint48 originTimestamp;
    /// @notice The L1 block number when the proposal was accepted.
    uint48 originBlockNumber;
    /// @notice Whether the proposal is from a forced inclusion.
    bool isForcedInclusion;
    /// @notice The percentage of base fee paid to coinbase.
    uint8 basefeeSharingPctg;
    /// @notice Provability bond for the proposal.
    uint48 provabilityBondGwei;
    /// @notice Liveness bond for the proposal, paid by the designated prover.
    uint48 livenessBondGwei;
    /// @notice Blobs that contains the proposal's manifest data.
    LibBlobs.BlobSlice blobSlice;
}
```

We can now collect the following metadata fields:

| Metadata Field              | Value Assignment                 |
| --------------------------- | -------------------------------- |
| metadata.id                 | `= proposal.id;`                 |
| metadata.proposer           | `= proposal.proposer;`           |
| metadata.originTimestamp    | `= proposal.originTimestamp;`    |
| metadata.originBlockNumber  | `= proposal.originBlockNumber;`  |
| metadata.basefeeSharingPctg | `= proposal.basefeeSharingPctg;` |
| metadata.isForcedInclusion  | `= proposal.isForcedInclusion;`  |

The `blobSlice` within the proposal is instrumental in pinpointing and validating the proposal's manifest, which is defined as follows:

```solidity
 /// @notice Represents a signed Ethereum transaction
    /// @dev Follows EIP-2718 typed transaction format with EIP-1559 support
    struct SignedTransaction {
        ... // fields ignore here
    }

    struct ProverAuth {
       ... // fields ignore here
    }

    /// @notice Represents a block manifest
    struct BlockManifest {
        /// @notice The timestamp of the block.
        uint48 timestamp;
        /// @notice The coinbase of the block.
        address coinbase;
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
        ProverAuth proverAuth;
        BlockManifest[] blocks;
    }
```

### Slicing blobs

The `BlobSlice` struct is defined as:

```solidity
/// @notice Represents a frame of data that is stored in multiple blobs. Note the size is
/// encoded as a bytes32 at the offset location.
struct BlobSlice {
    /// @notice The blobs containing the proposal's content.
    bytes32[] blobHashes;
     /// @notice The byte offset of the proposal's content in the containing blobs.
    uint24 offset;
    /// @notice The timestamp when the frame was created.
    uint48 timestamp;
}
```

It reporsents a byte slice contained in one or multiple blobs. We need to concatenate all blobs in the order they are contained in the `blobhashes` field, then read the first 32 bytes at `[offset, offset+31]` as the version number, in Shasta, only `0x1` is supported. For `version = 0x1`, the next 24 bytes at `[offset+32, offset+55]` is the size of the data slice, denoted as `size`.

If the size exceeds a protocol constant `PROPOSAL_MAX_BYTE_SIZE`, an empty bytes (`""`) will be returned.

### Decoding data slice

The data slice will then be ZLIB-decompressed and then RLP-decoded into a `ProposalManifest` object. If decompression fails or decoding fails, an default proposal manifest will be returned.

## Metadata Application

### Pre-Execution Block Header

### Anchor Transaction
