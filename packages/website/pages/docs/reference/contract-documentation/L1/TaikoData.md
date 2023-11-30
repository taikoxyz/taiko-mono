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
  uint64 chainId;
  uint64 blockMaxProposals;
  uint64 blockRingBufferSize;
  uint64 maxBlocksToVerifyPerProposal;
  uint32 blockMaxGasLimit;
  uint24 blockMaxTxListBytes;
  uint24 blobExpiry;
  bool blobAllowedForDA;
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

### TierFee

_Struct representing prover assignment_

```solidity
struct TierFee {
  uint16 tier;
  uint128 fee;
}
```

### TierProof

```solidity
struct TierProof {
  uint16 tier;
  bytes data;
}
```

### HookCall

```solidity
struct HookCall {
  address hook;
  bytes data;
}
```

### BlockParams

```solidity
struct BlockParams {
  address assignedProver;
  bytes32 extraData;
  bytes32 blobHash;
  uint24 txListByteOffset;
  uint24 txListByteSize;
  bool cacheBlobForReuse;
  bytes32 parentMetaHash;
  struct TaikoData.HookCall[] hookCalls;
}
```

### BlockMetadata

_Struct containing data only required for proving a block
Note: On L2, `block.difficulty` is the pseudo name of
`block.prevrandao`, which returns a random number provided by the layer
1 chain._

```solidity
struct BlockMetadata {
  bytes32 l1Hash;
  bytes32 difficulty;
  bytes32 blobHash;
  bytes32 extraData;
  bytes32 depositsHash;
  address coinbase;
  uint64 id;
  uint32 gasLimit;
  uint64 timestamp;
  uint64 l1Height;
  uint24 txListByteOffset;
  uint24 txListByteSize;
  uint16 minTier;
  bool blobUsed;
  bytes32 parentMetaHash;
}
```

### Transition

_Struct representing transition to be proven._

```solidity
struct Transition {
  bytes32 parentHash;
  bytes32 blockHash;
  bytes32 signalRoot;
  bytes32 graffiti;
}
```

### TransitionState

_Struct representing state transition data.
10 slots reserved for upgradability, 6 slots used._

```solidity
struct TransitionState {
  bytes32 key;
  bytes32 blockHash;
  bytes32 signalRoot;
  address prover;
  uint96 validityBond;
  address contester;
  uint96 contestBond;
  uint64 timestamp;
  uint16 tier;
  uint8 contestations;
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
  uint64 proposedIn;
  uint32 nextTransitionId;
  uint32 verifiedTransitionId;
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
  uint64 lastVerifiedBlockId;
  bool provingPaused;
}
```

### State

_Struct holding the state variables for the {TaikoL1} contract._

```solidity
struct State {
  mapping(uint64 => struct TaikoData.Block) blocks;
  mapping(uint64 => mapping(bytes32 => uint32)) transitionIds;
  mapping(uint64 => mapping(uint32 => struct TaikoData.TransitionState)) transitions;
  mapping(uint256 => uint256) ethDeposits;
  mapping(address => uint256) tokenBalances;
  mapping(bytes32 => uint256) reusableBlobs;
  struct TaikoData.SlotA slotA;
  struct TaikoData.SlotB slotB;
  uint256[142] __gap;
}
```
