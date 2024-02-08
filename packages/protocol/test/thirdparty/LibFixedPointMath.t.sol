// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

/// @author Kirk Baird <kirk@sigmaprime.io>
contract TestLibFixedPointMath is TaikoTest {
    function test_exp() external {
        assertEq(LibFixedPointMath.exp(1e18), 2_718_281_828_459_045_235); // 2.718281828459045235
        assertEq(LibFixedPointMath.exp(2e18), 7_389_056_098_930_650_227); // 7.389056098930650227
        assertEq(LibFixedPointMath.exp(0), 1_000_000_000_000_000_000); // 1
        assertEq(LibFixedPointMath.exp(-1e18), 367_879_441_171_442_321); // 0.3678794411714423216
        assertEq(LibFixedPointMath.exp(1), 1_000_000_000_000_000_001); //1.000000000000000001
        assertEq(LibFixedPointMath.exp(-1), 999_999_999_999_999_999); //0.9999999999999999990

        // accurate up to 1e-16%
        assertApproxEqRel(
            LibFixedPointMath.exp(135e18),
            42_633_899_483_147_210_448_936_866_880_765_989_356_468_745_853_255_281_087_440_011_736_227_864_297_277,
            1
        ); // 42633899483147210448936866880765989356468745853255281087440.011736227864297277

        // accurate up to 1e-16%
        assertApproxEqRel(
            LibFixedPointMath.exp(135_305_999_368_893_231_588),
            57_896_044_618_658_097_649_816_762_928_942_336_782_129_491_980_154_662_247_847_962_410_455_084_893_091,
            1
        ); // 57896044618658097649816762928942336782129491980154662247847.962410455084893091

        assertEq(LibFixedPointMath.exp(-40e18), 4);

        // returns 0 if result is <0.5
        assertEq(LibFixedPointMath.exp(-42_139_678_854_452_767_552), 0);
    }

    function test_exp_overflow() external {
        vm.expectRevert(LibFixedPointMath.Overflow.selector);
        LibFixedPointMath.exp(135_305_999_368_893_231_589); // max input is 135305999368893231588
    }
}
