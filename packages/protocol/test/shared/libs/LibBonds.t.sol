// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibBondInstruction } from "src/layer1/core/libs/LibBondInstruction.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

contract LibBondsTest is Test {
    uint48 constant PROPOSAL_ID = 1;
    uint48 constant PROPOSAL_TIMESTAMP = 1_000_000;
    uint48 constant PRIOR_FINALIZED_TIMESTAMP = PROPOSAL_TIMESTAMP - uint48(30 minutes);
    uint48 constant MAX_PROOF_SUBMISSION_DELAY = uint48(5 minutes);
    uint48 constant PROVING_WINDOW = 1 hours;
    uint48 constant EXTENDED_PROVING_WINDOW = 2 hours;

    address constant PROPOSER = address(0x1);
    address constant DESIGNATED_PROVER = address(0x2);
    address constant ACTUAL_PROVER = address(0x3);

    // ---------------------------------------------------------------
    // calculateBondInstruction tests
    // ---------------------------------------------------------------

    function test_calculateBondInstruction_onTime_returnsNone() public {
        // Proof submitted at proving window boundary
        vm.warp(uint256(PROPOSAL_TIMESTAMP) + PROVING_WINDOW);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            PROPOSAL_ID,
            PROPOSAL_TIMESTAMP,
            PRIOR_FINALIZED_TIMESTAMP,
            MAX_PROOF_SUBMISSION_DELAY,
            PROPOSER,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

    function test_calculateBondInstruction_onTime_dueToSequentialDelay_returnsNone() public {
        // Sequential deadline extends liveness window past proving window
        uint48 priorFinalizedTimestamp = PROPOSAL_TIMESTAMP - uint48(5 minutes);
        uint48 maxProofSubmissionDelay = uint48(90 minutes);
        vm.warp(uint256(priorFinalizedTimestamp) + maxProofSubmissionDelay);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            PROPOSAL_ID,
            PROPOSAL_TIMESTAMP,
            priorFinalizedTimestamp,
            maxProofSubmissionDelay,
            PROPOSER,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

    function test_calculateBondInstruction_lateWithinExtended_returnsLiveness() public {
        vm.warp(uint256(PROPOSAL_TIMESTAMP) + PROVING_WINDOW + 1);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            PROPOSAL_ID,
            PROPOSAL_TIMESTAMP,
            PRIOR_FINALIZED_TIMESTAMP,
            MAX_PROOF_SUBMISSION_DELAY,
            PROPOSER,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.LIVENESS));
        assertEq(result.proposalId, PROPOSAL_ID);
        assertEq(result.payer, DESIGNATED_PROVER);
        assertEq(result.payee, ACTUAL_PROVER);
    }

    function test_calculateBondInstruction_veryLate_returnsProvability() public {
        vm.warp(uint256(PROPOSAL_TIMESTAMP) + EXTENDED_PROVING_WINDOW + 1);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            PROPOSAL_ID,
            PROPOSAL_TIMESTAMP,
            PRIOR_FINALIZED_TIMESTAMP,
            MAX_PROOF_SUBMISSION_DELAY,
            PROPOSER,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.PROVABILITY));
        assertEq(result.proposalId, PROPOSAL_ID);
        assertEq(result.payer, PROPOSER);
        assertEq(result.payee, ACTUAL_PROVER);
    }

    function test_calculateBondInstruction_samePayerPayee_returnsNone() public {
        // Late proof but designated prover proves their own block
        vm.warp(uint256(PROPOSAL_TIMESTAMP) + PROVING_WINDOW + 1);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            PROPOSAL_ID,
            PROPOSAL_TIMESTAMP,
            PRIOR_FINALIZED_TIMESTAMP,
            MAX_PROOF_SUBMISSION_DELAY,
            PROPOSER,
            DESIGNATED_PROVER,
            DESIGNATED_PROVER, // actual prover same as designated
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        // No bond movement when payer == payee
        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

    function test_calculateBondInstruction_proposerProvesLate_returnsNone() public {
        // Very late but proposer proves their own block
        vm.warp(uint256(PROPOSAL_TIMESTAMP) + EXTENDED_PROVING_WINDOW + 1);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            PROPOSAL_ID,
            PROPOSAL_TIMESTAMP,
            PRIOR_FINALIZED_TIMESTAMP,
            MAX_PROOF_SUBMISSION_DELAY,
            PROPOSER,
            DESIGNATED_PROVER,
            PROPOSER, // actual prover same as proposer
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        // No bond movement when payer == payee
        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

    function test_calculateBondInstruction_atExtendedWindowBoundary_returnsLiveness() public {
        vm.warp(uint256(PROPOSAL_TIMESTAMP) + EXTENDED_PROVING_WINDOW);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            PROPOSAL_ID,
            PROPOSAL_TIMESTAMP,
            PRIOR_FINALIZED_TIMESTAMP,
            MAX_PROOF_SUBMISSION_DELAY,
            PROPOSER,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW,
            EXTENDED_PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.LIVENESS));
        assertEq(result.proposalId, PROPOSAL_ID);
        assertEq(result.payer, DESIGNATED_PROVER);
        assertEq(result.payee, ACTUAL_PROVER);
    }
}
