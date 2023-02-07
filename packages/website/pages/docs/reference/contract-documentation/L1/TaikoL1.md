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
function init(address _addressManager, bytes32 _genesisBlockHash, uint256 _feeBase) external
```

### commitBlock

```solidity
function commitBlock(uint64 commitSlot, bytes32 commitHash) external
```

Write a _commit hash_ so a few blocks later a L2 block can be proposed
such that `calculateCommitHash(meta.beneficiary, meta.txListHash)` equals
to this commit hash.

#### Parameters

| Name       | Type    | Description                                                                 |
| ---------- | ------- | --------------------------------------------------------------------------- |
| commitSlot | uint64  | A slot to save this commit. Slot 0 will always be reset to zero for refund. |
| commitHash | bytes32 | Calculated with: `calculateCommitHash(beneficiary, txListHash)`.            |

### proposeBlock

```solidity
function proposeBlock(bytes[] inputs) external
```

Propose a Taiko L2 block.

#### Parameters

| Name   | Type    | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------ | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| inputs | bytes[] | A list of data input: - inputs[0] is abi-encoded BlockMetadata that the actual L2 block header must satisfy. Note the following fields in the provided meta object must be zeros -- their actual values will be provisioned by Ethereum. - id - l1Height - l1Hash - mixHash - timestamp - inputs[1] is a list of transactions in this block, encoded with RLP. Note, in the corresponding L2 block an _anchor transaction_ will be the first transaction in the block -- if there are n transactions in `txList`, then there will be up to n+1 transactions in the L2 block. |

### proveBlock

```solidity
function proveBlock(uint256 blockId, bytes[] inputs) external
```

Prove a block is valid with a zero-knowledge proof, a transaction
merkel proof, and a receipt merkel proof.

#### Parameters

| Name    | Type    | Description                                                                                                                                                                                                                                                                                                                                     |
| ------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| blockId | uint256 | The index of the block to prove. This is also used to select the right implementation version.                                                                                                                                                                                                                                                  |
| inputs  | bytes[] | A list of data input: - inputs[0] is an abi-encoded object with various information regarding the block to be proven and the actual proofs. - inputs[1] is the actual anchor transaction in this L2 block. Note that the anchor transaction is always the first transaction in the block. - inputs[2] is the receipt of the anchor transaction. |

### proveBlockInvalid

```solidity
function proveBlockInvalid(uint256 blockId, bytes[] inputs) external
```

Prove a block is invalid with a zero-knowledge proof and a receipt
merkel proof.

#### Parameters

| Name    | Type    | Description                                                                                                                                                                                                                                                                                                                                                 |
| ------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| blockId | uint256 | The index of the block to prove. This is also used to select the right implementation version.                                                                                                                                                                                                                                                              |
| inputs  | bytes[] | A list of data input: - inputs[0] An Evidence object with various information regarding the block to be proven and the actual proofs. - inputs[1] The target block to be proven invalid. - inputs[2] The receipt for the `invalidBlock` transaction on L2. Note that the `invalidBlock` transaction is supposed to be the only transaction in the L2 block. |

### verifyBlocks

```solidity
function verifyBlocks(uint256 maxBlocks) external
```

Verify up to N blocks.

#### Parameters

| Name      | Type    | Description                     |
| --------- | ------- | ------------------------------- |
| maxBlocks | uint256 | Max number of blocks to verify. |

### halt

```solidity
function halt(bool toHalt) public
```

Halt or resume the chain.

#### Parameters

| Name   | Type | Description                    |
| ------ | ---- | ------------------------------ |
| toHalt | bool | True to halt, false to resume. |

### getBlockFee

```solidity
function getBlockFee() public view returns (uint256)
```

### getProofReward

```solidity
function getProofReward(uint64 provenAt, uint64 proposedAt) public view returns (uint256 reward)
```

### isHalted

```solidity
function isHalted() public view returns (bool)
```

Check if the L1 is halted.

#### Return Values

| Name | Type | Description                      |
| ---- | ---- | -------------------------------- |
| [0]  | bool | True if halted, false otherwise. |

### isCommitValid

```solidity
function isCommitValid(uint256 commitSlot, uint256 commitHeight, bytes32 commitHash) public view returns (bool)
```

### getProposedBlock

```solidity
function getProposedBlock(uint256 id) public view returns (struct TaikoData.ProposedBlock)
```

### getSyncedHeader

```solidity
function getSyncedHeader(uint256 number) public view returns (bytes32)
```

### getLatestSyncedHeader

```solidity
function getLatestSyncedHeader() public view returns (bytes32)
```

### getStateVariables

```solidity
function getStateVariables() public view returns (uint64, uint64, uint64, uint256, uint64, uint64, uint64, uint64, uint64, uint64)
```

### signWithGoldenTouch

```solidity
function signWithGoldenTouch(bytes32 hash, uint8 k) public view returns (uint8 v, uint256 r, uint256 s)
```

### getForkChoice

```solidity
function getForkChoice(uint256 id, bytes32 parentHash) public view returns (struct TaikoData.ForkChoice)
```

### getUncleProofDelay

```solidity
function getUncleProofDelay(uint256 blockId) public view returns (uint64)
```

### getConfig

```solidity
function getConfig() public pure virtual returns (struct TaikoData.Config)
```

### isBlockVerifiable

```solidity
function isBlockVerifiable(uint256 blockId, bytes32 parentHash) public view returns (bool)
```
