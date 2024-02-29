// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LibMath
/// @dev This library offers additional math functions for uint256.
/// @custom:security-contact security@taiko.xyz
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
