## TaikoData

### FeeConfig

```solidity
struct FeeConfig {
  uint16 avgTimeMAF;
  uint16 dampingFactorBips;
}
```

### Config

```solidity
struct Config {
  uint256 chainId;
  uint256 maxNumProposedBlocks;
  uint256 ringBufferSize;
  uint256 maxNumVerifiedBlocks;
  uint256 maxVerificationsPerTx;
  uint256 blockMaxGasLimit;
  uint256 maxTransactionsPerBlock;
  uint256 maxBytesPerTxList;
  uint256 minTxGasLimit;
  uint256 slotSmoothingFactor;
  uint256 rewardBurnBips;
  uint256 proposerDepositPctg;
  uint64 maxEthDepositPerBlock;
  uint256 feeBaseMAF;
  uint256 txListCacheExpiry;
  uint256 proofCooldownPeriod;
  bool relaySignalRoot;
  bool enableSoloProposer;
  bool enableTokenomics;
  bool skipZKPVerification;
  struct TaikoData.FeeConfig proposingConfig;
  struct TaikoData.FeeConfig provingConfig;
}
```

### StateVariables

```solidity
struct StateVariables {
  uint64 feeBase;
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
  uint64[] ethDepositIds;
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
  bytes32 graffiti;
  address prover;
  uint32 parentGasUsed;
  uint32 gasUsed;
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
  uint48 amountGwei;
  uint48 feeGwei;
}
```

### State

```solidity
struct State {
  mapping(uint256 => struct TaikoData.Block) blocks;
  mapping(uint256 => mapping(bytes32 => mapping(uint32 => uint256))) forkChoiceIds;
  mapping(address => uint256) balances;
  mapping(bytes32 => struct TaikoData.TxListInfo) txListInfo;
  mapping(uint256 => struct TaikoData.EthDeposit) ethDeposits;
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 __reserved1;
  uint64 __reserved2;
  uint64 numBlocks;
  uint64 lastProposedAt;
  uint64 avgBlockTime;
  uint64 nextEthDepositId;
  uint64 lastVerifiedBlockId;
  uint64 __reserved4;
  uint64 avgProofTime;
  uint64 feeBase;
  uint256[43] __gap;
}
```
