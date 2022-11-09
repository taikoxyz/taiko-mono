## BlockHeader

```solidity
struct BlockHeader {
  bytes32 parentHash;
  bytes32 ommersHash;
  address beneficiary;
  bytes32 stateRoot;
  bytes32 transactionsRoot;
  bytes32 receiptsRoot;
  bytes32[8] logsBloom;
  uint256 difficulty;
  uint128 height;
  uint64 gasLimit;
  uint64 gasUsed;
  uint64 timestamp;
  bytes extraData;
  bytes32 mixHash;
  uint64 nonce;
  uint256 baseFeePerGas;
}

```

## LibBlockHeader

### EMPTY_OMMERS_HASH

```solidity
bytes32 EMPTY_OMMERS_HASH
```

### hashBlockHeader

```solidity
function hashBlockHeader(struct BlockHeader header) internal pure returns (bytes32)
```

### isPartiallyValidForTaiko

```solidity
function isPartiallyValidForTaiko(struct BlockHeader header) internal pure returns (bool)
```
