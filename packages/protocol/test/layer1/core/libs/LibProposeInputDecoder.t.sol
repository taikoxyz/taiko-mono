// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibProposeInputDecoder } from "src/layer1/core/libs/LibProposeInputDecoder.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract LibProposeInputDecoderTest is Test {
    function test_encode_decode_simple() public pure {
        // Setup simple test case with new structure
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 10,
            lastProposalBlockId: 999,
            lastFinalizedProposalId: 9,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });

        // Create empty parent proposals array
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](0);

        // Create blob reference
        LibBlobs.BlobReference memory blobReference =
            LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 });

        // Create empty transition records
        IInbox.TransitionRecord[] memory transitionRecords = new IInbox.TransitionRecord[](0);

        // Create checkpoint
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 100, blockHash: bytes32(uint256(123)), stateRoot: bytes32(uint256(456))
        });

        // Create propose input with new structure
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 12_345,
            coreState: coreState,
            parentProposals: parentProposals,
            blobReference: blobReference,
            transitionRecords: transitionRecords,
            checkpoint: checkpoint,
            numForcedInclusions: 2
        });

        // Test encoding
        bytes memory encoded = LibProposeInputDecoder.encode(input);
        assertGt(encoded.length, 0, "Encoded data should not be empty");

        // Test decoding
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        // Verify all fields are correctly encoded/decoded
        assertEq(decoded.deadline, input.deadline, "Deadline mismatch");
        assertEq(
            decoded.coreState.nextProposalId,
            input.coreState.nextProposalId,
            "NextProposalId mismatch"
        );
        assertEq(
            decoded.coreState.lastProposalBlockId,
            input.coreState.lastProposalBlockId,
            "LastProposalBlockId mismatch"
        );
        assertEq(
            decoded.coreState.lastFinalizedProposalId,
            input.coreState.lastFinalizedProposalId,
            "LastFinalizedProposalId mismatch"
        );
        assertEq(
            decoded.coreState.lastCheckpointTimestamp,
            input.coreState.lastCheckpointTimestamp,
            "LastCheckpointTimestamp mismatch"
        );
        assertEq(
            decoded.coreState.lastFinalizedTransitionHash,
            input.coreState.lastFinalizedTransitionHash,
            "LastFinalizedTransitionHash mismatch"
        );
        assertEq(
            decoded.coreState.bondInstructionsHash,
            input.coreState.bondInstructionsHash,
            "BondInstructionsHash mismatch"
        );

        assertEq(
            decoded.parentProposals.length,
            input.parentProposals.length,
            "Parent proposals length mismatch"
        );
        assertEq(
            decoded.blobReference.blobStartIndex,
            input.blobReference.blobStartIndex,
            "BlobStartIndex mismatch"
        );
        assertEq(decoded.blobReference.numBlobs, input.blobReference.numBlobs, "NumBlobs mismatch");
        assertEq(decoded.blobReference.offset, input.blobReference.offset, "Blob offset mismatch");

        assertEq(
            decoded.transitionRecords.length,
            input.transitionRecords.length,
            "Transition records length mismatch"
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
        // Test with some parent proposals
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](2);

        parentProposals[0] = IInbox.Proposal({
            id: 8,
            timestamp: 900,
            endOfSubmissionWindowTimestamp: 1000,
            proposer: address(0x1234),
            coreStateHash: bytes32(uint256(111)),
            derivationHash: bytes32(uint256(222))
        });

        parentProposals[1] = IInbox.Proposal({
            id: 9,
            timestamp: 950,
            endOfSubmissionWindowTimestamp: 1050,
            proposer: address(0x5678),
            coreStateHash: bytes32(uint256(333)),
            derivationHash: bytes32(uint256(444))
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 10,
            lastProposalBlockId: 999,
            lastFinalizedProposalId: 7,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: bytes32(uint256(555)),
            bondInstructionsHash: bytes32(uint256(666))
        });

        LibBlobs.BlobReference memory blobReference =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 100 });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 67_890,
            coreState: coreState,
            parentProposals: parentProposals,
            blobReference: blobReference,
            transitionRecords: new IInbox.TransitionRecord[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            numForcedInclusions: 1
        });

        // Test encoding/decoding
        bytes memory encoded = LibProposeInputDecoder.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        // Verify parent proposals
        assertEq(decoded.parentProposals.length, 2, "Parent proposals length mismatch");
        assertEq(decoded.parentProposals[0].id, 8, "Parent proposal 0 ID mismatch");
        assertEq(
            decoded.parentProposals[0].proposer,
            address(0x1234),
            "Parent proposal 0 proposer mismatch"
        );
        assertEq(decoded.parentProposals[1].id, 9, "Parent proposal 1 ID mismatch");
        assertEq(
            decoded.parentProposals[1].proposer,
            address(0x5678),
            "Parent proposal 1 proposer mismatch"
        );

        // Verify blob reference
        assertEq(decoded.blobReference.blobStartIndex, 1, "BlobStartIndex mismatch");
        assertEq(decoded.blobReference.numBlobs, 2, "NumBlobs mismatch");
        assertEq(decoded.blobReference.offset, 100, "Blob offset mismatch");
    }

    function test_encode_decode_with_transition_records() public pure {
        // Test with transition records containing bond instructions
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](2);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111),
            payee: address(0x2222)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 2,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333),
            payee: address(0x4444)
        });

        IInbox.TransitionRecord[] memory transitionRecords = new IInbox.TransitionRecord[](1);
        transitionRecords[0] = IInbox.TransitionRecord({
            span: 5,
            bondInstructions: bondInstructions,
            transitionHash: bytes32(uint256(777)),
            checkpointHash: bytes32(uint256(888))
        });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 11_111,
            coreState: IInbox.CoreState({
                nextProposalId: 5,
                lastProposalBlockId: 499,
                lastFinalizedProposalId: 4,
                lastCheckpointTimestamp: 0,
                lastFinalizedTransitionHash: bytes32(uint256(999)),
                bondInstructionsHash: bytes32(uint256(1010))
            }),
            parentProposals: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 }),
            transitionRecords: transitionRecords,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 200,
                blockHash: bytes32(uint256(1111)),
                stateRoot: bytes32(uint256(1212))
            }),
            numForcedInclusions: 0
        });

        // Test encoding/decoding
        bytes memory encoded = LibProposeInputDecoder.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        // Verify transition records
        assertEq(decoded.transitionRecords.length, 1, "Transition records length mismatch");
        assertEq(decoded.transitionRecords[0].span, 5, "Transition record span mismatch");
        assertEq(
            decoded.transitionRecords[0].bondInstructions.length,
            2,
            "Bond instructions length mismatch"
        );
        assertEq(
            decoded.transitionRecords[0].bondInstructions[0].proposalId,
            1,
            "Bond instruction 0 proposalId mismatch"
        );
        assertEq(
            uint8(decoded.transitionRecords[0].bondInstructions[0].bondType),
            uint8(LibBonds.BondType.PROVABILITY),
            "Bond instruction 0 bondType mismatch"
        );
        assertEq(
            decoded.transitionRecords[0].bondInstructions[1].proposalId,
            2,
            "Bond instruction 1 proposalId mismatch"
        );
        assertEq(
            uint8(decoded.transitionRecords[0].bondInstructions[1].bondType),
            uint8(LibBonds.BondType.LIVENESS),
            "Bond instruction 1 bondType mismatch"
        );
    }

    function test_encode_decode_empty_checkpoint() public pure {
        // Test with empty checkpoint (should be optimized)
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 12_345,
            coreState: IInbox.CoreState({
                nextProposalId: 1,
                lastProposalBlockId: 99,
                lastFinalizedProposalId: 0,
                lastCheckpointTimestamp: 0,
                lastFinalizedTransitionHash: bytes32(0),
                bondInstructionsHash: bytes32(0)
            }),
            parentProposals: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 0, offset: 0 }),
            transitionRecords: new IInbox.TransitionRecord[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        bytes memory encoded = LibProposeInputDecoder.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        // Verify empty checkpoint is handled correctly
        assertEq(decoded.checkpoint.blockNumber, 0, "Empty checkpoint blockNumber should be 0");
        assertEq(decoded.checkpoint.blockHash, bytes32(0), "Empty checkpoint blockHash should be 0");
        assertEq(decoded.checkpoint.stateRoot, bytes32(0), "Empty checkpoint stateRoot should be 0");
    }

    function test_encode_decode_lastCheckpointTimestamp() public pure {
        // Test that lastCheckpointTimestamp is properly encoded and decoded
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 12_345,
            coreState: IInbox.CoreState({
                nextProposalId: 42,
                lastProposalBlockId: 2000,
                lastFinalizedProposalId: 41,
                lastCheckpointTimestamp: 1_700_000_000, // Non-zero timestamp
                lastFinalizedTransitionHash: bytes32(uint256(6666)),
                bondInstructionsHash: bytes32(uint256(7777))
            }),
            parentProposals: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 }),
            transitionRecords: new IInbox.TransitionRecord[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        bytes memory encoded = LibProposeInputDecoder.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        // Verify all CoreState fields including lastCheckpointTimestamp
        assertEq(
            decoded.coreState.nextProposalId,
            input.coreState.nextProposalId,
            "Next proposal ID mismatch"
        );
        assertEq(
            decoded.coreState.lastProposalBlockId,
            input.coreState.lastProposalBlockId,
            "Last proposal block ID mismatch"
        );
        assertEq(
            decoded.coreState.lastFinalizedProposalId,
            input.coreState.lastFinalizedProposalId,
            "Last finalized proposal ID mismatch"
        );
        assertEq(
            decoded.coreState.lastCheckpointTimestamp,
            input.coreState.lastCheckpointTimestamp,
            "Last checkpoint timestamp mismatch"
        );
        assertEq(
            decoded.coreState.lastFinalizedTransitionHash,
            input.coreState.lastFinalizedTransitionHash,
            "Last finalized transition hash mismatch"
        );
        assertEq(
            decoded.coreState.bondInstructionsHash,
            input.coreState.bondInstructionsHash,
            "Bond instructions hash mismatch"
        );
    }

    function test_encode_decode_lastCheckpointTimestamp_maxValue() public pure {
        // Test with maximum uint48 value for lastCheckpointTimestamp
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 12_345,
            coreState: IInbox.CoreState({
                nextProposalId: 1,
                lastProposalBlockId: 1000,
                lastFinalizedProposalId: 0,
                lastCheckpointTimestamp: type(uint48).max, // Maximum value
                lastFinalizedTransitionHash: bytes32(uint256(3333)),
                bondInstructionsHash: bytes32(uint256(4444))
            }),
            parentProposals: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 }),
            transitionRecords: new IInbox.TransitionRecord[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        bytes memory encoded = LibProposeInputDecoder.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        assertEq(
            decoded.coreState.lastCheckpointTimestamp,
            type(uint48).max,
            "Max lastCheckpointTimestamp should be preserved"
        );
    }
}
