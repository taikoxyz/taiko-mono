## V1Finalizing

### BlockFinalized

```solidity
event BlockFinalized(uint256 id, bytes32 blockHash)
```

### HeaderSynced

```solidity
event HeaderSynced(uint256 height, uint256 srcHeight, bytes32 srcHash)
```

### init

```solidity
function init(struct LibData.State s, bytes32 _genesisBlockHash, uint256 _avgFee) public
```

### finalizeBlocks

```solidity
function finalizeBlocks(struct LibData.State s, contract AddressResolver resolver, uint256 maxBlocks) public
```

### getProofReward

```solidity
function getProofReward(struct LibData.State s, uint64 provenAt, uint64 proposedAt, uint64 gasLimit) public view returns (uint256 reward, uint256 premiumReward)
```

