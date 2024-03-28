// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract TestLib1559Math is TaikoTest {
    using LibMath for uint256;

    function test_eip1559_math() external {
        LibL2Config.Config memory config = LibL2Config.get();
        uint256 adjustmentFactor = config.gasTargetPerL1Block * config.basefeeAdjustmentQuotient;

        uint256 baseFee;
        uint256 i;

        baseFee = Lib1559Math.basefee(config.gasExcessMinValue, adjustmentFactor);
        assertEq(baseFee, 99_627_953); // slightly smaller than 0.1gwei
        console2.log("gasExcessMinValue:", config.gasExcessMinValue);
        console2.log("min base fee:", baseFee);

        for (; baseFee < 1 gwei; ++i) {
            baseFee = Lib1559Math.basefee(config.gasTargetPerL1Block * i, adjustmentFactor);
            console2.log("base fee:", i, baseFee);
        }

        // base fee will reach 1 gwei if gasExcess > 19620000000
        console2.log("base fee will reach 1 gwei if gasExcess >", config.gasTargetPerL1Block * i);
        assertEq(i, 327);

        for (; baseFee < 10 gwei; ++i) {
            baseFee = Lib1559Math.basefee(config.gasTargetPerL1Block * i, adjustmentFactor);
            console2.log("base fee:", i, baseFee);
        }

        // base fee will reach 10 gwei if gasExcess > 20760000000
        console2.log("base fee will reach 10 gwei if gasExcess >", config.gasTargetPerL1Block * i);
        assertEq(i, 346);
    }
}
