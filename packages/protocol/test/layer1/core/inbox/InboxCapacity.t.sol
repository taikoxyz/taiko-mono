// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @notice Capacity-focused tests with a small ring buffer to exercise bounds.
contract InboxCapacityTest is InboxTestBase {
    function test_propose_RevertWhen_CapacityExceeded() public {
        _setBlobHashes(3);
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

    function _buildConfig() internal virtual override returns (IInbox.Config memory) {
        IInbox.Config memory cfg = super._buildConfig();
        cfg.ringBufferSize = 3;
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
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        IInbox.ProposedEventPayload memory p5 = _proposeAndDecode(_defaultProposeInput());

        IInbox.Transition memory t1 = _transitionFor(
            p1, inbox.getState().lastFinalizedBlockHash, bytes32(uint256(1)), prover, prover
        );
        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal), transitions: _transitions(t1), syncCheckpoint: true
        });

        _proveAndDecode(proveInput);

        _advanceBlock();
        IInbox.ProposedEventPayload memory p6 =
            _proposeAndDecodeWithGas(_defaultProposeInput(), "propose_after_ring_buffer_wrap");

        assertEq(p6.proposal.id, p5.proposal.id + 1, "proposal id");
        assertEq(
            inbox.getProposalHash(p6.proposal.id), codec.hashProposal(p6.proposal), "proposal hash"
        );
    }
}
