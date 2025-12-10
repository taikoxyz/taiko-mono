// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @notice Test contract with minProposalsToFinalize = 3 to test LastProposalIdTooSmall
contract InboxProveMinProposalsTest is InboxTestBase {
    function _buildConfig() internal override returns (IInbox.Config memory) {
        IInbox.Config memory cfg = super._buildConfig();
        cfg.minProposalsToFinalize = 3;
        return cfg;
    }

    function test_prove_RevertWhen_LastProposalIdTooSmall() public {
        // Propose 2 blocks (not enough - need minProposalsToFinalize = 3)
        _proposeOne();
        _advanceBlock();
        _proposeOne();

        // Try to prove only 2 proposals when minProposalsToFinalize = 3
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](2);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash1")
        });
        proposalStates[1] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash2")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(2),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover,
            proposalStates: proposalStates
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooSmall.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_succeedsWhen_MinProposalsFinalized() public {
        // Propose 3 blocks (exactly minProposalsToFinalize)
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p3 = _proposeOne();

        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](3);
        proposalStates[0] = _proposalStateFor(p1, prover, keccak256("blockHash1"));
        proposalStates[1] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash2")
        });
        proposalStates[2] = _proposalStateFor(p3, prover, keccak256("blockHash3"));

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(p3.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover,
            proposalStates: proposalStates
        });

        _prove(input);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, 3, "finalized id");
    }
}

