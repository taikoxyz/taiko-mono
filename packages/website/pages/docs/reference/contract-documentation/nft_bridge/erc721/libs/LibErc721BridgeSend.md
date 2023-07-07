---
title: LibErc721BridgeSend
---

## LibErc721BridgeSend

Entry point for starting a bridge transaction.

### B_INCORRECT_VALUE

```solidity
error B_INCORRECT_VALUE()
```

### ERC721_B_OWNER_IS_NULL

```solidity
error ERC721_B_OWNER_IS_NULL()
```

### ERC721_B_WRONG_CHAIN_ID

```solidity
error ERC721_B_WRONG_CHAIN_ID()
```

### ERC721_B_WRONG_TO_ADDRESS

```solidity
error ERC721_B_WRONG_TO_ADDRESS()
```

### ERC721_B_ARRAY_LENGTH_DO_NOT_MATCH

```solidity
error ERC721_B_ARRAY_LENGTH_DO_NOT_MATCH()
```

### sendMessageErc721

```solidity
function sendMessageErc721(struct LibErc721BridgeData.State state, contract AddressResolver resolver, struct IErc721Bridge.Message message) internal returns (bytes32 msgHash)
```

Send a message to the Bridge with the details of the request.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state | struct LibErc721BridgeData.State | The current state of the Bridge |
| resolver | contract AddressResolver | The address resolver |
| message | struct IErc721Bridge.Message | Specifies the `depositValue`, `callValue`, and `processingFee`. These must sum to `msg.value`. It also specifies the `destChainId` which must have a `bridge` address set on the AddressResolver and differ from the current chain ID. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| msgHash | bytes32 | The hash of the sent message. This is picked up by an off-chain relayer which indicates a bridge message has been sent and is ready to be processed on the destination chain. |

### isDestChainEnabled

```solidity
function isDestChainEnabled(contract AddressResolver resolver, uint256 chainId) internal view returns (bool enabled, address destBridge)
```

Check if the destination chain is enabled.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| resolver | contract AddressResolver | The address resolver |
| chainId | uint256 | The destination chain id |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| enabled | bool | True if the destination chain is enabled |
| destBridge | address | The bridge of the destination chain |

### isMessageSentErc721

```solidity
function isMessageSentErc721(contract AddressResolver resolver, bytes32 msgHash) internal view returns (bool)
```

Check if the message was sent.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| resolver | contract AddressResolver | The address resolver |
| msgHash | bytes32 | The hash of the sent message |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True if the message was sent |

### isMessageReceivedErc721

```solidity
function isMessageReceivedErc721(contract AddressResolver resolver, bytes32 msgHash, uint256 srcChainId, bytes proof) internal view returns (bool)
```

Check if the message was received.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| resolver | contract AddressResolver | The address resolver |
| msgHash | bytes32 | The hash of the received message |
| srcChainId | uint256 | The id of the source chain |
| proof | bytes | The proof of message receipt |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True if the message was received |

