---
title: IRecallableMessageSender
---

## IRecallableMessageSender

An interface that all recallable message senders shall implement.

### onMessageRecalled

```solidity
function onMessageRecalled(struct IBridge.Message message) external payable
```

---

## title: IBridge

## IBridge

The bridge used in conjunction with the {ISignalService}.

_Ether is held by Bridges on L1 and by the EtherVault on L2,
not by token vaults._

### Message

```solidity
struct Message {
  uint256 id;
  address from;
  uint256 srcChainId;
  uint256 destChainId;
  address user;
  address to;
  address refundTo;
  uint256 value;
  uint256 fee;
  uint256 gasLimit;
  bytes data;
  string memo;
}
```

### Context

```solidity
struct Context {
  bytes32 msgHash;
  address from;
  uint256 srcChainId;
}
```

### SignalSent

```solidity
event SignalSent(address sender, bytes32 msgHash)
```

### MessageSent

```solidity
event MessageSent(bytes32 msgHash, struct IBridge.Message message)
```

### MessageRecalled

```solidity
event MessageRecalled(bytes32 msgHash)
```

### sendMessage

```solidity
function sendMessage(struct IBridge.Message message) external payable returns (bytes32 msgHash)
```

Sends a message to the destination chain and takes custody
of Ether required in this contract. All extra Ether will be refunded.

#### Parameters

| Name    | Type                   | Description             |
| ------- | ---------------------- | ----------------------- |
| message | struct IBridge.Message | The message to be sent. |

#### Return Values

| Name    | Type    | Description                   |
| ------- | ------- | ----------------------------- |
| msgHash | bytes32 | The hash of the sent message. |

### processMessage

```solidity
function processMessage(struct IBridge.Message message, bytes proof) external
```

Processes a message received from another chain.

#### Parameters

| Name    | Type                   | Description                            |
| ------- | ---------------------- | -------------------------------------- |
| message | struct IBridge.Message | The message to process.                |
| proof   | bytes                  | The proof of the cross-chain transfer. |

### retryMessage

```solidity
function retryMessage(struct IBridge.Message message, bool isLastAttempt) external
```

Retries executing a message that previously failed on its
destination chain.

#### Parameters

| Name          | Type                   | Description                                                     |
| ------------- | ---------------------- | --------------------------------------------------------------- |
| message       | struct IBridge.Message | The message to retry.                                           |
| isLastAttempt | bool                   | Specifies whether this is the last attempt to send the message. |

### recallMessage

```solidity
function recallMessage(struct IBridge.Message message, bytes proof) external
```

Recalls a failed message on its source chain.

#### Parameters

| Name    | Type                   | Description                              |
| ------- | ---------------------- | ---------------------------------------- |
| message | struct IBridge.Message | The message to be recalled.              |
| proof   | bytes                  | The proof of message processing failure. |

### isMessageSent

```solidity
function isMessageSent(bytes32 msgHash) external view returns (bool)
```

Checks if the message with the given hash has been sent on its
source chain.

#### Parameters

| Name    | Type    | Description              |
| ------- | ------- | ------------------------ |
| msgHash | bytes32 | The hash of the message. |

#### Return Values

| Name | Type | Description                                                 |
| ---- | ---- | ----------------------------------------------------------- |
| [0]  | bool | Returns true if the message has been sent, false otherwise. |

### isMessageReceived

```solidity
function isMessageReceived(bytes32 msgHash, uint256 srcChainId, bytes proof) external view returns (bool)
```

Checks if the message with the given hash has been received on
its destination chain.

#### Parameters

| Name       | Type    | Description                   |
| ---------- | ------- | ----------------------------- |
| msgHash    | bytes32 | The hash of the message.      |
| srcChainId | uint256 | The source chain ID.          |
| proof      | bytes   | The proof of message receipt. |

#### Return Values

| Name | Type | Description                                                     |
| ---- | ---- | --------------------------------------------------------------- |
| [0]  | bool | Returns true if the message has been received, false otherwise. |

### isMessageFailed

```solidity
function isMessageFailed(bytes32 msgHash, uint256 destChainId, bytes proof) external view returns (bool)
```

Checks if a msgHash has failed on its destination chain.

#### Parameters

| Name        | Type    | Description                   |
| ----------- | ------- | ----------------------------- |
| msgHash     | bytes32 | The hash of the message.      |
| destChainId | uint256 | The destination chain ID.     |
| proof       | bytes   | The proof of message failure. |

#### Return Values

| Name | Type | Description                                              |
| ---- | ---- | -------------------------------------------------------- |
| [0]  | bool | Returns true if the message has failed, false otherwise. |

### isMessageRecalled

```solidity
function isMessageRecalled(bytes32 msgHash) external view returns (bool)
```

Checks if a failed message has been recalled on its source
chain.

#### Parameters

| Name    | Type    | Description              |
| ------- | ------- | ------------------------ |
| msgHash | bytes32 | The hash of the message. |

#### Return Values

| Name | Type | Description                                                   |
| ---- | ---- | ------------------------------------------------------------- |
| [0]  | bool | Returns true if the Ether has been released, false otherwise. |

### context

```solidity
function context() external view returns (struct IBridge.Context context)
```

Returns the bridge state context.

#### Return Values

| Name    | Type                   | Description                                  |
| ------- | ---------------------- | -------------------------------------------- |
| context | struct IBridge.Context | The context of the current bridge operation. |

### hashMessage

```solidity
function hashMessage(struct IBridge.Message message) external pure returns (bytes32)
```

Computes the hash of a given message.

#### Parameters

| Name    | Type                   | Description                          |
| ------- | ---------------------- | ------------------------------------ |
| message | struct IBridge.Message | The message to compute the hash for. |

#### Return Values

| Name | Type    | Description                      |
| ---- | ------- | -------------------------------- |
| [0]  | bytes32 | Returns the hash of the message. |
