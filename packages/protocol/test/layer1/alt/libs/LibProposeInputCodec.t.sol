// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/alt/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/alt/libs/LibBlobs.sol";
import { LibProposeInputCodec } from "src/layer1/alt/libs/LibProposeInputCodec.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProposeInputCodecTest
/// @notice Unit tests for LibProposeInputCodec
/// @custom:security-contact security@taiko.xyz
contract LibProposeInputCodecTest is Test {
    function test_encode_decode_simple() public pure {
        // Setup simple test case with unique values for each field
        IInbox.CoreState memory coreState = IInbox.CoreState({
            proposalHead: 42,
            proposalHeadContainerBlock: 1234,
            finalizationHead: 38,
            synchronizationHead: 35,
            finalizationHeadTransitionHash: bytes27(uint216(98_765_432_109_876)),
            aggregatedBondInstructionsHash: bytes32(uint256(0xABCDEF123456789))
        });

        // Create empty head proposals array
        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](0);

        // Create blob reference with unique values
        LibBlobs.BlobReference memory blobReference =
            LibBlobs.BlobReference({ blobStartIndex: 3, numBlobs: 5, offset: 1024 });

        // Create empty transitions
        IInbox.Transition[] memory transitions = new IInbox.Transition[](0);

        // Create checkpoint with unique values
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 18_500_000,
            blockHash: bytes32(uint256(0x123456789ABCDEF0)),
            stateRoot: bytes32(uint256(0xFEDCBA9876543210))
        });

        // Create propose input
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_700_050_000,
            coreState: coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: blobReference,
            transitions: transitions,
            checkpoint: checkpoint,
            numForcedInclusions: 7
        });

        // Test encoding
        bytes memory encoded = LibProposeInputCodec.encode(input);
        assertGt(encoded.length, 0, "Encoded data should not be empty");

        // Test decoding
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify all fields are correctly encoded/decoded
        assertEq(decoded.deadline, input.deadline, "Deadline mismatch");
        assertEq(
            decoded.coreState.proposalHead, input.coreState.proposalHead, "ProposalHead mismatch"
        );
        assertEq(
            decoded.coreState.proposalHeadContainerBlock,
            input.coreState.proposalHeadContainerBlock,
            "ProposalHeadContainerBlock mismatch"
        );
        assertEq(
            decoded.coreState.finalizationHead,
            input.coreState.finalizationHead,
            "FinalizationHead mismatch"
        );
        assertEq(
            decoded.coreState.synchronizationHead,
            input.coreState.synchronizationHead,
            "SynchronizationHead mismatch"
        );
        assertEq(
            decoded.coreState.finalizationHeadTransitionHash,
            input.coreState.finalizationHeadTransitionHash,
            "FinalizationHeadTransitionHash mismatch"
        );
        assertEq(
            decoded.coreState.aggregatedBondInstructionsHash,
            input.coreState.aggregatedBondInstructionsHash,
            "AggregatedBondInstructionsHash mismatch"
        );

        assertEq(
            decoded.headProposalAndProof.length,
            input.headProposalAndProof.length,
            "Head proposals length mismatch"
        );
        assertEq(
            decoded.blobReference.blobStartIndex,
            input.blobReference.blobStartIndex,
            "BlobStartIndex mismatch"
        );
        assertEq(decoded.blobReference.numBlobs, input.blobReference.numBlobs, "NumBlobs mismatch");
        assertEq(decoded.blobReference.offset, input.blobReference.offset, "Blob offset mismatch");

        assertEq(
            decoded.transitions.length, input.transitions.length, "Transitions length mismatch"
        );
        assertEq(
            decoded.checkpoint.blockNumber,
            input.checkpoint.blockNumber,
            "Checkpoint blockNumber mismatch"
        );
        assertEq(
            decoded.checkpoint.blockHash,
            input.checkpoint.blockHash,
            "Checkpoint blockHash mismatch"
        );
        assertEq(
            decoded.checkpoint.stateRoot,
            input.checkpoint.stateRoot,
            "Checkpoint stateRoot mismatch"
        );
        assertEq(
            decoded.numForcedInclusions, input.numForcedInclusions, "NumForcedInclusions mismatch"
        );
    }

    function test_encode_decode_with_proposals() public pure {
        // Test with some head proposals - each field has distinct values
        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](2);

        headProposalAndProof[0] = IInbox.Proposal({
            id: 156,
            timestamp: 1_699_900_000,
            endOfSubmissionWindowTimestamp: 1_699_900_012,
            proposer: address(0xaabBccDdEe11223344556677889900aaBBccDDEE),
            coreStateHash: bytes32(uint256(0x1111111111111111)),
            derivationHash: bytes32(uint256(0x2222222222222222)),
            parentProposalHash: bytes32(uint256(0x3333333333333333))
        });

        headProposalAndProof[1] = IInbox.Proposal({
            id: 157,
            timestamp: 1_699_900_012,
            endOfSubmissionWindowTimestamp: 1_699_900_024,
            proposer: address(0x112233445566778899AabbcCDDeEFF0011223344),
            coreStateHash: bytes32(uint256(0x4444444444444444)),
            derivationHash: bytes32(uint256(0x5555555555555555)),
            parentProposalHash: bytes32(uint256(0x6666666666666666))
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            proposalHead: 158,
            proposalHeadContainerBlock: 2500,
            finalizationHead: 150,
            synchronizationHead: 145,
            finalizationHeadTransitionHash: bytes27(uint216(0x777888999AAABBBCCC)),
            aggregatedBondInstructionsHash: bytes32(uint256(0xDDDEEEFFF000111222))
        });

        LibBlobs.BlobReference memory blobReference =
            LibBlobs.BlobReference({ blobStartIndex: 4, numBlobs: 6, offset: 2048 });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_700_100_000,
            coreState: coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: blobReference,
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            numForcedInclusions: 3
        });

        // Test encoding/decoding
        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify head proposals
        assertEq(decoded.headProposalAndProof.length, 2, "Head proposals length mismatch");
        assertEq(decoded.headProposalAndProof[0].id, 156, "Head proposal 0 ID mismatch");
        assertEq(
            decoded.headProposalAndProof[0].proposer,
            address(0xaabBccDdEe11223344556677889900aaBBccDDEE),
            "Head proposal 0 proposer mismatch"
        );
        assertEq(decoded.headProposalAndProof[1].id, 157, "Head proposal 1 ID mismatch");
        assertEq(
            decoded.headProposalAndProof[1].proposer,
            address(0x112233445566778899AabbcCDDeEFF0011223344),
            "Head proposal 1 proposer mismatch"
        );

        // Verify blob reference
        assertEq(decoded.blobReference.blobStartIndex, 4, "BlobStartIndex mismatch");
        assertEq(decoded.blobReference.numBlobs, 6, "NumBlobs mismatch");
        assertEq(decoded.blobReference.offset, 2048, "Blob offset mismatch");
    }

    function test_encode_decode_with_transitions() public pure {
        // Test with transitions - each field has distinct values
        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            bondInstructionHash: bytes32(uint256(0xAAAABBBBCCCCDDDD1111)),
            checkpointHash: bytes32(uint256(0xEEEEFFFF00001111222))
        });
        transitions[1] = IInbox.Transition({
            bondInstructionHash: bytes32(uint256(0x3333444455556666777)),
            checkpointHash: bytes32(uint256(0x888899990000AAABBBC))
        });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_700_200_000,
            coreState: IInbox.CoreState({
                proposalHead: 75,
                proposalHeadContainerBlock: 1850,
                finalizationHead: 70,
                synchronizationHead: 65,
                finalizationHeadTransitionHash: bytes27(uint216(0xCCCDDDEEE111222333)),
                aggregatedBondInstructionsHash: bytes32(uint256(0x444555666777888999AAA))
            }),
            headProposalAndProof: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 2, numBlobs: 4, offset: 512 }),
            transitions: transitions,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 18_600_000,
                blockHash: bytes32(uint256(0xBBBCCCDDD000111222333)),
                stateRoot: bytes32(uint256(0x444555666777888999AAA))
            }),
            numForcedInclusions: 5
        });

        // Test encoding/decoding
        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify transitions
        assertEq(decoded.transitions.length, 2, "Transitions length mismatch");
        assertEq(
            decoded.transitions[0].bondInstructionHash,
            bytes32(uint256(0xAAAABBBBCCCCDDDD1111)),
            "Transition 0 bondInstructionHash mismatch"
        );
        assertEq(
            decoded.transitions[0].checkpointHash,
            bytes32(uint256(0xEEEEFFFF00001111222)),
            "Transition 0 checkpointHash mismatch"
        );
        assertEq(
            decoded.transitions[1].bondInstructionHash,
            bytes32(uint256(0x3333444455556666777)),
            "Transition 1 bondInstructionHash mismatch"
        );
        assertEq(
            decoded.transitions[1].checkpointHash,
            bytes32(uint256(0x888899990000AAABBBC)),
            "Transition 1 checkpointHash mismatch"
        );
    }

    function test_encode_decode_empty_checkpoint() public pure {
        // Test with empty checkpoint (should be optimized)
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 12_345,
            coreState: IInbox.CoreState({
                proposalHead: 1,
                proposalHeadContainerBlock: 99,
                finalizationHead: 0,
                synchronizationHead: 0,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            headProposalAndProof: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 0, offset: 0 }),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify empty checkpoint is handled correctly
        assertEq(decoded.checkpoint.blockNumber, 0, "Empty checkpoint blockNumber should be 0");
        assertEq(decoded.checkpoint.blockHash, bytes32(0), "Empty checkpoint blockHash should be 0");
        assertEq(decoded.checkpoint.stateRoot, bytes32(0), "Empty checkpoint stateRoot should be 0");
    }

    function test_encode_decode_synchronizationHead() public pure {
        // Test that synchronizationHead is properly encoded and decoded
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 12_345,
            coreState: IInbox.CoreState({
                proposalHead: 42,
                proposalHeadContainerBlock: 2000,
                finalizationHead: 41,
                synchronizationHead: 35, // Non-zero synchronizationHead
                finalizationHeadTransitionHash: bytes27(uint216(6666)),
                aggregatedBondInstructionsHash: bytes32(uint256(7777))
            }),
            headProposalAndProof: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 }),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify all CoreState fields including synchronizationHead
        assertEq(
            decoded.coreState.proposalHead, input.coreState.proposalHead, "Proposal head mismatch"
        );
        assertEq(
            decoded.coreState.proposalHeadContainerBlock,
            input.coreState.proposalHeadContainerBlock,
            "Proposal head container block mismatch"
        );
        assertEq(
            decoded.coreState.finalizationHead,
            input.coreState.finalizationHead,
            "Finalization head mismatch"
        );
        assertEq(
            decoded.coreState.synchronizationHead,
            input.coreState.synchronizationHead,
            "Synchronization head mismatch"
        );
        assertEq(
            decoded.coreState.finalizationHeadTransitionHash,
            input.coreState.finalizationHeadTransitionHash,
            "Finalization head transition hash mismatch"
        );
        assertEq(
            decoded.coreState.aggregatedBondInstructionsHash,
            input.coreState.aggregatedBondInstructionsHash,
            "Aggregated bond instructions hash mismatch"
        );
    }

    function test_encode_decode_maxValues() public pure {
        // Test with maximum values for uint40 fields
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: type(uint40).max,
            coreState: IInbox.CoreState({
                proposalHead: type(uint40).max,
                proposalHeadContainerBlock: type(uint40).max,
                finalizationHead: type(uint40).max,
                synchronizationHead: type(uint40).max,
                finalizationHeadTransitionHash: bytes27(type(uint216).max),
                aggregatedBondInstructionsHash: bytes32(type(uint256).max)
            }),
            headProposalAndProof: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({
                blobStartIndex: type(uint16).max,
                numBlobs: type(uint16).max,
                offset: type(uint24).max
            }),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: type(uint48).max,
                blockHash: bytes32(type(uint256).max),
                stateRoot: bytes32(type(uint256).max)
            }),
            numForcedInclusions: type(uint8).max
        });

        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        assertEq(decoded.deadline, type(uint40).max, "Max deadline should be preserved");
        assertEq(
            decoded.coreState.proposalHead, type(uint40).max, "Max proposalHead should be preserved"
        );
        assertEq(
            decoded.blobReference.blobStartIndex,
            type(uint16).max,
            "Max blobStartIndex should be preserved"
        );
        assertEq(
            decoded.numForcedInclusions,
            type(uint8).max,
            "Max numForcedInclusions should be preserved"
        );
    }

    function test_encoding_size_optimization() public pure {
        // Test that encoded size is smaller than abi.encode
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 1,
            timestamp: 100,
            endOfSubmissionWindowTimestamp: 200,
            proposer: address(0x1234),
            coreStateHash: bytes32(uint256(1)),
            derivationHash: bytes32(uint256(2)),
            parentProposalHash: bytes32(uint256(3))
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            bondInstructionHash: bytes32(uint256(4)), checkpointHash: bytes32(uint256(5))
        });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 12_345,
            coreState: IInbox.CoreState({
                proposalHead: 1,
                proposalHeadContainerBlock: 99,
                finalizationHead: 0,
                synchronizationHead: 0,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            headProposalAndProof: proposals,
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 }),
            transitions: transitions,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 100, blockHash: bytes32(uint256(6)), stateRoot: bytes32(uint256(7))
            }),
            numForcedInclusions: 1
        });

        bytes memory optimized = LibProposeInputCodec.encode(input);
        bytes memory standard = abi.encode(input);

        // Optimized encoding should be more compact than standard ABI encoding
        assertLt(
            optimized.length,
            standard.length,
            "Optimized encoding should be smaller than ABI encoding"
        );
    }

    function test_encoding_determinism() public pure {
        // Test that encoding is deterministic
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 12_345,
            coreState: IInbox.CoreState({
                proposalHead: 1,
                proposalHeadContainerBlock: 99,
                finalizationHead: 0,
                synchronizationHead: 0,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            headProposalAndProof: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 }),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        bytes memory encoded1 = LibProposeInputCodec.encode(input);
        bytes memory encoded2 = LibProposeInputCodec.encode(input);

        assertEq(keccak256(encoded1), keccak256(encoded2), "Encoding should be deterministic");
    }
}
