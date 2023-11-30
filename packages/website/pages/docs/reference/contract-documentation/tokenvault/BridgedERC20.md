---
title: BridgedERC20
---

## BridgedERC20

An upgradeable ERC20 contract that represents tokens bridged from
another chain.

### srcToken

```solidity
address srcToken
```

### srcChainId

```solidity
uint256 srcChainId
```

### BRIDGED_TOKEN_CANNOT_RECEIVE

```solidity
error BRIDGED_TOKEN_CANNOT_RECEIVE()
```

### BRIDGED_TOKEN_INVALID_PARAMS

```solidity
error BRIDGED_TOKEN_INVALID_PARAMS()
```

### init

```solidity
function init(address _addressManager, address _srcToken, uint256 _srcChainId, uint8 _decimals, string _symbol, string _name) external
```

Initializes the contract.

_Different BridgedERC20 Contract is deployed per unique \_srcToken
(e.g., one for USDC, one for USDT, etc.)._

#### Parameters

| Name             | Type    | Description                                       |
| ---------------- | ------- | ------------------------------------------------- |
| \_addressManager | address | The address manager.                              |
| \_srcToken       | address | The source token address.                         |
| \_srcChainId     | uint256 | The source chain ID.                              |
| \_decimals       | uint8   | The number of decimal places of the source token. |
| \_symbol         | string  | The symbol of the token.                          |
| \_name           | string  | The name of the token.                            |

### mint

```solidity
function mint(address account, uint256 amount) public
```

Mints tokens to an account.

_Only an ERC20Vault can call this function._

#### Parameters

| Name    | Type    | Description                    |
| ------- | ------- | ------------------------------ |
| account | address | The account to mint tokens to. |
| amount  | uint256 | The amount of tokens to mint.  |

### burn

```solidity
function burn(address account, uint256 amount) public
```

Burns tokens from an account.

_Only an ERC20Vault can call this function._

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

### name

```solidity
function name() public view returns (string)
```

Gets the name of the token.

#### Return Values

| Name | Type   | Description                                              |
| ---- | ------ | -------------------------------------------------------- |
| [0]  | string | The name of the token with the source chain ID appended. |

### decimals

```solidity
function decimals() public view returns (uint8)
```

Gets the number of decimal places of the token.

#### Return Values

| Name | Type  | Description                                |
| ---- | ----- | ------------------------------------------ |
| [0]  | uint8 | The number of decimal places of the token. |

### canonical

```solidity
function canonical() public view returns (address, uint256)
```

Gets the canonical token's address and chain ID.

#### Return Values

| Name | Type    | Description                                 |
| ---- | ------- | ------------------------------------------- |
| [0]  | address | The canonical token's address and chain ID. |
| [1]  | uint256 |                                             |

---

## title: ProxiedBridgedERC20

## ProxiedBridgedERC20

Proxied version of the parent contract.
