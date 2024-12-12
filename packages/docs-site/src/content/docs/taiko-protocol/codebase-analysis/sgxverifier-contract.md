---
title: SGXVerifier
description: Taiko protocol page for "SGXVerifier.sol".
---

## Overview

The `SGXVerifier` smart contract implements SGX (Software Guard Extensions) signature proof verification on-chain. This verification ensures integrity and security of rollup state transitions by validating SGX-generated signatures. It also enables management and tracking of SGX instances through registration and replacement.

---

## Core Components

### **SGX Instance Management**

- **Instance Registry**:

  - Each SGX instance is uniquely identified by its Ethereum address (derived from an ECDSA public-private key pair generated in the SGX enclave).
  - The registry ensures:
    - Only valid instances are allowed.
    - Instances are valid for a predefined duration (`INSTANCE_EXPIRY`).

- **Instance Lifecycle**:
  - **Addition**: SGX instances can be added via the `addInstances` function or the `registerInstance` method (following attestation verification).
  - **Replacement**: Old SGX instances can be replaced with new ones to maintain security.
  - **Deletion**: Instances can be removed using the `deleteInstances` function.

---

## Functions

### **`addInstances`**

- **Purpose**: Adds new SGX instances to the registry.
- **Input**:
  - `_instances`: Array of Ethereum addresses corresponding to the SGX instances.
- **Output**: Returns an array of assigned instance IDs.
- **Access Control**: Restricted to the owner.

---

### **`deleteInstances`**

- **Purpose**: Removes SGX instances from the registry.
- **Input**:
  - `_ids`: Array of instance IDs to be removed.
- **Access Control**: Restricted to the owner or the `SGX_WATCHDOG` role.

---

### **`registerInstance`**

- **Purpose**: Registers an SGX instance by verifying its attestation off-chain and adding it to the registry.
- **Input**:
  - `_attestation`: Parsed attestation quote containing SGX enclave report details.
- **Output**: Returns the assigned instance ID.
- **Access Control**: Open to external calls.

---

### **`verifyProof`**

- **Purpose**: Validates the SGX signature proof for a single block state transition.
- **Input**:
  - `_ctx`: Context of the proof.
  - `_tran`: Transition data.
  - `_proof`: SGX signature proof.
- **Mechanism**:
  - Validates the instance ID and signature.
  - Ensures the SGX instance is valid and replaces it if needed.

---

### **`verifyBatchProof`**

- **Purpose**: Validates SGX signature proofs for multiple block state transitions in a batch.
- **Input**:
  - `_ctxs`: Array of contexts for the batch.
  - `_proof`: SGX batch signature proof.
- **Mechanism**:
  - Verifies the signature against public inputs for all blocks.
  - Replaces the SGX instance if necessary.

---

## Key Events

1. **`InstanceAdded`**:

- Emitted when a new SGX instance is added or an old instance is replaced.
- Parameters:
  - `id`: ID of the SGX instance.
  - `instance`: Address of the new SGX instance.
  - `replaced`: Address of the replaced instance (if any).
  - `validSince`: Timestamp indicating when the instance became valid.

2. **`InstanceDeleted`**:

- Emitted when an SGX instance is removed from the registry.
- Parameters:
  - `id`: ID of the SGX instance.
  - `instance`: Address of the removed instance.

---

## Constants

1. **`INSTANCE_EXPIRY`**: Duration (365 days) for which an SGX instance remains valid.
2. **`INSTANCE_VALIDITY_DELAY`**: Delay before an SGX instance becomes valid after registration.

---
