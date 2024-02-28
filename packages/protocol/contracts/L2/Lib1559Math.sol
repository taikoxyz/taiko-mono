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

import "../thirdparty/solmate/LibFixedPointMath.sol";

/// @title Lib1559Math
/// @custom:security-contact security@taiko.xyz
/// @dev Implementation of e^(x) based bonding curve for EIP-1559
/// See https://ethresear.ch/t/make-eip-1559-more-like-an-amm-curve/9082
library Lib1559Math {
    error EIP1559_INVALID_PARAMS();

    /// @dev eth_qty(excess_gas_issued) / (TARGET * ADJUSTMENT_QUOTIENT)
    /// @param adjustmentFactor The product of gasTarget and adjustmentQuotient
    function basefee(uint256 gasExcess, uint256 adjustmentFactor) internal pure returns (uint256) {
        if (adjustmentFactor == 0) {
            revert EIP1559_INVALID_PARAMS();
        }

        return _ethQty(gasExcess, adjustmentFactor) / LibFixedPointMath.SCALING_FACTOR
            / adjustmentFactor;
    }

    /// @dev exp(gas_qty / TARGET / ADJUSTMENT_QUOTIENT)
    function _ethQty(uint256 gasExcess, uint256 adjustmentFactor) private pure returns (uint256) {
        uint256 input = gasExcess * LibFixedPointMath.SCALING_FACTOR / adjustmentFactor;
        if (input > LibFixedPointMath.MAX_EXP_INPUT) {
            input = LibFixedPointMath.MAX_EXP_INPUT;
        }
        return uint256(LibFixedPointMath.exp(int256(input)));
    }
}
