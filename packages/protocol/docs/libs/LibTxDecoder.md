## LibTxDecoder

### TransactionLegacy

```solidity
struct TransactionLegacy {
  uint256 nonce;
  uint256 gasPrice;
  uint256 gasLimit;
  address destination;
  uint256 amount;
  bytes data;
  uint8 v;
  uint256 r;
  uint256 s;
}
```

### Transaction2930

```solidity
struct Transaction2930 {
  uint256 chainId;
  uint256 nonce;
  uint256 gasPrice;
  uint256 gasLimit;
  address destination;
  uint256 amount;
  bytes data;
  struct LibTxDecoder.AccessItem[] accessList;
  uint8 signatureYParity;
  uint256 signatureR;
  uint256 signatureS;
}
```

### Transaction1559

```solidity
struct Transaction1559 {
  uint256 chainId;
  uint256 nonce;
  uint256 maxPriorityFeePerGas;
  uint256 maxFeePerGas;
  uint256 gasLimit;
  address destination;
  uint256 amount;
  bytes data;
  struct LibTxDecoder.AccessItem[] accessList;
  uint8 signatureYParity;
  uint256 signatureR;
  uint256 signatureS;
}
```

### AccessItem

```solidity
struct AccessItem {
  address addr;
  bytes32[] slots;
}
```

### Tx

```solidity
struct Tx {
  uint8 txType;
  address destination;
  bytes data;
  uint256 gasLimit;
  uint8 v;
  uint256 r;
  uint256 s;
  bytes txData;
}
```

### TxList

```solidity
struct TxList {
  struct LibTxDecoder.Tx[] items;
}
```

### decodeTxList

```solidity
function decodeTxList(bytes encoded) public pure returns (struct LibTxDecoder.TxList txList)
```

### decodeTx

```solidity
function decodeTx(bytes txBytes) public pure returns (struct LibTxDecoder.Tx _tx)
```

### hashTxList

```solidity
function hashTxList(bytes encoded) internal pure returns (bytes32)
```

### decodeLegacyTx

```solidity
function decodeLegacyTx(struct LibRLPReader.RLPItem[] body) internal pure returns (struct LibTxDecoder.TransactionLegacy txLegacy)
```

### decodeTx2930

```solidity
function decodeTx2930(struct LibRLPReader.RLPItem[] body) internal pure returns (struct LibTxDecoder.Transaction2930 tx2930)
```

### decodeTx1559

```solidity
function decodeTx1559(struct LibRLPReader.RLPItem[] body) internal pure returns (struct LibTxDecoder.Transaction1559 tx1559)
```

### decodeAccessList

```solidity
function decodeAccessList(struct LibRLPReader.RLPItem[] accessListRLP) internal pure returns (struct LibTxDecoder.AccessItem[] accessList)
```

### sumGasLimit

```solidity
function sumGasLimit(struct LibTxDecoder.TxList txList) internal pure returns (uint256 sum)
```

