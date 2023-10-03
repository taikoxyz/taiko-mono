// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibFixedPointMath } from "../thirdparty/LibFixedPointMath.sol";

/// @title Lib1559Math
/// @dev Implementation of e^(x) based bonding curve for EIP-1559
/// See https://ethresear.ch/t/make-eip-1559-more-like-an-amm-curve/9082
library Lib1559Math {
    error EIP1559_INVALID_PARAMS();

    /// @dev eth_qty(excess_gas_issued) / (TARGET * ADJUSTMENT_QUOTIENT)
    function basefee(
        uint256 gasExcess,
        uint256 gasTarget,
        uint256 adjustmentQuotient
    )
        internal
        pure
        returns (uint256)
    {
        if (gasTarget == 0 || adjustmentQuotient <= 1) {
            revert EIP1559_INVALID_PARAMS();
        }

        return _ethQty(gasExcess, gasTarget, adjustmentQuotient) / gasTarget
            / adjustmentQuotient / LibFixedPointMath.SCALING_FACTOR_1E18;
    }

    /// @dev exp(gas_qty / TARGET / ADJUSTMENT_QUOTIENT)
    function _ethQty(
        uint256 gasQuantity,
        uint256 gasTarget,
        uint256 adjustmentQuotient
    )
        private
        pure
        returns (uint256)
    {
        uint256 input = gasQuantity * LibFixedPointMath.SCALING_FACTOR_1E18
            / gasTarget / adjustmentQuotient;
        if (input > LibFixedPointMath.MAX_EXP_INPUT) {
            input = LibFixedPointMath.MAX_EXP_INPUT;
        }
        return uint256(LibFixedPointMath.exp(int256(input)));
    }
}
