// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

library LibL2Tokenomics {
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    function get1559Basefee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 gasInBlock
    )
        internal
        view
        returns (uint256 newGasExcess, uint32 basefee, uint256 gasPurchaseCost)
    {
        return
            calculate1559Basefee(
                state.gasExcess,
                config.gasTarget,
                config.adjustmentQuotient,
                gasInBlock,
                block.timestamp - state.lastProposedAt
            );
    }

    // @dev Return adjusted basefee per gas for the next L2 block.
    //      See https://ethresear.ch/t/make-eip-1559-more-like-an-amm-curve/9082
    function calculate1559Basefee(
        uint256 gasExcess,
        uint256 gasTarget,
        uint256 adjustmentQuotient,
        uint256 gasInBlock,
        uint256 blockTime
    )
        internal
        pure
        returns (uint256 newGasExcess, uint32 basefee, uint256 gasPurchaseCost)
    {
        uint256 adjustment = gasTarget * blockTime;
        newGasExcess = gasExcess.max(adjustment) - adjustment;

        gasPurchaseCost =
            LibMath.exp(
                (newGasExcess + gasInBlock) / gasTarget / adjustmentQuotient
            ) -
            LibMath.exp(newGasExcess / gasTarget / adjustmentQuotient);
        basefee = (gasPurchaseCost / gasInBlock).toUint32();
        newGasExcess += gasInBlock;
    }
}
