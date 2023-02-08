---
title: ISignalService
---

## ISignalService

### sendSignal

```solidity
function sendSignal(bytes32 signal) external returns (bytes32 storageSlot)
```

Send a signal by storing the key with a value of 1.

#### Parameters

| Name   | Type    | Description         |
| ------ | ------- | ------------------- |
| signal | bytes32 | The signal to send. |

#### Return Values

| Name        | Type    | Description                                        |
| ----------- | ------- | -------------------------------------------------- |
| storageSlot | bytes32 | The slot in storage that this signal is persisted. |

### isSignalSent

```solidity
function isSignalSent(address app, bytes32 signal) external view returns (bool)
```

Check if a signal has been sent (key stored with a value of 1).

#### Parameters

| Name   | Type    | Description                         |
| ------ | ------- | ----------------------------------- |
| app    | address | The address that sent this message. |
| signal | bytes32 | The signal to check.                |

### isSignalReceived

```solidity
function isSignalReceived(uint256 srcChainId, address app, bytes32 signal, bytes proof) external view returns (bool)
```

Check if signal has been received on the destination chain (current).

#### Parameters

| Name       | Type    | Description                                             |
| ---------- | ------- | ------------------------------------------------------- |
| srcChainId | uint256 | The source chain ID.                                    |
| app        | address | The address that sent this message.                     |
| signal     | bytes32 | The signal to check.                                    |
| proof      | bytes   | The proof of the signal being sent on the source chain. |
