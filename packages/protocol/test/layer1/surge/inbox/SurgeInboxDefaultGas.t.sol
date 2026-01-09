// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "../../core/inbox/InboxTestBase.sol";
import { MockSurgeVerifier } from "./mocks/MockContracts.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { SurgeInbox } from "src/layer1/surge/deployments/internal-devnet/SurgeInbox.sol";

contract SurgeInboxDefaultGas is InboxTestBase {
    function test_surge_propose() public {
        _setBlobHashes(1);

        IInbox.ProposeInput memory input = _defaultProposeInput();
        IInbox.CoreState memory stateBefore = inbox.getCoreState();

        ProposedEvent memory payload =
            _proposeAndDecodeWithGas(input, "propose_single", "surge-propose");
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

    function test_surge_prove_single() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        _proveWithGas(input, "surge-prove", "prove_single");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.commitment.firstProposalId, "finalized id");
        assertEq(
            state.lastFinalizedBlockHash, input.commitment.transitions[0].blockHash, "checkpoint"
        );
    }

    function test_surge_prove_batch2() public {
        IInbox.ProveInput memory input = _buildBatchInput(2);

        _proveWithGas(input, "surge-prove", "prove_batch_2");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(
            state.lastFinalizedProposalId, input.commitment.firstProposalId + 1, "finalized id"
        );
        assertEq(
            state.lastFinalizedBlockHash,
            input.commitment.transitions[1].blockHash,
            "checkpoint hash"
        );
    }

    function test_surge_prove_batch3() public {
        IInbox.ProveInput memory input = _buildBatchInput(3);

        _proveWithGas(input, "surge-prove", "prove_batch_3");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(
            state.lastFinalizedProposalId, input.commitment.firstProposalId + 2, "finalized id"
        );
        assertEq(
            state.lastFinalizedBlockHash,
            input.commitment.transitions[2].blockHash,
            "checkpoint hash"
        );
    }

    function test_surge_prove_batch5() public {
        IInbox.ProveInput memory input = _buildBatchInput(5);

        _proveWithGas(input, "surge-prove", "prove_batch_5");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(
            state.lastFinalizedProposalId, input.commitment.firstProposalId + 4, "finalized id"
        );
        assertEq(
            state.lastFinalizedBlockHash,
            input.commitment.transitions[4].blockHash,
            "checkpoint hash"
        );
    }

    function test_surge_prove_batch10() public {
        IInbox.ProveInput memory input = _buildBatchInput(10);

        _proveWithGas(input, "surge-prove", "prove_batch_10");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(
            state.lastFinalizedProposalId, input.commitment.firstProposalId + 9, "finalized id"
        );
        assertEq(
            state.lastFinalizedBlockHash,
            input.commitment.transitions[9].blockHash,
            "checkpoint hash"
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

        ProposedEvent memory payload =
            _proposeAndDecodeWithGas(input, "propose_forced_inclusion", "surge-propose");
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

    // ---------------------------------------------------------------------
    // Hook overrides
    // ---------------------------------------------------------------------

    function _buildConfig() internal virtual override returns (IInbox.Config memory) {
        return IInbox.Config({
            proofVerifier: address(new MockSurgeVerifier()),
            proposerChecker: address(proposerChecker),
            proverWhitelist: address(proverWhitelistContract),
            signalService: address(signalService),
            provingWindow: 2 hours,
            maxProofSubmissionDelay: 3 minutes,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 384,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            minCheckpointDelay: 60_000, // large enough for skipping checkpoints in prove benches
            permissionlessInclusionMultiplier: 5
        });
    }

    /// @dev Override to deploy surge inbox instead of the base inbox
    function _deployInbox() internal virtual override returns (Inbox) {
        address impl = address(
            new SurgeInbox(
                config,
                518_400, /* _maxFinalizationDelayBeforeStreakReset */
                604_800 /* _maxFinalizationDelayBeforeRollback */
            )
        );
        return _deployProxy(impl);
    }
}
