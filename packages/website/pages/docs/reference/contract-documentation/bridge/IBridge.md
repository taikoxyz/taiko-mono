---
title: IBridge
---

## IBridge

Bridge interface.

_Ether is held by Bridges on L1 and by the EtherVault on L2,
not TokenVaults._

### Message

```solidity
struct Message {
  uint256 id;
  address sender;
  uint256 srcChainId;
  uint256 destChainId;
  address owner;
  address to;
  address refundAddress;
  uint256 depositValue;
  uint256 callValue;
  uint256 processingFee;
  uint256 gasLimit;
  bytes data;
  string memo;
}
```

### Context

```solidity
struct Context {
  bytes32 msgHash;
  address sender;
  uint256 srcChainId;
}
```

### SignalSent

```solidity
event SignalSent(address sender, bytes32 msgHash)
```

### MessageSent

```solidity
event MessageSent(bytes32 msgHash, struct IBridge.Message message)
```

### EtherReleased

```solidity
event EtherReleased(bytes32 msgHash, address to, uint256 amount)
```

### sendMessage

```solidity
function sendMessage(struct IBridge.Message message) external payable returns (bytes32 msgHash)
```

Sends a message to the destination chain and takes custody
of Ether required in this contract. All extra Ether will be refunded.

### releaseEther

```solidity
function releaseEther(struct IBridge.Message message, bytes proof) external
```

### isMessageSent

```solidity
function isMessageSent(bytes32 msgHash) external view returns (bool)
```

Checks if a msgHash has been stored on the bridge contract by the
current address.

### isMessageReceived

```solidity
function isMessageReceived(bytes32 msgHash, uint256 srcChainId, bytes proof) external view returns (bool)
```

Checks if a msgHash has been received on the destination chain and
sent by the src chain.

### isMessageFailed

```solidity
function isMessageFailed(bytes32 msgHash, uint256 destChainId, bytes proof) external view returns (bool)
```

Checks if a msgHash has been failed on the destination chain.

### context

```solidity
function context() external view returns (struct IBridge.Context context)
```

Returns the bridge state context.

### hashMessage

```solidity
function hashMessage(struct IBridge.Message message) external pure returns (bytes32)
```
