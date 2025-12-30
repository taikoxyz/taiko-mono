// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @notice Capacity-focused tests with a small ring buffer to exercise bounds.
contract InboxCapacityTest is InboxTestBase {
    function test_propose_RevertWhen_InvalidCoreState() public {
        // Corrupt core state: nextProposalId == lastFinalizedProposalId
        uint48 nextProposalId = 1;
        uint48 lastProposalBlockId = uint48(block.number - 1);
        uint48 lastFinalizedProposalId = 1;
        uint48 lastFinalizedTimestamp = uint48(block.timestamp);
        uint48 lastCheckpointTimestamp = 0;

        uint256 packed = uint256(nextProposalId)
            | (uint256(lastProposalBlockId) << 48)
            | (uint256(lastFinalizedProposalId) << 96)
            | (uint256(lastFinalizedTimestamp) << 144)
            | (uint256(lastCheckpointTimestamp) << 192);

        // CoreState slot is 252 (see MainnetInbox_Layout.sol)
        vm.store(address(inbox), bytes32(uint256(252)), bytes32(packed));

        _setBlobHashes(1);
        bytes memory encoded = codec.encodeProposeInput(_defaultProposeInput());
        vm.expectRevert(Inbox.InvalidCoreState.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), encoded);
    }

    function test_propose_RevertWhen_CapacityExceeded() public {
        _setBlobHashes(3);
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());

        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());

        // Third proposal fills remaining capacity (ringBufferSize=4 -> max unfinalized=3)
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
        ProposedEvent memory payload = _proposeAndDecode(_defaultProposeInput());
        assertEq(payload.id, 3, "should succeed at capacity boundary");

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
        ProposedEvent memory p1 = _proposeAndDecode(_defaultProposeInput());
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p2 = _proposeAndDecode(_defaultProposeInput());
        uint48 p2Timestamp = uint48(block.timestamp);
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        _proposeAndDecode(_defaultProposeInput());
        _advanceBlock();
        ProposedEvent memory p5 = _proposeAndDecode(_defaultProposeInput());

        // Create checkpoint data for the transition
        uint48 endBlockNumber = uint48(block.number);
        bytes32 endStateRoot = keccak256("stateRoot");
        bytes32 checkpoint2Hash = keccak256("blockHash2");

        // Prove p1 and p2 using prove
        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(p1, p1Timestamp, prover, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(p2, p2Timestamp, prover, checkpoint2Hash);

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: p1.id,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(p2.id),
                actualProver: prover,
                endBlockNumber: endBlockNumber,
                endStateRoot: endStateRoot,
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        _prove(proveInput);

        _advanceBlock();
        ProposedEvent memory p6 =
            _proposeAndDecodeWithGas(_defaultProposeInput(), "propose_after_ring_buffer_wrap");
        uint48 p6Timestamp = uint48(block.timestamp);
        uint48 p6OriginBlockNumber = uint48(block.number - 1);
        bytes32 p6OriginBlockHash = blockhash(block.number - 1);
        IInbox.Proposal memory expectedP6 =
            _proposalFromPayload(p6, p6Timestamp, p6OriginBlockNumber, p6OriginBlockHash);

        assertEq(p6.id, p5.id + 1, "proposal id");
        assertEq(
            inbox.getProposalHash(expectedP6.id), codec.hashProposal(expectedP6), "proposal hash"
        );
    }
}
