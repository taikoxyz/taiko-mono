---
title: TaikoL2Signer
---

## TaikoL2Signer

### GOLDEN_TOUCH_ADDRESS

```solidity
address GOLDEN_TOUCH_ADDRESS
```

### GOLDEN_TOUCH_PRIVATEKEY

```solidity
uint256 GOLDEN_TOUCH_PRIVATEKEY
```

### L2_INVALID_GOLDEN_TOUCH_K

```solidity
error L2_INVALID_GOLDEN_TOUCH_K()
```

### signAnchor

```solidity
function signAnchor(bytes32 digest, uint8 k) public view returns (uint8 v, uint256 r, uint256 s)
```
