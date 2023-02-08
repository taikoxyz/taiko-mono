---
title: IHeaderSync
---

## IHeaderSync

Interface implemented by both the TaikoL1 and TaikoL2 contracts. It exposes
the methods needed to access the block hashes of the other chain.

### HeaderSynced

```solidity
event HeaderSynced(uint256 height, uint256 srcHeight, bytes32 srcHash)
```

### getSyncedHeader

```solidity
function getSyncedHeader(uint256 number) external view returns (bytes32)
```

### getLatestSyncedHeader

```solidity
function getLatestSyncedHeader() external view returns (bytes32)
```
