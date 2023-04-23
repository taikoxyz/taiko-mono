## IAddressManager

Interface to set and get an address for a name.

### setAddress

```solidity
function setAddress(uint256 domain, string name, address newAddress) external
```

Changes the address associated with a particular name.

#### Parameters

| Name       | Type    | Description                                  |
| ---------- | ------- | -------------------------------------------- |
| domain     | uint256 | Uint256 domain to assiciate an address with. |
| name       | string  | String name to associate an address with.    |
| newAddress | address | Address to associate with the name.          |

### getAddress

```solidity
function getAddress(uint256 domain, string name) external view returns (address)
```

Retrieves the address associated with a given name.

#### Parameters

| Name   | Type    | Description                       |
| ------ | ------- | --------------------------------- |
| domain | uint256 | Class to retrieve an address for. |
| name   | string  | Name to retrieve an address for.  |

#### Return Values

| Name | Type    | Description                             |
| ---- | ------- | --------------------------------------- |
| [0]  | address | Address associated with the given name. |

## AddressManager

### AddressSet

```solidity
event AddressSet(uint256 _domain, string _name, address _newAddress, address _oldAddress)
```

### init

```solidity
function init() external
```

_Initializer to be called after being deployed behind a proxy._

### setAddress

```solidity
function setAddress(uint256 domain, string name, address newAddress) external
```

Changes the address associated with a particular name.

#### Parameters

| Name       | Type    | Description                                  |
| ---------- | ------- | -------------------------------------------- |
| domain     | uint256 | Uint256 domain to assiciate an address with. |
| name       | string  | String name to associate an address with.    |
| newAddress | address | Address to associate with the name.          |

### getAddress

```solidity
function getAddress(uint256 domain, string name) external view returns (address addr)
```

Retrieves the address associated with a given name.

#### Parameters

| Name   | Type    | Description                       |
| ------ | ------- | --------------------------------- |
| domain | uint256 | Class to retrieve an address for. |
| name   | string  | Name to retrieve an address for.  |

#### Return Values

| Name | Type    | Description                             |
| ---- | ------- | --------------------------------------- |
| addr | address | Address associated with the given name. |
