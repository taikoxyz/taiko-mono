---
title: ProofVerifier
---

## ProofVerifier

See the documentation in {IProofVerifier}.

### L1_INVALID_PROOF

```solidity
error L1_INVALID_PROOF()
```

### init

```solidity
function init(address _addressManager) external
```

Initializes the contract with the provided address manager.

#### Parameters

| Name             | Type    | Description                                  |
| ---------------- | ------- | -------------------------------------------- |
| \_addressManager | address | The address of the address manager contract. |

### verifyProofs

```solidity
function verifyProofs(uint64, bytes blockProofs, bytes32 instance) external view
```

Verify the given proof(s) for the given blockId. This function
should revert if the verification fails.

#### Parameters

| Name        | Type    | Description                                                                               |
| ----------- | ------- | ----------------------------------------------------------------------------------------- |
|             | uint64  |                                                                                           |
| blockProofs | bytes   | Raw bytes representing the proof(s).                                                      |
| instance    | bytes32 | Hashed evidence & config data. If set to zero, proof is assumed to be from oracle prover. |

---

## title: ProxiedProofVerifier

## ProxiedProofVerifier

Proxied version of the parent contract.
