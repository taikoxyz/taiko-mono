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
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

    function test_calculateBondInstruction_onTime_dueToSequentialDelay_returnsNone() public {
        // Sequential deadline extends liveness window past proving window
        uint48 priorFinalizedTimestamp = PROPOSAL_TIMESTAMP - uint48(2 hours);
        uint48 maxProofSubmissionDelay = uint48(3 hours);
        vm.warp(uint256(priorFinalizedTimestamp) + maxProofSubmissionDelay);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            PROPOSAL_ID,
            PROPOSAL_TIMESTAMP,
            priorFinalizedTimestamp,
            maxProofSubmissionDelay,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.NONE));
    }

    function test_calculateBondInstruction_late_returnsLiveness() public {
        vm.warp(uint256(PROPOSAL_TIMESTAMP) + PROVING_WINDOW + 1);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            PROPOSAL_ID,
            PROPOSAL_TIMESTAMP,
            PRIOR_FINALIZED_TIMESTAMP,
            MAX_PROOF_SUBMISSION_DELAY,
            DESIGNATED_PROVER,
            ACTUAL_PROVER,
            PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.LIVENESS));
        assertEq(result.proposalId, PROPOSAL_ID);
        assertEq(result.payer, DESIGNATED_PROVER);
        assertEq(result.payee, ACTUAL_PROVER);
    }

    function test_calculateBondInstruction_payerEqualsPayee_returnsLiveness() public {
        vm.warp(uint256(PROPOSAL_TIMESTAMP) + PROVING_WINDOW + 1);

        LibBonds.BondInstruction memory result = LibBondInstruction.calculateBondInstruction(
            PROPOSAL_ID,
            PROPOSAL_TIMESTAMP,
            PRIOR_FINALIZED_TIMESTAMP,
            MAX_PROOF_SUBMISSION_DELAY,
            DESIGNATED_PROVER,
            DESIGNATED_PROVER,
            PROVING_WINDOW
        );

        assertEq(uint8(result.bondType), uint8(LibBonds.BondType.LIVENESS));
        assertEq(result.payer, DESIGNATED_PROVER);
        assertEq(result.payee, DESIGNATED_PROVER);
    }
}
