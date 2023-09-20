---
title: SignalService
---

## SignalService

See the documentation in {ISignalService} for more details.

### SignalProof

```solidity
struct SignalProof {
  uint64 height;
  bytes proof;
}
```

### B_ZERO_SIGNAL

```solidity
error B_ZERO_SIGNAL()
```

### B_NULL_APP_ADDR

```solidity
error B_NULL_APP_ADDR()
```

### B_WRONG_CHAIN_ID

```solidity
error B_WRONG_CHAIN_ID()
```

### validApp

```solidity
modifier validApp(address app)
```

### validSignal

```solidity
modifier validSignal(bytes32 signal)
```

### validChainId

```solidity
modifier validChainId(uint256 srcChainId)
```

### init

```solidity
function init(address _addressManager) external
```

_Initializer to be called after being deployed behind a proxy._

### sendSignal

```solidity
function sendSignal(bytes32 signal) public returns (bytes32 storageSlot)
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
function isSignalSent(address app, bytes32 signal) public view returns (bool)
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
function isSignalReceived(uint256 srcChainId, address app, bytes32 signal, bytes proof) public view returns (bool)
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

### getSignalSlot

```solidity
function getSignalSlot(address app, bytes32 signal) public pure returns (bytes32 signalSlot)
```

Get the storage slot of the signal.

#### Parameters

| Name   | Type    | Description                            |
| ------ | ------- | -------------------------------------- |
| app    | address | The address that initiated the signal. |
| signal | bytes32 | The signal to get the storage slot of. |

#### Return Values

| Name       | Type    | Description                                                                                                      |
| ---------- | ------- | ---------------------------------------------------------------------------------------------------------------- |
| signalSlot | bytes32 | The unique storage slot of the signal which is created by encoding the sender address with the signal (message). |

---

## title: ProxiedSignalService

## ProxiedSignalService

Proxied version of the parent contract.
