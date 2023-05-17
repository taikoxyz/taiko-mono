---
title: TaikoEvents
---

## TaikoEvents

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct TaikoData.BlockMetadata meta)
```

### BlockProven

```solidity
event BlockProven(uint256 id, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover, uint32 parentGasUsed)
```

### BlockVerified

```solidity
event BlockVerified(uint256 id, bytes32 blockHash)
```

### EthDeposited

```solidity
event EthDeposited(struct TaikoData.EthDeposit deposit)
```

### ProofTimeTargetChanged

```solidity
event ProofTimeTargetChanged(uint64 proofTimeTarget)
```
