// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @notice Capacity-focused tests with a small ring buffer to exercise bounds.
/// @dev ringBufferSize = 4, minProposalsToFinalize = 1, so max unfinalized = 3
contract InboxCapacityTest is InboxTestBase {
    function test_propose_RevertWhen_CapacityExceeded() public {
        _setBlobHashes(4);
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());

        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());

        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());

        _advanceBlock();
        bytes memory encodedInput = codec.encodeProposeInput(_defaultProposeInput());
        vm.expectRevert(Inbox.NotEnoughCapacity.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
    }

    /// @notice Test propose succeeds at exact capacity boundary (capacity == 1)
    /// ringBufferSize = 4, so max unfinalized = 3
    /// After 2 proposals: numUnfinalized = 2, capacity = 4 - 1 - 2 = 1
    function test_propose_succeedsWhen_CapacityExactlyOne() public {
        _setBlobHashes(3);
        _advanceBlock();

        // First proposal: numUnfinalized becomes 1
        _proposeAndDecode(_defaultProposeInput());

        // Second proposal: numUnfinalized becomes 2, capacity = 4 - 1 - 2 = 1
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());

        // Third proposal should succeed at capacity = 1 (exact boundary)
        _advanceBlock();
        IInbox.ProposedEventPayload memory payload = _proposeAndDecode(_defaultProposeInput());
        assertEq(payload.proposal.id, 3, "should succeed at capacity boundary");

        // After this: numUnfinalized = 3, capacity = 4 - 1 - 3 = 0, next should fail
    }

    function _buildConfig() internal virtual override returns (IInbox.Config memory) {
        IInbox.Config memory cfg = super._buildConfig();
        cfg.ringBufferSize = 4;
        return cfg;
    }
}

/// @notice Ring buffer tests with larger buffer to test wrap-around behavior.
contract InboxRingBufferTest is InboxTestBase {
    function _buildConfig() internal override returns (IInbox.Config memory cfg) {
        cfg = super._buildConfig();
        // Need headroom for 10-item batches in ring-buffer tests.
        cfg.ringBufferSize = 16;
        return cfg;
    }

    function test_ringBuffer_reuse_after_finalization_recordsGas() public {
        _setBlobHashes(6);
        IInbox.ProposedEventPayload memory p1 = _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        IInbox.ProposedEventPayload memory p5 = _proposeAndDecode(_defaultProposeInput());

        // Prove p1 and p2 using prove
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](2);
        proposalStates[0] = _proposalStateFor(p1, prover, keccak256("blockHash1"));
        proposalStates[1] = _proposalStateFor(p2, prover, keccak256("blockHash2"));

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            firstProposalId: p1.proposal.id,
            firstProposalParentBlockHash: inbox.lastFinalizedBlockHash(),
            lastProposalHash: inbox.getProposalHash(p2.proposal.id),
            lastBlockNumber: uint48(block.number),
            lastStateRoot: keccak256("stateRoot"),
            actualProver: prover,
            proposalStates: proposalStates
        });

        _prove(proveInput);

        _advanceBlock();
        IInbox.ProposedEventPayload memory p6 =
            _proposeAndDecodeWithGas(_defaultProposeInput(), "propose_after_ring_buffer_wrap");

        assertEq(p6.proposal.id, p5.proposal.id + 1, "proposal id");
        assertEq(
            inbox.getProposalHash(p6.proposal.id), codec.hashProposal(p6.proposal), "proposal hash"
        );
    }
}
