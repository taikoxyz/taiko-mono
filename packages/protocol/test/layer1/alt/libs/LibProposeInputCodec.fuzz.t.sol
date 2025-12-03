// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/alt/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/alt/libs/LibBlobs.sol";
import { LibProposeInputCodec } from "src/layer1/alt/libs/LibProposeInputCodec.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProposeInputCodecFuzzTest
/// @notice Fuzz tests for LibProposeInputCodec to ensure encode/decode correctness
/// @custom:security-contact security@taiko.xyz
contract LibProposeInputCodecFuzzTest is Test {
    /// @notice Fuzz test for basic encode/decode with simple types
    function testFuzz_encodeDecodeBasicTypes(
        uint40 deadline,
        uint40 proposalHead,
        uint40 finalizationHead,
        bytes27 finalizationHeadTransitionHash,
        bytes32 aggregatedBondInstructionsHash,
        uint16 blobStartIndex,
        uint16 numBlobs,
        uint24 offset
    )
        public
        pure
    {
        // Bound proposalHead to avoid issues
        proposalHead = uint40(bound(proposalHead, 1, 2_800_000));
        finalizationHead = uint40(bound(finalizationHead, 0, proposalHead));

        uint40 proposalHeadContainerBlock = proposalHead == 1 ? uint40(0) : proposalHead - 1;

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: deadline,
            coreState: IInbox.CoreState({
                proposalHead: proposalHead,
                proposalHeadContainerBlock: proposalHeadContainerBlock,
                finalizationHead: finalizationHead,
                synchronizationHead: 0,
                finalizationHeadTransitionHash: finalizationHeadTransitionHash,
                aggregatedBondInstructionsHash: aggregatedBondInstructionsHash
            }),
            headProposalAndProof: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({
                blobStartIndex: blobStartIndex, numBlobs: numBlobs, offset: offset
            }),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify
        assertEq(decoded.deadline, deadline);
        assertEq(decoded.coreState.proposalHead, proposalHead);
        assertEq(decoded.coreState.proposalHeadContainerBlock, proposalHeadContainerBlock);
        assertEq(decoded.blobReference.blobStartIndex, blobStartIndex);
    }

    /// @notice Fuzz test for single proposal - all proposal fields are fuzzed
    function testFuzz_encodeDecodeSingleProposal(
        uint40 proposalId,
        address proposer,
        uint40 timestamp,
        uint40 endOfSubmissionWindowTimestamp,
        bytes32 coreStateHash,
        bytes32 derivationHash,
        bytes32 parentProposalHash
    )
        public
        pure
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: proposalId,
            proposer: proposer,
            timestamp: timestamp,
            endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
            coreStateHash: coreStateHash,
            derivationHash: derivationHash,
            parentProposalHash: parentProposalHash
        });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_000_000,
            coreState: IInbox.CoreState({
                proposalHead: 100,
                proposalHeadContainerBlock: 9999,
                finalizationHead: 95,
                synchronizationHead: 90,
                finalizationHeadTransitionHash: bytes27(keccak256("test")),
                aggregatedBondInstructionsHash: keccak256("bonds")
            }),
            headProposalAndProof: proposals,
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 }),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        // Encode and decode
        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify all fuzzed fields
        assertEq(decoded.headProposalAndProof.length, 1);
        assertEq(decoded.headProposalAndProof[0].id, proposalId);
        assertEq(decoded.headProposalAndProof[0].proposer, proposer);
        assertEq(decoded.headProposalAndProof[0].timestamp, timestamp);
        assertEq(
            decoded.headProposalAndProof[0].endOfSubmissionWindowTimestamp,
            endOfSubmissionWindowTimestamp
        );
        assertEq(decoded.headProposalAndProof[0].coreStateHash, coreStateHash);
        assertEq(decoded.headProposalAndProof[0].derivationHash, derivationHash);
        assertEq(decoded.headProposalAndProof[0].parentProposalHash, parentProposalHash);
    }

    /// @notice Fuzz test for transitions
    function testFuzz_encodeDecodeTransition(
        bytes32 bondInstructionHash,
        bytes32 checkpointHash
    )
        public
        pure
    {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            bondInstructionHash: bondInstructionHash, checkpointHash: checkpointHash
        });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_000_000,
            coreState: IInbox.CoreState({
                proposalHead: 100,
                proposalHeadContainerBlock: 9999,
                finalizationHead: 95,
                synchronizationHead: 90,
                finalizationHeadTransitionHash: bytes27(keccak256("test")),
                aggregatedBondInstructionsHash: keccak256("bonds")
            }),
            headProposalAndProof: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 }),
            transitions: transitions,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 100, blockHash: keccak256("block"), stateRoot: keccak256("state")
            }),
            numForcedInclusions: 0
        });

        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify
        assertEq(decoded.transitions.length, 1);
        assertEq(decoded.transitions[0].bondInstructionHash, bondInstructionHash);
        assertEq(decoded.transitions[0].checkpointHash, checkpointHash);
    }

    /// @notice Fuzz test with variable array lengths
    function testFuzz_encodeDecodeVariableLengths(
        uint8 proposalCount,
        uint8 transitionCount
    )
        public
        pure
    {
        // Bound the inputs to reasonable values
        proposalCount = uint8(bound(proposalCount, 0, 10));
        transitionCount = uint8(bound(transitionCount, 0, 10));

        // Create test data
        IInbox.CoreState memory coreState = IInbox.CoreState({
            proposalHead: 100,
            proposalHeadContainerBlock: 0,
            finalizationHead: 95,
            synchronizationHead: 90,
            finalizationHeadTransitionHash: bytes27(keccak256("test")),
            aggregatedBondInstructionsHash: keccak256("bonds")
        });

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 });

        // Create proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            proposals[i] = IInbox.Proposal({
                id: uint40(i + 1),
                proposer: address(uint160(0x1000 + i)),
                timestamp: uint40(1_000_000 + i),
                endOfSubmissionWindowTimestamp: uint40(1_000_000 + i + 12),
                coreStateHash: keccak256(abi.encodePacked("state", i)),
                derivationHash: keccak256(abi.encodePacked("derivation", i)),
                parentProposalHash: keccak256(abi.encodePacked("parentProposal", i))
            });
        }

        // Create transitions
        IInbox.Transition[] memory transitions = new IInbox.Transition[](transitionCount);
        for (uint256 i = 0; i < transitionCount; i++) {
            transitions[i] = IInbox.Transition({
                bondInstructionHash: keccak256(abi.encodePacked("bondInstruction", i)),
                checkpointHash: keccak256(abi.encodePacked("checkpoint", i))
            });
        }

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 999_999,
            coreState: coreState,
            headProposalAndProof: proposals,
            blobReference: blobRef,
            transitions: transitions,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 2_000_000,
                blockHash: keccak256("endBlock"),
                stateRoot: keccak256("endState")
            }),
            numForcedInclusions: 0
        });

        // Encode
        bytes memory encoded = LibProposeInputCodec.encode(input);

        // Decode
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify basic properties
        assertEq(decoded.deadline, 999_999, "Deadline mismatch");
        assertEq(decoded.headProposalAndProof.length, proposalCount, "Proposals length mismatch");
        assertEq(decoded.transitions.length, transitionCount, "Transitions length mismatch");

        // Verify proposal details
        for (uint256 i = 0; i < proposalCount; i++) {
            assertEq(decoded.headProposalAndProof[i].id, proposals[i].id, "Proposal id mismatch");
            assertEq(
                decoded.headProposalAndProof[i].proposer, proposals[i].proposer, "Proposer mismatch"
            );
            assertEq(
                decoded.headProposalAndProof[i].timestamp,
                proposals[i].timestamp,
                "Timestamp mismatch"
            );
            assertEq(
                decoded.headProposalAndProof[i].coreStateHash,
                proposals[i].coreStateHash,
                "Core state hash mismatch"
            );
            assertEq(
                decoded.headProposalAndProof[i].derivationHash,
                proposals[i].derivationHash,
                "Derivation hash mismatch"
            );
        }

        // Verify transition details
        for (uint256 i = 0; i < transitionCount; i++) {
            assertEq(
                decoded.transitions[i].bondInstructionHash,
                transitions[i].bondInstructionHash,
                "Bond instruction hash mismatch"
            );
            assertEq(
                decoded.transitions[i].checkpointHash,
                transitions[i].checkpointHash,
                "Checkpoint hash mismatch"
            );
        }
    }

    /// @notice Fuzz test to ensure encoded size is always smaller than abi.encode
    function testFuzz_encodedSizeComparison(
        uint8 proposalCount,
        uint8 transitionCount
    )
        public
        pure
    {
        // Bound the inputs
        proposalCount = uint8(bound(proposalCount, 1, 10));
        transitionCount = uint8(bound(transitionCount, 1, 10));

        // Create test data
        IInbox.ProposeInput memory input = _createTestData(proposalCount, transitionCount);

        // Encode with both methods
        bytes memory abiEncoded = abi.encode(input);
        bytes memory libEncoded = LibProposeInputCodec.encode(input);

        // Verify LibProposeInputCodec produces smaller output
        assertLt(
            libEncoded.length,
            abiEncoded.length,
            "LibProposeInputCodec should produce smaller output"
        );

        // Verify decode produces identical results
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(libEncoded);

        assertEq(decoded.deadline, input.deadline, "Deadline mismatch after decode");
        assertEq(decoded.coreState.proposalHead, input.coreState.proposalHead, "CoreState mismatch");
        assertEq(
            decoded.headProposalAndProof.length,
            input.headProposalAndProof.length,
            "Proposals length mismatch"
        );
        assertEq(
            decoded.transitions.length, input.transitions.length, "Transitions length mismatch"
        );
    }

    /// @notice Helper function to create test data
    function _createTestData(
        uint256 _proposalCount,
        uint256 _transitionCount
    )
        private
        pure
        returns (IInbox.ProposeInput memory input)
    {
        input.deadline = 2_000_000;

        input.coreState = IInbox.CoreState({
            proposalHead: 100,
            proposalHeadContainerBlock: 0,
            finalizationHead: 95,
            synchronizationHead: 90,
            finalizationHeadTransitionHash: bytes27(keccak256("last_finalized")),
            aggregatedBondInstructionsHash: keccak256("bond_instructions")
        });

        input.headProposalAndProof = new IInbox.Proposal[](_proposalCount);
        for (uint256 i = 0; i < _proposalCount; i++) {
            input.headProposalAndProof[i] = IInbox.Proposal({
                id: uint40(96 + i),
                proposer: address(uint160(0x1000 + i)),
                timestamp: uint40(1_000_000 + i * 10),
                endOfSubmissionWindowTimestamp: uint40(1_000_000 + i * 10 + 12),
                coreStateHash: keccak256(abi.encodePacked("core_state", i)),
                derivationHash: keccak256(abi.encodePacked("derivation", i)),
                parentProposalHash: keccak256(abi.encodePacked("parentProposal", i))
            });
        }

        input.blobReference = LibBlobs.BlobReference({
            blobStartIndex: 1, numBlobs: uint16(_proposalCount * 2), offset: 512
        });

        input.transitions = new IInbox.Transition[](_transitionCount);
        for (uint256 i = 0; i < _transitionCount; i++) {
            input.transitions[i] = IInbox.Transition({
                bondInstructionHash: keccak256(abi.encodePacked("bondInstruction", i)),
                checkpointHash: keccak256(abi.encodePacked("checkpoint", i))
            });
        }

        input.checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 2_000_000,
            blockHash: keccak256("final_end_block"),
            stateRoot: keccak256("final_end_state")
        });
    }

    /// @notice Fuzz test for synchronizationHead field
    function testFuzz_encodeDecodeCoreState_synchronizationHead(
        uint40 proposalHead,
        uint40 proposalHeadContainerBlock,
        uint40 finalizationHead,
        uint40 synchronizationHead,
        bytes27 finalizationHeadTransitionHash,
        bytes32 aggregatedBondInstructionsHash
    )
        public
        pure
    {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 12_345,
            coreState: IInbox.CoreState({
                proposalHead: proposalHead,
                proposalHeadContainerBlock: proposalHeadContainerBlock,
                finalizationHead: finalizationHead,
                synchronizationHead: synchronizationHead,
                finalizationHeadTransitionHash: finalizationHeadTransitionHash,
                aggregatedBondInstructionsHash: aggregatedBondInstructionsHash
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
        assertEq(decoded.coreState.proposalHead, input.coreState.proposalHead);
        assertEq(
            decoded.coreState.proposalHeadContainerBlock, input.coreState.proposalHeadContainerBlock
        );
        assertEq(decoded.coreState.finalizationHead, input.coreState.finalizationHead);
        assertEq(decoded.coreState.synchronizationHead, input.coreState.synchronizationHead);
        assertEq(
            decoded.coreState.finalizationHeadTransitionHash,
            input.coreState.finalizationHeadTransitionHash
        );
        assertEq(
            decoded.coreState.aggregatedBondInstructionsHash,
            input.coreState.aggregatedBondInstructionsHash
        );
    }

    /// @notice Fuzz test for checkpoint fields
    function testFuzz_encodeDecodeCheckpoint(
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        pure
    {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_700_000_000,
            coreState: IInbox.CoreState({
                proposalHead: 100,
                proposalHeadContainerBlock: 9999,
                finalizationHead: 95,
                synchronizationHead: 90,
                finalizationHeadTransitionHash: bytes27(keccak256("test")),
                aggregatedBondInstructionsHash: keccak256("bonds")
            }),
            headProposalAndProof: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 }),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber, blockHash: blockHash, stateRoot: stateRoot
            }),
            numForcedInclusions: 3
        });

        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify all checkpoint fields
        assertEq(decoded.checkpoint.blockNumber, blockNumber);
        assertEq(decoded.checkpoint.blockHash, blockHash);
        assertEq(decoded.checkpoint.stateRoot, stateRoot);
    }

    /// @notice Fuzz test for numForcedInclusions field
    function testFuzz_encodeDecodeNumForcedInclusions(uint8 numForcedInclusions) public pure {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_700_000_000,
            coreState: IInbox.CoreState({
                proposalHead: 100,
                proposalHeadContainerBlock: 9999,
                finalizationHead: 95,
                synchronizationHead: 90,
                finalizationHeadTransitionHash: bytes27(keccak256("test")),
                aggregatedBondInstructionsHash: keccak256("bonds")
            }),
            headProposalAndProof: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 }),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 18_000_000,
                blockHash: keccak256("block"),
                stateRoot: keccak256("state")
            }),
            numForcedInclusions: numForcedInclusions
        });

        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        assertEq(decoded.numForcedInclusions, numForcedInclusions);
    }

    /// @notice Fuzz test for blob reference fields
    function testFuzz_encodeDecodeBlobReference(
        uint16 blobStartIndex,
        uint16 numBlobs,
        uint24 offset
    )
        public
        pure
    {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_700_000_000,
            coreState: IInbox.CoreState({
                proposalHead: 100,
                proposalHeadContainerBlock: 9999,
                finalizationHead: 95,
                synchronizationHead: 90,
                finalizationHeadTransitionHash: bytes27(keccak256("test")),
                aggregatedBondInstructionsHash: keccak256("bonds")
            }),
            headProposalAndProof: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({
                blobStartIndex: blobStartIndex, numBlobs: numBlobs, offset: offset
            }),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 18_000_000,
                blockHash: keccak256("block"),
                stateRoot: keccak256("state")
            }),
            numForcedInclusions: 3
        });

        bytes memory encoded = LibProposeInputCodec.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputCodec.decode(encoded);

        // Verify blob reference fields
        assertEq(decoded.blobReference.blobStartIndex, blobStartIndex);
        assertEq(decoded.blobReference.numBlobs, numBlobs);
        assertEq(decoded.blobReference.offset, offset);
    }
}
