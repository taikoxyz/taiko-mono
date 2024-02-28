// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../thirdparty/solmate/LibFixedPointMath.sol";

/// @title Lib1559Math
/// @notice Implements e^(x) based bonding curve for EIP-1559
/// @dev See https://ethresear.ch/t/make-eip-1559-more-like-an-amm-curve/9082
/// @custom:security-contact security@taiko.xyz
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
