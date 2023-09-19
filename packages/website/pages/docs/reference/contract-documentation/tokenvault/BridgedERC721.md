---
title: BridgedERC721
---

## BridgedERC721

Contract for bridging ERC721 tokens across different chains.

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

_Initializer function to be called after deployment._

#### Parameters

| Name             | Type    | Description                         |
| ---------------- | ------- | ----------------------------------- |
| \_addressManager | address | The address of the address manager. |
| \_srcToken       | address | Address of the source token.        |
| \_srcChainId     | uint256 | Source chain ID.                    |
| \_symbol         | string  | Symbol of the bridged token.        |
| \_name           | string  | Name of the bridged token.          |

### mint

```solidity
function mint(address account, uint256 tokenId) public
```

_Mints tokens._

#### Parameters

| Name    | Type    | Description                          |
| ------- | ------- | ------------------------------------ |
| account | address | Address to receive the minted token. |
| tokenId | uint256 | ID of the token to mint.             |

### burn

```solidity
function burn(address account, uint256 tokenId) public
```

_Burns tokens._

#### Parameters

| Name    | Type    | Description                             |
| ------- | ------- | --------------------------------------- |
| account | address | Address from which the token is burned. |
| tokenId | uint256 | ID of the token to burn.                |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 tokenId) public
```

_Safely transfers tokens from one address to another._

#### Parameters

| Name    | Type    | Description                                  |
| ------- | ------- | -------------------------------------------- |
| from    | address | Address from which the token is transferred. |
| to      | address | Address to which the token is transferred.   |
| tokenId | uint256 | ID of the token to transfer.                 |

### name

```solidity
function name() public view returns (string)
```

Gets the concatenated name of the bridged token.

#### Return Values

| Name | Type   | Description            |
| ---- | ------ | ---------------------- |
| [0]  | string | The concatenated name. |

### source

```solidity
function source() public view returns (address, uint256)
```

Gets the source token and source chain ID being bridged.

#### Return Values

| Name | Type    | Description                               |
| ---- | ------- | ----------------------------------------- |
| [0]  | address | Source token address and source chain ID. |
| [1]  | uint256 |                                           |

### tokenURI

```solidity
function tokenURI(uint256 tokenId) public pure virtual returns (string)
```

Returns an empty token URI.

#### Parameters

| Name    | Type    | Description      |
| ------- | ------- | ---------------- |
| tokenId | uint256 | ID of the token. |

#### Return Values

| Name | Type   | Description      |
| ---- | ------ | ---------------- |
| [0]  | string | An empty string. |

---

## title: ProxiedBridgedERC721

## ProxiedBridgedERC721

Proxied version of the parent contract.
