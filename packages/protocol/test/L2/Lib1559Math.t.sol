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
            basefee = Lib1559Math.basefee(i * 5_000_000, 5_000_000 * 8) / 10_000_000;
            if (basefee != 0) {
                console2.log("basefee (uint 0.01gwei) after", i, "seconds:", basefee);
            }
            i += 1;
        }
    }

    function test_change_of_quotient_and_gips() public {
        uint64 excess = 150 * 2_000_000;
        uint64 target = 4 * 2_000_000;
        uint256 unit = 10_000_000; // 0.01 gwei

        // uint 0.01 gwei
        uint256 baselineBasefee = Lib1559Math.basefee(excess, target) / unit;
        console2.log("baseline basefee: ", baselineBasefee);

        uint256 basefee = Lib1559Math.basefee(excess, target * 2) / unit;
        console2.log("basefee will decrease if target increases:", basefee);

        basefee = Lib1559Math.basefee(excess, target / 2) / unit;
        console2.log("basefee will increase if target decreases:", basefee);

        console2.log("maintain basefee when target increases");
        {
            uint64 newTarget = 5 * 2_000_000;
            uint64 newExcess = Lib1559Math.adjustExcess(excess, target, newTarget);
            basefee = Lib1559Math.basefee(newExcess, newTarget) / unit;
            console2.log("new gas excess: ", newExcess);
            console2.log("basefee: ", basefee);
            assertEq(baselineBasefee, basefee);
        }

        console2.log("maintain basefee when target decreases");
        {
            uint64 newTarget = 3 * 2_000_000;
            uint64 newExcess = Lib1559Math.adjustExcess(excess, target, newTarget);
            basefee = Lib1559Math.basefee(newExcess, newTarget) / unit;
            console2.log("new gas excess: ", newExcess);
            console2.log("basefee: ", basefee);
            assertEq(baselineBasefee, basefee);
        }
    }
}
