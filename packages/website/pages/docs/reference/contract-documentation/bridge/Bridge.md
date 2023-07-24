---
title: Bridge
---

## Bridge

This contract is a Bridge contract which is deployed on both L1 and L2. Mostly
a thin wrapper
which calls the library implementations. See _IBridge_ for more details.

_The code hash for the same address on L1 and L2 may be different._

### MessageStatusChanged

```solidity
event MessageStatusChanged(bytes32 msgHash, enum LibBridgeStatus.MessageStatus status, address transactor)
```

### DestChainEnabled

```solidity
event DestChainEnabled(uint256 chainId, bool enabled)
```

### receive

```solidity
receive() external payable
```

Allow Bridge to receive ETH from the TaikoL1, TokenVault or EtherVault.

### init

```solidity
function init(address _addressManager) external
```

Initializer to be called after being deployed behind a proxy.

_Initializer function to setup the EssentialContract._

#### Parameters

| Name             | Type    | Description                                 |
| ---------------- | ------- | ------------------------------------------- |
| \_addressManager | address | The address of the AddressManager contract. |

### sendMessage

```solidity
function sendMessage(struct IBridge.Message message) external payable returns (bytes32 msgHash)
```

Sends a message from the current chain to the destination chain specified
in the message.

_Sends a message by calling the LibBridgeSend.sendMessage library
function._

#### Parameters

| Name    | Type                   | Description                        |
| ------- | ---------------------- | ---------------------------------- |
| message | struct IBridge.Message | The message to send. (See IBridge) |

#### Return Values

| Name    | Type    | Description                            |
| ------- | ------- | -------------------------------------- |
| msgHash | bytes32 | The hash of the message that was sent. |

### releaseEther

```solidity
function releaseEther(struct IBridge.Message message, bytes proof) external
```

Releases the Ether locked in the bridge as part of a cross-chain
transfer.

_Releases the Ether by calling the LibBridgeRelease.releaseEther
library function._

#### Parameters

| Name    | Type                   | Description                                                             |
| ------- | ---------------------- | ----------------------------------------------------------------------- |
| message | struct IBridge.Message | The message containing the details of the Ether transfer. (See IBridge) |
| proof   | bytes                  | The proof of the cross-chain transfer.                                  |

### processMessage

```solidity
function processMessage(struct IBridge.Message message, bytes proof) external
```

Processes a message received from another chain.

_Processes the message by calling the LibBridgeProcess.processMessage
library function._

#### Parameters

| Name    | Type                   | Description                            |
| ------- | ---------------------- | -------------------------------------- |
| message | struct IBridge.Message | The message to process.                |
| proof   | bytes                  | The proof of the cross-chain transfer. |

### retryMessage

```solidity
function retryMessage(struct IBridge.Message message, bool isLastAttempt) external
```

Retries sending a message that previously failed to send.

_Retries the message by calling the LibBridgeRetry.retryMessage
library function._

#### Parameters

| Name          | Type                   | Description                                                     |
| ------------- | ---------------------- | --------------------------------------------------------------- |
| message       | struct IBridge.Message | The message to retry.                                           |
| isLastAttempt | bool                   | Specifies whether this is the last attempt to send the message. |

### isMessageSent

```solidity
function isMessageSent(bytes32 msgHash) public view virtual returns (bool)
```

Check if the message with the given hash has been sent.

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
function isMessageReceived(bytes32 msgHash, uint256 srcChainId, bytes proof) public view virtual returns (bool)
```

Check if the message with the given hash has been received.

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
function isMessageFailed(bytes32 msgHash, uint256 destChainId, bytes proof) public view virtual returns (bool)
```

Check if the message with the given hash has failed.

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

### getMessageStatus

```solidity
function getMessageStatus(bytes32 msgHash) public view virtual returns (enum LibBridgeStatus.MessageStatus)
```

Get the status of the message with the given hash.

#### Parameters

| Name    | Type    | Description              |
| ------- | ------- | ------------------------ |
| msgHash | bytes32 | The hash of the message. |

#### Return Values

| Name | Type                               | Description                        |
| ---- | ---------------------------------- | ---------------------------------- |
| [0]  | enum LibBridgeStatus.MessageStatus | Returns the status of the message. |

### context

```solidity
function context() public view returns (struct IBridge.Context)
```

Get the current context

#### Return Values

| Name | Type                   | Description                  |
| ---- | ---------------------- | ---------------------------- |
| [0]  | struct IBridge.Context | Returns the current context. |

### isEtherReleased

```solidity
function isEtherReleased(bytes32 msgHash) public view returns (bool)
```

Check if the Ether associated with the given message hash has been
released.

#### Parameters

| Name    | Type    | Description              |
| ------- | ------- | ------------------------ |
| msgHash | bytes32 | The hash of the message. |

#### Return Values

| Name | Type | Description                                                   |
| ---- | ---- | ------------------------------------------------------------- |
| [0]  | bool | Returns true if the Ether has been released, false otherwise. |

### isDestChainEnabled

```solidity
function isDestChainEnabled(uint256 _chainId) public view returns (bool enabled)
```

Check if the destination chain with the given ID is enabled.

#### Parameters

| Name      | Type    | Description          |
| --------- | ------- | -------------------- |
| \_chainId | uint256 | The ID of the chain. |

#### Return Values

| Name    | Type | Description                                                        |
| ------- | ---- | ------------------------------------------------------------------ |
| enabled | bool | Returns true if the destination chain is enabled, false otherwise. |

### hashMessage

```solidity
function hashMessage(struct IBridge.Message message) public pure returns (bytes32)
```

Compute the hash of a given message.

#### Parameters

| Name    | Type                   | Description                          |
| ------- | ---------------------- | ------------------------------------ |
| message | struct IBridge.Message | The message to compute the hash for. |

#### Return Values

| Name | Type    | Description                      |
| ---- | ------- | -------------------------------- |
| [0]  | bytes32 | Returns the hash of the message. |

### getMessageStatusSlot

```solidity
function getMessageStatusSlot(bytes32 msgHash) public pure returns (bytes32)
```

Get the slot associated with a given message hash status.

#### Parameters

| Name    | Type    | Description              |
| ------- | ------- | ------------------------ |
| msgHash | bytes32 | The hash of the message. |

#### Return Values

| Name | Type    | Description                                                     |
| ---- | ------- | --------------------------------------------------------------- |
| [0]  | bytes32 | Returns the slot associated with the given message hash status. |

---

## title: ProxiedBridge

## ProxiedBridge
