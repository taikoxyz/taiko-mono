---
title: TaikoGovernor
---

## TaikoGovernor

### constructor

```solidity
constructor(contract IVotes _token, contract TimelockController _timelock) public
```

### propose

```solidity
function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)
```

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view returns (bool)
```

### state

```solidity
function state(uint256 proposalId) public view returns (enum IGovernor.ProposalState)
```

### votingDelay

```solidity
function votingDelay() public pure returns (uint256)
```

module:user-config

_Delay, in number of block, between the proposal is created and the vote starts. This can be increassed to
leave time for users to buy voting power, or delegate it, before the voting of a proposal starts._

### votingPeriod

```solidity
function votingPeriod() public pure returns (uint256)
```

module:user-config

_Delay, in number of blocks, between the vote start and vote ends.

NOTE: The {votingDelay} can delay the start of the vote. This must be considered when setting the voting
duration compared to the voting delay._

### proposalThreshold

```solidity
function proposalThreshold() public pure returns (uint256)
```

_Part of the Governor Bravo's interface: _"The number of votes required in order for a voter to become a proposer"_._

### _execute

```solidity
function _execute(uint256 proposalId, address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) internal
```

### _cancel

```solidity
function _cancel(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) internal returns (uint256)
```

### _executor

```solidity
function _executor() internal view returns (address)
```

