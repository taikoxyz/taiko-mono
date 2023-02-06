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
  uint256 zkProofsPerBlock;
  uint256 maxVerificationsPerTx;
  uint256 commitConfirmations;
  uint256 maxProofsPerForkChoice;
  uint256 blockMaxGasLimit;
  uint256 maxTransactionsPerBlock;
  uint256 maxBytesPerTxList;
  uint256 minTxGasLimit;
  uint256 anchorTxGasLimit;
  uint256 feePremiumLamda;
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
  uint64 initialUncleDelay;
  bool enableTokenomics;
  bool enablePublicInputsCheck;
  bool enableProofValidation;
  bool enableOracleProver;
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
  uint64 provenAt;
  address[] provers;
}
```

### State

```solidity
struct State {
  mapping(uint256 => bytes32) l2Hashes;
  mapping(uint256 => struct TaikoData.ProposedBlock) proposedBlocks;
  mapping(uint256 => mapping(bytes32 => struct TaikoData.ForkChoice)) forkChoices;
  mapping(address => mapping(uint256 => bytes32)) commits;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 __reservedA1;
  uint64 statusBits;
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
