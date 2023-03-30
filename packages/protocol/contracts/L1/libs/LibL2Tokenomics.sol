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
        uint32 gasLimit
    ) internal view returns (uint64 basefee, uint64 newGasExcess) {
        if (config.gasIssuedPerSecond == 0) {
            // L2 1559 disabled
            return (0, 0);
        }

        unchecked {
            uint256 reduced = (block.timestamp - state.lastProposedAt) *
                config.gasIssuedPerSecond;
            newGasExcess = uint64(reduced.max(state.l2GasExcess) - reduced);
        }

        basefee = calc1559Basefee({
            l2GasExcess: newGasExcess,
            xscale: state.l2Xscale,
            yscale: uint256(state.l2Yscale) << 64,
            gasAmount: gasLimit
        }).toUint64();

        newGasExcess += gasLimit;
    }

    function calc1559Params(
        uint64 excessMax,
        uint64 basefeeInitial,
        uint64 gasTarget,
        uint64 expected2X1XRatio
    ) internal pure returns (uint64 l2GasExcess, uint64 xscale, uint64 yscale) {
        assert(excessMax != 0);

        l2GasExcess = excessMax / 2;

        // calculate xscale
        uint256 _xscale = LibFixedPointMath.MAX_EXP_INPUT / excessMax;
        if (_xscale >= type(uint64).max) {
            revert L1_1559_X_SCALE_TOO_LARGE();
        }
        xscale = uint64(_xscale);

        // calculate yscale
        uint256 _yscale = calc1559Basefee(
            l2GasExcess,
            xscale,
            basefeeInitial,
            gasTarget
        );
        if ((_yscale >> 64) >= type(uint64).max) {
            revert L1_1559_Y_SCALE_TOO_LARGE();
        }

        yscale = uint64(_yscale >> 64);

        // Verify the gas price ratio between two blocks, one has
        // 2*gasTarget gas and the other one has gasTarget gas.
        {
            _yscale = uint256(yscale) << 64;
            uint256 price1x = calc1559Basefee(
                l2GasExcess,
                xscale,
                _yscale,
                gasTarget
            );
            uint256 price2x = calc1559Basefee(
                l2GasExcess,
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
        uint64 l2GasExcess,
        uint64 xscale,
        uint256 yscale,
        uint64 gasAmount
    ) internal pure returns (uint256) {
        assert(gasAmount != 0 && xscale != 0 && yscale != 0);
        uint256 _before = _ethqty(l2GasExcess, xscale);
        uint256 _after = _ethqty(l2GasExcess + gasAmount, xscale);
        return (_after - _before) / gasAmount / yscale;
    }

    function _ethqty(
        uint256 l2GasExcess,
        uint256 xscale
    ) private pure returns (uint256) {
        uint256 x = l2GasExcess * xscale;
        if (x > LibFixedPointMath.MAX_EXP_INPUT) revert L1_OUT_OF_BLOCK_SPACE();
        return uint256(LibFixedPointMath.exp(int256(x)));
    }
}
