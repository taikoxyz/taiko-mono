---
title: SignalService
description: Taiko Alethia protocol page for "SignalService.sol".
---

[SignalService](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.0/packages/protocol/contracts/shared/signal/SignalService.sol) is a **cross-chain signaling contract** that enables **secure message passing** Taiko Alethia. It allows applications to **send signals**, **synchronize chain data**, and **verify signals using Merkle proofs**. The contract ensures that cross-chain messages are **securely persisted and verifiable** without introducing additional trust assumptions.

## Features

- **Cross-chain message synchronization**: Facilitates Merkle-proof-based message verification.
- **State root and signal caching**: Stores and verifies state roots and signal roots for cross-layer communication.
- **Efficient storage**: Uses **slot-based** storage for optimized signal retrieval.
- **Authorization mechanism**: Controls **who can sync chain data** to prevent unauthorized updates.

---

## Contract Methods

### `sendSignal`

Stores a **signal** in contract storage for cross-chain message passing.

| Parameter | Type      | Description                    |
| --------- | --------- | ------------------------------ |
| `_signal` | `bytes32` | The signal (message) to store. |

**Returns**:

| Return Value | Type      | Description                                  |
| ------------ | --------- | -------------------------------------------- |
| `slot_`      | `bytes32` | The storage slot where the signal is stored. |

---

### `syncChainData`

Synchronizes **state roots** and **signal roots** from other chains.

| Parameter    | Type      | Description                                                |
| ------------ | --------- | ---------------------------------------------------------- |
| `_chainId`   | `uint64`  | Identifier of the source chain.                            |
| `_kind`      | `bytes32` | Type of data being synced (e.g., state root, signal root). |
| `_blockId`   | `uint64`  | Block ID from which the data is sourced.                   |
| `_chainData` | `bytes32` | Data to be stored as the signal.                           |

**Returns**:

| Return Value | Type      | Description                                        |
| ------------ | --------- | -------------------------------------------------- |
| `signal_`    | `bytes32` | The signal corresponding to the stored chain data. |

---

### `proveSignalReceived`

Verifies that a **signal has been received** on the target chain using **Merkle proofs**.

| Parameter  | Type      | Description                                                     |
| ---------- | --------- | --------------------------------------------------------------- |
| `_chainId` | `uint64`  | Source chain identifier.                                        |
| `_app`     | `address` | Address that sent the signal.                                   |
| `_signal`  | `bytes32` | The signal being verified.                                      |
| `_proof`   | `bytes`   | Merkle proof that the signal was persisted on the source chain. |

**Returns**:

| Return Value   | Type      | Description                       |
| -------------- | --------- | --------------------------------- |
| `numCacheOps_` | `uint256` | The number of newly cached items. |

**Mechanism**:

- Uses `_verifySignalReceived()` to **validate** the proof.
- **Caches state roots and signal roots** for future verification.

---

### `verifySignalReceived`

Read-only version of `proveSignalReceived`, verifying **without modifying state**.

| Parameter  | Type      | Description                                                     |
| ---------- | --------- | --------------------------------------------------------------- |
| `_chainId` | `uint64`  | Source chain identifier.                                        |
| `_app`     | `address` | Address that sent the signal.                                   |
| `_signal`  | `bytes32` | The signal being verified.                                      |
| `_proof`   | `bytes`   | Merkle proof that the signal was persisted on the source chain. |

**Technical Note**:

- Uses `_verifySignalReceived()` for validation.
- Does not cache or modify contract state.

---

### `isSignalSent`

Checks whether a given **signal has been sent**.

| Parameter | Type      | Description                   |
| --------- | --------- | ----------------------------- |
| `_app`    | `address` | Address that sent the signal. |
| `_signal` | `bytes32` | The signal to check.          |

**Returns**:

| Return Value | Type   | Description                                                    |
| ------------ | ------ | -------------------------------------------------------------- |
| `bool`       | `bool` | Returns `true` if the signal has been sent, otherwise `false`. |

---

### `isChainDataSynced`

Checks if a given **chain data has been successfully synced**.

