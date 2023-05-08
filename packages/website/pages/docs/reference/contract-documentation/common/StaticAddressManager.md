---
title: StaticAddressManager
---

## StaticAddressManager

### DISABLED

```solidity
error DISABLED()
```

### setAddress

```solidity
function setAddress(uint256, bytes32, address) external pure
```

### getAddress

```solidity
function getAddress(uint256 domain, bytes32 name) public pure returns (address)
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

## title: ProxiedStaticAddressManager

## ProxiedStaticAddressManager
