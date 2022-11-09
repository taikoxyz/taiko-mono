// SPDX-License-Identifier: GPLv3
// Taken from https://github.com/SimonSuckut/Solidity_Uint512/blob/main/contracts/Uint512.sol

pragma solidity ^0.8.9;

library Uint512 {
    /// @notice Calculates the product of two uint256
    /// @dev Used the chinese remainder theoreme
    /// @param a A uint256 representing the first factor.
    /// @param b A uint256 representing the second factor.
    /// @return r0 The result as an uint512. r0 contains the lower bits.
    /// @return r1 The higher bits of the result.
    function mul256x256(
        uint256 a,
        uint256 b
    ) public pure returns (uint256 r0, uint256 r1) {
        assembly {
            let mm := mulmod(a, b, not(0))
            r0 := mul(a, b)
            r1 := sub(sub(mm, r0), lt(mm, r0))
        }
    }

    /// @notice Calculates the product of two uint512 and uint256
    /// @dev Used the chinese remainder theoreme
    /// @param a0 A uint256 representing lower bits of the first factor.
    /// @param a1 A uint256 representing higher bits of the first factor.
    /// @param b A uint256 representing the second factor.
    /// @return r0 The result as an uint512. r0 contains the lower bits.
    /// @return r1 The higher bits of the result.
    function mul512x256(
        uint256 a0,
        uint256 a1,
        uint256 b
    ) public pure returns (uint256 r0, uint256 r1) {
        assembly {
            let mm := mulmod(a0, b, not(0))
            r0 := mul(a0, b)
            r1 := sub(sub(mm, r0), lt(mm, r0))
            r1 := add(r1, mul(a1, b))
        }
    }

    /// @notice Calculates the product and remainder of two uint256
    /// @dev Used the chinese remainder theoreme
    /// @param a A uint256 representing the first factor.
    /// @param b A uint256 representing the second factor.
    /// @return r0 The result as an uint512. r0 contains the lower bits.
    /// @return r1 The higher bits of the result.
    /// @return r2 The remainder.
    function mulMod256x256(
        uint256 a,
        uint256 b,
        uint256 c
    ) public pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly {
            let mm := mulmod(a, b, not(0))
            r0 := mul(a, b)
            r1 := sub(sub(mm, r0), lt(mm, r0))
            r2 := mulmod(a, b, c)
        }
    }

    /// @notice Calculates the difference of two uint512
    /// @param a0 A uint256 representing the lower bits of the first addend.
    /// @param a1 A uint256 representing the higher bits of the first addend.
    /// @param b0 A uint256 representing the lower bits of the seccond addend.
    /// @param b1 A uint256 representing the higher bits of the seccond addend.
    /// @return r0 The result as an uint512. r0 contains the lower bits.
    /// @return r1 The higher bits of the result.
    function add512x512(
        uint256 a0,
        uint256 a1,
        uint256 b0,
        uint256 b1
    ) public pure returns (uint256 r0, uint256 r1) {
        assembly {
            r0 := add(a0, b0)
            r1 := add(add(a1, b1), lt(r0, a0))
        }
    }

    /// @notice Calculates the difference of two uint512
    /// @param a0 A uint256 representing the lower bits of the minuend.
    /// @param a1 A uint256 representing the higher bits of the minuend.
    /// @param b0 A uint256 representing the lower bits of the subtrahend.
    /// @param b1 A uint256 representing the higher bits of the subtrahend.
    /// @return r0 The result as an uint512. r0 contains the lower bits.
    /// @return r1 The higher bits of the result.
    function sub512x512(
        uint256 a0,
        uint256 a1,
        uint256 b0,
        uint256 b1
    ) public pure returns (uint256 r0, uint256 r1) {
        assembly {
            r0 := sub(a0, b0)
            r1 := sub(sub(a1, b1), lt(a0, b0))
        }
    }

    /// @notice Calculates the division of a 512 bit unsigned integer by a 256 bit integer. It
    /// requires the remainder to be known and the result must fit in a 256 bit integer.
    /// @dev For a detailed explaination see:
    /// https://www.researchgate.net/publication/235765881_Efficient_long_division_via_Montgomery_multiply.
    /// @param a0 A uint256 representing the low bits of the nominator.
    /// @param a1 A uint256 representing the high bits of the nominator.
    /// @param b A uint256 representing the denominator.
    /// @param rem A uint256 representing the remainder of the devision. The algorithm is cheaper to compute if the remainder is known. The remainder often be retreived cheaply using the mulmod and addmod operations.
    /// @return r The result as an uint256. Result must have at most 256 bit.
    function divRem512x256(
        uint256 a0,
        uint256 a1,
        uint256 b,
        uint256 rem
    ) public pure returns (uint256 r) {
        assembly {
            // subtract the remainder
            a1 := sub(a1, lt(a0, rem))
            a0 := sub(a0, rem)

            // The integer space mod 2**256 is not an abilian group on the multiplication operation. In fact the
            // multiplicative inserve only exists for odd numbers. The denominator gets shifted right until the
            // least significant bit is 1. To do this we find the biggest power of 2 that devides the denominator.
            let pow := and(sub(0, b), b)
            b := div(b, pow)

            // Also shift the nominator. We only shift a0 and the lower bits of a1 which are transfered into a0
            // by the shift operation. a1 no longer required for the calculation. This might sound odd, but in
            // fact under the conditions that r < 2**255 and a / b = (r * a) + rem with rem = 0 the value of a1
            // is uniquely identified. Thus the value is not needed for the calculation.
            a0 := div(a0, pow)
            pow := add(div(sub(0, pow), pow), 1)
            a0 := or(a0, mul(a1, pow))
        }

        // if a1 is zero after the shifting, a single word division is sufficient
        if (a1 == 0) return a0 / b;

        assembly {
            // Calculate the multiplicative inverse mod 2**256 of b. See the paper for details.
            let inv := xor(mul(3, b), 2)
            inv := mul(inv, sub(2, mul(b, inv)))
            inv := mul(inv, sub(2, mul(b, inv)))
            inv := mul(inv, sub(2, mul(b, inv)))
            inv := mul(inv, sub(2, mul(b, inv)))
            inv := mul(inv, sub(2, mul(b, inv)))
            inv := mul(inv, sub(2, mul(b, inv)))

            r := mul(a0, inv)
        }
    }

    /// @notice Calculates the division of a 512 bit unsigned integer by a 256 bit integer. It
    /// requires the result to fit in a 256 bit integer.
    /// @dev For a detailed explaination see:
    /// https://www.researchgate.net/publication/235765881_Efficient_long_division_via_Montgomery_multiply.
    /// @param a0 A uint256 representing the low bits of the nominator.
    /// @param a1 A uint256 representing the high bits of the nominator.
    /// @param b A uint256 representing the denominator.
    /// @return r The result as an uint256. Result must have at most 256 bit.
    function div512x256(
        uint256 a0,
        uint256 a1,
        uint256 b
    ) public pure returns (uint256 r) {
        assembly {
            // calculate the remainder
            let rem := mulmod(a1, not(0), b)
            rem := addmod(rem, a1, b)
            rem := addmod(rem, a0, b)

            // subtract the remainder
            a1 := sub(a1, lt(a0, rem))
            a0 := sub(a0, rem)

            // The integer space mod 2**256 is not an abilian group on the multiplication operation. In fact the
            // multiplicative inserve only exists for odd numbers. The denominator gets shifted right until the
            // least significant bit is 1. To do this we find the biggest power of 2 that devides the denominator.
            let pow := and(sub(0, b), b)
            b := div(b, pow)

            // Also shift the nominator. We only shift a0 and the lower bits of a1 which are transfered into a0
            // by the shift operation. a1 no longer required for the calculation. This might sound odd, but in
            // fact under the conditions that r < 2**255 and a / b = (r * a) + rem with rem = 0 the value of a1
            // is uniquely identified. Thus the value is not needed for the calculation.
            a0 := div(a0, pow)
            pow := add(div(sub(0, pow), pow), 1)
            a0 := or(a0, mul(a1, pow))
        }

        // if a1 is zero after the shifting, a single word division is sufficient
        if (a1 == 0) return a0 / b;

        assembly {
            // Calculate the multiplicative inverse mod 2**256 of b. See the paper for details.
            let inv := xor(mul(3, b), 2)
            inv := mul(inv, sub(2, mul(b, inv)))
            inv := mul(inv, sub(2, mul(b, inv)))
            inv := mul(inv, sub(2, mul(b, inv)))
            inv := mul(inv, sub(2, mul(b, inv)))
            inv := mul(inv, sub(2, mul(b, inv)))
            inv := mul(inv, sub(2, mul(b, inv)))

            r := mul(a0, inv)
        }
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    /// @param x The uint256 number for which to calculate the square root.
    /// @return s The square root as an uint256.
    function sqrt256(uint256 x) public pure returns (uint256 s) {
        if (x == 0) return 0;

        assembly {
            s := 1

            let xAux := x

            let cmp := or(
                gt(xAux, 0x100000000000000000000000000000000),
                eq(xAux, 0x100000000000000000000000000000000)
            )
            xAux := sar(mul(cmp, 128), xAux)
            s := shl(mul(cmp, 64), s)

            cmp := or(
                gt(xAux, 0x10000000000000000),
                eq(xAux, 0x10000000000000000)
            )
            xAux := sar(mul(cmp, 64), xAux)
            s := shl(mul(cmp, 32), s)

            cmp := or(gt(xAux, 0x100000000), eq(xAux, 0x100000000))
            xAux := sar(mul(cmp, 32), xAux)
            s := shl(mul(cmp, 16), s)

            cmp := or(gt(xAux, 0x10000), eq(xAux, 0x10000))
            xAux := sar(mul(cmp, 16), xAux)
            s := shl(mul(cmp, 8), s)

            cmp := or(gt(xAux, 0x100), eq(xAux, 0x100))
            xAux := sar(mul(cmp, 8), xAux)
            s := shl(mul(cmp, 4), s)

            cmp := or(gt(xAux, 0x10), eq(xAux, 0x10))
            xAux := sar(mul(cmp, 4), xAux)
            s := shl(mul(cmp, 2), s)

            s := shl(mul(or(gt(xAux, 0x8), eq(xAux, 0x8)), 2), s)
        }

        unchecked {
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            s = (s + x / s) >> 1;
            uint256 roundedDownResult = x / s;
            return s >= roundedDownResult ? roundedDownResult : s;
        }
    }

    /// @notice Calculates the square root of a 512 bit unsigned integer, rounding down.
    /// @dev Uses the Karatsuba Square Root method. See https://hal.inria.fr/inria-00072854/document for details.
    /// @param a0 A uint256 representing the low bits of the input.
    /// @param a1 A uint256 representing the high bits of the input.
    /// @return s The square root as an uint256. Result has at most 256 bit.
    function sqrt512(uint256 a0, uint256 a1) public pure returns (uint256 s) {
        // A simple 256 bit square root is sufficient
        if (a1 == 0) return sqrt256(a0);

        // The used algorithm has the pre-condition a1 >= 2**254
        uint256 shift;

        assembly {
            let digits := mul(lt(a1, 0x100000000000000000000000000000000), 128)
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(
                lt(a1, 0x1000000000000000000000000000000000000000000000000),
                64
            )
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(
                lt(
                    a1,
                    0x100000000000000000000000000000000000000000000000000000000
                ),
                32
            )
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(
                lt(
                    a1,
                    0x1000000000000000000000000000000000000000000000000000000000000
                ),
                16
            )
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(
                lt(
                    a1,
                    0x100000000000000000000000000000000000000000000000000000000000000
                ),
                8
            )
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(
                lt(
                    a1,
                    0x1000000000000000000000000000000000000000000000000000000000000000
                ),
                4
            )
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            digits := mul(
                lt(
                    a1,
                    0x4000000000000000000000000000000000000000000000000000000000000000
                ),
                2
            )
            a1 := shl(digits, a1)
            shift := add(shift, digits)

            a1 := or(a1, shr(sub(256, shift), a0))
            a0 := shl(shift, a0)
        }

        uint256 sp = sqrt256(a1);
        uint256 rp = a1 - (sp * sp);

        uint256 nom;
        uint256 denom;
        uint256 u;
        uint256 q;

        assembly {
            nom := or(shl(128, rp), shr(128, a0))
            denom := shl(1, sp)
            q := div(nom, denom)
            u := mod(nom, denom)

            // The nominator can be bigger than 2**256. We know that rp < (sp+1) * (sp+1). As sp can be
            // at most floor(sqrt(2**256 - 1)) we can conclude that the nominator has at most 513 bits
            // set. An expensive 512x256 bit division can be avoided by treating the bit at position 513 manually
            let carry := shr(128, rp)
            let x := mul(
                carry,
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            )
            q := add(q, div(x, denom))
            u := add(u, add(carry, mod(x, denom)))
            q := add(q, div(u, denom))
            u := mod(u, denom)
        }

        unchecked {
            s = (sp << 128) + q;

            uint256 rl = ((u << 128) |
                (a0 & 0xffffffffffffffffffffffffffffffff));
            uint256 rr = q * q;

            if (
                (q >> 128) > (u >> 128) ||
                (((q >> 128) == (u >> 128)) && rl < rr)
            ) {
                s = s - 1;
            }

            return s >> (shift / 2);
        }
    }
}
