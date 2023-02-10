---
title: EtherVault
---

## EtherVault

EtherVault is a special vault contract that:

- Is initialized with 2^128 Ether.
- Allows the contract owner to authorize addresses.
- Allows authorized addresses to send/release Ether.

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

### init

```solidity
function init(address addressManager) external
```

### releaseEther

```solidity
function releaseEther(uint256 amount) public
```

Transfer Ether from EtherVault to the sender, checking that the sender
is authorized.

#### Parameters

| Name   | Type    | Description              |
| ------ | ------- | ------------------------ |
| amount | uint256 | Amount of Ether to send. |

### releaseEther

```solidity
function releaseEther(address recipient, uint256 amount) public
```

Transfer Ether from EtherVault to a designated address, checking that the
sender is authorized.

#### Parameters

| Name      | Type    | Description               |
| --------- | ------- | ------------------------- |
| recipient | address | Address to receive Ether. |
| amount    | uint256 | Amount of ether to send.  |

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
