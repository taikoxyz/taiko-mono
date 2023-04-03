// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {LibFixedPointMath} from "../../thirdparty/LibFixedPointMath.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

library LibL2Tokenomics {
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    error L1_1559_GAS_CHANGE_MISMATCH(uint64 expectedRatio, uint64 actualRatio);
    error L1_1559_X_SCALE_TOO_LARGE();
    error L1_1559_Y_SCALE_TOO_LARGE();
    error L1_OUT_OF_BLOCK_SPACE();

    function getL2Basefee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 gasUsed
    ) internal view returns (uint64 basefee, uint64 newGasExcess) {
        if (config.gasIssuedPerSecond == 0) {
            // L2 1559 disabled
            return (0, 0);
        }

        unchecked {
            uint256 reduced = (block.timestamp - state.lastProposedAt) *
                config.gasIssuedPerSecond;
            newGasExcess = uint64(
                reduced.max(state.l2GasExcess + gasUsed) - reduced
            );
        }

        uint256 _basefee = calcL2Basefee({
            l2GasExcess: newGasExcess,
            xscale: state.l2Xscale,
            yscale: uint256(state.l2Yscale) << 64,
            gasAmount: 1
        }).toUint64();

        if (_basefee >= type(uint64).max) {
            // This is a valid case when the curve slope is large.
            revert L1_OUT_OF_BLOCK_SPACE();
        }

        basefee = uint64(_basefee);
    }

    function calcL2BasefeeParams(
        uint64 gasExcessMax,
        uint64 basefeeInitial,
        uint64 gasTarget,
        uint64 expected2X1XRatio
    ) internal pure returns (uint64 xscale, uint256 yscale) {
        assert(gasExcessMax != 0);

        uint64 l2GasExcess = gasExcessMax / 2;

        // calculate xscale
        uint256 _xscale = LibFixedPointMath.MAX_EXP_INPUT / gasExcessMax;
        if (_xscale >= type(uint64).max) {
            revert L1_1559_X_SCALE_TOO_LARGE();
        }
        xscale = uint64(_xscale);

        // calculate yscale
        yscale = calcL2Basefee(l2GasExcess, xscale, basefeeInitial, gasTarget);
        if ((yscale >> 64) >= type(uint64).max) {
            revert L1_1559_Y_SCALE_TOO_LARGE();
        }

        // Verify the gas price ratio between two blocks, one has
        // 2*gasTarget gas and the other one has gasTarget gas.
        {
            uint256 price1x = calcL2Basefee(
                l2GasExcess,
                xscale,
                yscale,
                gasTarget
            );
            uint256 price2x = calcL2Basefee(
                l2GasExcess,
                xscale,
                yscale,
                gasTarget * 2
            );

            uint64 ratio = uint64((price2x * 100) / price1x);

            if (expected2X1XRatio != ratio) {
                revert L1_1559_GAS_CHANGE_MISMATCH(expected2X1XRatio, ratio);
            }
        }
    }

    function calcL2Basefee(
        uint64 l2GasExcess,
        uint64 xscale,
        uint256 yscale,
        uint64 gasAmount
    ) internal pure returns (uint256) {
        uint64 _gasAmount = gasAmount == 0 ? 1 : gasAmount;
        assert(xscale != 0 && yscale != 0);
        uint256 _before = _ethqty(l2GasExcess, xscale);
        uint256 _after = _ethqty(l2GasExcess + _gasAmount, xscale);
        return (_after - _before) / _gasAmount / yscale;
    }

    function _ethqty(
        uint256 l2GasExcess,
        uint256 xscale
    ) private pure returns (uint256) {
        uint256 x = l2GasExcess * xscale;
        if (x > LibFixedPointMath.MAX_EXP_INPUT) {
            revert L1_OUT_OF_BLOCK_SPACE();
        }
        return uint256(LibFixedPointMath.exp(int256(x)));
    }
}
