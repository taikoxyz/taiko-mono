// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";

contract InboxInit3Test is InboxTestBase {
    function test_init3_VoidsQueuedForcedInclusions() public {
        _setBlobHashes(3);
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();

        _saveForcedInclusion(1);
        _saveForcedInclusion(2);

        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        assertEq(head, 0, "head before");
        assertEq(tail, 2, "tail before");

        vm.expectEmit(address(inbox));
        emit IInbox.ForcedInclusionsVoided(0, 2);
        inbox.init3();

        (head, tail) = inbox.getForcedInclusionState();
        assertEq(head, 2, "head after");
        assertEq(tail, 2, "tail after");

        // Even far beyond the inclusion delay, nothing is due or processable anymore.
        vm.warp(block.timestamp + config.forcedInclusionDelay + 1);
        vm.roll(block.number + 1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.numForcedInclusions = type(uint16).max;
        ProposedEvent memory payload = _proposeAndDecode(input);

        assertEq(payload.sources.length, 1, "only the normal source");
        assertFalse(payload.sources[0].isForcedInclusion, "no forced inclusion consumed");
    }

    function test_init3_QueueOperationalAfterVoiding() public {
        _setBlobHashes(4);
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();

        _saveForcedInclusion(1);

        inbox.init3();

        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        assertEq(head, 1, "head after void");
        assertEq(tail, 1, "tail after void");

        // New forced inclusions enqueue after the moved cursor and are consumed normally.
        _advanceBlock();
        _saveForcedInclusion(2);

        vm.warp(block.timestamp + config.forcedInclusionDelay + 1);
        vm.roll(block.number + 1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.blobReference = LibBlobs.BlobReference({ blobStartIndex: 3, numBlobs: 1, offset: 0 });
        input.numForcedInclusions = 1;
        ProposedEvent memory payload = _proposeAndDecode(input);

        assertEq(payload.sources.length, 2, "forced + normal source");
        assertTrue(payload.sources[0].isForcedInclusion, "forced inclusion consumed");

        (head, tail) = inbox.getForcedInclusionState();
        assertEq(head, 2, "head after consume");
        assertEq(tail, 2, "tail after consume");
    }

    function test_init3_EmptyQueue() public {
        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        assertEq(head, tail, "queue empty");

        vm.expectEmit(address(inbox));
        emit IInbox.ForcedInclusionsVoided(head, tail);
        inbox.init3();

        (uint48 headAfter, uint48 tailAfter) = inbox.getForcedInclusionState();
        assertEq(headAfter, head, "head unchanged");
        assertEq(tailAfter, tail, "tail unchanged");
    }

    function test_init3_WorksAfterInit2() public {
        // Mirrors the mainnet upgrade path: init2 (version 2) already consumed, then init3.
        inbox.init2(0, keccak256("trustedBlockHash"));
        inbox.init3();
    }

    function test_init3_RevertWhen_CallerNotOwner() public {
        vm.expectRevert();
        vm.prank(Alice);
        inbox.init3();
    }

    function test_init3_RevertWhen_CalledTwice() public {
        inbox.init3();

        vm.expectRevert();
        inbox.init3();
    }

    function test_init3_RevertWhen_ProxyAlreadyAtVersion3() public {
        vm.store(address(inbox), bytes32(0), bytes32(uint256(3)));

        vm.expectRevert();
        inbox.init3();
    }

    function _saveForcedInclusion(uint16 _blobStartIndex) private {
        LibBlobs.BlobReference memory ref =
            LibBlobs.BlobReference({ blobStartIndex: _blobStartIndex, numBlobs: 1, offset: 0 });
        uint256 feeInGwei = inbox.getCurrentForcedInclusionFee();
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: feeInGwei * 1 gwei }(ref);
    }
}
