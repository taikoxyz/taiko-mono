---
title: IMintableERC20
---

## IMintableERC20

Interface for ERC20 tokens with mint and burn functionality.

### mint

```solidity
function mint(address account, uint256 amount) external
```

Mints `amount` tokens and assigns them to the `account` address.

#### Parameters

| Name    | Type    | Description                               |
| ------- | ------- | ----------------------------------------- |
| account | address | The account to receive the minted tokens. |
| amount  | uint256 | The amount of tokens to mint.             |

### burn

```solidity
function burn(address from, uint256 amount) external
```

Burns `amount` tokens from the `from` address.

#### Parameters

| Name   | Type    | Description                                       |
| ------ | ------- | ------------------------------------------------- |
| from   | address | The account from which the tokens will be burned. |
| amount | uint256 | The amount of tokens to burn.                     |
