## V1Finalizing

### BlockVerified

```solidity
event BlockVerified(uint256 id, bytes32 blockHash)
```

### HeaderSynced

```solidity
event HeaderSynced(uint256 height, uint256 srcHeight, bytes32 srcHash)
```

### init

```solidity
function init(struct LibData.State s, bytes32 _genesisBlockHash) public
```

### verifyBlocks

```solidity
function verifyBlocks(struct LibData.State s, uint256 maxBlocks) public
```
