---
title: Bridge
---

## Bridge

See the documentation for {IBridge}.

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

### init

```solidity
function init(address _addressManager) external
```

Initializes the contract.

#### Parameters

| Name             | Type    | Description                                   |
| ---------------- | ------- | --------------------------------------------- |
| \_addressManager | address | The address of the {AddressManager} contract. |

### sendMessage

```solidity
function sendMessage(struct IBridge.Message message) external payable returns (bytes32 msgHash)
```

Sends a message from the current chain to the destination chain
specified in the message.

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

Recalls a failed message on its source chain

#### Parameters

| Name    | Type                   | Description                              |
| ------- | ---------------------- | ---------------------------------------- |
| message | struct IBridge.Message | The message to be recalled.              |
| proof   | bytes                  | The proof of message processing failure. |

### isMessageSent

```solidity
function isMessageSent(bytes32 msgHash) public view virtual returns (bool)
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
function isMessageReceived(bytes32 msgHash, uint256 srcChainId, bytes proof) public view virtual returns (bool)
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
function isMessageFailed(bytes32 msgHash, uint256 destChainId, bytes proof) public view virtual returns (bool)
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
function isMessageRecalled(bytes32 msgHash) public view returns (bool)
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

### getMessageStatus

```solidity
function getMessageStatus(bytes32 msgHash) public view virtual returns (enum LibBridgeStatus.MessageStatus)
```

Gets the execution status of the message with the given hash on
its destination chain.

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

Gets the current context.

#### Return Values

| Name | Type                   | Description |
| ---- | ---------------------- | ----------- |
| [0]  | struct IBridge.Context |             |

### isDestChainEnabled

```solidity
function isDestChainEnabled(uint256 _chainId) public view returns (bool enabled)
```

Checks if the destination chain with the given ID is enabled.

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

Computes the hash of a given message.

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

Gets the slot associated with a given message hash status.

#### Parameters

| Name    | Type    | Description              |
| ------- | ------- | ------------------------ |
| msgHash | bytes32 | The hash of the message. |

#### Return Values

| Name | Type    | Description                                                     |
| ---- | ------- | --------------------------------------------------------------- |
| [0]  | bytes32 | Returns the slot associated with the given message hash status. |

### shouldCheckProof

```solidity
function shouldCheckProof() internal pure virtual returns (bool)
```

Tells if we need to check real proof or it is a test.

#### Return Values

| Name | Type | Description                                                  |
| ---- | ---- | ------------------------------------------------------------ |
| [0]  | bool | Returns true if this contract, or can be false if mock/test. |

---

## title: ProxiedBridge

## ProxiedBridge

Proxied version of the parent contract.
