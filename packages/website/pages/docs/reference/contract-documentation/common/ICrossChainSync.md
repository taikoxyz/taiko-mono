---
title: ICrossChainSync
---

## ICrossChainSync

_This interface is implemented by both the TaikoL1 and TaikoL2
contracts.
It outlines the essential methods required for synchronizing and accessing
block hashes across chains. The core idea is to ensure that data between
both chains remain consistent and can be cross-referenced with integrity._

### Snippet

```solidity
struct Snippet {
  uint64 remoteBlockId;
  uint64 syncedInBlock;
  bytes32 blockHash;
  bytes32 signalRoot;
}
```

### CrossChainSynced

```solidity
event CrossChainSynced(uint64 syncedInBlock, uint64 blockId, bytes32 blockHash, bytes32 signalRoot)
```

_Emitted when a block has been synced across chains._

#### Parameters

| Name          | Type    | Description                                                             |
| ------------- | ------- | ----------------------------------------------------------------------- |
| syncedInBlock | uint64  | The ID of this chain's block where the sync happened.                   |
| blockId       | uint64  | The ID of the remote block whose block hash and signal root are synced. |
| blockHash     | bytes32 | The hash of the synced block.                                           |
| signalRoot    | bytes32 | The root hash representing cross-chain signals.                         |

### getSyncedSnippet

```solidity
function getSyncedSnippet(uint64 blockId) external view returns (struct ICrossChainSync.Snippet snippet)
```

Fetches the hash of a block from the opposite chain.

#### Parameters

| Name    | Type   | Description                                                               |
| ------- | ------ | ------------------------------------------------------------------------- |
| blockId | uint64 | The target block id. Specifying 0 retrieves the hash of the latest block. |

#### Return Values

| Name    | Type                           | Description                            |
| ------- | ------------------------------ | -------------------------------------- |
| snippet | struct ICrossChainSync.Snippet | The block hash and signal root synced. |
