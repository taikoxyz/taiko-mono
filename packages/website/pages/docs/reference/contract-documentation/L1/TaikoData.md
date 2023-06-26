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
  uint256 proofRegularCooldown;
  uint256 proofOracleCooldown;
  uint16 proofMinWindow;
  uint16 proofMaxWindow;
  uint256 ethDepositRingBufferSize;
  uint64 ethDepositMinCountPerBlock;
  uint64 ethDepositMaxCountPerBlock;
  uint96 ethDepositMinAmount;
  uint96 ethDepositMaxAmount;
  uint256 ethDepositGas;
  uint256 ethDepositMaxFee;
  uint32 rewardPerGasRange;
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

### BlockMetadataInput

```solidity
struct BlockMetadataInput {
  bytes32 txListHash;
  address beneficiary;
  uint32 gasLimit;
  uint24 txListByteStart;
  uint24 txListByteEnd;
  bool cacheTxListInfo;
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
  address prover;
  uint64 provenAt;
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
  address prover;
  uint32 rewardPerGas;
  uint64 proofWindow;
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

### State

```solidity
struct State {
  mapping(uint256 => struct TaikoData.Block) blocks;
  mapping(uint256 => mapping(bytes32 => mapping(uint32 => uint24))) forkChoiceIds;
  mapping(bytes32 => struct TaikoData.TxListInfo) txListInfo;
  mapping(uint256 => uint256) ethDeposits;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 __reserved70;
  uint64 __reserved71;
  uint64 numOpenBlocks;
  uint64 numEthDeposits;
  uint64 numBlocks;
  uint64 nextEthDepositToProcess;
  uint64 lastVerifiedAt;
  uint64 lastVerifiedBlockId;
  uint64 __reserved90;
  uint32 feePerGas;
  uint16 avgProofDelay;
  uint256[43] __gap;
}
```
