## V1Verifying

### BlockVerified

```solidity
event BlockVerified(uint256 id, bytes32 blockHash)
```

### HeaderSynced

```solidity
event HeaderSynced(uint256 height, uint256 srcHeight, bytes32 srcHash)
```

### init

```solidity
function init(struct LibData.State state, bytes32 genesisBlockHash) public
```

### verifyBlocks

```solidity
function verifyBlocks(struct LibData.State state, contract AddressResolver resolver, uint256 maxBlocks, bool checkHalt) public
```

### \_cleanUp

```solidity
function _cleanUp(struct LibData.ForkChoice fc) private
```

### \_isVerifiable

```solidity
function _isVerifiable(struct LibData.State state, struct LibData.ForkChoice fc) private view returns (bool)
```
