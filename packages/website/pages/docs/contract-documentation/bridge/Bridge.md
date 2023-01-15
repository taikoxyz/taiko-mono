---
title: Bridge
---

## Bridge

Bridge contract which is deployed on both L1 and L2. Mostly a thin wrapper
which calls the library implementations. See _IBridge_ for more details.

_The code hash for the same address on L1 and L2 may be different._

### MessageStatusChanged

```solidity
event MessageStatusChanged(bytes32 signal, enum LibBridgeStatus.MessageStatus status)
```

### DestChainEnabled

```solidity
event DestChainEnabled(uint256 chainId, bool enabled)
```

### receive

```solidity
receive() external payable
```

Allow Bridge to receive ETH from EtherVault.

### init

```solidity
function init(address _addressManager) external
```

_Initializer to be called after being deployed behind a proxy._

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

### processMessage

```solidity
function processMessage(struct IBridge.Message message, bytes proof) external
```

### retryMessage

```solidity
function retryMessage(struct IBridge.Message message, bool isLastAttempt) external
```

### isMessageSent

```solidity
function isMessageSent(bytes32 signal) public view virtual returns (bool)
```

Checks if a signal has been stored on the bridge contract by the
current address.

### isMessageReceived

```solidity
function isMessageReceived(bytes32 signal, uint256 srcChainId, bytes proof) public view virtual returns (bool)
```

Checks if a signal has been received on the destination chain and
sent by the src chain.

### isSignalSent

```solidity
function isSignalSent(address sender, bytes32 signal) public view virtual returns (bool)
```

Checks if a signal has been stored on the bridge contract by the
specified address.

### isSignalReceived

```solidity
function isSignalReceived(bytes32 signal, uint256 srcChainId, address sender, bytes proof) public view virtual returns (bool)
```

Check if a signal has been received on the destination chain and sent
by the specified sender.

### getMessageStatus

```solidity
function getMessageStatus(bytes32 signal) public view virtual returns (enum LibBridgeStatus.MessageStatus)
```

### context

```solidity
function context() public view returns (struct IBridge.Context)
```

Returns the bridge state context.

### isDestChainEnabled

```solidity
function isDestChainEnabled(uint256 _chainId) public view returns (bool)
```

### getMessageStatusSlot

```solidity
function getMessageStatusSlot(bytes32 signal) public pure returns (bytes32)
```
