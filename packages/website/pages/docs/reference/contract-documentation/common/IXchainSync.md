## ChainData

```solidity
struct ChainData {
  bytes32 blockHash;
  bytes32 signalRoot;
}
```

---

## title: IXchainSync

## IXchainSync

### XchainSynced

```solidity
event XchainSynced(uint256 srcHeight, struct ChainData srcChainData)
```

### getXchainBlockHash

```solidity
function getXchainBlockHash(uint256 number) external view returns (bytes32)
```

Returns the cross-chain block hash at the given block number.

#### Parameters

| Name   | Type    | Description                                   |
| ------ | ------- | --------------------------------------------- |
| number | uint256 | The block number. Use 0 for the latest block. |

#### Return Values

| Name | Type    | Description                 |
| ---- | ------- | --------------------------- |
| [0]  | bytes32 | The cross-chain block hash. |

### getXchainSignalRoot

```solidity
function getXchainSignalRoot(uint256 number) external view returns (bytes32)
```

Returns the cross-chain signal service storage root at the given
block number.

#### Parameters

| Name   | Type    | Description                                   |
| ------ | ------- | --------------------------------------------- |
| number | uint256 | The block number. Use 0 for the latest block. |

#### Return Values

| Name | Type    | Description                                  |
| ---- | ------- | -------------------------------------------- |
| [0]  | bytes32 | The cross-chain signal service storage root. |
