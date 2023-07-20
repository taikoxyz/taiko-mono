---
title: ProofVerifier
---

## ProofVerifier

### structEncoding

```solidity
bytes structEncoding
```

### TypedProof

```solidity
struct TypedProof {
  uint16 verifierId;
  bytes32 proofType;
  bytes proof;
}
```

### init

```solidity
function init(address _addressManager) external
```

### verifyProofs

```solidity
function verifyProofs(bytes blockProofs) external view
```

Verifying proof via the ProofVerifier contract

#### Parameters

| Name        | Type  | Description           |
| ----------- | ----- | --------------------- |
| blockProofs | bytes | Raw bytes of proof(s) |

---

## title: ProxiedProofVerifier

## ProxiedProofVerifier
