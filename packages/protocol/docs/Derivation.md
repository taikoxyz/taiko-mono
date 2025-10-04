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

| **Metadata Component**   | **Description**                                               |
| ------------------------ | ------------------------------------------------------------- |
| **id**                   | A unique, sequential identifier for the proposal              |
| **proposer**             | The address that proposed the proposal                        |
| **isLowBondProposal**    | Indicates if the proposer has insufficient bond or is exiting |
| **designatedProver**     | The prover responsible for proving the block                  |
| **timestamp**            | The timestamp when the proposal was accepted on L1            |
| **originBlockNumber**    | The L1 block number in which the proposal was accepted        |
| **proverAuthBytes**      | An ABI-encoded ProverAuth object                              |
| **numBlocks**            | The total number of blocks in this proposal                   |
| **basefeeSharingPctg**   | The percentage of base fee paid to coinbase                   |
| **isForcedInclusion**    | Indicates if the proposal is a forced inclusion               |
| **bondInstructionsHash** | Expected cumulative hash after processing bond instructions   |
| **bondInstructions**     | Array of bond credit/debit instructions to be performed on L2 |

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

The metadata preparation process initiates with a subscription to the inbox's `Proposed` event, which emits a `ProposedEventPayload` object containing the `proposal`, `derivation`, and `coreState`. The proposal structure is defined in the protocol's L1 smart contract as follows:

```solidity
/// @notice Represents a proposal for L2 blocks.
struct Proposal {
  /// @notice Unique identifier for the proposal.
  uint48 id;
  /// @notice The L1 block timestamp when the proposal was accepted.
  uint48 timestamp;
  /// @notice The timestamp of the last slot where the current preconfer can propose.
  uint48 endOfSubmissionWindowTimestamp;
  /// @notice Address of the proposer.
  address proposer;
  /// @notice The current hash of coreState
  bytes32 coreStateHash;
  /// @notice Hash of the Derivation struct containing additional proposal data.
  bytes32 derivationHash;
}
```

The `Derivation` struct contains additional proposal data not needed during proving:

```solidity
/// @notice Contains derivation data for a proposal that is not needed during proving.
/// @dev This data is hashed and stored in the Proposal struct to reduce calldata size.
struct Derivation {
  /// @notice The L1 block number when the proposal was accepted.
  uint48 originBlockNumber;
  /// @notice The hash of the origin block.
  bytes32 originBlockHash;
  /// @notice The percentage of base fee paid to coinbase.
  uint8 basefeeSharingPctg;
  /// @notice Array of derivation sources, where each can be regular or forced inclusion.
  DerivationSource[] sources;
}

/// @notice Represents a source of derivation data within a Derivation
struct DerivationSource {
  /// @notice Whether this source is from a forced inclusion.
  bool isForcedInclusion;
  /// @notice Blobs that contain the source's manifest data.
  LibBlobs.BlobSlice blobSlice;
}
```

The following metadata fields are extracted from the `proposal` and `derivation` objects:

| Metadata Field                | Value Assignment                    |
| ----------------------------- | ----------------------------------- |
| `metadata.id`                 | `proposal.id`                      |
| `metadata.proposer`           | `proposal.proposer`                 |
| `metadata.timestamp`          | `proposal.timestamp`                |
| `metadata.originBlockNumber`  | `derivation.originBlockNumber`      |
| `metadata.basefeeSharingPctg` | `derivation.basefeeSharingPctg`     |
| `metadata.isForcedInclusion`  | `derivation.sources[i].isForcedInclusion` |

The `derivation.sources` array contains `DerivationSource` objects, each with a `blobSlice` field that serves as the primary mechanism for locating and validating the proposal's manifest. The manifest structure is defined as follows:

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

### Proposer and `isLowBondProposal` Validation

To maintain the integrity of the proposal process, the `proposer` address must pass specific validation checks, which include:

- Confirming that the proposer holds a sufficient balance in the L2 BondManager contract.
- Ensuring the proposer is not waiting for exiting.

Should any of these validation checks fail (as determined by the `updateState` function returning `isLowBondProposal = true`), the proposal is replaced with the default manifest, which contains a single empty block with no transactions.

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
4. **Decompression**: Apply ZLIB decompression to the extracted data slice (bytes `[offset+64, offset+64+size)`)
5. **Decoding**: RLP decode the decompressed data into a `ProposalManifest` struct

