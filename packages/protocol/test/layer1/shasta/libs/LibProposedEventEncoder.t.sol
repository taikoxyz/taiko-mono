// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProposedEventEncoder } from "src/layer1/shasta/libs/LibProposedEventEncoder.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

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
            nextProposalBlockId: 1001,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: bytes32(uint256(555)),
            bondInstructionsHash: bytes32(uint256(666)),
            parentHash: bytes32(uint256(0x5555))
        });

        // Create proposed event payload
        IInbox.ProposedEventPayload memory original = IInbox.ProposedEventPayload({
            proposal: proposal,
            derivation: derivation,
            coreState: coreState
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
            decoded.coreState.nextProposalBlockId,
            original.coreState.nextProposalBlockId,
            "Next proposal block ID mismatch"
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
                nextProposalBlockId: 5001,
                lastFinalizedProposalId: 9,
                lastFinalizedTransitionHash: bytes32(uint256(999)),
                bondInstructionsHash: bytes32(0),
                parentHash: bytes32(uint256(0x5555))
            })
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
                nextProposalBlockId: 2501,
                lastFinalizedProposalId: 4,
                lastFinalizedTransitionHash: bytes32(uint256(1515)),
                bondInstructionsHash: bytes32(uint256(1616)),
                parentHash: bytes32(uint256(0x5555))
            })
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
                nextProposalBlockId: 1001,
                lastFinalizedProposalId: 0,
                lastFinalizedTransitionHash: bytes32(0),
                bondInstructionsHash: bytes32(0),
                parentHash: bytes32(uint256(0x5555))
            })
        });

        bytes memory encoded1 = LibProposedEventEncoder.encode(payload);
        bytes memory encoded2 = LibProposedEventEncoder.encode(payload);

        assertEq(keccak256(encoded1), keccak256(encoded2), "Encoding should be deterministic");
    }
}
