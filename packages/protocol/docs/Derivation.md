# Block Derivation in Taiko

This document provides a comprehensive specification for deriving blocks from on-chain proposals in Taiko's Shasta fork.

## Terminology

The Shasta fork introduces refined terminology to better reflect the system's architecture:

- **Proposal**: Replaces the term _Batch_ to denote the unit of on-chain submission for block construction data
- **Finalization**: Replaces _Verification_ to describe the state where a proposal's post-state is confirmed as final

## Metadata Architecture

Block construction requires a comprehensive collection of metadata, organized into three distinct categories:

- **Proposal-level metadata**: Shared across all blocks and sources within a proposal
- **Derivation source-level metadata**: Specific to each derivation source within a proposal
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
| **basefeeSharingPctg**   | The percentage of base fee paid to coinbase                   |
| **bondInstructionsHash** | Expected cumulative hash after processing bond instructions   |
| **bondInstructions**     | Array of bond credit/debit instructions to be performed on L2 |

### Derivation Source-level Metadata

| **Metadata Component** | **Description**                                    |
| ---------------------- | -------------------------------------------------- |
| **isForcedInclusion**  | Flags whether this source is from forced inclusion |
| **numBlocks**          | The number of blocks in this derivation source     |

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

The following metadata fields are extracted from the `proposal`, `derivation`, and `derivation.sources[i]` objects:

**Proposal-level assignments:**

| Metadata Field                | Value Assignment                |
| ----------------------------- | ------------------------------- |
| `metadata.id`                 | `proposal.id`                   |
| `metadata.proposer`           | `proposal.proposer`             |
| `metadata.timestamp`          | `proposal.timestamp`            |
| `metadata.originBlockNumber`  | `derivation.originBlockNumber`  |
| `metadata.basefeeSharingPctg` | `derivation.basefeeSharingPctg` |

**Derivation source-level assignments (for source `i`):**

| Metadata Field               | Value Assignment                          |
| ---------------------------- | ----------------------------------------- |
| `metadata.isForcedInclusion` | `derivation.sources[i].isForcedInclusion` |

The `derivation.sources` array contains `DerivationSource` objects, each with a `blobSlice` field that serves as the primary mechanism for locating and validating proposal metadata. Responsibilities are split as follows:

- **Forced inclusion submitters** publish their `DerivationSourceManifest` blob on L1 directly as blobs.
- **The proposer** gathers every required derivation source—both their own blocks and any outstanding forced inclusions—and publishes a single `ProposalManifest` within their own `DerivationSource` (**appended last**). The inbox contract guarantees that forced inclusions are proposed as they were posted(without metadata being maniupalted).

The manifest data structures are defined as follows:

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

/// @notice Represents a proposal manifest containing proposal-level metadata and all sources
/// @dev The ProposalManifest aggregates all DerivationSources' blob data for a proposal.
struct ProposalManifest {
  /// @notice Prover authentication data (proposal-level).
  bytes proverAuthBytes;
  /// @notice Array of derivation source manifests (one per derivation source).
  DerivationSourceManifest[] sources;
}

