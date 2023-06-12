// SPDX-License-Identifier: UNLICENSED
// Taken from:
// https://github.com/recmo/experiment-solexp/blob/main/src/FixedPointMathLib.sol
pragma solidity ^0.8.20;

library LibFixedPointMath {
    uint128 public constant MAX_EXP_INPUT = 135_305_999_368_893_231_588;
    uint256 public constant SCALING_FACTOR_1E18 = 1e18; // For fixed point
        // representation factor

    error Overflow();

    // Computes e^x in 1e18 fixed point.
    function exp(int256 x) internal pure returns (int256 r) {
        unchecked {
            // Input x is in fixed point format, with scale factor 1/1e18.

            // When the result is < 0.5 we return zero. This happens when
            // x <= floor(log(0.5e18) * 1e18) ~ -42e18
            if (x <= -42_139_678_854_452_767_551) {
                return 0;
            }

            // When the result is > (2**255 - 1) / 1e18 we can not represent it
            // as an int256. This happens when x >= floor(log((2**255 -1) /
            // 1e18) * 1e18) ~ 135.
            if (x >= 135_305_999_368_893_231_589) revert Overflow();

            // x is now in the range (-42, 136) * 1e18. Convert to (-42, 136) *
            // 2**96
            // for more intermediate precision and a binary basis. This base
            // conversion
            // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
            x = (x << 78) / 5 ** 18;

            // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out
            // powers of two
            // such that exp(x) = exp(x') * 2**k, where k is an integer.
            // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
            int256 k = (
                (x << 96) / 54_916_777_467_707_473_351_141_471_128 + 2 ** 95
            ) >> 96;
            x = x - k * 54_916_777_467_707_473_351_141_471_128;
            // k is in the range [-61, 195].

            // Evaluate using a (6, 7)-term rational approximation
            // p is made monic, we will multiply by a scale factor later
            int256 p = x + 2_772_001_395_605_857_295_435_445_496_992;
            p = ((p * x) >> 96) + 44_335_888_930_127_919_016_834_873_520_032;
            p = ((p * x) >> 96) + 398_888_492_587_501_845_352_592_340_339_721;
            p = ((p * x) >> 96) + 1_993_839_819_670_624_470_859_228_494_792_842;
            p = p * x + (4_385_272_521_454_847_904_632_057_985_693_276 << 96);
            // We leave p in 2**192 basis so we don't need to scale it back up
            // for the division.
            // Evaluate using using Knuth's scheme from p. 491.
            int256 z = x + 750_530_180_792_738_023_273_180_420_736;
            z = ((z * x) >> 96) + 32_788_456_221_302_202_726_307_501_949_080;
            int256 w = x - 2_218_138_959_503_481_824_038_194_425_854;
            w = ((w * z) >> 96) + 892_943_633_302_991_980_437_332_862_907_700;
            int256 q = z + w - 78_174_809_823_045_304_726_920_794_422_040;
            q = ((q * w) >> 96) + 4_203_224_763_890_128_580_604_056_984_195_872;
            assembly {
                // Div in assembly because solidity adds a zero check despite
                // the `unchecked`.
                // The q polynomial is known not to have zeros in the domain.
                // (All roots are complex)
                // No scaling required because p is already 2**96 too large.
                r := sdiv(p, q)
            }
            // r should be in the range (0.09, 0.25) * 2**96.

            // We now need to multiply r by
            //  * the scale factor s = ~6.031367120...,
            //  * the 2**k factor from the range reduction, and
            //  * the 1e18 / 2**96 factor for base converison.
            // We do all of this at once, with an intermediate result in 2**213
            // basis
            // so the final right shift is always by a positive amount.
            r = int256(
                (
                    uint256(r)
                        *
                        3_822_833_074_963_236_453_042_738_258_902_158_003_155_416_615_667
                ) >> uint256(195 - k)
            );
        }
    }
}
