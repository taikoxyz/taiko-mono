## V1Proving

### Evidence

```solidity
struct Evidence {
  struct LibData.BlockMetadata meta;
  struct BlockHeader header;
  address prover;
  bytes[] proofs;
}
```

### BlockProven

```solidity
event BlockProven(uint256 id, bytes32 parentHash, bytes32 blockHash, uint64 timestamp, uint64 provenAt, address prover)
```

### proveBlock

```solidity
function proveBlock(struct LibData.State s, contract AddressResolver resolver, uint256 blockIndex, bytes[] inputs) public
```

### proveBlockInvalid

```solidity
function proveBlockInvalid(struct LibData.State s, contract AddressResolver resolver, uint256 blockIndex, bytes[] inputs) public
```

### _proveBlock

```solidity
function _proveBlock(struct LibData.State s, contract AddressResolver resolver, struct V1Proving.Evidence evidence, struct LibData.BlockMetadata target, bytes32 blockHashOverride) private
```

### _markBlockProven

```solidity
function _markBlockProven(struct LibData.State s, address prover, struct LibData.BlockMetadata target, bytes32 parentHash, bytes32 blockHash) private
```

### _validateAnchorTxSignature

```solidity
function _validateAnchorTxSignature(struct LibTxDecoder.Tx _tx) private view
```

### _checkMetadata

```solidity
function _checkMetadata(struct LibData.State s, struct LibData.BlockMetadata meta) private view
```

### _validateHeaderForMetadata

```solidity
function _validateHeaderForMetadata(struct BlockHeader header, struct LibData.BlockMetadata meta) private pure
```

