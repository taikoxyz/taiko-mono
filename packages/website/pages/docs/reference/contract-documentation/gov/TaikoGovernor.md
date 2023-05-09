---
title: TaikoGovernor
---

## TaikoGovernor

### init

```solidity
function init(address _addressManager, contract IVotesUpgradeable _token, contract TimelockControllerUpgradeable _timelock) public
```

### propose

```solidity
function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)
```

### votingDelay

```solidity
function votingDelay() public view returns (uint256)
```

### votingPeriod

```solidity
function votingPeriod() public view returns (uint256)
```

### quorum

```solidity
function quorum(uint256 blockNumber) public view returns (uint256)
```

### state

```solidity
function state(uint256 proposalId) public view returns (enum IGovernorUpgradeable.ProposalState)
```

### proposalThreshold

```solidity
function proposalThreshold() public view returns (uint256)
```

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view returns (bool)
```

### \_execute

```solidity
function _execute(uint256 proposalId, address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) internal
```

### \_cancel

```solidity
function _cancel(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) internal returns (uint256)
```

### \_executor

```solidity
function _executor() internal view returns (address)
```

---

## title: ProxiedTaikoGovernor

## ProxiedTaikoGovernor
