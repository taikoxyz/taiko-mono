// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {
    LibFixedPointMath as Math
} from "../../thirdparty/LibFixedPointMath.sol";

import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

import {console2} from "forge-std/console2.sol";

library LibL2Tokenomics {
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    uint public constant MAX_EXP_INPUT = 135305999368893231588;

    error L1_OUT_OF_BLOCK_SPACE();

    //TODO(daniel): return a fixed base fee.
    function get1559Basefee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint32 gasInBlock
    ) internal view returns (uint64 newGasExcess, uint64 basefee) {
        return
            calc1559Basefee(
                state.gasExcess,
                config.gasTargetPerSecond,
                config.gasAdjustmentQuotient,
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
        uint64 gasTargetPerSecond,
        uint64 gasAdjustmentQuotient,
        uint32 gasInBlock,
        uint64 blockTime
    ) internal view returns (uint64 newGasExcess, uint64 basefee) {
        if (gasInBlock == 0) {
            uint256 _basefee = ethQty(gasExcess, gasAdjustmentQuotient) /
                gasAdjustmentQuotient;
            basefee = uint64(_basefee.min(type(uint64).max));

            return (gasExcess, basefee);
        }
        unchecked {
            uint64 newGas = gasTargetPerSecond * blockTime;
            uint64 _gasExcess = gasExcess > newGas ? gasExcess - newGas : 0;

            if (uint256(_gasExcess) + gasInBlock >= type(uint64).max)
                revert L1_OUT_OF_BLOCK_SPACE();

            newGasExcess = _gasExcess + gasInBlock;

            uint256 a = ethQty(
                newGasExcess, // larger
                gasAdjustmentQuotient
            );
            uint256 b = ethQty(
                _gasExcess, // smaller
                gasAdjustmentQuotient
            );
            uint256 _basefee = (a - b) / gasInBlock;
            basefee = uint64(_basefee.min(type(uint64).max));

            console2.log("-----------------------");
            console2.log("gasExcess:", gasExcess);
            console2.log("newGas:", newGas);
            console2.log("_gasExcess:", _gasExcess);
            console2.log("newGasExcess:", newGasExcess);
            console2.log("a:", a);
            console2.log("b:", b);
            console2.log("_basefee:", _basefee);
            console2.log("basefee:", basefee);
        }
    }

    function ethQty(
        uint64 gasAmount,
        uint64 gasAdjustmentQuotient
    ) internal view returns (uint256 qty) {
        uint x = gasAmount / gasAdjustmentQuotient;
        int y = Math.exp(int256(uint256(x)));
        qty = y > 0 ? uint256(y) : 0;
        console2.log("   -  gasAmount:", gasAmount);
        console2.log("   -  qty:", qty);
    }

    function ethqty(uint excess, uint xscale) internal pure returns (uint256) {
        uint x = excess * xscale;
        assert(x <= MAX_EXP_INPUT);
        return uint256(Math.exp(int256(x)));
    }

    function basefee(
        uint excess,
        uint xscale,
        uint yscale,
        uint amount
    ) internal pure returns (uint256) {
        return
            (ethqty(excess + amount, xscale) - ethqty(excess, xscale)) / yscale;
    }
}
