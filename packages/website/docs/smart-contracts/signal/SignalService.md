## SignalService

### SignalProof

```solidity
struct SignalProof {
  struct BlockHeader header;
  bytes proof;
}
```

### init

```solidity
function init(address _addressManager) external
```

_Initializer to be called after being deployed behind a proxy._

### sendSignal

```solidity
function sendSignal(address user, bytes32 signal) public
```

Send a signal by storing the key with a value of 1.

#### Parameters

| Name   | Type    | Description                          |
| ------ | ------- | ------------------------------------ |
| user   | address | The user address sending the signal. |
| signal | bytes32 | The signal to send.                  |

### isSignalSent

```solidity
function isSignalSent(address app, address user, bytes32 signal) public view returns (bool)
```

Check if a signal has been sent (key stored with a value of 1).

#### Parameters

| Name   | Type    | Description                         |
| ------ | ------- | ----------------------------------- |
| app    | address | The address that sent this message. |
| user   | address | The logical owner of the signal.    |
| signal | bytes32 | The signal to check.                |

### isSignalReceived

```solidity
function isSignalReceived(address app, address user, bytes32 signal, bytes proof) public view returns (bool verified)
```

Check if signal has been received on the destination chain (current).

#### Parameters

| Name   | Type    | Description                                             |
| ------ | ------- | ------------------------------------------------------- |
| app    | address | The address that sent this message.                     |
| user   | address |                                                         |
| signal | bytes32 | The signal to check.                                    |
| proof  | bytes   | The proof of the signal being sent on the source chain. |

### getSignalSlot

```solidity
function getSignalSlot(address app, address user, bytes32 signal) public pure returns (bytes32)
```
