// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {TaikoData} from "../TaikoData.sol";

library Lib1559 {
    using LibMath for uint256;

    function get1559BurnAmountAndBasefee(
        TaikoData.Config memory config,
        uint256 gasExcess,
        uint256 blockGasLimit
    )
        internal
        pure
        returns (uint256 ethToBurn, uint256 basefee, uint256 newExcessGasIssued)
    {
        uint256 t = config.blockGasTarget;
        uint256 q = config.basefee1559AdjustmentQuotient;
        uint256 eq1 = exp(gasExcess / t / q);
        basefee = eq1 / t / q;

        uint256 _gasExcess = gasExcess + blockGasLimit;
        uint256 eq2 = exp(_gasExcess / t / q);
        ethToBurn = eq2 - eq1;

        newExcessGasIssued = t.max(_gasExcess) - t;
    }

    // Return `2.71828 ** x`.
    function exp(uint256 x) internal pure returns (uint256 y) {
        // TODO
    }
}
