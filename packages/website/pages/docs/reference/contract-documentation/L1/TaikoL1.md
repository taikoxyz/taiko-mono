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
function init(address _addressManager, uint64 _feeBase, bytes32 _genesisBlockHash) external
```

Initialize the rollup.

#### Parameters

| Name               | Type    | Description                                                  |
| ------------------ | ------- | ------------------------------------------------------------ |
| \_addressManager   | address | The AddressManager address.                                  |
| \_feeBase          | uint64  | The initial value of the proposer-fee/prover-reward feeBase. |
| \_genesisBlockHash | bytes32 | The block hash of the genesis block.                         |

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

### oracleProveBlocks

```solidity
function oracleProveBlocks(uint256 blockId, bytes input) external
```

Oracle prove mutliple blocks in a row.

#### Parameters

| Name    | Type    | Description                                                                                          |
| ------- | ------- | ---------------------------------------------------------------------------------------------------- |
| blockId | uint256 | The index of the first block to prove. This is also used to select the right implementation version. |
| input   | bytes   | An abi-encoded TaikoData.BlockOracle[] object.                                                       |

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
function getBlock(uint256 blockId) public view returns (bytes32 _metaHash, uint256 _deposit, address _proposer, uint64 _proposedAt)
```

### getForkChoice

```solidity
function getForkChoice(uint256 blockId, bytes32 parentHash, uint32 parentGasUsed) public view returns (struct TaikoData.ForkChoice)
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
