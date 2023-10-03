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

    function calcPurchaseBaseFee(
        uint64 numL1Blocks,
        uint32 gasInBlock,
        uint128 gasExcess,
        uint64 gasTarget,
        uint64 adjustmentQuotient
    )
        internal
        pure
        returns (uint256 _baseFeePerGas, uint128 _gasExcess)
    {
        if (gasTarget == 0 || adjustmentQuotient <= 1 || gasInBlock == 0) {
            revert EIP1559_INVALID_PARAMS();
        }

        uint128 issuance = numL1Blocks * gasTarget;
        _gasExcess = issuance >= gasExcess ? 0 : gasExcess - issuance;

        _baseFeePerGas =
            _calcBaseFee(_gasExcess, gasInBlock, gasTarget, adjustmentQuotient);
        _gasExcess += gasInBlock;
    }

    function calcSpotBaseFee(
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

    function _calcBaseFee(
        uint256 gasExcess,
        uint256 gasInBlock,
        uint256 gasTarget,
        uint256 adjustmentQuotient
    )
        private
        pure
        returns (uint256 baseFeePerGas)
    {
        int256 diff = _ethQty(
            gasExcess + gasInBlock, gasTarget, adjustmentQuotient
        ) - _ethQty(gasExcess, gasTarget, adjustmentQuotient);
        baseFeePerGas =
            uint256(diff) / gasInBlock / LibFixedPointMath.SCALING_FACTOR_1E18;
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
