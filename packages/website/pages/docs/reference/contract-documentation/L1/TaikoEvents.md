---
title: TaikoEvents
---

## TaikoEvents

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
event BlockVerified(uint256 id, bytes32 blockHash, uint64 reward)
```

### EthDeposited

```solidity
event EthDeposited(struct TaikoData.EthDeposit deposit)
```

### ProofParamsChanged

```solidity
event ProofParamsChanged(uint64 proofTimeTarget, uint64 proofTimeIssued, uint64 blockFee, uint16 adjustmentQuotient)
```

### Bid

```solidity
event Bid(uint256 id, address bidder, uint256 bidAt, uint256 deposit, uint256 feePerGas)
```
