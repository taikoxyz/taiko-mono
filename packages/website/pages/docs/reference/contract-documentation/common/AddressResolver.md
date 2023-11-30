---
title: AddressResolver
---

## AddressResolver

This contract acts as a bridge for name-to-address resolution.
It delegates the resolution to the AddressManager. By separating the logic,
we can maintain flexibility in address management without affecting the
resolving process.

Note that the address manager should be changed using upgradability, there
is no setAddressManager() function go guarantee atomicness across all
contracts that are resolvers.

### addressManager

```solidity
address addressManager
```

### RESOLVER_DENIED

```solidity
error RESOLVER_DENIED()
```

### RESOLVER_INVALID_MANAGER

```solidity
error RESOLVER_INVALID_MANAGER()
```

### RESOLVER_UNEXPECTED_CHAINID

```solidity
error RESOLVER_UNEXPECTED_CHAINID()
```

### RESOLVER_ZERO_ADDR

```solidity
error RESOLVER_ZERO_ADDR(uint64 chainId, string name)
```

### onlyFromNamed

```solidity
modifier onlyFromNamed(bytes32 name)
```

#### Parameters

| Name | Type    | Description                |
| ---- | ------- | -------------------------- |
| name | bytes32 | The name to check against. |

### resolve

```solidity
function resolve(bytes32 name, bool allowZeroAddress) public view virtual returns (address payable addr)
```

Resolves a name to its address deployed on this chain.

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
function resolve(uint64 chainId, bytes32 name, bool allowZeroAddress) public view virtual returns (address payable addr)
```

Resolves a name to its address deployed on a specified chain.

#### Parameters

| Name             | Type    | Description                                                             |
| ---------------- | ------- | ----------------------------------------------------------------------- |
| chainId          | uint64  | The chainId of interest.                                                |
| name             | bytes32 | Name whose address is to be resolved.                                   |
| allowZeroAddress | bool    | If set to true, does not throw if the resolved address is `address(0)`. |

#### Return Values

| Name | Type            | Description                                                    |
| ---- | --------------- | -------------------------------------------------------------- |
| addr | address payable | Address associated with the given name on the specified chain. |

### \_init

```solidity
function _init(address _addressManager) internal virtual
```

#### Parameters

| Name             | Type    | Description                    |
| ---------------- | ------- | ------------------------------ |
| \_addressManager | address | Address of the AddressManager. |
