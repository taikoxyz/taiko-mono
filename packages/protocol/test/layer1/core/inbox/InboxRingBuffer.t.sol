// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ProveTestBase } from "./InboxProve.t.sol";
import { InboxVariant } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";

abstract contract RingBufferTestBase is ProveTestBase {
    constructor(InboxVariant _variant) ProveTestBase(_variant) { }

    function _buildConfig() internal override returns (IInbox.Config memory cfg) {
        cfg = super._buildConfig();
        // Need headroom for 10-item batches in ring-buffer tests.
        cfg.ringBufferSize = 16;
        return cfg;
    }

    /// forge-config: default.isolate = true
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
            p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)), prover, prover
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

contract InboxRingBufferProveTest is RingBufferTestBase {
    constructor() RingBufferTestBase(InboxVariant.Simple) { }
}

contract InboxOptimizedRingBufferProveTest is RingBufferTestBase {
    constructor() RingBufferTestBase(InboxVariant.Optimized) { }
}
