---
title: TaikoData
---

## TaikoData

This library defines various data structures used in the Taiko
protocol.

### Config

_Struct holding Taiko configuration parameters. See {TaikoConfig}._

```solidity
struct Config {
  uint256 chainId;
  bool relaySignalRoot;
  uint64 blockMaxProposals;
  uint64 blockRingBufferSize;
  uint64 maxBlocksToVerifyPerProposal;
  uint32 blockMaxGasLimit;
  uint32 blockFeeBaseGas;
  uint24 blockMaxTxListBytes;
  uint256 blockTxListExpiry;
  uint256 proposerRewardPerSecond;
  uint256 proposerRewardMax;
  uint96 livenessBond;
  uint256 ethDepositRingBufferSize;
  uint64 ethDepositMinCountPerBlock;
  uint64 ethDepositMaxCountPerBlock;
  uint96 ethDepositMinAmount;
  uint96 ethDepositMaxAmount;
  uint256 ethDepositGas;
  uint256 ethDepositMaxFee;
}
```

### StateVariables

_Struct holding state variables._

```solidity
struct StateVariables {
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 nextEthDepositToProcess;
  uint64 numEthDeposits;
  uint64 numBlocks;
  uint64 lastVerifiedBlockId;
}
```

### ProverAssignment and TierFee

_Struct representing prover assignment and associated tiers_

```solidity
struct TierFee {
    uint16 tier;
    uint256 fee;
}

struct ProverAssignment {
    address prover;
    address feeToken;
    TierFee[] tierFees;
    uint64 expiry;
    bytes signature;
}
```

### BlockMetadata

_Struct containing data only required for proving a block
Warning: changing this struct requires changing {LibUtils.hashMetadata}
accordingly._

```solidity
struct BlockMetadata {
  bytes32 l1Hash;
  bytes32 mixHash;
  bytes32 txListHash;
  uint64 id;
  uint64 timestamp;
  uint64 l1Height;
  uint32 gasLimit;
  address coinbase;
  TaikoData.EthDeposit[] depositsProcessed;
}
```

### BlockEvidence

_Struct representing block evidence._

```solidity
struct BlockEvidence {
  bytes32 metaHash;
  bytes32 parentHash;
  bytes32 blockHash;
  bytes32 signalRoot;
  bytes32 graffiti;
  uint16 tier;
  bytes proof;
}
```

### Transition

_Struct representing state transition data.
10 slots reserved for upgradability, 6 slots used._

```solidity
struct Transition {
  bytes32 key;
  bytes32 blockHash;
  bytes32 signalRoot;
  address prover;
  uint96 validityBond;
  address contester;
  uint96 contestBond;
  uint64 timestamp;
  uint16 tier;
  bytes32[4] __reserved;
}
```

### Block

_Struct containing data required for verifying a block.
10 slots reserved for upgradability, 3 slots used._

```solidity
struct Block {
  bytes32 metaHash;
  address assignedProver;
  uint96 livenessBond;
  uint64 blockId;
  uint64 proposedAt;
  uint32 nextTransitionId;
  uint32 verifiedTransitionId;
  uint16 minTier;
  bytes32[7] __reserved;
}
```

### EthDeposit

_Struct representing an Ethereum deposit.
1 slot used._

```solidity
struct EthDeposit {
  address recipient;
  uint96 amount;
  uint64 id;
}
```

### SlotA

_Forge is only able to run coverage in case the contracts by default
capable of compiling without any optimization (neither optimizer runs,
no compiling --via-ir flag).
In order to resolve stack too deep without optimizations, we needed to
introduce outsourcing vars into structs below._

```solidity
struct SlotA {
  uint64 genesisHeight;
  uint64 genesisTimestamp;
  uint64 numEthDeposits;
  uint64 nextEthDepositToProcess;
}
```

### SlotB

```solidity
struct SlotB {
  uint64 numBlocks;
  uint64 nextEthDepositToProcess;
  uint64 lastVerifiedAt;
  uint64 lastVerifiedBlockId;
}
```

### State

_Struct holding the state variables for the {TaikoL1} contract._

```solidity
struct State {
  mapping(uint64 => struct TaikoData.Block) blocks;
  mapping(uint64 => mapping(uint32 => struct TaikoData.Transition)) transitions;
  mapping(uint64 => mapping(bytes32 => uint32)) transitionIds;
  mapping(uint256 => uint256) ethDeposits;
  mapping(address => uint256) tokenBalances;
  struct TaikoData.SlotA slotA;
  struct TaikoData.SlotB slotB;
  uint256[143] __gap;
}
```
