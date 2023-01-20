---
title: IHeaderSync
---

## IHeaderSync

Interface to set and get an address for a name.

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
