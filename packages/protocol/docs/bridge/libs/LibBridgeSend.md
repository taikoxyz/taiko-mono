## LibBridgeSend

Entry point for starting a bridge transaction.

### sendMessage

```solidity
function sendMessage(struct LibBridgeData.State state, contract AddressResolver resolver, struct IBridge.Message message) internal returns (bytes32 signal)
```

Initiate a bridge request.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state | struct LibBridgeData.State |  |
| resolver | contract AddressResolver |  |
| message | struct IBridge.Message | Specifies the `depositValue`, `callValue`, and `processingFee`. These must sum to `msg.value`. It also specifies the `destChainId` which must be first enabled via `enableDestChain`, and differ from the current chain ID. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| signal | bytes32 | The message is hashed, stored, and emitted as a signal. This is picked up by an off-chain relayer which indicates a bridge message has been sent and is ready to be processed on the destination chain. |

### enableDestChain

```solidity
function enableDestChain(struct LibBridgeData.State state, uint256 chainId, bool enabled) internal
```

Enable a destination chain ID for bridge transactions.

