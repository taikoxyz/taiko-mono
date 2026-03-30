// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { RealTimeInboxTestBase } from "./RealTimeInboxTestBase.sol";
import { IRealTimeInbox } from "src/layer1/core/iface/IRealTimeInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { RealTimeInbox } from "src/layer1/core/impl/RealTimeInbox.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Vm } from "forge-std/src/Vm.sol";

/// @notice Tests for RealTimeInbox.propose() and hashing helpers.
contract RealTimeInboxProposeTest is RealTimeInboxTestBase {
    // ---------------------------------------------------------------
    // propose()
    // ---------------------------------------------------------------

    function test_propose_succeeds() public {
        IRealTimeInbox.ProposeInput memory input = _buildDefaultProposeInput();
        ICheckpointStore.Checkpoint memory checkpoint = _buildCheckpoint();

        Vm.Log[] memory logs = _proposeAndGetLogs(input, checkpoint);

        // lastFinalizedBlockHash should be updated to checkpoint.blockHash
        assertEq(
            inbox.lastFinalizedBlockHash(), checkpoint.blockHash, "lastFinalizedBlockHash updated"
        );

        // Verify ProposedAndProved event was emitted
        assertTrue(logs.length > 0, "should emit events");
    }

    function test_propose_RevertWhen_NotActivated() public {
        RealTimeInbox freshInbox = _deployNonActivatedInbox();

        IRealTimeInbox.ProposeInput memory input = _buildDefaultProposeInput();
        ICheckpointStore.Checkpoint memory checkpoint = _buildCheckpoint();

        bytes memory data = abi.encode(input);
        _setBlobHashes(1);

        vm.expectRevert(RealTimeInbox.NotActivated.selector);
        vm.prank(proposer);
        freshInbox.propose(data, checkpoint, bytes(""));
    }

    function test_propose_withSignalSlots_succeeds() public {
        // Pre-set signals as sent
        bytes32[] memory slots = new bytes32[](2);
        slots[0] = keccak256("signal-slot-0");
        slots[1] = keccak256("signal-slot-1");
        signalService.setSignalsReceived(slots);

        IRealTimeInbox.ProposeInput memory input = _buildDefaultProposeInput();
        input.signalSlots = slots;

        ICheckpointStore.Checkpoint memory checkpoint = _buildCheckpoint();

        Vm.Log[] memory logs = _proposeAndGetLogs(input, checkpoint);

        assertEq(
            inbox.lastFinalizedBlockHash(), checkpoint.blockHash, "lastFinalizedBlockHash updated"
        );
        assertTrue(logs.length > 0, "should emit events");
    }

    function test_propose_RevertWhen_SignalSlotNotSent() public {
        bytes32[] memory slots = new bytes32[](1);
        slots[0] = keccak256("nonexistent-signal");

        IRealTimeInbox.ProposeInput memory input = _buildDefaultProposeInput();
        input.signalSlots = slots;

        ICheckpointStore.Checkpoint memory checkpoint = _buildCheckpoint();

        bytes memory data = abi.encode(input);
        _setBlobHashes(1);

        vm.expectRevert(abi.encodeWithSelector(RealTimeInbox.SignalSlotNotSent.selector, slots[0]));
        vm.prank(proposer);
        inbox.propose(data, checkpoint, bytes(""));
    }

    function test_propose_RevertWhen_MaxAnchorBlockTooOld() public {
        // Advance far enough that block 1 is > 256 blocks in the past
        vm.roll(300);

        IRealTimeInbox.ProposeInput memory input = _buildDefaultProposeInput();
        input.maxAnchorBlockNumber = 1; // blockhash(1) == 0 when block.number >= 258

        ICheckpointStore.Checkpoint memory checkpoint = _buildCheckpoint();
        bytes memory data = abi.encode(input);
        _setBlobHashes(1);

        vm.expectRevert(RealTimeInbox.MaxAnchorBlockTooOld.selector);
        vm.prank(proposer);
        inbox.propose(data, checkpoint, bytes(""));
    }

    function test_propose_emptySignalSlots_hashIsZero() public {
        IRealTimeInbox.ProposeInput memory input = _buildDefaultProposeInput();
        // signalSlots is already empty from _buildDefaultProposeInput()

        ICheckpointStore.Checkpoint memory checkpoint = _buildCheckpoint();

        Vm.Log[] memory logs = _proposeAndGetLogs(input, checkpoint);

        // Verify the hashSignalSlots returns bytes32(0) for empty array
        bytes32 emptyHash = inbox.hashSignalSlots(new bytes32[](0));
        assertEq(emptyHash, bytes32(0), "empty signal slots hash should be zero");

        assertTrue(logs.length > 0, "should emit events");
    }

    function test_propose_updatesChainHead() public {
        // First proposal
        IRealTimeInbox.ProposeInput memory input1 = _buildDefaultProposeInput();
        ICheckpointStore.Checkpoint memory checkpoint1 =
            _buildCheckpoint(1, keccak256("block-1"), keccak256("state-1"));

        _proposeAndGetLogs(input1, checkpoint1);
        assertEq(inbox.lastFinalizedBlockHash(), keccak256("block-1"), "after first propose");

        _advanceBlock();

        // Second proposal
        IRealTimeInbox.ProposeInput memory input2 = _buildDefaultProposeInput();
        ICheckpointStore.Checkpoint memory checkpoint2 =
            _buildCheckpoint(2, keccak256("block-2"), keccak256("state-2"));

        _proposeAndGetLogs(input2, checkpoint2);
        assertEq(inbox.lastFinalizedBlockHash(), keccak256("block-2"), "after second propose");
    }

    // ---------------------------------------------------------------
    // hashProposal()
    // ---------------------------------------------------------------

    function test_hashProposal_isConsistent() public view {
        IRealTimeInbox.Proposal memory proposal = _buildSampleProposal();

        bytes32 hash1 = inbox.hashProposal(proposal);
        bytes32 hash2 = inbox.hashProposal(proposal);

        assertEq(hash1, hash2, "same input should produce same hash");
        assertTrue(hash1 != bytes32(0), "hash should be non-zero");
    }

    // ---------------------------------------------------------------
    // hashCommitment()
    // ---------------------------------------------------------------

    function test_hashCommitment_bindsAllFields() public view {
        ICheckpointStore.Checkpoint memory checkpoint = _buildCheckpoint();

        IRealTimeInbox.Commitment memory base = IRealTimeInbox.Commitment({
            proposalHash: keccak256("proposal"),
            lastFinalizedBlockHash: keccak256("lastFinalized"),
            checkpoint: checkpoint
        });

        bytes32 baseHash = inbox.hashCommitment(base);

        // Change proposalHash
        IRealTimeInbox.Commitment memory changed1 = IRealTimeInbox.Commitment({
            proposalHash: keccak256("different-proposal"),
            lastFinalizedBlockHash: base.lastFinalizedBlockHash,
            checkpoint: checkpoint
        });
        assertTrue(inbox.hashCommitment(changed1) != baseHash, "proposalHash should affect hash");

        // Change lastFinalizedBlockHash
        IRealTimeInbox.Commitment memory changed2 = IRealTimeInbox.Commitment({
            proposalHash: base.proposalHash,
            lastFinalizedBlockHash: keccak256("different-last"),
            checkpoint: checkpoint
        });
        assertTrue(
            inbox.hashCommitment(changed2) != baseHash, "lastFinalizedBlockHash should affect hash"
        );

        // Change checkpoint
        ICheckpointStore.Checkpoint memory differentCheckpoint =
            _buildCheckpoint(99, keccak256("other-block"), keccak256("other-state"));
        IRealTimeInbox.Commitment memory changed3 = IRealTimeInbox.Commitment({
            proposalHash: base.proposalHash,
            lastFinalizedBlockHash: base.lastFinalizedBlockHash,
            checkpoint: differentCheckpoint
        });
        assertTrue(inbox.hashCommitment(changed3) != baseHash, "checkpoint should affect hash");
    }

    // ---------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------

    function _buildSampleProposal()
        internal
        pure
        returns (IRealTimeInbox.Proposal memory proposal_)
    {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](0);
        proposal_ = IRealTimeInbox.Proposal({
            maxAnchorBlockNumber: 50,
            maxAnchorBlockHash: keccak256("anchor"),
            basefeeSharingPctg: 0,
            sources: sources,
            signalSlotsHash: bytes32(0)
        });
    }
}
