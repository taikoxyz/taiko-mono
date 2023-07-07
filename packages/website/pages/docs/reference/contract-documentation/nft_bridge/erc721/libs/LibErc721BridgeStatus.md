---
title: LibErc721BridgeStatus
---

## LibErc721BridgeStatus

This library provides functions to get and update the status of bridge
messages.

### MessageStatus

```solidity
enum MessageStatus {
  NEW,
  RETRIABLE,
  DONE,
  FAILED
}
```

### MessageStatusChangedErc721

```solidity
event MessageStatusChangedErc721(bytes32 msgHash, enum LibErc721BridgeStatus.MessageStatus status, address transactor)
```

### B_MSG_HASH_NULL

```solidity
error B_MSG_HASH_NULL()
```

### B_WRONG_CHAIN_ID

```solidity
error B_WRONG_CHAIN_ID()
```

### updateMessageStatusErc721

```solidity
function updateMessageStatusErc721(bytes32 msgHash, enum LibErc721BridgeStatus.MessageStatus status) internal
```

Updates the status of a bridge message.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| msgHash | bytes32 | The hash of the message. |
| status | enum LibErc721BridgeStatus.MessageStatus | The new status of the message. |

### getMessageStatusErc721

```solidity
function getMessageStatusErc721(bytes32 msgHash) internal view returns (enum LibErc721BridgeStatus.MessageStatus)
```

Gets the status of a bridge message.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| msgHash | bytes32 | The hash of the message. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | enum LibErc721BridgeStatus.MessageStatus | The status of the message. |

### isMessageFailedErc721

```solidity
function isMessageFailedErc721(contract AddressResolver resolver, bytes32 msgHash, uint256 destChainId, bytes proof) internal view returns (bool)
```

Checks if a bridge message has failed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| resolver | contract AddressResolver | The address resolver. |
| msgHash | bytes32 | The hash of the message. |
| destChainId | uint256 | The ID of the destination chain. |
| proof | bytes | The proof of the status of the message. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True if the message has failed, false otherwise. |

### getMessageStatusSlot

```solidity
function getMessageStatusSlot(bytes32 msgHash) internal pure returns (bytes32)
```

Gets the storage slot for a bridge message status.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| msgHash | bytes32 | The hash of the message. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | The storage slot for the message status. |

