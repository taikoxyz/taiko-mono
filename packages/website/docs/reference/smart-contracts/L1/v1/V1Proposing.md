## V1Proposing

### BlockCommitted

```solidity
event BlockCommitted(uint64 commitSlot, uint64 commitHeight, bytes32 commitHash)
```

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct LibData.BlockMetadata meta)
```

### onlyWhitelistedProposer

```solidity
modifier onlyWhitelistedProposer(struct LibData.TentativeState tentative)
```

### commitBlock

```solidity
function commitBlock(struct LibData.State state, uint64 commitSlot, bytes32 commitHash) public
```

### proposeBlock

```solidity
function proposeBlock(struct LibData.State state, struct LibData.TentativeState tentative, contract AddressResolver resolver, bytes[] inputs) public
```

### isCommitValid

```solidity
function isCommitValid(struct LibData.State state, uint256 commitSlot, uint256 commitHeight, bytes32 commitHash) public view returns (bool)
```

### _verifyBlockCommit

```solidity
function _verifyBlockCommit(struct LibData.State state, struct LibData.BlockMetadata meta) private
```

### _validateMetadata

```solidity
function _validateMetadata(struct LibData.BlockMetadata meta) private pure
```

### _calculateCommitHash

```solidity
function _calculateCommitHash(address beneficiary, bytes32 txListHash) private pure returns (bytes32)
```

### _aggregateCommitHash

```solidity
function _aggregateCommitHash(uint256 commitHeight, bytes32 commitHash) private pure returns (bytes32)
```

