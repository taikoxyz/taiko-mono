---
title: TaikoToken
---

## TaikoToken

The TaikoToken (TKO), in the protocol is used for prover collateral
in the form of bonds. It is an ERC20 token with 18 decimal places of
precision.

### TKO_INVALID_ADDR

```solidity
error TKO_INVALID_ADDR()
```

### TKO_INVALID_PREMINT_PARAMS

```solidity
error TKO_INVALID_PREMINT_PARAMS()
```

### init

```solidity
function init(address _addressManager, string _name, string _symbol, address[] _premintRecipients, uint256[] _premintAmounts) public
```

Initializes the TaikoToken contract and mints initial tokens to
specified recipients.

#### Parameters

| Name                | Type      | Description                                                         |
| ------------------- | --------- | ------------------------------------------------------------------- |
| \_addressManager    | address   | The {AddressManager} address.                                       |
| \_name              | string    | The name of the token.                                              |
| \_symbol            | string    | The symbol of the token.                                            |
| \_premintRecipients | address[] | An array of addresses to receive initial token minting.             |
| \_premintAmounts    | uint256[] | An array of token amounts to mint for each corresponding recipient. |

### snapshot

```solidity
function snapshot() public
```

Creates a new token snapshot.

### pause

```solidity
function pause() public
```

Pauses token transfers.

### unpause

```solidity
function unpause() public
```

Unpauses token transfers.

### mint

```solidity
function mint(address to, uint256 amount) public
```

Mints new tokens to the specified address.

#### Parameters

| Name   | Type    | Description                               |
| ------ | ------- | ----------------------------------------- |
| to     | address | The address to receive the minted tokens. |
| amount | uint256 | The amount of tokens to mint.             |

### burn

```solidity
function burn(address from, uint256 amount) public
```

Burns tokens from the specified address.

#### Parameters

| Name   | Type    | Description                      |
| ------ | ------- | -------------------------------- |
| from   | address | The address to burn tokens from. |
| amount | uint256 | The amount of tokens to burn.    |

### transfer

```solidity
function transfer(address to, uint256 amount) public returns (bool)
```

Transfers tokens to a specified address.

#### Parameters

| Name   | Type    | Description                        |
| ------ | ------- | ---------------------------------- |
| to     | address | The address to transfer tokens to. |
| amount | uint256 | The amount of tokens to transfer.  |

#### Return Values

| Name | Type | Description                                                      |
| ---- | ---- | ---------------------------------------------------------------- |
| [0]  | bool | A boolean indicating whether the transfer was successful or not. |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) public returns (bool)
```

Transfers tokens from one address to another.

#### Parameters

| Name   | Type    | Description                          |
| ------ | ------- | ------------------------------------ |
| from   | address | The address to transfer tokens from. |
| to     | address | The address to transfer tokens to.   |
| amount | uint256 | The amount of tokens to transfer.    |

#### Return Values

| Name | Type | Description                                                      |
| ---- | ---- | ---------------------------------------------------------------- |
| [0]  | bool | A boolean indicating whether the transfer was successful or not. |

### \_beforeTokenTransfer

```solidity
function _beforeTokenTransfer(address from, address to, uint256 amount) internal
```

### \_afterTokenTransfer

```solidity
function _afterTokenTransfer(address from, address to, uint256 amount) internal
```

### \_mint

```solidity
function _mint(address to, uint256 amount) internal
```

### \_burn

```solidity
function _burn(address from, uint256 amount) internal
```

---

## title: ProxiedTaikoToken

## ProxiedTaikoToken

Proxied version of the TaikoToken contract.
