---
title: BridgedERC20
---

## BridgedERC20

### srcToken

```solidity
address srcToken
```

### srcChainId

```solidity
uint256 srcChainId
```

### init

```solidity
function init(address _addressManager, address _srcToken, uint256 _srcChainId, uint8 _decimals, string _symbol, string _name) external
```

_Initializer to be called after being deployed behind a proxy._

### mint

```solidity
function mint(address account, uint256 amount) public
```

_only a TokenVault can call this function_

### burn

```solidity
function burn(address from, uint256 amount) public
```

_only a TokenVault can call this function_

### transfer

```solidity
function transfer(address to, uint256 amount) public returns (bool)
```

_any address can call this_

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) public returns (bool)
```

_any address can call this_

### decimals

```solidity
function decimals() public view returns (uint8)
```

### source

```solidity
function source() public view returns (address, uint256)
```

_returns the srcToken being bridged and the srcChainId_

---

## title: ProxiedBridgedERC20

## ProxiedBridgedERC20
