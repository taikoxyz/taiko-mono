---
title: IVerifier
---

## IVerifier

A contract that is responsible for verifying proofs. Implementing this interface is required by different (tier) verifiers. This is a key part of our new multi-proof system.

For example the `PseZkVerifier.sol` is a verifier tied to a tier called `TIER_PSE_ZKEVM` and will contain all the necessary code to verify a specific proof tied to that given tier.

### verifyProofs

```solidity
function verifyProofs(uint64 blockId, address prover, bool isContesting, TaikoData.BlockEvidence memory evidence) external
```

Verify the given proof(s) for the given blockId. This function
should revert if the verification fails.

#### Parameters

| Name         | Type                    | Description                                                                     |
| ------------ | ----------------------- | ------------------------------------------------------------------------------- |
| blockId      | uint64                  | Unique identifier for the block.                                                |
| prover       | address                 | Address of the prover.                                                          |
| isContesting | bool                    | A boolean to indicate if this is an actual proof or only a contest (challenge). |
| evidence     | TaikoData.BlockEvidence | Evidence data to be able to verify the proofs.                                  |
