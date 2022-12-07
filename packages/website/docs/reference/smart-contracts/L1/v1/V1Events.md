## V1Events

### BlockVerified

```solidity
event BlockVerified(uint256 id, bytes32 blockHash)
```

### BlockCommitted

```solidity
event BlockCommitted(uint64 commitSlot, uint64 commitHeight, bytes32 commitHash)
```

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct LibData.BlockMetadata meta)
```

### BlockProven

```solidity
event BlockProven(uint256 id, bytes32 parentHash, bytes32 blockHash, uint64 timestamp, uint64 provenAt, address prover)
```

### WhitelistingEnabled

```solidity
event WhitelistingEnabled(bool whitelistProposers, bool whitelistProvers)
```

### ProposerWhitelisted

```solidity
event ProposerWhitelisted(address prover, bool whitelisted)
```

### ProverWhitelisted

```solidity
event ProverWhitelisted(address prover, bool whitelisted)
```

### Halted

```solidity
event Halted(bool halted)
```

