---
title: IVerifier
---

## IVerifier

Defines the function that handles proof verification.

### Context

```solidity
struct Context {
  bytes32 metaHash;
  bytes32 blobHash;
  address prover;
  uint64 blockId;
  bool isContesting;
  bool blobUsed;
}
```

### verifyProof

```solidity
function verifyProof(struct IVerifier.Context ctx, struct TaikoData.Transition tran, struct TaikoData.TierProof proof) external
```

