---
title: AddressResolver
---

## AddressResolver

This contract acts as a bridge for name-to-address resolution.
It delegates the resolution to the AddressManager. By separating the logic,
we can maintain flexibility in address management without affecting the
resolving process.

### \_addressManager

```solidity
contract IAddressManager _addressManager
```

### AddressManagerChanged

```solidity
event AddressManagerChanged(address addressManager)
```

### RESOLVER_DENIED

```solidity
error RESOLVER_DENIED()
```

### RESOLVER_INVALID_ADDR

```solidity
error RESOLVER_INVALID_ADDR()
```

### RESOLVER_ZERO_ADDR

```solidity
error RESOLVER_ZERO_ADDR(uint256 chainId, bytes32 name)
```

### onlyFromNamed

```solidity
modifier onlyFromNamed(bytes32 name)
```

#### Parameters

| Name | Type    | Description                |
| ---- | ------- | -------------------------- |
| name | bytes32 | The name to check against. |

### onlyFromNamed2

```solidity
modifier onlyFromNamed2(bytes32 name1, bytes32 name2)
```

#### Parameters

| Name  | Type    | Description                       |
| ----- | ------- | --------------------------------- |
| name1 | bytes32 | The first name to check against.  |
| name2 | bytes32 | The second name to check against. |

### resolve

```solidity
function resolve(bytes32 name, bool allowZeroAddress) public view virtual returns (address payable addr)
```

Resolves a name to its address on the current chain.

#### Parameters

| Name             | Type    | Description                                                             |
| ---------------- | ------- | ----------------------------------------------------------------------- |
| name             | bytes32 | Name whose address is to be resolved.                                   |
| allowZeroAddress | bool    | If set to true, does not throw if the resolved address is `address(0)`. |

#### Return Values

| Name | Type            | Description                             |
| ---- | --------------- | --------------------------------------- |
| addr | address payable | Address associated with the given name. |

### resolve

```solidity
function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) public view virtual returns (address payable addr)
```

Resolves a name to its address on a specified chain.

#### Parameters

| Name             | Type    | Description                                                             |
| ---------------- | ------- | ----------------------------------------------------------------------- |
| chainId          | uint256 | The chainId of interest.                                                |
| name             | bytes32 | Name whose address is to be resolved.                                   |
| allowZeroAddress | bool    | If set to true, does not throw if the resolved address is `address(0)`. |

#### Return Values

| Name | Type            | Description                                                    |
| ---- | --------------- | -------------------------------------------------------------- |
| addr | address payable | Address associated with the given name on the specified chain. |

### addressManager

```solidity
function addressManager() public view returns (address)
```

Fetches the AddressManager's address.

#### Return Values

| Name | Type    | Description                                |
| ---- | ------- | ------------------------------------------ |
| [0]  | address | The current address of the AddressManager. |

### \_init

```solidity
function _init(address addressManager_) internal virtual
```

#### Parameters

| Name             | Type    | Description                    |
| ---------------- | ------- | ------------------------------ |
| addressManager\_ | address | Address of the AddressManager. |
