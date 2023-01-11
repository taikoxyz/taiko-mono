## ISignalService

### sendSignal

```solidity
function sendSignal(address user, bytes32 signal) external
```

Send a signal by storing the key with a value of 1.

#### Parameters

| Name   | Type    | Description                          |
| ------ | ------- | ------------------------------------ |
| user   | address | The user address sending the signal. |
| signal | bytes32 | The signal to send.                  |

### isSignalSent

```solidity
function isSignalSent(address app, address user, bytes32 signal) external view returns (bool)
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
function isSignalReceived(address app, address user, bytes32 signal, bytes proof) external view returns (bool)
```

Check if signal has been received on the destination chain (current).

#### Parameters

| Name   | Type    | Description                                             |
| ------ | ------- | ------------------------------------------------------- |
| app    | address | The address that sent this message.                     |
| user   | address |                                                         |
| signal | bytes32 | The signal to check.                                    |
| proof  | bytes   | The proof of the signal being sent on the source chain. |
