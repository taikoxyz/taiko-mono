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
  uint64 blockMaxVerificationsPerTx;
  uint32 blockMaxGasLimit;
  uint32 blockFeeBaseGas;
  uint24 blockMaxTxListBytes;
  uint256 blockTxListExpiry;
  uint256 proposerRewardPerSecond;
  uint256 proposerRewardMax;
  uint256 proofRegularCooldown;
  uint256 proofOracleCooldown;
  uint16 proofWindow;
  uint96 proofBond;
  bool skipProverAssignmentVerificaiton;
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
  uint64 numBlocks;
  uint64 lastVerifiedBlockId;
  uint64 nextEthDepositToProcess;
  uint64 numEthDeposits;
}
```

### BlockMetadataInput

_Struct representing input data for block metadata._

```solidity
struct BlockMetadataInput {
  bytes32 txListHash;
  address proposer;
  uint24 txListByteStart;
  uint24 txListByteEnd;
  bool cacheTxListInfo;
}
```

### ProverAssignment

_Struct representing prover assignment_

```solidity
struct ProverAssignment {
  address prover;
  uint64 expiry;
  bytes data;
}
```

### BlockMetadata

_Struct containing data only required for proving a block
Warning: changing this struct requires changing {LibUtils.hashMetadata}
accordingly._

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
  address proposer;
  struct TaikoData.EthDeposit[] depositsProcessed;
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
  address prover;
  bytes proofs;
}
```

### Transition

_Struct representing state transition data.
10 slots reserved for upgradability, 4 slots used._

```solidity
struct Transition {
  bytes32 key;
  bytes32 blockHash;
  bytes32 signalRoot;
  address prover;
  uint64 provenAt;
  bytes32[6] __reserved;
}
```

### Block

_Struct containing data required for verifying a block.
10 slots reserved for upgradability, 3 slots used._

```solidity
struct Block {
  bytes32 metaHash;
  address prover;
  uint96 proofBond;
  uint64 blockId;
  uint64 proposedAt;
  uint32 nextTransitionId;
  uint32 verifiedTransitionId;
  bytes32[7] __reserved;
}
```

### TxListInfo

_Struct representing information about a transaction list.
1 slot used._

```solidity
struct TxListInfo {
  uint64 validSince;
  uint24 size;
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
  mapping(uint64 => mapping(bytes32 => uint32)) transitionIds;
  mapping(uint64 => mapping(uint32 => struct TaikoData.Transition)) transitions;
  mapping(bytes32 => struct TaikoData.TxListInfo) txListInfo;
  mapping(uint256 => uint256) ethDeposits;
  mapping(address => uint256) taikoTokenBalances;
  struct TaikoData.SlotA slotA;
  struct TaikoData.SlotB slotB;
  uint256[142] __gap;
}
```
