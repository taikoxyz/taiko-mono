---
title: AuthorizableContract
---

## AuthorizableContract

### authorizedAddresses

```solidity
mapping(address => bytes32) authorizedAddresses
```

### Authorized

```solidity
event Authorized(address addr, bytes32 oldLabel, bytes32 newLabel)
```

### ADDRESS_UNAUTHORIZED

```solidity
error ADDRESS_UNAUTHORIZED()
```

### INVALID_ADDRESS

```solidity
error INVALID_ADDRESS()
```

### INVALID_LABEL

```solidity
error INVALID_LABEL()
```

### onlyFromAuthorized

```solidity
modifier onlyFromAuthorized()
```

### authorize

```solidity
function authorize(address addr, bytes32 label) external
```

### isAuthorized

```solidity
function isAuthorized(address addr) public view returns (bool)
```

### isAuthorizedAs

```solidity
function isAuthorizedAs(address addr, bytes32 label) public view returns (bool)
```

### \_init

```solidity
function _init(address _addressManager) internal virtual
```

Initializes the contract with an address manager.

#### Parameters

| Name             | Type    | Description                         |
| ---------------- | ------- | ----------------------------------- |
| \_addressManager | address | The address of the address manager. |

### \_init

```solidity
function _init() internal virtual
```
