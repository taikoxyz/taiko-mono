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

| **Metadata Component** | **Description**                                                         |
| ---------------------- | ----------------------------------------------------------------------- |
| **id**                 | A unique, sequential identifier for the proposal                        |
| **proposer**           | The address that proposed the proposal                                  |
| **timestamp**          | The timestamp when the proposal was accepted on L1                      |
| **originBlockNumber**  | The L1 block number from **one block before** the proposal was accepted |
| **originBlockHash**    | The hash of `originBlockNumber` block                                   |
| **gasUsed**            | L1 gas used by the proposal transaction                                 |
| **numBlobs**           | Number of blobs attached to the proposal transaction                    |
| **basefee**            | L1 basefee (EIP-1559) at proposal inclusion                             |
| **blobBasefee**        | L1 blob basefee (EIP-4844) at proposal inclusion                        |

The `gasUsed`, `numBlobs`, `basefee`, and `blobBasefee` fields are used by the L2 fee vault for
proposal cost accounting; they do not affect block derivation.

`gasUsed` is computed in-contract as intrinsic gas plus calldata cost and execution up to the
recording point, plus fixed estimates for storing the proposal hash in the ring buffer and
emitting the `Proposed` event log; it excludes any L1 priority fee and later bookkeeping costs.
These values are grouped in the `ProposalCost` sub-struct of the proposal.

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

