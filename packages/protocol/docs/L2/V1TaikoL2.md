## V1TaikoL2

### l2Hashes

```solidity
mapping(uint256 => bytes32) l2Hashes
```

### l1Hashes

```solidity
mapping(uint256 => bytes32) l1Hashes
```

### publicInputHash

```solidity
bytes32 publicInputHash
```

### __gap

```solidity
uint256[47] __gap
```

### BlockInvalidated

```solidity
event BlockInvalidated(bytes32 txListHash)
```

### constructor

```solidity
constructor(address _addressManager) public
```

### anchor

```solidity
function anchor(uint256 l1Height, bytes32 l1Hash) external
```

Persist the latest L1 block height and hash to L2 for cross-layer
bridging. This function will also check certain block-level global
variables because they are not part of the Trie structure.
Note: this transaction shall be the first transaction in everyL2 block.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| l1Height | uint256 | The latest L1 block height when this block was proposed. |
| l1Hash | bytes32 | The latest L1 block hash when this block was proposed. |

### invalidateBlock

```solidity
function invalidateBlock(bytes txList, enum LibInvalidTxList.Reason hint, uint256 txIdx) external
```

Invalidate a L2 block by verifying its txList is not intrinsically valid.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| txList | bytes | The L2 block's txlist. |
| hint | enum LibInvalidTxList.Reason | A hint for this method to invalidate the txList. |
| txIdx | uint256 | If the hint is for a specific transaction in txList,        txIdx specifies which transaction to check. |

### getSyncedHeader

```solidity
function getSyncedHeader(uint256 number) public view returns (bytes32)
```

### getBlockHash

```solidity
function getBlockHash(uint256 number) public view returns (bytes32)
```

### getConstants

```solidity
function getConstants() public pure returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, bytes32, uint256, uint256, uint256, bytes4, bytes32)
```

### _checkPublicInputs

```solidity
function _checkPublicInputs() private
```

### _hashPublicInputs

```solidity
function _hashPublicInputs(uint256 chainId, uint256 number, uint256 baseFee, bytes32[255] ancestors) private pure returns (bytes32)
```

