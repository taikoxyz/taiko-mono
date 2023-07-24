---
title: IAddressManager
---

## IAddressManager

Interface to set and get an address for a name.

### setAddress

```solidity
function setAddress(uint256 domain, bytes32 name, address newAddress) external
```

Changes the address associated with a particular name.

#### Parameters

| Name       | Type    | Description                                  |
| ---------- | ------- | -------------------------------------------- |
| domain     | uint256 | Uint256 domain to assiciate an address with. |
| name       | bytes32 | Name to associate an address with.           |
| newAddress | address | Address to associate with the name.          |

### getAddress

```solidity
function getAddress(uint256 domain, bytes32 name) external view returns (address)
```

Retrieves the address associated with a given name.

#### Parameters

| Name   | Type    | Description                       |
| ------ | ------- | --------------------------------- |
| domain | uint256 | Class to retrieve an address for. |
| name   | bytes32 | Name to retrieve an address for.  |

#### Return Values

| Name | Type    | Description                             |
| ---- | ------- | --------------------------------------- |
| [0]  | address | Address associated with the given name. |

---

## title: AddressManager

## AddressManager

### AddressSet

```solidity
event AddressSet(uint256 _domain, bytes32 _name, address _newAddress, address _oldAddress)
```

### EOAOwnerAddressNotAllowed

```solidity
error EOAOwnerAddressNotAllowed()
```

### init

```solidity
function init() external
```

_Initializer to be called after being deployed behind a proxy._

### setAddress

```solidity
function setAddress(uint256 domain, bytes32 name, address newAddress) external virtual
```

Changes the address associated with a particular name.

#### Parameters

| Name       | Type    | Description                                  |
| ---------- | ------- | -------------------------------------------- |
| domain     | uint256 | Uint256 domain to assiciate an address with. |
| name       | bytes32 | Name to associate an address with.           |
| newAddress | address | Address to associate with the name.          |

### getAddress

```solidity
function getAddress(uint256 domain, bytes32 name) external view virtual returns (address addr)
```

Retrieves the address associated with a given name.

#### Parameters

| Name   | Type    | Description                       |
| ------ | ------- | --------------------------------- |
| domain | uint256 | Class to retrieve an address for. |
| name   | bytes32 | Name to retrieve an address for.  |

#### Return Values

| Name | Type    | Description                             |
| ---- | ------- | --------------------------------------- |
| addr | address | Address associated with the given name. |

---

## title: ProxiedAddressManager

## ProxiedAddressManager
