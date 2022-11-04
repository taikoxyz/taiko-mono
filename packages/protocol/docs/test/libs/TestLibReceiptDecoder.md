# TestLibReceiptDecoder

## Methods

### decodeReceipt

```solidity
function decodeReceipt(bytes encoded) external pure returns (struct LibReceiptDecoder.Receipt receipt)
```

#### Parameters

| Name    | Type  | Description |
| ------- | ----- | ----------- |
| encoded | bytes | undefined   |

#### Returns

| Name    | Type                      | Description |
| ------- | ------------------------- | ----------- |
| receipt | LibReceiptDecoder.Receipt | undefined   |

### emitTestEvent

```solidity
function emitTestEvent(uint256 a, bytes32 b) external nonpayable
```

#### Parameters

| Name | Type    | Description |
| ---- | ------- | ----------- |
| a    | uint256 | undefined   |
| b    | bytes32 | undefined   |

## Events

### TestLibReceiptDecoderEvent

```solidity
event TestLibReceiptDecoderEvent(uint256 indexed a, bytes32 b)
```

#### Parameters

| Name        | Type    | Description |
| ----------- | ------- | ----------- |
| a `indexed` | uint256 | undefined   |
| b           | bytes32 | undefined   |
