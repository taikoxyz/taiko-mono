---
title: TaikoData
---

## TaikoData

### Config

```solidity
struct Config {
  uint256 chainId;
  uint256 maxNumBlocks;
  uint256 blockHashHistory;
  uint256 maxVerificationsPerTx;
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
  bool enableSoloProposer;
  bool enableOracleProver;
  bool enableTokenomics;
  bool skipZKPVerification;
}
```

### StateVariables

```solidity
struct StateVariables {
  uint256 feeBase;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 nextBlockId;
  uint64 lastProposedAt;
  uint64 avgBlockTime;
  uint64 latestVerifiedHeight;
  uint64 latestVerifiedId;
  uint64 avgProofTime;
}
```

### BlockMetadataInput

```solidity
struct BlockMetadataInput {
  bytes32 txListHash;
  address beneficiary;
  uint64 gasLimit;
}
```

### BlockMetadata

```solidity
struct BlockMetadata {
  uint256 id;
  uint256 l1Height;
  bytes32 l1Hash;
  bytes32 mixHash;
  bytes32 txListHash;
  address beneficiary;
  uint64 gasLimit;
  uint64 timestamp;
}
```

### ZKProof

```solidity
struct ZKProof {
  bytes data;
  uint256 circuitId;
}
```

### BlockEvidence

```solidity
struct BlockEvidence {
  struct TaikoData.BlockMetadata meta;
  struct TaikoData.ZKProof zkproof;
  bytes32 parentHash;
  bytes32 blockHash;
  bytes32 signalRoot;
  address prover;
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
  struct ChainData chainData;
  address prover;
  uint64 provenAt;
}
```

### State

```solidity
struct State {
  mapping(uint256 => struct TaikoData.ProposedBlock) proposedBlocks;
  mapping(uint256 => mapping(bytes32 => struct TaikoData.ForkChoice)) forkChoices;
  mapping(uint256 => struct ChainData) l2ChainDatas;
  mapping(address => uint256) balances;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 __reserved1;
  uint64 __reserved2;
  uint64 nextBlockId;
  uint64 lastProposedAt;
  uint64 avgBlockTime;
  uint64 __reserved3;
  uint64 latestVerifiedHeight;
  uint64 latestVerifiedId;
  uint64 avgProofTime;
  uint64 feeBaseSzabo;
  uint256[42] __gap;
}
```
