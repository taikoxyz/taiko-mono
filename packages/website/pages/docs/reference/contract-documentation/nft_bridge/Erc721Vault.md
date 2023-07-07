---
title: Erc721Vault
---

## Erc721Vault

This contract is for vaulting (and releasing) ERC721 tokens

_Only the contract owner can authorize or deauthorize addresses._

### ContractMapping

```solidity
struct ContractMapping {
  address sisterContractAddress;
  string tokenName;
  string tokenSymbol;
  mapping(uint256 => bool) tokenInVault;
}
```

### originalToWrappedCollection

```solidity
mapping(address => struct Erc721Vault.ContractMapping) originalToWrappedCollection
```

### wrappedToOriginal

```solidity
mapping(address => address) wrappedToOriginal
```

### isNativeCollection

```solidity
mapping(address => bool) isNativeCollection
```

### Authorized

```solidity
event Authorized(address addr, bool authorized)
```

### TokensReleased

```solidity
event TokensReleased(address to, address contractAddress, uint256[] tokenIds)
```

### TokensReleasedAndOrMinted

```solidity
event TokensReleasedAndOrMinted(address to, address contractAddress, uint256[] tokenIds)
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

### init

```solidity
function init(address addressManager) external
```

Initialize the contract with an address manager

#### Parameters

| Name           | Type    | Description                        |
| -------------- | ------- | ---------------------------------- |
| addressManager | address | The address of the address manager |

### releaseTokens

```solidity
function releaseTokens(address recipient, address tokenContract, uint256[] tokenIds) public
```

Transfer token(s) from Erc721Vault to a designated address, checking that the
sender is authorized. This function is called when we need to send back tokens
to owner due to failed messgae status on destination chain.

#### Parameters

| Name          | Type      | Description                  |
| ------------- | --------- | ---------------------------- |
| recipient     | address   | Address to receive tokens.   |
| tokenContract | address   | Token contract.              |
| tokenIds      | uint256[] | Array of tokenIds to be sent |

### releaseOrMintTokens

```solidity
function releaseOrMintTokens(address recipient, address tokenContract, uint256[] tokenIds, string[] tokenURIs, string tokenName, string tokenSymbol) public
```

Transfer token(s) from Erc721Vault to a designated address, checking that the
sender is authorized. This is called during bridging (!). This is called from processMessage()
so always on the 'other side' of the chain where was initiated.

#### Parameters

| Name          | Type      | Description                  |
| ------------- | --------- | ---------------------------- |
| recipient     | address   | Address to receive tokens    |
| tokenContract | address   | Token contract               |
| tokenIds      | uint256[] | Array of tokenIds to be sent |
| tokenURIs     | string[]  | Array of tokenURIs           |
| tokenName     | string    | Name of the token            |
| tokenSymbol   | string    | Token symbol                 |

### setNative

```solidity
function setNative(address tokenContract) public
```

Called when sendMessage is called and sets if contract is native or not.

#### Parameters

| Name          | Type    | Description            |
| ------------- | ------- | ---------------------- |
| tokenContract | address | Token contract address |

### authorize

```solidity
function authorize(address addr, bool authorized) public
```

Set the authorized status of an address, only the owner can call this.

#### Parameters

| Name       | Type    | Description                              |
| ---------- | ------- | ---------------------------------------- |
| addr       | address | Address to set the authorized status of. |
| authorized | bool    | Authorized status to set.                |

### isAuthorized

```solidity
function isAuthorized(address addr) public view returns (bool)
```

Get the authorized status of an address.

#### Parameters

| Name | Type    | Description                              |
| ---- | ------- | ---------------------------------------- |
| addr | address | Address to get the authorized status of. |

### getOriginalContractAddress

```solidity
function getOriginalContractAddress(address tokenContract) public view returns (address)
```

If the asset during bridging has a counterpart in the wrappedToOriginal then we need to use it
as original contract address - so that we get back our original assets on the original chain.

#### Parameters

| Name          | Type    | Description                                                  |
| ------------- | ------- | ------------------------------------------------------------ |
| tokenContract | address | Address to check if the token in query is a wrap or original |

### onERC721Received

```solidity
function onERC721Received(address, address, uint256, bytes) external pure returns (bytes4)
```

---

## title: ProxiedErc721Vault

## ProxiedErc721Vault
