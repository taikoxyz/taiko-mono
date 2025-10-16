// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProveInputDecoder } from "src/layer1/core/libs/LibProveInputDecoder.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProveInputDecoderTest
/// @notice Tests for LibProveInputDecoder
contract LibProveInputDecoderTest is Test {
    function test_encode_decode_simple() public pure {
        // Create simple prove input with one proposal and one transition
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 10,
            timestamp: 1000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            proposer: address(0x1234),
            coreStateHash: bytes32(uint256(1)),
            derivationHash: bytes32(uint256(2))
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(3)),
            parentTransitionHash: bytes32(uint256(4)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 100, blockHash: bytes32(uint256(5)), stateRoot: bytes32(uint256(6))
            })
        });

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(0x5678), actualProver: address(0x9ABC)
        });

        // Create ProveInput (no endBlockHeader field)
        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        // Test encoding
        bytes memory encoded = LibProveInputDecoder.encode(input);
        assertGt(encoded.length, 0, "Encoded data should not be empty");

        // Test decoding
        IInbox.ProveInput memory decoded = LibProveInputDecoder.decode(encoded);

        // Verify proposals array
        assertEq(decoded.proposals.length, 1, "Proposals length mismatch");
        assertEq(decoded.proposals[0].id, 10, "Proposal ID mismatch");
        assertEq(decoded.proposals[0].proposer, address(0x1234), "Proposer mismatch");
        assertEq(decoded.proposals[0].timestamp, 1000, "Timestamp mismatch");
        assertEq(
            decoded.proposals[0].coreStateHash, bytes32(uint256(1)), "Core state hash mismatch"
        );

        // Verify transitions array
        assertEq(decoded.transitions.length, 1, "Transitions length mismatch");
        assertEq(decoded.transitions[0].proposalHash, bytes32(uint256(3)), "Proposal hash mismatch");
        assertEq(
            decoded.transitions[0].parentTransitionHash,
            bytes32(uint256(4)),
            "Parent transition hash mismatch"
        );
        assertEq(
            decoded.transitions[0].checkpoint.blockNumber, 100, "Checkpoint block number mismatch"
        );

        // Verify metadata array
        assertEq(decoded.metadata.length, 1, "Metadata length mismatch");
        assertEq(
            decoded.metadata[0].designatedProver, address(0x5678), "Designated prover mismatch"
        );
        assertEq(decoded.metadata[0].actualProver, address(0x9ABC), "Actual prover mismatch");
    }

    function test_encode_decode_multiple() public pure {
        // Test with multiple proposals, transitions, and metadata
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = IInbox.Proposal({
            id: 1,
            timestamp: 100,
            endOfSubmissionWindowTimestamp: 200,
            proposer: address(0x1111),
            coreStateHash: bytes32(uint256(11)),
            derivationHash: bytes32(uint256(12))
        });
        proposals[1] = IInbox.Proposal({
            id: 2,
            timestamp: 300,
            endOfSubmissionWindowTimestamp: 400,
            proposer: address(0x2222),
            coreStateHash: bytes32(uint256(21)),
            derivationHash: bytes32(uint256(22))
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(31)),
            parentTransitionHash: bytes32(uint256(32)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 1000, blockHash: bytes32(uint256(33)), stateRoot: bytes32(uint256(34))
            })
        });
        transitions[1] = IInbox.Transition({
            proposalHash: bytes32(uint256(41)),
            parentTransitionHash: bytes32(uint256(42)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 2000, blockHash: bytes32(uint256(43)), stateRoot: bytes32(uint256(44))
            })
        });

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](2);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(0x3333), actualProver: address(0x5555)
        });
        metadata[1] = IInbox.TransitionMetadata({
            designatedProver: address(0x4444), actualProver: address(0x6666)
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        // Test encoding/decoding
        bytes memory encoded = LibProveInputDecoder.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputDecoder.decode(encoded);

        // Verify arrays have correct lengths
        assertEq(decoded.proposals.length, 2, "Proposals length mismatch");
        assertEq(decoded.transitions.length, 2, "Transitions length mismatch");
        assertEq(decoded.metadata.length, 2, "Metadata length mismatch");

        // Verify second elements (first were tested in simple test)
        assertEq(decoded.proposals[1].id, 2, "Proposal 1 ID mismatch");
        assertEq(decoded.proposals[1].proposer, address(0x2222), "Proposal 1 proposer mismatch");
        assertEq(
            decoded.transitions[1].proposalHash,
            bytes32(uint256(41)),
            "Transition 1 proposal hash mismatch"
        );
        assertEq(
            decoded.metadata[1].designatedProver,
            address(0x4444),
            "Metadata 1 designated prover mismatch"
        );
    }

    function test_encode_decode_empty_arrays() public pure {
        // Test with empty arrays
        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: new IInbox.Proposal[](0),
            transitions: new IInbox.Transition[](0),
            metadata: new IInbox.TransitionMetadata[](0)
        });

        bytes memory encoded = LibProveInputDecoder.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputDecoder.decode(encoded);

        assertEq(decoded.proposals.length, 0, "Empty proposals array mismatch");
        assertEq(decoded.transitions.length, 0, "Empty transitions array mismatch");
        assertEq(decoded.metadata.length, 0, "Empty metadata array mismatch");
    }

    function test_encoding_size_optimization() public pure {
        // Test that encoded size is reasonable
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 1,
            timestamp: 100,
            endOfSubmissionWindowTimestamp: 200,
            proposer: address(0x1234),
            coreStateHash: bytes32(uint256(1)),
            derivationHash: bytes32(uint256(2))
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(3)),
            parentTransitionHash: bytes32(uint256(4)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 100, blockHash: bytes32(uint256(5)), stateRoot: bytes32(uint256(6))
            })
        });

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(0x5678), actualProver: address(0x9DEF)
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        bytes memory optimized = LibProveInputDecoder.encode(input);
        bytes memory standard = abi.encode(input);

        // Optimized encoding should be more compact than standard ABI encoding
        assertLt(
            optimized.length,
            standard.length,
            "Optimized encoding should be smaller than ABI encoding"
        );
    }
}
