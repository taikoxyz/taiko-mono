---
title: PseZkVerifier
---

## PseZkVerifier

See the documentation in {IVerifier}.

### PointProof

```solidity
struct PointProof {
  bytes32 txListHash;
  uint256 pointValue;
  bytes1[48] pointCommitment;
  bytes1[48] pointProof;
}
```

### ZkEvmProof

```solidity
struct ZkEvmProof {
  uint16 verifierId;
  bytes zkp;
  bytes pointProof;
}
```

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

| Name | Type | Description |
| ---- | ---- | ----------- |
| _addressManager | address | The address of the address manager contract. |

### verifyProof

```solidity
function verifyProof(struct IVerifier.Context ctx, struct TaikoData.Transition tran, struct TaikoData.TierProof proof) external view
```

### calc4844PointEvalX

```solidity
function calc4844PointEvalX(bytes32 blobHash, bytes32 txListHash) public pure returns (uint256)
```

### calcInstance

```solidity
function calcInstance(struct TaikoData.Transition tran, address prover, bytes32 metaHash, bytes32 txListHash, uint256 pointValue) public pure returns (bytes32 instance)
```

### getVerifierName

```solidity
function getVerifierName(uint16 id) public pure returns (bytes32)
```

---
title: ProxiedPseZkVerifier
---

## ProxiedPseZkVerifier

Proxied version of the parent contract.

