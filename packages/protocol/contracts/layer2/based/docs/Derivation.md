# Block Derivation in Taiko

This document provides a comprehensive specification for deriving blocks from on-chain proposals in Taiko's Shasta fork.

## Terminology

The Shasta fork introduces refined terminology to better reflect the system's architecture:

- **Proposal**: Replaces the term _Batch_ to denote the unit of on-chain submission for block construction data
- **Finalization**: Replaces _Verification_ to describe the state where a proposal's post-state is confirmed as final

## Metadata Architecture

Block construction requires a comprehensive collection of metadata, organized into two distinct categories:

- **Proposal-level metadata**: Shared across all blocks within a proposal
- **Block-level metadata**: Unique to each individual block

Throughout this document, metadata references follow the notation `metadata.fieldName`.

### Proposal-level Metadata

| **Metadata Component** | **Description**                                             |
| ---------------------- | ----------------------------------------------------------- |
| **id**                 | A unique, sequential identifier for the proposal            |
| **proposer**           | The address that proposed the proposal                      |
| **originTimestamp**    | The timestamp when the proposal was accepted on L1          |
| **originBlockNumber**  | The L1 block number in which the proposal was accepted      |
| **proverAuthBytes**    | An ABI-encoded ProverAuth object                            |
| **numBlocks**          | The total number of blocks in this proposal                 |
| **basefeeSharingPctg** | The percentage of base fee paid to coinbase                 |
| **isForcedInclusion**  | Indicates if the proposal is a forced inclusion             |
| **bondOperationsHash** | Expected cumulative hash after processing bond operations   |
| **bondOperations**     | Array of bond credit/debit operations to be performed on L2 |

### Block-level Metadata

| **Metadata Component** | **Description**                                       |
| ---------------------- | ----------------------------------------------------- |
| **number**             | The block number                                      |
| **difficulty**         | A random number seed                                  |
| **index**              | The zero-based index of the block within the proposal |
| **timestamp**          | The timestamp of the block                            |
| **coinbase**           | The coinbase address for the block                    |
| **gasLimit**           | The block's gas limit                                 |
| **transactions**       | The list of raw transactions included in the block    |
| **anchorBlockNumber**  | The L1 block number to which this block anchors       |
| **anchorBlockHash**    | The block hash for the block at anchorBlockNumber     |
| **anchorStateRoot**    | The state root for the block at anchorBlockNumber     |

## Metadata Preparation

The metadata preparation process initiates with a subscription to the inbox's `Proposed` event, which emits a `proposal` object. The proposal structure is defined in the protocol's L1 smart contract as follows:

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

The following metadata fields are directly extracted from the `proposal` object:

| Metadata Field              | Value Assignment                |
| --------------------------- | ------------------------------- |
| metadata.id                 | `= proposal.id`                 |
| metadata.proposer           | `= proposal.proposer`           |
| metadata.originTimestamp    | `= proposal.originTimestamp`    |
| metadata.originBlockNumber  | `= proposal.originBlockNumber`  |
| metadata.basefeeSharingPctg | `= proposal.basefeeSharingPctg` |
| metadata.isForcedInclusion  | `= proposal.isForcedInclusion`  |

The `blobSlice` field serves as the primary mechanism for locating and validating the proposal's manifest. The manifest structure is defined as follows:

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
  /// @notice The coinbase of the block.
  address coinbase;
  /// @notice The anchor block number. This field can be zero, if so, this block will use the
  /// most recent anchor in a previous block.
  uint48 anchorBlockNumber;
  /// @notice The block's gas limit.
  uint48 gasLimit;
  /// @notice The transactions for this block.
  SignedTransaction[] transactions;
}

