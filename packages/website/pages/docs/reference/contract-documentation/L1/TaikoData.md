---
title: TaikoData
---

## TaikoData

### Config

```solidity
struct Config {
  uint256 chainId;
  bool relaySignalRoot;
  uint256 blockMaxProposals;
  uint256 blockRingBufferSize;
  uint256 blockMaxVerificationsPerTx;
  uint32 blockMaxGasLimit;
  uint32 blockFeeBaseGas;
  uint64 blockMaxTransactions;
  uint64 blockMaxTxListBytes;
  uint256 blockTxListExpiry;
  uint256 proofCooldownPeriod;
  uint256 systemProofCooldownPeriod;
  uint256 proofRegularCooldown;
  uint256 proofOracleCooldown;
  uint256 realProofSkipSize;
  uint16 proofMinWindow;
  uint16 proofMaxWindow;
  uint256 ethDepositRingBufferSize;
  uint64 ethDepositMinCountPerBlock;
  uint64 ethDepositMaxCountPerBlock;
  uint96 ethDepositMinAmount;
  uint96 ethDepositMaxAmount;
  uint256 ethDepositGas;
  uint256 ethDepositMaxFee;
  uint8 rewardOpenMultipler;
  uint256 rewardOpenMaxCount;
}
```

### StateVariables

```solidity
struct StateVariables {
  uint32 feePerGas;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 numBlocks;
  uint64 lastVerifiedBlockId;
  uint64 nextEthDepositToProcess;
  uint64 numEthDeposits;
}
```

### StateVariables_A3

```solidity
struct StateVariables_A3 {
  uint64 blockFee;
  uint64 accBlockFees;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 numBlocks;
  uint64 proofTimeIssued;
  uint64 proofTimeTarget;
  uint64 lastVerifiedBlockId;
  uint64 accProposedAt;
  uint64 nextEthDepositToProcess;
  uint64 numEthDeposits;
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
  uint64 timestamp;
  uint64 l1Height;
  bytes32 l1Hash;
  bytes32 mixHash;
  bytes32 txListHash;
  uint24 txListByteStart;
  uint24 txListByteEnd;
  uint32 gasLimit;
  address beneficiary;
  address treasury;
  struct TaikoData.EthDeposit[] depositsProcessed;
}
```

### BlockEvidence

```solidity
struct BlockEvidence {
  bytes32 metaHash;
  bytes32 parentHash;
  bytes32 blockHash;
  bytes32 signalRoot;
  bytes32 graffiti;
  address prover;
  uint32 parentGasUsed;
  uint32 gasUsed;
  uint16 verifierId;
  bytes proof;
}
```

### ForkChoice

```solidity
struct ForkChoice {
  bytes32 key;
  bytes32 blockHash;
  bytes32 signalRoot;
  uint64 provenAt;
  address prover;
  uint32 gasUsed;
}
```

### Block

```solidity
struct Block {
  mapping(uint256 => struct TaikoData.ForkChoice) forkChoices;
  bytes32 metaHash;
  uint64 blockId;
  uint32 gasLimit;
  uint24 nextForkChoiceId;
  uint24 verifiedForkChoiceId;
  bool proverReleased;
  address proposer;
  uint32 feePerGas;
  uint64 proposedAt;
  address assignedProver;
  uint32 rewardPerGas;
  uint64 proofWindow;
}
```

### Block_A3

```solidity
struct Block_A3 {
  mapping(uint256 => struct TaikoData.ForkChoice) forkChoices;
  uint64 blockId;
  uint64 proposedAt;
  uint24 nextForkChoiceId;
  uint24 verifiedForkChoiceId;
  bytes32 metaHash;
  address proposer;
}
```

### TxListInfo

```solidity
struct TxListInfo {
  uint64 validSince;
  uint24 size;
}
```

### EthDeposit

```solidity
struct EthDeposit {
  address recipient;
  uint96 amount;
  uint64 id;
}
```

### Slot6

```solidity
struct Slot6 {
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint16 adjustmentQuotient;
  uint32 feePerGas;
  uint16 avgProofDelay;
  uint64 numOpenBlocks;
}
```

### Slot7

```solidity
struct Slot7 {
  uint64 accProposedAt;
  uint64 accBlockFees;
  uint64 numBlocks;
  uint64 nextEthDepositToProcess;
}
```

### Slot8

```solidity
struct Slot8 {
  uint64 blockFee;
  uint64 proofTimeIssued;
  uint64 lastVerifiedBlockId;
  uint64 proofTimeTarget;
}
```

### State

```solidity
struct State {
  mapping(uint256 => struct TaikoData.Block_A3) blocks_A3;
  mapping(uint256 => mapping(bytes32 => mapping(uint32 => uint24))) forkChoiceIds;
  mapping(address => uint256) taikoTokenBalances;
  mapping(bytes32 => struct TaikoData.TxListInfo) txListInfo;
  struct TaikoData.EthDeposit[] ethDeposits_A3;
  struct TaikoData.Slot6 slot6;
  struct TaikoData.Slot7 slot7;
  struct TaikoData.Slot8 slot8;
  uint64 numEthDeposits;
  uint64 lastVerifiedAt;
  mapping(uint256 => struct TaikoData.Block) blocks;
  mapping(uint256 => uint256) ethDeposits;
  uint256[39] __gap;
}
```
