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

### onMessageRecalled

```solidity
function onMessageRecalled(struct IBridge.Message message) external returns (bytes4)
```

Release deposited ERC721 token(s) back to the owner on the source chain
with
a proof that the message processing on the destination Bridge has failed.

#### Parameters

| Name    | Type                   | Description                                                             |
| ------- | ---------------------- | ----------------------------------------------------------------------- |
| message | struct IBridge.Message | The message that corresponds to the ERC721 deposit on the source chain. |

### onERC721Received

```solidity
function onERC721Received(address, address, uint256, bytes) external pure returns (bytes4)
```

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

_See {IERC165-supportsInterface}._

---

## title: ProxiedERC721Vault

## ProxiedERC721Vault
