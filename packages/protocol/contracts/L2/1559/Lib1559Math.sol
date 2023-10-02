// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibFixedPointMath as Math } from
    "../../thirdparty/LibFixedPointMath.sol";

library Lib1559Math {
    error EIP1559_INPUT_TOO_BIG();
    error EIP1559_INVALID_PARAMS();

    function calcBaseFee(
        uint64 numL1Blocks,
        uint128 gasExcessIssued,
        uint32 gasInBlock,
        uint64 gasTarget,
        uint64 adjustmentQuotient
    )
        internal
        pure
        returns (uint256 _baseFeePerGas, uint128 _gasExcessIssued)
    {
        if (gasTarget == 0 || adjustmentQuotient <= 1 || gasInBlock == 0) {
            revert EIP1559_INVALID_PARAMS();
        }

        uint128 issuance = numL1Blocks * gasTarget;
        _gasExcessIssued =
            issuance >= gasExcessIssued ? 0 : gasExcessIssued - issuance;

        _baseFeePerGas = _calcBaseFee(
            _gasExcessIssued, gasInBlock, gasTarget, adjustmentQuotient
        );
        _gasExcessIssued += gasInBlock;
    }

    function _calcBaseFee(
        uint256 gasExcessIssued,
        uint256 gasInBlock,
        uint256 gasTarget,
        uint256 adjustmentQuotient
    )
        private
        pure
        returns (uint256 baseFeePerGas)
    {
        int256 diff = _ethQty(
            gasExcessIssued + gasInBlock, gasTarget, adjustmentQuotient
        ) - _ethQty(gasExcessIssued, gasTarget, adjustmentQuotient);
        baseFeePerGas = uint256(diff) / gasInBlock / Math.SCALING_FACTOR_1E18;
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
        uint256 input = gasQuantity * Math.SCALING_FACTOR_1E18 / gasTarget
            / adjustmentQuotient;
        if (input >= Math.MAX_EXP_INPUT) revert EIP1559_INPUT_TOO_BIG();
        return Math.exp(int256(input));
    }
}
