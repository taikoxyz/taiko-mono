---
title: LibVaultUtils
---

## LibVaultUtils

### MAX_TOKEN_PER_TXN

```solidity
uint256 MAX_TOKEN_PER_TXN
```

### VAULT_INVALID_SENDER

```solidity
error VAULT_INVALID_SENDER()
```

Thrown when the sender in a message context is invalid.
This could happen if the sender isn't the expected token vault on the
source chain.

### VAULT_INVALID_TOKEN

```solidity
error VAULT_INVALID_TOKEN()
```

Thrown when token contract is 0 address.

### VAULT_INVALID_TO

```solidity
error VAULT_INVALID_TO()
```

Thrown when the 'to' is an invalid address.

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

### VAULT_INVALID_AMOUNT

```solidity
error VAULT_INVALID_AMOUNT()
```

Thrown when the amount in a transaction is invalid.
This could happen if the amount is zero or exceeds the sender's balance.

### deployProxy

```solidity
function deployProxy(address implementation, address owner, bytes initializationData) external returns (address proxy)
```

_Deploys a contract (via proxy)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| implementation | address | The new implementation address |
| owner | address | The owner of the proxy admin contract |
| initializationData | bytes | Data for the initialization |

### checkValidContext

```solidity
function checkValidContext(bytes32 validSender, address resolver) external view returns (struct IBridge.Context ctx)
```

_Checks if context is valid_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| validSender | bytes32 | The valid sender to be allowed |
| resolver | address | The address of the resolver |

### hashAndCheckToken

```solidity
function hashAndCheckToken(struct IBridge.Message message, address bridgeAddress, address tokenAddress) external pure returns (bytes32 msgHash)
```

_Checks if token is invalid and returns the message hash_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| message | struct IBridge.Message | The bridged message struct data |
| bridgeAddress | address | The bridge contract |
| tokenAddress | address | The token address to be checked |

### checkIfValidAddresses

```solidity
function checkIfValidAddresses(address vault, address to, address token) external pure
```

### checkIfValidAmounts

```solidity
function checkIfValidAmounts(uint256[] amounts, uint256[] tokenIds, bool isERC721) external pure
```

