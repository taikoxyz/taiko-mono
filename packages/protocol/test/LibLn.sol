// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Taken from: https://github.com/recmo/experiment-solexp/blob/main/src/FixedPointMathLib.sol
import {LibFixedPointMath} from "../contracts/thirdparty/LibFixedPointMath.sol";

library LibLn {
    error Overflow();
    error LnNegativeUndefined();

    // Integer log2 (alternative implementation)
    // @returns floor(log2(x)) if x is nonzero, otherwise 0.
    // Consumes 317 gas. This could have been an 3 gas EVM opcode though.
    function ilog2_alt(uint256 x) internal pure returns (uint256 r) {
        unchecked {
            // Repeat first zero all the way to the right
            x |= x >> 1;
            x |= x >> 2;
            x |= x >> 4;
            x |= x >> 8;
            x |= x >> 16;
            x |= x >> 32;
            x |= x >> 64;
            x |= x >> 128;

            // Count 32 bit chunks
            r = x & 0x100000001000000010000000100000001000000010000000100000001;
            r *= 0x20000000200000002000000020000000200000002000000020;
            r >>= 224;

            // Extract highest bit
            x ^= x >> 1;

            // Copy to lowest 32 bit chunk
            x |= x >> 32;
            x |= x >> 64;
            x |= x >> 128;
            // No need to clear the other chunks

            // Map to 0-31 using the B(2, 5) de Bruijn sequence 0x077CB531.
            // See <https://en.wikipedia.org/wiki/De_Bruijn_sequence#Finding_least-_or_most-significant_set_bit_in_a_word>
            x = ((x * 0x077CB531) >> 27) & 0x1f;

            // Use a bytes32 32 entry lookup table
            assembly {
                // Need assembly here because solidity introduces an uncessary bounds
                // check.
                r :=
                    add(r, byte(x, 0x11c021d0e18031e16140f191104081f1b0d17151310071a0c12060b050a09))
            }
        }
    }

    // Integer log2
    // @returns floor(log2(x)) if x is nonzero, otherwise 0. This is the same
    //          as the location of the highest set bit.
    // Consumes 232 gas. This could have been an 3 gas EVM opcode though.
    function ilog2(uint256 x) internal pure returns (uint256 r) {
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            r := or(r, shl(2, lt(0xf, shr(r, x))))
            r := or(r, shl(1, lt(0x3, shr(r, x))))
            r := or(r, lt(0x1, shr(r, x)))
        }
    }

    function ln_pub(int256 x) public pure returns (int256 r) {
        return ln(x);
    }

    // Computes ln(x) in 1e18 fixed point.
    // Reverts if x is negative or zero.
    // Consumes 670 gas.
    function ln(int256 x) internal pure returns (int256 r) {
        unchecked {
            if (x < 1) {
                if (x < 0) revert LnNegativeUndefined();
                revert Overflow();
            }

            // We want to convert x from 10**18 fixed point to 2**96 fixed point.
            // We do this by multiplying by 2**96 / 10**18.
            // But since ln(x * C) = ln(x) + ln(C), we can simply do nothing here
            // and add ln(2**96 / 10**18) at the end.

            // Reduce range of x to (1, 2) * 2**96
            // ln(2^k * x) = k * ln(2) + ln(x)
            // Note: inlining ilog2 saves 8 gas.
            int256 k = int256(ilog2(uint256(x))) - 96;
            x <<= uint256(159 - k);
            x = int256(uint256(x) >> 159);

            // Evaluate using a (8, 8)-term rational approximation
            // p is made monic, we will multiply by a scale factor later
            int256 p = x + 3273285459638523848632254066296;
            p = ((p * x) >> 96) + 24828157081833163892658089445524;
            p = ((p * x) >> 96) + 43456485725739037958740375743393;
            p = ((p * x) >> 96) - 11111509109440967052023855526967;
            p = ((p * x) >> 96) - 45023709667254063763336534515857;
            p = ((p * x) >> 96) - 14706773417378608786704636184526;
            p = p * x - (795164235651350426258249787498 << 96);
            //emit log_named_int("p", p);
            // We leave p in 2**192 basis so we don't need to scale it back up for the division.
            // q is monic by convention
            int256 q = x + 5573035233440673466300451813936;
            q = ((q * x) >> 96) + 71694874799317883764090561454958;
            q = ((q * x) >> 96) + 283447036172924575727196451306956;
            q = ((q * x) >> 96) + 401686690394027663651624208769553;
            q = ((q * x) >> 96) + 204048457590392012362485061816622;
            q = ((q * x) >> 96) + 31853899698501571402653359427138;
            q = ((q * x) >> 96) + 909429971244387300277376558375;
            assembly {
                // Div in assembly because solidity adds a zero check despite the `unchecked`.
                // The q polynomial is known not to have zeros in the domain. (All roots are complex)
                // No scaling required because p is already 2**96 too large.
                r := sdiv(p, q)
            }
            // r is in the range (0, 0.125) * 2**96

            // Finalization, we need to
            // * multiply by the scale factor s = 5.549…
            // * add ln(2**96 / 10**18)
            // * add k * ln(2)
            // * multiply by 10**18 / 2**96 = 5**18 >> 78
            // mul s * 5e18 * 2**96, base is now 5**18 * 2**192
            r *= 1677202110996718588342820967067443963516166;
            // add ln(2) * k * 5e18 * 2**192
            r += 16597577552685614221487285958193947469193820559219878177908093499208371 * k;
            // add ln(2**96 / 10**18) * 5e18 * 2**192
            r += 600920179829731861736702779321621459595472258049074101567377883020018308;
            // base conversion: mul 2**18 / 2**192
            r >>= 174;
        }
    }

    // Computes e^x in 1e18 fixed point.
    function exp(int256 x) internal pure returns (int256 r) {
        unchecked {
            // Input x is in fixed point format, with scale factor 1/1e18.

            // When the result is < 0.5 we return zero. This happens when
            // x <= floor(log(0.5e18) * 1e18) ~ -42e18
            if (x <= -42139678854452767551) {
                return 0;
            }

            // When the result is > (2**255 - 1) / 1e18 we can not represent it
            // as an int256. This happens when x >= floor(log((2**255 -1) / 1e18) * 1e18) ~ 135.
            if (x >= 135305999368893231589) revert Overflow();

            // x is now in the range (-42, 136) * 1e18. Convert to (-42, 136) * 2**96
            // for more intermediate precision and a binary basis. This base conversion
            // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
            x = (x << 78) / 5 ** 18;

            // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers of two
            // such that exp(x) = exp(x') * 2**k, where k is an integer.
            // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
            int256 k = ((x << 96) / 54916777467707473351141471128 + 2 ** 95) >> 96;
            x = x - k * 54916777467707473351141471128;
            // k is in the range [-61, 195].

            // Evaluate using a (6, 7)-term rational approximation
            // p is made monic, we will multiply by a scale factor later
            int256 p = x + 2772001395605857295435445496992;
            p = ((p * x) >> 96) + 44335888930127919016834873520032;
            p = ((p * x) >> 96) + 398888492587501845352592340339721;
            p = ((p * x) >> 96) + 1993839819670624470859228494792842;
            p = p * x + (4385272521454847904632057985693276 << 96);
            // We leave p in 2**192 basis so we don't need to scale it back up for the division.
            // Evaluate using using Knuth's scheme from p. 491.
            int256 z = x + 750530180792738023273180420736;
            z = ((z * x) >> 96) + 32788456221302202726307501949080;
            int256 w = x - 2218138959503481824038194425854;
            w = ((w * z) >> 96) + 892943633302991980437332862907700;
            int256 q = z + w - 78174809823045304726920794422040;
            q = ((q * w) >> 96) + 4203224763890128580604056984195872;
            assembly {
                // Div in assembly because solidity adds a zero check despite the `unchecked`.
                // The q polynomial is known not to have zeros in the domain. (All roots are complex)
                // No scaling required because p is already 2**96 too large.
                r := sdiv(p, q)
            }
            // r should be in the range (0.09, 0.25) * 2**96.

            // We now need to multiply r by
            //  * the scale factor s = ~6.031367120...,
            //  * the 2**k factor from the range reduction, and
            //  * the 1e18 / 2**96 factor for base converison.
            // We do all of this at once, with an intermediate result in 2**213 basis
            // so the final right shift is always by a positive amount.
            r = int256(
                (uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k)
            );
        }
    }

    function calcInitProofTimeIssued(
        uint64 basefee,
        uint16 proofTimeTarget,
        uint8 adjustmentQuotient
    ) public pure returns (uint64 initProofTimeIssued) {
        uint256 scale = uint256(proofTimeTarget) * adjustmentQuotient;
        // ln_pub() expects 1e18 fixed format
        uint256 lnReq = scale * basefee * LibFixedPointMath.SCALING_FACTOR_1E18;
        require(lnReq <= uint256(type(int256).max));
        int256 log_result = ln_pub(int256(lnReq));
        initProofTimeIssued =
            uint64(((scale * (uint256(log_result))) / (LibFixedPointMath.SCALING_FACTOR_1E18)));
    }
}
