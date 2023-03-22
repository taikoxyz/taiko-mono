---
title: TaikoL1
---

## TaikoL1

### state

```solidity
struct TaikoData.State state
```

### init

```solidity
function init(address _addressManager, bytes32 _genesisBlockHash, uint64 _feeBaseTwei) external
```

### proposeBlock

```solidity
function proposeBlock(bytes input, bytes txList) external
```

Propose a Taiko L2 block.

#### Parameters

| Name   | Type  | Description                                                                                                                                                                                                                                                                 |
| ------ | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| input  | bytes | An abi-encoded BlockMetadataInput that the actual L2 block header must satisfy.                                                                                                                                                                                             |
| txList | bytes | A list of transactions in this block, encoded with RLP. Note, in the corresponding L2 block an _anchor transaction_ will be the first transaction in the block -- if there are `n` transactions in `txList`, then there will be up to `n + 1` transactions in the L2 block. |

### proveBlock

```solidity
function proveBlock(uint256 blockId, bytes input) external
```

Prove a block is valid with a zero-knowledge proof, a transaction
merkel proof, and a receipt merkel proof.

#### Parameters

| Name    | Type    | Description                                                                                    |
| ------- | ------- | ---------------------------------------------------------------------------------------------- |
| blockId | uint256 | The index of the block to prove. This is also used to select the right implementation version. |
| input   | bytes   | An abi-encoded TaikoData.ValidBlockEvidence object.                                            |

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
function withdraw(uint256 amount) external
```

### getBalance

```solidity
function getBalance(address addr) public view returns (uint256)
```

### getBlockFee

```solidity
function getBlockFee() public view returns (uint256 feeAmount, uint256 depositAmount)
```

### getProofReward

```solidity
function getProofReward(uint64 provenAt, uint64 proposedAt) public view returns (uint256 reward)
```

### getBlock

```solidity
function getBlock(uint256 id) public view returns (bytes32 _metaHash, uint256 _deposit, address _proposer, uint64 _proposedAt)
```

### getForkChoice

```solidity
function getForkChoice(uint256 id, bytes32 parentHash) public view returns (struct TaikoData.ForkChoice)
```

### getXchainBlockHash

```solidity
function getXchainBlockHash(uint256 blockId) public view returns (bytes32)
```

### getXchainSignalRoot

```solidity
function getXchainSignalRoot(uint256 blockId) public view returns (bytes32)
```

### getStateVariables

```solidity
function getStateVariables() public view returns (struct TaikoData.StateVariables)
```

### getConfig

```solidity
function getConfig() public pure virtual returns (struct TaikoData.Config)
```
