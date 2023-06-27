// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { Lib1559Math as T } from "../contracts/libs/Lib1559Math.sol";
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

contract TestLib1559Math is Test {
    using SafeCastUpgradeable for uint256;

    function test1559_2X1XRatio(uint16 rand) public {
        vm.assume(rand != 0);

        uint64 xExcessMax = (uint256(15_000_000) * 256 * rand).toUint64();
        uint64 xTarget = (uint256(6_000_000) * rand).toUint64();
        uint64 price0 = (uint256(5_000_000_000) * rand).toUint64();
        uint64 ratio2x1x = 11_177;
        (uint128 xscale, uint128 yscale) = T.calculateScales({
            xExcessMax: xExcessMax,
            price: price0,
            target: xTarget,
            ratio2x1x: ratio2x1x
        });

        // basefee should be 0 when xExcess is 0
        assertEq(T.calculatePrice(xscale, yscale, 0, xTarget), 0);

        uint64 N = 50;
        // In the [xExcessMax/2 - 50 * xTarget, xExcessMax/2 + 50 * xTarget]
        // x range, the ratio2x1x holds, and the price is still smaller
        // than uint64.max
        for (
            uint64 xExcess = xExcessMax / 2 - N * xTarget;
            xExcess <= xExcessMax / 2 + N * xTarget;
            xExcess += xTarget
        ) {
            uint256 basefee1 =
                T.calculatePrice(xscale, yscale, xExcess, xTarget);
            assertLt(basefee1, type(uint64).max);

            uint256 basefee2 =
                T.calculatePrice(xscale, yscale, xExcess, 2 * xTarget);

            assertLt(basefee2, type(uint64).max);

            if (basefee1 != 0) {
                assertEq((basefee2 * 10_000) / basefee1, ratio2x1x);
            }
        }
    }

    function test1559_SpecalCases(uint16 rand) public {
        vm.assume(rand != 0);

        uint64 xExcessMax = (uint256(15_000_000) * 256 * rand).toUint64();
        uint64 xTarget = (uint256(6_000_000) * rand).toUint64();
        uint64 price0 = (uint256(5_000_000_000) * rand).toUint64();
        uint64 ratio2x1x = 11_177;

        (uint128 xscale, uint128 yscale) = T.calculateScales({
            xExcessMax: xExcessMax,
            price: price0,
            target: xTarget,
            ratio2x1x: ratio2x1x
        });

        assertEq(T.calculatePrice(xscale, yscale, 0, 0), 0);
        assertEq(T.calculatePrice(xscale, yscale, 0, 1), 0);

        assertGt(
            T.calculatePrice(xscale, yscale, xExcessMax - xTarget, xTarget),
            type(uint64).max
        );

        assertGt(
            T.calculatePrice(xscale, yscale, 0, xExcessMax), type(uint64).max
        );

        assertGt(
            T.calculatePrice(xscale, yscale, xExcessMax / 2, xExcessMax / 2),
            type(uint64).max
        );
    }
}
