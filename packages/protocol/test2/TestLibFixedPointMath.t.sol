// SPDX-License-Identifier: UNLICENSED
// Some of the tests are taken from:
// https://github.com/recmo/experiment-solexp/blob/main/src/test/FixedPointMathLib.t.sol
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import "../contracts/thirdparty/LibFixedPointMath.sol";

contract LibFixedPointMathTest is Test {
    function setUp() public {}

    function testLn1() public {
        assertEq(LibFixedPointMath.ln(1e18), 0);
    }

    function testLn() public {
        assertEq(LibFixedPointMath.ln(1e18), 0);

        // Actual: 999999999999999999.8674576…
        assertEq(LibFixedPointMath.ln(2718281828459045235), 999999999999999999);

        // Actual: 2461607324344817917.963296…
        assertEq(
            LibFixedPointMath.ln(11723640096265400935),
            2461607324344817918
        );
    }

    function testLnSmall() public {
        // Actual: -41446531673892822312.3238461…
        assertEq(LibFixedPointMath.ln(1), -41446531673892822313);

        // Actual: -37708862055609454006.40601608…
        assertEq(LibFixedPointMath.ln(42), -37708862055609454007);

        // Actual: -32236191301916639576.251880365581…
        assertEq(LibFixedPointMath.ln(1e4), -32236191301916639577);

        // Actual: -20723265836946411156.161923092…
        assertEq(LibFixedPointMath.ln(1e9), -20723265836946411157);
    }

    function testLnBig() public {
        // Actual: 135305999368893231589.070344787…
        assertEq(LibFixedPointMath.ln(2 ** 255 - 1), 135305999368893231589);

        // Actual: 76388489021297880288.605614463571…
        assertEq(LibFixedPointMath.ln(2 ** 170), 76388489021297880288);

        // Actual: 47276307437780177293.081865…
        assertEq(LibFixedPointMath.ln(2 ** 128), 47276307437780177293);
    }

    function testLnGas() public {
        uint256 count = 0;
        uint256 sum = 0;
        uint256 sum_sq = 0;
        for (uint256 i = 1; i < 255; i++) {
            int256 k = int256(1 << i) - 1;
            uint g0 = gasleft();
            LibFixedPointMath.ln(k);
            uint g1 = gasleft();
            sum += g0 - g1;
            sum_sq += (g0 - g1) * (g0 - g1);
            ++count;
            ++k;
            g0 = gasleft();
            LibFixedPointMath.ln(k);
            g1 = gasleft();
            sum += g0 - g1;
            sum_sq += (g0 - g1) * (g0 - g1);
            ++count;
            ++k;
            g0 = gasleft();
            LibFixedPointMath.ln(k);
            g1 = gasleft();
            sum += g0 - g1;
            sum_sq += (g0 - g1) * (g0 - g1);
            ++count;
        }
        console2.log("gas", sum / count);
        console2.log("gas_var", (sum_sq - (sum * sum) / count) / (count - 1));
    }

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

    // function testExpExtra() public {
    //     assertEq(LibFixedPointMath.exp(1*1E18), 2*1E18);
    //     assertEq(LibFixedPointMath.exp(0), 1*1E18);
    //     assertEq(LibFixedPointMath.exp(100*1E18), 26881171*1E54);
    //     assertEq(LibFixedPointMath.exp(1000000*1E18), 26881171*1E54);
    //     // assertEq(LibFixedPointMath.exp(1000*1E18), 22026465794800000000000);
    //     // assertEq(LibFixedPointMath.exp(10000*1E18), 22026465794800000000000);
    // }
}
