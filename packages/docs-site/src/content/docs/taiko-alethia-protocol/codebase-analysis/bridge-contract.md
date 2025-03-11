---
title: Bridge
description: Taiko Alethia protocol page for "Bridge.sol".
---

[Bridge](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v1.12.0/packages/protocol/contracts/shared/bridge/Bridge.sol) is a **cross-chain message passing contract** that enables **secure asset transfers** between Layer 1 (Ethereum) and Layer 2 (Taiko Alethia). The bridge allows users to **send, process, retry, and recall messages** between chains, leveraging the **Signal Service** for proof verification.

The contract also supports **quota management** to prevent excessive withdrawals and is designed to work efficiently in rollup environments.

---

## Features

- **Cross-chain message transfers**: Facilitates **message passing and asset transfers** between L1 and L2.
- **Signal verification**: Uses **Merkle proofs** to validate messages.
- **Gas-optimized execution**: Implements **EIP-1559-based fee calculations** for processing efficiency.
- **Quota management**: Ensures **rate-limited withdrawals** via the QuotaManager contract.
- **Relayer-friendly architecture**: Allows relayers to **submit transactions and earn fees**.

---

## Contract Methods

### `sendMessage`

Sends a **cross-chain message** and takes custody of **Ether or tokens**.

| Parameter  | Type      | Description                                    |
| ---------- | --------- | ---------------------------------------------- |
| `_message` | `Message` | The message struct containing message details. |

**Returns**:

| Return Value | Type      | Description                   |
| ------------ | --------- | ----------------------------- |
| `msgHash_`   | `bytes32` | The hash of the sent message. |
| `message_`   | `Message` | The updated message details.  |

**Mechanism**:

- Stores the **message hash** and emits a **MessageSent** event.
- Sends a **signal** to the **SignalService** for proof verification.

---

### `processMessage`

Processes a **bridge message** on the destination chain.

| Parameter  | Type      | Description                         |
| ---------- | --------- | ----------------------------------- |
| `_message` | `Message` | The message to process.             |
| `_proof`   | `bytes`   | Merkle proof verifying the message. |

**Returns**:

| Return Value | Type           | Description                                                  |
| ------------ | -------------- | ------------------------------------------------------------ |
| `status_`    | `Status`       | The final status of the message (e.g., `DONE`, `RETRIABLE`). |
| `reason_`    | `StatusReason` | Reason for status change.                                    |

**Mechanism**:

- **Verifies message authenticity** using **Merkle proofs**.
- **Checks if the relayer is eligible for fees**.
- **Processes the message call** on the destination chain.
- **Refunds excess Ether** to the `destOwner`.

---

### `retryMessage`

Retries processing a **failed message**.

| Parameter        | Type      | Description                                                |
| ---------------- | --------- | ---------------------------------------------------------- |
| `_message`       | `Message` | The message to retry.                                      |
| `_isLastAttempt` | `bool`    | If `true`, marks the message as **failed** if retry fails. |

**Mechanism**:

- **Checks message status** before retrying.
- **Attempts re-execution** on the destination chain.
- **Marks the message as `DONE` if successful**, otherwise **`FAILED`**.

---

### `failMessage`

Marks a message as **failed** if it's in a **retriable** state.

| Parameter  | Type      | Description                    |
| ---------- | --------- | ------------------------------ |
| `_message` | `Message` | The message to mark as failed. |

**Mechanism**:

- **Updates message status** to `FAILED`.
- **Sends a failure signal** via the **SignalService**.

---

### `recallMessage`

Recalls a **failed message** on the source chain and **refunds associated assets**.

| Parameter  | Type      | Description                           |
| ---------- | --------- | ------------------------------------- |
| `_message` | `Message` | The message to recall.                |
| `_proof`   | `bytes`   | Merkle proof proving message failure. |

**Mechanism**:

- **Validates Merkle proof** to confirm failure.
- **Refunds Ether** or **calls the sender's recall function**.

---

### `isMessageSent`

Checks whether a **message has been sent**.

