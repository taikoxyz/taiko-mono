// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";

contract InboxProposeTest is InboxTestBase {
    function test_propose() public {
        _setBlobHashes(1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        IInbox.CoreState memory stateBefore = inbox.getState();

        IInbox.ProposedEventPayload memory expected =
            _buildExpectedProposedPayload(stateBefore, input);

        IInbox.ProposedEventPayload memory actual =
            _proposeAndDecodeWithGas(input, "propose_single");
        _assertPayloadEqual(actual, expected);

        IInbox.CoreState memory stateAfter = inbox.getState();
        assertEq(stateAfter.nextProposalId, stateBefore.nextProposalId + 1, "next id");
        _assertStateEqual(stateAfter, _expectedStateAfterProposal(stateBefore));
        assertEq(
            inbox.getProposalHash(expected.proposal.id),
            codec.hashProposal(expected.proposal),
            "proposal hash"
        );
    }

    function test_propose_RevertWhen_DeadlinePassed() public {
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.deadline = uint48(block.timestamp - 1);

        bytes memory encodedInput = codec.encodeProposeInput(input);
        vm.expectRevert(Inbox.DeadlineExceeded.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
    }

    function test_propose_RevertWhen_NotActivated() public {
        Inbox unactivated = _deployInbox();

        IInbox.ProposeInput memory input = _defaultProposeInput();
        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.ActivationRequired.selector);
        vm.prank(proposer);
        unactivated.propose(bytes(""), encodedInput);
    }

    function test_propose_RevertWhen_SameBlock() public {
        _setBlobHashes(2);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);

        vm.prank(proposer);
        vm.expectRevert(Inbox.CannotProposeInCurrentBlock.selector);
        inbox.propose(bytes(""), encodedInput);
    }

    function test_saveForcedInclusion_RevertWhen_NoProposalYet() public {
        _setBlobHashes(1);
        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 });

        uint256 feeInGwei = inbox.getCurrentForcedInclusionFee();
        vm.expectRevert(Inbox.IncorrectProposalCount.selector);
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: feeInGwei * 1 gwei }(forcedRef);
    }

    function test_propose_RevertWhen_ForcedInclusionDueNotProcessed() public {
        _setBlobHashes(2);
        _proposeAndDecode(_defaultProposeInput());
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        _saveForcedInclusion(forcedRef);

        vm.warp(block.timestamp + config.forcedInclusionDelay + 1);
        vm.roll(block.number + 1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        bytes memory encodedInput = codec.encodeProposeInput(input);
        vm.expectRevert(Inbox.UnprocessedForcedInclusionIsDue.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
    }

    function test_propose_allowsPermissionlessWhen_ForcedInclusionTooOld() public {
        _setBlobHashes(3);
        IInbox.ProposedEventPayload memory first = _proposeAndDecode(_defaultProposeInput());
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        _saveForcedInclusion(forcedRef);

        uint256 waitTime = uint256(config.forcedInclusionDelay)
            * uint256(config.permissionlessInclusionMultiplier);
        vm.warp(block.timestamp + waitTime + 1);
        vm.roll(block.number + 1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.numForcedInclusions = 1;

        IInbox.ProposedEventPayload memory payload = _proposeWithCaller(David, input);

        assertEq(payload.proposal.proposer, David, "proposer");
        assertEq(payload.proposal.endOfSubmissionWindowTimestamp, 0, "end of submission window");
        assertTrue(payload.derivation.sources[0].isForcedInclusion, "forced inclusion");
        assertEq(payload.proposal.id, first.proposal.id + 1, "proposal id");
    }

    function test_propose_processesForcedInclusion_andRecordsGas() public {
        bytes32[] memory blobHashes = _getBlobHashes(3);
        _setBlobHashes(3);

        IInbox.ProposedEventPayload memory first = _proposeAndDecode(_defaultProposeInput());
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        uint256 feeInGwei = inbox.getCurrentForcedInclusionFee();
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: feeInGwei * 1 gwei }(forcedRef);

        vm.warp(block.timestamp + config.forcedInclusionDelay + 1);
        vm.roll(block.number + 1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.blobReference = LibBlobs.BlobReference({ blobStartIndex: 2, numBlobs: 1, offset: 0 });
        input.numForcedInclusions = 1;

        IInbox.ProposedEventPayload memory payload =
            _proposeAndDecodeWithGas(input, "propose_forced_inclusion");

        assertEq(payload.derivation.sources.length, 2, "sources length");
        assertTrue(payload.derivation.sources[0].isForcedInclusion, "forced slot");
        assertEq(
            payload.derivation.sources[0].blobSlice.blobHashes[0], blobHashes[1], "forced blob hash"
        );
        assertEq(
            payload.derivation.sources[1].blobSlice.blobHashes[0], blobHashes[2], "normal blob hash"
        );
        assertEq(payload.proposal.id, first.proposal.id + 1, "proposal id");

        (uint48 head, uint48 tail,) = inbox.getForcedInclusionState();
        assertEq(head, 1, "queue head");
        assertEq(tail, 1, "queue tail");
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _buildExpectedProposedPayload(
        IInbox.CoreState memory _stateBefore,
        IInbox.ProposeInput memory _input
    )
        internal
        view
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(_input.blobReference);

        payload_.derivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            basefeeSharingPctg: config.basefeeSharingPctg,
            sources: new IInbox.DerivationSource[](1)
        });
        payload_.derivation.sources[0] =
            IInbox.DerivationSource({ isForcedInclusion: false, blobSlice: blobSlice });

        // Get the parent proposal hash from the ring buffer
        bytes32 parentProposalHash = inbox.getProposalHash(_stateBefore.nextProposalId - 1);

        payload_.proposal = IInbox.Proposal({
            id: _stateBefore.nextProposalId,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: 0,
            proposer: proposer,
            parentProposalHash: parentProposalHash,
            derivationHash: bytes32(0)
        });

        payload_.proposal.derivationHash = codec.hashDerivation(payload_.derivation);
    }

    function _assertPayloadEqual(
        IInbox.ProposedEventPayload memory _actual,
        IInbox.ProposedEventPayload memory _expected
    )
        internal
        pure
    {
        assertEq(_actual.proposal.id, _expected.proposal.id, "proposal id");
        assertEq(_actual.proposal.timestamp, _expected.proposal.timestamp, "proposal timestamp");
        assertEq(
            _actual.proposal.endOfSubmissionWindowTimestamp,
            _expected.proposal.endOfSubmissionWindowTimestamp,
            "proposal deadline"
        );
        assertEq(_actual.proposal.proposer, _expected.proposal.proposer, "proposal proposer");
        assertEq(
            _actual.proposal.derivationHash,
            _expected.proposal.derivationHash,
            "proposal derivation hash"
        );

        assertEq(
            _actual.derivation.originBlockNumber,
            _expected.derivation.originBlockNumber,
            "origin block number"
        );
        assertEq(
            _actual.derivation.originBlockHash,
            _expected.derivation.originBlockHash,
            "origin block hash"
        );
        assertEq(
            _actual.derivation.basefeeSharingPctg,
            _expected.derivation.basefeeSharingPctg,
            "basefee sharing"
        );
        assertEq(
            _actual.derivation.sources.length, _expected.derivation.sources.length, "sources length"
        );
        if (_actual.derivation.sources.length != 0) {
            assertEq(
                _actual.derivation.sources[0].isForcedInclusion,
                _expected.derivation.sources[0].isForcedInclusion,
                "source forced"
            );
            assertEq(
                _actual.derivation.sources[0].blobSlice.blobHashes,
                _expected.derivation.sources[0].blobSlice.blobHashes,
                "blob hashes"
            );
            assertEq(
                _actual.derivation.sources[0].blobSlice.offset,
                _expected.derivation.sources[0].blobSlice.offset,
                "blob offset"
            );
            assertEq(
                _actual.derivation.sources[0].blobSlice.timestamp,
                _expected.derivation.sources[0].blobSlice.timestamp,
                "blob timestamp"
            );
        }
    }

    function _expectedStateAfterProposal(IInbox.CoreState memory _stateBefore)
        internal
        view
        returns (IInbox.CoreState memory state_)
    {
        state_.nextProposalId = _stateBefore.nextProposalId + 1;
        state_.lastProposalBlockId = uint48(block.number);
        state_.lastFinalizedProposalId = _stateBefore.lastFinalizedProposalId;
        state_.lastFinalizedTimestamp = _stateBefore.lastFinalizedTimestamp;
        state_.lastCheckpointTimestamp = _stateBefore.lastCheckpointTimestamp;
    }

    function _saveForcedInclusion(LibBlobs.BlobReference memory _ref) internal {
        uint256 feeInGwei = inbox.getCurrentForcedInclusionFee();
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: feeInGwei * 1 gwei }(_ref);
    }

    function _proposeWithCaller(
        address _caller,
        IInbox.ProposeInput memory _input
    )
        internal
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        bytes memory encodedInput = codec.encodeProposeInput(_input);
        vm.recordLogs();
        vm.prank(_caller);
        inbox.propose(bytes(""), encodedInput);
        payload_ = _readProposedEvent();
    }

    // =========================================================================
    // Boundary Tests - propose() conditions
    // =========================================================================

    /// @notice Test propose succeeds at exact block boundary
    /// (block.number == lastProposalBlockId + 1)
    function test_propose_succeedsWhen_NextBlock() public {
        _setBlobHashes(2);

        // First proposal
        _proposeAndDecode(_defaultProposeInput());
        uint48 lastProposalBlockId = inbox.getState().lastProposalBlockId;

        // Advance exactly 1 block
        vm.roll(block.number + 1);
        assertEq(block.number, lastProposalBlockId + 1, "should be exactly next block");

        // Second proposal should succeed at exact boundary
        IInbox.ProposedEventPayload memory payload = _proposeAndDecode(_defaultProposeInput());
        assertEq(payload.proposal.id, 2, "should be second proposal");
    }

    /// @notice Test propose succeeds at exact deadline boundary (block.timestamp == deadline)
    function test_propose_succeedsWhen_DeadlineExact() public {
        _setBlobHashes(1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.deadline = uint48(block.timestamp); // Exact boundary: timestamp == deadline

        // Should succeed because block.timestamp <= deadline
        IInbox.ProposedEventPayload memory payload = _proposeAndDecode(input);
        assertEq(payload.proposal.id, 1, "should succeed at exact deadline");
    }

    /// @notice Test propose fails 1 second after deadline (block.timestamp == deadline + 1)
    function test_propose_RevertWhen_OneSecondPastDeadline() public {
        _setBlobHashes(1);

        uint48 deadline = uint48(block.timestamp);
        vm.warp(block.timestamp + 1); // Now timestamp > deadline

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.deadline = deadline;

        bytes memory encodedInput = codec.encodeProposeInput(input);
        vm.expectRevert(Inbox.DeadlineExceeded.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
    }

    /// @notice Test permissionless proposal at exact boundary
    /// (timestamp == permissionlessTimestamp)
    function test_propose_notPermissionlessWhen_AtExactPermissionlessTimestamp() public {
        _setBlobHashes(3);
        _proposeAndDecode(_defaultProposeInput());
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        _saveForcedInclusion(forcedRef);

        // Calculate exact permissionlessTimestamp
        // permissionlessTimestamp = forcedInclusionDelay * multiplier + oldestTimestamp
        uint256 waitTime = uint256(config.forcedInclusionDelay)
            * uint256(config.permissionlessInclusionMultiplier);

        // Warp to exactly the permissionless timestamp
        vm.warp(block.timestamp + waitTime);
        vm.roll(block.number + 1);

        // At exact boundary (timestamp == permissionlessTimestamp), NOT permissionless
        // because condition is block.timestamp > permissionlessTimestamp (strict >)
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.numForcedInclusions = 1;

        // Should NOT be permissionless at exact boundary, so unauthorized user fails
        bytes memory encodedInput = codec.encodeProposeInput(input);
        vm.expectRevert(); // Will revert due to proposer check
        vm.prank(David);
        inbox.propose(bytes(""), encodedInput);
    }
}
