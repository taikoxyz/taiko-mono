---
title: SisterContract
---

## SisterContract

### tokenToUri

```solidity
mapping(uint256 => string) tokenToUri
```

### constructor

```solidity
constructor(string name, string symbol) public
```

### safeMintOrTransfer

```solidity
function safeMintOrTransfer(address to, uint256 tokenId, string uri) public
```

### _setTokenURI

```solidity
function _setTokenURI(uint256 tokenId, string uri) internal
```

### tokenURI

```solidity
function tokenURI(uint256 tokenId) public view returns (string)
```

_See {IERC721Metadata-tokenURI}._

