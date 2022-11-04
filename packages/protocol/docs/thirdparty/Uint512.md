# Uint512

## Methods

### add512x512

```solidity
function add512x512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) external pure returns (uint256 r0, uint256 r1)
```

Calculates the difference of two uint512

#### Parameters

| Name | Type    | Description                                                   |
| ---- | ------- | ------------------------------------------------------------- |
| a0   | uint256 | A uint256 representing the lower bits of the first addend.    |
| a1   | uint256 | A uint256 representing the higher bits of the first addend.   |
| b0   | uint256 | A uint256 representing the lower bits of the seccond addend.  |
| b1   | uint256 | A uint256 representing the higher bits of the seccond addend. |

#### Returns

| Name | Type    | Description                                           |
| ---- | ------- | ----------------------------------------------------- |
| r0   | uint256 | The result as an uint512. r0 contains the lower bits. |
| r1   | uint256 | The higher bits of the result.                        |

### div512x256

```solidity
function div512x256(uint256 a0, uint256 a1, uint256 b) external pure returns (uint256 r)
```

Calculates the division of a 512 bit unsigned integer by a 256 bit integer. It requires the result to fit in a 256 bit integer.

_For a detailed explaination see: https://www.researchgate.net/publication/235765881_Efficient_long_division_via_Montgomery_multiply._

#### Parameters

| Name | Type    | Description                                            |
| ---- | ------- | ------------------------------------------------------ |
| a0   | uint256 | A uint256 representing the low bits of the nominator.  |
| a1   | uint256 | A uint256 representing the high bits of the nominator. |
| b    | uint256 | A uint256 representing the denominator.                |

#### Returns

| Name | Type    | Description                                                 |
| ---- | ------- | ----------------------------------------------------------- |
| r    | uint256 | The result as an uint256. Result must have at most 256 bit. |

### divRem512x256

```solidity
function divRem512x256(uint256 a0, uint256 a1, uint256 b, uint256 rem) external pure returns (uint256 r)
```

Calculates the division of a 512 bit unsigned integer by a 256 bit integer. It requires the remainder to be known and the result must fit in a 256 bit integer.

_For a detailed explaination see: https://www.researchgate.net/publication/235765881_Efficient_long_division_via_Montgomery_multiply._

#### Parameters

| Name | Type    | Description                                                                                                                                                                                           |
| ---- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| a0   | uint256 | A uint256 representing the low bits of the nominator.                                                                                                                                                 |
| a1   | uint256 | A uint256 representing the high bits of the nominator.                                                                                                                                                |
| b    | uint256 | A uint256 representing the denominator.                                                                                                                                                               |
| rem  | uint256 | A uint256 representing the remainder of the devision. The algorithm is cheaper to compute if the remainder is known. The remainder often be retreived cheaply using the mulmod and addmod operations. |

#### Returns

| Name | Type    | Description                                                 |
| ---- | ------- | ----------------------------------------------------------- |
| r    | uint256 | The result as an uint256. Result must have at most 256 bit. |

### mul256x256

```solidity
function mul256x256(uint256 a, uint256 b) external pure returns (uint256 r0, uint256 r1)
```

Calculates the product of two uint256

_Used the chinese remainder theoreme_

#### Parameters

| Name | Type    | Description                               |
| ---- | ------- | ----------------------------------------- |
| a    | uint256 | A uint256 representing the first factor.  |
| b    | uint256 | A uint256 representing the second factor. |

#### Returns

| Name | Type    | Description                                           |
| ---- | ------- | ----------------------------------------------------- |
| r0   | uint256 | The result as an uint512. r0 contains the lower bits. |
| r1   | uint256 | The higher bits of the result.                        |

### mul512x256

```solidity
function mul512x256(uint256 a0, uint256 a1, uint256 b) external pure returns (uint256 r0, uint256 r1)
```

Calculates the product of two uint512 and uint256

_Used the chinese remainder theoreme_

#### Parameters

| Name | Type    | Description                                             |
| ---- | ------- | ------------------------------------------------------- |
| a0   | uint256 | A uint256 representing lower bits of the first factor.  |
| a1   | uint256 | A uint256 representing higher bits of the first factor. |
| b    | uint256 | A uint256 representing the second factor.               |

#### Returns

| Name | Type    | Description                                           |
| ---- | ------- | ----------------------------------------------------- |
| r0   | uint256 | The result as an uint512. r0 contains the lower bits. |
| r1   | uint256 | The higher bits of the result.                        |

### mulMod256x256

```solidity
function mulMod256x256(uint256 a, uint256 b, uint256 c) external pure returns (uint256 r0, uint256 r1, uint256 r2)
```

Calculates the product and remainder of two uint256

_Used the chinese remainder theoreme_

#### Parameters

| Name | Type    | Description                               |
| ---- | ------- | ----------------------------------------- |
| a    | uint256 | A uint256 representing the first factor.  |
| b    | uint256 | A uint256 representing the second factor. |
| c    | uint256 | undefined                                 |

#### Returns

| Name | Type    | Description                                           |
| ---- | ------- | ----------------------------------------------------- |
| r0   | uint256 | The result as an uint512. r0 contains the lower bits. |
| r1   | uint256 | The higher bits of the result.                        |
| r2   | uint256 | The remainder.                                        |

### sqrt256

```solidity
function sqrt256(uint256 x) external pure returns (uint256 s)
```

Calculates the square root of x, rounding down.

_Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method._

#### Parameters

| Name | Type    | Description                                                |
| ---- | ------- | ---------------------------------------------------------- |
| x    | uint256 | The uint256 number for which to calculate the square root. |

#### Returns

| Name | Type    | Description                    |
| ---- | ------- | ------------------------------ |
| s    | uint256 | The square root as an uint256. |

### sqrt512

```solidity
function sqrt512(uint256 a0, uint256 a1) external pure returns (uint256 s)
```

Calculates the square root of a 512 bit unsigned integer, rounding down.

_Uses the Karatsuba Square Root method. See https://hal.inria.fr/inria-00072854/document for details._

#### Parameters

| Name | Type    | Description                                        |
| ---- | ------- | -------------------------------------------------- |
| a0   | uint256 | A uint256 representing the low bits of the input.  |
| a1   | uint256 | A uint256 representing the high bits of the input. |

#### Returns

| Name | Type    | Description                                                |
| ---- | ------- | ---------------------------------------------------------- |
| s    | uint256 | The square root as an uint256. Result has at most 256 bit. |

### sub512x512

```solidity
function sub512x512(uint256 a0, uint256 a1, uint256 b0, uint256 b1) external pure returns (uint256 r0, uint256 r1)
```

Calculates the difference of two uint512

#### Parameters

| Name | Type    | Description                                               |
| ---- | ------- | --------------------------------------------------------- |
| a0   | uint256 | A uint256 representing the lower bits of the minuend.     |
| a1   | uint256 | A uint256 representing the higher bits of the minuend.    |
| b0   | uint256 | A uint256 representing the lower bits of the subtrahend.  |
| b1   | uint256 | A uint256 representing the higher bits of the subtrahend. |

#### Returns

| Name | Type    | Description                                           |
| ---- | ------- | ----------------------------------------------------- |
| r0   | uint256 | The result as an uint512. r0 contains the lower bits. |
| r1   | uint256 | The higher bits of the result.                        |
