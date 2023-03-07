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
function init(address _addressManager, bytes32 _genesisBlockHash, uint256 _feeBase) external
```

### proposeBlock

```solidity
function proposeBlock(bytes[] inputs) external
```

Propose a Taiko L2 block.

#### Parameters

| Name   | Type    | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| inputs | bytes[] | A list of data input: - inputs[0] is abi-encoded BlockMetadata that the actual L2 block header must satisfy. Note the following fields in the provided meta object must be zeros -- their actual values will be provisioned by Ethereum. - id - l1Height - l1Hash - mixHash - timestamp - inputs[1] is called the `txList` which is list of transactions in this block, encoded with RLP. Note, in the corresponding L2 block an _anchor transaction_ will be the first transaction in the block -- if there are n transactions in `txList`, then there will be up to n+1 transactions in the L2 block. - inputs[2] is the `txListProof` which is the ZK-proof to verify that the txList is correctly encoded and satisify a few other requirements as detailed in the whitepaper. There are a couple of things that are very important: 1) txListProof does not cover the transaction signature validation. Transactions with invalid signatures will be filtered. 2) `txListProof` will not be verified with a ZK-verifier as the main ZK-proof covers `txListProof` already. |

### proveBlock

```solidity
function proveBlock(uint256 blockId, bytes evidenceBytes) external
```

Prove a block is valid with a zero-knowledge proof, a transaction
merkel proof, and a receipt merkel proof.

#### Parameters

| Name          | Type    | Description                                                                                    |
| ------------- | ------- | ---------------------------------------------------------------------------------------------- |
| blockId       | uint256 | The index of the block to prove. This is also used to select the right implementation version. |
| evidenceBytes | bytes   | An abi-encoded TaikoData.ValidBlockEvidence object.                                            |

### proveBlockInvalid

```solidity
function proveBlockInvalid(uint256 blockId, bytes evidenceBytes) external
```

Prove a block is invalid with a zero-knowledge proof and a receipt
merkel proof.

#### Parameters

| Name          | Type    | Description                                                                                    |
| ------------- | ------- | ---------------------------------------------------------------------------------------------- |
| blockId       | uint256 | The index of the block to prove. This is also used to select the right implementation version. |
| evidenceBytes | bytes   | evidenceBytes An abi-encoded TaikoData.InvalidBlockEvidence object.                            |

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
