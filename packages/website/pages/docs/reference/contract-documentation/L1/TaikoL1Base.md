---
title: TaikoL1Base
---

## TaikoL1Base

This contract serves as the "base layer contract" of the Taiko
protocol, providing functionalities for proposing, proving, and verifying
blocks. The term "base layer contract" means that although this is usually
deployed on L1, it can also be deployed on L2s to create L3s ("inception
layers"). The contract also handles the deposit and withdrawal of Taiko
tokens and Ether.

### state

```solidity
struct TaikoData.State state
```

### receive

```solidity
receive() external payable
```

_Fallback function to receive Ether and deposit to to Layer 2._

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
function proposeBlock(bytes input, bytes assignment, bytes txList) external payable returns (struct TaikoData.BlockMetadata meta)
```

Proposes a Taiko L2 block.

#### Parameters

| Name       | Type  | Description                                                                                                                                                                                                                                                                   |
| ---------- | ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| input      | bytes | An abi-encoded BlockMetadataInput that the actual L2 block header must satisfy.                                                                                                                                                                                               |
| assignment | bytes | Data to assign a prover.                                                                                                                                                                                                                                                      |
| txList     | bytes | A list of transactions in this block, encoded with RLP. Note, in the corresponding L2 block an "anchor transaction" will be the first transaction in the block. If there are `n` transactions in the `txList`, then there will be up to `n + 1` transactions in the L2 block. |

#### Return Values

| Name | Type                           | Description                            |
| ---- | ------------------------------ | -------------------------------------- |
| meta | struct TaikoData.BlockMetadata | The metadata of the proposed L2 block. |

### proveBlock

```solidity
function proveBlock(uint64 blockId, bytes input) external
```

Proves a block with a zero-knowledge proof.

#### Parameters

| Name    | Type   | Description                                                                                    |
| ------- | ------ | ---------------------------------------------------------------------------------------------- |
| blockId | uint64 | The index of the block to prove. This is also used to select the right implementation version. |
| input   | bytes  | An abi-encoded {TaikoData.BlockEvidence} object.                                               |

### verifyBlocks

```solidity
function verifyBlocks(uint64 maxBlocks) external
```

Verifies up to N blocks.

#### Parameters

| Name      | Type   | Description                     |
| --------- | ------ | ------------------------------- |
| maxBlocks | uint64 | Max number of blocks to verify. |

### depositTaikoToken

```solidity
function depositTaikoToken(uint256 amount) external
```

Deposits Taiko tokens to the contract.

#### Parameters

| Name   | Type    | Description                        |
| ------ | ------- | ---------------------------------- |
| amount | uint256 | Amount of Taiko tokens to deposit. |

### withdrawTaikoToken

```solidity
function withdrawTaikoToken(uint256 amount) external
```

Withdraws Taiko tokens from the contract.

#### Parameters

| Name   | Type    | Description                         |
| ------ | ------- | ----------------------------------- |
| amount | uint256 | Amount of Taiko tokens to withdraw. |

### depositEtherToL2

```solidity
function depositEtherToL2(address recipient) public payable
```

Deposits Ether to Layer 2.

#### Parameters

| Name      | Type    | Description                                                  |
| --------- | ------- | ------------------------------------------------------------ |
| recipient | address | Address of the recipient for the deposited Ether on Layer 2. |

### getTaikoTokenBalance

```solidity
function getTaikoTokenBalance(address addr) public view returns (uint256)
```

Gets the Taiko token balance for a specific address.

#### Parameters

| Name | Type    | Description                               |
| ---- | ------- | ----------------------------------------- |
| addr | address | Address to check the Taiko token balance. |

#### Return Values

| Name | Type    | Description                             |
| ---- | ------- | --------------------------------------- |
| [0]  | uint256 | The Taiko token balance of the address. |

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
function getTransition(uint64 blockId, bytes32 parentHash) public view returns (struct TaikoData.Transition)
```

Gets the state transition for a specific block.

#### Parameters

| Name       | Type    | Description               |
| ---------- | ------- | ------------------------- |
| blockId    | uint64  | Index of the block.       |
| parentHash | bytes32 | Parent hash of the block. |

#### Return Values

| Name | Type                        | Description                             |
| ---- | --------------------------- | --------------------------------------- |
| [0]  | struct TaikoData.Transition | The state transition data of the block. |

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

### getStateVariables

```solidity
function getStateVariables() public view returns (struct TaikoData.StateVariables)
```

Gets the state variables of the TaikoL1 contract.

#### Return Values

| Name | Type                            | Description                                       |
| ---- | ------------------------------- | ------------------------------------------------- |
| [0]  | struct TaikoData.StateVariables | StateVariables struct containing state variables. |

### getVerifierName

```solidity
function getVerifierName(uint16 id) public pure returns (bytes32)
```

Gets the name of the proof verifier by ID.

#### Parameters

| Name | Type   | Description         |
| ---- | ------ | ------------------- |
| id   | uint16 | ID of the verifier. |

#### Return Values

| Name | Type    | Description    |
| ---- | ------- | -------------- |
| [0]  | bytes32 | Verifier name. |

### getConfig

```solidity
function getConfig() public pure virtual returns (struct TaikoData.Config)
```

Gets the configuration of the TaikoL1 contract.

#### Return Values

| Name | Type                    | Description                                        |
| ---- | ----------------------- | -------------------------------------------------- |
| [0]  | struct TaikoData.Config | Config struct containing configuration parameters. |
