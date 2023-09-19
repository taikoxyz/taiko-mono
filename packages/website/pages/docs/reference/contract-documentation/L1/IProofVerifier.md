---
title: IProofVerifier
---

## IProofVerifier

Contract that is responsible for verifying proofs.

### verifyProofs

```solidity
function verifyProofs(uint64 blockId, bytes blockProofs, bytes32 instance) external
```

Verify the given proof(s) for the given blockId. This function
should revert if the verification fails.

#### Parameters

| Name        | Type    | Description                                                                               |
| ----------- | ------- | ----------------------------------------------------------------------------------------- |
| blockId     | uint64  | Unique identifier for the block.                                                          |
| blockProofs | bytes   | Raw bytes representing the proof(s).                                                      |
| instance    | bytes32 | Hashed evidence & config data. If set to zero, proof is assumed to be from oracle prover. |
