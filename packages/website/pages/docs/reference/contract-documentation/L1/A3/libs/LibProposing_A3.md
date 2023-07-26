---
title: LibProposing_A3
---

## LibProposing_A3

### BlockProposed

```solidity
event BlockProposed(uint256 id, struct TaikoData.BlockMetadata meta, uint64 blockFee)
```

### L1_BLOCK_ID

```solidity
error L1_BLOCK_ID()
```

### L1_INSUFFICIENT_TOKEN

```solidity
error L1_INSUFFICIENT_TOKEN()
```

### L1_INVALID_METADATA

```solidity
error L1_INVALID_METADATA()
```

### L1_TOO_MANY_BLOCKS

```solidity
error L1_TOO_MANY_BLOCKS()
```

### L1_TX_LIST_NOT_EXIST

```solidity
error L1_TX_LIST_NOT_EXIST()
```

### L1_TX_LIST_HASH

```solidity
error L1_TX_LIST_HASH()
```

### L1_TX_LIST_RANGE

```solidity
error L1_TX_LIST_RANGE()
```

### L1_TX_LIST

```solidity
error L1_TX_LIST()
```

### proposeBlock

```solidity
function proposeBlock(struct TaikoData.State state, struct TaikoData.Config config, contract AddressResolver resolver, struct TaikoData.BlockMetadataInput input, bytes txList) internal returns (struct TaikoData.BlockMetadata meta)
```

### getBlock

```solidity
function getBlock(struct TaikoData.State state, struct TaikoData.Config config, uint256 blockId) internal view returns (struct TaikoData.Block_A3 blk)
```

