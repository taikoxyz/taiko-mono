---
title: Bridge
---

## Bridge

See the documentation for {IBridge}.

_Labeled in AddressResolver as "bridge"
The code hash for the same address on L1 and L2 may be different._

### Status

```solidity
enum Status {
  NEW,
  RETRIABLE,
  DONE,
  FAILED
}
```

### PLACEHOLDER

```solidity
uint256 PLACEHOLDER
```

### nextMessageId

```solidity
uint128 nextMessageId
```

### isMessageRecalled

```solidity
mapping(bytes32 => bool) isMessageRecalled
```

### messageStatus

```solidity
mapping(bytes32 => enum Bridge.Status) messageStatus
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

### DestChainEnabled

```solidity
event DestChainEnabled(uint64 chainId, bool enabled)
```

### MessageStatusChanged

```solidity
event MessageStatusChanged(bytes32 msgHash, enum Bridge.Status status)
```

### B_INVALID_CHAINID

```solidity
error B_INVALID_CHAINID()
```

### B_INVALID_CONTEXT

```solidity
error B_INVALID_CONTEXT()
```

### B_INVALID_GAS_LIMIT

```solidity
error B_INVALID_GAS_LIMIT()
```

### B_INVALID_SIGNAL

```solidity
error B_INVALID_SIGNAL()
```

### B_INVALID_USER

```solidity
error B_INVALID_USER()
```

### B_INVALID_VALUE

```solidity
error B_INVALID_VALUE()
```

### B_NON_RETRIABLE

```solidity
error B_NON_RETRIABLE()
```

### B_NOT_FAILED

```solidity
error B_NOT_FAILED()
```

### B_NOT_RECEIVED

```solidity
error B_NOT_RECEIVED()
```

### B_PERMISSION_DENIED

```solidity
error B_PERMISSION_DENIED()
```

### B_RECALLED_ALREADY

```solidity
error B_RECALLED_ALREADY()
```

### B_STATUS_MISMATCH

```solidity
error B_STATUS_MISMATCH()
```

### sameChain

```solidity
modifier sameChain(uint64 chainId)
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
function sendMessage(struct IBridge.Message message) external payable returns (bytes32 msgHash, struct IBridge.Message _message)
```

Sends a message to the destination chain and takes custody
of Ether required in this contract. All extra Ether will be refunded.

#### Parameters

| Name    | Type                   | Description             |
| ------- | ---------------------- | ----------------------- |
| message | struct IBridge.Message | The message to be sent. |

#### Return Values

| Name      | Type                   | Description                   |
| --------- | ---------------------- | ----------------------------- |
| msgHash   | bytes32                | The hash of the sent message. |
| \_message | struct IBridge.Message |                               |

### recallMessage

```solidity
function recallMessage(struct IBridge.Message message, bytes proof) external
```

Recalls a failed message on its source chain, releasing
associated assets.

_This function checks if the message failed on the source chain and
releases associated Ether or tokens._

#### Parameters

| Name    | Type                   | Description                                            |
| ------- | ---------------------- | ------------------------------------------------------ |
| message | struct IBridge.Message | The message whose associated Ether should be released. |
| proof   | bytes                  | The merkle inclusion proof.                            |

### processMessage

```solidity
function processMessage(struct IBridge.Message message, bytes proof) external
```

Processes a bridge message on the destination chain. This
function is callable by any address, including the `message.owner`.

_The process begins by hashing the message and checking the message
status in the bridge If the status is "NEW", the message is invoked. The
status is updated accordingly, and processing fees are refunded as
needed._

#### Parameters

| Name    | Type                   | Description                  |
| ------- | ---------------------- | ---------------------------- |
| message | struct IBridge.Message | The message to be processed. |
| proof   | bytes                  | The merkle inclusion proof.  |

### retryMessage

```solidity
function retryMessage(struct IBridge.Message message, bool isLastAttempt) external
```

Retries to invoke the messageCall after releasing associated
Ether and tokens.

_This function can be called by any address, including the
`message.owner`.
It attempts to invoke the messageCall and updates the message status
accordingly._

#### Parameters

| Name          | Type                   | Description                                                 |
| ------------- | ---------------------- | ----------------------------------------------------------- |
| message       | struct IBridge.Message | The message to retry.                                       |
| isLastAttempt | bool                   | Specifies if this is the last attempt to retry the message. |

### isMessageSent

```solidity
function isMessageSent(struct IBridge.Message message) public view returns (bool)
```

Checks if the message was sent.

#### Parameters

| Name    | Type                   | Description  |
| ------- | ---------------------- | ------------ |
| message | struct IBridge.Message | The message. |

#### Return Values

| Name | Type | Description                   |
| ---- | ---- | ----------------------------- |
| [0]  | bool | True if the message was sent. |

### proveMessageFailed

```solidity
function proveMessageFailed(struct IBridge.Message message, bytes proof) public view returns (bool)
```

Checks if a msgHash has failed on its destination chain.

#### Parameters

| Name    | Type                   | Description                 |
| ------- | ---------------------- | --------------------------- |
| message | struct IBridge.Message | The message.                |
| proof   | bytes                  | The merkle inclusion proof. |

#### Return Values

| Name | Type | Description                                              |
| ---- | ---- | -------------------------------------------------------- |
| [0]  | bool | Returns true if the message has failed, false otherwise. |

### proveMessageReceived

```solidity
function proveMessageReceived(struct IBridge.Message message, bytes proof) public view returns (bool)
```

Checks if a msgHash has failed on its destination chain.

#### Parameters

| Name    | Type                   | Description                 |
| ------- | ---------------------- | --------------------------- |
| message | struct IBridge.Message | The message.                |
| proof   | bytes                  | The merkle inclusion proof. |

#### Return Values

| Name | Type | Description                                              |
| ---- | ---- | -------------------------------------------------------- |
| [0]  | bool | Returns true if the message has failed, false otherwise. |

### isDestChainEnabled

```solidity
function isDestChainEnabled(uint64 chainId) public view returns (bool enabled, address destBridge)
```

Checks if the destination chain is enabled.

#### Parameters

| Name    | Type   | Description               |
| ------- | ------ | ------------------------- |
| chainId | uint64 | The destination chain ID. |

#### Return Values

| Name       | Type    | Description                               |
| ---------- | ------- | ----------------------------------------- |
| enabled    | bool    | True if the destination chain is enabled. |
| destBridge | address | The bridge of the destination chain.      |

### context

```solidity
function context() public view returns (struct IBridge.Context)
```

Gets the current context.

#### Return Values

| Name | Type                   | Description |
| ---- | ---------------------- | ----------- |
| [0]  | struct IBridge.Context |             |

### hashMessage

```solidity
function hashMessage(struct IBridge.Message message) public pure returns (bytes32)
```

Hash the message

---

## title: ProxiedSingletonBridge

## ProxiedSingletonBridge

Proxied version of the parent contract.

_Deploy this contract as a singleton per chain for use by multiple L2s
or L3s. No singleton check is performed within the code; it's the deployer's
responsibility to ensure this. Singleton deployment is essential for
enabling multi-hop bridging across all Taiko L2/L3s._