/// @notice Represents a derivation source manifest containing blocks for one source
/// @dev Each proposal can have multiple DerivationSourceManifests (one per DerivationSource).
struct DerivationSourceManifest {
  /// @notice The blocks for this derivation source.
  BlockManifest[] blocks;
}
```

### Proposer and `isLowBondProposal` Validation

To maintain the integrity of the proposal process, the `proposer` address must pass specific validation checks, which include:

- Confirming that the proposer holds a sufficient balance in the L2 BondManager contract.
- Ensuring the proposer is not waiting for exiting.

Should any of these validation checks fail (as determined by the `anchorV4` function returning `isLowBondProposal = true`), the proposer's derivation source is replaced with the default manifest, which contains a single block with only an anchor transaction.

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

The `BlobSlice` struct represents binary data distributed across multiple blobs. `DerivationSource` entries are processed sequentially—forced inclusions first, followed by the proposer’s source—to reassemble the final manifest and cross-check data integrity.

#### Per-Source Manifest Extraction

For each `DerivationSource[i]`, the validator performs:

1. **Blob Validation**: Verify `blobSlice.blobHashes.length > 0`
2. **Offset Validation**: Verify `blobSlice.offset <= BLOB_BYTES * blobSlice.blobHashes.length - 64`
3. **Version Extraction**: Extract version from bytes `[offset, offset+32)` and verify it equals `0x1`
4. **Size Extraction**: Extract data size from bytes `[offset+32, offset+64)`
5. **Decompression**: Apply ZLIB decompression to bytes `[offset+64, offset+64+size)`
6. **Decoding**: RLP decode the decompressed data
7. **Block Count Validation**: Verify `manifest.blocks.length <= PROPOSAL_MAX_BLOCKS`

If any validation step fails for source `i`, that source is replaced with a **default source manifest** (single block with only an anchor transaction). Other sources are unaffected.

#### Default Source Manifest

A default source manifest is used when validation fails for a specific source:

```solidity
DerivationSourceManifest memory defaultSource;
defaultSource.blocks = new BlockManifest[](1);  // // Single block
```

#### ProposalManifest Construction

After processing all sources, the `ProposalManifest` is constructed:

```solidity
ProposalManifest memory manifest;
manifest.proverAuthBytes = proverAuthBytesFromProposerSource;
manifest.sources = [sourceManifest0, sourceManifest1, ...];  // With defaults for failed sources
```

**Censorship Resistance**: This per-source validation design prevents a malicious proposer from invalidating valid forced inclusions by including invalid data in other sources. Each source is isolated: failures only affect that specific source, not the entire proposal.

#### Forced Inclusion Submission Requirements

Users submit forced inclusion transactions directly to L1 by posting blob data containing a `DerivationSourceManifest` struct. To ensure valid forced inclusions that pass validation, the following `BlockManifest` fields must be set to zero, allowing the protocol to assign appropriate values:

| Field               | Required Value | Reason                                                  |
| ------------------- | -------------- | ------------------------------------------------------- |
| `timestamp`         | `0`            | Protocol assigns based on proposal timing               |
| `coinbase`          | `address(0)`   | Protocol uses `proposal.proposer` for forced inclusions |
| `anchorBlockNumber` | `0`            | Protocol inherits from parent block                     |
| `gasLimit`          | `0`            | Protocol inherits from parent block                     |
| `transactions`      | User-provided  | The actual transactions to be forcibly included         |

This design ensures forced inclusions integrate properly with the chain's metadata while allowing users to specify only their transactions without requiring knowledge of chain state parameters.

If any of `gasLimit`, `coinbase`, `anchorBlockNumber`, or `timestamp` is non-zero, the decoder overwrites that field with zero so the derivation source remains valid rather than being downgraded to the default manifest.

### Metadata Validation and Computation

With the extracted `ProposalManifest`, metadata computation proceeds using both the proposal manifest data and the parent block's metadata (`parent.metadata`). Each `DerivationSourceManifest` within the `ProposalManifest.sources[]` array is processed sequentially, with validation applied to each source's blocks. The following sections detail the validation rules for each metadata component:

#### `timestamp` Validation

Timestamp validation is performed collectively across all blocks and may result in block count reduction:

1. **Upper bound enforcement**: If `metadata.timestamp > proposal.timestamp`, set `metadata.timestamp = proposal.timestamp`
2. **Lower bound calculation**: `lowerBound = max(parent.metadata.timestamp + 1, proposal.timestamp - TIMESTAMP_MAX_OFFSET)`
3. **Lower bound enforcement**: If `metadata.timestamp < lowerBound`, set `metadata.timestamp = lowerBound`

#### `anchorBlockNumber` Validation

Anchor block validation ensures proper L1 state synchronization and may trigger manifest replacement:

**Invalidation conditions** (sets `anchorBlockNumber` to `parent.metadata.anchorBlockNumber`):

- **Non-monotonic progression**: `manifest.blocks[i].anchorBlockNumber < parent.metadata.anchorBlockNumber`
- **Future reference**: `manifest.blocks[i].anchorBlockNumber >= proposal.originBlockNumber - MIN_ANCHOR_OFFSET`
- **Excessive lag**: `manifest.blocks[i].anchorBlockNumber < proposal.originBlockNumber - MAX_ANCHOR_OFFSET`

**Forced inclusion protection**: For non-forced derivation sources (`derivationSource.isForcedInclusion == false`), if no blocks have valid anchor numbers greater than its parent's, the entire source manifest is replaced with the default source manifest (single block with only an anchor transaction), penalizing proposers that fail to provide proper L1 anchoring. Forced inclusion sources are exempt from this penalty.

#### `anchorBlockHash` and `anchorStateRoot` Validation

The anchor hash and state root must maintain consistency with the anchor block number (enforced by the Taiko node/driver):

- If `anchorBlockNumber == parent.metadata.anchorBlockNumber`: Both `anchorBlockHash` and `anchorStateRoot` must be zero
- Otherwise: Both fields must accurately reflect the L1 block state at the specified `anchorBlockNumber`

#### `coinbase` Assignment

The L2 coinbase address determination follows a hierarchical priority system:

1. **Forced inclusions**: Always use `proposal.proposer`
2. **Regular proposals**: Use `orderedBlocks[i].coinbase` if non-zero
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

After all calculations above, an additional `1_000_000` gas units will be added to the final gas limit value, reserving headroom for the mandatory `Anchor.anchorV4` transaction.

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

The designated prover system ensures every L2 block has a responsible prover, maintaining chain liveness even during adversarial conditions. The system operates through the `anchorV4` function in ShastaAnchor, which manages prover designation on the first block of each proposal (`blockIndex == 0`).

The `ProverAuth` structure used in Shasta for prover authentication:

```solidity
/// @notice Structure for prover authentication
/// @dev Used in the proverAuthBytes field of ProposalManifest (proposal-level)
struct ProverAuth {
  uint48 proposalId;
  address proposer;
  uint256 provingFee; // denominated in Wei
  bytes signature;
}
```

#### Prover Designation Process

**Proposal-Level Prover Authentication**: The `proverAuthBytes` field in the `ProposalManifest` is proposal-level data, meaning there is ONE designated prover per proposal (shared across all `DerivationSourceManifest` objects in the `sources[]` array). This field is processed only once during the first block of the proposal (`_blockIndex == 0`) when the `anchorV4` function designates the prover for the entire proposal.

##### 1. Authentication and Validation

The `_validateProverAuth` function processes prover authentication data with the following steps:

- **Signature Verification**:

  - Validates the `ProverAuth` struct from the provided bytes
  - Decodes the `ProverAuth` containing: `proposalId`, `proposer`, `provingFee`, and ECDSA `signature`
  - Verifies the signature against the computed message digest
  - Returns the authenticated prover address and fee information

- **Validation Failures**: If authentication fails (insufficient data length < 225 bytes, ABI decode failure, invalid signature, or mismatched proposal/proposalId), the system falls back to the proposer address with zero proving fee. Invalid `proverAuthBytes` does NOT trigger a default manifest

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

- **Default Manifest Replacement**: When `isLowBondProposal = true`, the **only the proposer's manifest** is replaced with the default manifest, minimizing proving costs and disincentivizing spam. Forced inclusion manifests are still processed.
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

**Block-level assignments:**

| Metadata Field          | Value Assignment                                                  |
| ----------------------- | ----------------------------------------------------------------- |
| `metadata.index`        | `parent.metadata.index + 1` (abbreviated as `i`)                  |
| `metadata.number`       | `parent.metadata.number + 1`                                      |
| `metadata.difficulty`   | `keccak(abi.encode(parent.metadata.difficulty, metadata.number))` |
| `metadata.transactions` | `sourceManifest.blocks[i].transactions` (from current source)     |

**Proposal-level assignments:**

| Metadata Field             | Value Assignment                   |
| -------------------------- | ---------------------------------- |
| `metadata.proverAuthBytes` | `proposalManifest.proverAuthBytes` |

**Derivation source-level assignments:**

| Metadata Field       | Value Assignment                                                                  |
| -------------------- | --------------------------------------------------------------------------------- |
| `metadata.numBlocks` | Total blocks from current source `sourceManifest.blocks.length` (post-validation) |

**Important**: The `numBlocks` field must be assigned only after timestamp and anchor block validation completes, as these validations may reduce the effective block count within that source.

#### Block Index Monotonicity

The `_blockIndex` parameter in the anchor transaction's `anchorV4` function is **globally monotonic** across all `DerivationSourceManifest` objects within **the same proposal**. This means:

- First source's blocks: `_blockIndex = 0, 1, 2, ...`
- Second source's blocks: `_blockIndex` continues from where the first source ended
- Third source's blocks: `_blockIndex` continues sequentially, etc.

**Why this is critical**: The check `if (_blockIndex == 0)` gates proposal-level operations that must execute exactly once per proposal:

1. **Prover designation** - ONE designated prover per proposal
2. **Bond instruction processing** - Bond instructions must be processed exactly once (enforced by hash chain validation)

If `_blockIndex` were to reset per source (e.g., each source starting from 0), these operations would execute multiple times, causing:

- Financial incorrectness (bond instructions processed multiple times)
- Multiple prover designations (violating the one-prover-per-proposal design)
- Hash chain integrity violations

Therefore, `_blockIndex` **must** be globally monotonic across all sources in a proposal. This is not a design choice—it's a correctness requirement.

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

For Shasta specifically, consensus pins the base fee to `25_000_000 wei` for the first three blocks after the fork. EIP-4396 derives the next base fee from the parent block time (`parent.timestamp - parent.parent.timestamp`); when the fork starts from genesis this delta may be enormous. Maintaining a three-block fixed-fee window absorbs that anomaly and prevents an outsized jump—the fourth Shasta block and onward go to the normal EIP-4396 calculation.

### Anchor Transaction

The anchor transaction serves as a privileged system transaction responsible for L1 state synchronization and bond instruction processing. It invokes the `anchorV4` function on the ShastaAnchor contract with precisely defined parameters:

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
   - Tracks parent block hash to prevent duplicate `anchorV4` calls within the same block

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


## Base Fee Calculation

The calculation of block base fee shall follow [EIP-4396](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-4396.md#specification).


## Constants

The following constants govern the block derivation process:

| Constant | Value | Description |
|----------|-------|-------------|
| **PROPOSAL_MAX_BLOCKS** | `384` | The maximum number of blocks allowed in a proposal. If we assume block time is as small as one second, 384 blocks will cover an Ethereum epoch. |
| **MAX_ANCHOR_OFFSET** | `128` | The maximum anchor block number offset from the proposal origin block number. |
| **MIN_ANCHOR_OFFSET** | `2` | The minimum anchor block number offset from the proposal origin block number. |
| **TIMESTAMP_MAX_OFFSET** | `384` (12 * 32) | The maximum number timestamp offset from the proposal origin timestamp. |
| **BLOCK_GAS_LIMIT_MAX_CHANGE** | `10` | The maximum block gas limit change per block, in millionths (1/1,000,000). For example, 10 = 10 / 1,000,000 = 0.001%. |
| **MIN_BLOCK_GAS_LIMIT** | `15,000,000` | The minimum block gas limit. This ensures block gas limit never drops below a critical threshold. |
| **BOND_PROCESSING_DELAY** | `6` | The delay in processing bond instructions relative to the current proposal. A value of 1 signifies that the bond instructions of the immediate parent proposal will be processed. |
| **INITIAL_BASE_FEE** | `0.025 gwei` (25,000,000 wei) | The initial base fee for the first Shasta block. |
| **MIN_BASE_FEE** | `0.005 gwei` (5,000,000 wei) | The minimum base fee (inclusive) after Shasta fork. |
| **MAX_BASE_FEE** | `1 gwei` (1,000,000,000 wei) | The maximum base fee (inclusive) after Shasta fork. |
| **BLOCK_TIME_TARGET** | `2 seconds` | The block time target. |
