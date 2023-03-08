---
title: TaikoL1
---

## TaikoL1

### state

```solidity
struct TaikoData.State state
```

### onlyFromEOA

```solidity
modifier onlyFromEOA()
```

### init

```solidity
function init(address _addressManager, bytes32 _genesisBlockHash, uint64 _feeBaseSzabo) external
```

### proposeBlock

```solidity
function proposeBlock(struct TaikoData.BlockMetadataInput input, bytes txList) external returns (struct TaikoData.BlockMetadata meta)
```

Propose a Taiko L2 block.

#### Parameters

| Name   | Type                                | Description                                                                                                                                                                                                                                                                 |
| ------ | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| input  | struct TaikoData.BlockMetadataInput | An abi-encoded BlockMetadataInput that the actual L2 block header must satisfy.                                                                                                                                                                                             |
| txList | bytes                               | A list of transactions in this block, encoded with RLP. Note, in the corresponding L2 block an _anchor transaction_ will be the first transaction in the block -- if there are `n` transactions in `txList`, then there will be up to `n + 1` transactions in the L2 block. |

#### Return Values

| Name | Type                           | Description                 |
| ---- | ------------------------------ | --------------------------- |
| meta | struct TaikoData.BlockMetadata | The updated block metadata. |

### proveBlock

```solidity
function proveBlock(uint256 blockId, struct TaikoData.ValidBlockEvidence evidence) external
```

Prove a block is valid with a zero-knowledge proof, a transaction
merkel proof, and a receipt merkel proof.

#### Parameters

| Name     | Type                                | Description                                                                                    |
| -------- | ----------------------------------- | ---------------------------------------------------------------------------------------------- |
| blockId  | uint256                             | The index of the block to prove. This is also used to select the right implementation version. |
| evidence | struct TaikoData.ValidBlockEvidence | An abi-encoded TaikoData.ValidBlockEvidence object.                                            |

### proveBlockInvalid

```solidity
function proveBlockInvalid(uint256 blockId, struct TaikoData.InvalidBlockEvidence evidence) external
```

Prove a block is invalid with a zero-knowledge proof and a receipt
merkel proof.

#### Parameters

| Name     | Type                                  | Description                                                                                    |
| -------- | ------------------------------------- | ---------------------------------------------------------------------------------------------- |
| blockId  | uint256                               | The index of the block to prove. This is also used to select the right implementation version. |
| evidence | struct TaikoData.InvalidBlockEvidence | An abi-encoded TaikoData.InvalidBlockEvidence object.                                          |

### verifyBlocks

```solidity
function verifyBlocks(uint256 maxBlocks) external
```

Verify up to N blocks.

#### Parameters

| Name      | Type    | Description                     |
| --------- | ------- | ------------------------------- |
| maxBlocks | uint256 | Max number of blocks to verify. |

### deposit

```solidity
function deposit(uint256 amount) external
```

### withdraw

```solidity
function withdraw() external
```

### getBalance

```solidity
function getBalance(address addr) public view returns (uint256)
```

### getBlockFee

```solidity
function getBlockFee() public view returns (uint256)
```

### getProofReward

```solidity
function getProofReward(uint64 provenAt, uint64 proposedAt) public view returns (uint256 reward)
```

### getProposedBlock

```solidity
function getProposedBlock(uint256 id) public view returns (struct TaikoData.ProposedBlock)
```

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

### getStateVariables

```solidity
function getStateVariables() public view returns (struct LibUtils.StateVariables)
```

### getForkChoice

```solidity
function getForkChoice(uint256 id, bytes32 parentHash) public view returns (struct TaikoData.ForkChoice)
```

### getConfig

```solidity
function getConfig() public pure virtual returns (struct TaikoData.Config)
```
