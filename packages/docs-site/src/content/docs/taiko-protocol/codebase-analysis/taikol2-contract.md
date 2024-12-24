---
title: TaikoL2
description: Taiko protocol page for "TaikoL2.sol".
---

[TaikoL2](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/contracts/layer2/based/TaikoL2.sol) is a smart contract that handles cross-layer message verification and manages EIP-1559 gas pricing for Taiko operations. It is used to anchor the latest L1 block details to L2 for cross-layer communication, manage EIP-1559 parameters for gas pricing, and store verified L1 block information.

---

## Core Purpose

1. **Anchor:**
   Due to Taiko's **based rollup** nature, each L2 block requires anchoring to the latest L1 block details. The first transaction of every block must perform this anchor, or all calls will revert with `L2_PUBLIC_INPUT_HASH_MISMATCH`.

2. **Gas Pricing:**
   The contract calculates **EIP-1559 base fee** and updates gas parameters dynamically for optimal gas pricing using key inputs such as `_parentGasUsed` and `_baseFeeConfig`.

3. **State Synchronization:**
   The contract ensures L2 remains in sync with L1 by storing verified block information and updating state data like block hashes and timestamps.

4. **Bridging Support:**
   It plays a crucial role in **L1-L2 bridging**, anchoring state roots to enable secure and efficient communication between layers. For more, visit the [Bridging page](/taiko-protocol/bridging).

---

## Key Functions

### `anchorV2`

- **Purpose:**
  Anchors the latest L1 block details to L2, enabling **cross-layer message verification**.

- **Parameters:**

  - `_anchorBlockId`: The L1 block ID to anchor.
  - `_anchorStateRoot`: State root of the specified L1 block.
  - `_parentGasUsed`: Gas usage in the parent block.
  - `_baseFeeConfig`: Configuration for base fee calculation.

- **Mechanism:**
  Verifies and updates the `publicInputHash`, calculates the base fee and gas excess using `getBasefeeV2`, and synchronizes chain data.

---

### `getBasefeeV2`

- **Purpose:**
  Computes the **EIP-1559 base fee** and updates gas parameters like **gas excess** and **gas target**.

- **Parameters:**

  - `_parentGasUsed`: Gas used in the parent block.
  - `_baseFeeConfig`: Configuration for EIP-1559 calculations.

- **Returns:**

  - `basefee_`: Calculated base fee per gas.
  - `newGasTarget_`: Updated gas target.
  - `newGasExcess_`: Updated gas excess.

- **Technical Details:**
  Uses `LibEIP1559.calc1559BaseFee` and `LibEIP1559.adjustExcess` for precise gas pricing dynamics.

---

### `getBlockHash`

- **Purpose:**
  Fetches the block hash for a specified block ID.

- **Technical Note:**
  If the block ID is too old (not in the last 256 blocks), it uses an internal mapping (`_blockhashes`) to retrieve stored hashes.

---

## Key Events

1. **`Anchored`**
   Emitted when L1 block details are successfully anchored to L2.

   **Parameters:**

   - `parentHash`: Hash of the parent block.
   - `parentGasExcess`: Gas excess for base fee calculation.

2. **`EIP1559Update`**
   Emitted when gas parameters (e.g., target, excess, base fee) are updated.

   **Parameters:**

   - `oldGasTarget`: Previous gas target.
   - `newGasTarget`: Updated gas target.
   - `oldGasExcess`: Previous gas excess.
   - `newGasExcess`: Updated gas excess.
   - `basefee`: Calculated base fee.

---

## Important Data Structures

### State Variables

1. **`publicInputHash`**:
   Validates the integrity of public inputs for block verification.

2. **`parentGasExcess`**:
   Tracks gas usage exceeding the target for dynamic base fee adjustment.

3. **`lastSyncedBlock`**:
   Stores the ID of the most recent L1 block synced with L2.

4. **`l1ChainId`**:
   Chain ID of the base layer (L1).

---
