// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibBondInstruction } from "src/layer1/core/libs/LibBondInstruction.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

contract LibBondsTest is Test {
    uint48 constant PROVING_WINDOW = 1 hours;
    uint48 constant EXTENDED_PROVING_WINDOW = 2 hours;

    address proposer = address(0x1);
    address designatedProver = address(0x2);
    address actualProver = address(0x3);

    // ---------------------------------------------------------------
    // calculateBondInstruction tests
    // ---------------------------------------------------------------

    function test_calculateBondInstruction_onTime_returnsNone() public {
        uint48 readyTimestamp = uint48(block.timestamp);

        // Prove within proving window
        vm.warp(readyTimestamp + PROVING_WINDOW);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            1, proposer, designatedProver, actualProver, readyTimestamp, PROVING_WINDOW, EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

    function test_calculateBondInstruction_lateWithinExtended_returnsLiveness() public {
        uint48 readyTimestamp = uint48(block.timestamp);

        // Prove after proving window but within extended window
        vm.warp(readyTimestamp + PROVING_WINDOW + 1);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            1, proposer, designatedProver, actualProver, readyTimestamp, PROVING_WINDOW, EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.LIVENESS));
        assertEq(result.payer, designatedProver);
        assertEq(result.payee, actualProver);
    }

    function test_calculateBondInstruction_veryLate_returnsProvability() public {
        uint48 readyTimestamp = uint48(block.timestamp);

        // Prove after extended proving window
        vm.warp(readyTimestamp + EXTENDED_PROVING_WINDOW + 1);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            1, proposer, designatedProver, actualProver, readyTimestamp, PROVING_WINDOW, EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.PROVABILITY));
        assertEq(result.payer, proposer);
        assertEq(result.payee, actualProver);
    }

    function test_calculateBondInstruction_samePayerPayee_returnsNone() public {
        uint48 readyTimestamp = uint48(block.timestamp);

        // Late proof but designated prover proves their own block
        vm.warp(readyTimestamp + PROVING_WINDOW + 1);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            1,
            proposer,
            designatedProver,
            designatedProver, // actual prover same as designated
            readyTimestamp,
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        // No bond movement when payer == payee
        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

}
