---
title: TaikoL2
---

## TaikoL2

### VerifiedBlock

```solidity
struct VerifiedBlock {
  bytes32 blockHash;
  bytes32 signalRoot;
}
```

### EIP1559Params

```solidity
struct EIP1559Params {
  uint64 basefee;
  uint64 gasIssuedPerSecond;
  uint64 gasExcessMax;
  uint64 gasTarget;
  uint64 ratio2x1x;
}
```

### publicInputHash

```solidity
bytes32 publicInputHash
```

### yscale

```solidity
uint128 yscale
```

### xscale

```solidity
uint64 xscale
```

### gasIssuedPerSecond

```solidity
uint64 gasIssuedPerSecond
```

### parentTimestamp

```solidity
uint64 parentTimestamp
```

### latestSyncedL1Height

```solidity
uint64 latestSyncedL1Height
```

### basefee

```solidity
uint64 basefee
```

### gasExcess

```solidity
uint64 gasExcess
```

### BlockVars

```solidity
event BlockVars(uint64 number, uint64 basefee, uint64 gaslimit, uint64 timestamp, bytes32 parentHash, uint256 prevrandao, address coinbase, uint32 chainid)
```

### L2_INVALID_1559_PARAMS

```solidity
error L2_INVALID_1559_PARAMS()
```

### L2_INVALID_BASEFEE

```solidity
error L2_INVALID_BASEFEE()
```

### L2_INVALID_CHAIN_ID

```solidity
error L2_INVALID_CHAIN_ID()
```

### L2_INVALID_SENDER

```solidity
error L2_INVALID_SENDER()
```

### L2_PUBLIC_INPUT_HASH_MISMATCH

```solidity
error L2_PUBLIC_INPUT_HASH_MISMATCH()
```

### L2_TOO_LATE

```solidity
error L2_TOO_LATE()
```

### M1559_UNEXPECTED_CHANGE

```solidity
error M1559_UNEXPECTED_CHANGE(uint64 expected, uint64 actual)
```

### M1559_OUT_OF_STOCK

```solidity
error M1559_OUT_OF_STOCK()
```

### init

```solidity
function init(address _addressManager, struct TaikoL2.EIP1559Params _param1559) external
```

### anchor

```solidity
function anchor(uint64 l1Height, bytes32 l1Hash, bytes32 l1SignalRoot) external
```

Persist the latest L1 block height and hash to L2 for cross-layer
message verification (eg. bridging). This function will also check
certain block-level global variables because they are not part of the
Trie structure.

A circuit will verify the integrity among:

- l1Hash, l1SignalRoot, and l1SignalServiceAddress
- (l1Hash and l1SignalServiceAddress) are both hashed into of the
  ZKP's instance.

This transaction shall be the first transaction in every L2 block.

#### Parameters

| Name         | Type    | Description                                               |
| ------------ | ------- | --------------------------------------------------------- |
| l1Height     | uint64  | The latest L1 block height when this block was proposed.  |
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
