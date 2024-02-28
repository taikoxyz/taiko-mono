// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

/// @title LibMath
/// @custom:security-contact security@taiko.xyz
/// @dev This library offers additional math functions for uint256.
library LibMath {
    /// @dev Returns the smaller of the two given values.
    /// @param _a The first number to compare.
    /// @param _b The second number to compare.
    /// @return The smaller of the two numbers.
    function min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _b : _a;
    }

    /// @dev Returns the larger of the two given values.
    /// @param _a The first number to compare.
    /// @param _b The second number to compare.
    /// @return The larger of the two numbers.
    function max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a > _b ? _a : _b;
    }
}
