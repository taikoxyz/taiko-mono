// SPDX-License-Identifier: MIT
// Taken from the contract below, expWad() function tailored to Taiko's need
// https://github.com/transmissions11/solmate/blob/v7/src/utils/FixedPointMathLib.sol
pragma solidity 0.8.24;

library LibFixedPointMath {
    uint128 public constant MAX_EXP_INPUT = 135_305_999_368_893_231_588;
    uint256 public constant SCALING_FACTOR = 1e18; // For fixed point representation factor

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
            int256 k = ((x << 96) / 54_916_777_467_707_473_351_141_471_128 + 2 ** 95) >> 96;
            x = x - k * 54_916_777_467_707_473_351_141_471_128;
            // k is in the range [-61, 195].

            // Evaluate using a (6, 7)-term rational approximation.
            // p is made monic, we'll multiply by a scale factor later.
            int256 y = x + 1_346_386_616_545_796_478_920_950_773_328;
            y = ((y * x) >> 96) + 57_155_421_227_552_351_082_224_309_758_442;
            int256 p = y + x - 94_201_549_194_550_492_254_356_042_504_812;
            p = ((p * y) >> 96) + 28_719_021_644_029_726_153_956_944_680_412_240;
            p = p * x + (4_385_272_521_454_847_904_659_076_985_693_276 << 96);

            // We leave p in 2**192 basis so we don't need to scale it back up
            // for the division.
            int256 q = x - 2_855_989_394_907_223_263_936_484_059_900;
            q = ((q * x) >> 96) + 50_020_603_652_535_783_019_961_831_881_945;
            q = ((q * x) >> 96) - 533_845_033_583_426_703_283_633_433_725_380;
            q = ((q * x) >> 96) + 3_604_857_256_930_695_427_073_651_918_091_429;
            q = ((q * x) >> 96) - 14_423_608_567_350_463_180_887_372_962_807_573;
            q = ((q * x) >> 96) + 26_449_188_498_355_588_339_934_803_723_976_023;
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
            //  * the 1e18 / 2**96 factor for base conversion.
            // We do all of this at once, with an intermediate result in 2**213
            // basis
            // so the final right shift is always by a positive amount.
            r = int256(
                (uint256(r) * 3_822_833_074_963_236_453_042_738_258_902_158_003_155_416_615_667)
                    >> uint256(195 - k)
            );
        }
    }

    function ln(int256 x) internal pure returns (int256 r) {
        unchecked {
            require(x > 0, "UNDEFINED");

            // We want to convert x from 10**18 fixed point to 2**96 fixed point.
            // We do this by multiplying by 2**96 / 10**18. But since
            // ln(x * C) = ln(x) + ln(C), we can simply do nothing here
            // and add ln(2**96 / 10**18) at the end.

            // Reduce range of x to (1, 2) * 2**96
            // ln(2^k * x) = k * ln(2) + ln(x)
            int256 k = int256(log2(uint256(x))) - 96;
            x <<= uint256(159 - k);
            x = int256(uint256(x) >> 159);

            // Evaluate using a (8, 8)-term rational approximation.
            // p is made monic, we will multiply by a scale factor later.
            int256 p = x + 3_273_285_459_638_523_848_632_254_066_296;
            p = ((p * x) >> 96) + 24_828_157_081_833_163_892_658_089_445_524;
            p = ((p * x) >> 96) + 43_456_485_725_739_037_958_740_375_743_393;
            p = ((p * x) >> 96) - 11_111_509_109_440_967_052_023_855_526_967;
            p = ((p * x) >> 96) - 45_023_709_667_254_063_763_336_534_515_857;
            p = ((p * x) >> 96) - 14_706_773_417_378_608_786_704_636_184_526;
            p = p * x - (795_164_235_651_350_426_258_249_787_498 << 96);

            // We leave p in 2**192 basis so we don't need to scale it back up for the division.
            // q is monic by convention.
            int256 q = x + 5_573_035_233_440_673_466_300_451_813_936;
            q = ((q * x) >> 96) + 71_694_874_799_317_883_764_090_561_454_958;
            q = ((q * x) >> 96) + 283_447_036_172_924_575_727_196_451_306_956;
            q = ((q * x) >> 96) + 401_686_690_394_027_663_651_624_208_769_553;
            q = ((q * x) >> 96) + 204_048_457_590_392_012_362_485_061_816_622;
            q = ((q * x) >> 96) + 31_853_899_698_501_571_402_653_359_427_138;
            q = ((q * x) >> 96) + 909_429_971_244_387_300_277_376_558_375;
            assembly {
                // Div in assembly because solidity adds a zero check despite the unchecked.
                // The q polynomial is known not to have zeros in the domain.
                // No scaling required because p is already 2**96 too large.
                r := sdiv(p, q)
            }

            // r is in the range (0, 0.125) * 2**96

            // Finalization, we need to:
            // * multiply by the scale factor s = 5.549…
            // * add ln(2**96 / 10**18)
            // * add k * ln(2)
            // * multiply by 10**18 / 2**96 = 5**18 >> 78

            // mul s * 5e18 * 2**96, base is now 5**18 * 2**192
            r *= 1_677_202_110_996_718_588_342_820_967_067_443_963_516_166;
            // add ln(2) * k * 5e18 * 2**192
            r +=
            16_597_577_552_685_614_221_487_285_958_193_947_469_193_820_559_219_878_177_908_093_499_208_371
                * k;
            // add ln(2**96 / 10**18) * 5e18 * 2**192
            r +=
                600_920_179_829_731_861_736_702_779_321_621_459_595_472_258_049_074_101_567_377_883_020_018_308;
            // base conversion: mul 2**18 / 2**192
            r >>= 174;
        }
    }

    function log2(uint256 x) internal pure returns (uint256 r) {
        require(x > 0, "UNDEFINED");

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
}
