---
title: ISignalService
---

## ISignalService

The SignalService contract serves as a secure cross-chain message
passing system. It defines methods for sending and verifying signals with
merkle proofs. The trust assumption is that the target chain has secure
access to the merkle root (such as Taiko injects it in the anchor
transaction). With this, verifying a signal is reduced to simply verifying
a merkle proof.

### sendSignal

```solidity
function sendSignal(bytes32 signal) external returns (bytes32 storageSlot)
```

Send a signal (message) by setting the storage slot to a value
of 1.

#### Parameters

| Name   | Type    | Description                   |
| ------ | ------- | ----------------------------- |
| signal | bytes32 | The signal (message) to send. |

#### Return Values

| Name        | Type    | Description                                          |
| ----------- | ------- | ---------------------------------------------------- |
| storageSlot | bytes32 | The location in storage where this signal is stored. |

### isSignalSent

```solidity
function isSignalSent(address app, bytes32 signal) external view returns (bool)
```

Verifies if a particular signal has already been sent.

#### Parameters

| Name   | Type    | Description                            |
| ------ | ------- | -------------------------------------- |
| app    | address | The address that initiated the signal. |
| signal | bytes32 | The signal (message) to send.          |

#### Return Values

| Name | Type | Description                                        |
| ---- | ---- | -------------------------------------------------- |
| [0]  | bool | True if the signal has been sent, otherwise false. |

### isSignalReceived

```solidity
function isSignalReceived(uint256 srcChainId, address app, bytes32 signal, bytes proof) external view returns (bool)
```

Verifies if a signal has been received on the target chain.

#### Parameters

| Name       | Type    | Description                                                           |
| ---------- | ------- | --------------------------------------------------------------------- |
| srcChainId | uint256 | The identifier for the source chain from which the signal originated. |
| app        | address | The address that initiated the signal.                                |
| signal     | bytes32 | The signal (message) to send.                                         |
| proof      | bytes   | Merkle proof that the signal was persisted on the source chain.       |

#### Return Values

| Name | Type | Description                                            |
| ---- | ---- | ------------------------------------------------------ |
| [0]  | bool | True if the signal has been received, otherwise false. |
