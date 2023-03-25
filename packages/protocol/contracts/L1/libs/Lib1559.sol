// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
// import {
//     SafeCastUpgradeable
// } from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

// import {TaikoToken} from "../TaikoToken.sol";

library Lib1559 {
    using LibMath for uint256;

    function get1559BurnAmountAndBaseFee(
        TaikoData.Config memory config,
        uint256 excessGasIssued,
        uint256 blockGasLimit
    )
        internal
        pure
        returns (uint256 ethToBurn, uint256 basefee, uint256 newExcessGasIssued)
    {
        uint256 gasTarget = config.gasTargetPerL2Block;
        uint256 quotient = config.gasFeeAdjustmentQuotient;

        uint256 quality1 = ethQty(gasTarget, quotient, excessGasIssued);
        basefee = quality1 / gasTarget / quotient;

        uint256 _excessGasIssued = excessGasIssued + blockGasLimit;
        uint256 quality2 = ethQty(gasTarget, quotient, _excessGasIssued);

        ethToBurn = quality2 - quality1;

        newExcessGasIssued = gasTarget.max(_excessGasIssued) - gasTarget;
    }

    function ethQty(
        uint256 gasTarget,
        uint256 gasFeeAdjustmentQuotient,
        uint256 excessGasIssued
    ) internal pure returns (uint256) {
        return exp(excessGasIssued / gasTarget / gasFeeAdjustmentQuotient);
    }

    // Return `2.71828 ** x`.
    function exp(uint256 x) internal pure returns (uint256 y) {
        // TODO
    }
}
