// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract TestLib1559Math is TaikoTest {
    using LibMath for uint256;

    function test_ethQty() external {
        assertEq(Lib1559Math.ethQty(0, 60_000_000 * 8), 1);
        assertEq(Lib1559Math.ethQty(60_000_000, 60_000_000 * 8), 1);
        assertEq(Lib1559Math.ethQty(60_000_000 * 100, 60_000_000 * 8), 268_337);
        assertEq(Lib1559Math.ethQty(60_000_000 * 200, 60_000_000 * 8), 72_004_899_337);
    }

    function test_basefee() external pure {
        uint256 basefee;
        for (uint256 i; basefee <= 5000;) {
            // uint 0.01 gwei
            basefee = Lib1559Math.basefee(i * 2_000_000, 2_000_000 * 4) / 10_000_000;
            if (basefee != 0) {
                console2.log("basefee (uint 0.01gwei) after", i, "seconds:", basefee);
            }
            i += 1;
        }
    }

    function test_change_of_quotient_and_gips() public pure {
        uint256 excess = 150 * 2_000_000;

        // uint 0.01 gwei
        uint256 basefee = Lib1559Math.basefee(excess, 2_000_000 * 4) / 10_000_000;
        console2.log("basefee (uint 0.01gwei) with quotient = 4: ", basefee);

        /// basefee will decrease if (gas_issued_per_second * quotient) increases.
        basefee = Lib1559Math.basefee(excess, 2_000_000 * 8) / 10_000_000;
        console2.log("basefee (uint 0.01gwei) with quotient = 8: ", basefee);
        basefee = Lib1559Math.basefee(excess, 4_000_000 * 4) / 10_000_000;
        console2.log("basefee (uint 0.01gwei) with gips = 4_000_000: ", basefee);

        // basefee will increase if (gas_issued_per_second * quotient) decreases.
        basefee = Lib1559Math.basefee(excess, 2_000_000 * 2) / 10_000_000;
        console2.log("basefee (uint 0.01gwei) with quotient = 2: ", basefee);
        basefee = Lib1559Math.basefee(excess, 1_000_000 * 4) / 10_000_000;
        console2.log("basefee (uint 0.01gwei) with gips = 1_000_000: ", basefee);

        /// basefee will remain the same if (gas_issued_per_second * quotient) remains the same.
        basefee = Lib1559Math.basefee(excess, 4_000_000 * 2) / 10_000_000;
        console2.log("basefee (uint 0.01gwei) ", basefee);
    }
}