| Parameter  | Type      | Description           |
| ---------- | --------- | --------------------- |
| `_message` | `Message` | The message to check. |

**Returns**:

| Return Value | Type   | Description                             |
| ------------ | ------ | --------------------------------------- |
| `bool`       | `bool` | Returns `true` if the message was sent. |

---

### `isMessageReceived`

Checks whether a **message has been received**.

| Parameter  | Type      | Description                         |
| ---------- | --------- | ----------------------------------- |
| `_message` | `Message` | The message to check.               |
| `_proof`   | `bytes`   | Merkle proof verifying the message. |

**Returns**:

| Return Value | Type   | Description                                 |
| ------------ | ------ | ------------------------------------------- |
| `bool`       | `bool` | Returns `true` if the message was received. |

---

## Events

### `MessageSent`

Emitted when a **message is sent**.

| Parameter | Type      | Description          |
| --------- | --------- | -------------------- |
| `msgHash` | `bytes32` | Hash of the message. |
| `message` | `Message` | The message details. |

---

### `MessageStatusChanged`

Emitted when a **message's status changes**.

| Parameter | Type      | Description                |
| --------- | --------- | -------------------------- |
| `msgHash` | `bytes32` | Hash of the message.       |
| `status`  | `Status`  | New status of the message. |

---

### `MessageProcessed`

Emitted when a **message is successfully processed**.

| Parameter | Type              | Description                    |
| --------- | ----------------- | ------------------------------ |
| `msgHash` | `bytes32`         | Hash of the processed message. |
| `message` | `Message`         | The message details.           |
| `stats`   | `ProcessingStats` | Gas usage and relayer stats.   |

---

## Important Data Structures

### `Message`

A **message** represents a cross-chain transaction.

| Field         | Type      | Description                                    |
| ------------- | --------- | ---------------------------------------------- |
| `id`          | `uint64`  | Unique ID assigned to the message.             |
| `fee`         | `uint64`  | Maximum processing fee for relayers.           |
| `gasLimit`    | `uint32`  | Gas limit required for processing.             |
| `from`        | `address` | Sender's address.                              |
| `srcChainId`  | `uint64`  | Source chain ID.                               |
| `srcOwner`    | `address` | Owner of the message on the source chain.      |
| `destChainId` | `uint64`  | Destination chain ID.                          |
| `destOwner`   | `address` | Owner of the message on the destination chain. |
| `to`          | `address` | Recipient address on the destination chain.    |
| `value`       | `uint256` | Ether amount to send.                          |
| `data`        | `bytes`   | Call data for execution.                       |

---

### `Status`

Represents the **current state of a message**.

| Status      | Description                             |
| ----------- | --------------------------------------- |
| `NEW`       | Message is **pending processing**.      |
| `RETRIABLE` | Message **failed but can be retried**.  |
| `DONE`      | Message **processed successfully**.     |
| `FAILED`    | Message **failed permanently**.         |
| `RECALLED`  | Message was **recalled by the sender**. |

---

### `StatusReason`

Represents the **reason for a message's status change**.

| Reason                  | Description                                   |
| ----------------------- | --------------------------------------------- |
| `INVOCATION_OK`         | Message **executed successfully**.            |
| `INVOCATION_PROHIBITED` | Message **execution was blocked**.            |
| `INVOCATION_FAILED`     | Message execution **failed**.                 |
| `OUT_OF_ETH_QUOTA`      | Insufficient **quota for message execution**. |

---

## Gas Considerations

| Parameter                         | Value     | Description                          |
| --------------------------------- | --------- | ------------------------------------ |
| `GAS_RESERVE`                     | `800,000` | Reserved gas for processing.         |
| `GAS_OVERHEAD`                    | `120,000` | Overhead for message execution.      |
| `RELAYER_MAX_PROOF_BYTES`         | `200,000` | Max proof size relayers can process. |
| `_GAS_REFUND_PER_CACHE_OPERATION` | `20,000`  | Gas refund per cache operation.      |
| `_SEND_ETHER_GAS_LIMIT`           | `35,000`  | Gas limit for sending Ether.         |

---
