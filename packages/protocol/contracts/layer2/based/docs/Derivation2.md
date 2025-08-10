# Block Derivation in Taiko

This document details the process of deriving blocks from on-chain proposals in Taiko's Shasta fork.

## Terminology

In the Shasta fork, the term _Proposal_ is used instead of _Batch_ to denote the unit of on-chain submission for block construction data. The term _Finalization_ replaces _Verification_ to describe the state where a proposal's post-state is confirmed as final.

## Metadata

To construct a block, a detailed collection of data, referred to as the block's metadata, is required. This metadata is divided into two primary categories: proposal-level metadata and block-level metadata. The proposal-level metadata is common to all blocks within the proposal, while block-level metadata is specific to each individual block.

### Proposal-level Metadata

| Metadata Component  | Description                                            |
| ------------------- | ------------------------------------------------------ |
| id                  | A unique, sequential identifier for the proposal       |
| proposer            | The address that proposed the proposal                 |
| originTimestamp     | The timestamp when the proposal was proposed           |
| originBlockNumber   | The L1 block number in which the proposal was proposed |
| proverAuthBytes     | An ABI-encoded ProverAuth object                       |
| numBlocks           | The total number of blocks in this proposal            |
| basefeeSharingPctg  | The percentage of base fee paid to coinbase            |
| isEnforcedInclusion | Indicates if the proposal is a forced inclusion        |

### Block-level Metadata

| Metadata Component   | Description                                           |
| -------------------- | ----------------------------------------------------- |
| index                | The zero-based index of the block within the proposal |
| timestamp            | The timestamp of the block                            |
| coinbase             | The coinbase address for the block                    |
| gasIssuancePerSecond | The gas issuance rate per second for the next block   |
| transactions         | The list of transactions included in the block        |
| anchorBlockNumber    | The L1 block number to which this block anchors       |
| anchorBlockHash      | The block hash for block at anchorBlockNumber         |
| anchorStateRoot      | The state root for block at anchorBlockNumber         |

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

| Metadata Field              | Value Assignment                |
| --------------------------- | ------------------------------- |
| metadata.id                 | `= proposal.id`                 |
| metadata.proposer           | `= proposal.proposer`           |
| metadata.originTimestamp    | `= proposal.originTimestamp`    |
| metadata.originBlockNumber  | `= proposal.originBlockNumber`  |
| metadata.basefeeSharingPctg | `= proposal.basefeeSharingPctg` |
| metadata.isForcedInclusion  | `= proposal.isForcedInclusion`  |

The `blobSlice` within the proposal is instrumental in pinpointing and validating the proposal's manifest, which is defined as follows:

```solidity
 /// @notice Represents a signed Ethereum transaction
    /// @dev Follows EIP-2718 typed transaction format with EIP-1559 support
    struct SignedTransaction {
        // Transaction fields omitted for brevity
    }

    struct ProverAuth {
        // Fields omitted for brevity
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
        bytes proverAuthBytes;
        BlockManifest[] blocks;
    }
```

### Obtain Manifest

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

The `BlobSlice` structure is designed to represent a segment of data distributed across multiple blobs. To process this data, concatenate the blobs in the order specified by the `blobHashes` array. The initial 32 bytes, located at the range `[offset, offset+32)`, denote the version number. Within the Shasta protocol, only version `0x1` is considered valid. For this version, the next 32 bytes, located at `[offset+32, offset+64)`, specify the size of the data slice, termed as `size`.

Subsequently, the data slice is subjected to ZLIB decompression followed by RLP decoding to transform it into a `manifest` object.

A default Manifest will be returned in any of the following conditions:

- `blobHashes.length` is either zero or exceeds `PROPOSAL_MAX_BLOBS`.
- `offset` is greater than `4096 * 32 * blobHashes.length - 64`.
- The version number is not `0x1`.
- `size` exceeds `PROPOSAL_MAX_BYTE_SIZE`.
- ZLIB-decompression fails.
- RLP-decoding fails.
- `manifest.blocks.length` exceeds `PROPOSAL_MAX_BLOCKS`.
- `proverAuthBytes` bytes is non-empty but cannot be ABI-decoded into a `ProverAuth` struct.
- Any block in `manifest.blocks` contains more than `BLOCK_MAX_RAW_TRANSACTIONS` transactions.