/// @notice Represents a proposal manifest
struct ProposalManifest {
  bytes proverAuthBytes;
  BlockManifest[] blocks;
}
```

### Manifest Extraction

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

The `BlobSlice` struct represents binary data distributed across multiple blobs. Processing involves the following steps:

1. **Blob Concatenation**: Concatenate blobs in the order specified by the `blobHashes` array
2. **Version Extraction**: Extract the version number from bytes `[offset, offset+32)` (only version `0x1` is valid for Shasta)
3. **Size Extraction**: Extract the data size from bytes `[offset+32, offset+64)`
4. **Decompression**: Apply ZLIB decompression to the data slice
5. **Decoding**: RLP decode the decompressed data into a `ProposalManifest` struct

#### Default Manifest Conditions

A default manifest is returned when any of the following validation criteria fail:

- **Blob validation**: `blobHashes.length` is zero or exceeds `PROPOSAL_MAX_BLOBS`
- **Offset validation**: `offset > BLOB_BYTES * blobHashes.length - 64`
- **Version validation**: Version number is not `0x1`
- **Size validation**: `size` exceeds `PROPOSAL_MAX_BYTES`
- **Decompression failure**: ZLIB decompression fails
- **Decoding failure**: RLP decoding fails
- **Block count validation**: `manifest.blocks.length` exceeds `PROPOSAL_MAX_BLOCKS`
- **Prover authentication**: Non-empty `proverAuthBytes` that cannot be ABI-decoded into a `ProverAuth` struct
- **Transaction limit**: Any block contains more than `BLOCK_MAX_RAW_TRANSACTIONS` transactions

The default manifest is one initialized as:

```solidity
ProposalManifest memory default;
default.blocks = new Block[](1);
```

A default manifest contains a single empty block, effectively serving as a fallback mechanism for invalid proposals.

### Metadata Validation and Computation

With the extracted manifest, metadata computation proceeds using both the manifest data and the parent block's metadata (`parent.metadata`). The following sections detail the validation rules for each metadata component:

#### `timestamp` Validation

Timestamp validation is performed collectively across all blocks and may result in block count reduction:

1. **Upper bound enforcement**: If `metadata.timestamp > proposal.originTimestamp`, set `metadata.timestamp = proposal.originTimestamp`
2. **Lower bound calculation**: `lowerBound = max(parent.metadata.timestamp + 1, proposal.originTimestamp - TIMESTAMP_MAX_OFFSET)`
3. **Lower bound enforcement**: If `metadata.timestamp < lowerBound`, set `metadata.timestamp = lowerBound`
4. **Block pruning**: If `metadata.timestamp > proposal.originTimestamp` after adjustments, discard this and all subsequent blocks

#### `anchorBlockNumber` Validation

Anchor block validation ensures proper L1 state synchronization and may trigger manifest replacement:

**Invalidation conditions** (sets `anchorBlockNumber` to `parent.metadata.anchorBlockNumber`):

- Non-monotonic progression: `manifest.blocks[i].anchorBlockNumber < parent.metadata.anchorBlockNumber`
- Future reference: `manifest.blocks[i].anchorBlockNumber >= proposal.originBlockNumber`
- Excessive lag: `manifest.blocks[i].anchorBlockNumber < proposal.originBlockNumber - ANCHOR_MAX_OFFSET`

**Forced inclusion protection**: For non-forced proposals (`proposal.isForcedInclusion == false`), if no blocks have valid anchor numbers greater than its parent's, the entire manifest is replaced with the default manifest, penalizing proposals that fail to provide proper L1 anchoring.

#### `anchorBlockHash` and `anchorStateRoot` Validation

The anchor hash and state root must maintain consistency with the anchor block number:

- If `anchorBlockNumber == parent.metadata.anchorBlockNumber`: Both `anchorBlockHash` and `anchorStateRoot` must be zero
- Otherwise: Both fields must accurately reflect the L1 block state at the specified `anchorBlockNumber`

#### `coinbase` Assignment

The L2 coinbase address determination follows a hierarchical priority system:

```solidity
function assignCoinbase() {
    if (metadata.isForcedInclusion) {
        // Forced inclusions always reward the proposer
        metadata.coinbase = proposal.proposer;
    } else {
        // Use manifest-specified coinbase, falling back to proposer
        metadata.coinbase = manifest.blocks[i].coinbase;
        if (metadata.coinbase == address(0)) {
            metadata.coinbase = proposal.proposer;
        }
    }
}
```

#### `gasLimit` Validation

Gas limit adjustments are constrained by `MAX_BLOCK_GAS_LIMIT_CHANGE_PERMYRIAD` permyriad (units of 1/10,000) per block to ensure economic stability. With the default value of 10 permyriad, this allows ±0.1 basis points (±0.001%) change per block. Additionally, block gas limit must never fall below `MIN_BLOCK_GAS_LIMIT`:

**Calculation process**:

1. **Define bounds**:

   - `lowerBound = max(parent.metadata.gasLimit * (100000 - MAX_BLOCK_GAS_LIMIT_CHANGE_PERMYRIAD) / 100000, MIN_BLOCK_GAS_LIMIT)`
   - `upperBound = parent.metadata.gasLimit * (100000 + MAX_BLOCK_GAS_LIMIT_CHANGE_PERMYRIAD) / 100000`

2. **Apply constraints**:
   - If `manifest.blocks[i].gasLimit == 0`: Inherit parent value
   - If below `lowerBound`: Clamp to `lowerBound`
   - If above `upperBound`: Clamp to `upperBound`
   - Otherwise: Use manifest value unchanged

#### `bondOperationsHash` and `bondOperations` Validation

For an L2 block with a higher anchor block number than its parent, bond operations must be processed within its anchor transaction.

To begin, locate a `CoreState` object in the L1 anchor block's world state whose keccak hash matches the `coreStateHash` from the inbox contract. Extract the `bondOperationsHash` field from this object and set `metadata.bondOperationsHash` to this value.

If `metadata.anchorBlockNumber` exceeds `parent.metadata.anchorBlockNumber`, collect all `BondOperations` emitted from the Taiko inbox via `BondOperationCreated` events, occurring between blocks numbered `parent.metadata.anchorBlockNumber + 1` and `metadata.anchorBlockNumber`. Assign this collection to `metadata.bondOperations`, which may be empty.

#### Additional Metadata Fields

The remaining metadata fields follow straightforward assignment patterns:

| Metadata Field             | Value Assignment                                                  |
| -------------------------- | ----------------------------------------------------------------- |
| `metadata.index`           | `parent.metadata.index + 1` (abbreviated as `i`)                  |
| `metadata.number`          | `parent.metadata.number + 1`                                      |
| `metadata.difficulty`      | `keccak(abi.encode(parent.metadata.difficulty, metadata.number))` |
| `metadata.numBlocks`       | `manifest.blocks.length` (post-validation)                        |
| `metadata.proverAuthBytes` | `manifest.proverAuthBytes`                                        |
| `metadata.transactions`    | `manifest.blocks[i].transactions`                                 |

**Important**: The `numBlocks` field must be assigned only after timestamp and anchor block validation completes, as these validations may reduce the effective block count.

## Metadata Application

The validated metadata serves three critical functions in block construction:

1. **Pre-execution block header field determination**
2. **L2 anchor transaction construction**
3. **L2 world state modification**

### Pre-Execution Block Header

Metadata encoding into L2 block header fields facilitates efficient peer validation and statistical analysis:

| Metadata Component   | Type    | Header Field                  |
| -------------------- | ------- | ----------------------------- |
| `number`             | uint256 | `number`                      |
| `timestamp`          | uint256 | `timestamp`                   |
| `difficulty`         | uint256 | `difficulty`                  |
| `gasLimit`           | uint256 | `gasLimit`                    |
| `id`                 | uint48  | `withdrawalsRoot` (bytes TBD) |
| `numBlocks`          | uint16  | `withdrawalsRoot` (bytes TBD) |
| `isForcedInclusion`  | bool    | `withdrawalsRoot` (bytes TBD) |
| `index`              | uint16  | `withdrawalsRoot` (bytes TBD) |
| `basefeeSharingPctg` | uint8   | First byte in `extraData`     |
| `anchorBlockNumber ` | uint48  | Next 6 bytes in `extraData`   |

#### Additional Pre-Execution Block Header Fields

The following block header fields are also set before transaction execution but are not derived from metadata:

| Header Field | Value                                                                                                                                                             |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `parentHash` | Hash of the previous L2 block                                                                                                                                     |
| `mixHash`    | 0                                                                                                                                                                 |
| `baseFee`    | Calculated using EIP-4396 from `parent.metadata.timestamp`, `parent.metadata.timestamp`,[how to break here ]and `metadata.timestamp` before transaction execution |

Note: Fields like `stateRoot`, `transactionsRoot`, `receiptsRoot`, `logsBloom`, and `gasUsed` are populated after transaction execution.

### Anchor Transaction

The anchor transaction serves as a privileged system transaction responsible for L1 state synchronization and bond operation processing. It invokes the `updateState` function on the ShastaAnchor contract with precisely defined parameters:

| Parameter          | Type            |
| ------------------ | --------------- |
| proposalId         | uint48          |
| blockCount         | uint16          |
| proposer           | address         |
| proverAuth         | bytes           |
| bondOperationsHash | bytes32         |
| bondOperations     | BondOperation[] |
| blockIndex         | uint16          |
| anchorBlockNumber  | uint48          |
| anchorBlockHash    | bytes32         |
| anchorStateRoot    | bytes32         |

#### Transaction Execution Flow

The anchor transaction executes a carefully orchestrated sequence of operations:

1. **Proposal initialization** (blockIndex == 0 only)

   - Initializes proposal state
   - Validates prover authentication credentials

2. **Bond operation processing** (all blocks)

   - Processes operations incrementally
   - Maintains cumulative hash for verification

3. **L1 state anchoring** (when anchorBlockNumber > parent.metadata.anchorBlockNumber)

   - Persists L1 block data
   - Enables cross-chain verification

4. **Parent block verification**
   - Validates parent block hash
   - Ensures chain continuity

**Execution constraints**:

- Gas limit: Exactly 1,000,000 gas
- Caller restriction: Golden touch address (system account) only

### Transaction Execution

TODO

## Base Fee Calculation

The calculation of block base fee shall follow [EIP-4396](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-4396.md#specification).
