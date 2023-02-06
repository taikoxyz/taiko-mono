---
title: TkoToken
---

## TkoToken

_This is Taiko's governance and fee token._

### Mint

```solidity
event Mint(address account, uint256 amount)
```

### Burn

```solidity
event Burn(address account, uint256 amount)
```

### init

```solidity
function init(address _addressManager) external
```

_Initializer to be called after being deployed behind a proxy.
Based on our simulation in simulate/tokenomics/index.js, both
amountMintToDAO and amountMintToDev shall be set to ~150,000,000._

### transfer

```solidity
function transfer(address to, uint256 amount) public returns (bool)
```

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) public returns (bool)
```

### mint

```solidity
function mint(address account, uint256 amount) public
```

_Mints tokens to the given address's balance. This will increase
the circulating supply._

#### Parameters

| Name    | Type    | Description                        |
| ------- | ------- | ---------------------------------- |
| account | address | The address to receive the tokens. |
| amount  | uint256 | The amount of tokens to mint.      |

### burn

```solidity
function burn(address account, uint256 amount) public
```

_Burn tokens from the given address's balance. This will decrease
the circulating supply._

#### Parameters

| Name    | Type    | Description                          |
| ------- | ------- | ------------------------------------ |
| account | address | The address to burn the tokens from. |
| amount  | uint256 | The amount of tokens to burn.        |
