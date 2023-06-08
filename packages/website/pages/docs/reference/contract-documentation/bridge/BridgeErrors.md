---
title: BridgeErrors
---

## BridgeErrors

### B_CANNOT_RECEIVE

```solidity
error B_CANNOT_RECEIVE()
```

Emitted when the contract is not intended to receive Ether

### B_DENIED

```solidity
error B_DENIED()
```

Emitted when an operation is denied due to incorrect permissions

### B_ERC20_CANNOT_RECEIVE

```solidity
error B_ERC20_CANNOT_RECEIVE()
```

Emitted when the contract is not designed to receive ERC20 tokens

### B_ETHER_RELEASED_ALREADY

```solidity
error B_ETHER_RELEASED_ALREADY()
```

Emitted when Ether has already been released as part of a transfer

### B_EV_DO_NOT_BURN

```solidity
error B_EV_DO_NOT_BURN()
```

Emitted when attempting to burn Ether in EtherVault

### B_EV_NOT_AUTHORIZED

```solidity
error B_EV_NOT_AUTHORIZED()
```

Emitted when an unauthorized action is attempted in EtherVault

### B_EV_PARAM

```solidity
error B_EV_PARAM()
```

Emitted when an incorrect parameter is passed in EtherVault

### B_FAILED_TRANSFER

```solidity
error B_FAILED_TRANSFER()
```

Emitted when an ERC20 token transfer fails

### B_FORBIDDEN

```solidity
error B_FORBIDDEN()
```

Emitted when an action is forbidden

### B_GAS_LIMIT

```solidity
error B_GAS_LIMIT()
```

Emitted when the gas limit for an operation is exceeded

### B_INCORRECT_VALUE

```solidity
error B_INCORRECT_VALUE()
```

Emitted when an incorrect value is used in an operation

### B_INIT_PARAM_ERROR

```solidity
error B_INIT_PARAM_ERROR()
```

Emitted when an incorrect parameter is passed during initialization

### B_MSG_HASH_NULL

```solidity
error B_MSG_HASH_NULL()
```

Emitted when a null message hash is used

### B_MSG_NON_RETRIABLE

```solidity
error B_MSG_NON_RETRIABLE()
```

Emitted when a non-retriable message is retried

### B_MSG_NOT_FAILED

```solidity
error B_MSG_NOT_FAILED()
```

Emitted when a message that hasn't failed is retried

### B_NULL_APP_ADDR

```solidity
error B_NULL_APP_ADDR()
```

Emitted when a null address is used in an application

### B_OWNER_IS_NULL

```solidity
error B_OWNER_IS_NULL()
```

Emitted when a null owner address is used

### B_SIGNAL_NOT_RECEIVED

```solidity
error B_SIGNAL_NOT_RECEIVED()
```

Emitted when a signal has not been received

### B_STATUS_MISMATCH

```solidity
error B_STATUS_MISMATCH()
```

Emitted when the status of an operation does not match the expected status

### B_WRONG_CHAIN_ID

```solidity
error B_WRONG_CHAIN_ID()
```

Emitted when an incorrect chain ID is used

### B_WRONG_TO_ADDRESS

```solidity
error B_WRONG_TO_ADDRESS()
```

Emitted when an incorrect recipient address is used

### B_ZERO_SIGNAL

```solidity
error B_ZERO_SIGNAL()
```

Emitted when a signal of zero is used
