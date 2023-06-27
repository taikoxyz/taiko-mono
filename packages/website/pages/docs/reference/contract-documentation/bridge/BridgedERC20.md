---
title: BridgedERC20
---

## BridgedERC20

This contract is an upgradeable ERC20 contract that represents tokens bridged
from another chain.

### srcToken

```solidity
address srcToken
```

### srcChainId

```solidity
uint256 srcChainId
```

### BridgeMint

```solidity
event BridgeMint(address account, uint256 amount)
```

### BridgeBurn

```solidity
event BridgeBurn(address account, uint256 amount)
```

### init

```solidity
function init(address _addressManager, address _srcToken, uint256 _srcChainId, uint8 _decimals, string _symbol, string _name) external
```

Initializes the contract.

_Different BridgedERC20 Contract to be deployed
per unique \_srcToken i.e. one for USDC, one for USDT etc._

#### Parameters

| Name             | Type    | Description                                       |
| ---------------- | ------- | ------------------------------------------------- |
| \_addressManager | address | The address manager.                              |
| \_srcToken       | address | The source token address.                         |
| \_srcChainId     | uint256 | The source chain ID.                              |
| \_decimals       | uint8   | The number of decimal places of the source token. |
| \_symbol         | string  | The symbol of the token.                          |
| \_name           | string  | The name of the token.                            |

### bridgeMintTo

```solidity
function bridgeMintTo(address account, uint256 amount) public
```

Mints tokens to an account.

_Only a TokenVault can call this function._

#### Parameters

| Name    | Type    | Description                    |
| ------- | ------- | ------------------------------ |
| account | address | The account to mint tokens to. |
| amount  | uint256 | The amount of tokens to mint.  |

### bridgeBurnFrom

```solidity
function bridgeBurnFrom(address account, uint256 amount) public
```

Burns tokens from an account.

_Only a TokenVault can call this function._

#### Parameters

| Name    | Type    | Description                      |
| ------- | ------- | -------------------------------- |
| account | address | The account to burn tokens from. |
| amount  | uint256 | The amount of tokens to burn.    |

### transfer

```solidity
function transfer(address to, uint256 amount) public returns (bool)
```

Transfers tokens from the caller to another account.

_Any address can call this. Caller must have at least 'amount' to
call this._

#### Parameters

| Name   | Type    | Description                        |
| ------ | ------- | ---------------------------------- |
| to     | address | The account to transfer tokens to. |
| amount | uint256 | The amount of tokens to transfer.  |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) public returns (bool)
```

Transfers tokens from one account to another account.

_Any address can call this. Caller must have allowance of at least
'amount' for 'from's tokens._

#### Parameters

| Name   | Type    | Description                          |
| ------ | ------- | ------------------------------------ |
| from   | address | The account to transfer tokens from. |
| to     | address | The account to transfer tokens to.   |
| amount | uint256 | The amount of tokens to transfer.    |

### decimals

```solidity
function decimals() public view returns (uint8)
```

Gets the number of decimal places of the token.

#### Return Values

| Name | Type  | Description                                |
| ---- | ----- | ------------------------------------------ |
| [0]  | uint8 | The number of decimal places of the token. |

### source

```solidity
function source() public view returns (address, uint256)
```

Gets the source token address and the source chain ID.

#### Return Values

| Name | Type    | Description                                       |
| ---- | ------- | ------------------------------------------------- |
| [0]  | address | The source token address and the source chain ID. |
| [1]  | uint256 |                                                   |

---

## title: ProxiedBridgedERC20

## ProxiedBridgedERC20
