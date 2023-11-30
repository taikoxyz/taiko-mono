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

_Labeled in AddressResolver as "erc1155_vault"_

### sendToken

```solidity
function sendToken(struct BaseNFTVault.BridgeTransferOp op) external payable returns (struct IBridge.Message _message)
```

Transfers ERC1155 tokens to this vault and sends a message to
the destination chain so the user can receive the same (bridged) tokens
by invoking the message call.

#### Parameters

| Name | Type                                 | Description                           |
| ---- | ------------------------------------ | ------------------------------------- |
| op   | struct BaseNFTVault.BridgeTransferOp | Option for sending the ERC1155 token. |

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
function onMessageRecalled(struct IBridge.Message message, bytes32 msgHash) external payable
```

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

### name

```solidity
function name() public pure returns (bytes32)
```

---

## title: ProxiedSingletonERC1155Vault

## ProxiedSingletonERC1155Vault

Proxied version of the parent contract.

_Deploy this contract as a singleton per chain for use by multiple L2s
or L3s. No singleton check is performed within the code; it's the deployer's
responsibility to ensure this. Singleton deployment is essential for
enabling multi-hop bridging across all Taiko L2/L3s._
