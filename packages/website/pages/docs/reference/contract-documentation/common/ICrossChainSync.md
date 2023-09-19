---
title: ICrossChainSync
---

## ICrossChainSync

_This interface is implemented by both the TaikoL1 and TaikoL2
contracts.
It outlines the essential methods required for synchronizing and accessing
block hashes across chains. The core idea is to ensure that data between
both chains remain consistent and can be cross-referenced with integrity._

### CrossChainSynced

```solidity
event CrossChainSynced(uint64 srcHeight, bytes32 blockHash, bytes32 signalRoot)
```

_Emitted when a block has been synced across chains._

#### Parameters

| Name       | Type    | Description                                     |
| ---------- | ------- | ----------------------------------------------- |
| srcHeight  | uint64  | The height (block id\_ that was synced.         |
| blockHash  | bytes32 | The hash of the synced block.                   |
| signalRoot | bytes32 | The root hash representing cross-chain signals. |

### getCrossChainBlockHash

```solidity
function getCrossChainBlockHash(uint64 blockId) external view returns (bytes32)
```

Fetches the hash of a block from the opposite chain.

#### Parameters

| Name    | Type   | Description                                                               |
| ------- | ------ | ------------------------------------------------------------------------- |
| blockId | uint64 | The target block id. Specifying 0 retrieves the hash of the latest block. |

#### Return Values

| Name | Type    | Description                                         |
| ---- | ------- | --------------------------------------------------- |
| [0]  | bytes32 | The hash of the desired block from the other chain. |

### getCrossChainSignalRoot

```solidity
function getCrossChainSignalRoot(uint64 blockId) external view returns (bytes32)
```

Retrieves the root hash of the signal service storage for a
given block from the opposite chain.

#### Parameters

| Name    | Type   | Description                                                               |
| ------- | ------ | ------------------------------------------------------------------------- |
| blockId | uint64 | The target block id. Specifying 0 retrieves the root of the latest block. |

#### Return Values

| Name | Type    | Description                                             |
| ---- | ------- | ------------------------------------------------------- |
| [0]  | bytes32 | The root hash for the specified block's signal service. |
