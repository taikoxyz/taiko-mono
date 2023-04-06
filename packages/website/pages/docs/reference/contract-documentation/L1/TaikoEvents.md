## TaikoEvents

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct TaikoData.BlockMetadata meta, bool txListCached)
```

### BlockProven

```solidity
event BlockProven(uint256 id, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
```

### ConflictingProof

```solidity
event ConflictingProof(uint256 id, bytes32 parentHash, bytes32 conflictingBlockHash, bytes32 conflictingSignalRoot, bytes32 blockHash, bytes32 signalRoot)
```

### BlockVerified

```solidity
event BlockVerified(uint256 id, bytes32 blockHash)
```
