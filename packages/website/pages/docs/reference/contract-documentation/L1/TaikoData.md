---
title: TaikoData
---

## TaikoData

### Config

```solidity
struct Config {
  uint256 chainId;
  uint256 maxNumProposedBlocks;
  uint256 ringBufferSize;
  uint256 maxVerificationsPerTx;
  uint256 blockMaxGasLimit;
  uint256 maxTransactionsPerBlock;
  uint256 maxBytesPerTxList;
  uint256 minTxGasLimit;
  uint256 txListCacheExpiry;
  uint256 proofCooldownPeriod;
  uint256 ethDepositGas;
  uint256 ethDepositMaxFee;
  uint64 minEthDepositsPerBlock;
  uint64 maxEthDepositsPerBlock;
  uint96 maxEthDepositAmount;
  uint96 minEthDepositAmount;
  uint64 proofTimeTarget;
  uint8 adjustmentQuotient;
  bool relaySignalRoot;
}
```

### StateVariables

```solidity
struct StateVariables {
  uint64 blockFee;
  uint64 accBlockFees;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 numBlocks;
  uint64 proofTimeIssued;
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
  bytes32 depositsRoot;
  bytes32 txListHash;
  uint24 txListByteStart;
  uint24 txListByteEnd;
  uint32 gasLimit;
  address beneficiary;
  uint8 cacheTxListInfo;
  address treasure;
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
  uint64 blockId;
  uint64 proposedAt;
  uint64 deposit;
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
}
```

### State

```solidity
struct State {
  mapping(uint256 => struct TaikoData.Block) blocks;
  mapping(uint256 => mapping(bytes32 => mapping(uint32 => uint256))) forkChoiceIds;
  mapping(address => uint256) taikoTokenBalances;
  mapping(bytes32 => struct TaikoData.TxListInfo) txListInfo;
  struct TaikoData.EthDeposit[] ethDeposits;
  bytes32 staticRefs;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 __reserved71;
  uint64 __reserved72;
  uint64 accProposedAt;
  uint64 accBlockFees;
  uint64 numBlocks;
  uint64 nextEthDepositToProcess;
  uint64 blockFee;
  uint64 proofTimeIssued;
  uint64 lastVerifiedBlockId;
  uint64 __reserved91;
  uint256[41] __gap;
}
```
