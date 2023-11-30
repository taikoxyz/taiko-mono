---
title: ERC721Vault
---

## ERC721Vault

This vault holds all ERC721 tokens that users have deposited.
It also manages the mapping between canonical tokens and their bridged
tokens.

_Labeled in AddressResolver as "erc721_vault"_

### sendToken

```solidity
function sendToken(struct BaseNFTVault.BridgeTransferOp op) external payable returns (struct IBridge.Message _message)
```

Transfers ERC721 tokens to this vault and sends a message to the
destination chain so the user can receive the same (bridged) tokens
by invoking the message call.

#### Parameters

| Name | Type                                 | Description                          |
| ---- | ------------------------------------ | ------------------------------------ |
| op   | struct BaseNFTVault.BridgeTransferOp | Option for sending the ERC721 token. |

### receiveToken

```solidity
function receiveToken(struct BaseNFTVault.CanonicalNFT ctoken, address from, address to, uint256[] tokenIds) external payable
```

Receive bridged ERC721 tokens and handle them accordingly.

#### Parameters

| Name     | Type                             | Description                                      |
| -------- | -------------------------------- | ------------------------------------------------ |
| ctoken   | struct BaseNFTVault.CanonicalNFT | Canonical NFT data for the token being received. |
| from     | address                          | Source address.                                  |
| to       | address                          | Destination address.                             |
| tokenIds | uint256[]                        | Array of token IDs being received.               |

### onMessageRecalled

```solidity
function onMessageRecalled(struct IBridge.Message message, bytes32 msgHash) external payable
```

### onERC721Received

```solidity
function onERC721Received(address, address, uint256, bytes) external pure returns (bytes4)
```

\_Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
by `operator` from `from`, this function is called.

It must return its Solidity selector to confirm the token transfer.
If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.

The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.\_

### name

```solidity
function name() public pure returns (bytes32)
```

---

## title: ProxiedSingletonERC721Vault

## ProxiedSingletonERC721Vault

Proxied version of the parent contract.

_Deploy this contract as a singleton per chain for use by multiple L2s
or L3s. No singleton check is performed within the code; it's the deployer's
responsibility to ensure this. Singleton deployment is essential for
enabling multi-hop bridging across all Taiko L2/L3s._
