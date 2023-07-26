---
title: LibUtils_A3
---

## LibUtils_A3

### L1_BLOCK_ID

```solidity
error L1_BLOCK_ID()
```

### getL2ChainData

```solidity
function getL2ChainData(struct TaikoData.State state, struct TaikoData.Config config, uint256 blockId) internal view returns (bool found, struct TaikoData.Block_A3 blk)
```

### getForkChoiceId

```solidity
function getForkChoiceId(struct TaikoData.State state, struct TaikoData.Block_A3 blk, bytes32 parentHash, uint32 parentGasUsed) internal view returns (uint256 fcId)
```

### getStateVariables

```solidity
function getStateVariables(struct TaikoData.State state) internal view returns (struct TaikoData.StateVariables_A3)
```

### movingAverage

```solidity
function movingAverage(uint256 maValue, uint256 newValue, uint256 maf) internal pure returns (uint256)
```

### hashMetadata

```solidity
function hashMetadata(struct TaikoData.BlockMetadata meta) internal pure returns (bytes32 hash)
```

### keyForForkChoice

```solidity
function keyForForkChoice(bytes32 parentHash, uint32 parentGasUsed) internal pure returns (bytes32 key)
```

### getVerifierName

```solidity
function getVerifierName(uint16 id) internal pure returns (bytes32)
```

