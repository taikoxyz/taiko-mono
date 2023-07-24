---
title: ERC1155NameAndSymbol
---

## ERC1155NameAndSymbol

Some ERC1155 contracts implementing the name() and symbol()
functions, although they are not part of the interface

### name

```solidity
function name() external view returns (string)
```

### symbol

```solidity
function symbol() external view returns (string)
```

---

## title: ERC1155Vault

## ERC1155Vault

This vault holds all ERC1155 tokens that users have deposited.
It also manages the mapping between canonical tokens and their bridged
tokens.

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
function receiveToken(struct BaseNFTVault.CanonicalNFT ctoken, address from, address to, uint256[] tokenIds, uint256[] amounts) external
```

_This function can only be called by the bridge contract while
invoking a message call. See sendToken, which sets the data to invoke
this function._

#### Parameters

| Name     | Type                             | Description                                                                                                              |
| -------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| ctoken   | struct BaseNFTVault.CanonicalNFT | The canonical ERC1155 token which may or may not live on this chain. If not, a BridgedERC1155 contract will be deployed. |
| from     | address                          | The source address.                                                                                                      |
| to       | address                          | The destination address.                                                                                                 |
| tokenIds | uint256[]                        | The tokenIds to be sent.                                                                                                 |
| amounts  | uint256[]                        | The amounts to be sent.                                                                                                  |

### releaseToken

```solidity
function releaseToken(struct IBridge.Message message, bytes proof) external
```

Release deposited ERC1155 token(s) back to the owner on the source chain
with
a proof that the message processing on the destination Bridge has failed.

#### Parameters

| Name    | Type                   | Description                                                              |
| ------- | ---------------------- | ------------------------------------------------------------------------ |
| message | struct IBridge.Message | The message that corresponds to the ERC1155 deposit on the source chain. |
| proof   | bytes                  | The proof from the destination chain to show the message has failed.     |

### onERC1155Received

```solidity
function onERC1155Received(address, address, uint256, uint256, bytes) external pure returns (bytes4)
```

### onERC1155BatchReceived

```solidity
function onERC1155BatchReceived(address, address, uint256[], uint256[], bytes) external pure returns (bytes4)
```

---

## title: ProxiedERC1155Vault

## ProxiedERC1155Vault
