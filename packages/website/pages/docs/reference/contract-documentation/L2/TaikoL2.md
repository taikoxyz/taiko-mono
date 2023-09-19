---
title: TaikoL2
---

## TaikoL2

Taiko L2 is a smart contract that handles cross-layer message
verification and manages EIP-1559 gas pricing for Layer 2 (L2) operations.
It is used to anchor the latest L1 block details to L2 for cross-layer
communication, manage EIP-1559 parameters for gas pricing, and store
verified L1 block information.

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
  uint32 gasIssuedPerSecond;
  uint64 gasExcessMax;
  uint64 gasTarget;
  uint64 ratio2x1x;
}
```

### EIP1559Config

```solidity
struct EIP1559Config {
  uint128 yscale;
  uint64 xscale;
  uint32 gasIssuedPerSecond;
}
```

### publicInputHash

```solidity
bytes32 publicInputHash
```

### eip1559Config

```solidity
struct TaikoL2.EIP1559Config eip1559Config
```

### parentTimestamp

```solidity
uint64 parentTimestamp
```

### latestSyncedL1Height

```solidity
uint64 latestSyncedL1Height
```

### gasExcess

```solidity
uint64 gasExcess
```

### Anchored

```solidity
event Anchored(uint64 number, uint64 basefee, uint32 gaslimit, uint64 timestamp, bytes32 parentHash, uint256 prevrandao, address coinbase, uint64 chainid)
```

### EIP1559ConfigUpdated

```solidity
event EIP1559ConfigUpdated(struct TaikoL2.EIP1559Config config, uint64 gasExcess)
```

### L2_BASEFEE_MISMATCH

```solidity
error L2_BASEFEE_MISMATCH()
```

### L2_INVALID_1559_PARAMS

```solidity
error L2_INVALID_1559_PARAMS()
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

### init

```solidity
function init(address _addressManager, struct TaikoL2.EIP1559Params _param1559) external
```

Initializes the TaikoL2 contract.

#### Parameters

| Name             | Type                         | Description                                          |
| ---------------- | ---------------------------- | ---------------------------------------------------- |
| \_addressManager | address                      | Address of the {AddressManager} contract.            |
| \_param1559      | struct TaikoL2.EIP1559Params | EIP-1559 parameters to set up the gas pricing model. |

### anchor

```solidity
function anchor(bytes32 l1Hash, bytes32 l1SignalRoot, uint64 l1Height, uint32 parentGasUsed) external
```

Anchors the latest L1 block details to L2 for cross-layer
message verification.

#### Parameters

| Name          | Type    | Description                                              |
| ------------- | ------- | -------------------------------------------------------- |
| l1Hash        | bytes32 | The latest L1 block hash when this block was proposed.   |
| l1SignalRoot  | bytes32 | The latest value of the L1 signal service storage root.  |
| l1Height      | uint64  | The latest L1 block height when this block was proposed. |
| parentGasUsed | uint32  | The gas used in the parent block.                        |

### updateEIP1559Config

```solidity
function updateEIP1559Config(struct TaikoL2.EIP1559Params _param1559) public
```

Updates EIP-1559 configurations.

#### Parameters

| Name        | Type                         | Description                                          |
| ----------- | ---------------------------- | ---------------------------------------------------- |
| \_param1559 | struct TaikoL2.EIP1559Params | EIP-1559 parameters to set up the gas pricing model. |

### getBasefee

```solidity
function getBasefee(uint64 timeSinceParent, uint32 parentGasUsed) public view returns (uint256 _basefee)
```

Gets the basefee and gas excess using EIP-1559 configuration for
the given parameters.

#### Parameters

| Name            | Type   | Description                                      |
| --------------- | ------ | ------------------------------------------------ |
| timeSinceParent | uint64 | Time elapsed since the parent block's timestamp. |
| parentGasUsed   | uint32 | Gas used in the parent block.                    |

#### Return Values

| Name      | Type    | Description                      |
| --------- | ------- | -------------------------------- |
| \_basefee | uint256 | The calculated EIP-1559 basefee. |

### getCrossChainBlockHash

```solidity
function getCrossChainBlockHash(uint64 blockId) public view returns (bytes32)
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
function getCrossChainSignalRoot(uint64 blockId) public view returns (bytes32)
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

### getEIP1559Config

```solidity
function getEIP1559Config() public view virtual returns (struct TaikoL2.EIP1559Config)
```

Retrieves the current EIP-1559 configuration details.

#### Return Values

| Name | Type                         | Description                                                                                                  |
| ---- | ---------------------------- | ------------------------------------------------------------------------------------------------------------ |
| [0]  | struct TaikoL2.EIP1559Config | The current EIP-1559 configuration details, including the yscale, xscale, and gasIssuedPerSecond parameters. |

---

## title: ProxiedTaikoL2

## ProxiedTaikoL2

Proxied version of the TaikoL2 contract.
