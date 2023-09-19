---
title: BaseNFTVault
---

## BaseNFTVault

Abstract contract for bridging NFTs across different chains.

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
  uint256 fee;
  address refundTo;
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

### VAULT_INVALID_TO

```solidity
error VAULT_INVALID_TO()
```

### VAULT_INVALID_TOKEN

```solidity
error VAULT_INVALID_TOKEN()
```

### VAULT_INVALID_AMOUNT

```solidity
error VAULT_INVALID_AMOUNT()
```

### VAULT_INVALID_USER

```solidity
error VAULT_INVALID_USER()
```

### VAULT_INVALID_FROM

```solidity
error VAULT_INVALID_FROM()
```

### VAULT_INVALID_SRC_CHAIN_ID

```solidity
error VAULT_INVALID_SRC_CHAIN_ID()
```

### VAULT_INTERFACE_NOT_SUPPORTED

```solidity
error VAULT_INTERFACE_NOT_SUPPORTED()
```

### VAULT_MESSAGE_NOT_FAILED

```solidity
error VAULT_MESSAGE_NOT_FAILED()
```

### VAULT_MESSAGE_RELEASED_ALREADY

```solidity
error VAULT_MESSAGE_RELEASED_ALREADY()
```

### VAULT_TOKEN_ARRAY_MISMATCH

```solidity
error VAULT_TOKEN_ARRAY_MISMATCH()
```

### VAULT_MAX_TOKEN_PER_TXN_EXCEEDED

```solidity
error VAULT_MAX_TOKEN_PER_TXN_EXCEEDED()
```

### init

```solidity
function init(address addressManager) external
```

Initializes the contract with an address manager.

#### Parameters

| Name           | Type    | Description                         |
| -------------- | ------- | ----------------------------------- |
| addressManager | address | The address of the address manager. |
