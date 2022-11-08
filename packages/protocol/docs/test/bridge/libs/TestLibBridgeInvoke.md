# TestLibBridgeInvoke









## Methods

### invokeMessageCall

```solidity
function invokeMessageCall(IBridge.Message message, bytes32 signal, uint256 gasLimit) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| message | IBridge.Message | undefined |
| signal | bytes32 | undefined |
| gasLimit | uint256 | undefined |

### state

```solidity
function state() external view returns (uint256 nextMessageId, struct IBridge.Context ctx)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| nextMessageId | uint256 | undefined |
| ctx | IBridge.Context | undefined |



## Events

### MessageInvoked

```solidity
event MessageInvoked(bytes32 signal, bool success)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| signal  | bytes32 | undefined |
| success  | bool | undefined |



