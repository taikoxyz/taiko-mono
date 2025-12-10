// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibBondInstruction } from "src/layer1/core/libs/LibBondInstruction.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

contract LibBondsTest is Test {
    uint48 constant PROVING_WINDOW = 1 hours;
    uint48 constant EXTENDED_PROVING_WINDOW = 2 hours;

    address constant PROPOSER = address(0x1);
    address constant DESIGNATED_PROVER = address(0x2);
    address constant ACTUAL_PROVER = address(0x3);

    // ---------------------------------------------------------------
    // calculateBondInstruction tests
    // ---------------------------------------------------------------

    function test_calculateBondInstruction_onTime_returnsNone() public pure {
        // proposalAge exactly at proving window boundary
        uint256 proposalAge = PROVING_WINDOW;

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            1,
            proposalAge,
            PROPOSER,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

    function test_calculateBondInstruction_lateWithinExtended_returnsLiveness() public pure {
        // proposalAge just past proving window but within extended window
        uint256 proposalAge = PROVING_WINDOW + 1;

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            1,
            proposalAge,
            PROPOSER,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.LIVENESS));
        assertEq(result.payer, DESIGNATED_PROVER);
        assertEq(result.payee, ACTUAL_PROVER);
    }

    function test_calculateBondInstruction_veryLate_returnsProvability() public pure {
        // proposalAge past extended proving window
        uint256 proposalAge = EXTENDED_PROVING_WINDOW + 1;

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            1,
            proposalAge,
            PROPOSER,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.PROVABILITY));
        assertEq(result.payer, PROPOSER);
        assertEq(result.payee, ACTUAL_PROVER);
    }

    function test_calculateBondInstruction_samePayerPayee_returnsNone() public pure {
        // Late proof but designated prover proves their own block
        uint256 proposalAge = PROVING_WINDOW + 1;

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            1,
            proposalAge,
            PROPOSER,
            DESIGNATED_PROVER,
            DESIGNATED_PROVER, // actual prover same as designated
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        // No bond movement when payer == payee
        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

    function test_calculateBondInstruction_proposerProvesLate_returnsNone() public pure {
        // Very late but proposer proves their own block
        uint256 proposalAge = EXTENDED_PROVING_WINDOW + 1;

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            1,
            proposalAge,
            PROPOSER,
            DESIGNATED_PROVER,
            PROPOSER, // actual prover same as proposer
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        // No bond movement when payer == payee
        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

    function test_calculateBondInstruction_atExtendedWindowBoundary_returnsLiveness() public pure {
        // proposalAge exactly at extended window boundary (still within)
        uint256 proposalAge = EXTENDED_PROVING_WINDOW;

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            1,
            proposalAge,
            PROPOSER,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.LIVENESS));
        assertEq(result.payer, DESIGNATED_PROVER);
        assertEq(result.payee, ACTUAL_PROVER);
    }
}
