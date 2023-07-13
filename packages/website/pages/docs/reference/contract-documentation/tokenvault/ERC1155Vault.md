---
title: ERC1155Vault
---

## ERC1155Vault

This vault holds all ERC721 and ERC1155 tokens that users have deposited.
It also manages the mapping between canonical ERC721/1155 tokens and their
bridged
tokens.

### ERC1155_INTERFACE_ID

```solidity
bytes4 ERC1155_INTERFACE_ID
```

### ERC1155_METADATA_INTERFACE_ID

```solidity
bytes4 ERC1155_METADATA_INTERFACE_ID
```

### BridgedTokenDeployed

```solidity
event BridgedTokenDeployed(uint256 srcChainId, address canonicalToken, address bridgedToken)
```

### TokenSent

```solidity
event TokenSent(bytes32 msgHash, address from, address to, uint256 destChainId, address token, uint256 tokenId, uint256 amount)
```

### TokenReleased

```solidity
event TokenReleased(bytes32 msgHash, address from, address token, uint256 tokenId, uint256 amount)
```

### TokenReceived

```solidity
event TokenReceived(bytes32 msgHash, address from, address to, uint256 srcChainId, address token, uint256 tokenId, uint256 amount)
```

### sendToken

```solidity
function sendToken(struct BaseNFTVault.BridgeTransferOp opt) external payable
```

Transfers ERC1155 tokens to this vault and sends a message to the
destination chain so the user can receive the same (bridged) tokens
by invoking the message call.

#### Parameters

| Name | Type                                 | Description                           |
| ---- | ------------------------------------ | ------------------------------------- |
| opt  | struct BaseNFTVault.BridgeTransferOp | Option for sending the ERC1155 token. |

### receiveToken

```solidity
function receiveToken(struct BaseNFTVault.CanonicalNFT canonicalToken, address from, address to, uint256 tokenId, uint256 amount) external
```

_This function can only be called by the bridge contract while
invoking a message call. See sendToken, which sets the data to invoke
this function._

#### Parameters

| Name           | Type                             | Description                                                                                                              |
| -------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| canonicalToken | struct BaseNFTVault.CanonicalNFT | The canonical ERC1155 token which may or may not live on this chain. If not, a BridgedERC1155 contract will be deployed. |
| from           | address                          | The source address.                                                                                                      |
| to             | address                          | The destination address.                                                                                                 |
| tokenId        | uint256                          | The tokenId to be sent.                                                                                                  |
| amount         | uint256                          | The amount to be sent.                                                                                                   |

### releaseToken

```solidity
function releaseToken(struct IBridge.Message message, bytes proof) external
```

### onERC1155Received

```solidity
function onERC1155Received(address, address, uint256, uint256, bytes) external pure returns (bytes4)
```

### onERC1155BatchReceived

```solidity
function onERC1155BatchReceived(address, address, uint256[], uint256[], bytes) external pure returns (bytes4)
```

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

_See {IERC165-supportsInterface}._

### decodeTokenData

```solidity
function decodeTokenData(bytes dataWithSelector) public pure returns (struct BaseNFTVault.CanonicalNFT, address, address, uint256, uint256)
```

_Decodes the data which was abi.encodeWithSelector() encoded. We need
this to get to know
to whom / which token and tokenId we shall release._

---

## title: ProxiedERC1155Vault

## ProxiedERC1155Vault
