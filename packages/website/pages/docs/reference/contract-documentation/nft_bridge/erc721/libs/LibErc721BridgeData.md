---
title: LibErc721BridgeData
---

## LibErc721BridgeData

Stores message metadata on the Bridge. It's used to keep track of the state
of messages that are being
transferred across the bridge, and it contains functions to hash messages and
check their status.

### State

_The State struct stores the state of messages in the Bridge
contract._

```solidity
struct State {
  uint256 nextMessageId;
  struct IErc721Bridge.Context ctx;
  mapping(bytes32 => bool) tokensReleased;
  uint256[45] __gap;
}
```

### StatusProof

_StatusProof holds the block header and proof for a particular
status._

```solidity
struct StatusProof {
  struct BlockHeader header;
  bytes proof;
}
```

### MESSAGE_HASH_PLACEHOLDER

```solidity
bytes32 MESSAGE_HASH_PLACEHOLDER
```

### CHAINID_PLACEHOLDER

```solidity
uint256 CHAINID_PLACEHOLDER
```

### SRC_CHAIN_SENDER_PLACEHOLDER

```solidity
address SRC_CHAIN_SENDER_PLACEHOLDER
```

### MessageSentErc721

```solidity
event MessageSentErc721(bytes32 msgHash, struct IErc721Bridge.Message message)
```

### DestChainEnabledErc721

```solidity
event DestChainEnabledErc721(uint256 chainId, bool enabled)
```

### hashMessage

```solidity
function hashMessage(struct IErc721Bridge.Message message) internal pure returns (bytes32)
```

Calculate the keccak256 hash of the message

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| message | struct IErc721Bridge.Message | The message to be hashed |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | msgHash The keccak256 hash of the message |

