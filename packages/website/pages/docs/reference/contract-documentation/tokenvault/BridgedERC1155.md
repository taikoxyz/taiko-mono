---
title: BridgedERC1155
---

## BridgedERC1155

Contract for bridging ERC1155 tokens across different chains.

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
function mint(address account, uint256 tokenId, uint256 amount) public
```

_Mints tokens._

#### Parameters

| Name    | Type    | Description                           |
| ------- | ------- | ------------------------------------- |
| account | address | Address to receive the minted tokens. |
| tokenId | uint256 | ID of the token to mint.              |
| amount  | uint256 | Amount of tokens to mint.             |

### burn

```solidity
function burn(address account, uint256 tokenId, uint256 amount) public
```

_Burns tokens._

#### Parameters

| Name    | Type    | Description                           |
| ------- | ------- | ------------------------------------- |
| account | address | Address from which tokens are burned. |
| tokenId | uint256 | ID of the token to burn.              |
| amount  | uint256 | Amount of tokens to burn.             |

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 tokenId, uint256 amount, bytes data) public
```

_Safely transfers tokens from one address to another._

#### Parameters

| Name    | Type    | Description                                |
| ------- | ------- | ------------------------------------------ |
| from    | address | Address from which tokens are transferred. |
| to      | address | Address to which tokens are transferred.   |
| tokenId | uint256 | ID of the token to transfer.               |
| amount  | uint256 | Amount of tokens to transfer.              |
| data    | bytes   | Additional data.                           |

### name

```solidity
function name() public view returns (string)
```

Gets the concatenated name of the bridged token.

#### Return Values

| Name | Type   | Description            |
| ---- | ------ | ---------------------- |
| [0]  | string | The concatenated name. |

---

## title: ProxiedBridgedERC1155

## ProxiedBridgedERC1155

Proxied version of the parent contract.
