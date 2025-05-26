---
title: SGXVerifier
description: Taiko Alethia protocol page for "SGXVerifier.sol".
---

[SGXVerifier](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.0/packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol)is a smart contract that implements **SGX (Software Guard Extensions) signature proof verification** on-chain. It ensures the integrity and security of rollup state transitions by **validating SGX-generated signatures**. The contract also manages SGX instance registration, tracking, and lifecycle operations.

SGX instances are uniquely identified by Ethereum addresses, derived from **an ECDSA public-private key pair** generated within the SGX enclave. The SGXVerifier contract ensures **only authorized instances participate in rollup verification**.

---

## Features

- **Instance Registry**: Tracks valid SGX instances and enforces expiration policies.
- **Instance Lifecycle Management**: Registers new instances, rotates old instances, and removes compromised or outdated instances.
- **SGX Proof Verification**: Validates **block state transitions** using SGX-generated signatures and supports **batch proof verification** for efficiency.

---

## Contract Methods

### `addInstances`

Registers new SGX instances.

| Input Parameter | Type        | Description                                          |
| --------------- | ----------- | ---------------------------------------------------- |
| `_instances`    | `address[]` | List of SGX instance Ethereum addresses to register. |

**Access Control**: Only callable by the contract owner.

---

### `deleteInstances`

Removes registered SGX instances.

| Input Parameter | Type        | Description                          |
| --------------- | ----------- | ------------------------------------ |
| `_ids`          | `uint256[]` | Array of instance IDs to be removed. |

**Access Control**: Restricted to the owner or `SGX_WATCHDOG` role.

---

### `registerInstance`

Registers an SGX instance after verifying its attestation off-chain.

| Input Parameter | Type    | Description                                              |
| --------------- | ------- | -------------------------------------------------------- |
| `_attestation`  | `bytes` | Attestation quote containing SGX enclave report details. |

**Returns**: The assigned instance ID.

**Access Control**: Open to external calls.

---

### `verifyProof`

Verifies an SGX proof for a **single block state transition**.

| Input Parameter | Type      | Description            |
| --------------- | --------- | ---------------------- |
| `_ctx`          | `bytes32` | Context of the proof.  |
| `_tran`         | `bytes32` | Block transition data. |
| `_proof`        | `bytes`   | SGX signature proof.   |

**Mechanism**:

- Validates the **instance ID and signature**.
- Ensures the SGX instance is **not expired**.
- Replaces the SGX instance if invalid.

---

### `verifyBatchProof`

Verifies multiple SGX proofs for **batch block state transitions**.

| Input Parameter | Type        | Description                |
| --------------- | ----------- | -------------------------- |
| `_ctxs`         | `bytes32[]` | Array of proof contexts.   |
| `_proof`        | `bytes`     | SGX batch signature proof. |

**Mechanism**:

- Verifies the signature against **public inputs for all blocks**.
- Automatically rotates instances **if an invalid proof is detected**.

---

## Events

### `InstanceAdded`

Triggered when a **new SGX instance is added or replaced**.

| Event Parameter | Type      | Description                                |
| --------------- | --------- | ------------------------------------------ |
| `id`            | `uint256` | ID of the SGX instance.                    |
| `instance`      | `address` | Address of the added SGX instance.         |
| `replaced`      | `address` | Address of the replaced instance (if any). |
| `validSince`    | `uint256` | Timestamp when the instance became valid.  |

---

### `InstanceDeleted`

Triggered when an **SGX instance is removed**.

| Event Parameter | Type      | Description                      |
| --------------- | --------- | -------------------------------- |
| `id`            | `uint256` | ID of the removed SGX instance.  |
| `instance`      | `address` | Address of the removed instance. |

---

## Constants

| Constant Name             | Value    | Description                                             |
| ------------------------- | -------- | ------------------------------------------------------- |
| `INSTANCE_EXPIRY`         | 365 days | Duration before an SGX instance expires.                |
| `INSTANCE_VALIDITY_DELAY` | 1 hour   | Delay before a newly registered instance becomes valid. |

---
