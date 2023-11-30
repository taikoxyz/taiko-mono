---
title: SgxAndZkVerifier
---

## SgxAndZkVerifier

See the documentation in {IVerifier}.

### SGX_PROOF_SIZE

```solidity
uint8 SGX_PROOF_SIZE
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
function verifyProof(struct IVerifier.Context ctx, struct TaikoData.Transition tran, struct TaikoData.TierProof proof) external
```

---
title: ProxiedSgxAndZkVerifier
---

## ProxiedSgxAndZkVerifier

Proxied version of the parent contract.

