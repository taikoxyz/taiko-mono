---
title: BaseVault
---

## BaseVault

### VAULT_PERMISSION_DENIED

```solidity
error VAULT_PERMISSION_DENIED()
```

### onlyFromBridge

```solidity
modifier onlyFromBridge()
```

### init

```solidity
function init(address addressManager) external
```

Initializes the contract with the address manager.

#### Parameters

| Name           | Type    | Description                       |
| -------------- | ------- | --------------------------------- |
| addressManager | address | Address manager contract address. |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool)
```

Checks if the contract supports the given interface.

#### Parameters

| Name        | Type   | Description               |
| ----------- | ------ | ------------------------- |
| interfaceId | bytes4 | The interface identifier. |

#### Return Values

| Name | Type | Description                                                   |
| ---- | ---- | ------------------------------------------------------------- |
| [0]  | bool | true if the contract supports the interface, false otherwise. |

### name

```solidity
function name() public pure virtual returns (bytes32)
```

### checkProcessMessageContext

```solidity
function checkProcessMessageContext() internal view returns (struct IBridge.Context ctx)
```

### checkRecallMessageContext

```solidity
function checkRecallMessageContext() internal view returns (struct IBridge.Context ctx)
```
