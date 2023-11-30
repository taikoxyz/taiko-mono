---
title: SignalService
---

## SignalService

See the documentation in {ISignalService} for more details.

_Labeled in AddressResolver as "signal_service"
Authorization Guide for Multi-Hop Bridging:
For facilitating multi-hop bridging, authorize all deployed TaikoL1 and
TaikoL2 contracts involved in the bridging path.
Use the respective chain IDs as labels for authorization.
Note: SignalService should not authorize Bridges or other Bridgable
applications._

### Hop

```solidity
struct Hop {
  address signalRootRelay;
  bytes32 signalRoot;
  bytes storageProof;
}
```

### Proof

```solidity
struct Proof {
  address crossChainSync;
  uint64 height;
  bytes storageProof;
  struct SignalService.Hop[] hops;
}
```

### SS_INVALID_APP

```solidity
error SS_INVALID_APP()
```

### SS_INVALID_SIGNAL

```solidity
error SS_INVALID_SIGNAL()
```

### init

```solidity
function init() external
```

_Initializer to be called after being deployed behind a proxy._

### sendSignal

```solidity
function sendSignal(bytes32 signal) public returns (bytes32 slot)
```

Send a signal (message) by setting the storage slot to a value
of 1.

#### Parameters

| Name   | Type    | Description                   |
| ------ | ------- | ----------------------------- |
| signal | bytes32 | The signal (message) to send. |

#### Return Values

| Name | Type    | Description |
| ---- | ------- | ----------- |
| slot | bytes32 |             |

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

### proveSignalReceived

```solidity
function proveSignalReceived(uint64 srcChainId, address app, bytes32 signal, bytes proof) public view returns (bool)
```

Verifies if a signal has been received on the target chain.

#### Parameters

| Name       | Type    | Description                                                           |
| ---------- | ------- | --------------------------------------------------------------------- |
| srcChainId | uint64  | The identifier for the source chain from which the signal originated. |
| app        | address | The address that initiated the signal.                                |
| signal     | bytes32 | The signal (message) to send.                                         |
| proof      | bytes   | Merkle proof that the signal was persisted on the source chain.       |

#### Return Values

| Name | Type | Description                                            |
| ---- | ---- | ------------------------------------------------------ |
| [0]  | bool | True if the signal has been received, otherwise false. |

### getSignalSlot

```solidity
function getSignalSlot(uint64 chainId, address app, bytes32 signal) public pure returns (bytes32)
```

Get the storage slot of the signal.

#### Parameters

| Name    | Type    | Description                            |
| ------- | ------- | -------------------------------------- |
| chainId | uint64  | The address's chainId.                 |
| app     | address | The address that initiated the signal. |
| signal  | bytes32 | The signal to get the storage slot of. |

#### Return Values

| Name | Type    | Description                                                                                                      |
| ---- | ------- | ---------------------------------------------------------------------------------------------------------------- |
| [0]  | bytes32 | The unique storage slot of the signal which is created by encoding the sender address with the signal (message). |

### skipProofCheck

```solidity
function skipProofCheck() public pure virtual returns (bool)
```

Tells if we need to check real proof or it is a test.

#### Return Values

| Name | Type | Description                                     |
| ---- | ---- | ----------------------------------------------- |
| [0]  | bool | Returns true to skip checking inclusion proofs. |

---

## title: ProxiedSingletonSignalService

## ProxiedSingletonSignalService

Proxied version of the parent contract.

_Deploy this contract as a singleton per chain for use by multiple L2s
or L3s. No singleton check is performed within the code; it's the deployer's
responsibility to ensure this. Singleton deployment is essential for
enabling multi-hop bridging across all Taiko L2/L3s._
