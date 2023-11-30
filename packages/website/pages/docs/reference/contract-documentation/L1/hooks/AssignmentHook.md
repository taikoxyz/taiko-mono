---
title: AssignmentHook
---

## AssignmentHook

### ProverAssignment

```solidity
struct ProverAssignment {
  address feeToken;
  uint64 expiry;
  uint64 maxBlockId;
  uint64 maxProposedIn;
  bytes32 metaHash;
  struct TaikoData.TierFee[] tierFees;
  bytes signature;
}
```

### Input

```solidity
struct Input {
  struct AssignmentHook.ProverAssignment assignment;
  uint256 tip;
}
```

### MAX_GAS_PAYING_PROVER

```solidity
uint256 MAX_GAS_PAYING_PROVER
```

### BlockAssigned

```solidity
event BlockAssigned(address assignedProver, struct TaikoData.BlockMetadata meta, struct AssignmentHook.ProverAssignment assignment)
```

### HOOK_ASSIGNMENT_EXPIRED

```solidity
error HOOK_ASSIGNMENT_EXPIRED()
```

### HOOK_ASSIGNMENT_INVALID_SIG

```solidity
error HOOK_ASSIGNMENT_INVALID_SIG()
```

### HOOK_ASSIGNMENT_INSUFFICIENT_FEE

```solidity
error HOOK_ASSIGNMENT_INSUFFICIENT_FEE()
```

### HOOK_TIER_NOT_FOUND

```solidity
error HOOK_TIER_NOT_FOUND()
```

### init

```solidity
function init(address _addressManager) external
```

### onBlockProposed

```solidity
function onBlockProposed(struct TaikoData.Block blk, struct TaikoData.BlockMetadata meta, bytes data) external payable
```

### hashAssignment

```solidity
function hashAssignment(struct AssignmentHook.ProverAssignment assignment, address taikoAddress, bytes32 blobHash) public pure returns (bytes32)
```

---
title: ProxiedAssignmentHook
---

## ProxiedAssignmentHook

Proxied version of the parent contract.

