# Block Derivation in Taiko

This document provides a comprehensive specification for deriving blocks from on-chain proposals, starting with Taiko's Shasta fork. Later forks change some of these rules, and every such change names the fork that introduces it (see [Forks](#forks)).

## Terminology

The Shasta fork introduces refined terminology to better reflect the system's architecture:

- **Proposal**: Replaces the term _Batch_ to denote the unit of on-chain submission for block construction data
- **Finalization**: Replaces _Verification_ to describe the state where a proposal's post-state is confirmed as final

## Forks

| Fork   | Activation         | Status                      | Changes to derivation                                                                                                                                             |
| ------ | ------------------ | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Shasta | `SHASTA_FORK_TIME` | Active on Hoodi and mainnet | Baseline of this document; the EVM follows Ethereum's Shanghai rules                                                                                              |
| Unzen  | `UNZEN_FORK_TIME`  | Active on Hoodi and mainnet | The EVM follows Ethereum's Osaka rules, and headers gain the Cancun and Prague fields; zk gas metering, recorded in `difficulty`; a larger per-source block limit |
| Etna   | `ETNA_FORK_TIME`   | Not scheduled               | No anchor transaction; the L1 anchor block hash is carried in `parentBeaconBlockRoot` instead (see [Etna](#etna-blocks-without-an-anchor-transaction))            |

Each L2 block follows the rules of the fork that is active at its own timestamp (`metadata.timestamp`). Block timestamps may trail the proposal's L1 timestamp by up to `TIMESTAMP_MAX_OFFSET`, so one proposal can contain blocks of two forks. The per-source block limit is the only rule selected by the proposal's L1 timestamp (`proposal.timestamp`) instead.

The activation times are listed under [Constants](#constants).

## Metadata Architecture

Block construction requires a comprehensive collection of metadata, organized into three distinct categories:

- **Proposal-level metadata**: Shared across all blocks and sources within a proposal
- **Derivation source-level metadata**: Specific to each derivation source within a proposal
- **Block-level metadata**: Unique to each individual block

Throughout this document, metadata references follow the notation `metadata.fieldName`.

### Proposal-level Metadata

| **Metadata Component**             | **Description**                                                                                       |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------- |
| **id**                             | A unique, sequential identifier for the proposal                                                      |
| **proposer**                       | The address that proposed the proposal                                                                |
| **timestamp**                      | The timestamp when the proposal was accepted on L1                                                    |
| **endOfSubmissionWindowTimestamp** | The last slot timestamp where the current preconfer can propose. `0` for whitelisted preconfirmations |
| **parentProposalHash**             | The hash of the parent proposal                                                                       |
| **originBlockNumber**              | The L1 block number from **one block before** the proposal was accepted                               |
| **originBlockHash**                | The hash of `originBlockNumber` block                                                                 |
| **basefeeSharingPctg**             | The percentage of base fee paid to coinbase                                                           |

### Derivation Source-level Metadata

| **Metadata Component** | **Description**                                    |
| ---------------------- | -------------------------------------------------- |
| **isForcedInclusion**  | Flags whether this source is from forced inclusion |
| **numBlocks**          | The number of blocks in this derivation source     |

### Block-level Metadata

| **Metadata Component** | **Description**                                                           |
| ---------------------- | ------------------------------------------------------------------------- |
| **number**             | The block number                                                          |
| **mixHash**            | The block's `prevRandao` value                                            |
| **index**              | The zero-based index of the block within the proposal                     |
| **timestamp**          | The timestamp of the block                                                |
| **coinbase**           | The coinbase address for the block                                        |
| **gasLimit**           | The block's gas limit                                                     |
| **transactions**       | The list of raw transactions included in the block                        |
| **anchorBlockNumber**  | The L1 block number to which this block anchors                           |
| **anchorBlockHash**    | The block hash for the block at anchorBlockNumber                         |
| **anchorStateRoot**    | The state root for the block at anchorBlockNumber (used before Etna only) |

## Metadata Preparation

The metadata preparation process initiates with a subscription to the inbox's `Proposed` event (see
[`IInbox.Proposed`](../contracts/layer1/core/iface/IInbox.sol#L174-L188)).

The other fields can be derived by querying the L1:

- `timestamp` comes from the L1 block that emitted the log; `originBlockHash/Number` come from its parent block (event block - 1).

The following metadata fields are extracted directly from the event payload:

**Proposal-level assignments:**

| Metadata Field                            | Value Assignment                         |
| ----------------------------------------- | ---------------------------------------- |
| `metadata.id`                             | `payload.id`                             |
| `metadata.proposer`                       | `payload.proposer`                       |
| `metadata.parentProposalHash`             | `payload.parentProposalHash`             |
| `metadata.endOfSubmissionWindowTimestamp` | `payload.endOfSubmissionWindowTimestamp` |
| `metadata.basefeeSharingPctg`             | `payload.basefeeSharingPctg`             |

**Derivation source-level assignments (for source `i`):**

| Metadata Field               | Value Assignment                       |
| ---------------------------- | -------------------------------------- |
| `metadata.isForcedInclusion` | `payload.sources[i].isForcedInclusion` |

The `sources` array in the `Proposed` event (`payload.sources`) contains `DerivationSource` objects (see
[`IInbox.DerivationSource`](../contracts/layer1/core/iface/IInbox.sol#L47-L53)). Each source includes a `blobSlice` field that serves as the primary mechanism for locating and validating proposal metadata. Responsibilities are split as follows:

- **Forced inclusion submitters** publish blob data for a `DerivationSourceManifest` and call `Inbox.saveForcedInclusion(blobReference)`; the inbox stores the resulting `blobSlice` in a queue.
- **The proposer** publishes blob data for their own `DerivationSourceManifest` and calls `Inbox.propose(...)` with a `blobReference` to it plus `numForcedInclusions`. The inbox dequeues up to `min(numForcedInclusions, MAX_FORCED_INCLUSIONS_PER_PROPOSAL)` forced inclusions (FIFO, currently 10) and appends the proposer's source **last**. If forced inclusions are due, the proposer must request at least `min(numDue, MAX_FORCED_INCLUSIONS_PER_PROPOSAL)` forced inclusions.

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
2. **Offset Validation**: Verify `blobSlice.offset <= BLOB_BYTES - 64`
3. **Version Extraction**: Extract version from bytes `[offset, offset+32)` and verify it equals `0x1`
4. **Size Extraction**: Extract data size from bytes `[offset+32, offset+64)`
5. **Decompression**: Apply ZLIB decompression to bytes `[offset+64, offset+64+size)`
6. **Decoding**: RLP decode the decompressed data
7. **Block Count Validation**: Verify `manifest.blocks.length` does not exceed the per-source limit selected by the landed L1 block timestamp of the proposal (`proposal.timestamp`):
   - Before `UNZEN_FORK_TIME`: `DERIVATION_SOURCE_MAX_BLOCKS = 192`
   - At/after `UNZEN_FORK_TIME`: `UNZEN_DERIVATION_SOURCE_MAX_BLOCKS = 768`
8. **Forced Inclusion Block Count Enforcement**: If `derivation.sources[i].isForcedInclusion` is true and `manifest.blocks.length != 1`, replace the entire source with the default manifest

If any validation step fails for source `i`, that source is replaced with a **default source manifest** (a single block without manifest transactions). Other sources are unaffected.

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
| `transactions`      | Empty list. Before Etna the block contains only the anchor transaction; from Etna on it contains no transactions.                         |

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

#### Parent Metadata

Within a source, a block's parent is the previous block of the same source, whose metadata has just been computed. The first block of a source has the preceding L2 block as its parent, and that block's metadata is recovered from the block itself:

| Field                               | Value                                                                                                                                                                                                                                                                                        |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `parent.metadata.number`            | The parent header's `number`                                                                                                                                                                                                                                                                 |
| `parent.metadata.timestamp`         | The parent header's `timestamp`                                                                                                                                                                                                                                                              |
| `parent.metadata.gasLimit`          | The parent header's `gasLimit`, minus `ANCHOR_GAS_LIMIT` if the parent is a non-genesis block before Etna                                                                                                                                                                                    |
| `parent.metadata.anchorBlockNumber` | `0` for the genesis block. For a parent before Etna, the anchor block number stored by its anchor transaction (`Anchor.getBlockState().anchorBlockNumber` at the parent block). For a parent at or after Etna, the number of the L1 block whose hash is the parent's `parentBeaconBlockRoot` |

An Etna parent's anchor block is never newer than `proposal.originBlockNumber`. If it is older than `max(0, proposal.originBlockNumber - MAX_ANCHOR_OFFSET)`, every rule that reads `parent.metadata.anchorBlockNumber` has the same outcome whatever its exact value, and a block that inherits the anchor simply copies the parent's `parentBeaconBlockRoot`. An implementation that holds the L1 headers from that block number up to `proposal.originBlockNumber`, linked by parent hash to `proposal.originBlockHash`, can therefore treat a root that matches none of them as older than that range.

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

**Forced inclusion protection**: Only proposer-supplied sources are penalized for stagnant anchors. Forced inclusions (`derivationSource.isForcedInclusion == true`) blocks intentionally inherit the parent anchor as mentioned above and never get replaced with the default manifest even when the anchor number does not advance.

#### `anchorBlockHash` and `anchorStateRoot` Validation

The anchor hash and state root must always correspond to the actual L1 block referenced by the block's final `anchorBlockNumber`. They are not proposer inputs (`BlockManifest` carries only `anchorBlockNumber`): the driver reads both from that L1 block. Provers enforce the correspondence. A new anchor is matched against L1 headers linked by parent hash to `proposal.originBlockHash`. An inherited anchor is matched against the parent block: for a parent before Etna, against the checkpoint stored in the parent's L2 state; for a parent at or after Etna, against the parent's `parentBeaconBlockRoot`.

- Before Etna, both values are arguments of the [anchor transaction](#anchor-transaction).
- From Etna on, `anchorBlockHash` is the header's `parentBeaconBlockRoot`, and `anchorStateRoot` is not used.

#### `coinbase` Assignment

The L2 coinbase address determination follows a hierarchical priority system:

1. **Forced inclusions**: Always use `proposal.proposer`
2. **Regular proposals**: Use `orderedBlocks[i].coinbase`

#### `gasLimit` Validation

Gas limit adjustments are constrained by `BLOCK_GAS_LIMIT_MAX_CHANGE` parts per million (units of 1/1,000,000) per block to ensure economic stability. With the default value of 200, this allows ±200 millionths (±0.02%) change per block. Additionally, block gas limit must never fall below `MIN_BLOCK_GAS_LIMIT`:

**Validation process**:

1. **Define bounds**:

   - `upperBound = min(parent.metadata.gasLimit * (1_000_000 + BLOCK_GAS_LIMIT_MAX_CHANGE) / 1_000_000, MAX_BLOCK_GAS_LIMIT)`
   - `lowerBound = min(max(parent.metadata.gasLimit * (1_000_000 - BLOCK_GAS_LIMIT_MAX_CHANGE) / 1_000_000, MIN_BLOCK_GAS_LIMIT), upperBound)`

2. **Source validation**:
   - If `manifest.blocks[i].gasLimit` falls outside `[lowerBound, upperBound]`: Replace the entire derivation source with the default source manifest.

Before Etna, `ANCHOR_GAS_LIMIT` (`1_000_000`) gas units are added to the final gas limit value, reserving headroom for the mandatory `Anchor.anchorV4` transaction. From Etna on there is no reserve: the header's gas limit is the validated value. `parent.metadata.gasLimit` follows the parent's fork (see [Parent Metadata](#parent-metadata)).

### Additional Metadata Fields

The remaining metadata fields follow straightforward assignment patterns:

**Block-level assignments:**

| Metadata Field          | Value Assignment                                                                                                                                      |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `metadata.index`        | `parent.metadata.index + 1` (abbreviated as `i`)                                                                                                      |
| `metadata.number`       | `parent.metadata.number + 1`                                                                                                                          |
| `metadata.mixHash`      | `keccak256(abi.encode(parent.difficulty, metadata.number))`, both encoded as `uint256`, where `parent.difficulty` is the parent header's `difficulty` |
| `metadata.transactions` | `sourceManifest.blocks[i].transactions` (from current source)                                                                                         |

**Derivation source-level assignments:**

| Metadata Field       | Value Assignment                                                                  |
| -------------------- | --------------------------------------------------------------------------------- |
| `metadata.numBlocks` | Total blocks from current source `sourceManifest.blocks.length` (post-validation) |

**Important**: The `numBlocks` field must be assigned only after timestamp and anchor block validation completes, as these validations may reduce the effective block count within that source.

## Metadata Application

The validated metadata serves three critical functions in block construction:

1. **Pre-execution block header field determination**
2. **L2 anchor transaction construction** (before Etna)
3. **L2 world state modification**: the anchor transaction's writes before Etna, and the EIP-4788 and EIP-2935 pre-execution calls, which run from Unzen on and write state once their contracts are deployed (see [Etna](#etna-blocks-without-an-anchor-transaction))

### Pre-Execution Block Header

Metadata encoding into L2 block header fields facilitates efficient peer validation:

| Metadata Component   | Type    | Header Field                                     |
| -------------------- | ------- | ------------------------------------------------ |
| `number`             | uint256 | `number`                                         |
| `timestamp`          | uint256 | `timestamp`                                      |
| `coinbase`           | address | `coinbase`                                       |
| `mixHash`            | bytes32 | `mixHash` (`prevRandao`, see EIP-4399)           |
| `gasLimit`           | uint256 | `gasLimit`, plus `ANCHOR_GAS_LIMIT` before Etna  |
| `anchorBlockHash`    | bytes32 | `parentBeaconBlockRoot` from Etna on (see below) |
| `basefeeSharingPctg` | uint8   | First byte in `extraData`                        |
| `proposalId`         | uint48  | Bytes 1..6 in `extraData` (big-endian)           |

#### Additional Pre-Execution Block Header Fields

The following block header fields are also set before transaction execution but are not derived from metadata:

| Header Field      | Value                                                                                                                 |
| ----------------- | --------------------------------------------------------------------------------------------------------------------- |
| `parentHash`      | Hash of the previous L2 block                                                                                         |
| `baseFee`         | Calculated using EIP-4396 from the parent and grandparent headers (see [Base Fee Calculation](#base-fee-calculation)) |
| `withdrawalsHash` | Root of an empty withdrawals list; blocks never carry withdrawals                                                     |

#### Fork-Dependent Header Fields

| Header Field                   | Before Unzen | Unzen                    | Etna                                                            |
| ------------------------------ | ------------ | ------------------------ | --------------------------------------------------------------- |
| `parentBeaconBlockRoot`        | Absent       | `0x0`                    | `metadata.anchorBlockHash`, never zero                          |
| `blobGasUsed`, `excessBlobGas` | Absent       | `0`                      | `0`                                                             |
| `requestsHash`                 | Absent       | `EMPTY_REQUESTS_HASH`    | `EMPTY_REQUESTS_HASH`                                           |
| `difficulty` (after execution) | `0`          | zk gas used by the block | zk gas used by the block (`0` for a block without transactions) |

Because every header before Unzen has a zero `difficulty`, `metadata.mixHash` depends only on the block number up to and including the first Unzen block. After that it also depends on the parent's zk gas used.

Note: Fields like `stateRoot`, `transactionsRoot`, `receiptsRoot`, `logsBloom`, and `gasUsed`, and from Unzen on `difficulty`, are populated after transaction execution.

### zk Gas

From Unzen on, execution meters zk gas as specified in [the zk gas spec](./zk_gas_spec.md). If a transaction would take the block's zk gas above `BLOCK_ZK_GAS_LIMIT`, that transaction is aborted and every later transaction of the block is skipped, so the block keeps only the transactions before it. The header's `difficulty` records the zk gas the block used. Before Etna the anchor transaction is metered too, but it is never the transaction that is aborted; from Etna on, any transaction, including the first one, can be.

### Anchor Transaction

Every block before Etna starts with the anchor transaction. Etna removes it (see [Etna](#etna-blocks-without-an-anchor-transaction)).

The anchor transaction serves as a privileged system transaction responsible for L1 state synchronization. It invokes the `anchorV4` function on the `Anchor` contract with the L1 checkpoint fields:

| Parameter         | Type    | Description                                     |
| ----------------- | ------- | ----------------------------------------------- |
| anchorBlockNumber | uint48  | L1 block number to anchor (0 to skip anchoring) |
| anchorBlockHash   | bytes32 | L1 block hash at anchorBlockNumber              |
| anchorStateRoot   | bytes32 | L1 state root at anchorBlockNumber              |

#### Transaction Execution Flow

The anchor transaction executes a carefully orchestrated sequence of operations:

1. **Block validation and duplicate prevention**

   - Verifies the incoming anchor parameters are valid relative to the latest stored anchor state
   - Tracks parent block hash to prevent inconsistent or duplicate `anchorV4` processing within the same block

2. **L1 state anchoring** (when anchorBlockNumber > previous anchorBlockNumber)
   - Persists L1 block data via `checkpointStore.saveCheckpoint`
   - Updates anchor state atomically with the latest anchor block metadata

**Execution constraints**:

- Gas limit: Exactly `ANCHOR_GAS_LIMIT` (1,000,000) gas (enforced by the Taiko node software)
- Caller restriction: Golden touch address (system account) only

## Etna: Blocks Without an Anchor Transaction

> Etna is not scheduled on any network. This section specifies the derivation side of [taiko-mono#22147](https://github.com/taikoxyz/taiko-mono/issues/22147). The execution side is implemented in [alethia-reth#248](https://github.com/taikoxyz/alethia-reth/pull/248), whose driver guide also defines the Engine API methods drivers use for Etna blocks.

Etna removes the anchor transaction. The L1 block that an L2 block anchors to is committed in the block header instead, and the standard EIP-4788 pre-execution call records it in L2 state. The proposal format and the metadata validation rules stay the same; what changes is how a block is built from its metadata and how a parent's metadata is recovered.

### Block Contents

- A block's transactions are `metadata.transactions`. Nothing is prepended and no position is reserved, so the first transaction is handled like every other one.
- A source replaced by the default source manifest yields a block without transactions.
- Transactions sent by the golden touch address are ordinary transactions, with ordinary balance, fee and refund handling.
- The block's gas limit has no anchor reserve (see [`gasLimit` Validation](#gaslimit-validation)).

### L1 Anchor in the Header

`parentBeaconBlockRoot` is `metadata.anchorBlockHash`: the hash of the L1 block at the block's final `anchorBlockNumber`. A block that inherits its parent's anchor, such as a forced inclusion or a default source manifest block, therefore repeats the parent's `parentBeaconBlockRoot`. The value is never zero, and it is not the hash of the L1 block that included the proposal.

The execution engine only checks that the field is present and non-zero. Its relation to L1 is a derivation rule: drivers set it from L1, and provers check it as described in [`anchorBlockHash` and `anchorStateRoot` Validation](#anchorblockhash-and-anchorstateroot-validation).

### Recording L1 Data on L2

Two standard pre-execution calls replace the anchor transaction's writes. Execution has run both since Unzen, and until their contracts are deployed the calls change nothing. They run in every block, including blocks without transactions, and their writes are part of the state transition:

- EIP-4788 stores `parentBeaconBlockRoot` in the beacon roots contract (`0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02`), in a ring buffer of 8191 entries keyed by block timestamp.
- EIP-2935 stores the parent block hash in the history storage contract (`0x0000F90827F1C53a10cb7A02335B175320002935`), for the last 8191 blocks.

Blocks no longer write L1 checkpoints. Any account can persist one by calling `SignalService.revealCheckpoint` with the L1 header that a hash recorded by EIP-4788 commits to. This is an ordinary transaction, not part of derivation.

### Activation

- Parent metadata follows the parent's fork (see [Parent Metadata](#parent-metadata)). For the first Etna block, `ANCHOR_GAS_LIMIT` is still subtracted from the parent's gas limit, and the parent's anchor block number still comes from `Anchor`.
- The base fee reads the parent header as recorded (see [Base Fee Calculation](#base-fee-calculation)).
- Before the first Etna block:
  - every taiko-geth node must execute the EIP-4788 call identically when building and when importing blocks ([taiko-geth#601](https://github.com/taikoxyz/taiko-geth/pull/601)), and only then can the EIP-4788 contract be deployed on L2; the EIP-2935 contract must be deployed as well;
  - `Anchor.anchorV4` and the L2 `SignalService` checkpoint writer must be disabled. The anchor contract's own checks still pass in the first block without an anchor transaction, and the golden touch key is public, so otherwise a proposer could put an `anchorV4` call with a forged checkpoint into that block.

## L1 Proof and Liveness Bond Settlement

Late-proof handling on L1 may trigger at most one liveness-bond settlement for the first proven proposal. The Inbox applies the settlement inside `prove` on L1 (best-effort), crediting 50% of the debited bond to the actual prover and burning the remainder.

## Base Fee Calculation

The calculation of block base fee shall follow [EIP-4396](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-4396.md#specification).

Its inputs are the parent header's `gasLimit`, `gasUsed` and `baseFee` as recorded, and the parent block time (`parent.timestamp - parent.parent.timestamp`). Unlike [`gasLimit` validation](#gaslimit-validation), the calculation subtracts no anchor reserve, so for a parent before Etna, including the parent of the first Etna block, these values include the anchor reserve and the anchor transaction's gas.

The consensus engine pins the base fee at `INITIAL_BASE_FEE` for the very first block when the Shasta fork starts from genesis, because the parent block time (`parent.timestamp - parent.parent.timestamp`) needed for calculation is unavailable. If the fork activates later or once the block height exceeds `1`, base fee computation should follow [EIP-4396](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-4396.md#specification), and the calculated value must be clamped within a chain-specific lower bound and `MAX_BASE_FEE`.

The minimum clamp is selected by chain ID:

- `MAINNET_MIN_BASE_FEE` (`0.01 gwei`) on Taiko mainnet
- `MIN_BASE_FEE` (`0.005 gwei`) on non-mainnet chains

## Constants

The following constants govern the block derivation process:

| Constant                               | Value                                                                                    | Description                                                                                                            |
| -------------------------------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **DERIVATION_SOURCE_MAX_BLOCKS**       | `192`                                                                                    | The pre-Unzen per-derivation-source block limit.                                                                       |
| **UNZEN_DERIVATION_SOURCE_MAX_BLOCKS** | `768`                                                                                    | The per-derivation-source block limit for proposals whose landed L1 block timestamp is at or after Unzen.              |
| **MAX_ANCHOR_OFFSET**                  | Hoodi: `128`, Mainnet: `512`                                                             | The maximum anchor block number offset from the proposal origin block number.                                          |
| **TIMESTAMP_MAX_OFFSET**               | Hoodi: `1536` (12 \* 128), Mainnet: `6144` (12 \* 512)                                   | The maximum timestamp offset from the proposal origin timestamp.                                                       |
| **BLOCK_GAS_LIMIT_MAX_CHANGE**         | `200`                                                                                    | The maximum block gas limit change per block, in millionths (1/1,000,000). For example, 200 = 200 / 1,000,000 = 0.02%. |
| **MIN_BLOCK_GAS_LIMIT**                | `10,000,000`                                                                             | The minimum block gas limit. This ensures block gas limit never drops below a critical threshold.                      |
| **MAX_BLOCK_GAS_LIMIT**                | `45,000,000`                                                                             | The maximum block gas limit. This ensures block gas limit never goes above a critical threshold.                       |
| **INITIAL_BASE_FEE**                   | `0.025 gwei` (25,000,000 wei)                                                            | The initial base fee for the first Shasta block when the Shasta fork activated from genesis.                           |
| **MIN_BASE_FEE**                       | `0.005 gwei` (5,000,000 wei)                                                             | The default minimum base fee (inclusive) after Shasta fork for non-mainnet chains.                                     |
| **MAINNET_MIN_BASE_FEE**               | `0.01 gwei` (10,000,000 wei)                                                             | The minimum base fee (inclusive) after Shasta fork on Taiko mainnet.                                                   |
| **MAX_BASE_FEE**                       | `1 gwei` (1,000,000,000 wei)                                                             | The maximum base fee (inclusive) after Shasta fork.                                                                    |
| **BLOCK_TIME_TARGET**                  | `2 seconds`                                                                              | The block time target.                                                                                                 |
| **ANCHOR_GAS_LIMIT**                   | `1,000,000`                                                                              | The anchor transaction's gas limit, added to every block's gas limit before Etna.                                      |
| **BLOCK_ZK_GAS_LIMIT**                 | `100,000,000`                                                                            | The maximum zk gas per block from Unzen on (see [the zk gas spec](./zk_gas_spec.md)).                                  |
| **EMPTY_REQUESTS_HASH**                | `0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`                     | The `requestsHash` of a block without execution requests (`sha256("")`, see EIP-7685).                                 |
| **SHASTA_FORK_TIME**                   | Hoodi: `1770296400` (2026-02-05 13:00 UTC), Mainnet: `1775135700` (2026-04-02 13:15 UTC) | The Shasta fork activation timestamp.                                                                                  |
| **UNZEN_FORK_TIME**                    | Hoodi: `1781787600` (2026-06-18 13:00 UTC), Mainnet: `1786021200` (2026-08-06 13:00 UTC) | The Unzen fork activation timestamp.                                                                                   |
| **ETNA_FORK_TIME**                     | Hoodi/Mainnet: not scheduled                                                             | The Etna fork activation timestamp.                                                                                    |
