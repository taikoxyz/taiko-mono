## LibData

### BlockMetadata

```solidity
struct BlockMetadata {
  uint256 id;
  uint256 l1Height;
  bytes32 l1Hash;
  address beneficiary;
  bytes32 txListHash;
  bytes32 mixHash;
  bytes extraData;
  uint64 gasLimit;
  uint64 timestamp;
  uint64 commitHeight;
  uint64 commitSlot;
}

```

### ProposedBlock

```solidity
struct ProposedBlock {
  bytes32 metaHash;
  address proposer;
  uint64 proposedAt;
}

```

### ForkChoice

```solidity
struct ForkChoice {
  bytes32 blockHash;
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
  mapping(address => mapping(uint256 => bytes32)) commits;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 __reservedA1;
  uint64 statusBits;
  uint64 nextBlockId;
  uint64 lastProposedAt;
  uint64 avgBlockTime;
  uint64 __avgGasLimit;
  uint64 latestVerifiedHeight;
  uint64 latestVerifiedId;
  uint64 avgProofTime;
  uint64 __reservedC1;
  uint256[42] __gap;
}
```

### TentativeState

```solidity
struct TentativeState {
  mapping(address => bool) proposers;
  mapping(address => bool) provers;
  bool whitelistProposers;
  bool whitelistProvers;
  uint256[46] __gap;
}

```

### saveProposedBlock

```solidity
function saveProposedBlock(struct LibData.State state, uint256 id, struct LibData.ProposedBlock blk) internal
```

### getProposedBlock

```solidity
function getProposedBlock(struct LibData.State state, uint256 id) internal view returns (struct LibData.ProposedBlock)
```

### getL2BlockHash

```solidity
function getL2BlockHash(struct LibData.State state, uint256 number) internal view returns (bytes32)
```

### getStateVariables

```solidity
function getStateVariables(struct LibData.State state) internal view returns (uint64 genesisHeight, uint64 latestVerifiedHeight, uint64 latestVerifiedId, uint64 nextBlockId)
```

### hashMetadata

```solidity
function hashMetadata(struct LibData.BlockMetadata meta) internal pure returns (bytes32)
```
