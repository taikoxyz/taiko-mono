// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { InboxTestBase, InboxVariant } from "../common/InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";

abstract contract ProposeTestBase is InboxTestBase {
    constructor(InboxVariant _variant) InboxTestBase(_variant) { }

    function test_propose() public {
        _setBlobHashes(3);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        IInbox.CoreState memory stateBefore = inbox.getState();

        IInbox.ProposedEventPayload memory expected = _buildExpectedProposedPayload(stateBefore, input);

        IInbox.ProposedEventPayload memory actual = _proposeAndDecodeWithGas(input, "propose_single");
        _assertPayloadEqual(actual, expected);

        IInbox.CoreState memory stateAfter = inbox.getState();
        assertEq(stateAfter.nextProposalId, stateBefore.nextProposalId + 1, "next id");
        _assertStateEqual(stateAfter, _expectedStateAfterProposal(stateBefore));
        assertEq(inbox.getProposalHash(expected.proposal.id), _hashProposal(expected.proposal), "proposal hash");
    }

    function test_propose_RevertWhen_DeadlinePassed() public {
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.deadline = uint48(block.timestamp - 1);

        vm.prank(proposer);
        vm.expectRevert(Inbox.DeadlineExceeded.selector);
        inbox.propose(bytes(""), _encodeProposeInput(input));
    }

    function test_propose_RevertWhen_SameBlock() public {
        _setBlobHashes(2);
        IInbox.ProposeInput memory input = _defaultProposeInput();

        vm.prank(proposer);
        inbox.propose(bytes(""), _encodeProposeInput(input));

        vm.prank(proposer);
        vm.expectRevert(Inbox.CannotProposeInCurrentBlock.selector);
        inbox.propose(bytes(""), _encodeProposeInput(input));
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
        assertEq(payload.derivation.sources[0].blobSlice.blobHashes[0], blobHashes[1], "forced blob hash");
        assertEq(payload.derivation.sources[1].blobSlice.blobHashes[0], blobHashes[2], "normal blob hash");
        assertEq(payload.proposal.id, first.proposal.id + 1, "proposal id");

        (uint48 head, uint48 tail,) = inbox.getForcedInclusionState();
        assertEq(head, 1, "queue head");
        assertEq(tail, 1, "queue tail");
    }

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
        payload_.derivation.sources[0] = IInbox.DerivationSource({ isForcedInclusion: false, blobSlice: blobSlice });

        payload_.proposal = IInbox.Proposal({
            id: _stateBefore.nextProposalId,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: 0,
            proposer: proposer,
            derivationHash: bytes32(0)
        });

        payload_.proposal.derivationHash = _hashDerivation(payload_.derivation);
    }

    function _assertPayloadEqual(
        IInbox.ProposedEventPayload memory _actual,
        IInbox.ProposedEventPayload memory _expected
    )
        internal
        view
    {
        assertEq(_actual.proposal.id, _expected.proposal.id, "proposal id");
        assertEq(_actual.proposal.timestamp, _expected.proposal.timestamp, "proposal timestamp");
        assertEq(
            _actual.proposal.endOfSubmissionWindowTimestamp,
            _expected.proposal.endOfSubmissionWindowTimestamp,
            "proposal deadline"
        );
        assertEq(_actual.proposal.proposer, _expected.proposal.proposer, "proposal proposer");
        assertEq(_actual.proposal.derivationHash, _expected.proposal.derivationHash, "proposal derivation hash");

        assertEq(
            _actual.derivation.originBlockNumber, _expected.derivation.originBlockNumber, "origin block number"
        );
        assertEq(_actual.derivation.originBlockHash, _expected.derivation.originBlockHash, "origin block hash");
        assertEq(
            _actual.derivation.basefeeSharingPctg, _expected.derivation.basefeeSharingPctg, "basefee sharing"
        );
        assertEq(_actual.derivation.sources.length, _expected.derivation.sources.length, "sources length");
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
        state_.lastFinalizedTransitionHash = _stateBefore.lastFinalizedTransitionHash;
    }

    function _assertStateEqual(IInbox.CoreState memory _actual, IInbox.CoreState memory _expected) internal pure {
        assertEq(_actual.nextProposalId, _expected.nextProposalId, "state nextProposalId");
        assertEq(_actual.lastProposalBlockId, _expected.lastProposalBlockId, "state last block");
        assertEq(_actual.lastFinalizedProposalId, _expected.lastFinalizedProposalId, "state finalized id");
        assertEq(_actual.lastFinalizedTimestamp, _expected.lastFinalizedTimestamp, "state finalized ts");
        assertEq(_actual.lastCheckpointTimestamp, _expected.lastCheckpointTimestamp, "state checkpoint ts");
        assertEq(_actual.lastFinalizedTransitionHash, _expected.lastFinalizedTransitionHash, "state transition hash");
    }
}

contract InboxProposeTest is ProposeTestBase {
    constructor() ProposeTestBase(InboxVariant.Simple) { }
}

contract InboxOptimizedProposeTest is ProposeTestBase {
    constructor() ProposeTestBase(InboxVariant.Optimized) { }
}
