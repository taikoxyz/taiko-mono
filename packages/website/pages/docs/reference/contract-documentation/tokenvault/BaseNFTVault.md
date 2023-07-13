---
title: BaseNFTVault
---

## BaseNFTVault

This vault is a parent contract for ERC721 and ERC1155 vaults.

### CanonicalNFT

```solidity
struct CanonicalNFT {
  uint256 srcChainId;
  address tokenAddr;
  string symbol;
  string name;
  string uri;
}
```

### BridgeTransferOp

```solidity
struct BridgeTransferOp {
  uint256 destChainId;
  address to;
  address token;
  string baseTokenUri;
  uint256 tokenId;
  uint256 amount;
  uint256 gasLimit;
  uint256 processingFee;
  address refundAddress;
  string memo;
}
```

### isBridgedToken

```solidity
mapping(address => bool) isBridgedToken
```

### bridgedToCanonical

```solidity
mapping(address => struct BaseNFTVault.CanonicalNFT) bridgedToCanonical
```

### canonicalToBridged

```solidity
mapping(uint256 => mapping(address => address)) canonicalToBridged
```

### setBridgedToken

```solidity
function setBridgedToken(address bridgedToken, struct BaseNFTVault.CanonicalNFT canonical) internal
```

#### Parameters

| Name         | Type                             | Description                        |
| ------------ | -------------------------------- | ---------------------------------- |
| bridgedToken | address                          | The bridged token contract address |
| canonical    | struct BaseNFTVault.CanonicalNFT | The canonical NFT                  |

### msgHashIfValidRequest

```solidity
function msgHashIfValidRequest(struct IBridge.Message message, bytes proof, address tokenAddress) internal view returns (bytes32 msgHash)
```

#### Parameters

| Name         | Type                   | Description                     |
| ------------ | ---------------------- | ------------------------------- |
| message      | struct IBridge.Message | The bridged message struct data |
| proof        | bytes                  | The proof bytes                 |
| tokenAddress | address                | The token address to be checked |

### extractCalldata

```solidity
function extractCalldata(bytes calldataWithSelector) internal pure returns (bytes)
```
