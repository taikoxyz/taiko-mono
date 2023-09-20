---
title: IAddressManager
---

## IAddressManager

Specifies methods to manage address mappings for given domain-name
pairs.

### setAddress

```solidity
function setAddress(uint256 domain, bytes32 name, address newAddress) external
```

Sets the address for a specific domain-name pair.

#### Parameters

| Name       | Type    | Description                                     |
| ---------- | ------- | ----------------------------------------------- |
| domain     | uint256 | The domain to which the address will be mapped. |
| name       | bytes32 | The name to which the address will be mapped.   |
| newAddress | address | The Ethereum address to be mapped.              |

### getAddress

```solidity
function getAddress(uint256 domain, bytes32 name) external view returns (address)
```

Gets the address mapped to a specific domain-name pair.

#### Parameters

| Name   | Type    | Description                                           |
| ------ | ------- | ----------------------------------------------------- |
| domain | uint256 | The domain for which the address needs to be fetched. |
| name   | bytes32 | The name for which the address needs to be fetched.   |

#### Return Values

| Name | Type    | Description                                   |
| ---- | ------- | --------------------------------------------- |
| [0]  | address | Address associated with the domain-name pair. |

---

## title: AddressManager

## AddressManager

Manages a mapping of domain-name pairs to Ethereum addresses.

### AddressSet

```solidity
event AddressSet(uint256 domain, bytes32 name, address newAddress, address oldAddress)
```

### EOA_OWNER_NOT_ALLOWED

```solidity
error EOA_OWNER_NOT_ALLOWED()
```

### init

```solidity
function init() external
```

Initializes the owner for the upgradable contract.

### setAddress

```solidity
function setAddress(uint256 domain, bytes32 name, address newAddress) external virtual
```

Sets the address for a specific domain-name pair.

#### Parameters

| Name       | Type    | Description                                     |
| ---------- | ------- | ----------------------------------------------- |
| domain     | uint256 | The domain to which the address will be mapped. |
| name       | bytes32 | The name to which the address will be mapped.   |
| newAddress | address | The Ethereum address to be mapped.              |

### getAddress

```solidity
function getAddress(uint256 domain, bytes32 name) external view virtual returns (address)
```

Gets the address mapped to a specific domain-name pair.

#### Parameters

| Name   | Type    | Description                                           |
| ------ | ------- | ----------------------------------------------------- |
| domain | uint256 | The domain for which the address needs to be fetched. |
| name   | bytes32 | The name for which the address needs to be fetched.   |

#### Return Values

| Name | Type    | Description                                   |
| ---- | ------- | --------------------------------------------- |
| [0]  | address | Address associated with the domain-name pair. |

---

## title: ProxiedAddressManager

## ProxiedAddressManager

Proxied version of the parent contract.
