## LibBridgeData

Stores message data for the bridge.

### MessageStatus

```solidity
enum MessageStatus {
  NEW,
  RETRIABLE,
  DONE
}
```

### State

```solidity
struct State {
  mapping(uint256 => bool) destChains;
  mapping(bytes32 => enum LibBridgeData.MessageStatus) messageStatus;
  uint256 nextMessageId;
  struct IBridge.Context ctx;
  uint256[44] __gap;
}
```

### SIGNAL_PLACEHOLDER

```solidity
bytes32 SIGNAL_PLACEHOLDER
```

### CHAINID_PLACEHOLDER

```solidity
uint256 CHAINID_PLACEHOLDER
```

### SRC_CHAIN_SENDER_PLACEHOLDER

```solidity
address SRC_CHAIN_SENDER_PLACEHOLDER
```

### MessageSent

```solidity
event MessageSent(bytes32 signal, struct IBridge.Message message)
```

### MessageStatusChanged

```solidity
event MessageStatusChanged(bytes32 signal, enum LibBridgeData.MessageStatus status)
```

### DestChainEnabled

```solidity
event DestChainEnabled(uint256 chainId, bool enabled)
```

### updateMessageStatus

```solidity
function updateMessageStatus(struct LibBridgeData.State state, bytes32 signal, enum LibBridgeData.MessageStatus status) internal
```

_If messageStatus is same as in the messageStatus mapping,
     does nothing._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state | struct LibBridgeData.State | The current bridge state. |
| signal | bytes32 | The messageHash of the message. |
| status | enum LibBridgeData.MessageStatus | The status of the message. |

### hashMessage

```solidity
function hashMessage(struct IBridge.Message message) internal pure returns (bytes32)
```

_Hashes messages and returns the hash signed with
"TAIKO_BRIDGE_MESSAGE" for verification._

