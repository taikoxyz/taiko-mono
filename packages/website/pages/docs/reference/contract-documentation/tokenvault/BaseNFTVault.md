---
title: BaseNFTVault
---

## BaseNFTVault

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

Thrown when the `to` address in an operation is invalid.
This can happen if it's zero address or the address of the token vault.

### VAULT_INVALID_TOKEN

```solidity
error VAULT_INVALID_TOKEN()
```

Thrown when the token address in a transaction is invalid.
This could happen if the token address is zero or doesn't conform to the
ERC20 standard.

### VAULT_INVALID_AMOUNT

```solidity
error VAULT_INVALID_AMOUNT()
```

Thrown when the amount in a transaction is invalid.
This could happen if the amount is zero or exceeds the sender's balance.

### VAULT_INVALID_OWNER

```solidity
error VAULT_INVALID_OWNER()
```

Thrown when the owner address in a message is invalid.
This could happen if the owner address is zero or doesn't match the
expected owner.

### VAULT_INVALID_SENDER

```solidity
error VAULT_INVALID_SENDER()
```

Thrown when the sender in a message context is invalid.
This could happen if the sender isn't the expected token vault on the
source chain.

### VAULT_INVALID_SRC_CHAIN_ID

```solidity
error VAULT_INVALID_SRC_CHAIN_ID()
```

Thrown when the source chain ID in a message is invalid.
This could happen if the source chain ID doesn't match the current
chain's ID.

### VAULT_INTERFACE_NOT_SUPPORTED

```solidity
error VAULT_INTERFACE_NOT_SUPPORTED()
```

Thrown when the interface (ERC1155/ERC721) is not supported.

### VAULT_MESSAGE_NOT_FAILED

```solidity
error VAULT_MESSAGE_NOT_FAILED()
```

Thrown when a message has not failed.
This could happen if trying to release a message deposit without proof of
failure.

### VAULT_MESSAGE_RELEASED_ALREADY

```solidity
error VAULT_MESSAGE_RELEASED_ALREADY()
```

Thrown when a message has already released

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

### init

```solidity
function init(address addressManager) external
```
