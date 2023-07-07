---
title: LibErc721BridgeRelease
---

## LibErc721BridgeRelease

This library provides functions for releasing tokens related to message
execution on the Bridge.

### ERC721_B_TOKEN_RELEASED_ALREADY

```solidity
error ERC721_B_TOKEN_RELEASED_ALREADY()
```

### ERC721_B_FAILED_TRANSFER

```solidity
error ERC721_B_FAILED_TRANSFER()
```

### ERC721_B_MSG_NOT_FAILED

```solidity
error ERC721_B_MSG_NOT_FAILED()
```

### ERC721_B_OWNER_IS_NULL

```solidity
error ERC721_B_OWNER_IS_NULL()
```

### ERC721_B_WRONG_CHAIN_ID

```solidity
error ERC721_B_WRONG_CHAIN_ID()
```

### releaseTokensErc721

```solidity
function releaseTokensErc721(struct LibErc721BridgeData.State state, contract AddressResolver resolver, struct IErc721Bridge.Message message, bytes proof) internal
```

Release Token(s) to the message owner

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state | struct LibErc721BridgeData.State | The current state of the Bridge |
| resolver | contract AddressResolver | The AddressResolver instance |
| message | struct IErc721Bridge.Message | The message whose associated Ether should be released |
| proof | bytes | The proof data |

