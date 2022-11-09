## LibInvalidTxList

A library to invalidate a txList using the following rules:

A txList is valid if and only if:

1. The txList's length is no more than `TAIKO_TXLIST_MAX_BYTES`.
2. The txList is well-formed RLP, with no additional trailing bytes.
3. The total number of transactions is no more than `TAIKO_BLOCK_MAX_TXS`.
4. The sum of all transaction gas limit is no more than
   `TAIKO_BLOCK_MAX_GAS_LIMIT`.

A transaction is valid if and only if:

1. The transaction is well-formed RLP, with no additional trailing bytes
   (rule #1 in Ethereum yellow paper).
2. The transaction's signature is valid (rule #2 in Ethereum yellow paper).
3. The transaction's the gas limit is no smaller than the intrinsic gas
   `TAIKO_TX_MIN_GAS_LIMIT` (rule #5 in Ethereum yellow paper).

### Reason

```solidity
enum Reason {
  OK,
  BINARY_TOO_LARGE,
  BINARY_NOT_DECODABLE,
  BLOCK_TOO_MANY_TXS,
  BLOCK_GAS_LIMIT_TOO_LARGE,
  TX_INVALID_SIG,
  TX_GAS_LIMIT_TOO_SMALL
}

```

### isTxListInvalid

```solidity
function isTxListInvalid(bytes encoded, enum LibInvalidTxList.Reason hint, uint256 txIdx) internal pure returns (enum LibInvalidTxList.Reason)
```
