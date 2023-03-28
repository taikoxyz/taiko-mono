## TaikoEvents

### BlockVerified

```solidity
event BlockVerified(uint256 id, bytes32 blockHash)
```

### BlockCommitted

```solidity
event BlockCommitted(uint64 commitSlot, bytes32 commitHash)
```

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct TaikoData.BlockMetadata meta)
```

### BlockProven

```solidity
event BlockProven(uint256 id, bytes32 parentHash, bytes32 blockHash, address prover, uint64 provenAt)
```
