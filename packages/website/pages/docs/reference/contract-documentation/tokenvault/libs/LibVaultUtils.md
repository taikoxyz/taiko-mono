---
title: LibVaultUtils
---

## LibVaultUtils

### VAULT_INVALID_SENDER

```solidity
error VAULT_INVALID_SENDER()
```

Thrown when the sender in a message context is invalid.
This could happen if the sender isn't the expected token vault on the
source chain.

### deployProxy

```solidity
function deployProxy(address implementation, address owner, bytes initializationData) external returns (address proxy)
```

_Deploys a contract (via proxy)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| implementation | address | The new implementation address |
| owner | address | The owner of the proxy admin contract |
| initializationData | bytes | Data for the initialization |

### checkValidContext

```solidity
function checkValidContext(bytes32 validSender, address resolver) external view returns (struct IBridge.Context ctx)
```

_Checks if context is valid_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| validSender | bytes32 | The valid sender to be allowed |
| resolver | address | The address of the resolver |

