---
title: TaikoEvents
---

## TaikoEvents

### Bid

```solidity
event Bid(uint64 batchId, uint64 startedAt, struct TaikoData.Bid bid)
```

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct TaikoData.BlockMetadata meta, uint64 blockFee)
```

### BlockProven

```solidity
event BlockProven(uint256 id, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover, uint32 parentGasUsed)
```

### BlockVerified

```solidity
event BlockVerified(uint256 id, bytes32 blockHash, uint64 proposerFefund, uint64 proverReward)
```

### EthDeposited

```solidity
event EthDeposited(struct TaikoData.EthDeposit deposit)
```

### ProofParamsChanged

```solidity
event ProofParamsChanged(uint64 proofTimeTarget, uint64 proofTimeIssued, uint64 feePerGas, uint16 adjustmentQuotient)
```