#### Default Manifest Conditions

A default manifest is returned when any of the following validation criteria fail:

- **Blob validation**: `blobHashes.length` is zero
- **Offset validation**: `offset > BLOB_BYTES * blobHashes.length - 64`
- **Version validation**: Version number is not `0x1`
- **Decompression failure**: ZLIB decompression fails
- **Decoding failure**: RLP decoding fails
- **Block count validation**: `manifest.blocks.length` exceeds `PROPOSAL_MAX_BLOCKS`

The default manifest is one initialized as:

```solidity
ProposalManifest memory default;
default.blocks = new BlockManifest[](1) ;
```

A default manifest contains a single empty block, effectively serving as a fallback mechanism for invalid proposals.

### Metadata Validation and Computation

With the extracted manifest, metadata computation proceeds using both the manifest data and the parent block's metadata (`parent.metadata`). The following sections detail the validation rules for each metadata component:

#### `timestamp` Validation

Timestamp validation is performed collectively across all blocks and may result in block count reduction:

1. **Upper bound enforcement**: If `metadata.timestamp > proposal.timestamp`, set `metadata.timestamp = proposal.timestamp`
2. **Lower bound calculation**: `lowerBound = max(parent.metadata.timestamp + 1, proposal.timestamp - TIMESTAMP_MAX_OFFSET)`
3. **Lower bound enforcement**: If `metadata.timestamp < lowerBound`, set `metadata.timestamp = lowerBound`

#### `anchorBlockNumber` Validation

Anchor block validation ensures proper L1 state synchronization and may trigger manifest replacement:

**Invalidation conditions** (sets `anchorBlockNumber` to `parent.metadata.anchorBlockNumber`):

- **Non-monotonic progression**: `manifest.blocks[i].anchorBlockNumber < parent.metadata.anchorBlockNumber`
- **Future reference**: `manifest.blocks[i].anchorBlockNumber >= proposal.originBlockNumber - ANCHOR_MIN_OFFSET`
- **Excessive lag**: `manifest.blocks[i].anchorBlockNumber < proposal.originBlockNumber - ANCHOR_MAX_OFFSET`

**Forced inclusion protection**: For non-forced proposals (`proposal.isForcedInclusion == false`), if no blocks have valid anchor numbers greater than its parent's, the entire manifest is replaced with the default manifest, penalizing proposals that fail to provide proper L1 anchoring.

#### `anchorBlockHash` and `anchorStateRoot` Validation

The anchor hash and state root must maintain consistency with the anchor block number (enforced by the Taiko node/driver):

- If `anchorBlockNumber == parent.metadata.anchorBlockNumber`: Both `anchorBlockHash` and `anchorStateRoot` must be zero
- Otherwise: Both fields must accurately reflect the L1 block state at the specified `anchorBlockNumber`

#### `coinbase` Assignment

The L2 coinbase address determination follows a hierarchical priority system:

1. **Forced inclusions**: Always use `proposal.proposer`
2. **Regular proposals**: Use `manifest.blocks[i].coinbase` if non-zero
3. **Fallback**: Use `proposal.proposer` if manifest coinbase is `address(0)`

#### `gasLimit` Validation

Gas limit adjustments are constrained by `BLOCK_GAS_LIMIT_MAX_CHANGE` permyriad (units of 1/10,000) per block to ensure economic stability. With the default value of 10 permyriad, this allows ±10 basis points (±0.1%) change per block. Additionally, block gas limit must never fall below `MIN_BLOCK_GAS_LIMIT`:

**Calculation process**:

1. **Define bounds**:

   - `lowerBound = max(parent.metadata.gasLimit * (10000 - BLOCK_GAS_LIMIT_MAX_CHANGE) / 10000, MIN_BLOCK_GAS_LIMIT)`
   - `upperBound = parent.metadata.gasLimit * (10000 + BLOCK_GAS_LIMIT_MAX_CHANGE) / 10000`

2. **Apply constraints**:
   - If `manifest.blocks[i].gasLimit == 0`: Inherit parent value
   - If below `lowerBound`: Clamp to `lowerBound`
   - If above `upperBound`: Clamp to `upperBound`
   - Otherwise: Use manifest value unchanged

#### `bondInstructionsHash` and `bondInstructions` Validation

The first block's anchor transaction in each proposal must process all bond instructions linked to transitions finalized by the parent proposal. Bond instructions are defined as follows:

