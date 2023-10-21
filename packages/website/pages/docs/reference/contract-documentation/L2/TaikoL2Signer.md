---
title: TaikoL2Signer
---

## TaikoL2Signer

This contract allows for signing operations required on Taiko L2.

_It uses precomputed values for optimized signature creation._

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

Signs the provided digest using the golden touch mechanism.

#### Parameters

| Name   | Type    | Description                              |
| ------ | ------- | ---------------------------------------- |
| digest | bytes32 | The hash of the data to be signed.       |
| k      | uint8   | The selector for signature optimization. |

#### Return Values

| Name | Type    | Description                       |
| ---- | ------- | --------------------------------- |
| v    | uint8   | The recovery id.                  |
| r    | uint256 | The r component of the signature. |
| s    | uint256 | The s component of the signature. |
