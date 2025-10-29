// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBondInstruction } from "src/layer1/core/libs/LibBondInstruction.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

contract LibBondInstructionTest is Test {
    address private constant DESIGNATED = address(0xD1);
    address private constant ACTUAL = address(0xA1);
    address private constant PROPOSER = address(0xB1);

    // ---------------------------------------------------------------
    // mergeBondInstructions
    // ---------------------------------------------------------------

    function test_mergeBondInstructions_UsesLoopCopyBelowThreshold() external pure {
        LibBonds.BondInstruction[] memory existing = new LibBonds.BondInstruction[](3);
        existing[0] = _makeInstruction(1, LibBonds.BondType.LIVENESS, PROPOSER, DESIGNATED);
        existing[1] = _makeInstruction(2, LibBonds.BondType.PROVABILITY, DESIGNATED, ACTUAL);
        existing[2] = _makeInstruction(3, LibBonds.BondType.NONE, DESIGNATED, ACTUAL);

        LibBonds.BondInstruction[] memory incoming = new LibBonds.BondInstruction[](2);
        incoming[0] = _makeInstruction(4, LibBonds.BondType.LIVENESS, ACTUAL, DESIGNATED);
        incoming[1] = _makeInstruction(5, LibBonds.BondType.PROVABILITY, DESIGNATED, PROPOSER);

        LibBonds.BondInstruction[] memory merged =
            LibBondInstruction.mergeBondInstructions(existing, incoming);

        assertEq(merged.length, 5, "Merged array should keep ordering");
        for (uint256 i; i < existing.length; ++i) {
            assertEq(merged[i].proposalId, existing[i].proposalId);
        }
        for (uint256 i; i < incoming.length; ++i) {
            assertEq(merged[existing.length + i].proposalId, incoming[i].proposalId);
        }

        // Ensure original arrays are untouched
        assertEq(uint8(existing[0].bondType), uint8(LibBonds.BondType.LIVENESS));
        assertEq(uint8(incoming[0].bondType), uint8(LibBonds.BondType.LIVENESS));
    }

    // ---------------------------------------------------------------
    // calculateBondInstructions
    // ---------------------------------------------------------------

    function test_calculateBondInstructions_ReturnsEmptyWhenOnTime() external {
        IInbox.Proposal memory proposal = _makeProposal(uint48(block.timestamp));
        vm.warp(proposal.timestamp + 5);

        LibBonds.BondInstruction[] memory result = LibBondInstruction.calculateBondInstructions(
            10, // proving window
            20, // extended window
            proposal,
            _makeMetadata(DESIGNATED, DESIGNATED)
        );

        assertEq(result.length, 0, "On-time proofs must not create bond instructions");
    }

    function test_calculateBondInstructions_ReturnsEmptyWhenSameProverLate() external {
        IInbox.Proposal memory proposal = _makeProposal(uint48(block.timestamp));
        vm.warp(proposal.timestamp + 15);

        LibBonds.BondInstruction[] memory result = LibBondInstruction.calculateBondInstructions(
            10, 30, proposal, _makeMetadata(DESIGNATED, DESIGNATED)
        );

        assertEq(result.length, 0, "Same prover within extended window should not penalize");
    }

    function test_calculateBondInstructions_ReturnsLivenessInstructionWhenLate() external {
        IInbox.Proposal memory proposal = _makeProposal(uint48(block.timestamp));
        vm.warp(proposal.timestamp + 15);

        LibBonds.BondInstruction[] memory result = LibBondInstruction.calculateBondInstructions(
            10, 30, proposal, _makeMetadata(DESIGNATED, ACTUAL)
        );

        assertEq(result.length, 1, "Expected single liveness instruction");
        assertEq(result[0].proposalId, proposal.id);
        assertEq(uint8(result[0].bondType), uint8(LibBonds.BondType.LIVENESS));
        assertEq(result[0].payer, DESIGNATED, "Designated prover pays liveness bond");
        assertEq(result[0].payee, ACTUAL);
    }

    function test_calculateBondInstructions_ReturnsProvabilityInstructionWhenVeryLate() external {
        IInbox.Proposal memory proposal = _makeProposal(uint48(block.timestamp));
        vm.warp(proposal.timestamp + 50);

        LibBonds.BondInstruction[] memory result = LibBondInstruction.calculateBondInstructions(
            10, 30, proposal, _makeMetadata(DESIGNATED, ACTUAL)
        );

        assertEq(result.length, 1, "Expected single provability instruction");
        assertEq(uint8(result[0].bondType), uint8(LibBonds.BondType.PROVABILITY));
        assertEq(result[0].payer, PROPOSER, "Original proposer must pay provability bond");
        assertEq(result[0].payee, ACTUAL);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _makeInstruction(
        uint48 _proposalId,
        LibBonds.BondType _bondType,
        address _payer,
        address _payee
    )
        internal
        pure
        returns (LibBonds.BondInstruction memory)
    {
        return LibBonds.BondInstruction({
            proposalId: _proposalId, bondType: _bondType, payer: _payer, payee: _payee
        });
    }

    function _makeProposal(uint48 _timestamp) internal pure returns (IInbox.Proposal memory) {
        return IInbox.Proposal({
            id: 999,
            timestamp: _timestamp,
            endOfSubmissionWindowTimestamp: _timestamp + 1,
            proposer: PROPOSER,
            coreStateHash: bytes32(uint256(0x11)),
            derivationHash: bytes32(uint256(0x22))
        });
    }

    function _makeMetadata(
        address _designated,
        address _actual
    )
        internal
        pure
        returns (IInbox.TransitionMetadata memory)
    {
        return IInbox.TransitionMetadata({ designatedProver: _designated, actualProver: _actual });
    }
}
