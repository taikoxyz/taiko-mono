---
title: TaikoInbox
description: Taiko Alethia protocol page for "TaikoInbox.sol".
---

[TaikoInbox](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.0/packages/protocol/contracts/layer1/based/TaikoInbox.sol) is the **core Layer 1 smart contract** in the Taiko Alethia protocol. It is responsible for **batch lifecycle management**, **state synchronization**, and **bond management**. TaikoInbox ensures seamless interaction between L1 and L2, enabling a secure and scalable rollup architecture.

## Features

- **Batch Lifecycle Management**: Handles batch **proposal, proving, and verification**.
- **Cross-Layer Synchronization**: Ensures **state consistency** between L1 and L2.
- **Bond Management**: Maintains economic security by **requiring bonds** for proposers.
- **Scalability**: Supports **Layer 3 (L3) deployments**, expanding Taiko’s rollup capabilities.

---

## Contract Methods

### `proposeBatch`

Proposes a batch of batches.

| Input Parameter | Type    | Description                                                                                    |
| --------------- | ------- | ---------------------------------------------------------------------------------------------- |
| `_params`       | `bytes` | ABI-encoded batchParams.                                                                       |
| `_txList`       | `bytes` | Transaction list in calldata. If the txList is empty, blob will be used for data availability. |

**Returns**:

- `BatchInfo memory info_`: Batch information essential for constructing blocks offchain.
- `BatchMetadata memory meta_`: Metadata of the proposed batch.

---

### `proveBatches`

Proves **multiple batches** with a single aggregated proof.

| Input Parameter | Type    | Description                                                         |
| --------------- | ------- | ------------------------------------------------------------------- |
| `_params`       | `bytes` | ABI-encoded parameter containing metas and transitions.             |
| `_proof`        | `bytes` | The aggregated cryptographic proof proving the batches transitions. |

**Returns**:

- `TaikoData.batchMetadataV2[]`: Array of metadata for all proposed batches.

---

### `verifyBatches`

Verifies a **batch of blocks** after proofs are submitted.

| Input Parameter | Type    | Description                          |
| --------------- | ------- | ------------------------------------ |
| `_length`       | `uint8` | Maximum number of batches to verify. |

---

### `depositBond`

Locks a **bond deposit** required for proposing batches.

| Input Parameter | Type      | Description                |
| --------------- | --------- | -------------------------- |
| `_amount`       | `uint256` | Amount of bond to deposit. |

---

### `withdrawBond`

Withdraws a **bond deposit** after batch proposals are finalized.

| Input Parameter | Type      | Description                 |
| --------------- | --------- | --------------------------- |
| `_amount`       | `uint256` | Amount of bond to withdraw. |

---

### `getLastVerifiedTransition`

Retrieves the **most recent verified batch**.

| Return Value | Type              | Description                                  |
| ------------ | ----------------- | -------------------------------------------- |
| `batchId_`   | `uint64`          | ID of the last verified batch.               |
| `batchId_`   | `uint64`          | ID of the last verified batch.               |
| `ts_`        | `TransitionState` | The transition used for verifying the batch. |

---

## Events

### `BatchProposed`

Triggered when a **new batch is proposed**.

| Event Parameter | Type            | Description                         |
| --------------- | --------------- | ----------------------------------- |
| `info`          | `BatchInfo`     | The info of the proposed batch.     |
| `meta`          | `BatchMetadata` | The metadata of the proposed batch. |
| `txList`        | `bytes`         | The tx list in calldata.            |

---

### `BatchesProved`

Triggered when a **validity proof is submitted** for a batch.

| Event Parameter | Type           | Description                |
| --------------- | -------------- | -------------------------- |
| `verifier`      | `address`      | Address of the verifier.   |
| `batchIds`      | `uint64[]`     | IDs of the proven batches. |
| `transitions`   | `Transition[]` | The transitions data.      |

---

### `BatchesVerified`

Emitted when a **batch is verified**.

| Event Parameter | Type      | Description                      |
| --------------- | --------- | -------------------------------- |
| `batchId`       | `uint64`  | ID of the verified batch.        |
| `batchHash`     | `bytes32` | The hash of the verified batch . |

---

## Constants

| Constant Name        | Value | Description                                   |
| -------------------- | ----- | --------------------------------------------- |
| `livenessBondBase`   | 125   | Required bond for proposing a batch.          |
| `maxBlocksPerBatch`  | 768   | Maximum number of blocks proposed in a batch. |
| `maxBatchesToVerify` | 16    | Maximum number of batches verified at once.   |

---

## Design Considerations

1. **Ethereum-Equivalent Execution**
   - The contract follows Ethereum’s rollup-centric roadmap, allowing **Ethereum-equivalent execution**.
   - No modifications to **EVM opcodes**, ensuring compatibility.

    </br>

2. **Based Rollup Architecture**
   - Batches are proposed permissionlessly, following **Ethereum’s L1 sequencing** rules.
   - No centralized sequencer; TaikoInbox ensures **censorship resistance**.

    </br>

3. **Multiproving System**
   - Supports multiple proving mechanisms: **TEE + TEE, TEE + ZK**.
   - Ensures security **even if one proof system is compromised**.

---
