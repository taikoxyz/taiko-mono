## LibBridgeProcess

Process bridge messages on the destination chain.

### processMessage

```solidity
function processMessage(struct LibBridgeData.State state, contract AddressResolver resolver, struct IBridge.Message message, bytes proof) external
```

Process the bridge message on the destination chain. It can be called by
any address, including `message.owner`. It starts by hashing the message,
and doing a lookup in the bridge state to see if the status is "NEW". It
then takes custody of the ether from the EtherVault and attempts to
invoke the messageCall, changing the message's status accordingly.
Finally, it refunds the processing fee if needed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state | struct LibBridgeData.State | The bridge state. |
| resolver | contract AddressResolver | The address resolver. |
| message | struct IBridge.Message | The message to process. |
| proof | bytes | The proof of the signal being sent on the source chain. |

