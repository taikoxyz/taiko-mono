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

    error L1_OUT_OF_BLOCK_SPACE();
    error L1_1559_GAS_CHANGE_NOT_MATCH(
        uint64 expectedRatio,
        uint64 actualRatio
    );

    function update1559Basefee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint32 gasLimit
    ) internal returns (uint64 basefee) {
        unchecked {
            uint256 reduced = (block.timestamp - state.lastProposedAt) *
                config.gasTargetPerSecond;
            state.gasExcess = uint64(reduced.max(state.gasExcess) - reduced);
        }

        basefee = calc1559Basefee({
            excess: state.gasExcess,
            xscale: state.xscale,
            yscale: state.yscale << 64,
            amount: gasLimit
        }).toUint64();

        state.gasExcess += gasLimit;
    }

    function calc1559Params(
        uint64 excessMax,
        uint64 basefeeInitial,
        uint64 gasTarget,
        uint64 expected2X1XRatio
    ) internal pure returns (uint64 excess, uint64 xscale, uint64 yscale) {
        assert(excessMax != 0);

        excess = excessMax / 2;
        xscale = (MAX_EXP_INPUT / excessMax).toUint64();

        uint256 _yscale = calc1559Basefee(
            excess,
            xscale,
            basefeeInitial,
            gasTarget
        );
        yscale = (_yscale >> 64).toUint64();
        assert(xscale < type(uint64).max);

        {
            uint256 price1x = calc1559Basefee(
                excess,
                xscale,
                uint256(yscale) << 64,
                gasTarget
            );
            uint256 price2x = calc1559Basefee(
                excess,
                xscale,
                uint256(yscale) << 64,
                gasTarget * 2
            );

            uint64 ratio = uint64((price2x * 100) / price1x);

            if (expected2X1XRatio != ratio)
                revert L1_1559_GAS_CHANGE_NOT_MATCH(expected2X1XRatio, ratio);
        }
    }

    function calc1559Basefee(
        uint64 excess,
        uint64 xscale,
        uint256 yscale,
        uint64 amount
    ) internal pure returns (uint256) {
        assert(amount != 0 && xscale != 0 && yscale != 0);
        uint256 _before = _ethqty(excess, xscale);
        uint256 _after = _ethqty(excess + amount, xscale);
        return (_after - _before) / amount / yscale;
    }

    function _ethqty(
        uint256 excess,
        uint256 xscale
    ) private pure returns (uint256) {
        uint256 x = excess * xscale;
        if (x > MAX_EXP_INPUT) revert L1_OUT_OF_BLOCK_SPACE();
        return uint256(Math.exp(int256(x)));
    }
}
