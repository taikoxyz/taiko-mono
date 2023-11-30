---
title: GuardianVerifier
---

## GuardianVerifier

### PERMISSION_DENIED

```solidity
error PERMISSION_DENIED()
```

### init

```solidity
function init(address _addressManager) external
```

Initializes the contract with the provided address manager.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _addressManager | address | The address of the address manager contract. |

### verifyProof

```solidity
function verifyProof(struct IVerifier.Context ctx, struct TaikoData.Transition, struct TaikoData.TierProof) external view
```

---
title: ProxiedGuardianVerifier
---

## ProxiedGuardianVerifier

Proxied version of the parent contract.

