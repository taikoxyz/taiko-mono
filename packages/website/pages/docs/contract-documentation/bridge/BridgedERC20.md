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

_Initializer to be called after being deployed behind a proxy._

### bridgeMintTo

```solidity
function bridgeMintTo(address account, uint256 amount) public
```

_only a TokenVault can call this function_

### bridgeBurnFrom

```solidity
function bridgeBurnFrom(address account, uint256 amount) public
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

### source

```solidity
function source() public view returns (address, uint256)
```

_returns the srcToken being bridged and the srcChainId_
