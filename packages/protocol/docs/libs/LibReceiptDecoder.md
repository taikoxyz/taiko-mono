## LibReceiptDecoder

### Receipt

```solidity
struct Receipt {
  uint64 status;
  uint64 cumulativeGasUsed;
  bytes32[8] logsBloom;
  struct LibReceiptDecoder.Log[] logs;
}
```

### Log

```solidity
struct Log {
  address contractAddress;
  bytes32[] topics;
  bytes data;
}

```

### decodeReceipt

```solidity
function decodeReceipt(bytes encoded) public pure returns (struct LibReceiptDecoder.Receipt receipt)
```

### decodeLogsBloom

```solidity
function decodeLogsBloom(struct LibRLPReader.RLPItem logsBloomRlp) internal pure returns (bytes32[8] logsBloom)
```

### decodeLogs

```solidity
function decodeLogs(struct LibRLPReader.RLPItem[] logsRlp) internal pure returns (struct LibReceiptDecoder.Log[])
```

### decodeTopics

```solidity
function decodeTopics(struct LibRLPReader.RLPItem[] topicsRlp) internal pure returns (bytes32[])
```
