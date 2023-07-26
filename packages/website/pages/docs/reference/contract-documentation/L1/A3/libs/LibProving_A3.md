---
title: LibProving_A3
---

## LibProving_A3

### BlockProven

```solidity
event BlockProven(uint256 id, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover, uint32 parentGasUsed)
```

### L1_ALREADY_PROVEN

```solidity
error L1_ALREADY_PROVEN()
```

### L1_BLOCK_ID

```solidity
error L1_BLOCK_ID()
```

### L1_EVIDENCE_MISMATCH

```solidity
error L1_EVIDENCE_MISMATCH(bytes32 expected, bytes32 actual)
```

### L1_FORK_CHOICE_NOT_FOUND

```solidity
error L1_FORK_CHOICE_NOT_FOUND()
```

### L1_INVALID_EVIDENCE

```solidity
error L1_INVALID_EVIDENCE()
```

### L1_INVALID_PROOF

```solidity
error L1_INVALID_PROOF()
```

### L1_INVALID_PROOF_OVERWRITE

```solidity
error L1_INVALID_PROOF_OVERWRITE()
```

### L1_NOT_SPECIAL_PROVER

```solidity
error L1_NOT_SPECIAL_PROVER()
```

### L1_ORACLE_PROVER_DISABLED

```solidity
error L1_ORACLE_PROVER_DISABLED()
```

### L1_SAME_PROOF

```solidity
error L1_SAME_PROOF()
```

### L1_SYSTEM_PROVER_DISABLED

```solidity
error L1_SYSTEM_PROVER_DISABLED()
```

### L1_SYSTEM_PROVER_PROHIBITED

```solidity
error L1_SYSTEM_PROVER_PROHIBITED()
```

### proveBlock

```solidity
function proveBlock(struct TaikoData.State state, struct TaikoData.Config config, contract AddressResolver resolver, uint256 blockId, struct TaikoData.BlockEvidence evidence) internal
```

### getForkChoice

```solidity
function getForkChoice(struct TaikoData.State state, struct TaikoData.Config config, uint256 blockId, bytes32 parentHash, uint32 parentGasUsed) internal view returns (struct TaikoData.ForkChoice fc)
```

