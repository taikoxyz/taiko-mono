# LibBlockHeaderDecoder

> LibBlockHeaderDecoder

## Methods

### decodeBlockHeader

```solidity
function decodeBlockHeader(bytes blockHeader, bytes32 blockHash, bool postEIP1559) external pure returns (bytes32 _stateRoot, uint256 _timestamp, bytes32 _transactionsRoot, bytes32 _receiptsRoot)
```

This method extracts [stateRoot, timestamp] of a block header.

#### Parameters

| Name        | Type    | Description                                          |
| ----------- | ------- | ---------------------------------------------------- |
| blockHeader | bytes   | RLP encoded block header                             |
| blockHash   | bytes32 | The expected block hash                              |
| postEIP1559 | bool    | True to check header to have 16 fields, 15 otherwise |

#### Returns

| Name               | Type    | Description          |
| ------------------ | ------- | -------------------- |
| \_stateRoot        | bytes32 | The state root       |
| \_timestamp        | uint256 | The timestamp        |
| \_transactionsRoot | bytes32 | The transactionsRoot |
| \_receiptsRoot     | bytes32 | The receiptsRoot     |
