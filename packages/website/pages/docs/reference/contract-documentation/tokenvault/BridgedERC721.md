---
title: BridgedERC721
---

## BridgedERC721

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

### BRIDGED_TOKEN_INVALID_BURN

```solidity
error BRIDGED_TOKEN_INVALID_BURN()
```

### init

```solidity
function init(address _addressManager, address _srcToken, uint256 _srcChainId, string _symbol, string _name) external
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

### name

```solidity
function name() public view returns (string)
```

_See {IERC721Metadata-name}._

### source

```solidity
function source() public view returns (address, uint256)
```

_returns the srcToken being bridged and the srcChainId_

### tokenURI

```solidity
function tokenURI(uint256) public pure virtual returns (string)
```

---

## title: ProxiedBridgedERC721

## ProxiedBridgedERC721
