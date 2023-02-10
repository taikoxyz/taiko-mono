---
title: Bridge
---

## Bridge

Bridge contract which is deployed on both L1 and L2. Mostly a thin wrapper
which calls the library implementations. See _IBridge_ for more details.

_The code hash for the same address on L1 and L2 may be different._

### MessageStatusChanged

```solidity
event MessageStatusChanged(bytes32 msgHash, enum LibBridgeStatus.MessageStatus status)
```

### DestChainEnabled

```solidity
event DestChainEnabled(uint256 chainId, bool enabled)
```

### receive

```solidity
receive() external payable
```

Allow Bridge to receive ETH from the TokenVault or EtherVault.

### init

```solidity
function init(address _addressManager) external
```

_Initializer to be called after being deployed behind a proxy._

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
function isMessageSent(bytes32 msgHash) public view virtual returns (bool)
```

Checks if a msgHash has been stored on the bridge contract by the
current address.

### isMessageReceived

```solidity
function isMessageReceived(bytes32 msgHash, uint256 srcChainId, bytes proof) public view virtual returns (bool)
```

Checks if a msgHash has been received on the destination chain and
sent by the src chain.

### isMessageFailed

```solidity
function isMessageFailed(bytes32 msgHash, uint256 destChainId, bytes proof) public view virtual returns (bool)
```

Checks if a msgHash has been failed on the destination chain.

### getMessageStatus

```solidity
function getMessageStatus(bytes32 msgHash) public view virtual returns (enum LibBridgeStatus.MessageStatus)
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

### hashMessage

```solidity
function hashMessage(struct IBridge.Message message) public pure returns (bytes32)
```

### getMessageStatusSlot

```solidity
function getMessageStatusSlot(bytes32 msgHash) public pure returns (bytes32)
```
