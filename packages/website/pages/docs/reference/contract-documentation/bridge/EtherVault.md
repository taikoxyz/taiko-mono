---
title: EtherVault
---

## EtherVault

Vault that holds Ether.

### Authorized

```solidity
event Authorized(address addr, bool authorized)
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

### receive

```solidity
receive() external payable
```

### init

```solidity
function init(address addressManager) external
```

### receiveEther

```solidity
function receiveEther(uint256 amount) public
```

Send Ether from EtherVault to the sender, checking they are authorized.

#### Parameters

| Name   | Type    | Description              |
| ------ | ------- | ------------------------ |
| amount | uint256 | Amount of ether to send. |

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
