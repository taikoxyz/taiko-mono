---
title: LibTaikoTokenConfig
---

## LibTaikoTokenConfig

### DECIMALS

```solidity
uint8 DECIMALS
```

---

## title: TaikoToken

## TaikoToken

### Mint

```solidity
event Mint(address account, uint256 amount)
```

### Burn

```solidity
event Burn(address account, uint256 amount)
```

### TKO_INVALID_ADDR

```solidity
error TKO_INVALID_ADDR()
```

### TKO_INVALID_PREMINT_PARAMS

```solidity
error TKO_INVALID_PREMINT_PARAMS()
```

### TKO_MINT_DISALLOWED

```solidity
error TKO_MINT_DISALLOWED()
```

### constructor

```solidity
constructor() public
```

### init

```solidity
function init(address _addressManager, string _name, string _symbol, address[] _premintRecipients, uint256[] _premintAmounts) public
```

### snapshot

```solidity
function snapshot() public
```

### pause

```solidity
function pause() public
```

### unpause

```solidity
function unpause() public
```

### mint

```solidity
function mint(address to, uint256 amount) public
```

### burn

```solidity
function burn(address from, uint256 amount) public
```

### transfer

```solidity
function transfer(address to, uint256 amount) public returns (bool)
```

\_See {IERC20-transfer}.

Requirements:

- `to` cannot be the zero address.
- the caller must have a balance of at least `amount`.\_

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) public returns (bool)
```

\_See {IERC20-transferFrom}.

Emits an {Approval} event indicating the updated allowance. This is not
required by the EIP. See the note at the beginning of {ERC20}.

NOTE: Does not update the allowance if the current allowance
is the maximum `uint256`.

Requirements:

- `from` and `to` cannot be the zero address.
- `from` must have a balance of at least `amount`.
- the caller must have allowance for `from`'s tokens of at least
  `amount`.\_

### decimals

```solidity
function decimals() public pure returns (uint8)
```

\_Returns the number of decimals used to get its user representation.
For example, if `decimals` equals `2`, a balance of `505` tokens should
be displayed to a user as `5.05` (`505 / 10 ** 2`).

Tokens usually opt for a value of 18, imitating the relationship between
Ether and Wei. This is the value {ERC20} uses, unless this function is
overridden;

NOTE: This information is only used for _display_ purposes: it in
no way affects any of the arithmetic of the contract, including
{IERC20-balanceOf} and {IERC20-transfer}.\_

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
