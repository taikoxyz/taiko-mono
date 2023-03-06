---
title: TaikoL2
---

## TaikoL2

### l1ChainId

```solidity
uint256 l1ChainId
```

### latestSyncedL1Height

```solidity
uint256 latestSyncedL1Height
```

### BlockInvalidated

```solidity
event BlockInvalidated(bytes32 txListHash)
```

### L2_INVALID_CHAIN_ID

```solidity
error L2_INVALID_CHAIN_ID()
```

### L2_PUBLIC_INPUT_HASH_MISMATCH

```solidity
error L2_PUBLIC_INPUT_HASH_MISMATCH()
```

### init

```solidity
function init(address _addressManager, uint256 _l1ChainId) external
```

### anchor

```solidity
function anchor(uint256 l1Height, bytes32 l1Hash, bytes32 l1SignalRoot) external
```

Persist the latest L1 block height and hash to L2 for cross-layer
message verification (eg. bridging). This function will also check
certain block-level global variables because they are not part of the
Trie structure.

Note: This transaction shall be the first transaction in every L2 block.

#### Parameters

| Name         | Type    | Description                                               |
| ------------ | ------- | --------------------------------------------------------- |
| l1Height     | uint256 | The latest L1 block height when this block was proposed.  |
| l1Hash       | bytes32 | The latest L1 block hash when this block was proposed.    |
| l1SignalRoot | bytes32 | The latest value of the L1 "signal service storage root". |

### getXchainBlockHash

```solidity
function getXchainBlockHash(uint256 number) public view returns (bytes32)
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

### getXchainSignalRoot

```solidity
function getXchainSignalRoot(uint256 number) public view returns (bytes32)
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

### getBlockHash

```solidity
function getBlockHash(uint256 number) public view returns (bytes32)
```
