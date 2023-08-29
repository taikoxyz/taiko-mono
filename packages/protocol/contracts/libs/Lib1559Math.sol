// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibFixedPointMath } from "../thirdparty/LibFixedPointMath.sol";
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

/// @title Lib1559Math
/// @dev This library provides utilities related to the L2 EIP-1559
/// implementation.
/// See formulas described in the whitepaper
/// https://taikoxyz.github.io/taiko-mono/taiko-whitepaper.pdf
/// From section:  "9.6. Rate Limiting using EIP-1559."
/// Additional info about the arithmetic formula:
/// https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/docs/L2EIP1559.md
library Lib1559Math {
    using SafeCastUpgradeable for uint256;

    error L2_1559_UNEXPECTED_CHANGE(uint64 expected, uint64 actual);
    error L2_1559_OUT_OF_STOCK();

    /// @dev Calculates xscale and yscale values used for pricing.
    /// @param xExcessMax The maximum excess value.
    /// @param price The current price.
    /// @param target The target gas value.
    /// @param ratio2x1x Expected ratio of gas price for two blocks.
    /// @return xscale Calculated x scale value.
    /// @return yscale Calculated y scale value.
    function calculateScales(
        uint64 xExcessMax,
        uint64 price,
        uint64 target,
        uint64 ratio2x1x
    )
        internal
        pure
        returns (uint128 xscale, uint128 yscale)
    {
        assert(xExcessMax != 0);
        uint64 x = xExcessMax / 2;

        // Calculate xscale
        xscale = LibFixedPointMath.MAX_EXP_INPUT / xExcessMax;

        // Calculate yscale
        yscale = calculatePrice(xscale, price, x, target).toUint128();

        // Verify the gas price ratio between two blocks, one has
        // target * 2 gas and the other one has target gas.
        uint256 price1x = calculatePrice(xscale, yscale, x, target);
        uint256 price2x = calculatePrice(xscale, yscale, x, target * 2);
        uint64 ratio = uint64((price2x * 10_000) / price1x);

        if (ratio2x1x != ratio) {
            revert L2_1559_UNEXPECTED_CHANGE(ratio2x1x, ratio);
        }
    }

    /// @dev Calculates the price based on provided scales.
    /// @param xscale The x scale value.
    /// @param yscale The y scale value.
    /// @param xExcess Current excess value.
    /// @param xPurchase Amount of gas purchased.
    /// @return The calculated price.
    function calculatePrice(
        uint128 xscale,
        uint128 yscale,
        uint64 xExcess,
        uint64 xPurchase
    )
        internal
        pure
        returns (uint256)
    {
        assert(xscale != 0 && yscale != 0);
        uint64 _xPurchase = xPurchase == 0 ? 1 : xPurchase;
        uint256 _before = _calcY(xExcess, xscale);
        uint256 _after = _calcY(xExcess + _xPurchase, xscale);
        return (_after - _before) / _xPurchase / yscale;
    }

    /// @dev Internal function to calculate y value based on x value and scale.
    /// @param x The x value.
    /// @param xscale The x scale value.
    /// @return The calculated y value.
    function _calcY(uint256 x, uint128 xscale) private pure returns (uint256) {
        uint256 _x = x * xscale;
        if (_x >= LibFixedPointMath.MAX_EXP_INPUT) {
            revert L2_1559_OUT_OF_STOCK();
        }
        return uint256(LibFixedPointMath.exp(int256(_x)));
    }
}
