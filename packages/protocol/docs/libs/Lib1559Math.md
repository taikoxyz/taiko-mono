## Lib1559Math

This library offers two functions for EIP-1559-style math.
     See more at https://dankradfeist.de/ethereum/2022/03/16/exponential-eip1559.html

### adjustTarget

```solidity
function adjustTarget(uint256 prevTarget, uint256 prevMeasured, uint256 T, uint256 A) internal pure returns (uint256 nextTarget)
```

Calculates and returns the next round's target value using the equation below:

     `nextTarget = prevTarget * ((A-1) * T + prevMeasured / (A * T)`
     which implies if `prevMeasured` is larger than `T`, `nextTarget` will
     become larger than `prevTarget`.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| prevTarget | uint256 | The previous round's target value. |
| prevMeasured | uint256 | The previous round's measured value. It must be in the same unit as `T`. |
| T | uint256 | The base target value. It must be in the same unit as `prevMeasured`. |
| A | uint256 | The adjustment factor. Bigger values change the next round's target more slowly. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nextTarget | uint256 | The next round's target value. |

### adjustTargetReverse

```solidity
function adjustTargetReverse(uint256 prevTarget, uint256 prevMeasured, uint256 T, uint256 A) internal pure returns (uint256 nextTarget)
```

Calculates and returns the next round's target value using the equation below:

     `nextTarget = prevTarget * A * T / ((A-1) * T + prevMeasured)`
     which implies if `prevMeasured` is larger than `T`, `nextTarget` will
     become smaller than `prevTarget`.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| prevTarget | uint256 | The previous round's target value. |
| prevMeasured | uint256 | The previous round's measured value. It must be in the same unit as `T`. |
| T | uint256 | The base target value. It must be in the same unit as `prevMeasured`. |
| A | uint256 | The adjustment factor. Bigger values change the next round's target more slowly. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nextTarget | uint256 | The next round's target value. |

