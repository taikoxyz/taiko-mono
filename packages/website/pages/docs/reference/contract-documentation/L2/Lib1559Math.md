---
title: Lib1559Math
---

## Lib1559Math

_Implementation of e^(x) based bonding curve for EIP-1559
See https://ethresear.ch/t/make-eip-1559-more-like-an-amm-curve/9082_

### EIP1559_INVALID_PARAMS

```solidity
error EIP1559_INVALID_PARAMS()
```

### basefee

```solidity
function basefee(uint256 gasExcess, uint256 adjustmentFactor) internal pure returns (uint256)
```

#### Parameters

| Name             | Type    | Description                                     |
| ---------------- | ------- | ----------------------------------------------- |
| gasExcess        | uint256 |                                                 |
| adjustmentFactor | uint256 | The product of gasTarget and adjustmentQuotient |
