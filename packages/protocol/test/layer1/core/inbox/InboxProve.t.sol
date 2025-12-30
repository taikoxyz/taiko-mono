// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract InboxProveTest is InboxTestBase {
    // ---------------------------------------------------------------------
    // Happy paths
    // ---------------------------------------------------------------------
    function test_prove_single() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        _proveWithGas(input, "shasta-prove", "prove_single");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.commitment.firstProposalId, "finalized id");
        assertEq(
            state.lastFinalizedBlockHash, input.commitment.transitions[0].blockHash, "checkpoint"
        );
    }

    function test_prove_batch2() public {
        IInbox.ProveInput memory input = _buildBatchInput(2);

        _proveWithGas(input, "shasta-prove", "prove_batch_2");

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

    function test_prove_batch3() public {
        IInbox.ProveInput memory input = _buildBatchInput(3);

        _proveWithGas(input, "shasta-prove", "prove_batch_3");

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

    function test_prove_batch5() public {
        IInbox.ProveInput memory input = _buildBatchInput(5);

        _proveWithGas(input, "shasta-prove", "prove_batch_5");

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

    function test_prove_batch10() public {
        IInbox.ProveInput memory input = _buildBatchInput(10);

        _proveWithGas(input, "shasta-prove", "prove_batch_10");

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

    // ---------------------------------------------------------------------
    // Proof verifier args
    // ---------------------------------------------------------------------
    function test_prove_passesProposalAge_forSingleProposalProofs() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        IInbox.CoreState memory stateBefore = inbox.getCoreState();
        uint48 proposalTimestamp = input.commitment.transitions[0].timestamp;

        vm.warp(uint256(proposalTimestamp) + 123);

        uint48 availableSince = proposalTimestamp > stateBefore.lastFinalizedTimestamp
            ? proposalTimestamp
            : stateBefore.lastFinalizedTimestamp;
        uint256 expectedAge = block.timestamp - uint256(availableSince);
        assertGt(expectedAge, 0, "sanity: expected age should be > 0");

        bytes32 expectedCommitmentHash = codec.hashCommitment(input.commitment);

        vm.expectCall(
            address(verifier),
            abi.encodeCall(
                IProofVerifier.verifyProof, (expectedAge, expectedCommitmentHash, bytes("proof"))
            )
        );
        _prove(input);
    }

    function test_prove_passesZeroProposalAge_forMultiProposalBatches() public {
        IInbox.ProveInput memory input = _buildBatchInput(2);

        bytes32 expectedCommitmentHash = codec.hashCommitment(input.commitment);

        vm.expectCall(
            address(verifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, expectedCommitmentHash, bytes("proof")))
        );
        _prove(input);
    }

    // ---------------------------------------------------------------------
    // Bounds and validation
    // ---------------------------------------------------------------------
    function test_prove_RevertWhen_EmptyBatch() public {
        IInbox.ProveInput memory emptyInput = _buildInput(
            1, inbox.getCoreState().lastFinalizedBlockHash, new IInbox.Transition[](0), bytes32(0)
        );

        bytes memory encodedInput = codec.encodeProveInput(emptyInput);
        vm.expectRevert(Inbox.EmptyBatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_FirstProposalIdTooLarge() public {
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(payload, proposalTimestamp, keccak256("checkpoint1"));

        IInbox.ProveInput memory input = _buildInput(
            payload.id + 1,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            keccak256("stateRoot")
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.FirstProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_LastProposalIdTooLarge() public {
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] =
            _transitionFor(payload, proposalTimestamp, prover, keccak256("checkpoint1"));
        transitions[1] =
            _transitionFor(payload, proposalTimestamp, prover, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = _buildInput(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            keccak256("stateRoot")
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_ParentBlockHashMismatch() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p2 = _proposeOne();
        uint48 p2Timestamp = uint48(block.timestamp);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(p1, p1Timestamp, prover, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(p2, p2Timestamp, prover, keccak256("checkpoint2"));

        IInbox.ProveInput memory input =
            _buildInput(1, bytes32(uint256(999)), transitions, keccak256("stateRoot"));

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.ParentBlockHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_acceptsProofWithFinalizedPrefix() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p2 = _proposeOne();
        uint48 p2Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p3 = _proposeOne();
        uint48 p3Timestamp = uint48(block.timestamp);

        bytes32 p1Checkpoint = keccak256("checkpoint1");
        IInbox.Transition[] memory firstBatch = _transitionArrayFor(p1, p1Timestamp, p1Checkpoint);

        IInbox.ProveInput memory firstInput = _buildInput(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, firstBatch, keccak256("stateRoot1")
        );
        _prove(firstInput);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, p1.id, "p1 finalized");

        IInbox.Transition[] memory fullBatch = new IInbox.Transition[](3);
        fullBatch[0] = _transitionFor(p1, p1Timestamp, prover, p1Checkpoint);
        fullBatch[1] = _transitionFor(p2, p2Timestamp, prover, keccak256("checkpoint2"));
        fullBatch[2] = _transitionFor(p3, p3Timestamp, prover, keccak256("checkpoint3"));

        IInbox.ProveInput memory fullInput =
            _buildInput(p1.id, bytes32(0), fullBatch, keccak256("stateRoot3"));
        _prove(fullInput);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, p3.id, "finalized id");
        assertEq(state.lastFinalizedBlockHash, fullBatch[2].blockHash, "checkpoint hash");
    }

    function test_prove_RevertWhen_FinalizedPrefixHashMismatch() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p2 = _proposeOne();
        uint48 p2Timestamp = uint48(block.timestamp);

        bytes32 p1Checkpoint = keccak256("checkpoint1");
        IInbox.Transition[] memory firstBatch = _transitionArrayFor(p1, p1Timestamp, p1Checkpoint);

        IInbox.ProveInput memory firstInput = _buildInput(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, firstBatch, keccak256("stateRoot1")
        );
        _prove(firstInput);

        IInbox.Transition[] memory fullBatch = new IInbox.Transition[](2);
        fullBatch[0] = _transitionFor(p1, p1Timestamp, prover, keccak256("wrongCheckpoint"));
        fullBatch[1] = _transitionFor(p2, p2Timestamp, prover, keccak256("checkpoint2"));

        IInbox.ProveInput memory fullInput =
            _buildInput(p1.id, bytes32(0), fullBatch, keccak256("stateRoot2"));

        bytes memory encodedInput = codec.encodeProveInput(fullInput);
        vm.expectRevert(Inbox.ParentBlockHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // ---------------------------------------------------------------------
    // Boundary Tests - prove() conditions
    // ---------------------------------------------------------------------
    function test_prove_succeedsWhen_FirstProposalIdAtExactBoundary() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);
        assertEq(input.commitment.firstProposalId, 1, "firstProposalId should be 1");
        assertEq(
            inbox.getCoreState().lastFinalizedProposalId, 0, "lastFinalizedProposalId should be 0"
        );

        _prove(input);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, 1, "should finalize");
    }

    function test_prove_succeedsWhen_LastProposalIdAtExactBoundary() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        assertEq(
            inbox.getCoreState().nextProposalId,
            input.commitment.firstProposalId + 1,
            "nextProposalId"
        );

        uint256 lastProposalId =
            input.commitment.firstProposalId + input.commitment.transitions.length - 1;
        assertEq(lastProposalId, 1, "lastProposalId at exact boundary");

        _prove(input);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, 1, "should finalize");
    }

    function test_prove_RevertWhen_LastProposalIdEqualsNextProposalId() public {
        ProposedEvent memory payload = _proposeOne(); // id = 1, nextProposalId = 2
        uint48 proposalTimestamp = uint48(block.timestamp);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] =
            _transitionFor(payload, proposalTimestamp, prover, keccak256("checkpoint1"));
        transitions[1] =
            _transitionFor(payload, proposalTimestamp, prover, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = _buildInput(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            keccak256("stateRoot")
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // ---------------------------------------------------------------------
    // Checkpoint handling
    // ---------------------------------------------------------------------
    function test_prove_noCheckpointSync_beforeDelay() public {
        // Provide empty endBlockNumber/endStateRoot to avoid syncing
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);
        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 1,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(1),
                actualProver: prover,
                endBlockNumber: 0,
                endStateRoot: bytes32(0),
                transitions: _transitionArrayFor(
                    payload, proposalTimestamp, keccak256("checkpoint")
                )
            }),
            forceCheckpointSync: false
        });

        _prove(input);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.commitment.firstProposalId, "finalized id");
        assertEq(state.lastCheckpointTimestamp, 0, "checkpoint timestamp unchanged");
    }

    function test_prove_checkpointSyncsAfterDelay() public {
        // First prove without checkpoint sync
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);
        IInbox.ProveInput memory input1 = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 1,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(1),
                actualProver: prover,
                endBlockNumber: 0,
                endStateRoot: bytes32(0),
                transitions: _transitionArrayFor(p1, p1Timestamp, keccak256("checkpoint1"))
            }),
            forceCheckpointSync: false
        });
        _prove(input1);

        uint48 checkpointBefore = inbox.getCoreState().lastCheckpointTimestamp;
        assertEq(checkpointBefore, 0, "checkpoint not synced initially");

        _advanceBlock();
        ProposedEvent memory p2 = _proposeOne();
        uint48 p2Timestamp = uint48(block.timestamp);
        vm.warp(block.timestamp + config.minCheckpointDelay + 1);

        // Create checkpoint data for the transition
        uint48 endBlockNumber = uint48(block.number);
        bytes32 endStateRoot = keccak256("stateRoot2");
        bytes32 blockHash = keccak256("blockHash2");

        IInbox.Transition[] memory transitions = _transitionArrayFor(p2, p2Timestamp, blockHash);

        IInbox.ProveInput memory input2 = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: p2.id,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(p2.id),
                actualProver: prover,
                endBlockNumber: endBlockNumber,
                endStateRoot: endStateRoot,
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        _prove(input2);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint synced");
    }

    function test_prove_RevertWhen_CheckpointMissingAfterDelay() public {
        IInbox.ProveInput memory firstInput = _buildBatchInput(1);
        _prove(firstInput);

        uint48 checkpointTimestamp = inbox.getCoreState().lastCheckpointTimestamp;

        _advanceBlock();
        ProposedEvent memory p2 = _proposeOne();
        uint48 p2Timestamp = uint48(block.timestamp);
        vm.warp(uint256(checkpointTimestamp) + config.minCheckpointDelay + 1);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(p2, p2Timestamp, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: p2.id,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(p2.id),
                actualProver: prover,
                endBlockNumber: 0,
                endStateRoot: bytes32(0),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------
    function _buildInput(
        uint48 _firstProposalId,
        bytes32 _parentBlockHash,
        IInbox.Transition[] memory _transitions,
        bytes32 // _stateRoot - unused, kept for backward compatibility
    )
        internal
        view
        returns (IInbox.ProveInput memory)
    {
        // Use empty checkpoint values to skip the new checkpoint validation.
        // Tests that specifically need checkpoint syncing should use _buildInputWithCheckpoint.
        uint256 lastProposalId = _firstProposalId + _transitions.length - 1;
        return IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: _firstProposalId,
                firstProposalParentBlockHash: _parentBlockHash,
                lastProposalHash: inbox.getProposalHash(lastProposalId),
                actualProver: prover,
                endBlockNumber: 0,
                endStateRoot: bytes32(0),
                transitions: _transitions
            }),
            forceCheckpointSync: false
        });
    }

    function _buildInputWithCheckpoint(
        uint48 _firstProposalId,
        bytes32 _parentBlockHash,
        IInbox.Transition[] memory _transitions,
        uint48 _endBlockNumber,
        bytes32 _endStateRoot
    )
        internal
        view
        returns (IInbox.ProveInput memory)
    {
        uint256 lastProposalId = _firstProposalId + _transitions.length - 1;
        return IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: _firstProposalId,
                firstProposalParentBlockHash: _parentBlockHash,
                lastProposalHash: inbox.getProposalHash(lastProposalId),
                actualProver: prover,
                endBlockNumber: _endBlockNumber,
                endStateRoot: _endStateRoot,
                transitions: _transitions
            }),
            forceCheckpointSync: false
        });
    }

    function _transitionArrayFor(
        ProposedEvent memory _payload,
        uint48 _proposalTimestamp,
        bytes32 _blockHash
    )
        internal
        view
        returns (IInbox.Transition[] memory transitions_)
    {
        transitions_ = new IInbox.Transition[](1);
        transitions_[0] = _transitionFor(_payload, _proposalTimestamp, prover, _blockHash);
    }
}
