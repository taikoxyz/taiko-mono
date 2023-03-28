## TaikoData

### Config

```solidity
struct Config {
  uint256 chainId;
  uint256 maxNumBlocks;
  uint256 blockHashHistory;
  uint256 maxVerificationsPerTx;
  uint256 commitConfirmations;
  uint256 blockMaxGasLimit;
  uint256 maxTransactionsPerBlock;
  uint256 maxBytesPerTxList;
  uint256 minTxGasLimit;
  uint256 anchorTxGasLimit;
  uint256 slotSmoothingFactor;
  uint256 rewardBurnBips;
  uint256 proposerDepositPctg;
  uint256 feeBaseMAF;
  uint256 blockTimeMAF;
  uint256 proofTimeMAF;
  uint64 rewardMultiplierPctg;
  uint64 feeGracePeriodPctg;
  uint64 feeMaxPeriodPctg;
  uint64 blockTimeCap;
  uint64 proofTimeCap;
  uint64 bootstrapDiscountHalvingPeriod;
  bool enableTokenomics;
  bool enablePublicInputsCheck;
  bool enableAnchorValidation;
}
```

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

### Evidence

```solidity
struct Evidence {
  struct TaikoData.BlockMetadata meta;
  struct BlockHeader header;
  address prover;
  bytes[] proofs;
  uint16 circuitId;
}
```

### ProposedBlock

```solidity
struct ProposedBlock {
  bytes32 metaHash;
  uint256 deposit;
  address proposer;
  uint64 proposedAt;
}
```

### ForkChoice

```solidity
struct ForkChoice {
  bytes32 blockHash;
  address prover;
  uint64 provenAt;
}
```

### State

```solidity
struct State {
  mapping(uint256 => bytes32) l2Hashes;
  mapping(uint256 => struct TaikoData.ProposedBlock) proposedBlocks;
  mapping(uint256 => mapping(bytes32 => struct TaikoData.ForkChoice)) forkChoices;
  mapping(address => mapping(uint256 => bytes32)) commits;
  mapping(address => uint256) balances;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 __reservedA1;
  uint64 __reservedA2;
  uint256 feeBase;
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
