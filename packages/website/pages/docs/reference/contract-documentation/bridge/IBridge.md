---
title: IBridge
---

## IBridge

The bridge used in conjunction with the {ISignalService}.

_Ether is held by Bridges on L1 and L2s._

### Message

```solidity
struct Message {
  uint128 id;
  address from;
  uint64 srcChainId;
  uint64 destChainId;
  address owner;
  address to;
  address refundTo;
  uint256 value;
  uint256 fee;
  uint256 gasLimit;
  bytes data;
  string memo;
}
```

### Context

```solidity
struct Context {
  bytes32 msgHash;
  address from;
  uint64 srcChainId;
}
```

### sendMessage

```solidity
function sendMessage(struct IBridge.Message message) external payable returns (bytes32 msgHash, struct IBridge.Message updatedMessage)
```

Sends a message to the destination chain and takes custody
of Ether required in this contract. All extra Ether will be refunded.

#### Parameters

| Name    | Type                   | Description             |
| ------- | ---------------------- | ----------------------- |
| message | struct IBridge.Message | The message to be sent. |

#### Return Values

| Name           | Type                   | Description                   |
| -------------- | ---------------------- | ----------------------------- |
| msgHash        | bytes32                | The hash of the sent message. |
| updatedMessage | struct IBridge.Message | The updated message sent.     |

### context

```solidity
function context() external view returns (struct IBridge.Context context)
```

Returns the bridge state context.

#### Return Values

| Name    | Type                   | Description                                  |
| ------- | ---------------------- | -------------------------------------------- |
| context | struct IBridge.Context | The context of the current bridge operation. |

---

## title: IRecallableSender

## IRecallableSender

An interface that all recallable message senders shall implement.

### onMessageRecalled

```solidity
function onMessageRecalled(struct IBridge.Message message, bytes32 msgHash) external payable
```
