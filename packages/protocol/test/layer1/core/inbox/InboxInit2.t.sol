// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @notice Tests for the one-time `init2` recovery re-initializer.
contract InboxInit2Test is InboxTestBase {
    function test_init2_resetsCoreState() public {
        uint48 nextId = 7;
        uint48 lastBlock = uint48(block.number);
        uint48 finalizedId = 4;
        bytes32 finalizedHash = keccak256("recovered");

        vm.expectEmit();
        emit IInbox.StateRecovered(nextId, finalizedId, finalizedHash);
        inbox.init2(nextId, lastBlock, finalizedId, finalizedHash);

        IInbox.CoreState memory s = inbox.getCoreState();
        assertEq(s.nextProposalId, nextId, "nextProposalId");
        assertEq(s.lastProposalBlockId, lastBlock, "lastProposalBlockId");
        assertEq(s.lastFinalizedProposalId, finalizedId, "lastFinalizedProposalId");
        assertEq(s.lastFinalizedBlockHash, finalizedHash, "lastFinalizedBlockHash");
        assertEq(s.lastFinalizedTimestamp, uint48(block.timestamp), "lastFinalizedTimestamp");
        assertEq(s.lastCheckpointTimestamp, uint48(block.timestamp), "lastCheckpointTimestamp");
    }

    function test_init2_rollsBackFinalizationAfterProve() public {
        // Simulate the incident: a prove advances finalization.
        IInbox.ProveInput memory input = _buildBatchInput(1);
        _prove(input);

        IInbox.CoreState memory stateBefore = inbox.getCoreState();
        assertEq(
            stateBefore.lastFinalizedProposalId,
            input.commitment.firstProposalId,
            "finalized before recovery"
        );

        // Recover: roll finalization back while keeping proposals intact.
        bytes32 recoveredHash = keccak256("recovered-genesis");
        inbox.init2(stateBefore.nextProposalId, stateBefore.lastProposalBlockId, 0, recoveredHash);

        IInbox.CoreState memory s = inbox.getCoreState();
        assertEq(s.lastFinalizedProposalId, 0, "finalized id rolled back");
        assertEq(s.lastFinalizedBlockHash, recoveredHash, "finalized hash reset");
        // Proposal counters are preserved so proposals are not lost.
        assertEq(s.nextProposalId, stateBefore.nextProposalId, "nextProposalId preserved");
        assertEq(
            s.lastProposalBlockId, stateBefore.lastProposalBlockId, "lastProposalBlockId preserved"
        );
    }

    function test_init2_RevertWhen_NotOwner() public {
        vm.prank(Bob);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        inbox.init2(1, uint48(block.number), 0, keccak256("x"));
    }

    function test_init2_RevertWhen_CalledTwice() public {
        inbox.init2(1, uint48(block.number), 0, keccak256("x"));

        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        inbox.init2(1, uint48(block.number), 0, keccak256("y"));
    }

    function test_init2_RevertWhen_NextProposalIdZero() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(0, uint48(block.number), 0, keccak256("x"));
    }

    function test_init2_RevertWhen_LastProposalBlockInFuture() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(1, uint48(block.number + 1), 0, keccak256("x"));
    }

    function test_init2_RevertWhen_FinalizedIdNotLessThanNext() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(3, uint48(block.number), 3, keccak256("x"));
    }

    function test_init2_RevertWhen_BlockHashZero() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(1, uint48(block.number), 0, bytes32(0));
    }
}
