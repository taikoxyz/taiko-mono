// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

contract InboxInit2Test is InboxTestBase {
    function test_init2_ResetsCoreState() public {
        uint48 nextProposalId = 10;
        uint48 lastProposalBlockId = 1234;
        uint48 lastFinalizedProposalId = 8;
        bytes32 lastFinalizedBlockHash = keccak256("trustedBlockHash");

        vm.warp(4567);

        vm.expectEmit(false, false, false, true, address(inbox));
        emit IInbox.StateRecovered(nextProposalId, lastFinalizedProposalId, lastFinalizedBlockHash);

        inbox.init2(
            nextProposalId, lastProposalBlockId, lastFinalizedProposalId, lastFinalizedBlockHash
        );

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.nextProposalId, nextProposalId);
        assertEq(state.lastProposalBlockId, lastProposalBlockId);
        assertEq(state.lastFinalizedProposalId, lastFinalizedProposalId);
        assertEq(state.lastFinalizedTimestamp, uint48(block.timestamp));
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp));
        assertEq(state.lastFinalizedBlockHash, lastFinalizedBlockHash);
    }

    function test_init2_RevertWhen_CallerNotOwner() public {
        vm.expectRevert();
        vm.prank(Alice);
        inbox.init2(10, 1234, 8, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_NextProposalIdIsZero() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(0, 1234, 0, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_LastFinalizedProposalIdTooHigh() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(10, 1234, 10, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_UnfinalizedRangeExceedsRingBuffer() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(101, 1234, 1, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_LastFinalizedBlockHashZero() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(10, 1234, 8, bytes32(0));
    }

    function test_init2_RevertWhen_CalledTwice() public {
        inbox.init2(10, 1234, 8, keccak256("trustedBlockHash"));

        vm.expectRevert();
        inbox.init2(11, 1235, 9, keccak256("anotherTrustedBlockHash"));
    }
}
