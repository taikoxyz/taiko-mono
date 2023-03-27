## IProofVerifier

### verifyZKP

```solidity
function verifyZKP(string verifierId, bytes zkproof, bytes32 instance) external view returns (bool verified)
```

### verifyMKP

```solidity
function verifyMKP(bytes key, bytes value, bytes proof, bytes32 root) external pure returns (bool verified)
```

## ProofVerifier

### init

```solidity
function init(address addressManager) external
```

### verifyZKP

```solidity
function verifyZKP(string verifierId, bytes zkproof, bytes32 instance) external view returns (bool)
```

### verifyMKP

```solidity
function verifyMKP(bytes key, bytes value, bytes proof, bytes32 root) external pure returns (bool)
```
