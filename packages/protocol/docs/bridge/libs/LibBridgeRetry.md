## LibBridgeRetry

Retry bridge messages.

### retryMessage

```solidity
function retryMessage(struct LibBridgeData.State state, contract AddressResolver resolver, struct IBridge.Message message, bool isLastAttempt) external
```

Retry a bridge message on the destination chain. This function can be
called by any address, including `message.owner`. It can only be called
on messages marked "RETRIABLE". It attempts to reinvoke the messageCall.
If reinvoking fails and `isLastAttempt` is set to true, then the message
is marked "DONE" and cannot be retried.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state | struct LibBridgeData.State | The bridge state. |
| resolver | contract AddressResolver | The address resolver. |
| message | struct IBridge.Message | The message to retry. |
| isLastAttempt | bool | Specifies if this is the last attempt to retry the                      message. |

