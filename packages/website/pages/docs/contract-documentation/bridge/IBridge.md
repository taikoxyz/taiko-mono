---
title: IBridge
---

## IBridge

Bridge interface.

_Cross-chain Ether is held by Bridges, not TokenVaults._

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
  bytes32 signal;
  address sender;
  uint256 srcChainId;
}
```

### SignalSent

```solidity
event SignalSent(address sender, bytes32 signal)
```

### MessageSent

```solidity
event MessageSent(bytes32 signal, struct IBridge.Message message)
```

### sendMessage

```solidity
function sendMessage(struct IBridge.Message message) external payable returns (bytes32 signal)
```

Sends a message to the destination chain and takes custody
of Ether required in this contract. All extra Ether will be refunded.

### sendSignal

```solidity
function sendSignal(bytes32 signal) external
```

Stores a signal on the bridge contract and emits an event for the
relayer to pick up.

### isMessageSent

```solidity
function isMessageSent(bytes32 signal) external view returns (bool)
```

Checks if a signal has been stored on the bridge contract by the
current address.

### isMessageReceived

```solidity
function isMessageReceived(bytes32 signal, uint256 srcChainId, bytes proof) external view returns (bool)
```

Checks if a signal has been received on the destination chain and
sent by the src chain.

### isSignalSent

```solidity
function isSignalSent(address sender, bytes32 signal) external view returns (bool)
```

Checks if a signal has been stored on the bridge contract by the
specified address.

### isSignalReceived

```solidity
function isSignalReceived(bytes32 signal, uint256 srcChainId, address sender, bytes proof) external view returns (bool)
```

Check if a signal has been received on the destination chain and sent
by the specified sender.

### context

```solidity
function context() external view returns (struct IBridge.Context context)
```

Returns the bridge state context.
