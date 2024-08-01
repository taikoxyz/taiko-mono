// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract TestLib1559Math is TaikoTest {
    using LibMath for uint256;

    uint256 public constant gips = 2_000_000; // gas issuance per second
    uint256 public constant quotient = 4;
    uint256 public constant target = gips * quotient;

    function test_ethQty() external {
        assertEq(Lib1559Math.ethQty(0, 60_000_000 / 8), 1);
        assertEq(Lib1559Math.ethQty(60_000_000, 60_000_000 / 8), 2980);
        assertEq(Lib1559Math.ethQty(60_000_000 * 2, 60_000_000 / 8), 8_886_110);
        assertEq(Lib1559Math.ethQty(60_000_000 * 3, 60_000_000 / 8), 26_489_122_129);
        assertEq(Lib1559Math.ethQty(60_000_000 * 4, 60_000_000 / 8), 78_962_960_182_680);
        assertEq(
            Lib1559Math.ethQty(60_000_000 * 10, 60_000_000 / 8),
            55_406_223_843_935_100_525_863_115_942_268_902
        );
        assertEq(
            Lib1559Math.ethQty(60_000_000 * 100, 60_000_000 / 8),
            57_896_044_618_658_097_650_144_101_621_524_338_577_433_870_140_581_303_254_786
        );
    }

    function test_basefee() external {
        uint256 basefee;
        for (uint256 i; basefee <= 5000;) {
            // uint 0.01 gwei
            basefee = Lib1559Math.basefee(i * gips, target) / 10_000_000;
            if (basefee != 0) {
                console2.log("basefee (uint 0.01gwei) after", i, "seconds:", basefee);
            }
            i += 12;
        }
    }

    function test_eip1559_math() external pure {
        LibL2Config.Config memory config = LibL2Config.get();

        uint256 adjustmentFactor = config.gasTargetPerL1Block * config.basefeeAdjustmentQuotient;

        uint256 baseFee;
        uint256 i;
        uint256 target = 0.01 gwei;

        for (uint256 k; k < 5; ++k) {
            for (; baseFee < target; ++i) {
                baseFee = Lib1559Math.basefee(config.gasTargetPerL1Block * i, adjustmentFactor);
            }
            console2.log("base fee:", baseFee);
            console2.log("    gasExcess:", config.gasTargetPerL1Block * i);
            console2.log("    i:", i);
            target *= 10;
        }
    }

    function test_eip1559_math_max() external pure {
        LibL2Config.Config memory config = LibL2Config.get();
        uint256 adjustmentFactor = config.gasTargetPerL1Block * config.basefeeAdjustmentQuotient;

        uint256 gasExcess = type(uint64).max;
        uint256 baseFee = Lib1559Math.basefee(gasExcess, adjustmentFactor);

        console2.log("base fee (gwei):", baseFee / 1 gwei);
        console2.log("    gasExcess:", gasExcess);
    }
}