```solidity
/// @notice Represents a bond instruction for processing in the anchor transaction
struct BondInstruction {
  uint48 proposalId;
  BondType bondType;
  address payer;
  address payee;
}

/// @notice Types of bonds
enum BondType {
  NONE,
  PROVABILITY,
  LIVENESS
}
```

Bond instructions are emitted in the `Proposed` event, requiring clients to index these events. This indexing allows for the off-chain aggregation of bond instructions, which are then provided to the anchor transaction as input. Transitions that are proved but not used for finalization will be excluded from the anchor process and should be removed from the index.

A parent proposal L1 transaction may revert, potentially causing the subsequent proposal's anchor transaction to revert due to differing bond instructions. To reduce such reverts, the anchor transaction processes bond instructions from an ancestor proposal that is `BOND_PROCESSING_DELAY` proposals prior to the current one. If `BOND_PROCESSING_DELAY` is set to 1, it effectively processes the parent proposal's instructions.

### Designated Prover System

The designated prover system ensures every L2 block has a responsible prover, maintaining chain liveness even during adversarial conditions. The system operates through the `updateState` function in ShastaAnchor, which manages prover designation on the first block of each proposal (`blockIndex == 0`).

The `ProverAuth` structure used in Shasta for prover authentication:

```solidity
/// @notice Structure for prover authentication
/// @dev Used in the proverAuthBytes field of ProposalManifest
struct ProverAuth {
  address prover;
  address feeToken;
  uint96 fee;
  uint64 validUntil; // optional
  uint64 batchId; // optional
  bytes signature;
}
```

#### Prover Designation Process

##### 1. Authentication and Validation

The `_validateProverAuth` function processes prover authentication data with the following steps:

- **Signature Verification**:

  - Validates the `ProverAuth` struct from the provided bytes
  - Decodes the `ProverAuth` containing: `prover`, `feeToken`, `fee`, `validUntil`, `batchId`, and ECDSA `signature`
  - Verifies the signature against the computed message digest
  - Returns the authenticated prover address and fee information

- **Validation Failures**: If authentication fails (insufficient data length < 161 bytes, ABI decode failure, invalid signature, or mismatched proposal/proposalId), the system falls back to the proposer address with zero proving fee. Invalid `proverAuthBytes` does NOT trigger a default manifest

##### 2. Bond Sufficiency Assessment

The system evaluates bond adequacy through multiple checks:

- **Proposer Bond Check**: Verifies if the proposer maintains sufficient L2 bonds to cover the proving fee
- **Low-Bond Detection**: Sets `metadata.isLowBondProposal = true` when:
  - The proposer's bond balance falls below the protocol threshold
  - The proposer is in the process of exiting the system
- **Designated Prover Bond Check**: If a different prover is designated, verifies they have sufficient bonds

##### 3. Prover Assignment Logic

The final prover assignment follows a hierarchical fallback mechanism:

```solidity
if (isLowBondProposal) {
    // Inherit the parent block's designated prover
    designatedProver = parent.metadata.designatedProver;
} else if (designatedProver != proposer && !hasSufficientBond(designatedProver)) {
    // Fallback to proposer if designated prover lacks bonds
    designatedProver = proposer;
} else {
    // Use the authenticated prover
    designatedProver = authenticatedProver;
}
```

The assigned prover is stored in contract state and emitted via `ProverDesignated` event.

#### Low-Bond Proposal Handling

Low-bond proposals present a critical challenge: maintaining chain liveness when proposers lack sufficient bonds. The system implements several mitigation strategies:

##### Immediate Mitigations

- **Default Manifest Replacement**: When `isLowBondProposal = true`, the entire manifest is replaced with the default manifest (containing a single empty block with no transactions), minimizing proving costs and disincentivizing spam
- **Prover Persistence**: The designated prover is never `address(0)`, ensuring someone is always responsible
- **Inheritance Mechanism**: Low-bond proposals inherit their parent's designated prover, maintaining continuity

##### Economic Incentives and Penalties

- **Unpaid Proving**: The inherited prover must prove low-bond proposals without earning fees
- **Liveness Bonds**: Failure to prove results in liveness bond penalties
- **Penalty Redistribution**: Forfeited bonds can incentivize other provers to step in

##### System Implications

