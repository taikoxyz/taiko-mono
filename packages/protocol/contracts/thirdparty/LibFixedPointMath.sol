// SPDX-License-Identifier: UNLICENSED
// Taken from: https://github.com/recmo/experiment-solexp/blob/main/src/FixedPointMathLib.sol
pragma solidity ^0.8.20;

library LibFixedPointMath {
    uint128 public constant MAX_EXP_INPUT = 135305999368893231588;
    uint256 public constant SCALING_FACTOR_1E18 = 1e18; // For fixed point representation factor

    error Overflow();

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
}
