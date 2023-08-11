// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/**
 * @title LibMath Library
 * @notice This library offers additional math functions for uint256.
 * @dev Libraries in Solidity are similar to classes of OOP languages. They
 * provide functions that can be applied to variables in a more native way
 * without actually having an instance of a library.
 */
library LibMath {
    /**
     * @notice Returns the smaller of the two given values.
     * @dev Uses the ternary operator to determine and return the smaller value.
     * @param a The first number to compare.
     * @param b The second number to compare.
     * @return The smaller of the two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? b : a;
    }

    /**
     * @notice Returns the larger of the two given values.
     * @dev Uses the ternary operator to determine and return the larger value.
     * @param a The first number to compare.
     * @param b The second number to compare.
     * @return The larger of the two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