contract InboxProveTest is InboxTestBase {
    function test_prove_single() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        _proveWithGas(input, "shasta-prove", "prove_single");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId, "finalized id");
        assertEq(inbox.lastFinalizedBlockHash(), input.proposalStates[0].blockHash, "block hash");
    }

    function test_prove_batch3() public {
        IInbox.ProveInput memory input = _buildBatchInput(3);

        _proveWithGas(input, "shasta-prove", "prove_consecutive_3");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 2, "finalized id");
        assertEq(inbox.lastFinalizedBlockHash(), input.proposalStates[2].blockHash, "block hash");
    }

    function test_prove_batch5() public {
        IInbox.ProveInput memory input = _buildBatchInput(5);

        _proveWithGas(input, "shasta-prove", "prove_consecutive_5");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 4, "finalized id");
        assertEq(inbox.lastFinalizedBlockHash(), input.proposalStates[4].blockHash, "block hash");
    }

    function test_prove_batch10() public {
        IInbox.ProveInput memory input = _buildBatchInput(10);

        _proveWithGas(input, "shasta-prove", "prove_consecutive_10");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId + 9, "finalized id");
        assertEq(inbox.lastFinalizedBlockHash(), input.proposalStates[9].blockHash, "block hash");
    }

    function test_prove_RevertWhen_EmptyBatch() public {
        IInbox.ProveInput memory emptyInput = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: bytes32(0),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover,
            proposalStates: new IInbox.ProposalState[](0)
        });

        bytes memory encodedInput = codec.encodeProveInput(emptyInput);
        vm.expectRevert(Inbox.EmptyBatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_FirstProposalIdTooLarge() public {
        // Propose one block
        _proposeOne();

        // Try to prove starting from proposal 2 (which would skip proposal 1)
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 2, // lastFinalizedProposalId is 0, so max allowed is 1
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(1),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover,
            proposalStates: proposalStates
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.FirstProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_LastProposalIdTooLarge() public {
        // Propose one block (id = 1)
        _proposeOne();

        // Try to prove proposals 1 and 2 when only 1 exists
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](2);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash1")
        });
        proposalStates[1] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash2")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(1),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover,
            proposalStates: proposalStates
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_ParentBlockHashMismatch() public {
        _proposeOne();

        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32(uint256(999)), // Wrong parent hash
            lastProposalHash: inbox.getProposalHash(1),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover,
            proposalStates: proposalStates
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.ParentBlockHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_emitsBondSignal_afterProvingWindow() public {
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        // Move past the extended proving window to trigger PROVABILITY bond
        vm.warp(block.timestamp + config.extendedProvingWindow + 1);

        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](2);
        proposalStates[0] = _proposalStateFor(p1, prover, keccak256("blockHash1"));
        proposalStates[1] = _proposalStateFor(p2, prover, keccak256("blockHash2"));

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(p2.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover,
            proposalStates: proposalStates
        });

        _prove(input);

        // Verify bond signal was sent for PROVABILITY
        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: p1.proposal.id,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: p1.proposal.proposer,
            payee: prover
        });
        bytes32 expectedSignal = codec.hashBondInstruction(expectedInstruction);
        assertTrue(signalService.isSignalSent(address(inbox), expectedSignal), "bond signal sent");
    }

    function test_prove_emitsLivenessBond_withinExtendedWindow() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Move past proving window but still within extended window
        vm.warp(block.timestamp + config.provingWindow + 1);

        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        // Different designated prover than actual prover to trigger liveness bond
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from prover
            timestamp: proposed.proposal.timestamp,
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(proposed.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover,
            proposalStates: proposalStates
        });

        _prove(input);

        // Verify bond signal was sent for LIVENESS
        LibBonds.BondInstruction memory expectedInstruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer, // designatedProver pays
            payee: prover // actualProver receives
        });
        bytes32 expectedSignal = codec.hashBondInstruction(expectedInstruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), expectedSignal), "liveness bond signal"
        );
    }

    function test_prove_acceptsProofWithFinalizedPrefix() public {
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

        IInbox.ProveInput memory firstInput = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(p1.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot1"),
            actualProver: prover,
            proposalStates: firstBatch
        });

        _prove(firstInput);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, p1.proposal.id, "p1 finalized");

        // Now prove p1, p2, p3 (p1 already finalized - should be skipped)
        IInbox.ProposalState[] memory fullBatch = new IInbox.ProposalState[](3);
        fullBatch[0] = _proposalStateFor(p1, prover, p1BlockHash);
        fullBatch[1] = _proposalStateFor(p2, prover, keccak256("blockHash2"));
        fullBatch[2] = _proposalStateFor(p3, prover, keccak256("blockHash3"));

        IInbox.ProveInput memory fullInput = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: bytes32(0), // Ignored since offset > 0
            lastProposalHash: inbox.getProposalHash(p3.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot3"),
            actualProver: prover,
            proposalStates: fullBatch
        });

        _prove(fullInput);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, p3.proposal.id, "finalized id");
        assertEq(inbox.lastFinalizedBlockHash(), fullBatch[2].blockHash, "block hash");
    }

    function test_prove_RevertWhen_FinalizedPrefixHashMismatch() public {
        // Propose 2 blocks
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        // First, prove p1
        bytes32 p1BlockHash = keccak256("blockHash1");
        IInbox.ProposalState[] memory firstBatch = new IInbox.ProposalState[](1);
        firstBatch[0] = _proposalStateFor(p1, prover, p1BlockHash);

        IInbox.ProveInput memory firstInput = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(p1.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot1"),
            actualProver: prover,
            proposalStates: firstBatch
        });

        _prove(firstInput);

        // Try to prove p1, p2 with wrong p1 block hash (doesn't match finalized)
        IInbox.ProposalState[] memory fullBatch = new IInbox.ProposalState[](2);
        fullBatch[0] = _proposalStateFor(p1, prover, keccak256("wrongBlockHash")); // Wrong!
        fullBatch[1] = _proposalStateFor(p2, prover, keccak256("blockHash2"));

        IInbox.ProveInput memory fullInput = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: bytes32(0),
            lastProposalHash: inbox.getProposalHash(p2.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot2"),
            actualProver: prover,
            proposalStates: fullBatch
        });

        bytes memory encodedInput = codec.encodeProveInput(fullInput);
        vm.expectRevert(Inbox.ParentBlockHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_noBondSignal_withinProvingWindow() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Prove within the proving window - no bond signal should be emitted
        _prove(input);

        // No bond signal should be sent when proof is on time
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: input.firstProposalId,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);

        instruction.bondType = LibBonds.BondType.PROVABILITY;
        bytes32 provabilitySignal = codec.hashBondInstruction(instruction);

        assertFalse(
            signalService.isSignalSent(address(inbox), livenessSignal), "no liveness signal"
        );
        assertFalse(
            signalService.isSignalSent(address(inbox), provabilitySignal), "no provability signal"
        );
    }

    function test_prove_noBondSignal_whenPayerEqualsPayee() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Move past proving window but still within extended window
        vm.warp(block.timestamp + config.provingWindow + 1);

        // Set designatedProver = actualProver so payer == payee
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposed.proposal.proposer,
            designatedProver: prover, // Same as actualProver
            timestamp: proposed.proposal.timestamp,
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(proposed.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover, // Same as designatedProver
            proposalStates: proposalStates
        });

        _prove(input);

        // No bond signal should be sent when payer == payee
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: prover,
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);

        assertFalse(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "no liveness signal when payer==payee"
        );
    }

    // =========================================================================
    // Boundary Tests - prove() conditions
    // =========================================================================

    /// @notice Test firstProposalId at exact boundary (== lastFinalizedProposalId + 1)
    function test_prove_succeedsWhen_FirstProposalIdAtExactBoundary() public {
        // lastFinalizedProposalId = 0, so firstProposalId must be <= 1
        // Test with firstProposalId = 1 (exact boundary)
        IInbox.ProveInput memory input = _buildBatchInput(1);
        assertEq(input.firstProposalId, 1, "firstProposalId should be 1");
        assertEq(inbox.getCoreState().lastFinalizedProposalId, 0, "lastFinalizedProposalId should be 0");

        _prove(input);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, 1, "should finalize");
    }

    /// @notice Test lastProposalId at exact boundary (== nextProposalId - 1)
    function test_prove_succeedsWhen_LastProposalIdAtExactBoundary() public {
        // Use _buildBatchInput which handles propose internally
        // This verifies that lastProposalId = nextProposalId - 1 succeeds
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // After _buildBatchInput(1), we have 1 proposal, nextProposalId = 2
        assertEq(inbox.getCoreState().nextProposalId, 2, "nextProposalId should be 2");

        // lastProposalId = firstProposalId + numProposals - 1 = 1 + 1 - 1 = 1
        uint256 lastProposalId = input.firstProposalId + input.proposalStates.length - 1;
        assertEq(lastProposalId, 1, "lastProposalId at exact boundary");
        // Verify: lastProposalId (1) < nextProposalId (2) → passes

        _prove(input);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, 1, "should finalize");
    }

    /// @notice Test lastProposalId fails when == nextProposalId (just past boundary)
    function test_prove_RevertWhen_LastProposalIdEqualsNextProposalId() public {
        // Propose 1 block, nextProposalId = 2
        _proposeOne();

        // Try to prove 2 proposals (lastProposalId = 2 == nextProposalId)
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](2);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash1")
        });
        proposalStates[1] = IInbox.ProposalState({
            proposer: proposer,
            designatedProver: prover,
            timestamp: uint48(block.timestamp),
            blockHash: keccak256("blockHash2")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(1),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: bytes32(0),
            actualProver: prover,
            proposalStates: proposalStates
        });

        // lastProposalId = 1 + 2 - 1 = 2, nextProposalId = 2
        // Condition: lastProposalId < nextProposalId → 2 < 2 → false → revert
        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // =========================================================================
    // Boundary Tests - Bond instruction timing
    // =========================================================================

    /// @notice Test proving at exact provingWindow boundary (proposalAge == provingWindow)
    /// - no bond
    function test_prove_noBondSignal_atExactProvingWindowBoundary() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Warp to exactly provingWindow (proposalAge == provingWindow)
        vm.warp(proposed.proposal.timestamp + config.provingWindow);

        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from actualProver
            timestamp: proposed.proposal.timestamp,
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(proposed.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover,
            proposalStates: proposalStates
        });

        _prove(input);

        // At exact boundary (proposalAge <= provingWindow), no bond signal
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer,
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);
        assertFalse(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "no bond at exact provingWindow"
        );
    }

    /// @notice Test proving 1 second past provingWindow - triggers LIVENESS bond
    function test_prove_livenessBond_oneSecondPastProvingWindow() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Warp to provingWindow + 1 (just past boundary)
        vm.warp(proposed.proposal.timestamp + config.provingWindow + 1);

        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from actualProver to trigger bond
            timestamp: proposed.proposal.timestamp,
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(proposed.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover,
            proposalStates: proposalStates
        });

        _prove(input);

        // Just past provingWindow triggers LIVENESS bond
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer, // designatedProver pays
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "liveness bond 1 sec past window"
        );
    }

    /// @notice Test proving at exact extendedProvingWindow boundary - still LIVENESS bond
    function test_prove_livenessBond_atExactExtendedWindowBoundary() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Warp to exactly extendedProvingWindow (proposalAge == extendedProvingWindow)
        vm.warp(proposed.proposal.timestamp + config.extendedProvingWindow);

        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from actualProver to trigger bond
            timestamp: proposed.proposal.timestamp,
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(proposed.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover,
            proposalStates: proposalStates
        });

        _prove(input);

        // At exact extendedProvingWindow boundary (proposalAge <= extendedProvingWindow),
        // LIVENESS bond
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.LIVENESS,
            payer: proposer, // designatedProver
            payee: prover
        });
        bytes32 livenessSignal = codec.hashBondInstruction(instruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), livenessSignal),
            "liveness at exact extendedWindow"
        );
    }

    /// @notice Test proving 1 second past extendedProvingWindow - triggers PROVABILITY bond
    function test_prove_provabilityBond_oneSecondPastExtendedWindow() public {
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        // Warp to extendedProvingWindow + 1 (just past boundary)
        vm.warp(proposed.proposal.timestamp + config.extendedProvingWindow + 1);

        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: proposed.proposal.proposer,
            designatedProver: proposer, // Different from actualProver
            timestamp: proposed.proposal.timestamp,
            blockHash: keccak256("blockHash")
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: proposed.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(proposed.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover,
            proposalStates: proposalStates
        });

        _prove(input);

        // Past extendedProvingWindow triggers PROVABILITY bond
        // (proposer pays, not designatedProver)
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposed.proposal.id,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: proposed.proposal.proposer, // proposer pays
            payee: prover
        });
        bytes32 provabilitySignal = codec.hashBondInstruction(instruction);
        assertTrue(
            signalService.isSignalSent(address(inbox), provabilitySignal),
            "provability 1 sec past extended"
        );
    }

    function test_prove_noCheckpointSync_beforeDelay() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Do NOT warp past minCheckpointDelay - checkpoint should not sync
        _prove(input);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.firstProposalId, "finalized id");
        // Checkpoint timestamp should remain 0 (initial value) since delay hasn't passed
        assertEq(state.lastCheckpointTimestamp, 0, "checkpoint timestamp unchanged");
    }

    function test_prove_checkpointSyncsAfterDelay() public {
        // First prove without checkpoint sync
        IInbox.ProveInput memory input1 = _buildBatchInput(1);
        _prove(input1);

        uint48 checkpointBefore = inbox.getCoreState().lastCheckpointTimestamp;
        assertEq(checkpointBefore, 0, "checkpoint not synced initially");

        // Advance block and propose another
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();

        // Warp past minCheckpointDelay
        vm.warp(block.timestamp + config.minCheckpointDelay + 1);

        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = _proposalStateFor(p2, prover, keccak256("blockHash2"));

        IInbox.ProveInput memory input2 = IInbox.ProveInput({
            firstProposalId: p2.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(p2.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot2"),
            actualProver: prover,
            proposalStates: proposalStates
        });

        _prove(input2);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint synced");
    }
}
