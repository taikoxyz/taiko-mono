---
title: IAddressManager
---

## IAddressManager

Specifies methods to manage address mappings for given chainId-name
pairs.

### getAddress

```solidity
function getAddress(uint64 chainId, bytes32 name) external view returns (address)
```

Gets the address mapped to a specific chainId-name pair.

_Note that in production, this method shall be a pure function
without any storage access._

#### Parameters

| Name    | Type    | Description                                            |
| ------- | ------- | ------------------------------------------------------ |
| chainId | uint64  | The chainId for which the address needs to be fetched. |
| name    | bytes32 | The name for which the address needs to be fetched.    |

#### Return Values

| Name | Type    | Description                                    |
| ---- | ------- | ---------------------------------------------- |
| [0]  | address | Address associated with the chainId-name pair. |

---

## title: AddressManager

## AddressManager

Manages a mapping of chainId-name pairs to Ethereum addresses.

### AddressSet

```solidity
event AddressSet(uint64 chainId, bytes32 name, address newAddress, address oldAddress)
```

### init

```solidity
function init() external
```

Initializes the owner for the upgradable contract.

### setAddress

```solidity
function setAddress(uint64 chainId, bytes32 name, address newAddress) external virtual
```

Sets the address for a specific chainId-name pair.

#### Parameters

| Name       | Type    | Description                                      |
| ---------- | ------- | ------------------------------------------------ |
| chainId    | uint64  | The chainId to which the address will be mapped. |
| name       | bytes32 | The name to which the address will be mapped.    |
| newAddress | address | The Ethereum address to be mapped.               |

### getAddress

```solidity
function getAddress(uint64 chainId, bytes32 name) public view returns (address)
```

Gets the address mapped to a specific chainId-name pair.

_Note that in production, this method shall be a pure function
without any storage access._

#### Parameters

| Name    | Type    | Description                                            |
| ------- | ------- | ------------------------------------------------------ |
| chainId | uint64  | The chainId for which the address needs to be fetched. |
| name    | bytes32 | The name for which the address needs to be fetched.    |

#### Return Values

| Name | Type    | Description                                    |
| ---- | ------- | ---------------------------------------------- |
| [0]  | address | Address associated with the chainId-name pair. |

---

## title: ProxiedAddressManager

## ProxiedAddressManager

Proxied version of the parent contract.

### constructor

```solidity
constructor() public
```
