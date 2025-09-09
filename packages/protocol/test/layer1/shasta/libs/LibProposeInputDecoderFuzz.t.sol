// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibProposeInputDecoder } from "src/layer1/shasta/libs/LibProposeInputDecoder.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";

/// @title LibProposeInputDecoderFuzz
/// @notice Fuzzy tests for LibProposeInputDecoder to ensure encode/decode correctness
/// @custom:security-contact security@taiko.xyz
contract LibProposeInputDecoderFuzz is Test {
    /// @notice Fuzz test for basic encode/decode with simple types
    function testFuzz_encodeDecodeBasicTypes(
        uint48 deadline,
        uint48 nextProposalId,
        uint48 lastFinalizedProposalId,
        bytes32 lastFinalizedTransitionHash,
        bytes32 bondInstructionsHash,
        uint16 blobStartIndex,
        uint16 numBlobs,
        uint24 offset
    )
        public
        pure
    {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: deadline,
            coreState: IInbox.CoreState({
                nextProposalId: nextProposalId,
                lastFinalizedProposalId: lastFinalizedProposalId,
                lastFinalizedTransitionHash: lastFinalizedTransitionHash,
                bondInstructionsHash: bondInstructionsHash
            }),
            parentProposals: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({
                blobStartIndex: blobStartIndex,
                numBlobs: numBlobs,
                offset: offset
            }),
            transitionRecords: new IInbox.TransitionRecord[](0),
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: 0,
                blockHash: bytes32(0),
                stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        bytes memory encoded = LibProposeInputDecoder.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        // Verify
        assertEq(decoded.deadline, deadline);
        assertEq(decoded.coreState.nextProposalId, nextProposalId);
        assertEq(decoded.blobReference.blobStartIndex, blobStartIndex);
    }

    /// @notice Fuzz test for single proposal
    function testFuzz_encodeDecodeSingleProposal(
        uint48 proposalId,
        address proposer,
        uint48 timestamp,
        bytes32 coreStateHash,
        bytes32 derivationHash
    )
        public
        pure
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: proposalId,
            proposer: proposer,
            timestamp: timestamp,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: coreStateHash,
            derivationHash: derivationHash
        });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_000_000,
            coreState: IInbox.CoreState({
                nextProposalId: 100,
                lastFinalizedProposalId: 95,
                lastFinalizedTransitionHash: keccak256("test"),
                bondInstructionsHash: keccak256("bonds")
            }),
            parentProposals: proposals,
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 }),
            transitionRecords: new IInbox.TransitionRecord[](0),
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: 0,
                blockHash: bytes32(0),
                stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        // Encode and decode
        bytes memory encoded = LibProposeInputDecoder.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        // Verify
        assertEq(decoded.parentProposals.length, 1);
        assertEq(decoded.parentProposals[0].id, proposalId);
        assertEq(decoded.parentProposals[0].proposer, proposer);
    }

    /// @notice Fuzz test for transition records with bond instructions
    function testFuzz_encodeDecodeTransitionRecord(
        bytes32 transitionHash,
        bytes32 checkpointHash,
        uint8 span
    )
        public
        pure
    {
        span = uint8(bound(span, 1, 9));

        LibBonds.BondInstruction[] memory bonds = new LibBonds.BondInstruction[](1);
        bonds[0] = LibBonds.BondInstruction({
            proposalId: 100,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111),
            receiver: address(0x2222)
        });

        IInbox.TransitionRecord[] memory transitions = new IInbox.TransitionRecord[](1);
        transitions[0] = IInbox.TransitionRecord({
            span: span,
            bondInstructions: bonds,
            transitionHash: transitionHash,
            checkpointHash: checkpointHash
        });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 1_000_000,
            coreState: IInbox.CoreState({
                nextProposalId: 100,
                lastFinalizedProposalId: 95,
                lastFinalizedTransitionHash: keccak256("test"),
                bondInstructionsHash: keccak256("bonds")
            }),
            parentProposals: new IInbox.Proposal[](0),
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 }),
            transitionRecords: transitions,
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: 100,
                blockHash: keccak256("block"),
                stateRoot: keccak256("state")
            }),
            numForcedInclusions: 0
        });

        bytes memory encoded = LibProposeInputDecoder.encode(input);
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        // Verify
        assertEq(decoded.transitionRecords.length, 1);
        assertEq(decoded.transitionRecords[0].span, span);
        assertEq(decoded.transitionRecords[0].transitionHash, transitionHash);
        assertEq(decoded.transitionRecords[0].checkpointHash, checkpointHash);
    }

    /// @notice Fuzz test with variable array lengths
    function testFuzz_encodeDecodeVariableLengths(
        uint8 proposalCount,
        uint8 transitionCount,
        uint8 bondInstructionCount
    )
        public
        pure
    {
        // Bound the inputs to reasonable values
        proposalCount = uint8(bound(proposalCount, 0, 10));
        transitionCount = uint8(bound(transitionCount, 0, 10));
        bondInstructionCount = uint8(bound(bondInstructionCount, 0, 5));

        // Create test data
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 100,
            lastFinalizedProposalId: 95,
            lastFinalizedTransitionHash: keccak256("test"),
            bondInstructionsHash: keccak256("bonds")
        });

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 2, offset: 512 });

        // Create proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            proposals[i] = IInbox.Proposal({
                id: uint48(i + 1),
                proposer: address(uint160(0x1000 + i)),
                timestamp: uint48(1_000_000 + i),
                endOfSubmissionWindowTimestamp: uint48(1_000_000 + i + 12),
                coreStateHash: keccak256(abi.encodePacked("state", i)),
                derivationHash: keccak256(abi.encodePacked("derivation", i))
            });
        }

        // Create transition records
        IInbox.TransitionRecord[] memory transitionRecords =
            new IInbox.TransitionRecord[](transitionCount);
        for (uint256 i = 0; i < transitionCount; i++) {
            LibBonds.BondInstruction[] memory bondInstructions =
                new LibBonds.BondInstruction[](bondInstructionCount);
            for (uint256 j = 0; j < bondInstructionCount; j++) {
                bondInstructions[j] = LibBonds.BondInstruction({
                    proposalId: uint48(i + j),
                    bondType: j % 2 == 0 ? LibBonds.BondType.LIVENESS : LibBonds.BondType.PROVABILITY,
                    payer: address(uint160(0x2000 + i * 10 + j)),
                    receiver: address(uint160(0x3000 + i * 10 + j))
                });
            }

            transitionRecords[i] = IInbox.TransitionRecord({
                span: uint8(1 + (i % 3)),
                bondInstructions: bondInstructions,
                transitionHash: keccak256(abi.encodePacked("transition", i)),
                checkpointHash: keccak256(abi.encodePacked("endBlock", i))
            });
        }

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 999_999,
            coreState: coreState,
            parentProposals: proposals,
            blobReference: blobRef,
            transitionRecords: transitionRecords,
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: 2_000_000,
                blockHash: keccak256("endBlock"),
                stateRoot: keccak256("endState")
            }),
            numForcedInclusions: 0
        });

        // Encode
        bytes memory encoded = LibProposeInputDecoder.encode(input);

        // Decode
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(encoded);

        // Verify basic properties
        assertEq(decoded.deadline, 999_999, "Deadline mismatch");
        assertEq(decoded.parentProposals.length, proposalCount, "Proposals length mismatch");
        assertEq(
            decoded.transitionRecords.length, transitionCount, "TransitionRecords length mismatch"
        );

        // Verify proposal details
        for (uint256 i = 0; i < proposalCount; i++) {
            assertEq(decoded.parentProposals[i].id, proposals[i].id, "Proposal id mismatch");
            assertEq(
                decoded.parentProposals[i].proposer, proposals[i].proposer, "Proposer mismatch"
            );
            assertEq(
                decoded.parentProposals[i].timestamp, proposals[i].timestamp, "Timestamp mismatch"
            );
            assertEq(
                decoded.parentProposals[i].coreStateHash,
                proposals[i].coreStateHash,
                "Core state hash mismatch"
            );
            assertEq(
                decoded.parentProposals[i].derivationHash,
                proposals[i].derivationHash,
                "Derivation hash mismatch"
            );
        }

        // Verify transition record details
        for (uint256 i = 0; i < transitionCount; i++) {
            assertEq(
                decoded.transitionRecords[i].span,
                transitionRecords[i].span,
                "TransitionRecord span mismatch"
            );
            assertEq(
                decoded.transitionRecords[i].bondInstructions.length,
                bondInstructionCount,
                "Bond instruction count mismatch"
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
        IInbox.ProposeInput memory input =
            _createTestData(proposalCount, transitionCount, proposalCount * 2);

        // Encode with both methods
        bytes memory abiEncoded = abi.encode(input);
        bytes memory libEncoded = LibProposeInputDecoder.encode(input);

        // Verify LibProposeInputDecoder produces smaller output
        assertLt(
            libEncoded.length,
            abiEncoded.length,
            "LibProposeInputDecoder should produce smaller output"
        );

        // Verify decode produces identical results
        IInbox.ProposeInput memory decoded = LibProposeInputDecoder.decode(libEncoded);

        assertEq(decoded.deadline, input.deadline, "Deadline mismatch after decode");
        assertEq(
            decoded.coreState.nextProposalId, input.coreState.nextProposalId, "CoreState mismatch"
        );
        assertEq(
            decoded.parentProposals.length,
            input.parentProposals.length,
            "Proposals length mismatch"
        );
        assertEq(
            decoded.transitionRecords.length,
            input.transitionRecords.length,
            "TransitionRecords length mismatch"
        );
    }

    /// @notice Helper function to create test data
    function _createTestData(
        uint256 _proposalCount,
        uint256 _transitionCount,
        uint256 _totalBondInstructions
    )
        private
        pure
        returns (IInbox.ProposeInput memory input)
    {
        input.deadline = 2_000_000;

        input.coreState = IInbox.CoreState({
            nextProposalId: 100,
            lastFinalizedProposalId: 95,
            lastFinalizedTransitionHash: keccak256("last_finalized"),
            bondInstructionsHash: keccak256("bond_instructions")
        });

        input.parentProposals = new IInbox.Proposal[](_proposalCount);
        for (uint256 i = 0; i < _proposalCount; i++) {
            input.parentProposals[i] = IInbox.Proposal({
                id: uint48(96 + i),
                proposer: address(uint160(0x1000 + i)),
                timestamp: uint48(1_000_000 + i * 10),
                endOfSubmissionWindowTimestamp: uint48(1_000_000 + i * 10 + 12),
                coreStateHash: keccak256(abi.encodePacked("core_state", i)),
                derivationHash: keccak256(abi.encodePacked("derivation", i))
            });
        }

        input.blobReference = LibBlobs.BlobReference({
            blobStartIndex: 1,
            numBlobs: uint16(_proposalCount * 2),
            offset: 512
        });

        input.transitionRecords = new IInbox.TransitionRecord[](_transitionCount);
        uint256 bondIndex = 0;
        for (uint256 i = 0; i < _transitionCount; i++) {
            uint256 bondsForThisTransition = 0;
            if (i < _transitionCount - 1) {
                bondsForThisTransition = _totalBondInstructions / _transitionCount;
            } else {
                bondsForThisTransition = _totalBondInstructions - bondIndex;
            }

            LibBonds.BondInstruction[] memory bondInstructions =
                new LibBonds.BondInstruction[](bondsForThisTransition);
            for (uint256 j = 0; j < bondsForThisTransition; j++) {
                bondInstructions[j] = LibBonds.BondInstruction({
                    proposalId: uint48(96 + i),
                    bondType: j % 2 == 0 ? LibBonds.BondType.LIVENESS : LibBonds.BondType.PROVABILITY,
                    payer: address(uint160(0xaaaa + bondIndex)),
                    receiver: address(uint160(0xbbbb + bondIndex))
                });
                bondIndex++;
            }

            input.transitionRecords[i] = IInbox.TransitionRecord({
                span: uint8(1 + (i % 3)),
                bondInstructions: bondInstructions,
                transitionHash: keccak256(abi.encodePacked("transition", i)),
                checkpointHash: keccak256(abi.encodePacked("endBlock", i))
            });
        }

        input.checkpoint = ICheckpointManager.Checkpoint({
            blockNumber: 2_000_000,
            blockHash: keccak256("final_end_block"),
            stateRoot: keccak256("final_end_state")
        });
    }
}
