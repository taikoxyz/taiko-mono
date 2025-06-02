---
title: TaikoAnchor
description: Taiko Alethia protocol page for "TaikoAnchor.sol".
---

[TaikoAnchor](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.0/packages/protocol/contracts/layer2/based/TaikoAnchor.sol) is a **core smart contract** for the Taiko Alethia rollup, responsible for **cross-layer state synchronization**, **gas pricing via EIP-1559**, and **bridging support**. It ensures L2 remains in sync with L1 and facilitates **secure message verification**.

---

## Features

- **Anchor L1 State to L2**: Ensures **L2 block validity** by referencing L1 state.
- **EIP-1559 Gas Pricing**: Dynamically adjusts **base fees** and **gas targets** based on L1 data.
- **Cross-Layer Bridging**: Enables **state root anchoring** for message verification between L1 and L2.
- **Optimized Block Processing**: Ensures **gas-efficient state transitions**.

---

## Contract Methods

### `anchorV3`

Anchors the **latest L1 block details to L2** for cross-layer message verification.

| Parameter          | Type                          | Description                             |
| ------------------ | ----------------------------- | --------------------------------------- |
| `_anchorBlockId`   | `uint64`                      | L1 block ID to anchor.                  |
| `_anchorStateRoot` | `bytes32`                     | State root of the specified L1 block.   |
| `_parentGasUsed`   | `uint32`                      | Gas used in the parent block.           |
| `_baseFeeConfig`   | `LibSharedData.BaseFeeConfig` | Configuration for base fee calculation. |
| `_signalSlots`     | `bytes32[]`                   | The signal slots to mark as received.   |

- Synchronizes chain data.

---

### `getBasefeeV2`

Calculates **EIP-1559 base fee** and updates gas parameters.

| Parameter        | Type      | Description                              |
| ---------------- | --------- | ---------------------------------------- |
| `_parentGasUsed` | `uint256` | Gas used in the parent block.            |
| `_baseFeeConfig` | `uint256` | Configuration for EIP-1559 calculations. |

**Returns**:

| Return Value    | Type      | Description                |
| --------------- | --------- | -------------------------- |
| `basefee_`      | `uint256` | Computed base fee per gas. |
| `newGasTarget_` | `uint256` | Updated gas target.        |
| `newGasExcess_` | `uint256` | Updated gas excess.        |

**Technical Details**:

- Uses `LibEIP1559.calc1559BaseFee` to compute the **new base fee**.
- Adjusts gas targets dynamically using `LibEIP1559.adjustExcess`.

---

### `getBlockHash`

Retrieves the **block hash** for a given block ID.

| Parameter  | Type      | Description                  |
| ---------- | --------- | ---------------------------- |
| `_blockId` | `uint256` | ID of the block to retrieve. |

**Returns**:

| Return Value | Type      | Description                  |
| ------------ | --------- | ---------------------------- |
| `blockHash_` | `bytes32` | Hash of the requested block. |

**Technical Note**:

- If the block is older than **256 blocks**, `_blockhashes` mapping is used instead of `blockhash()`.

---

## Events

### `Anchored`

Emitted when **L1 block details** are successfully anchored to L2.

| Parameter         | Type      | Description                                |
| ----------------- | --------- | ------------------------------------------ |
| `parentHash`      | `bytes32` | Hash of the parent block.                  |
| `parentGasExcess` | `uint256` | Gas excess used for base fee calculations. |

---

### `EIP1559Update`

Emitted when **gas parameters** are updated.

| Parameter      | Type      | Description          |
| -------------- | --------- | -------------------- |
| `oldGasTarget` | `uint256` | Previous gas target. |
| `newGasTarget` | `uint256` | Updated gas target.  |
| `oldGasExcess` | `uint256` | Previous gas excess. |
| `newGasExcess` | `uint256` | Updated gas excess.  |
| `basefee`      | `uint256` | Computed base fee.   |

---

## State Variables

| Variable          | Type      | Description                                                |
| ----------------- | --------- | ---------------------------------------------------------- |
| `publicInputHash` | `bytes32` | Ensures integrity of public inputs for block verification. |
| `parentGasExcess` | `uint256` | Tracks gas usage exceeding the target for fee adjustments. |
| `lastSyncedBlock` | `uint256` | Stores the **most recent** L1 block ID synced with L2.     |
| `l1ChainId`       | `uint256` | Chain ID of **L1** (Ethereum).                             |
| `parentTimeStamp` | `uint64`  | The last L2 block's timestamp.                             |
| `parentGasTarget` | `uint64`  | The last L2 block's gas target.                            |

---

## Design Considerations

1. **State Synchronization**

   - Ensures **L1-L2 consistency** via **anchoring**.
   - Uses **public input hash validation** to prevent state mismatches.

2. **Gas Efficiency**

   - Implements **EIP-1559 dynamic gas pricing**.
   - Optimizes **L2 execution costs** based on **L1 gas usage**.

3. **Bridging & Interoperability**

   - Stores **verified state roots** to facilitate **cross-layer message verification**.
   - Ensures compatibility with **bridging mechanisms**.

---
