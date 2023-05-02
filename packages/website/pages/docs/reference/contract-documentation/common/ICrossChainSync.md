---
title: ICrossChainSync
---

## ICrossChainSync

Interface implemented by both the TaikoL1 and TaikoL2 contracts. It exposes
the methods needed to access the block hashes of the other chain.

### CrossChainSynced

```solidity
event CrossChainSynced(uint256 srcHeight, bytes32 blockHash, bytes32 signalRoot)
```

### getCrossChainBlockHash

```solidity
function getCrossChainBlockHash(uint256 number) external view returns (bytes32)
```

Returns the cross-chain block hash at the given block number.

#### Parameters

| Name   | Type    | Description                                   |
| ------ | ------- | --------------------------------------------- |
| number | uint256 | The block number. Use 0 for the latest block. |

#### Return Values

| Name | Type    | Description                 |
| ---- | ------- | --------------------------- |
| [0]  | bytes32 | The cross-chain block hash. |

### getCrossChainSignalRoot

```solidity
function getCrossChainSignalRoot(uint256 number) external view returns (bytes32)
```

Returns the cross-chain signal service storage root at the given
block number.

#### Parameters

| Name   | Type    | Description                                   |
| ------ | ------- | --------------------------------------------- |
| number | uint256 | The block number. Use 0 for the latest block. |

#### Return Values

| Name | Type    | Description                                  |
| ---- | ------- | -------------------------------------------- |
| [0]  | bytes32 | The cross-chain signal service storage root. |
