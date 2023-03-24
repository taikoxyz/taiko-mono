---
title: TaikoData
---

## TaikoData

### FeeConfig

```solidity
struct FeeConfig {
  uint16 avgTimeMAF;
  uint16 startBips;
}
```

### Config

```solidity
struct Config {
  uint256 chainId;
  uint256 maxNumProposedBlocks;
  uint256 maxNumVerifiedBlocks;
  uint256 maxVerificationsPerTx;
  uint256 blockMaxGasLimit;
  uint256 maxTransactionsPerBlock;
  uint256 maxBytesPerTxList;
  uint256 minTxGasLimit;
  uint256 slotSmoothingFactor;
  uint256 anchorTxGasLimit;
  uint256 rewardBurnBips;
  uint256 proposerDepositPctg;
  uint256 feeBaseMAF;
  uint64 bootstrapDiscountHalvingPeriod;
  uint64 constantFeeRewardBlocks;
  uint64 txListCacheExpiry;
  bool enableSoloProposer;
  bool enableOracleProver;
  bool enableTokenomics;
  bool skipZKPVerification;
  struct TaikoData.FeeConfig proposingConfig;
  struct TaikoData.FeeConfig provingConfig;
}
```

### StateVariables

```solidity
struct StateVariables {
  uint64 feeBaseTwei;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 numBlocks;
  uint64 lastVerifiedBlockId;
  uint64 avgBlockTime;
  uint64 avgProofTime;
  uint64 lastProposedAt;
}
```

### BlockMetadataInput

```solidity
struct BlockMetadataInput {
  bytes32 txListHash;
  address beneficiary;
  uint32 gasLimit;
  uint24 txListByteStart;
  uint24 txListByteEnd;
  uint8 cacheTxListInfo;
}
```

### BlockMetadata

```solidity
struct BlockMetadata {
  uint64 id;
  uint32 gasLimit;
  uint64 timestamp;
  uint64 l1Height;
  bytes32 l1Hash;
  bytes32 mixHash;
  bytes32 txListHash;
  uint24 txListByteStart;
  uint24 txListByteEnd;
  address beneficiary;
}
```

### ZKProof

```solidity
struct ZKProof {
  bytes data;
  uint16 verifierId;
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

### ForkChoice

```solidity
struct ForkChoice {
  bytes32 blockHash;
  bytes32 signalRoot;
  address prover;
  uint64 provenAt;
}
```

### ProposedBlock

```solidity
struct ProposedBlock {
  bytes32 metaHash;
  uint256 deposit;
  address proposer;
  uint64 proposedAt;
  uint24 nextForkChoiceId;
  mapping(uint256 => struct TaikoData.ForkChoice) forkChoices;
}
```

### VerifiedBlock

```solidity
struct VerifiedBlock {
  uint64 blockId;
  bytes32 blockHash;
  bytes32 signalRoot;
}
```

### TxListInfo

```solidity
struct TxListInfo {
  uint64 validSince;
  uint24 size;
}
```

### State

```solidity
struct State {
  mapping(uint256 => struct TaikoData.ProposedBlock) proposedBlocks;
  mapping(uint256 => struct TaikoData.VerifiedBlock) verifiedBlocks;
  mapping(uint256 => mapping(bytes32 => uint256)) forkChoiceIds;
  mapping(address => uint256) balances;
  mapping(bytes32 => struct TaikoData.TxListInfo) txListInfo;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 __reserved1;
  uint64 __reserved2;
  uint64 numBlocks;
  uint64 lastProposedAt;
  uint64 avgBlockTime;
  uint64 __reserved3;
  uint64 __reserved4;
  uint64 lastVerifiedBlockId;
  uint64 avgProofTime;
  uint64 feeBaseTwei;
  uint256[42] __gap;
}
```
