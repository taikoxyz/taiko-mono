// SPDX-License-Identifier: UNLICENSED
// Some of the tests are taken from:
// https://github.com/recmo/experiment-solexp/blob/main/src/test/FixedPointMathLib.t.sol
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import "../contracts/thirdparty/LibFixedPointMath.sol";

contract LibFixedPointMathTest is Test {
    function setUp() public {}

    function testExp1() public {
        assertEq(LibFixedPointMath.exp(-1e18), 367879441171442321);
    }

    function testExpSmallest() public {
        LibFixedPointMath.exp(-42139678854452767550);
    }

    function testExpLargest() public {
        LibFixedPointMath.exp(135305999368893231588);
    }

    function testExpSome() public {
        console2.logInt(LibFixedPointMath.exp(5e18));
    }

    function testExpGas() public {
        uint g0 = gasleft();
        LibFixedPointMath.exp(133e18);
        uint g1 = gasleft();
        LibFixedPointMath.exp(-23e18);
        uint g2 = gasleft();
        LibFixedPointMath.exp(5e18);
        uint g3 = gasleft();
        console2.logUint(g0 - g1);
        console2.logUint(g1 - g2);
        console2.logUint(g2 - g3);
    }

    function testExp3() public {
        LibFixedPointMath.exp(133e18);
        LibFixedPointMath.exp(10e18);
        LibFixedPointMath.exp(-23e18);
    }
}
