# Block Derivation in Taiko

This document details the process of deriving blocks from on-chain proposals in Taiko's Shasta fork.

## Terminology

In the Shasta fork, the term _Proposal_ is used instead of _Batch_ to denote the unit of on-chain submission for block construction data. The term _Finalization_ replaces _Verification_ to describe the state where a proposal's post-state is confirmed as final.

## Metadata

To construct a block, a detailed collection of data, referred to as the block's metadata, is required. This metadata is divided into two primary categories: proposal-level metadata and block-level metadata. The proposal-level metadata is common to all blocks within the proposal, while block-level metadata is specific to each individual block.

### Proposal-level Metadata

| Metadata Component       | Description                                      |
| ------------------------ | ------------------------------------------------ |
| id                       | A unique, sequential identifier for the proposal |
| proposer                 | The address of the entity proposing the proposal |
| originTimestamp          | The timestamp when the proposal was accepted     |
| originBlockNumber        | The block number when the proposal was accepted  |
| proverAuth               | An ABI-encoded ProverAuth object                 |
| numBlocks                | The total number of blocks in this proposal      |
| basefeeSharingPercentage | The percentage of base fee paid to coinbase      |
| isEnforcedInclusion      | Indicates if the proposal is a forced inclusion  |

### Block-level Metadata

| Metadata Component   | Description                                           |
| -------------------- | ----------------------------------------------------- |
| timestamp            | The timestamp of the block                            |
| coinbase             | The coinbase address for the block                    |
| anchorBlockNumber    | The L1 block number to which this block anchors       |
| gasIssuancePerSecond | The gas issuance rate per second for the next block   |
| transactions         | The list of transactions included in the block        |
| index                | The zero-based index of the block within the proposal |

The process of constructing blocks involves first preparing the necessary metadata for each block. This metadata is then used to assemble the actual L2 block. Throughout this document, we will refer to this metadata as `metadata`, with individual fields denoted as `metadata.someField`.

## Metadata Preparation

This process begins with a subscription to the inbox's Proposed event. In this event, a `proposal` object is emitted. The following is how the proposal is defined in the protocol contract:

```solidity
/// @notice Represents a proposal for L2 blocks.
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

We can now collect the following metadata fields:

```solidity
    metadata.id = proposal.id;
    metadata.proposer = proposal.proposer;
    metadata.originTimestamp = proposal.originTimestamp;
    metadata.originBlockNumber = proposal.originBlockNumber;
    metadata.isForcedInclusion = proposal.isForcedInclusion;
```

The blob slice object in the proposal can help locate and verify the proposal's mannifest, an object defined as:

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

But the manifest object is encoded and compressed in the blob, so we need to first identify the slice of bytes then perform decompression and decoding.

## Metadata Application

### Pre-Execution Block Header

### Anchor Transaction
