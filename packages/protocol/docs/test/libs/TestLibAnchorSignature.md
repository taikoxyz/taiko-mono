# TestLibAnchorSignature

## Methods

### goldenTouchAddress

```solidity
function goldenTouchAddress() external pure returns (address, uint256)
```

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |
| \_1  | uint256 | undefined   |

### recover

```solidity
function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) external pure returns (address)
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| hash | bytes32 | undefined   |
| v    | uint8   | undefined   |
| r    | bytes32 | undefined   |
| s    | bytes32 | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| \_0  | address | undefined   |

### signTransaction

```solidity
function signTransaction(bytes32 digest, uint8 k) external view returns (uint8 v, uint256 r, uint256 s)
```

#### Parameters

| Name   | Type    | Description |
| ------ | ------- | ----------- |
| digest | bytes32 | undefined   |
| k      | uint8   | undefined   |

#### Returns

| Name | Type    | Description |
| ---- | ------- | ----------- |
| v    | uint8   | undefined   |
| r    | uint256 | undefined   |
| s    | uint256 | undefined   |