The metadata preparation process initiates with a subscription to the inbox's `Proposed` event (see
[`IInbox.Proposed`](../contracts/layer1/core/iface/IInbox.sol#L193-L207)).

The other fields can be derived by querying the L1 and the inbox contract:

- `timestamp` comes from the L1 block that emitted the log; `originBlockHash/Number` come from its parent block (event block - 1).
- `parentProposalHash` comes from `Inbox.getProposalHash(id - 1)`.

The following metadata fields are extracted directly from the event payload:

**Proposal-level assignments:**

| Metadata Field         | Value Assignment           |
| ---------------------- | -------------------------- |
| `metadata.id`          | `payload.id`               |
| `metadata.proposer`    | `payload.proposer`         |
| `metadata.gasUsed`     | `payload.cost.gasUsed`     |
| `metadata.numBlobs`    | `payload.cost.numBlobs`    |
| `metadata.basefee`     | `payload.cost.basefee`     |
| `metadata.blobBasefee` | `payload.cost.blobBasefee` |

**Derivation source-level assignments (for source `i`):**

| Metadata Field               | Value Assignment                       |
| ---------------------------- | -------------------------------------- |
| `metadata.isForcedInclusion` | `payload.sources[i].isForcedInclusion` |

The `sources` array in the `Proposed` event (`payload.sources`) contains `DerivationSource` objects (see
[`IInbox.DerivationSource`](../contracts/layer1/core/iface/IInbox.sol#L47-L53)). Each source includes a `blobSlice` field that serves as the primary mechanism for locating and validating proposal metadata. Responsibilities are split as follows:

- **Forced inclusion submitters** publish blob data for a `DerivationSourceManifest` and call `Inbox.saveForcedInclusion(blobReference)`; the inbox stores the resulting `blobSlice` in a queue.
- **The proposer** publishes blob data for their own `DerivationSourceManifest` and calls `Inbox.propose(...)` with a `blobReference` to it plus `numForcedInclusions`. The inbox dequeues that many forced inclusions and appends the proposer's source **last**.

The manifest data structures are defined as follows:

```solidity
/// @notice Represents a proposal manifest containing proposal-level metadata and all sources
/// @dev The ProposalManifest aggregates all DerivationSources' blob data for a proposal.
/// The ProposalManifest is conceptual and used at derivation time only (i.e. it is not posted in blobs).
struct ProposalManifest {
  /// @notice Array of derivation source manifests (one per derivation source).
  DerivationSourceManifest[] sources;
}

/// @notice Represents a derivation source manifest containing blocks for one source
/// @dev Each proposal can have multiple DerivationSourceManifests (one per DerivationSource).
struct DerivationSourceManifest {
  /// @notice The blocks for this derivation source.
  BlockManifest[] blocks;
}

/// @notice Represents a block manifest
struct BlockManifest {
  /// @notice The timestamp of the block.
  uint48 timestamp;
  /// @notice The coinbase of the block.
  address coinbase;
  /// @notice The anchor block number. If set to zero, it will use the parent's anchor.
  uint48 anchorBlockNumber;
  /// @notice The block's gas limit.
  uint48 gasLimit;
  /// @notice The transactions for this block.
  SignedTransaction[] transactions;
}

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
```

### Proposer Bond Validation

The proposer must maintain at least the minimum bond on L1 in the `Inbox` contract. This minimum bond should be enough to cover the range of proposals from the proposer during a given period, ensuring enough bond is at stake.
Proposals from accounts below the minimum (or that have requested withdrawal) are rejected by the contract. Bonds remain optimistic: proposing only checks balances and does not debit them. Balances only change when slashing occurs.

### Manifest Extraction

The `BlobSlice` struct is defined in [`LibBlobs.BlobSlice`](../contracts/layer1/core/libs/LibBlobs.sol#L19-L28).

The `BlobSlice` struct represents binary data distributed across multiple blobs. `DerivationSource` entries are processed sequentially—forced inclusions first, followed by the proposer’s source—to reassemble the final manifest and cross-check data integrity.

#### Per-Source Manifest Extraction

For each `DerivationSource[i]`, the validator performs:

1. **Blob Validation**: Verify `blobSlice.blobHashes.length > 0`
   - Let `BLOB_BYTES = 4096 * 32 = 131072` (bytes per blob as defined by EIP-4844)
2. **Offset Validation**: Verify `blobSlice.offset <= BLOB_BYTES * blobSlice.blobHashes.length - 64`
3. **Version Extraction**: Extract version from bytes `[offset, offset+32)` and verify it equals `0x1`
4. **Size Extraction**: Extract data size from bytes `[offset+32, offset+64)`
5. **Decompression**: Apply ZLIB decompression to bytes `[offset+64, offset+64+size)`
6. **Decoding**: RLP decode the decompressed data
7. **Block Count Validation**: Verify `manifest.blocks.length <= PROPOSAL_MAX_BLOCKS`
8. **Forced Inclusion Block Count Enforcement**: If `derivation.sources[i].isForcedInclusion` is true and `manifest.blocks.length != 1`, replace the entire source with the default manifest

If any validation step fails for source `i`, that source is replaced with a **default source manifest** (single block with only an anchor transaction). Other sources are unaffected.

#### Default Source Manifest

A default source manifest is used when validation fails for a specific source:

```solidity
DerivationSourceManifest memory defaultSource;
defaultSource.blocks = new BlockManifest[](1);  // Single block
```

| Field               | Value                                                                                                                                     |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `timestamp`         | Protocol applies the timestamp validation lower bound afterward (see [`timestamp` validation](#timestamp-validation) for the exact rule). |
| `coinbase`          | Protocol substitutes `proposal.proposer`                                                                                                  |
| `anchorBlockNumber` | Protocol inherits from the parent block                                                                                                   |
| `gasLimit`          | Protocol inherits from the parent block                                                                                                   |
| `transactions`      | Empty list (only includes the anchor transaction)                                                                                         |

#### ProposalManifest Construction

After processing all sources, the `ProposalManifest` is constructed:

```solidity
ProposalManifest memory manifest;
manifest.sources = [sourceManifest0, sourceManifest1, ...];  // With defaults for failed sources
```

**Censorship Resistance**: This per-source validation design prevents a malicious proposer from invalidating valid forced inclusions by including invalid data in other sources. Each source is isolated: failures only affect that specific source, not the entire proposal.

#### Forced Inclusion Submission Requirements

Users submit forced inclusion transactions directly to L1 by posting blob data containing a `DerivationSourceManifest` struct. To ensure valid forced inclusions that pass validation, the following `BlockManifest` rules are applied:

| Field               | Value                                                                                                                                               |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `timestamp`         | Ignored; metadata application overwrites it with the computed lower bound (see [`timestamp` validation](#timestamp-validation) for the exact rule). |
| `coinbase`          | Protocol substitutes `proposal.proposer`                                                                                                            |
| `anchorBlockNumber` | Protocol inherits from the parent block                                                                                                             |
| `gasLimit`          | Protocol inherits from the parent block                                                                                                             |
| `transactions`      | User-provided list of L2 transactions to force-include                                                                                              |

This design ensures forced inclusions integrate properly with the chain's metadata while allowing users to specify only their transactions without requiring knowledge of chain state parameters.

Any non-zero `gasLimit`, `coinbase`, `anchorBlockNumber`, or `timestamp` is overwritten during metadata application with inherited proposer/parent values, keeping the source valid and avoiding a fallback to the default manifest.

### Metadata Validation and Computation

With the extracted `ProposalManifest`, metadata computation proceeds using both the proposal manifest data and the parent block's metadata (`parent.metadata`). Each `DerivationSourceManifest` within the `ProposalManifest.sources[]` array is processed sequentially, with validation applied to each source's blocks. The following sections detail the validation rules for each metadata component:

#### `timestamp` Validation

Timestamp validation is performed collectively across all blocks:

1. **Upper bound**: `proposal.timestamp`
2. **Lower bound**: `lowerBound = max(parent.metadata.timestamp + 1, proposal.timestamp - TIMESTAMP_MAX_OFFSET, SHASTA_FORK_TIME)`
3. **Out-of-bounds handling**: If any block's `manifest.blocks[i].timestamp` is outside `[lowerBound, proposal.timestamp]`, the entire derivation source is replaced with the default source manifest.

#### `anchorBlockNumber` Validation

Anchor block validation ensures proper L1 state synchronization and may trigger manifest replacement:

**Invalidation conditions** (replace the derivation source with the default source manifest):

- **Non-monotonic progression**: `manifest.blocks[i].anchorBlockNumber < parent.metadata.anchorBlockNumber`
- **Future reference**: `manifest.blocks[i].anchorBlockNumber > proposal.originBlockNumber`
- **Excessive lag**: `manifest.blocks[i].anchorBlockNumber < proposal.originBlockNumber - MAX_ANCHOR_OFFSET`

**Forced inclusion protection**: Only proposer-supplied sources are penalized for stagnant anchors. Forced inclusions (`derivationSource.isForcedInclusion == false`) blocks intentionally inherit the parent anchor as mentioned above and never get replaced with the default manifest even when the anchor number does not advance.

#### `anchorBlockHash` and `anchorStateRoot` Validation

The anchor hash and state root must always correspond to the actual L1 block referenced by `anchorBlockNumber`. The Taiko node/driver enforces that both `anchorBlockHash` and `anchorStateRoot` accurately reflect the L1 state for that block.

#### `coinbase` Assignment

The L2 coinbase address determination follows a hierarchical priority system:

1. **Forced inclusions**: Always use `proposal.proposer`
2. **Regular proposals**: Use `orderedBlocks[i].coinbase`

#### `gasLimit` Validation

Gas limit adjustments are constrained by `BLOCK_GAS_LIMIT_MAX_CHANGE` parts per million (units of 1/1,000,000) per block to ensure economic stability. With the default value of 10, this allows ±10 millionths (±0.001%) change per block. Additionally, block gas limit must never fall below `MIN_BLOCK_GAS_LIMIT`:

**Validation process**:

1. **Define bounds**:

   - `upperBound = min(parent.metadata.gasLimit * (1_000_000 + BLOCK_GAS_LIMIT_MAX_CHANGE) / 1_000_000, MAX_BLOCK_GAS_LIMIT)`
   - `lowerBound = min(max(parent.metadata.gasLimit * (1_000_000 - BLOCK_GAS_LIMIT_MAX_CHANGE) / 1_000_000, MIN_BLOCK_GAS_LIMIT), upperBound)`

2. **Source validation**:
   - If `manifest.blocks[i].gasLimit` falls outside `[lowerBound, upperBound]`: Replace the entire derivation source with the default source manifest.

After all calculations above, an additional `1_000_000` gas units will be added to the final gas limit value, reserving headroom for the mandatory `Anchor.anchorV4` transaction.

#### Bond instruction processing

Late-proof handling on L1 may trigger at most one liveness-bond settlement for the first proven proposal. The Inbox applies the settlement inside `prove` on L1 (best-effort), crediting 50% of the debited bond to the actual prover and burning the remainder.

### Additional Metadata Fields

The remaining metadata fields follow straightforward assignment patterns:

**Block-level assignments:**

| Metadata Field          | Value Assignment                                                  |
| ----------------------- | ----------------------------------------------------------------- |
| `metadata.index`        | `parent.metadata.index + 1` (abbreviated as `i`)                  |
| `metadata.number`       | `parent.metadata.number + 1`                                      |
| `metadata.difficulty`   | `keccak(abi.encode(parent.metadata.difficulty, metadata.number))` |
| `metadata.transactions` | `sourceManifest.blocks[i].transactions` (from current source)     |

**Derivation source-level assignments:**

| Metadata Field       | Value Assignment                                                                  |
| -------------------- | --------------------------------------------------------------------------------- |
| `metadata.numBlocks` | Total blocks from current source `sourceManifest.blocks.length` (post-validation) |

**Important**: The `numBlocks` field must be assigned only after timestamp and anchor block validation completes, as these validations may reduce the effective block count within that source.

## Metadata Application

The validated metadata serves three critical functions in block construction:

1. **Pre-execution block header field determination**
2. **L2 anchor transaction construction**
3. **L2 world state modification**

### Pre-Execution Block Header

Metadata encoding into L2 block header fields facilitates efficient peer validation:

| Metadata Component | Type    | Header Field                          |
| ------------------ | ------- | ------------------------------------- |
| `number`           | uint256 | `number`                              |
| `timestamp`        | uint256 | `timestamp`                           |
| `difficulty`       | uint256 | `difficulty`                          |
| `gasLimit`         | uint256 | `gasLimit`                            |
| `reserved`         | uint8   | First byte in `extraData` (must be 0) |
| `proposalId`       | uint48  | Bytes 1..6 in `extraData`             |

#### Additional Pre-Execution Block Header Fields

The following block header fields are also set before transaction execution but are not derived from metadata:

| Header Field | Value                                                                                           |
| ------------ | ----------------------------------------------------------------------------------------------- |
| `parentHash` | Hash of the previous L2 block                                                                   |
| `mixHash`    | Set to `prevRandao` as per EIP-4399                                                             |
| `baseFee`    | Calculated using EIP-4396 from parent and current block timestamps before transaction execution |

Note: Fields like `stateRoot`, `transactionsRoot`, `receiptsRoot`, `logsBloom`, and `gasUsed` are populated after transaction execution.

### Anchor Transaction

The anchor transaction serves as a privileged system transaction responsible for L1 state synchronization
and fee-vault imports. It invokes the `anchorV4` function on the ShastaAnchor contract with proposal-level
and block-level parameters.

**ProposalParams:**

| Parameter           | Type            | Description                                                                |
| ------------------- | --------------- | -------------------------------------------------------------------------- |
| proposalId          | uint48          | L1 proposal id for the current L2 block                                    |
| submissionWindowEnd | uint48          | End of the preconfirmation submission window                               |
| feeData             | ProposalFeeData | Canonical fee data to import into the L2 fee vault (proposalId == 0 skips) |

`ProposalFeeData` fields:

| Field            | Type    | Description                                              |
| ---------------- | ------- | -------------------------------------------------------- |
| proposalId       | uint48  | Proposal id (must be strictly sequential across imports) |
| proposer         | address | L1 proposer address                                      |
| l1GasUsed        | uint64  | Gas used by the L1 proposal transaction                  |
| numBlobs         | uint32  | Number of blobs attached to the proposal transaction     |
| l1Basefee        | uint128 | L1 basefee at proposal inclusion                         |
| l1BlobBasefee    | uint128 | L1 blob basefee at proposal inclusion                    |
| l2BasefeeRevenue | uint256 | Sum of L2 basefee revenue for blocks in this proposal    |

The validity proof must verify that `feeData` corresponds to canonical L1 Inbox state and L2 execution.
In particular, it should recompute `hashProposal(proposal)` from the full proposal data (including
cost fields) and verify it matches the proposal hash stored in the ring buffer for that `proposalId`,
using the appropriate L1 state root. It must also verify that `l2BasefeeRevenue` is correctly computed
from the L2 blocks in that proposal (excluding system transactions as specified by the protocol).

Fee data is provided once per proposal (typically on the first L2 block of that proposal). The
anchor tracks the last imported proposal id and only imports when `proposalId` increments; for other
blocks in the same proposal, `feeData.proposalId` is set to 0.

**BlockParams:**

| Parameter         | Type    | Description                                     |
| ----------------- | ------- | ----------------------------------------------- |
| anchorBlockNumber | uint48  | L1 block number to anchor (0 to skip anchoring) |
| anchorBlockHash   | bytes32 | L1 block hash at anchorBlockNumber              |
| anchorStateRoot   | bytes32 | L1 state root at anchorBlockNumber              |

#### Transaction Execution Flow

The anchor transaction executes a carefully orchestrated sequence of operations:

1. **Fork validation and duplicate prevention**

   - Verifies the current block number is at or after the Shasta fork height
   - Tracks parent block hash to prevent duplicate `anchorV4` calls within the same block

2. **L1 state anchoring** (when anchorBlockNumber > previous anchorBlockNumber)
   - Persists L1 block data via `checkpointStore.saveCheckpoint`
   - Updates anchor state atomically with the latest anchor block metadata

**Execution constraints**:

- Gas limit: Exactly 1,000,000 gas (enforced by the Taiko node software)
- Caller restriction: Golden touch address (system account) only

## Base Fee Calculation

The calculation of block base fee shall follow [EIP-4396](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-4396.md#specification).

The consensus engine pins the base fee at `INITIAL_BASE_FEE` for the very first block when the Shasta fork starts from genesis, because the parent block time (`parent.timestamp - parent.parent.timestamp`) needed for calculation is unavailable. If the fork activates later or once the block height exceeds `1`, base fee computation should follow [EIP-4396](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-4396.md#specification), and the calculated value must be clamped within `MIN_BASE_FEE` and `MAX_BASE_FEE`.

## Constants

The following constants govern the block derivation process:

| Constant                       | Value                         | Description                                                                                                                                                                |
| ------------------------------ | ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **PROPOSAL_MAX_BLOCKS**        | `384`                         | The maximum number of blocks allowed in a proposal. If we assume block time is as small as one second, 384 blocks will cover an Ethereum epoch.                            |
| **MAX_ANCHOR_OFFSET**          | `128`                         | The maximum anchor block number offset from the proposal origin block number.                                                                                              |
| **TIMESTAMP_MAX_OFFSET**       | `1536` (12 \* 128)            | The maximum number timestamp offset from the proposal origin timestamp. This is set to longer than an epoch to allow the next proposer to recover without causing a reorg. |
| **BLOCK_GAS_LIMIT_MAX_CHANGE** | `10`                          | The maximum block gas limit change per block, in millionths (1/1,000,000). For example, 10 = 10 / 1,000,000 = 0.001%.                                                      |
| **MIN_BLOCK_GAS_LIMIT**        | `10,000,000`                  | The minimum block gas limit. This ensures block gas limit never drops below a critical threshold.                                                                          |
| **MAX_BLOCK_GAS_LIMIT**        | `45,000,000`                  | The maximum block gas limit. This ensures block gas limit never goes above a critical threshold.                                                                           |
| **INITIAL_BASE_FEE**           | `0.025 gwei` (25,000,000 wei) | The initial base fee for the first Shasta block when the Shasta fork activated from genesis.                                                                               |
| **MIN_BASE_FEE**               | `0.005 gwei` (5,000,000 wei)  | The minimum base fee (inclusive) after Shasta fork.                                                                                                                        |
| **MAX_BASE_FEE**               | `1 gwei` (1,000,000,000 wei)  | The maximum base fee (inclusive) after Shasta fork.                                                                                                                        |
| **BLOCK_TIME_TARGET**          | `2 seconds`                   | The block time target.                                                                                                                                                     |
| **SHASTA_FORK_TIME**           | Hoodi/Mainnet: not scheduled  | The timestamp that determines when the fork should occur.                                                                                                                  |
