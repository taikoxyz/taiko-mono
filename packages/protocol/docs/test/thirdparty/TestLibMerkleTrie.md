# TestLibMerkleTrie

> TestLibMerkleTrie

## Methods

### get

```solidity
function get(bytes _key, bytes _proof, bytes32 _root) external pure returns (bool, bytes)
```

#### Parameters

| Name    | Type    | Description |
| ------- | ------- | ----------- |
| \_key   | bytes   | undefined   |
| \_proof | bytes   | undefined   |
| \_root  | bytes32 | undefined   |

#### Returns

| Name | Type  | Description |
| ---- | ----- | ----------- |
| \_0  | bool  | undefined   |
| \_1  | bytes | undefined   |

### verifyInclusionProof

```solidity
function verifyInclusionProof(bytes _key, bytes _value, bytes _proof, bytes32 _root) external view returns (bool)
```

#### Parameters

| Name    | Type    | Description |
| ------- | ------- | ----------- |
| \_key   | bytes   | undefined   |
| \_value | bytes   | undefined   |
| \_proof | bytes   | undefined   |
| \_root  | bytes32 | undefined   |

#### Returns

| Name | Type | Description |
| ---- | ---- | ----------- |
| \_0  | bool | undefined   |
