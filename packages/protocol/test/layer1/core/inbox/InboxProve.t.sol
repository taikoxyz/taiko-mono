// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

contract InboxProveTest is InboxTestBase {
    function test_prove2_single() public {
        IInbox.ProveInput2 memory input = _buildBatchInput2(1);

        _prove2WithGas(input, "shasta-prove2", "prove2_single");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId, "finalized id");
        assertEq(state.lastFinalizedBlockHash, input.proposals[0].blockHash, "block hash");
    }

    function test_prove2_batch3() public {
        IInbox.ProveInput2 memory input = _buildBatchInput2(3);

        _prove2WithGas(input, "shasta-prove2", "prove2_consecutive_3");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 2, "finalized id");
        assertEq(state.lastFinalizedBlockHash, input.proposals[2].blockHash, "block hash");
    }

    function test_prove2_batch5() public {
        IInbox.ProveInput2 memory input = _buildBatchInput2(5);

        _prove2WithGas(input, "shasta-prove2", "prove2_consecutive_5");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 4, "finalized id");
        assertEq(state.lastFinalizedBlockHash, input.proposals[4].blockHash, "block hash");
    }

    function test_prove2_batch10() public {
        IInbox.ProveInput2 memory input = _buildBatchInput2(10);

        _prove2WithGas(input, "shasta-prove2", "prove2_consecutive_10");

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 9, "finalized id");
        assertEq(state.lastFinalizedBlockHash, input.proposals[9].blockHash, "block hash");
    }

    function test_prove2_RevertWhen_EmptyBatch() public {
        IInbox.ProveInput2 memory emptyInput = IInbox.ProveInput2({
            firstProposalId: 1,
            firstProposalParentBlockHash: inbox.getState().lastFinalizedBlockHash,
            proposals: new IInbox.ProposalState[](0),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover
        });

        bytes memory encodedInput = abi.encode(emptyInput);
        vm.expectRevert(Inbox.EmptyBatch.selector);
        vm.prank(prover);
        inbox.prove2(encodedInput, bytes("proof"));
    }

    function test_prove2_RevertWhen_FirstProposalIdTooLarge() public {
        // Propose one block
        _proposeOne();

        // Try to prove starting from proposal 2 (which would skip proposal 1)
        IInbox.ProposalState[] memory proposals = new IInbox.ProposalState[](1);
        proposals[0] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput2 memory input = IInbox.ProveInput2({
            firstProposalId: 2, // lastFinalizedProposalId is 0, so max allowed is 1
            firstProposalParentBlockHash: inbox.getState().lastFinalizedBlockHash,
            proposals: proposals,
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover
        });

        bytes memory encodedInput = abi.encode(input);
        vm.expectRevert(Inbox.FirstProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove2(encodedInput, bytes("proof"));
    }

    function test_prove2_RevertWhen_LastProposalIdTooLarge() public {
        // Propose one block (id = 1)
        _proposeOne();

        // Try to prove proposals 1 and 2 when only 1 exists
        IInbox.ProposalState[] memory proposals = new IInbox.ProposalState[](2);
        proposals[0] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash1")
        });
        proposals[1] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash2")
        });

        IInbox.ProveInput2 memory input = IInbox.ProveInput2({
            firstProposalId: 1,
            firstProposalParentBlockHash: inbox.getState().lastFinalizedBlockHash,
            proposals: proposals,
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover
        });

        bytes memory encodedInput = abi.encode(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove2(encodedInput, bytes("proof"));
    }

    function test_prove2_RevertWhen_ParentBlockHashMismatch() public {
        _proposeOne();

        IInbox.ProposalState[] memory proposals = new IInbox.ProposalState[](1);
        proposals[0] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput2 memory input = IInbox.ProveInput2({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32(uint256(999)), // Wrong parent hash
            proposals: proposals,
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover
        });

        bytes memory encodedInput = abi.encode(input);
        vm.expectRevert(Inbox.ParentBlockHashMismatch.selector);
        vm.prank(prover);
        inbox.prove2(encodedInput, bytes("proof"));
    }

    function test_prove2_emitsBondSignal_afterProvingWindow() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        // Move past the extended proving window to trigger PROVABILITY bond
        vm.warp(block.timestamp + config.extendedProvingWindow + 1);

        IInbox.ProposalState[] memory proposals = new IInbox.ProposalState[](2);
        proposals[0] = _proposalStateFor(p1, prover, keccak256("blockHash1"));
        proposals[1] = _proposalStateFor(p2, prover, keccak256("blockHash2"));

        IInbox.ProveInput2 memory input = IInbox.ProveInput2({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: inbox.getState().lastFinalizedBlockHash,
            proposals: proposals,
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover
        });

        _prove2(input);

        // Verify bond signal was sent for PROVABILITY
        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: p1.proposal.id,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: p1.proposal.proposer,
            payee: prover
        });
        bytes32 expectedSignal = LibBonds.hashBondInstruction(expectedInstruction);
        assertTrue(signalService.isSignalSent(address(inbox), expectedSignal), "bond signal sent");
    }

    function test_prove2_emitsLivenessBond_withinExtendedWindow() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Move past proving window but still within extended window
        vm.warp(block.timestamp + config.provingWindow + 1);

        IInbox.ProposalState[] memory proposals = new IInbox.ProposalState[](1);
        // Different designated prover than actual prover to trigger liveness bond
        proposals[0] = IInbox.ProposalState({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from prover
            timestamp: proposed.proposal.timestamp,
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput2 memory input = IInbox.ProveInput2({
            firstProposalId: proposed.proposal.id,
            firstProposalParentBlockHash: inbox.getState().lastFinalizedBlockHash,
            proposals: proposals,
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover
        });

        _prove2(input);

        // Verify bond signal was sent for LIVENESS
        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer, // designatedProver pays
            payee: prover // actualProver receives
        });
        bytes32 expectedSignal = LibBonds.hashBondInstruction(expectedInstruction);
        assertTrue(signalService.isSignalSent(address(inbox), expectedSignal), "liveness bond signal");
    }

    function test_prove2_acceptsProofWithFinalizedPrefix() public {
        // Propose 3 blocks
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p3 = _proposeOne();

        // First, prove just p1
        IInbox.ProposalState[] memory firstBatch = new IInbox.ProposalState[](1);
        bytes32 p1BlockHash = keccak256("blockHash1");
        firstBatch[0] = _proposalStateFor(p1, prover, p1BlockHash);

        IInbox.ProveInput2 memory firstInput = IInbox.ProveInput2({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: inbox.getState().lastFinalizedBlockHash,
            proposals: firstBatch,
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot1"),
            actualProver: prover
        });

        _prove2(firstInput);

        assertEq(inbox.getState().lastFinalizedProposalId, p1.proposal.id, "p1 finalized");

        // Now prove p1, p2, p3 (p1 already finalized - should be skipped)
        IInbox.ProposalState[] memory fullBatch = new IInbox.ProposalState[](3);
        fullBatch[0] = _proposalStateFor(p1, prover, p1BlockHash);
        fullBatch[1] = _proposalStateFor(p2, prover, keccak256("blockHash2"));
        fullBatch[2] = _proposalStateFor(p3, prover, keccak256("blockHash3"));

        IInbox.ProveInput2 memory fullInput = IInbox.ProveInput2({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: bytes32(0), // Ignored since offset > 0
            proposals: fullBatch,
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot3"),
            actualProver: prover
        });

        _prove2(fullInput);

        IInbox.CoreState memory state = inbox.getState();
        assertEq(state.lastFinalizedProposalId, p3.proposal.id, "finalized id");
        assertEq(state.lastFinalizedBlockHash, fullBatch[2].blockHash, "block hash");
    }

    function test_prove2_RevertWhen_FinalizedPrefixHashMismatch() public {
        // Propose 2 blocks
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        // First, prove p1
        bytes32 p1BlockHash = keccak256("blockHash1");
        IInbox.ProposalState[] memory firstBatch = new IInbox.ProposalState[](1);
        firstBatch[0] = _proposalStateFor(p1, prover, p1BlockHash);

        IInbox.ProveInput2 memory firstInput = IInbox.ProveInput2({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: inbox.getState().lastFinalizedBlockHash,
            proposals: firstBatch,
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot1"),
            actualProver: prover
        });

        _prove2(firstInput);

        // Try to prove p1, p2 with wrong p1 block hash (doesn't match finalized)
        IInbox.ProposalState[] memory fullBatch = new IInbox.ProposalState[](2);
        fullBatch[0] = _proposalStateFor(p1, prover, keccak256("wrongBlockHash")); // Wrong!
        fullBatch[1] = _proposalStateFor(p2, prover, keccak256("blockHash2"));

        IInbox.ProveInput2 memory fullInput = IInbox.ProveInput2({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: bytes32(0),
            proposals: fullBatch,
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot2"),
            actualProver: prover
        });

        bytes memory encodedInput = abi.encode(fullInput);
        vm.expectRevert(Inbox.ParentBlockHashMismatch.selector);
        vm.prank(prover);
        inbox.prove2(encodedInput, bytes("proof"));
    }

    function test_prove2_noBondSignal_withinProvingWindow() public {
        IInbox.ProveInput2 memory input = _buildBatchInput2(1);

        // Prove within the proving window - no bond signal should be emitted
        _prove2(input);

        // No bond signal should be sent when proof is on time
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: input.firstProposalId,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 livenessSignal = LibBonds.hashBondInstruction(instruction);

        instruction.bondType = LibBonds.BondType.PROVABILITY;
        bytes32 provabilitySignal = LibBonds.hashBondInstruction(instruction);

        assertFalse(signalService.isSignalSent(address(inbox), livenessSignal), "no liveness signal");
        assertFalse(
            signalService.isSignalSent(address(inbox), provabilitySignal), "no provability signal"
        );
    }
}
