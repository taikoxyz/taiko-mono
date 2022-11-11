## LibData

### BlockMetadata

```solidity
struct BlockMetadata {
  uint256 id;
  uint256 l1Height;
  bytes32 l1Hash;
  address beneficiary;
  uint64 gasLimit;
  uint64 timestamp;
  bytes32 txListHash;
  bytes32 mixHash;
  bytes extraData;
}

```

### ProposedBlock

```solidity
struct ProposedBlock {
  bytes32 metaHash;
  address proposer;
  uint64 gasLimit;
}

```

### ForkChoice

```solidity
struct ForkChoice {
  bytes32 blockHash;
  uint64 proposedAt;
  uint64 provenAt;
  address[] provers;
}

```

### State

```solidity
struct State {
  mapping(uint256 => bytes32) l2Hashes;
  mapping(uint256 => struct LibData.ProposedBlock) proposedBlocks;
  mapping(uint256 => mapping(bytes32 => struct LibData.ForkChoice)) forkChoices;
  mapping(bytes32 => uint256) commits;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 reservedA1;
  uint64 reservedA2;
  uint256 feeBase;
  uint64 nextBlockId;
  uint64 lastProposedAt;
  uint64 avgBlockTime;
  uint64 avgGasLimit;
  uint64 latestFinalizedHeight;
  uint64 latestFinalizedId;
  uint64 avgProofTime;
  uint64 reservedC1;
}
```

### saveProposedBlock

```solidity
function saveProposedBlock(struct LibData.State s, uint256 id, struct LibData.ProposedBlock blk) internal
```

### getProposedBlock

```solidity
function getProposedBlock(struct LibData.State s, uint256 id) internal view returns (struct LibData.ProposedBlock)
```

### getL2BlockHash

```solidity
function getL2BlockHash(struct LibData.State s, uint256 number) internal view returns (bytes32)
```

### getStateVariables

```solidity
function getStateVariables(struct LibData.State s) internal view returns (uint64 genesisHeight, uint64 latestFinalizedHeight, uint64 latestFinalizedId, uint64 nextBlockId)
```

### hashMetadata

```solidity
function hashMetadata(struct LibData.BlockMetadata meta) internal pure returns (bytes32)
```
