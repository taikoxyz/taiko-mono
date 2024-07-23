// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract TestLib1559Math is TaikoTest {
    using LibMath for uint256;

    uint32 public constant gasTargetPerL1Block = 60_000_000;
    uint8 public constant basefeeAdjustmentQuotient = 8;

    function test_eip1559_math() external pure {
        uint256 adjustmentFactor = gasTargetPerL1Block * basefeeAdjustmentQuotient;

        uint256 baseFee;
        uint256 i;
        uint256 target = 0.01 gwei;

        for (uint256 k; k < 5; ++k) {
            for (; baseFee < target; ++i) {
                baseFee = Lib1559Math.basefee(gasTargetPerL1Block * i, adjustmentFactor);
            }
            console2.log("base fee:", baseFee);
            console2.log("    gasExcess:", gasTargetPerL1Block * i);
            console2.log("    i:", i);
            target *= 10;
        }
    }

    function test_eip1559_math_max() external pure {
        uint256 adjustmentFactor = gasTargetPerL1Block * basefeeAdjustmentQuotient;

        uint256 gasExcess = type(uint64).max;
        uint256 baseFee = Lib1559Math.basefee(gasExcess, adjustmentFactor);

        console2.log("base fee (gwei):", baseFee / 1 gwei);
        console2.log("    gasExcess:", gasExcess);
    }
}
