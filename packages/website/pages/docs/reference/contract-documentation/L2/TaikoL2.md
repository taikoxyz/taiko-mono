---
title: TaikoL2
---

## TaikoL2

### publicInputHash

```solidity
bytes32 publicInputHash
```

### latestSyncedL1Height

```solidity
uint256 latestSyncedL1Height
```

### BlockInvalidated

```solidity
event BlockInvalidated(bytes32 txListHash)
```

### constructor

```solidity
constructor(address _addressManager) public
```

### anchor

```solidity
function anchor(uint256 l1Height, bytes32 l1Hash) external
```

Persist the latest L1 block height and hash to L2 for cross-layer
message verification (eg. bridging). This function will also check
certain block-level global variables because they are not part of the
Trie structure.

Note: This transaction shall be the first transaction in every L2 block.

#### Parameters

| Name     | Type    | Description                                              |
| -------- | ------- | -------------------------------------------------------- |
| l1Height | uint256 | The latest L1 block height when this block was proposed. |
| l1Hash   | bytes32 | The latest L1 block hash when this block was proposed.   |

### invalidateBlock

```solidity
function invalidateBlock(bytes txList, enum LibInvalidTxList.Hint hint, uint256 txIdx) external
```

Invalidate a L2 block by verifying its txList is not intrinsically valid.

#### Parameters

| Name   | Type                       | Description                                                                                      |
| ------ | -------------------------- | ------------------------------------------------------------------------------------------------ |
| txList | bytes                      | The L2 block's txlist.                                                                           |
| hint   | enum LibInvalidTxList.Hint | A hint for this method to invalidate the txList.                                                 |
| txIdx  | uint256                    | If the hint is for a specific transaction in txList, txIdx specifies which transaction to check. |

### getConfig

```solidity
function getConfig() public view virtual returns (struct TaikoData.Config config)
```

### getSyncedHeader

```solidity
function getSyncedHeader(uint256 number) public view returns (bytes32)
```

### getLatestSyncedHeader

```solidity
function getLatestSyncedHeader() public view returns (bytes32)
```

### getBlockHash

```solidity
function getBlockHash(uint256 number) public view returns (bytes32)
```
