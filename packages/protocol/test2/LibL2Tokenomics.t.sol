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

    function test1559_basefeeMayBeZero() public {
        uint64 gasExcessMax = 15000000 * 256;
        uint64 gasTarget = 6000000;
        uint64 basefeeInitial = 5000000000;
        uint64 expected2X1XRatio = 111;

        (uint64 l2GasExcess, uint64 xscale, uint256 yscale) = T
            .calcL2BasefeeParams({
                gasExcessMax: gasExcessMax,
                basefeeInitial: basefeeInitial,
                gasTarget: gasTarget,
                expected2X1XRatio: expected2X1XRatio
            });

        // basefee should be 0 when gasExcess is 0
        assertEq(T.calcL2Basefee(0, xscale, yscale, gasTarget), 0);

        // In the [gasExcessMax/2 - 50 * gasTarget, gasExcessMax/2 + 50 * gasTarget]
        // gas range, the expected2X1XRatio holds.
        l2GasExcess = gasExcessMax / 2 - 50 * gasTarget;

        while (l2GasExcess <= gasExcessMax / 2 + 50 * gasTarget) {
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

            if (basefee1 != 0 && basefee2 != 0) {
                assertEq((basefee2 * 100) / basefee1, expected2X1XRatio);
            }

            l2GasExcess += gasTarget;
        }
    }

    // function test1559PurchaseMaxSizeGasWontOverflow() public view {
    //     uint64 basefeeInitial = 5000000000;
    //     uint64 gasTarget = 6000000;

    //     (uint64 _l2GasExcess, uint64 xscale, uint256 yscale) = T
    //         .calcL2BasefeeParams({
    //             gasExcessMax: 15000000 * 256,
    //             basefeeInitial: basefeeInitial,
    //             gasTarget: gasTarget,
    //             expected2X1XRatio: 111
    //         });

    //     uint64 l2GasExcess = 0;
    //     uint64 basefee = 0;

    //     for (uint i = 0; i < 1 ; ++i) {

    //         uint64 basefee = T
    //             .calcL2Basefee(l2GasExcess, xscale, yscale, gasTarget)
    //             .toUint64();

    //         // uint ratio = (newBasefee * 100) / _basefee;
    //         console2.log(i,l2GasExcess, "basefee", basefee);//, "+%", ratio);
    //         // basefee = newBasefee;

    //         // if (uint256(l2GasExcess) + gasTarget > type(uint64).max) break;
    //         // l2GasExcess += gasTarget;
    //     }
    // }
}
