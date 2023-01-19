---
title: IProofVerifier
---

## IProofVerifier

### verifyZKP

```solidity
function verifyZKP(bytes verificationKey, bytes zkproof, bytes32 blockHash, address prover, bytes32 txListHash) external pure returns (bool verified)
```

### verifyMKP

```solidity
function verifyMKP(bytes key, bytes value, bytes proof, bytes32 root) external pure returns (bool verified)
```

---

## title: ProofVerifier

## ProofVerifier

### verifyZKP

```solidity
function verifyZKP(bytes verificationKey, bytes zkproof, bytes32 blockHash, address prover, bytes32 txListHash) external pure returns (bool)
```

### verifyMKP

```solidity
function verifyMKP(bytes key, bytes value, bytes proof, bytes32 root) external pure returns (bool)
```
