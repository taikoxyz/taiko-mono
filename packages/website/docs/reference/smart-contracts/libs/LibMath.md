## LibMath

This library offers additional math functions for uint256.

### min

```solidity
function min(uint256 a, uint256 b) internal pure returns (uint256)
```

Returns the smaller value between the two given values.

#### Parameters

| Name | Type    | Description                      |
| ---- | ------- | -------------------------------- |
| a    | uint256 | One of the two values.           |
| b    | uint256 | The other one of the two values. |

#### Return Values

| Name | Type    | Description        |
| ---- | ------- | ------------------ |
| [0]  | uint256 | The smaller value. |

### max

```solidity
function max(uint256 a, uint256 b) internal pure returns (uint256)
```

Returns the larger value between the two given values.

#### Parameters

| Name | Type    | Description                      |
| ---- | ------- | -------------------------------- |
| a    | uint256 | One of the two values.           |
| b    | uint256 | The other one of the two values. |

#### Return Values

| Name | Type    | Description       |
| ---- | ------- | ----------------- |
| [0]  | uint256 | The larger value. |

### divceil

```solidity
function divceil(uint256 a, uint256 b) internal pure returns (uint256 c)
```

Returns the ceil value.

#### Parameters

| Name | Type    | Description      |
| ---- | ------- | ---------------- |
| a    | uint256 | The numerator.   |
| b    | uint256 | The denominator. |

#### Return Values

| Name | Type    | Description              |
| ---- | ------- | ------------------------ |
| c    | uint256 | The ceil value of (a/b). |

### sqrt

```solidity
function sqrt(uint256 y) internal pure returns (uint256 z)
```

Returns the square root of a given uint256.
This method is taken from:
https://github.com/Uniswap/v2-core/blob/v1.0.1/contracts/libraries/Math.sol.
It is based on the Babylonian method:
https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method).

#### Parameters

| Name | Type    | Description       |
| ---- | ------- | ----------------- |
| y    | uint256 | The given number. |

#### Return Values

| Name | Type    | Description           |
| ---- | ------- | --------------------- |
| z    | uint256 | The square root of y. |
