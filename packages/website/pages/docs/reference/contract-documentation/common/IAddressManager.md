---
title: IAddressManager
---

## IAddressManager

Interface to set and get an address for a name.

### setAddress

```solidity
function setAddress(string name, address addr) external
```

Associate an address to a name.

_The original address associated with the name, if exists, will be
replaced._

#### Parameters

| Name | Type    | Description                                        |
| ---- | ------- | -------------------------------------------------- |
| name | string  | The name which an address will be associated with. |
| addr | address | The address to be associated with the given name.  |

### getAddress

```solidity
function getAddress(string name) external view returns (address)
```

Returns the address associated with the given name.

#### Parameters

| Name | Type   | Description                                     |
| ---- | ------ | ----------------------------------------------- |
| name | string | The name for which an address will be returned. |

#### Return Values

| Name | Type    | Description                                                                                        |
| ---- | ------- | -------------------------------------------------------------------------------------------------- |
| [0]  | address | The address associated with the given name. If no address is found, `address(0)` will be returned. |
