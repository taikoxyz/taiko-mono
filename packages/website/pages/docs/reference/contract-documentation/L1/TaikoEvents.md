---
title: TaikoEvents
---

## TaikoEvents

### TxListInfoCached

```solidity
event TxListInfoCached(bytes32 txListHash, uint64 validSince)
```

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct TaikoData.BlockMetadata meta)
```

### BlockProven

```solidity
event BlockProven(uint256 id, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
```

### BlockVerified

```solidity
event BlockVerified(uint256 id, bytes32 blockHash)
```
