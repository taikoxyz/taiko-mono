---
title: TaikoL2
---

## TaikoL2

Taiko L2 is a smart contract that handles cross-layer message
verification and manages EIP-1559 gas pricing for Layer 2 (L2) operations.
It is used to anchor the latest L1 block details to L2 for cross-layer
communication, manage EIP-1559 parameters for gas pricing, and store
verified L1 block information.

### Config

```solidity
struct Config {
  uint32 gasTargetPerL1Block;
  uint8 basefeeAdjustmentQuotient;
}
```

### l2Hashes

```solidity
mapping(uint256 => bytes32) l2Hashes
```

### snippets

```solidity
mapping(uint256 => struct ICrossChainSync.Snippet) snippets
```

### signalService

```solidity
address signalService
```

### publicInputHash

```solidity
bytes32 publicInputHash
```

### gasExcess

```solidity
uint64 gasExcess
```

### latestSyncedL1Height

```solidity
uint64 latestSyncedL1Height
```

### Anchored

```solidity
event Anchored(bytes32 parentHash, uint64 gasExcess)
```

### L2_BASEFEE_MISMATCH

```solidity
error L2_BASEFEE_MISMATCH()
```

### L2_INVALID_CHAIN_ID

```solidity
error L2_INVALID_CHAIN_ID()
```

### L2_INVALID_PARAM

```solidity
error L2_INVALID_PARAM()
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

### init

```solidity
function init(address _signalService, uint64 _gasExcess) external
```

Initializes the TaikoL2 contract.

#### Parameters

| Name            | Type    | Description                               |
| --------------- | ------- | ----------------------------------------- |
| \_signalService | address | Address of the {ISignalService} contract. |
| \_gasExcess     | uint64  | The initial gasExcess.                    |

### anchor

```solidity
function anchor(bytes32 l1BlockHash, bytes32 l1SignalRoot, uint64 l1Height, uint32 parentGasUsed) external
```

Anchors the latest L1 block details to L2 for cross-layer
message verification.

#### Parameters

| Name          | Type    | Description                                              |
| ------------- | ------- | -------------------------------------------------------- |
| l1BlockHash   | bytes32 | The latest L1 block hash when this block was proposed.   |
| l1SignalRoot  | bytes32 | The latest value of the L1 signal root.                  |
| l1Height      | uint64  | The latest L1 block height when this block was proposed. |
| parentGasUsed | uint32  | The gas used in the parent block.                        |

### getSyncedSnippet

```solidity
function getSyncedSnippet(uint64 blockId) public view returns (struct ICrossChainSync.Snippet)
```

Fetches the hash of a block from the opposite chain.

#### Parameters

| Name    | Type   | Description                                                               |
| ------- | ------ | ------------------------------------------------------------------------- |
| blockId | uint64 | The target block id. Specifying 0 retrieves the hash of the latest block. |

#### Return Values

| Name | Type                           | Description |
| ---- | ------------------------------ | ----------- |
| [0]  | struct ICrossChainSync.Snippet |             |

### getBasefee

```solidity
function getBasefee(uint64 l1Height, uint32 parentGasUsed) public view returns (uint256 basefee)
```

Gets the basefee and gas excess using EIP-1559 configuration for
the given parameters.

#### Parameters

| Name          | Type   | Description                                  |
| ------------- | ------ | -------------------------------------------- |
| l1Height      | uint64 | The synced L1 height in the next Taiko block |
| parentGasUsed | uint32 | Gas used in the parent block.                |

#### Return Values

| Name    | Type    | Description                               |
| ------- | ------- | ----------------------------------------- |
| basefee | uint256 | The calculated EIP-1559 base fee per gas. |

### getBlockHash

```solidity
function getBlockHash(uint64 blockId) public view returns (bytes32)
```

Retrieves the block hash for the given L2 block number.

#### Parameters

| Name    | Type   | Description                                         |
| ------- | ------ | --------------------------------------------------- |
| blockId | uint64 | The L2 block number to retrieve the block hash for. |

#### Return Values

| Name | Type    | Description                                                                                                                 |
| ---- | ------- | --------------------------------------------------------------------------------------------------------------------------- |
| [0]  | bytes32 | The block hash for the specified L2 block id, or zero if the block id is greater than or equal to the current block number. |

### getConfig

```solidity
function getConfig() public view virtual returns (struct TaikoL2.Config config)
```

Returns EIP1559 related configurations

### skipFeeCheck

```solidity
function skipFeeCheck() public pure virtual returns (bool)
```

Tells if we need to validate basefee (for simulation).

#### Return Values

| Name | Type | Description                                     |
| ---- | ---- | ----------------------------------------------- |
| [0]  | bool | Returns true to skip checking basefee mismatch. |

---

## title: ProxiedSingletonTaikoL2

## ProxiedSingletonTaikoL2

Proxied version of the TaikoL2 contract.

_Deploy this contract as a singleton per chain for use by multiple L2s
or L3s. No singleton check is performed within the code; it's the deployer's
responsibility to ensure this. Singleton deployment is essential for
enabling multi-hop bridging across all Taiko L2/L3s._
