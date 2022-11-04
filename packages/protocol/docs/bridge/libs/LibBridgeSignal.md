## LibBridgeSignal

Library for working with bridge signals.

### SignalProof

```solidity
struct SignalProof {
  struct BlockHeader header;
  bytes proof;
}
```

### onlyValidSenderAndSignal

```solidity
modifier onlyValidSenderAndSignal(address sender, bytes32 signal)
```

### sendSignal

```solidity
function sendSignal(address sender, bytes32 signal) internal
```

Send a signal by storing the key with a value of 1.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address sending the signal. |
| signal | bytes32 | The signal to send. |

### isSignalSent

```solidity
function isSignalSent(address sender, bytes32 signal) internal view returns (bool)
```

Check if a signal has been sent (key stored with a value of 1).

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The sender of the signal. |
| signal | bytes32 | The signal to check. |

### isSignalReceived

```solidity
function isSignalReceived(contract AddressResolver resolver, address srcBridge, address sender, bytes32 signal, bytes proof) internal view returns (bool)
```

Check if signal has been received on the destination chain (current).

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| resolver | contract AddressResolver | The address resolver. |
| srcBridge | address | Address of the source bridge where the bridge                  was initiated. |
| sender | address | Address of the sender of the signal               (also should be srcBridge). |
| signal | bytes32 | The signal to check. |
| proof | bytes | The proof of the signal being sent on the source chain. |

### _key

```solidity
function _key(address sender, bytes32 signal) private pure returns (bytes32)
```

Generate the storage key for a signal.

