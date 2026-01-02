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
        IInbox.CoreState memory stateBefore = inbox.getCoreState();

        ProposedEvent memory payload = _proposeAndDecodeWithGas(input, "propose_single");
        uint48 proposalTimestamp = uint48(block.timestamp);
        uint48 originBlockNumber = uint48(block.number - 1);
        bytes32 originBlockHash = blockhash(block.number - 1);

        IInbox.Proposal memory expectedProposal =
            _proposalFromPayload(payload, proposalTimestamp, originBlockNumber, originBlockHash);
        _assertPayloadEqual(payload, expectedProposal);

        IInbox.CoreState memory stateAfter = inbox.getCoreState();
        assertEq(stateAfter.nextProposalId, stateBefore.nextProposalId + 1, "next id");
        _assertStateEqual(stateAfter, _expectedStateAfterProposal(stateBefore));
        assertEq(
            inbox.getProposalHash(expectedProposal.id),
            codec.hashProposal(expectedProposal),
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
        uint256 proverFeeWei = uint256(PROVER_FEE_GWEI) * 1 gwei;

        vm.prank(proposer);
        inbox.propose{ value: proverFeeWei }(bytes(""), encodedInput);

        vm.prank(proposer);
        vm.expectRevert(Inbox.CannotProposeInCurrentBlock.selector);
        inbox.propose{ value: proverFeeWei }(bytes(""), encodedInput);
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
        ProposedEvent memory first = _proposeAndDecode(_defaultProposeInput());
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

        ProposedEvent memory payload = _proposeWithCaller(David, input);

        uint48 proposalTimestamp = uint48(block.timestamp);
        uint48 originBlockNumber = uint48(block.number - 1);
        bytes32 originBlockHash = blockhash(block.number - 1);
        IInbox.Proposal memory expectedProposal =
            _proposalFromPayload(payload, proposalTimestamp, originBlockNumber, originBlockHash);

        assertEq(payload.proposer, David, "proposer");
        assertTrue(payload.sources[0].isForcedInclusion, "forced inclusion");
        assertEq(payload.id, first.id + 1, "proposal id");
        assertEq(
            inbox.getProposalHash(expectedProposal.id),
            codec.hashProposal(expectedProposal),
            "proposal hash"
        );
    }

    function test_propose_processesForcedInclusion_andRecordsGas() public {
        bytes32[] memory blobHashes = _getBlobHashes(3);
        _setBlobHashes(3);

        ProposedEvent memory first = _proposeAndDecode(_defaultProposeInput());
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

        ProposedEvent memory payload = _proposeAndDecodeWithGas(input, "propose_forced_inclusion");
        uint48 proposalTimestamp = uint48(block.timestamp);
        uint48 originBlockNumber = uint48(block.number - 1);
        bytes32 originBlockHash = blockhash(block.number - 1);
        IInbox.Proposal memory expectedProposal =
            _proposalFromPayload(payload, proposalTimestamp, originBlockNumber, originBlockHash);

        assertEq(payload.sources.length, 2, "sources length");
        assertTrue(payload.sources[0].isForcedInclusion, "forced slot");
        assertEq(payload.sources[0].blobSlice.blobHashes[0], blobHashes[1], "forced blob hash");
        assertEq(payload.sources[1].blobSlice.blobHashes[0], blobHashes[2], "normal blob hash");
        assertEq(payload.id, first.id + 1, "proposal id");
        assertEq(
            inbox.getProposalHash(expectedProposal.id),
            codec.hashProposal(expectedProposal),
            "proposal hash"
        );

        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        assertEq(head, 1, "queue head");
        assertEq(tail, 1, "queue tail");
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _assertPayloadEqual(
        ProposedEvent memory _actual,
        IInbox.Proposal memory _expected
    )
        internal
        pure
    {
        assertEq(_actual.id, _expected.id, "proposal id");
        assertEq(_actual.proposer, _expected.proposer, "proposal proposer");
        assertEq(
            _actual.endOfSubmissionWindowTimestamp,
            _expected.endOfSubmissionWindowTimestamp,
            "submission window"
        );
        assertEq(_actual.basefeeSharingPctg, _expected.basefeeSharingPctg, "basefee sharing");
        assertEq(_actual.sources.length, _expected.sources.length, "sources length");
        if (_actual.sources.length != 0) {
            assertEq(
                _actual.sources[0].isForcedInclusion,
                _expected.sources[0].isForcedInclusion,
                "source forced"
            );
            assertEq(
                _actual.sources[0].blobSlice.blobHashes,
                _expected.sources[0].blobSlice.blobHashes,
                "blob hashes"
            );
            assertEq(
                _actual.sources[0].blobSlice.offset,
                _expected.sources[0].blobSlice.offset,
                "blob offset"
            );
            assertEq(
                _actual.sources[0].blobSlice.timestamp,
                _expected.sources[0].blobSlice.timestamp,
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
        state_.lastFinalizedBlockHash = _stateBefore.lastFinalizedBlockHash;
    }

    function _saveForcedInclusion(LibBlobs.BlobReference memory _ref) private {
        uint256 feeInGwei = inbox.getCurrentForcedInclusionFee();
        vm.prank(proposer);
        inbox.saveForcedInclusion{ value: feeInGwei * 1 gwei }(_ref);
    }

    function _proposeWithCaller(
        address _caller,
        IInbox.ProposeInput memory _input
    )
        internal
        returns (ProposedEvent memory payload_)
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
        uint48 lastProposalBlockId = inbox.getCoreState().lastProposalBlockId;

        // Advance exactly 1 block
        vm.roll(block.number + 1);
        assertEq(block.number, lastProposalBlockId + 1, "should be exactly next block");

        // Second proposal should succeed at exact boundary
        ProposedEvent memory payload = _proposeAndDecode(_defaultProposeInput());
        assertEq(payload.id, 2, "should be second proposal");
    }

    /// @notice Test propose succeeds at exact deadline boundary (block.timestamp == deadline)
    function test_propose_succeedsWhen_DeadlineExact() public {
        _setBlobHashes(1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.deadline = uint48(block.timestamp); // Exact boundary: timestamp == deadline

        // Should succeed because block.timestamp <= deadline
        ProposedEvent memory payload = _proposeAndDecode(input);
        assertEq(payload.id, 1, "should succeed at exact deadline");
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

    function test_propose_permissionless_AllowsCallerWithoutBond() public {
        _setBlobHashes(3);
        _proposeAndDecode(_defaultProposeInput());
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

        ProposedEvent memory payload = _proposeWithCaller(Emma, input);
        assertEq(payload.id, 2, "permissionless proposal accepted");
        assertEq(payload.proposer, Emma, "permissionless proposer");
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

    // =========================================================================
    // Self-Prover Tests - when getProver() returns address(0)
    // =========================================================================

    /// @notice Test propose succeeds when no auction winner and proposer has sufficient bond
    function test_propose_succeedsWhen_NoAuctionWinner_ProposerHasBond() public {
        _setBlobHashes(1);

        // Set prover to address(0) - no auction winner
        proverAuction.setProver(address(0), PROVER_FEE_GWEI);
        // Proposer has sufficient bond (defaultBondCheck = true)
        proverAuction.setHasSufficientBond(proposer, true);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        ProposedEvent memory payload = _proposeAndDecode(input);

        // Proposer becomes the designated prover
        assertEq(payload.designatedProver, proposer, "proposer should be designated prover");
        assertEq(payload.id, 1, "proposal id");
    }

    /// @notice Test propose reverts when no auction winner and proposer lacks sufficient bond
    function test_propose_RevertWhen_NoAuctionWinner_ProposerLacksBond() public {
        _setBlobHashes(1);

        // Set prover to address(0) - no auction winner
        proverAuction.setProver(address(0), PROVER_FEE_GWEI);
        // Proposer does NOT have sufficient bond
        proverAuction.setDefaultBondCheck(false);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        bytes memory encodedInput = codec.encodeProposeInput(input);
        uint256 proverFeeWei = uint256(PROVER_FEE_GWEI) * 1 gwei;

        vm.expectRevert(Inbox.InvalidSelfProverBond.selector);
        vm.prank(proposer);
        inbox.propose{ value: proverFeeWei }(bytes(""), encodedInput);
    }

    /// @notice Test propose with self-prover receives correct ETH refund
    function test_propose_selfProver_ReceivesRefund() public {
        _setBlobHashes(1);

        // Set prover to address(0) - no auction winner
        proverAuction.setProver(address(0), PROVER_FEE_GWEI);
        proverAuction.setHasSufficientBond(proposer, true);

        uint256 proverFeeWei = uint256(PROVER_FEE_GWEI) * 1 gwei;
        uint256 extraEth = 0.5 ether;
        uint256 totalSent = proverFeeWei + extraEth;

        uint256 proposerBalanceBefore = proposer.balance;

        IInbox.ProposeInput memory input = _defaultProposeInput();
        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.prank(proposer);
        inbox.propose{ value: totalSent }(bytes(""), encodedInput);

        // When proposer is designated prover, the prover fee is sent to themselves
        // So proposer pays proverFee but receives it back, net cost should be 0
        // They also get back the extraEth
        uint256 proposerBalanceAfter = proposer.balance;

        // The proposer sent totalSent, received proverFee (as designated prover) + extraEth (refund)
        // Net balance change should be 0 (totalSent - proverFee - extraEth = 0)
        assertEq(proposerBalanceAfter, proposerBalanceBefore, "proposer balance unchanged");
    }

    /// @notice Test propose with self-prover and zero fee
    function test_propose_selfProver_ZeroFee() public {
        _setBlobHashes(1);

        // Set prover to address(0) with zero fee
        proverAuction.setProver(address(0), 0);
        proverAuction.setHasSufficientBond(proposer, true);

        uint256 proposerBalanceBefore = proposer.balance;

        IInbox.ProposeInput memory input = _defaultProposeInput();
        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.prank(proposer);
        inbox.propose{ value: 0 }(bytes(""), encodedInput);

        // No fee required, balance should be unchanged
        assertEq(proposer.balance, proposerBalanceBefore, "proposer balance unchanged");
    }

    /// @notice Test permissionless propose with self-prover
    function test_propose_permissionless_SelfProver() public {
        _setBlobHashes(3);
        _proposeAndDecode(_defaultProposeInput());
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        _saveForcedInclusion(forcedRef);

        uint256 waitTime = uint256(config.forcedInclusionDelay)
            * uint256(config.permissionlessInclusionMultiplier);
        vm.warp(block.timestamp + waitTime + 1);
        vm.roll(block.number + 1);

        // Set prover to address(0) - no auction winner
        proverAuction.setProver(address(0), PROVER_FEE_GWEI);
        proverAuction.setHasSufficientBond(Emma, true);

        // Fund Emma
        vm.deal(Emma, 100 ether);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.numForcedInclusions = 1;
        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.recordLogs();
        vm.prank(Emma);
        inbox.propose{ value: uint256(PROVER_FEE_GWEI) * 1 gwei }(bytes(""), encodedInput);
        ProposedEvent memory payload = _readProposedEvent();

        assertEq(payload.proposer, Emma, "permissionless proposer");
        assertEq(payload.designatedProver, Emma, "Emma should be designated prover");
    }

    /// @notice Test permissionless propose fails when caller lacks bond
    function test_propose_permissionless_RevertWhen_CallerLacksBond() public {
        _setBlobHashes(3);
        _proposeAndDecode(_defaultProposeInput());
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        LibBlobs.BlobReference memory forcedRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 1, offset: 0 });
        _saveForcedInclusion(forcedRef);

        uint256 waitTime = uint256(config.forcedInclusionDelay)
            * uint256(config.permissionlessInclusionMultiplier);
        vm.warp(block.timestamp + waitTime + 1);
        vm.roll(block.number + 1);

        // Set prover to address(0) - no auction winner
        proverAuction.setProver(address(0), PROVER_FEE_GWEI);
        // Emma does NOT have sufficient bond
        proverAuction.setDefaultBondCheck(false);

        // Fund Emma
        vm.deal(Emma, 100 ether);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.numForcedInclusions = 1;
        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.InvalidSelfProverBond.selector);
        vm.prank(Emma);
        inbox.propose{ value: uint256(PROVER_FEE_GWEI) * 1 gwei }(bytes(""), encodedInput);
    }
}
