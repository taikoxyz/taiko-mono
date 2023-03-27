// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

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
        uint32 gasInBlock
    )
        internal
        view
        returns (uint64 newGasExcess, uint64 basefee, uint256 gasPurchaseCost)
    {
        return
            calc1559Basefee(
                state.gasExcess,
                config.gasTargetPerSecond,
                config.gasPoolProduct,
                gasInBlock,
                uint64(block.timestamp - state.lastProposedAt)
            );
    }

    // @dev Return adjusted basefee per gas for the next L2 block.
    //      See https://ethresear.ch/t/make-eip-1559-more-like-an-amm-curve/9082
    //      But the current implementation use AMM style math as we don't yet
    //      have a solidity exp(uint256 x) implementation.
    function calc1559Basefee(
        uint64 gasExcess,
        uint256 gasTargetPerSecond,
        uint256 gasPoolProduct,
        uint32 gasInBlock,
        uint256 blockTime
    )
        internal
        pure
        returns (uint64 newGasExcess, uint64 basefee, uint256 gasPurchaseCost)
    {
        if (gasInBlock == 0) {
            return (gasExcess, 0, 0);
        }
        unchecked {
            uint256 _gasExcess = gasTargetPerSecond * blockTime + gasExcess;

            _gasExcess = _gasExcess.min(type(uint64).max);

            if (gasInBlock >= _gasExcess) revert L1_OUT_OF_BLOCK_SPACE();

            newGasExcess = uint64(_gasExcess - gasInBlock);

            gasPurchaseCost =
                (gasPoolProduct / newGasExcess) -
                (gasPoolProduct / _gasExcess);

            uint256 _basefee = gasPurchaseCost / gasInBlock;
            basefee = uint64(_basefee.min(type(uint64).max));
            gasPurchaseCost = uint256(basefee) * gasInBlock;
        }
    }
}
