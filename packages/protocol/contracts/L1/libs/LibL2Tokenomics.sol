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

    function calcScales(
        uint64 excessMax,
        uint64 basefeeInitial,
        uint64 gasTarget
    ) internal view returns (uint64 excess, uint64 xscale, uint64 yscale) {
        assert(excessMax != 0);

        excess = excessMax / 2;
        xscale = (MAX_EXP_INPUT / excessMax).toUint64();
        console2.log("xscale =", xscale);
        assert(xscale < type(uint64).max);

        yscale = (calc1559Basefee(excess, xscale, basefeeInitial, gasTarget) >>
            64).toUint64();
        console2.log("yscale =", yscale);
        assert(xscale < type(uint64).max);

        console2.log("initial basefee (configged)   =", basefeeInitial);
        console2.log(
            "initial basefee (recauculated)=",
            calc1559Basefee(excess, xscale, uint256(yscale) << 64, gasTarget)
        );
    }

    function _ethqty(uint excess, uint xscale) private pure returns (uint256) {
        uint x = excess * xscale;
        assert(x <= MAX_EXP_INPUT);
        return uint256(Math.exp(int256(x)));
    }

    function calc1559Basefee(
        uint64 excess,
        uint64 xscale,
        uint256 yscale,
        uint64 amount
    ) internal pure returns (uint256) {
        assert(amount != 0 && xscale != 0 && yscale != 0);
        uint _before = _ethqty(excess, xscale);
        uint _after = _ethqty(excess + amount, xscale);
        return (_after - _before) / yscale;
    }
}
