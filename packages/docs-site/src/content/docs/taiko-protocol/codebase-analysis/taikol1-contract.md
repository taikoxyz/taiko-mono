---
title: TaikoL1
description: Taiko protocol page for "TaikoL1.sol".
---

[TaikoL1](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/contracts/layer1/based/TaikoL1.sol) is a smart contract that serves as the **base layer** of the Taiko protocol. It provides functionalities for **proposing, proving, and verifying blocks**, enabling the rollup's consensus and state transitions. The contract also supports **bond deposits and withdrawals** and manages state synchronization between L1 and L2.

---

## Core Purpose

1. **Block Lifecycle Management**
   Manages the proposal, proof, and verification of Taiko blocks, ensuring consistent state transitions.

2. **Cross-Layer Synchronization**
   Ensures the synchronization of states between Layer 1 (L1) and Layer 2 (L2).

3. **Bond Management**
   Handles the deposit and withdrawal of bonds to incentivize proposers and ensure accountability.

4. **Base Layer Scalability**
   Enables the deployment on L2 to create L3 rollups, expanding Taiko's scalability.

---

## Key Functions

### `proposeBlockV2`

- **Purpose:**
  Proposes a single block for inclusion in the rollup.

- **Parameters:**

  - `_params`: Encoded block parameters.
  - `_txList`: Transactions to include in the block.

- **Returns:**
  `TaikoData.BlockMetadataV2` containing metadata of the proposed block.

---

### `proposeBlocksV2`

- **Purpose:**
  Proposes multiple blocks in batch.

- **Parameters:**

  - `_paramsArr`: Array of encoded block parameters.
  - `_txListArr`: Arrays of transactions for each block.

- **Returns:**
  Array of `TaikoData.BlockMetadataV2` for all proposed blocks.

---

### `proveBlock`

- **Purpose:**
  Proves the validity of a single block.

- **Parameters:**
  - `_blockId`: ID of the block to be proven.
  - `_input`: Encoded proof data.

---

### `proveBlocks`

- **Purpose:**
  Proves multiple blocks in a single call.

- **Parameters:**
  - `_blockIds`: IDs of the blocks to be proven.
  - `_inputs`: Proofs for each block.
  - `_batchProof`: Batch proof covering all blocks.

---

### `verifyBlocks`

- **Purpose:**
  Verifies a batch of blocks after proofs are submitted.

- **Parameters:**
  - `_maxBlocksToVerify`: Maximum number of blocks to verify.

---

### `depositBond`

- **Purpose:**
  Deposits a bond required for proposing blocks.

- **Parameters:**
  - `_amount`: Amount of bond to deposit.

---

### `withdrawBond`

- **Purpose:**
  Withdraws bond deposits after successful proposals.

- **Parameters:**
  - `_amount`: Amount of bond to withdraw.

---

### `getLastVerifiedBlock`

- **Purpose:**
  Retrieves the details of the most recently verified block.

- **Returns:**
  - `blockId_`: ID of the last verified block.
  - `blockHash_`: Block hash of the verified block.
  - `stateRoot_`: State root of the verified block.
  - `verifiedAt_`: Timestamp when the block was verified.

---

## Key Events

1. **`DebugGasPerBlock`**
   Provides gas usage metrics for block proposals or proofs.

- `isProposeBlock`: Indicates whether the event is for proposals or proofs.
- `gasUsed`: Gas consumed per block.
- `batchSize`: Number of blocks in the batch.

2. **`StateVariablesUpdated`**
   Signals updates to the state variables.

---

## Important Data Structures

1. **`state`**:
   Tracks the rollup state, including blocks, bonds, and configurations.

2. **`__gap`**:
   Reserved storage for future upgrades.

---

## Design Highlights

---
