// SPDX-License-Identifier: MIT
// Some of the tests are taken from:
// https://github.com/recmo/experiment-solexp/blob/main/src/test/FixedPointMathLib.t.sol
pragma solidity 0.8.24;

import "../TaikoTest.sol";
import { LibVestAndUnlock as L } from "../../contracts/team/LibVestAndUnlock.sol";

contract LibVestAndUnlockTest is TaikoTest {
    function test_calcVestedAmount_non0_vestDuration() public {
        uint256 g = 1e18;
        assertEq(L.calcVestedAmount(g, 100 days, 0), 0);
        assertEq(L.calcVestedAmount(g, 100 days, 100 days), g);
        assertEq(L.calcVestedAmount(g, 100 days, 100 days + 1 seconds), g);
        assertEq(L.calcVestedAmount(g, 100 days, 10 days), g / 10);
        assertEq(L.calcVestedAmount(g, 100 days, 90 days), g * 9 / 10);
    }

    function test_calcVestedAmount_0_vestDuration() public {
        uint256 g = 1e18;
        assertEq(L.calcVestedAmount(g, 0 days, 0), g);
        assertEq(L.calcVestedAmount(g, 0 days, 100 days), g);
        assertEq(L.calcVestedAmount(g, 0 days, 100 days + 1 seconds), g);
        assertEq(L.calcVestedAmount(g, 0 days, 10 days), g);
        assertEq(L.calcVestedAmount(g, 0 days, 90 days), g);
    }

    function test_calcUnlockedAmount_vestDuration_larger_than_unlockDuration() public {
        uint256 g = 1e18;
        assertEq(L.calcUnlockedAmount(g, 40 days, 10 days, 0), 0);
        assertEq(L.calcUnlockedAmount(g, 40 days, 10 days, 5 days), g / 4 / 8);
        assertEq(L.calcUnlockedAmount(g, 40 days, 10 days, 10 days), g / 8);
        assertEq(L.calcUnlockedAmount(g, 40 days, 10 days, 20 days), g * 3 / 8);
        assertEq(L.calcUnlockedAmount(g, 40 days, 10 days, 30 days), g * 5 / 8);
        assertEq(L.calcUnlockedAmount(g, 40 days, 10 days, 40 days), g * 7 / 8);
        assertEq(L.calcUnlockedAmount(g, 40 days, 10 days, 45 days), g - g / 4 / 8);
        assertEq(L.calcUnlockedAmount(g, 40 days, 10 days, 50 days), g);
        assertEq(L.calcUnlockedAmount(g, 40 days, 10 days, 50 days + 1 seconds), g);
    }

    function test_calcUnlockedAmount_vestDuration_smaller_than_unlockDuration() public {
        uint256 g = 1e18;
        assertEq(L.calcUnlockedAmount(g, 10 days, 40 days, 0), 0);
        assertEq(L.calcUnlockedAmount(g, 10 days, 40 days, 5 days), g / 4 / 8);
        assertEq(L.calcUnlockedAmount(g, 10 days, 40 days, 10 days), g / 8);
        assertEq(L.calcUnlockedAmount(g, 10 days, 40 days, 20 days), g * 3 / 8);
        assertEq(L.calcUnlockedAmount(g, 10 days, 40 days, 30 days), g * 5 / 8);
        assertEq(L.calcUnlockedAmount(g, 10 days, 40 days, 40 days), g * 7 / 8);
        assertEq(L.calcUnlockedAmount(g, 10 days, 40 days, 45 days), g - g / 4 / 8);
        assertEq(L.calcUnlockedAmount(g, 10 days, 40 days, 50 days), g);
        assertEq(L.calcUnlockedAmount(g, 10 days, 40 days, 50 days + 1 seconds), g);
    }

    function test_calcUnlockedAmount_0_vestDuration_non0_unlockDuration() public {
        uint256 g = 1e18;
        assertEq(L.calcUnlockedAmount(g, 0 days, 40 days, 0), 0);
        assertEq(L.calcUnlockedAmount(g, 0 days, 40 days, 5 days), g / 8);
        assertEq(L.calcUnlockedAmount(g, 0 days, 40 days, 10 days), g / 4);
        assertEq(L.calcUnlockedAmount(g, 0 days, 40 days, 20 days), g / 2);
        assertEq(L.calcUnlockedAmount(g, 0 days, 40 days, 30 days), g * 3 / 4);
        assertEq(L.calcUnlockedAmount(g, 0 days, 40 days, 40 days), g);
        assertEq(L.calcUnlockedAmount(g, 0 days, 40 days, 50 days + 1 seconds), g);
    }

    function test_calcUnlockedAmount_non0_vestDuration_0_unlockDuration() public {
        uint256 g = 1e18;
        assertEq(L.calcUnlockedAmount(g, 40 days, 0 days, 0), 0);
        assertEq(L.calcUnlockedAmount(g, 40 days, 0 days, 5 days), g / 8);
        assertEq(L.calcUnlockedAmount(g, 40 days, 0 days, 10 days), g / 4);
        assertEq(L.calcUnlockedAmount(g, 40 days, 0 days, 20 days), g / 2);
        assertEq(L.calcUnlockedAmount(g, 40 days, 0 days, 30 days), g * 3 / 4);
        assertEq(L.calcUnlockedAmount(g, 40 days, 0 days, 40 days), g);
        assertEq(L.calcUnlockedAmount(g, 40 days, 0 days, 50 days + 1 seconds), g);
    }
}
