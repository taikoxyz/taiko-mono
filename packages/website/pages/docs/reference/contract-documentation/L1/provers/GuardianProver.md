---
title: GuardianProver
---

## GuardianProver

_Labeled in AddressResolver as "guardian_prover"_

### NUM_GUARDIANS

```solidity
uint256 NUM_GUARDIANS
```

### REQUIRED_GUARDIANS

```solidity
uint256 REQUIRED_GUARDIANS
```

### guardianIds

```solidity
mapping(address => uint256) guardianIds
```

### approvals

```solidity
mapping(bytes32 => uint256) approvals
```

### guardians

```solidity
address[5] guardians
```

### GuardiansUpdated

```solidity
event GuardiansUpdated(address[5])
```

### Approved

```solidity
event Approved(uint64 blockId, uint256 approvalBits, bool proofSubmitted)
```

### INVALID_GUARDIAN

```solidity
error INVALID_GUARDIAN()
```

### INVALID_GUARDIAN_SET

```solidity
error INVALID_GUARDIAN_SET()
```

### INVALID_PROOF

```solidity
error INVALID_PROOF()
```

### PROVING_FAILED

```solidity
error PROVING_FAILED()
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

### setGuardians

```solidity
function setGuardians(address[5] _guardians) external
```

Set the set of guardians

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _guardians | address[5] | The new set of guardians |

### approve

```solidity
function approve(struct TaikoData.BlockMetadata meta, struct TaikoData.Transition tran, struct TaikoData.TierProof proof) external
```

_Called by guardians to approve a guardian proof_

---
title: ProxiedGuardianProver
---

## ProxiedGuardianProver

Proxied version of the parent contract.

