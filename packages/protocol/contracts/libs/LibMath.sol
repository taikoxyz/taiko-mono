// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/**
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
}
