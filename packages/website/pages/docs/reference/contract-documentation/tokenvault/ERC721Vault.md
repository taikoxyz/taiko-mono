---
title: ERC721Vault
---

## ERC721Vault

This vault holds all ERC721 tokens that users have deposited.
It also manages the mapping between canonical ERC721 tokens and their bridged
tokens.

### ERC721_INTERFACE_ID

```solidity
bytes4 ERC721_INTERFACE_ID
```

### ERC721_METADATA_INTERFACE_ID

```solidity
bytes4 ERC721_METADATA_INTERFACE_ID
```

### ERC721_ENUMERABLE_INTERFACE_ID

```solidity
bytes4 ERC721_ENUMERABLE_INTERFACE_ID
```

### BridgedTokenDeployed

```solidity
event BridgedTokenDeployed(uint256 srcChainId, address canonicalToken, address bridgedToken, string canonicalTokenSymbol, string canonicalTokenName)
```

### TokenSent

```solidity
event TokenSent(bytes32 msgHash, address from, address to, uint256 destChainId, address token, uint256 tokenId)
```

### TokenReleased

```solidity
event TokenReleased(bytes32 msgHash, address from, address token, uint256 tokenId)
```

### TokenReceived

```solidity
event TokenReceived(bytes32 msgHash, address from, address to, uint256 srcChainId, address token, uint256 tokenId)
```

### sendToken

```solidity
function sendToken(struct BaseNFTVault.BridgeTransferOp opt) external payable
```

Transfers ERC721 tokens to this vault and sends a message to the
destination chain so the user can receive the same (bridged) tokens
by invoking the message call.

#### Parameters

| Name | Type                                 | Description                          |
| ---- | ------------------------------------ | ------------------------------------ |
| opt  | struct BaseNFTVault.BridgeTransferOp | Option for sending the ERC721 token. |

### receiveToken

```solidity
function receiveToken(struct BaseNFTVault.CanonicalNFT canonicalToken, address from, address to, uint256 tokenId) external
```

_This function can only be called by the bridge contract while
invoking a message call. See sendToken, which sets the data to invoke
this function._

#### Parameters

| Name           | Type                             | Description                                                                                                            |
| -------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| canonicalToken | struct BaseNFTVault.CanonicalNFT | The canonical ERC721 token which may or may not live on this chain. If not, a BridgedERC721 contract will be deployed. |
| from           | address                          | The source address.                                                                                                    |
| to             | address                          | The destination address.                                                                                               |
| tokenId        | uint256                          | The tokenId to be sent.                                                                                                |

### releaseToken

```solidity
function releaseToken(struct IBridge.Message message, bytes proof) external
```

### onERC721Received

```solidity
function onERC721Received(address, address, uint256, bytes) external pure returns (bytes4)
```

### decodeMessageData

```solidity
function decodeMessageData(bytes dataWithSelector) public pure returns (struct BaseNFTVault.CanonicalNFT, address, address, uint256)
```

_Decodes the data which was abi.encodeWithSelector() encoded. We need
this to get to know
to whom / which token and tokenId we shall release._

---

## title: ProxiedERC721Vault

## ProxiedERC721Vault
