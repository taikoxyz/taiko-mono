---
title: AddressResolver
---

## AddressResolver

This abstract contract provides a name-to-address lookup. Under the hood,
it uses an AddressManager to manage the name-to-address mapping.

### \_addressManager

```solidity
contract IAddressManager _addressManager
```

### onlyFromNamed

```solidity
modifier onlyFromNamed(string name)
```

### resolve

```solidity
function resolve(string name, bool allowZeroAddress) public view virtual returns (address payable)
```

Resolves a name to an address on the current chain.

_This function will throw if the resolved address is `address(0)`._

#### Parameters

| Name             | Type   | Description                                |
| ---------------- | ------ | ------------------------------------------ |
| name             | string | The name to resolve.                       |
| allowZeroAddress | bool   | True to allow zero address to be returned. |

#### Return Values

| Name | Type            | Description                       |
| ---- | --------------- | --------------------------------- |
| [0]  | address payable | The name's corresponding address. |

### resolve

```solidity
function resolve(uint256 chainId, string name, bool allowZeroAddress) public view virtual returns (address payable)
```

Resolves a name to an address on the specified chain.

_This function will throw if the resolved address is `address(0)`._

#### Parameters

| Name             | Type    | Description                                |
| ---------------- | ------- | ------------------------------------------ |
| chainId          | uint256 | The chainId.                               |
| name             | string  | The name to resolve.                       |
| allowZeroAddress | bool    | True to allow zero address to be returned. |

#### Return Values

| Name | Type            | Description                       |
| ---- | --------------- | --------------------------------- |
| [0]  | address payable | The name's corresponding address. |

### addressManager

```solidity
function addressManager() public view returns (address)
```

Returns the AddressManager's address.

#### Return Values

| Name | Type    | Description                   |
| ---- | ------- | ----------------------------- |
| [0]  | address | The AddressManager's address. |

### \_init

```solidity
function _init(address addressManager_) internal virtual
```
