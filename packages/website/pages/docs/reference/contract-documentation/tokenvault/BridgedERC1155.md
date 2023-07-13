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

### srcUri

```solidity
string srcUri
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
function init(address _addressManager, address _srcToken, uint256 _srcChainId, string _uri) external
```

_Initializer to be called after being deployed behind a proxy._

### mint

```solidity
function mint(address account, uint256 tokenId, uint256 amount, bytes data) public
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

### source

```solidity
function source() public view returns (address, uint256)
```

_returns the srcToken being bridged and the srcChainId_
