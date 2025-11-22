---
title: TaikoAnchor
description: Taiko Alethia protocol page for "Anchor.sol" in layer2/core.
---

[Taiko Anchor](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/contracts/layer2/core/Anchor.sol) is a **core smart contract** for the Taiko Alethia rollup, responsible for **L1 checkpoint anchoring**, **bond-based security and prover designation**, and **public input integrity via ancestor-hash computation**. It ensures L2 remains consistent with L1 checkpoints and facilitates secure verification primitives.

---

## Features

- **L1 Checkpoint Anchoring**: Persists selected L1 block data (number, hash, state root) to L2 via `ICheckpointStore`.
- **Bond-Based Security**: Processes cumulative bond instructions with integrity verification using `LibBonds` and `IBondManager`.
- **Prover Designation (EIP-712)**: Validates designated prover via ECDSA signatures and transfers proving fees from proposer bonds when applicable.
- **Ancestor Hash Integrity**: Computes previous/new ancestors hash (public inputs) over a 255-block ring buffer plus `chainid` to secure sequencing.
- **Preconfirmation Metadata**: Stores per-block metadata required for slashing in permissionless preconfirmations.

---

## Contract Methods

### `anchorV4(ProposalParams _proposalParams, BlockParams _blockParams)`

Processes a block within a proposal: designates prover (first block only), processes bond instructions, anchors L1 checkpoint data if fresher, updates ancestors hash, and emits `Anchored`.

- **Access control**: `onlyValidSender` (see Access Control) and `nonReentrant`.

| Parameter          | Type            | Description |
| ------------------ | --------------- | ----------- |
| `_proposalParams`  | `ProposalParams`| Proposal-level parameters (first block of a proposal updates state). |
| `_blockParams`     | `BlockParams`   | Block-level parameters for anchoring and metadata. |

#### `ProposalParams`

| Field                   | Type                         | Description |
| ----------------------- | ---------------------------- | ----------- |
| `submissionWindowEnd`   | `uint48`                     | End of preconfirmation submission window (0 for whitelist preconfs). |
| `proposalId`            | `uint48`                     | Unique proposal identifier; must be monotonic. |
| `proposer`              | `address`                    | Proposer address. |
| `proverAuth`            | `bytes`                      | ABI-encoded `ProverAuth` for prover designation. |
| `bondInstructionsHash`  | `bytes32`                    | Expected cumulative hash after processing bond instructions. |
| `bondInstructions`      | `LibBonds.BondInstruction[]` | Bond credit instructions to process. |

#### `BlockParams`

| Field               | Type      | Description |
| ------------------- | --------- | ----------- |
| `anchorBlockNumber` | `uint48`  | L1 block number to anchor (0 to skip). |
| `anchorBlockHash`   | `bytes32` | L1 block hash at `anchorBlockNumber`. |
| `anchorStateRoot`   | `bytes32` | L1 state root at `anchorBlockNumber`. |
| `rawTxListHash`     | `bytes32` | Keccak256 of the block's unprocessed transaction list (0-bytes for whitelist preconfs). |

---

### `getDesignatedProver(uint48 _proposalId, address _proposer, bytes _proverAuth, address _currentDesignatedProver)`

Determines the designated prover from an EIP-712 signed `ProverAuth`, considering bond sufficiency.

| Returns                          | Type      | Description |
| -------------------------------- | --------- | ----------- |
| `isLowBondProposal_`             | `bool`    | True if proposer lacks sufficient bond for the proving fee. |
| `designatedProver_`              | `address` | The designated prover (may remain proposer). |
| `provingFeeToTransfer_`          | `uint256` | Fee to transfer from proposer bond to the prover. |

---

### `validateProverAuth(uint48 _proposalId, address _proposer, bytes _proverAuth)`

Validates and recovers signer from `ProverAuth` (EIP-712). Returns `(signer_, provingFee_)` where `signer_` is `proposer` on validation failure.

---

### `getProposalState()` / `getBlockState()` / `getPreconfMetadata(uint256 _blockNumber)`

- `getProposalState()` returns `ProposalState { bondInstructionsHash, designatedProver, isLowBondProposal, proposalId }`.
- `getBlockState()` returns `BlockState { anchorBlockNumber, ancestorsHash }`.
- `getPreconfMetadata(_blockNumber)` returns `PreconfMetadata { anchorBlockNumber, submissionWindowEnd, parentSubmissionWindowEnd, rawTxListHash, parentRawTxListHash }` and reverts if `_blockNumber` is invalid.

---

### `blockHashes(uint256) -> bytes32`

Public mapping of stored parent block hashes, updated during `anchorV4` for `block.number - 1`.

---

### `withdraw(address _token, address _to)`

Withdraws Ether (`_token == address(0)`) or ERC20 tokens to `_to`. Emits `Withdrawn`.

---

## Events

### `Anchored(bytes32 bondInstructionsHash, address designatedProver, bool isLowBondProposal, bool isNewProposal, uint48 prevAnchorBlockNumber, uint48 anchorBlockNumber, bytes32 ancestorsHash)`

Emitted on each processed block to record proposal-level and block-level state, including ancestors hash and latest anchored L1 block number.

---

### `Withdrawn(address token, address to, uint256 amount)`

Emitted on successful withdrawal of Ether or tokens from the contract.

---

## State Variables

- **Immutables**
  - `bondManager: IBondManager`
  - `checkpointStore: ICheckpointStore`
  - `livenessBond: uint256`
  - `provabilityBond: uint256`
  - `l1ChainId: uint64`

- **Public mapping**
  - `blockHashes(uint256 blockNumber) -> bytes32 blockHash`

- **Internal state**
  - `_proposalState: ProposalState { bondInstructionsHash, designatedProver, isLowBondProposal, proposalId }`
  - `_blockState: BlockState { anchorBlockNumber, ancestorsHash }`
  - `_preconfMetadata: mapping(uint256 => PreconfMetadata)`
  - `_pacayaSlots: uint256[3]` (legacy storage layout for Pacaya anchor slots; not user-facing)

---

## Design Considerations

1. **Checkpoint Freshness**
   - Saves checkpoints only when a strictly newer `anchorBlockNumber` is provided.

2. **Bond Instruction Integrity**
   - Aggregates `LibBonds.BondInstruction` entries and enforces `bondInstructionsHash` equality after processing.

3. **Prover Designation & Fees**
   - EIP-712 `ProverAuth` signature validation; proving fee debited from proposer bond and credited to designated prover when applicable.

4. **Ancestors Hash Computation**
   - Computes previous/new public input hashes using a 255-slot ring buffer of historical block hashes plus `chainid`.

5. **Preconfirmation Metadata**
   - Stores per-block metadata used for slashing checks in permissionless preconfs.

---

## Access Control & Limits

- **onlyValidSender**: `anchorV4` can only be called by `GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec`.
- **nonReentrant**: `anchorV4` is protected by reentrancy guard.
- **Gas limit**: Implementations must enforce `ANCHOR_GAS_LIMIT = 1_000_000` for anchor transactions.

---
