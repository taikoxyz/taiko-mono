---
title: TaikoL1
---

## TaikoL1

### state

```solidity
struct TaikoData.State state
```

### receive

```solidity
receive() external payable
```

### init

```solidity
function init(address _addressManager, bytes32 _genesisBlockHash, uint64 _initBlockFee, uint64 _initProofTimeTarget, uint64 _initProofTimeIssued) external
```

Initialize the rollup.

#### Parameters

| Name                  | Type    | Description                                                         |
| --------------------- | ------- | ------------------------------------------------------------------- |
| \_addressManager      | address | The AddressManager address.                                         |
| \_genesisBlockHash    | bytes32 | The block hash of the genesis block.                                |
| \_initBlockFee        | uint64  | Initial (reasonable) block fee value.                               |
| \_initProofTimeTarget | uint64  | Initial (reasonable) proof submission time target.                  |
| \_initProofTimeIssued | uint64  | Initial proof time issued corresponding with the initial block fee. |

### proposeBlock

```solidity
function proposeBlock(bytes input, bytes txList) external returns (struct TaikoData.BlockMetadata meta)
```

Propose a Taiko L2 block.

#### Parameters

| Name   | Type  | Description                                                                                                                                                                                                                                                                 |
| ------ | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| input  | bytes | An abi-encoded BlockMetadataInput that the actual L2 block header must satisfy.                                                                                                                                                                                             |
| txList | bytes | A list of transactions in this block, encoded with RLP. Note, in the corresponding L2 block an _anchor transaction_ will be the first transaction in the block -- if there are `n` transactions in `txList`, then there will be up to `n + 1` transactions in the L2 block. |

### proveBlock

```solidity
function proveBlock(uint256 blockId, bytes[] inputs) external
```

Prove a block with a zero-knowledge proof.

#### Parameters

| Name    | Type    | Description                                                                                    |
| ------- | ------- | ---------------------------------------------------------------------------------------------- |
| blockId | uint256 | The index of the block to prove. This is also used to select the right implementation version. |
| inputs  | bytes[] | Abi-encoded BlockEvidence and Proof.                                                           |

### verifyBlocks

```solidity
function verifyBlocks(uint256 maxBlocks) external
```

Verify up to N blocks.

#### Parameters

| Name      | Type    | Description                     |
| --------- | ------- | ------------------------------- |
| maxBlocks | uint256 | Max number of blocks to verify. |

### setProofParams

```solidity
function setProofParams(uint64 newProofTimeTarget, uint64 newProofTimeIssued) external
```

Change proof parameters (time target and time issued) - to avoid complex/risky
upgrades in case need to change relatively frequently.

#### Parameters

| Name               | Type   | Description                                                             |
| ------------------ | ------ | ----------------------------------------------------------------------- |
| newProofTimeTarget | uint64 | New proof time target.                                                  |
| newProofTimeIssued | uint64 | New proof time issued. If set to type(uint64).max, let it be unchanged. |

### depositTaikoToken

```solidity
function depositTaikoToken(uint256 amount) external
```

### withdrawTaikoToken

```solidity
function withdrawTaikoToken(uint256 amount) external
```

### depositEtherToL2

```solidity
function depositEtherToL2() public payable
```

### getTaikoTokenBalance

```solidity
function getTaikoTokenBalance(address addr) public view returns (uint256)
```

### getBlockFee

```solidity
function getBlockFee() public view returns (uint64)
```

### getProofReward

```solidity
function getProofReward(uint64 proofTime) public view returns (uint64)
```

### getBlock

```solidity
function getBlock(uint256 blockId) public view returns (bytes32 _metaHash, address _proposer, uint64 _proposedAt)
```

### getForkChoice

```solidity
function getForkChoice(uint256 blockId, bytes32 parentHash, uint32 parentGasUsed) public view returns (struct TaikoData.ForkChoice)
```

### getCrossChainBlockHash

```solidity
function getCrossChainBlockHash(uint256 blockId) public view returns (bytes32)
```

### getCrossChainSignalRoot

```solidity
function getCrossChainSignalRoot(uint256 blockId) public view returns (bytes32)
```

### getStateVariables

```solidity
function getStateVariables() public view returns (struct TaikoData.StateVariables)
```

### getConfig

```solidity
function getConfig() public pure virtual returns (struct TaikoData.Config)
```

### getVerifierName

```solidity
function getVerifierName(uint16 id) public pure returns (bytes32)
```

---

## title: ProxiedTaikoL1

## ProxiedTaikoL1
