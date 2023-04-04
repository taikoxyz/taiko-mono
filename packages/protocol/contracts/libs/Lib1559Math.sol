// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibFixedPointMath} from "../thirdparty/LibFixedPointMath.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {console2} from "forge-std/console2.sol";

library Lib1559Math {
    using SafeCastUpgradeable for uint256;

    error M1559_UNEXPECTED_CHANGE(uint64 expected, uint64 actual);
    error M1559_OUT_OF_STOCK();

    function calculateScales(
        uint64 xExcessMax,
        uint64 price,
        uint64 target,
        uint64 ratio2x1x
    ) internal view returns (uint128 xscale, uint128 yscale) {
        assert(xExcessMax != 0);

        uint64 x = xExcessMax / 2;

        // calculate xscale
        xscale = LibFixedPointMath.MAX_EXP_INPUT / xExcessMax;

        // calculate yscale
        yscale = calculatePrice(xscale, price, x, target).toUint128();

        // Verify the gas price ratio between two blocks, one has
        // 2*target gas and the other one has target gas.
        uint256 price1x = calculatePrice(xscale, yscale, x, target);
        uint256 price2x = calculatePrice(xscale, yscale, x, target * 2);
        uint64 ratio = uint64((price2x * 100) / price1x);

        if (ratio2x1x != ratio)
            revert M1559_UNEXPECTED_CHANGE(ratio2x1x, ratio);
    }

    function calculatePrice(
        uint128 xscale,
        uint128 yscale,
        uint64 xExcess,
        uint64 xPurchase
    ) internal view returns (uint256) {
        console2.log("-------calculatePrice");
        console2.log("- xPurchase", xPurchase);

        assert(xscale != 0 && yscale != 0);
        uint64 _xPurchase = xPurchase == 0 ? 1 : xPurchase;
        uint256 _before = _calcY(xExcess, xscale);
        uint256 _after = _calcY(xExcess + _xPurchase, xscale);
        return (_after - _before) / _xPurchase / yscale;
    }

    function _calcY(uint256 x, uint128 xscale) private view returns (uint256) {
        uint256 _x = x * xscale;
        console2.log("-------_calcY");
        console2.log("- x", x);
        console2.log("- xscale", xscale);
        console2.log("- x * xscale", _x);

        if (_x >= LibFixedPointMath.MAX_EXP_INPUT) {
            revert M1559_OUT_OF_STOCK();
        }
        return uint256(LibFixedPointMath.exp(int256(_x)));
    }
}
