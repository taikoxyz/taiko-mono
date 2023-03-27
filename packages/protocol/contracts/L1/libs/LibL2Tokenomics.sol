// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {console2} from "forge-std/console2.sol";

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {LibRealMath} from "../../libs/LibRealMath.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

library LibL2Tokenomics {
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    error L1_OUT_OF_BLOCK_SPACE();

    function get1559Basefee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 gasInBlock
    )
        internal
        view
        returns (uint256 newGasExcess, uint64 basefee, uint256 gasPurchaseCost)
    {
        return
            calc1559Basefee(
                state.gasExcess,
                config.gasTargetPerSecond,
                config.gasPoolProduct,
                gasInBlock,
                block.timestamp - state.lastProposedAt
            );
    }

    // @dev Return adjusted basefee per gas for the next L2 block.
    //      See https://ethresear.ch/t/make-eip-1559-more-like-an-amm-curve/9082
    //      But the current implementation use AMM style math as we don't yet
    //      have a solidity exp(uint256 x) implementation.
    function calc1559Basefee(
        uint256 gasExcess,
        uint256 gasTargetPerSecond,
        uint256 gasPoolProduct,
        uint256 gasInBlock,
        uint256 blockTime
    )
        internal
        view
        returns (uint256 newGasExcess, uint64 basefee, uint256 gasPurchaseCost)
    {
        unchecked {
            uint256 _gasExcess = gasExcess + (gasTargetPerSecond * blockTime);
            console2.log("----- _gasExcess:", _gasExcess);
            console2.log("----- newGasExcess:", _gasExcess - gasInBlock);
            console2.log("----- gasInBlock:", gasInBlock);

            if (gasInBlock >= _gasExcess) revert L1_OUT_OF_BLOCK_SPACE();
            newGasExcess = _gasExcess - gasInBlock;

            console2.log("----- larger:", (gasPoolProduct / newGasExcess));
            console2.log("----- smaller:", (gasPoolProduct / _gasExcess));

            gasPurchaseCost =
                (gasPoolProduct / newGasExcess) -
                (gasPoolProduct / _gasExcess);

            basefee = (gasPurchaseCost / gasInBlock).toUint64();
        }
    }
}
