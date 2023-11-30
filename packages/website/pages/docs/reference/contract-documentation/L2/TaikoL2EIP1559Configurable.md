---
title: TaikoL2EIP1559Configurable
---

## TaikoL2EIP1559Configurable

Taiko L2 with a setter to change EIP-1559 configurations and states.

### ConfigAndExcessChanged

```solidity
event ConfigAndExcessChanged(struct TaikoL2.Config config, uint64 gasExcess)
```

### L2_INVALID_CONFIG

```solidity
error L2_INVALID_CONFIG()
```

### setConfigAndExcess

```solidity
function setConfigAndExcess(struct TaikoL2.Config config, uint64 newGasExcess) external virtual
```

Sets EIP1559 configuration and gas excess.

#### Parameters

| Name         | Type                  | Description             |
| ------------ | --------------------- | ----------------------- |
| config       | struct TaikoL2.Config | The new EIP1559 config. |
| newGasExcess | uint64                | The new gas excess      |

### getConfig

```solidity
function getConfig() public view returns (struct TaikoL2.Config)
```

Returns EIP1559 related configurations

---

## title: ProxiedTaikoL2EIP1559Configurable

## ProxiedTaikoL2EIP1559Configurable

Proxied version of the TaikoL2EIP1559Configurable contract.
