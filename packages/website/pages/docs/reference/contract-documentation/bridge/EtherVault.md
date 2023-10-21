---
title: EtherVault
---

## EtherVault

This contract is initialized with 2^128 Ether and allows authorized
addresses to release Ether.

_Only the contract owner can authorize or deauthorize addresses._

### Authorized

```solidity
event Authorized(address addr, bool authorized)
```

### EtherReleased

```solidity
event EtherReleased(address to, uint256 amount)
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

### receive

```solidity
receive() external payable
```

Function to receive Ether.

_Only authorized addresses can send Ether to the contract._

### init

```solidity
function init(address addressManager) external
```

Initializes the contract with an {AddressManager}.

#### Parameters

| Name           | Type    | Description                                   |
| -------------- | ------- | --------------------------------------------- |
| addressManager | address | The address of the {AddressManager} contract. |

### releaseEther

```solidity
function releaseEther(uint256 amount) public
```

Transfers Ether from EtherVault to the sender, checking that the
sender is authorized.

#### Parameters

| Name   | Type    | Description              |
| ------ | ------- | ------------------------ |
| amount | uint256 | Amount of Ether to send. |

### releaseEther

```solidity
function releaseEther(address recipient, uint256 amount) public
```

Transfers Ether from EtherVault to a designated address,
checking that the sender is authorized.

#### Parameters

| Name      | Type    | Description               |
| --------- | ------- | ------------------------- |
| recipient | address | Address to receive Ether. |
| amount    | uint256 | Amount of ether to send.  |

### authorize

```solidity
function authorize(address addr, bool authorized) public
```

Sets the authorized status of an address, only the owner can
call this function.

#### Parameters

| Name       | Type    | Description                              |
| ---------- | ------- | ---------------------------------------- |
| addr       | address | Address to set the authorized status of. |
| authorized | bool    | Authorized status to set.                |

### isAuthorized

```solidity
function isAuthorized(address addr) public view returns (bool)
```

Gets the authorized status of an address.

#### Parameters

| Name | Type    | Description                              |
| ---- | ------- | ---------------------------------------- |
| addr | address | Address to get the authorized status of. |

---

## title: ProxiedEtherVault

## ProxiedEtherVault

Proxied version of the parent contract.