| Parameter    | Type      | Description                              |
| ------------ | --------- | ---------------------------------------- |
| `_chainId`   | `uint64`  | Source chain identifier.                 |
| `_kind`      | `bytes32` | Data type identifier.                    |
| `_blockId`   | `uint64`  | Block ID from which the data is sourced. |
| `_chainData` | `bytes32` | Data to check for synchronization.       |

**Returns**:

| Return Value | Type   | Description                                              |
| ------------ | ------ | -------------------------------------------------------- |
| `bool`       | `bool` | Returns `true` if the data is synced, otherwise `false`. |

---

### `getSyncedChainData`

Fetches the **latest synchronized chain data**.

| Parameter  | Type      | Description                                   |
| ---------- | --------- | --------------------------------------------- |
| `_chainId` | `uint64`  | Source chain identifier.                      |
| `_kind`    | `bytes32` | Data type identifier.                         |
| `_blockId` | `uint64`  | Block ID (if `0`, retrieves the most recent). |

**Returns**:

| Return Value | Type      | Description                              |
| ------------ | --------- | ---------------------------------------- |
| `blockId_`   | `uint64`  | Block ID of the synced data.             |
| `chainData_` | `bytes32` | Synchronized data from the source chain. |

---

### `signalForChainData`

Derives a **unique signal** for given **chain data**.

| Parameter  | Type      | Description                              |
| ---------- | --------- | ---------------------------------------- |
| `_chainId` | `uint64`  | Source chain identifier.                 |
| `_kind`    | `bytes32` | Data type identifier.                    |
| `_blockId` | `uint64`  | Block ID from which the data is sourced. |

**Returns**:

| Return Value | Type      | Description                                     |
| ------------ | --------- | ----------------------------------------------- |
| `signal_`    | `bytes32` | Unique signal hash representing the chain data. |

---

### `getSignalSlot`

Computes the **storage slot** where a signal is stored.

| Parameter  | Type      | Description                        |
| ---------- | --------- | ---------------------------------- |
| `_chainId` | `uint64`  | Chain ID of the signal.            |
| `_app`     | `address` | Address that initiated the signal. |
| `_signal`  | `bytes32` | Signal message to retrieve.        |

**Returns**:

| Return Value | Type      | Description                              |
| ------------ | --------- | ---------------------------------------- |
| `slot_`      | `bytes32` | Storage slot where the signal is stored. |

---

## Events

### `SignalSent`

Emitted when a **signal is sent**.

| Parameter | Type      | Description                         |
| --------- | --------- | ----------------------------------- |
| `app`     | `address` | Address that initiated the signal.  |
| `signal`  | `bytes32` | The signal (message) that was sent. |
| `slot`    | `bytes32` | Storage slot of the signal.         |
| `value`   | `bytes32` | The signal's value.                 |

---

### `ChainDataSynced`

Emitted when **state or signal roots** are synced from another chain.

| Parameter | Type      | Description                                       |
| --------- | --------- | ------------------------------------------------- |
| `chainId` | `uint64`  | Source chain identifier.                          |
| `blockId` | `uint64`  | Block ID associated with the data.                |
| `kind`    | `bytes32` | Data type identifier (state root or signal root). |
| `data`    | `bytes32` | The synchronized chain data.                      |
| `signal`  | `bytes32` | Signal associated with the chain data.            |

---

### `Authorized`

Emitted when an address is **authorized or deauthorized** for syncing chain data.

| Parameter    | Type      | Description                                   |
| ------------ | --------- | --------------------------------------------- |
| `addr`       | `address` | The address being authorized or deauthorized. |
| `authorized` | `bool`    | `true` if authorized, `false` otherwise.      |

---

## State Variables

| Variable       | Type                                            | Description                                                      |
| -------------- | ----------------------------------------------- | ---------------------------------------------------------------- |
| `topBlockId`   | `mapping(uint64 => mapping(bytes32 => uint64))` | Tracks the highest synced block ID for each chain and data type. |
| `isAuthorized` | `mapping(address => bool)`                      | Stores addresses authorized to sync chain data.                  |

---
