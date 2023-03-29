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

    uint256 public constant MAX_EXP_INPUT = 135305999368893231588;

    error L1_1559_GAS_CHANGE_MISMATCH(uint64 expectedRatio, uint64 actualRatio);
    error L1_1559_X_SCALE_TOO_LARGE();
    error L1_1559_Y_SCALE_TOO_LARGE();
    error L1_OUT_OF_BLOCK_SPACE();

    function get1559Basefee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint32 gasLimit
    ) internal view returns (uint64 basefee, uint64 newGasExcess) {
        uint64 newGasExcess;
        unchecked {
            uint256 reduced = (block.timestamp - state.lastProposedAt) *
                config.gasTargetPerSecond;
            newGasExcess = uint64(reduced.max(state.gasExcess) - reduced);
        }

        basefee = calc1559Basefee({
            gasExcess: newGasExcess,
            xscale: state.xscale,
            yscale: uint256(state.yscale) << 64,
            gasAmount: gasLimit
        }).toUint64();
        newGasExcess += gasLimit;
    }

    function calc1559Params(
        uint64 excessMax,
        uint64 basefeeInitial,
        uint64 gasTarget,
        uint64 expected2X1XRatio
    ) internal pure returns (uint64 gasExcess, uint64 xscale, uint64 yscale) {
        assert(excessMax != 0);

        gasExcess = excessMax / 2;

        // calculate xscale
        {
            uint256 _xscale = MAX_EXP_INPUT / excessMax;
            if (_xscale >= type(uint64).max) {
                revert L1_1559_X_SCALE_TOO_LARGE();
            }
            xscale = uint64(_xscale);
        }

        // calculate yscale
        {
            uint256 _yscale = calc1559Basefee(
                gasExcess,
                xscale,
                basefeeInitial,
                gasTarget
            );
            if ((_yscale >> 64) >= type(uint64).max) {
                revert L1_1559_Y_SCALE_TOO_LARGE();
            }

            yscale = uint64(_yscale >> 64);
        }

        // verify the gas price ratio between two blocks, one has
        // 2*gasTarget gas and the other one has gasTarget gas.
        {
            uint _yscale = uint256(yscale) << 64;
            uint256 price1x = calc1559Basefee(
                gasExcess,
                xscale,
                _yscale,
                gasTarget
            );
            uint256 price2x = calc1559Basefee(
                gasExcess,
                xscale,
                _yscale,
                gasTarget * 2
            );

            uint64 ratio = uint64((price2x * 100) / price1x);

            if (expected2X1XRatio != ratio) {
                revert L1_1559_GAS_CHANGE_MISMATCH(expected2X1XRatio, ratio);
            }
        }
    }

    function calc1559Basefee(
        uint64 gasExcess,
        uint64 xscale,
        uint256 yscale,
        uint64 gasAmount
    ) internal pure returns (uint256) {
        assert(gasAmount != 0 && xscale != 0 && yscale != 0);
        uint256 _before = _ethqty(gasExcess, xscale);
        uint256 _after = _ethqty(gasExcess + gasAmount, xscale);
        return (_after - _before) / gasAmount / yscale;
    }

    function _ethqty(
        uint256 gasExcess,
        uint256 xscale
    ) private pure returns (uint256) {
        uint256 x = gasExcess * xscale;
        if (x > MAX_EXP_INPUT) revert L1_OUT_OF_BLOCK_SPACE();
        return uint256(Math.exp(int256(x)));
    }
}
