// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LibL2Tokenomics} from "../contracts/L1/libs/LibL2Tokenomics.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

contract TestLibL2Tokenomics is Test {
    using SafeCastUpgradeable for uint256;

    uint64 initialBaseFee = 5000000000;
    uint32 gasTargetPerSecond = 1000000;
    uint64 gasExcess = gasTargetPerSecond * 100;
    uint256 gasPoolProduct = uint(gasExcess) * uint(gasExcess) * initialBaseFee;

    function test1559Basefee() public {
        (uint64 basefee1, uint256 cost1) = _purchaseGas(
            gasTargetPerSecond * 12,
            12
        );

        (uint64 basefee2, uint256 cost2) = _purchaseGas(
            gasTargetPerSecond * 12,
            12
        );

        assertEq(basefee1, basefee2);
        assertEq(cost1, cost2);

        (uint64 basefee3, uint256 cost3) = _purchaseGas(1, 12);

        console2.log("when purchase a block of size: 1");
        console2.log(
            "basefee decreases by:",
            100 - (basefee3 * 100) / basefee2
        );

        (uint64 basefee4, uint256 cost4) = _purchaseGas(
            gasTargetPerSecond * 24,
            0
        );

        console2.log("when purchase a block of size: 2 * target");
        console2.log(
            "basefee increases by:",
            (basefee4 * 100) / basefee2 - 100
        );

        uint64 basefee;
        for (uint i = 0; i < 5; i++) {
            (uint64 _basefee, ) = _purchaseGas(gasTargetPerSecond * 12, 0);
            assertGt(_basefee, basefee);
            if (basefee > 0) {
                console2.log(
                    "gas price",
                    (_basefee * 100) / basefee - 100,
                    "% larger than parent"
                );
            }
            basefee = _basefee;
        }
    }

    function _purchaseGas(
        uint32 amount,
        uint64 blockTime
    ) private returns (uint64 basefee, uint256 gasPurchaseCost) {
        (gasExcess, basefee, gasPurchaseCost) = LibL2Tokenomics.calc1559Basefee(
            gasExcess,
            gasTargetPerSecond,
            gasPoolProduct,
            amount,
            blockTime
        );
    }
}
