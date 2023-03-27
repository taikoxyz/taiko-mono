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

    // Ethereum offers 15M gas per 12 seconds, if we scale it by 24 times,
    // then each second, Taiko can offer 30M gas.

    uint32 gasTargetPerSecond = 30000000; // 30M gas per second
    uint64 gasExcess0 = uint64(gasTargetPerSecond) * 200;
    uint256 gasPoolProduct =
        uint(gasExcess0) * uint(gasExcess0) * initialBaseFee;

    uint64 gasExcess = gasExcess0;

    function setUp() public view {
        console2.log("gasPoolProduct:", gasPoolProduct);
    }

    function test1559PurchaseMaxSizeGasWontOverflow() public {
        gasExcess = type(uint64).max;

        (uint64 basefee, uint256 cost) = _purchaseGas(
            type(uint32).max,
            0 seconds
        );
        assertEq(basefee, 0);
        assertEq(cost, 0);
        gasExcess = gasExcess0;
    }

    function test1559Basefee_NoChangeAfterRefillTheSameAmount() public {
        (uint64 basefee1, uint256 cost1) = _purchaseGas(
            gasTargetPerSecond * 12,
            12 seconds
        );

        (uint64 basefee2, uint256 cost2) = _purchaseGas(
            gasTargetPerSecond * 12,
            12 seconds
        );

        assertEq(basefee1, basefee2);
        assertEq(cost1, cost2);
        gasExcess = gasExcess0;
    }

    function test1559Basefee_Compare_T_vs_2T() public {
        uint32 blockMaxGasLimit = 6000000;

        (uint64 basefee, ) = _purchaseGas(1, 24 seconds);
        gasExcess = gasExcess0;

        (uint64 basefeeT, ) = _purchaseGas(blockMaxGasLimit / 2, 0 seconds);
        gasExcess = gasExcess0;

        (uint64 basefee2T, ) = _purchaseGas(blockMaxGasLimit, 0 seconds);
        gasExcess = gasExcess0;

        console2.log("when purchase a block of size blockMaxGasLimit/2:");
        console2.log(
            unicode"👉 basefee increases by %%:",
            (basefeeT * 100) / basefee - 100
        );

        console2.log("when purchase a block of size blockMaxGasLimit:");
        console2.log(
            unicode"👉 basefee increases by %%:",
            (basefee2T * 100) / basefee - 100
        );
    }

    function test1559Basefee_EverIncreaseing() public {
        uint64 basefee;
        for (uint i = 0; i < 5; i++) {
            (uint64 _basefee, ) = _purchaseGas(gasTargetPerSecond * 12, 0);
            assertGt(_basefee, basefee);
            if (basefee > 0) {
                console2.log(
                    unicode"👉 gas price %%",
                    (_basefee * 100) / basefee - 100,
                    "larger than parent"
                );
            }
            basefee = _basefee;
        }
        gasExcess = gasExcess0;
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
