---
title: BridgedERC1155
---

## BridgedERC1155

### srcToken

```solidity
address srcToken
```

### srcChainId

```solidity
uint256 srcChainId
```

### symbol

```solidity
string symbol
```

### Transfer

```solidity
event Transfer(address from, address to, uint256 tokenId, uint256 amount)
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
function init(address _addressManager, address _srcToken, uint256 _srcChainId, string _symbol, string _name) external
```

_Initializer to be called after being deployed behind a proxy._

### mint

```solidity
function mint(address account, uint256 tokenId, uint256 amount) public
```

_only a TokenVault can call this function_

### burn

```solidity
function burn(address account, uint256 tokenId, uint256 amount) public
```

_only a TokenVault can call this function_

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 tokenId, uint256 amount, bytes data) public
```

_any address can call this_

### name

```solidity
function name() public view returns (string)
```

---

## title: ProxiedBridgedERC1155

## ProxiedBridgedERC1155
