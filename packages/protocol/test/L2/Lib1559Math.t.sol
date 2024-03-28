// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract TestLib1559Math is TaikoTest {
    using LibMath for uint256;

    function test_eip1559_math() external {
        uint256 gasTarget = 60_000_000;
        uint256 adjustmentQuotient = 8;
        uint256 adjustmentFactor = gasTarget * adjustmentQuotient;

        uint256 baseFee;
        uint256 i;
        for (; baseFee < 1 gwei; ++i) {
            baseFee = Lib1559Math.basefee(gasTarget * i, adjustmentFactor);
            console2.log("baseFee:", i, baseFee);
        }

        // basefee will reach 1 gwei if gasExcess > 19620000000
        console2.log("basefee will reach 1 gwei if gasExcess >", gasTarget * i);
        assertEq(i, 327);
    }
}
