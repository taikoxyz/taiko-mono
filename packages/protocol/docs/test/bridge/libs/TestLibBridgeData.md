# TestLibBridgeData









## Methods

### getMessageStatus

```solidity
function getMessageStatus(bytes32 signal) external view returns (enum LibBridgeData.MessageStatus)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| signal | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | enum LibBridgeData.MessageStatus | undefined |

### hashMessage

```solidity
function hashMessage(IBridge.Message message) external pure returns (bytes32)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| message | IBridge.Message | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### state

```solidity
function state() external view returns (uint256 nextMessageId, struct IBridge.Context ctx)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| nextMessageId | uint256 | undefined |
| ctx | IBridge.Context | undefined |

### updateMessageStatus

```solidity
function updateMessageStatus(bytes32 signal, enum LibBridgeData.MessageStatus status) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| signal | bytes32 | undefined |
| status | enum LibBridgeData.MessageStatus | undefined |




