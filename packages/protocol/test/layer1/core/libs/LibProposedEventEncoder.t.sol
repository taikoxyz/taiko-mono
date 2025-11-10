// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibProposedEventEncoder } from "src/layer1/core/libs/LibProposedEventEncoder.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibProposedEventEncoderTest
/// @notice Tests for LibProposedEventEncoder
contract LibProposedEventEncoderTest is Test {
    function test_encode_decode_simple() public pure {
        // Create proposal
        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 1,
            timestamp: 1000,
            endOfSubmissionWindowTimestamp: 1500,
            proposer: address(0x1234567890123456789012345678901234567890),
            coreStateHash: bytes32(uint256(111)),
            derivationHash: bytes32(uint256(222))
        });

        // Create derivation with new structure (with sources array)
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);

        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = bytes32(uint256(333));
        blobHashes[1] = bytes32(uint256(444));

        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes, offset: 100, timestamp: 3000 })
        });

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: 2000,
            originBlockHash: bytes32(uint256(2000)),
            basefeeSharingPctg: 50,
            sources: sources
        });

        // Create core state
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 2,
            lastProposalBlockId: 1000,
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: bytes32(uint256(555)),
            bondInstructionsHash: bytes32(uint256(666))
        });

        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](2);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111111111111111111111111111111111111111),
            payee: address(0x2222222222222222222222222222222222222222)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 2,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333333333333333333333333333333333333333),
            payee: address(0x4444444444444444444444444444444444444444)
        });

        // Create proposed event payload
        IInbox.ProposedEventPayload memory original = IInbox.ProposedEventPayload({
            proposal: proposal,
            derivation: derivation,
            coreState: coreState,
            bondInstructions: bondInstructions
        });

        // Test encoding
        bytes memory encoded = LibProposedEventEncoder.encode(original);
        assertGt(encoded.length, 0, "Encoded data should not be empty");

        // Test decoding
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify proposal fields
        assertEq(decoded.proposal.id, original.proposal.id, "Proposal ID mismatch");
        assertEq(decoded.proposal.proposer, original.proposal.proposer, "Proposer mismatch");
        assertEq(decoded.proposal.timestamp, original.proposal.timestamp, "Timestamp mismatch");
        assertEq(
            decoded.proposal.coreStateHash,
            original.proposal.coreStateHash,
            "Core state hash mismatch"
        );

        // Verify derivation fields
        assertEq(
            decoded.derivation.originBlockNumber,
            original.derivation.originBlockNumber,
            "Origin block number mismatch"
        );
        assertEq(
            decoded.derivation.originBlockHash,
            original.derivation.originBlockHash,
            "Origin block hash mismatch"
        );
        assertEq(
            decoded.derivation.basefeeSharingPctg,
            original.derivation.basefeeSharingPctg,
            "Basefee sharing percentage mismatch"
        );
        assertEq(decoded.derivation.sources.length, 1, "Sources array length mismatch");
        assertEq(
            decoded.derivation.sources[0].isForcedInclusion, false, "Forced inclusion flag mismatch"
        );
        assertEq(
            decoded.derivation.sources[0].blobSlice.blobHashes.length,
            2,
            "Blob hashes length mismatch"
        );

        // Verify core state fields
        assertEq(
            decoded.coreState.nextProposalId,
            original.coreState.nextProposalId,
            "Next proposal ID mismatch"
        );
        assertEq(
            decoded.coreState.lastProposalBlockId,
            original.coreState.lastProposalBlockId,
            "Last proposal block ID mismatch"
        );
        assertEq(
            decoded.coreState.lastFinalizedProposalId,
            original.coreState.lastFinalizedProposalId,
            "Last finalized proposal ID mismatch"
        );
        assertEq(
            decoded.coreState.lastFinalizedTransitionHash,
            original.coreState.lastFinalizedTransitionHash,
            "Last finalized transition hash mismatch"
        );
        assertEq(
            decoded.coreState.bondInstructionsHash,
            original.coreState.bondInstructionsHash,
            "Bond instructions hash mismatch"
        );

        assertEq(
            decoded.bondInstructions.length,
            original.bondInstructions.length,
            "Bond instruction length mismatch"
        );

        for (uint256 i; i < original.bondInstructions.length; ++i) {
            assertEq(
                decoded.bondInstructions[i].proposalId,
                original.bondInstructions[i].proposalId,
                "Bond instruction proposal id mismatch"
            );
            assertEq(
                uint8(decoded.bondInstructions[i].bondType),
                uint8(original.bondInstructions[i].bondType),
                "Bond instruction type mismatch"
            );
            assertEq(
                decoded.bondInstructions[i].payer,
                original.bondInstructions[i].payer,
                "Bond instruction payer mismatch"
            );
            assertEq(
                decoded.bondInstructions[i].payee,
                original.bondInstructions[i].payee,
                "Bond instruction payee mismatch"
            );
        }
    }

    function test_encode_decode_empty_sources() public pure {
        // Test with empty sources array
        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 10,
                timestamp: 5000,
                endOfSubmissionWindowTimestamp: 6000,
                proposer: address(0x9999),
                coreStateHash: bytes32(uint256(777)),
                derivationHash: bytes32(uint256(888))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 1000,
                originBlockHash: bytes32(uint256(1000)),
                basefeeSharingPctg: 25,
                sources: new IInbox.DerivationSource[](0)
            }),
            coreState: IInbox.CoreState({
                nextProposalId: 11,
                lastProposalBlockId: 5000,
                lastFinalizedProposalId: 9,
                lastCheckpointTimestamp: 0,
                lastFinalizedTransitionHash: bytes32(uint256(999)),
                bondInstructionsHash: bytes32(0)
            }),
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        assertEq(decoded.derivation.sources.length, 0, "Empty sources array should remain empty");
        assertEq(decoded.proposal.id, 10, "Proposal ID should match");
        assertEq(decoded.coreState.nextProposalId, 11, "Core state should match");
    }

    function test_encode_decode_multiple_sources() public pure {
        // Test with multiple sources
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](2);

        // First source - forced inclusion
        bytes32[] memory blobHashes1 = new bytes32[](1);
        blobHashes1[0] = bytes32(uint256(123));
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes1, offset: 0, timestamp: 1000 })
        });

        // Second source - regular
        bytes32[] memory blobHashes2 = new bytes32[](3);
        blobHashes2[0] = bytes32(uint256(456));
        blobHashes2[1] = bytes32(uint256(789));
        blobHashes2[2] = bytes32(uint256(101_112));
        sources[1] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes2, offset: 500, timestamp: 2000 })
        });

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 5,
                timestamp: 2500,
                endOfSubmissionWindowTimestamp: 3000,
                proposer: address(0xABCD),
                coreStateHash: bytes32(uint256(1313)),
                derivationHash: bytes32(uint256(1414))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 500,
                originBlockHash: bytes32(uint256(500)),
                basefeeSharingPctg: 75,
                sources: sources
            }),
            coreState: IInbox.CoreState({
                nextProposalId: 6,
                lastProposalBlockId: 2500,
                lastFinalizedProposalId: 4,
                lastCheckpointTimestamp: 0,
                lastFinalizedTransitionHash: bytes32(uint256(1515)),
                bondInstructionsHash: bytes32(uint256(1616))
            }),
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify multiple sources
        assertEq(decoded.derivation.sources.length, 2, "Should have 2 sources");
        assertEq(
            decoded.derivation.sources[0].isForcedInclusion,
            true,
            "First source should be forced inclusion"
        );
        assertEq(
            decoded.derivation.sources[1].isForcedInclusion,
            false,
            "Second source should not be forced inclusion"
        );
        assertEq(
            decoded.derivation.sources[0].blobSlice.blobHashes.length,
            1,
            "First source should have 1 blob hash"
        );
        assertEq(
            decoded.derivation.sources[1].blobSlice.blobHashes.length,
            3,
            "Second source should have 3 blob hashes"
        );
    }

    function test_encoding_determinism() public pure {
        // Test that encoding is deterministic
        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 1,
                timestamp: 1000,
                endOfSubmissionWindowTimestamp: 2000,
                proposer: address(0x1111),
                coreStateHash: bytes32(uint256(2222)),
                derivationHash: bytes32(uint256(3333))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 100,
                originBlockHash: bytes32(uint256(100)),
                basefeeSharingPctg: 50,
                sources: new IInbox.DerivationSource[](0)
            }),
            coreState: IInbox.CoreState({
                nextProposalId: 2,
                lastProposalBlockId: 1000,
                lastFinalizedProposalId: 0,
                lastCheckpointTimestamp: 0,
                lastFinalizedTransitionHash: bytes32(0),
                bondInstructionsHash: bytes32(0)
            }),
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        bytes memory encoded1 = LibProposedEventEncoder.encode(payload);
        bytes memory encoded2 = LibProposedEventEncoder.encode(payload);

        assertEq(keccak256(encoded1), keccak256(encoded2), "Encoding should be deterministic");
    }

    function test_encode_decode_lastCheckpointTimestamp() public pure {
        // Test that lastCheckpointTimestamp is properly encoded and decoded
        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 42,
                timestamp: 2000,
                endOfSubmissionWindowTimestamp: 3000,
                proposer: address(0xABCD),
                coreStateHash: bytes32(uint256(4444)),
                derivationHash: bytes32(uint256(5555))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 500,
                originBlockHash: bytes32(uint256(500)),
                basefeeSharingPctg: 75,
                sources: new IInbox.DerivationSource[](0)
            }),
            coreState: IInbox.CoreState({
                nextProposalId: 43,
                lastProposalBlockId: 2000,
                lastFinalizedProposalId: 41,
                lastCheckpointTimestamp: 1_700_000_000, // Non-zero timestamp
                lastFinalizedTransitionHash: bytes32(uint256(6666)),
                bondInstructionsHash: bytes32(uint256(7777))
            }),
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify all core state fields including lastCheckpointTimestamp
        assertEq(
            decoded.coreState.nextProposalId,
            payload.coreState.nextProposalId,
            "Next proposal ID mismatch"
        );
        assertEq(
            decoded.coreState.lastProposalBlockId,
            payload.coreState.lastProposalBlockId,
            "Last proposal block ID mismatch"
        );
        assertEq(
            decoded.coreState.lastFinalizedProposalId,
            payload.coreState.lastFinalizedProposalId,
            "Last finalized proposal ID mismatch"
        );
        assertEq(
            decoded.coreState.lastCheckpointTimestamp,
            payload.coreState.lastCheckpointTimestamp,
            "Last checkpoint timestamp mismatch"
        );
        assertEq(
            decoded.coreState.lastFinalizedTransitionHash,
            payload.coreState.lastFinalizedTransitionHash,
            "Last finalized transition hash mismatch"
        );
        assertEq(
            decoded.coreState.bondInstructionsHash,
            payload.coreState.bondInstructionsHash,
            "Bond instructions hash mismatch"
        );
    }

    function test_encode_decode_lastCheckpointTimestamp_maxValue() public pure {
        // Test with maximum uint48 value for lastCheckpointTimestamp
        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 1,
                timestamp: 1000,
                endOfSubmissionWindowTimestamp: 2000,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(1111)),
                derivationHash: bytes32(uint256(2222))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 100,
                originBlockHash: bytes32(uint256(100)),
                basefeeSharingPctg: 50,
                sources: new IInbox.DerivationSource[](0)
            }),
            coreState: IInbox.CoreState({
                nextProposalId: 2,
                lastProposalBlockId: 1000,
                lastFinalizedProposalId: 0,
                lastCheckpointTimestamp: type(uint48).max, // Maximum value
                lastFinalizedTransitionHash: bytes32(uint256(3333)),
                bondInstructionsHash: bytes32(uint256(4444))
            }),
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        assertEq(
            decoded.coreState.lastCheckpointTimestamp,
            type(uint48).max,
            "Max lastCheckpointTimestamp should be preserved"
        );
    }
}
