## LibTrieProof

### ACCOUNT_FIELD_INDEX_STORAGE_HASH

```solidity
uint256 ACCOUNT_FIELD_INDEX_STORAGE_HASH
```

### verify

```solidity
function verify(bytes32 stateRoot, address addr, bytes32 key, bytes32 value, bytes mkproof) public pure
```

Verifies that the value of a slot `key` in the storage tree of `addr`
is `value`.

#### Parameters

| Name      | Type    | Description                                                   |
| --------- | ------- | ------------------------------------------------------------- |
| stateRoot | bytes32 | The merkle root of state tree.                                |
| addr      | address | The contract address.                                         |
| key       | bytes32 | The slot in the contract.                                     |
| value     | bytes32 | The value to be verified.                                     |
| mkproof   | bytes   | The proof obtained by encoding state proof and storage proof. |
