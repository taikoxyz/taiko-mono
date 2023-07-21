---
title: BaseNFTVault
---

## BaseNFTVault

This vault is a parent contract for ERC721 and ERC1155 vaults.

### CanonicalNFT

```solidity
struct CanonicalNFT {
  uint256 chainId;
  address addr;
  string symbol;
  string name;
}
```

### BridgeTransferOp

```solidity
struct BridgeTransferOp {
  uint256 destChainId;
  address to;
  address token;
  uint256[] tokenIds;
  uint256[] amounts;
  uint256 gasLimit;
  uint256 processingFee;
  address refundAddress;
  string memo;
}
```

### ERC1155_INTERFACE_ID

```solidity
bytes4 ERC1155_INTERFACE_ID
```

### ERC721_INTERFACE_ID

```solidity
bytes4 ERC721_INTERFACE_ID
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

### MAX_TOKEN_PER_TXN

```solidity
uint256 MAX_TOKEN_PER_TXN
```

### BridgedTokenDeployed

```solidity
event BridgedTokenDeployed(uint256 chainId, address ctoken, address btoken, string ctokenSymbol, string ctokenName)
```

### TokenSent

```solidity
event TokenSent(bytes32 msgHash, address from, address to, uint256 destChainId, address token, uint256[] tokenIds, uint256[] amounts)
```

### TokenReleased

```solidity
event TokenReleased(bytes32 msgHash, address from, address token, uint256[] tokenIds, uint256[] amounts)
```

### TokenReceived

```solidity
event TokenReceived(bytes32 msgHash, address from, address to, uint256 srcChainId, address token, uint256[] tokenIds, uint256[] amounts)
```

### VAULT_TOKEN_ARRAY_MISMATCH

```solidity
error VAULT_TOKEN_ARRAY_MISMATCH()
```

Thrown when the length of the tokenIds array and the amounts
array differs.

### VAULT_MAX_TOKEN_PER_TXN_EXCEEDED

```solidity
error VAULT_MAX_TOKEN_PER_TXN_EXCEEDED()
```

Thrown when more tokens are about to be bridged than allowed.

### onlyValidAmounts

```solidity
modifier onlyValidAmounts(uint256[] amounts, uint256[] tokenIds, bool isERC721)
```

### setBridgedToken

```solidity
function setBridgedToken(address btoken, struct BaseNFTVault.CanonicalNFT ctoken) internal
```

#### Parameters

| Name   | Type                             | Description               |
| ------ | -------------------------------- | ------------------------- |
| btoken | address                          | The bridged token address |
| ctoken | struct BaseNFTVault.CanonicalNFT | The canonical token       |

### hashAndMarkMsgReleased

```solidity
function hashAndMarkMsgReleased(struct IBridge.Message message, bytes proof, address tokenAddress) internal returns (bytes32 msgHash)
```

#### Parameters

| Name         | Type                   | Description                     |
| ------------ | ---------------------- | ------------------------------- |
| message      | struct IBridge.Message | The bridged message struct data |
| proof        | bytes                  | The proof bytes                 |
| tokenAddress | address                | The token address to be checked |