The default manifest is one initialized as:

```solidity
ProposalManifest memory default;
default.blocks = new Block[](1);
```

The default manifest is characterized by having only one empty block.

At this stage, we have an unvalidated `manifest` object, which is used to compute the metadata for this block in conjunction with the parent block's metadata, `parent.metadata`.

- **`timestamp`**

  A crucial piece of metadata is the `timestamp`. The validation of this metadata is performed for all blocks in the proposal collectively, and it may result in altering the number of blocks in the proposal. For each block's timestamp, the following rules are applied:

  - Calculate the lower bound as `lowerBound = max(parent.metadata.timestamp + 1, proposal.originTimestamp - TIMESTAMP_MAX_OFFSET)`.
  - If `metadata.timestamp` is smaller than this lower bound, set `metadata.timestamp = lowerBound`.
  - If `metadata.timestamp` exceeds `proposal.originTimestamp`, this block and all subsequent blocks are discarded, reducing the total number of blocks in the manifest.

- **`anchorBlockNumber`**

  This is another crucial piece of metadata that must be validated collectively for all blocks, potentially reducing the number of blocks in the manifest. For a block, we set this metadata to 0 if any of the following conditions are met:

  - `manifest.blocks[i].anchorBlockNumber` is bigger than `parent.metadata.anchorBlockNumber`.
  - `manifest.blocks[i].anchorBlockNumber` is not smaller than `proposal.originBlockNumber`.

  If `proposal.isForcedInclusion` is true, we count the number of blocks in the manifest with a non-zero anchor block number. If this count is zero, we assign the default manifest to `manifest`, resulting in a proposal with a single empty block.

- **`anchorBlockHash` and `anchorStateRoot`**

  If a L2 block has a zero `anchorBlockNumber`, both `anchorBlockHash` and `anchorStateRoot` should also be zero. Otherwise, they must accurately reflect the values corresponding to the L1 block at the specified `anchorBlockNumber`.

  @Yue, could this pose a challenge for the prover?

- **`coinbase`**

  The L2 coinbase value is determined by checking if the proposal is a forced inclusion. If it is, the coinbase is set to the proposal's proposer. Otherwise, it is set to the coinbase address specified in the block manifest. If this address is zero, the coinbase defaults to the proposal's proposer.

  ```solidity
  function assignCoinbase() {
      if (metadata.isForcedInclusion) {
          metadata.coinbase = proposal.proposer;
      } else {
          metadata.coinbase = manifest.blocks[i].coinbase;
          if (metadata.coinbase == address(0)) {
              metadata.coinbase = proposal.proposer;
          }
      }
  }
  ```

- **`gasIssuancePerSecond`**

  Each L2 block can adjust the gas issuance parameter as long as the new value is within a +/-1 basis point range. Therefore the value is determined as follows:

  - let `lowerBound = parent.metadata.gasIssuancePerSecond * 9999/10000` and `upperBound = parent.metadata.gasIssuancePerSecond * 10001/10000`
  - if `manifest.blocks[i].gasIssuancePerSecond` is zero, use `parent.metadata.gasIssuancePerSecond`
  - if `manifest.blocks[i].gasIssuancePerSecond` is smaller than `lowerBound`, use `lowerBound` as the value,
  - if `manifest.blocks[i].gasIssuancePerSecond` is greater than `upperBound`, use `upperBound` as the value,
  - otherwise, use `manifest.blocks[i].gasIssuancePerSecond` as is.

- Other metadata
  Other metadata assignments are more straightforward.

  | Metadata Field           | Value Assignment                                     |
  | ------------------------ | ---------------------------------------------------- |
  | metadata.index           | `= parent.metadata.index + 1` (we use `i` for short) |
  | metadata.numBlocks       | `= manifest.blocks.length`                           |
  | metadata.proverAuthBytes | `= manifest.proverAuthBytes`                         |
  | metadata.transactions    | `= manifest.blocks[i].transactions`                  |

## Metadata Application

### Pre-Execution Block Header

### Anchor Transaction
