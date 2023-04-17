## TaikoEvents

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

### EthDepositRequested

```solidity
event EthDepositRequested(uint64 id, struct TaikoData.EthDeposit deposit)
```

### EthDepositCanceled

```solidity
event EthDepositCanceled(uint64 id, struct TaikoData.EthDeposit deposit)
```
