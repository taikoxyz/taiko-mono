---
title: ERC721Vault
---

## ERC721Vault

This vault holds all ERC721 tokens that users have deposited.
It also manages the mapping between canonical tokens and their bridged
tokens.

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
function receiveToken(struct BaseNFTVault.CanonicalNFT ctoken, address from, address to, uint256[] tokenIds) external
```

_This function can only be called by the bridge contract while
invoking a message call. See sendToken, which sets the data to invoke
this function._

#### Parameters

| Name     | Type                             | Description                                                                                                         |
| -------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| ctoken   | struct BaseNFTVault.CanonicalNFT | The ctoken ERC721 token which may or may not live on this chain. If not, a BridgedERC721 contract will be deployed. |
| from     | address                          | The source address.                                                                                                 |
| to       | address                          | The destination address.                                                                                            |
| tokenIds | uint256[]                        | The tokenId array to be sent.                                                                                       |

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
function decodeMessageData(bytes dataWithSelector) public pure returns (struct BaseNFTVault.CanonicalNFT nft, address owner, address to, uint256[] tokenIds)
```

Decodes the data which was abi.encodeWithSelector() encoded.

#### Parameters

| Name             | Type  | Description                               |
| ---------------- | ----- | ----------------------------------------- |
| dataWithSelector | bytes | Data encoded with abi.encodedWithSelector |

#### Return Values

| Name     | Type                             | Description                     |
| -------- | -------------------------------- | ------------------------------- |
| nft      | struct BaseNFTVault.CanonicalNFT | CanonicalNFT data               |
| owner    | address                          | Owner of the message            |
| to       | address                          | The to address messages sent to |
| tokenIds | uint256[]                        | The tokenIds                    |

---

## title: ProxiedERC721Vault

## ProxiedERC721Vault
