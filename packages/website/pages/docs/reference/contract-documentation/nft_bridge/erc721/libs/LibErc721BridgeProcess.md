---
title: LibErc721BridgeProcess
---

## LibErc721BridgeProcess

This library provides functions for processing bridge messages on the
destination chain.

### ERC721_B_FORBIDDEN

```solidity
error ERC721_B_FORBIDDEN()
```

### ERC721_B_SIGNAL_NOT_RECEIVED

```solidity
error ERC721_B_SIGNAL_NOT_RECEIVED()
```

### ERC721_B_STATUS_MISMATCH

```solidity
error ERC721_B_STATUS_MISMATCH()
```

### ERC721_B_WRONG_CHAIN_ID

```solidity
error ERC721_B_WRONG_CHAIN_ID()
```

### processMessageErc721

```solidity
function processMessageErc721(struct LibErc721BridgeData.State state, contract AddressResolver resolver, struct IErc721Bridge.Message message, bytes proof) internal
```

Process the bridge message on the destination chain. It can be called by
any address, including `message.owner`.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state | struct LibErc721BridgeData.State | The bridge state.  // @Jeff: Not needed here in erc721 bridge, since we dont have message.data() to invoke and no reentrancy attack for fungible tokens..(?) |
| resolver | contract AddressResolver | The address resolver. |
| message | struct IErc721Bridge.Message | The message to process. |
| proof | bytes | The msgHash proof from the source chain. |

