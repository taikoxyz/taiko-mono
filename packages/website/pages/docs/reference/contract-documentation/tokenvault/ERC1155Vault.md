---
title: ERC1155NameAndSymbol
---

## ERC1155NameAndSymbol

Interface for ERC1155 contracts that provide name() and symbol()
functions. These functions may not be part of the official interface but are
used by
some contracts.

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

Transfers ERC1155 tokens to this vault and sends a message to
the destination chain so the user can receive the same (bridged) tokens
by invoking the message call.

#### Parameters

| Name | Type                                 | Description                           |
| ---- | ------------------------------------ | ------------------------------------- |
| opt  | struct BaseNFTVault.BridgeTransferOp | Option for sending the ERC1155 token. |

### receiveToken

```solidity
function receiveToken(struct BaseNFTVault.CanonicalNFT ctoken, address from, address to, uint256[] tokenIds, uint256[] amounts) external payable
```

This function can only be called by the bridge contract while
invoking a message call. See sendToken, which sets the data to invoke
this function.

#### Parameters

| Name     | Type                             | Description                                                                                                              |
| -------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| ctoken   | struct BaseNFTVault.CanonicalNFT | The canonical ERC1155 token which may or may not live on this chain. If not, a BridgedERC1155 contract will be deployed. |
| from     | address                          | The source address.                                                                                                      |
| to       | address                          | The destination address.                                                                                                 |
| tokenIds | uint256[]                        | The tokenIds to be sent.                                                                                                 |
| amounts  | uint256[]                        | The amounts to be sent.                                                                                                  |

### onMessageRecalled

```solidity
function onMessageRecalled(struct IBridge.Message message) external payable
```

Releases deposited ERC1155 token(s) back to the user on the
source chain with a proof that the message processing on the destination
Bridge has failed.

#### Parameters

| Name    | Type                   | Description                                                              |
| ------- | ---------------------- | ------------------------------------------------------------------------ |
| message | struct IBridge.Message | The message that corresponds to the ERC1155 deposit on the source chain. |

### onERC1155BatchReceived

```solidity
function onERC1155BatchReceived(address, address, uint256[], uint256[], bytes) external pure returns (bytes4)
```

### onERC1155Received

```solidity
function onERC1155Received(address, address, uint256, uint256, bytes) external pure returns (bytes4)
```

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

_See {IERC165-supportsInterface}._

---

## title: ProxiedERC1155Vault

## ProxiedERC1155Vault

Proxied version of the parent contract.