The current design creates an asymmetric burden where the last legitimate designated prover may need to prove multiple low-bond proposals without compensation. This ensures chain liveness but raises fairness concerns during sustained attacks.

#### Future Improvements

Several enhancements are under consideration to address current limitations:

- **Prover Rotation**: Distribute low-bond proving responsibility across multiple provers using round-robin or stake-weighted selection
- **Reward Pool**: Establish a dedicated fund for compensating low-bond proposal proving
- **Dynamic Thresholds**: Adjust bond requirements based on network conditions and attack patterns
- **Alternative Finality**: Explore mechanisms that ensure chain progress without overburdening individual provers

### Additional Metadata Fields

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

Metadata encoding into L2 block header fields facilitates efficient peer validation:

| Metadata Component   | Type    | Header Field                              |
| -------------------- | ------- | ----------------------------------------- |
| `number`             | uint256 | `number`                                  |
| `timestamp`          | uint256 | `timestamp`                               |
| `difficulty`         | uint256 | `difficulty`                              |
| `gasLimit`           | uint256 | `gasLimit`                                |
| `basefeeSharingPctg` | uint8   | First byte in `extraData`                 |
| `isLowBondProposal`  | bool    | Lowest bit in the 2nd byte in `extraData` |

#### Additional Pre-Execution Block Header Fields

The following block header fields are also set before transaction execution but are not derived from metadata:

| Header Field | Value                                                                                           |
| ------------ | ----------------------------------------------------------------------------------------------- |
| `parentHash` | Hash of the previous L2 block                                                                   |
| `mixHash`    | Set to `prevRandao` as per EIP-4399                                                             |
| `baseFee`    | Calculated using EIP-4396 from parent and current block timestamps before transaction execution |

Note: Fields like `stateRoot`, `transactionsRoot`, `receiptsRoot`, `logsBloom`, and `gasUsed` are populated after transaction execution.

### Anchor Transaction

The anchor transaction serves as a privileged system transaction responsible for L1 state synchronization and bond instruction processing. It invokes the `updateState` function on the ShastaAnchor contract with precisely defined parameters:

| Parameter            | Type              | Description                                              |
| -------------------- | ----------------- | -------------------------------------------------------- |
| proposalId           | uint48            | Unique identifier of the proposal being anchored         |
| proposer             | address           | Address of the entity that proposed this batch of blocks |
| proverAuth           | bytes             | Encoded ProverAuth for prover designation                |
| bondInstructionsHash | bytes32           | Expected cumulative hash after processing instructions   |
| bondInstructions     | BondInstruction[] | Bond credit/debit instructions to process for this block |
| blockIndex           | uint16            | Current block index within the proposal (0-based)        |
| anchorBlockNumber    | uint48            | L1 block number to anchor (0 to skip anchoring)          |
| anchorBlockHash      | bytes32           | L1 block hash at anchorBlockNumber                       |
| anchorStateRoot      | bytes32           | L1 state root at anchorBlockNumber                       |

The function returns:

- `isLowBondProposal` (bool): True if proposer has insufficient bonds
- `designatedProver` (address): Address of the designated prover

#### Transaction Execution Flow

The anchor transaction executes a carefully orchestrated sequence of operations:

1. **Fork validation and duplicate prevention**

   - Verifies the current block number is at or after the Shasta fork height
   - Tracks parent block hash to prevent duplicate `updateState` calls within the same block

2. **Proposal initialization** (blockIndex == 0 only)

   - Designates the prover for the proposal
   - Sets `isLowBondProposal` flag based on bond sufficiency
   - Stores designated prover and low-bond status in contract state
   - Emits `ProverDesignated` event

3. **L1 state anchoring and bond processing** (when anchorBlockNumber > previous anchorBlockNumber)
   - Persists L1 block data via `checkpointManager.saveCheckpoint`
   - Processes bond instructions (NONE, LIVENESS, and PROVABILITY types) where NONE results in no transfer
   - Maintains cumulative hash integrity by chaining: `keccak256(previousHash, instruction)` (skips if proposalId=0 or bondType=NONE)
   - Updates anchor state atomically (bondInstructionsHash and anchorBlockNumber)

**Execution constraints**:

- Gas limit: Exactly 1,000,000 gas (enforced by the Taiko node software)
- Caller restriction: Golden touch address (system account) only

### Transaction Execution

## Base Fee Calculation

The calculation of block base fee shall follow [EIP-4396](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-4396.md#specification).
