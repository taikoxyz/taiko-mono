## V1Events

### BlockFinalized

```solidity
event BlockFinalized(uint256 id, bytes32 blockHash)
```

### BlockCommitted

```solidity
event BlockCommitted(bytes32 hash, uint256 validSince)
```

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct LibData.BlockMetadata meta)
```

### BlockProven

```solidity
event BlockProven(uint256 id, bytes32 parentHash, bytes32 blockHash, uint64 timestamp, uint64 provenAt, address prover)
```
