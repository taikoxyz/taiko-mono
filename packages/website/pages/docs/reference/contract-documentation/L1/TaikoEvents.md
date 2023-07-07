---
title: TaikoEvents
---

## TaikoEvents

### BlockProposed

```solidity
event BlockProposed(uint256 blockId, address assignedProver, uint32 rewardPerGas, uint64 feePerGas, struct TaikoData.BlockMetadata meta)
```

### BlockProven

```solidity
event BlockProven(uint256 blockId, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover, uint32 parentGasUsed)
```

### BlockVerified

```solidity
event BlockVerified(uint256 blockId, bytes32 blockHash, address prover, uint64 blockFee, uint64 reward)
```

### EthDeposited

```solidity
event EthDeposited(struct TaikoData.EthDeposit deposit)
```
