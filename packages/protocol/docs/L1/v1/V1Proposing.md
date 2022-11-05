## V1Proposing

### BlockCommitted

```solidity
event BlockCommitted(bytes32 hash, uint256 validSince)
```

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct LibData.BlockMetadata meta)
```

### commitBlock

```solidity
function commitBlock(struct LibData.State s, bytes32 commitHash) public
```

### proposeBlock

```solidity
function proposeBlock(struct LibData.State s, contract AddressResolver resolver, bytes[] inputs) public
```

### getBlockFee

```solidity
function getBlockFee(struct LibData.State s, uint64 gasLimit) public view returns (uint256 fee, uint256 premiumFee)
```

### isCommitValid

```solidity
function isCommitValid(struct LibData.State s, bytes32 hash) public view returns (bool)
```

### _updateAvgBlockTime

```solidity
function _updateAvgBlockTime(struct LibData.State s, uint64 blockTime) private
```

### _validateMetadata

```solidity
function _validateMetadata(struct LibData.BlockMetadata meta) private pure
```

### _calculateCommitHash

```solidity
function _calculateCommitHash(address beneficiary, bytes32 txListHash) private pure returns (bytes32)
```

