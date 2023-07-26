---
title: LibVerifying_A3
---

## LibVerifying_A3

### BlockVerified

```solidity
event BlockVerified(uint256 id, bytes32 blockHash, uint64 reward)
```

### CrossChainSynced

```solidity
event CrossChainSynced(uint256 srcHeight, bytes32 blockHash, bytes32 signalRoot)
```

### L1_INVALID_CONFIG

```solidity
error L1_INVALID_CONFIG()
```

### init

```solidity
function init(struct TaikoData.State state, struct TaikoData.Config config, bytes32 genesisBlockHash, uint64 initBlockFee, uint64 initProofTimeTarget, uint64 initProofTimeIssued, uint16 adjustmentQuotient) internal
```

### verifyBlocks

```solidity
function verifyBlocks(struct TaikoData.State state, struct TaikoData.Config config, contract AddressResolver resolver, uint256 maxBlocks) internal
```

