// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

/**
 * @author dantaik <dan@taiko.xyz>
 * @notice This library offers additional math functions for uint256.
 */

library LibMath {
    /**
     * @notice Returns the smaller value between the two given values.
     * @param a One of the two values.
     * @param b The other one of the two values.
     * @return The smaller value.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? b : a;
    }

    /**
     * @notice Returns the larger value between the two given values.
     * @param a One of the two values.
     * @param b The other one of the two values.
     * @return The larger value.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @notice Returns the ceil value.
     * @param a The numerator.
     * @param b The denominator.
     * @return c The ceil value of (a/b).
     */
    function divceil(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a / b;
        if (c * b < a) {
            c += 1;
        }
    }

    /**
     * @notice Returns the square root of a given uint256.
     * This method is taken from:
     * https://github.com/Uniswap/v2-core/blob/v1.0.1/contracts/libraries/Math.sol.
     * It is based on the Babylonian method:
     * https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method).
     * @param y The given number.
     * @return z The square root of y.
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
