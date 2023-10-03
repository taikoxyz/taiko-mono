// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibFixedPointMath } from "../../thirdparty/LibFixedPointMath.sol";

library Lib1559Math {
    error EIP1559_INPUT_TOO_BIG();
    error EIP1559_INVALID_PARAMS();

    function calcBaseFee(
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

        return uint256(_ethQty(gasExcess, gasTarget, adjustmentQuotient))
            / gasTarget / adjustmentQuotient / LibFixedPointMath.SCALING_FACTOR_1E18;
    }

    function _ethQty(
        uint256 gasQuantity,
        uint256 gasTarget,
        uint256 adjustmentQuotient
    )
        private
        pure
        returns (int256)
    {
        uint256 input = gasQuantity * LibFixedPointMath.SCALING_FACTOR_1E18
            / gasTarget / adjustmentQuotient;
        if (input >= LibFixedPointMath.MAX_EXP_INPUT) {
            revert EIP1559_INPUT_TOO_BIG();
        }
        return LibFixedPointMath.exp(int256(input));
    }
}
