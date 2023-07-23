---
title: BaseVault
---

## BaseVault

### releasedMessages

```solidity
mapping(bytes32 => bool) releasedMessages
```

### VAULT_INIT_PARAM_ERROR

```solidity
error VAULT_INIT_PARAM_ERROR()
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

### VAULT_INVALID_SENDER

```solidity
error VAULT_INVALID_SENDER()
```

Thrown when the sender in a message context is invalid.
This could happen if the sender isn't the expected token vault on the
source chain.

### onlyValidAddresses

```solidity
modifier onlyValidAddresses(uint256 chainId, bytes32 name, address to, address token)
```

### init

```solidity
function init(address addressManager) external
```

### \_deployProxy

```solidity
function _deployProxy(address implementation, bytes initializationData) internal returns (address proxy)
```

#### Parameters

| Name               | Type    | Description                    |
| ------------------ | ------- | ------------------------------ |
| implementation     | address | The new implementation address |
| initializationData | bytes   | Data for the initialization    |

### \_checkValidContext

```solidity
function _checkValidContext(bytes32 validSender) internal view returns (struct IBridge.Context ctx)
```

#### Parameters

| Name        | Type    | Description                    |
| ----------- | ------- | ------------------------------ |
| validSender | bytes32 | The valid sender to be allowed |

### \_extractCalldata

```solidity
function _extractCalldata(bytes calldataWithSelector) internal pure returns (bytes)
```

#### Parameters

| Name                 | Type  | Description                |
| -------------------- | ----- | -------------------------- |
| calldataWithSelector | bytes | Encoded data with selector |
