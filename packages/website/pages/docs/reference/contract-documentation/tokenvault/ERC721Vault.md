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
function onMessageRecalled(struct IBridge.Message message) external payable
```

Release deposited ERC721 token(s) back to the user on the source
chain with a proof that the message processing on the destination Bridge
has failed.

#### Parameters

| Name    | Type                   | Description                                                             |
| ------- | ---------------------- | ----------------------------------------------------------------------- |
| message | struct IBridge.Message | The message that corresponds to the ERC721 deposit on the source chain. |

### onERC721Received

```solidity
function onERC721Received(address, address, uint256, bytes) external pure returns (bytes4)
```

\_Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
by `operator` from `from`, this function is called.

It must return its Solidity selector to confirm the token transfer.
If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.

The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.\_

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

\_Returns true if this contract implements the interface defined by
`interfaceId`. See the corresponding
https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
to learn more about how these ids are created.

This function call must use less than 30 000 gas.\_

---

## title: ProxiedERC721Vault

## ProxiedERC721Vault

Proxied version of the parent contract.
