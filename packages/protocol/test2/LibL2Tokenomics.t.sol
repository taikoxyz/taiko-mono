// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LibL2Tokenomics as T} from "../contracts/L1/libs/LibL2Tokenomics.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {
    LibFixedPointMath as M
} from "../contracts/thirdparty/LibFixedPointMath.sol";

contract TestLibL2Tokenomics is Test {
    using SafeCastUpgradeable for uint256;

    function test1559_2X1XRatio(uint16 rand) public {
        vm.assume(rand != 0);

        uint64 gasExcessMax = (uint(15000000) * 256 * rand).toUint64();
        uint64 gasTarget = (uint(6000000) * rand).toUint64();
        uint64 basefeeInitial = (uint(5000000000) * rand).toUint64();
        uint64 expected2X1XRatio = 111;
        (uint64 xscale, uint256 yscale) = T.calcL2BasefeeParams({
            gasExcessMax: gasExcessMax,
            basefeeInitial: basefeeInitial,
            gasTarget: gasTarget,
            expected2X1XRatio: expected2X1XRatio
        });

        // basefee should be 0 when gasExcess is 0
        assertEq(T.calcL2Basefee(0, xscale, yscale, gasTarget), 0);

        uint64 N = 50;
        // In the [gasExcessMax/2 - 50 * gasTarget, gasExcessMax/2 + 50 * gasTarget]
        // gas range, the expected2X1XRatio holds.
        for (
            uint64 l2GasExcess = gasExcessMax / 2 - N * gasTarget;
            l2GasExcess <= gasExcessMax / 2 + N * gasTarget;
            l2GasExcess += gasTarget
        ) {
            uint256 basefee1 = T.calcL2Basefee(
                l2GasExcess,
                xscale,
                yscale,
                gasTarget
            );
            uint256 basefee2 = T.calcL2Basefee(
                l2GasExcess,
                xscale,
                yscale,
                2 * gasTarget
            );

            if (basefee1 != 0) {
                assertEq((basefee2 * 100) / basefee1, expected2X1XRatio);
            }
        }
    }

    function test1559_SpecalCases(uint16 rand) public {
        vm.assume(rand != 0);

        uint64 gasExcessMax = (uint(15000000) * 256 * rand).toUint64();
        uint64 gasTarget = (uint(6000000) * rand).toUint64();
        uint64 basefeeInitial = (uint(5000000000) * rand).toUint64();
        uint64 expected2X1XRatio = 111;

        (uint64 xscale, uint256 yscale) = T.calcL2BasefeeParams({
            gasExcessMax: gasExcessMax,
            basefeeInitial: basefeeInitial,
            gasTarget: gasTarget,
            expected2X1XRatio: expected2X1XRatio
        });

        assertEq(T.calcL2Basefee(0, xscale, yscale, 0), 0);
        assertEq(T.calcL2Basefee(0, xscale, yscale, 1), 0);

        assertGt(
            T.calcL2Basefee(
                gasExcessMax - gasTarget,
                xscale,
                yscale,
                gasTarget
            ),
            type(uint64).max
        );

        assertGt(
            T.calcL2Basefee(0, xscale, yscale, gasExcessMax),
            type(uint64).max
        );

        assertGt(
            T.calcL2Basefee(gasExcessMax / 2, xscale, yscale, gasExcessMax / 2),
            type(uint64).max
        );
    }
}
