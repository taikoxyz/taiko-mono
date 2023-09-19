---
title: LibVaultUtils
---

## LibVaultUtils

### MAX_TOKEN_PER_TXN

```solidity
uint256 MAX_TOKEN_PER_TXN
```

### VAULT_INVALID_FROM

```solidity
error VAULT_INVALID_FROM()
```

### VAULT_INVALID_TOKEN

```solidity
error VAULT_INVALID_TOKEN()
```

### VAULT_INVALID_TO

```solidity
error VAULT_INVALID_TO()
```

### VAULT_TOKEN_ARRAY_MISMATCH

```solidity
error VAULT_TOKEN_ARRAY_MISMATCH()
```

### VAULT_MAX_TOKEN_PER_TXN_EXCEEDED

```solidity
error VAULT_MAX_TOKEN_PER_TXN_EXCEEDED()
```

### VAULT_INVALID_AMOUNT

```solidity
error VAULT_INVALID_AMOUNT()
```

### deployProxy

```solidity
function deployProxy(address implementation, address owner, bytes initializationData) external returns (address proxy)
```

_Deploys a contract (via proxy)_

#### Parameters

| Name               | Type    | Description                           |
| ------------------ | ------- | ------------------------------------- |
| implementation     | address | The new implementation address        |
| owner              | address | The owner of the proxy admin contract |
| initializationData | bytes   | Data for the initialization           |

### checkValidContext

```solidity
function checkValidContext(bytes32 validSender, address resolver) external view returns (struct IBridge.Context ctx)
```

_Checks if context is valid_

#### Parameters

| Name        | Type    | Description                    |
| ----------- | ------- | ------------------------------ |
| validSender | bytes32 | The valid sender to be allowed |
| resolver    | address | The address of the resolver    |

### hashAndCheckToken

```solidity
function hashAndCheckToken(struct IBridge.Message message, address bridgeAddress, address tokenAddress) external pure returns (bytes32 msgHash)
```

_Checks if token is invalid and returns the message hash_

#### Parameters

| Name          | Type                   | Description                     |
| ------------- | ---------------------- | ------------------------------- |
| message       | struct IBridge.Message | The bridged message struct data |
| bridgeAddress | address                | The bridge contract             |
| tokenAddress  | address                | The token address to be checked |

### checkIfValidAddresses

```solidity
function checkIfValidAddresses(address vault, address to, address token) external pure
```

### checkIfValidAmounts

```solidity
function checkIfValidAmounts(uint256[] amounts, uint256[] tokenIds, bool isERC721) external pure
```
