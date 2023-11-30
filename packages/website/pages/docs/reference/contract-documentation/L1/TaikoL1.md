---
title: TaikoL1
---

## TaikoL1

This contract serves as the "base layer contract" of the Taiko
protocol, providing functionalities for proposing, proving, and verifying
blocks. The term "base layer contract" means that although this is usually
deployed on L1, it can also be deployed on L2s to create L3s ("inception
layers"). The contract also handles the deposit and withdrawal of Taiko
tokens and Ether.
This contract doesn't hold any Ether. Ether deposited to L2 are held by the Bridge contract.

_Labeled in AddressResolver as "taiko"_

### state

```solidity
struct TaikoData.State state
```

### receive

```solidity
receive() external payable
```

_Fallback function to receive Ether from Hooks_

### init

```solidity
function init(address _addressManager, bytes32 _genesisBlockHash) external
```

Initializes the rollup.

#### Parameters

| Name               | Type    | Description                          |
| ------------------ | ------- | ------------------------------------ |
| \_addressManager   | address | The {AddressManager} address.        |
| \_genesisBlockHash | bytes32 | The block hash of the genesis block. |

### proposeBlock

```solidity
function proposeBlock(bytes params, bytes txList) external payable returns (struct TaikoData.BlockMetadata meta, struct TaikoData.EthDeposit[] depositsProcessed)
```

Proposes a Taiko L2 block.

#### Parameters

| Name   | Type  | Description                                                |
| ------ | ----- | ---------------------------------------------------------- |
| params | bytes | Block parameters, currently an encoded BlockParams object. |
| txList | bytes | txList data if calldata is used for DA.                    |

#### Return Values

| Name              | Type                           | Description                            |
| ----------------- | ------------------------------ | -------------------------------------- |
| meta              | struct TaikoData.BlockMetadata | The metadata of the proposed L2 block. |
| depositsProcessed | struct TaikoData.EthDeposit[]  | The Ether deposits processed.          |

### proveBlock

```solidity
function proveBlock(uint64 blockId, bytes input) external
```

Proves or contests a block transition.

#### Parameters

| Name    | Type   | Description                                                                                    |
| ------- | ------ | ---------------------------------------------------------------------------------------------- |
| blockId | uint64 | The index of the block to prove. This is also used to select the right implementation version. |
| input   | bytes  | An abi-encoded (BlockMetadata, Transition, TierProof) tuple.                                   |

### verifyBlocks

```solidity
function verifyBlocks(uint64 maxBlocksToVerify) external
```

Verifies up to N blocks.

#### Parameters

| Name              | Type   | Description                     |
| ----------------- | ------ | ------------------------------- |
| maxBlocksToVerify | uint64 | Max number of blocks to verify. |

### pauseProving

```solidity
function pauseProving(bool pause) external
```

Pause block proving.

#### Parameters

| Name  | Type | Description     |
| ----- | ---- | --------------- |
| pause | bool | True if paused. |

### depositEtherToL2

```solidity
function depositEtherToL2(address recipient) external payable
```

Deposits Ether to Layer 2.

#### Parameters

| Name      | Type    | Description                                                  |
| --------- | ------- | ------------------------------------------------------------ |
| recipient | address | Address of the recipient for the deposited Ether on Layer 2. |

### canDepositEthToL2

```solidity
function canDepositEthToL2(uint256 amount) public view returns (bool)
```

Checks if Ether deposit is allowed for Layer 2.

#### Parameters

| Name   | Type    | Description                      |
| ------ | ------- | -------------------------------- |
| amount | uint256 | Amount of Ether to be deposited. |

#### Return Values

| Name | Type | Description                                        |
| ---- | ---- | -------------------------------------------------- |
| [0]  | bool | true if Ether deposit is allowed, false otherwise. |

### isBlobReusable

```solidity
function isBlobReusable(bytes32 blobHash) public view returns (bool)
```

### getBlock

```solidity
function getBlock(uint64 blockId) public view returns (struct TaikoData.Block blk)
```

Gets the details of a block.

#### Parameters

| Name    | Type   | Description         |
| ------- | ------ | ------------------- |
| blockId | uint64 | Index of the block. |

#### Return Values

| Name | Type                   | Description |
| ---- | ---------------------- | ----------- |
| blk  | struct TaikoData.Block | The block.  |

### getTransition

```solidity
function getTransition(uint64 blockId, bytes32 parentHash) public view returns (struct TaikoData.TransitionState)
```

Gets the state transition for a specific block.

#### Parameters

| Name       | Type    | Description               |
| ---------- | ------- | ------------------------- |
| blockId    | uint64  | Index of the block.       |
| parentHash | bytes32 | Parent hash of the block. |

#### Return Values

| Name | Type                             | Description                             |
| ---- | -------------------------------- | --------------------------------------- |
| [0]  | struct TaikoData.TransitionState | The state transition data of the block. |

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

### getStateVariables

```solidity
function getStateVariables() public view returns (struct TaikoData.SlotA a, struct TaikoData.SlotB b)
```

Gets the state variables of the TaikoL1 contract.

### getTaikoTokenBalance

```solidity
function getTaikoTokenBalance(address user) public view returns (uint256)
```

Gets the in-protocol Taiko token balance for a user

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| user | address | The user.   |

#### Return Values

| Name | Type    | Description                     |
| ---- | ------- | ------------------------------- |
| [0]  | uint256 | The user's Taiko token balance. |

### getTier

```solidity
function getTier(uint16 tierId) public view virtual returns (struct ITierProvider.Tier)
```

Retrieves the configuration for a specified tier.

#### Parameters

| Name   | Type   | Description     |
| ------ | ------ | --------------- |
| tierId | uint16 | ID of the tier. |

#### Return Values

| Name | Type                      | Description                                                                                           |
| ---- | ------------------------- | ----------------------------------------------------------------------------------------------------- |
| [0]  | struct ITierProvider.Tier | Tier struct containing the tier's parameters. This function will revert if the tier is not supported. |

### getTierIds

```solidity
function getTierIds() public view virtual returns (uint16[] ids)
```

Retrieves the IDs of all supported tiers.

### getMinTier

```solidity
function getMinTier(uint256 rand) public view virtual returns (uint16)
```

Determines the minimal tier for a block based on a random input.

### getConfig

```solidity
function getConfig() public view virtual returns (struct TaikoData.Config)
```

Gets the configuration of the TaikoL1 contract.

#### Return Values

| Name | Type                    | Description                                        |
| ---- | ----------------------- | -------------------------------------------------- |
| [0]  | struct TaikoData.Config | Config struct containing configuration parameters. |

### isConfigValid

```solidity
function isConfigValid() public view returns (bool)
```

---

## title: ProxiedTaikoL1

## ProxiedTaikoL1

Proxied version of the parent contract.
