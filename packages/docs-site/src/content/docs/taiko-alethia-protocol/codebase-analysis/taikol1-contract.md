---
title: TaikoL1
description: Taiko Alethia protocol page for "TaikoL1.sol".
---

[TaikoL1](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v1.12.0/packages/protocol/contracts/layer1/based/TaikoL1.sol) is the **core Layer 1 smart contract** in the Taiko Alethia protocol. It is responsible for **block lifecycle management**, **state synchronization**, and **bond management**. TaikoL1 ensures seamless interaction between L1 and L2, enabling a secure and scalable rollup architecture.

## Features

- **Block Lifecycle Management**: Handles block **proposal, proving, and verification**.
- **Cross-Layer Synchronization**: Ensures **state consistency** between L1 and L2.
- **Bond Management**: Maintains economic security by **requiring bonds** for block proposers.
- **Scalability**: Supports **Layer 3 (L3) deployments**, expanding Taiko’s rollup capabilities.

---

## Contract Methods

### `proposeBlockV2`

Submits a **single block** proposal to the rollup.

| Input Parameter | Type    | Description                                   |
| --------------- | ------- | --------------------------------------------- |
| `_params`       | `bytes` | Encoded block parameters.                     |
| `_txList`       | `bytes` | List of transactions to include in the block. |

**Returns**:

- `TaikoData.BlockMetadataV2`: Metadata of the proposed block.

---

### `proposeBlocksV2`

Submits **multiple block proposals** in a batch.

| Input Parameter | Type      | Description                          |
| --------------- | --------- | ------------------------------------ |
| `_paramsArr`    | `bytes[]` | Array of encoded block parameters.   |
| `_txListArr`    | `bytes[]` | List of transactions for each block. |

**Returns**:

- `TaikoData.BlockMetadataV2[]`: Array of metadata for all proposed blocks.

---

### `proveBlock`

Submits a **validity proof** for a specific block.

| Input Parameter | Type      | Description               |
| --------------- | --------- | ------------------------- |
| `_blockId`      | `uint256` | ID of the block to prove. |
| `_input`        | `bytes`   | Encoded proof data.       |

---

### `proveBlocks`

Submits **batch proofs** for multiple blocks.

| Input Parameter | Type        | Description                      |
| --------------- | ----------- | -------------------------------- |
| `_blockIds`     | `uint256[]` | Array of block IDs to be proven. |
| `_inputs`       | `bytes[]`   | Proofs for each block.           |
| `_batchProof`   | `bytes`     | Batch proof covering all blocks. |

---

### `verifyBlocks`

Verifies a **batch of blocks** after proofs are submitted.

| Input Parameter      | Type      | Description                         |
| -------------------- | --------- | ----------------------------------- |
| `_maxBlocksToVerify` | `uint256` | Maximum number of blocks to verify. |

---

### `depositBond`

Locks a **bond deposit** required for proposing blocks.

| Input Parameter | Type      | Description                |
| --------------- | --------- | -------------------------- |
| `_amount`       | `uint256` | Amount of bond to deposit. |

---

### `withdrawBond`

Withdraws a **bond deposit** after block proposals are finalized.

| Input Parameter | Type      | Description                 |
| --------------- | --------- | --------------------------- |
| `_amount`       | `uint256` | Amount of bond to withdraw. |

---

### `getLastVerifiedBlock`

Retrieves the **most recent verified block**.

| Return Value  | Type      | Description                            |
| ------------- | --------- | -------------------------------------- |
| `blockId_`    | `uint256` | ID of the last verified block.         |
| `blockHash_`  | `bytes32` | Block hash of the verified block.      |
| `stateRoot_`  | `bytes32` | State root of the verified block.      |
| `verifiedAt_` | `uint256` | Timestamp when the block was verified. |

---

## Events

### `BlockProposed`

Triggered when a **new block is proposed**.

| Event Parameter | Type      | Description                                     |
| --------------- | --------- | ----------------------------------------------- |
| `blockId`       | `uint256` | ID of the proposed block.                       |
| `proposer`      | `address` | Address of the proposer.                        |
| `txRoot`        | `bytes32` | Root of the transactions included in the block. |

---

### `BlockProven`

Triggered when a **validity proof is submitted** for a block.

| Event Parameter | Type      | Description                  |
| --------------- | --------- | ---------------------------- |
| `blockId`       | `uint256` | ID of the proven block.      |
| `prover`        | `address` | Address of the prover.       |
| `proofHash`     | `bytes32` | Hash of the submitted proof. |

---

### `BlockVerified`

Triggered when a **block is verified** and finalized.

| Event Parameter | Type      | Description                       |
| --------------- | --------- | --------------------------------- |
| `blockId`       | `uint256` | ID of the verified block.         |
| `verifier`      | `address` | Address of the verifier.          |
| `stateRoot`     | `bytes32` | State root of the verified block. |

---

## Constants

| Constant Name             | Value        | Description                                   |
| ------------------------- | ------------ | --------------------------------------------- |
| `BLOCK_BOND_AMOUNT`       | Configurable | Required bond for proposing a block.          |
| `MAX_PROPOSAL_BATCH_SIZE` | 10           | Maximum number of blocks proposed in a batch. |
| `MAX_VERIFICATION_BATCH`  | 5            | Maximum number of blocks verified at once.    |

---

## Design Considerations

1. **Ethereum-Equivalent Execution**

   - The contract follows Ethereum’s rollup-centric roadmap, allowing **Ethereum-equivalent execution**.
   - No modifications to **EVM opcodes**, ensuring compatibility.

    </br>

2. **Based Rollup Architecture**

   - Blocks are proposed permissionlessly, following **Ethereum’s L1 sequencing** rules.
   - No centralized sequencer; TaikoL1 ensures **censorship resistance**.

    </br>

3. **Multi-Proof System**

   - Supports multiple proving mechanisms: **SGX, ZK, hybrid proofs**.
   - Ensures security **even if one proof system is compromised**.

---
