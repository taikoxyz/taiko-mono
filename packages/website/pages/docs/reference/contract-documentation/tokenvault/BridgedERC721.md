---
title: BridgedERC721
---

## BridgedERC721

### srcToken

```solidity
address srcToken
```

### srcBaseUri

```solidity
string srcBaseUri
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
function init(address _addressManager, address _srcToken, uint256 _srcChainId, string _symbol, string _name, string _uri) external
```

_Initializer to be called after being deployed behind a proxy._

### mint

```solidity
function mint(address account, uint256 tokenId) public
```

_only a TokenVault can call this function_

### burn

```solidity
function burn(address account, uint256 tokenId) public
```

_only a TokenVault can call this function_

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 tokenId) public
```

_any address can call this_

### source

```solidity
function source() public view returns (address, uint256)
```

_returns the srcToken being bridged and the srcChainId_

### \_baseURI

```solidity
function _baseURI() internal view returns (string)
```
