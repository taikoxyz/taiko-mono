// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/alt/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/alt/libs/LibBlobs.sol";
import { LibProposedEventCodec } from "src/layer1/alt/libs/LibProposedEventCodec.sol";

/// @title LibProposedEventCodecTest
/// @notice Unit tests for LibProposedEventCodec
/// @custom:security-contact security@taiko.xyz
contract LibProposedEventCodecTest is Test {
    function test_encode_decode_simple() public pure {
        // Setup simple test case with minimal data
        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 1,
            timestamp: 1_700_000_000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            proposer: address(0x1234),
            coreStateHash: bytes32(uint256(111)),
            derivationHash: bytes32(uint256(222)),
            parentProposalHash: bytes32(uint256(333))
        });

        // Create empty sources array
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](0);

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: 18_000_000,
            basefeeSharingPctg: 50,
            originBlockHash: bytes32(uint256(444)),
            sources: sources
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            proposalHead: 10,
            proposalHeadContainerBlock: 999,
            finalizationHead: 9,
            synchronizationHead: 8,
            finalizationHeadTransitionHash: bytes27(0),
            aggregatedBondInstructionsHash: bytes32(0)
        });

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: proposal,
            derivation: derivation,
            coreState: coreState,
            transitions: new IInbox.Transition[](0)
        });

        // Test encoding
        bytes memory encoded = LibProposedEventCodec.encode(payload);
        assertGt(encoded.length, 0, "Encoded data should not be empty");

        // Test decoding
        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);

        // Verify proposal fields
        assertEq(decoded.proposal.id, payload.proposal.id, "Proposal ID mismatch");
        assertEq(decoded.proposal.timestamp, payload.proposal.timestamp, "Timestamp mismatch");
        assertEq(
            decoded.proposal.endOfSubmissionWindowTimestamp,
            payload.proposal.endOfSubmissionWindowTimestamp,
            "End of submission window timestamp mismatch"
        );
        assertEq(decoded.proposal.proposer, payload.proposal.proposer, "Proposer mismatch");
        assertEq(
            decoded.proposal.coreStateHash,
            payload.proposal.coreStateHash,
            "Core state hash mismatch"
        );
        assertEq(
            decoded.proposal.derivationHash,
            payload.proposal.derivationHash,
            "Derivation hash mismatch"
        );
        assertEq(
            decoded.proposal.parentProposalHash,
            payload.proposal.parentProposalHash,
            "Parent proposal hash mismatch"
        );

        // Verify derivation fields
        assertEq(
            decoded.derivation.originBlockNumber,
            payload.derivation.originBlockNumber,
            "Origin block number mismatch"
        );
        assertEq(
            decoded.derivation.basefeeSharingPctg,
            payload.derivation.basefeeSharingPctg,
            "Basefee sharing percentage mismatch"
        );
        assertEq(
            decoded.derivation.originBlockHash,
            payload.derivation.originBlockHash,
            "Origin block hash mismatch"
        );
        assertEq(decoded.derivation.sources.length, 0, "Sources should be empty");

        // Verify core state fields
        assertEq(
            decoded.coreState.proposalHead,
            payload.coreState.proposalHead,
            "ProposalHead mismatch"
        );
        assertEq(
            decoded.coreState.proposalHeadContainerBlock,
            payload.coreState.proposalHeadContainerBlock,
            "ProposalHeadContainerBlock mismatch"
        );
        assertEq(
            decoded.coreState.finalizationHead,
            payload.coreState.finalizationHead,
            "FinalizationHead mismatch"
        );
        assertEq(
            decoded.coreState.synchronizationHead,
            payload.coreState.synchronizationHead,
            "SynchronizationHead mismatch"
        );
    }

    function test_encode_decode_with_sources() public pure {
        // Test with derivation sources
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](2);

        // First source - regular submission
        bytes32[] memory blobHashes1 = new bytes32[](2);
        blobHashes1[0] = bytes32(uint256(0x1111));
        blobHashes1[1] = bytes32(uint256(0x2222));

        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes1,
                offset: 100,
                timestamp: 1_700_000_000
            })
        });

        // Second source - forced inclusion
        bytes32[] memory blobHashes2 = new bytes32[](1);
        blobHashes2[0] = bytes32(uint256(0x3333));

        sources[1] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes2, offset: 200, timestamp: 1_700_000_001 })
        });

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 5,
                timestamp: 1_700_000_010,
                endOfSubmissionWindowTimestamp: 1_700_000_022,
                proposer: address(0x5678),
                coreStateHash: bytes32(uint256(555)),
                derivationHash: bytes32(uint256(666)),
                parentProposalHash: bytes32(uint256(777))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 18_000_100,
                basefeeSharingPctg: 75,
                originBlockHash: bytes32(uint256(888)),
                sources: sources
            }),
            coreState: IInbox.CoreState({
                proposalHead: 20,
                proposalHeadContainerBlock: 1999,
                finalizationHead: 18,
                synchronizationHead: 15,
                finalizationHeadTransitionHash: bytes27(uint216(999)),
                aggregatedBondInstructionsHash: bytes32(uint256(1010))
            }),
            transitions: new IInbox.Transition[](0)
        });

        // Test encoding/decoding
        bytes memory encoded = LibProposedEventCodec.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);

        // Verify sources
        assertEq(decoded.derivation.sources.length, 2, "Sources length mismatch");

        // Verify first source
        assertEq(
            decoded.derivation.sources[0].isForcedInclusion, false, "Source 0 isForcedInclusion mismatch"
        );
        assertEq(
            decoded.derivation.sources[0].blobSlice.blobHashes.length,
            2,
            "Source 0 blob hashes length mismatch"
        );
        assertEq(
            decoded.derivation.sources[0].blobSlice.blobHashes[0],
            bytes32(uint256(0x1111)),
            "Source 0 blob hash 0 mismatch"
        );
        assertEq(
            decoded.derivation.sources[0].blobSlice.blobHashes[1],
            bytes32(uint256(0x2222)),
            "Source 0 blob hash 1 mismatch"
        );
        assertEq(decoded.derivation.sources[0].blobSlice.offset, 100, "Source 0 offset mismatch");
        assertEq(
            decoded.derivation.sources[0].blobSlice.timestamp, 1_700_000_000, "Source 0 timestamp mismatch"
        );

        // Verify second source
        assertEq(
            decoded.derivation.sources[1].isForcedInclusion, true, "Source 1 isForcedInclusion mismatch"
        );
        assertEq(
            decoded.derivation.sources[1].blobSlice.blobHashes.length,
            1,
            "Source 1 blob hashes length mismatch"
        );
        assertEq(
            decoded.derivation.sources[1].blobSlice.blobHashes[0],
            bytes32(uint256(0x3333)),
            "Source 1 blob hash 0 mismatch"
        );
        assertEq(decoded.derivation.sources[1].blobSlice.offset, 200, "Source 1 offset mismatch");
        assertEq(
            decoded.derivation.sources[1].blobSlice.timestamp, 1_700_000_001, "Source 1 timestamp mismatch"
        );
    }

    function test_encode_decode_maxValues() public pure {
        // Test with maximum values for bounded types
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = bytes32(type(uint256).max);

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: type(uint24).max,
                timestamp: type(uint40).max
            })
        });

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: type(uint40).max,
                timestamp: type(uint40).max,
                endOfSubmissionWindowTimestamp: type(uint40).max,
                proposer: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
                coreStateHash: bytes32(type(uint256).max),
                derivationHash: bytes32(type(uint256).max),
                parentProposalHash: bytes32(type(uint256).max)
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: type(uint40).max,
                basefeeSharingPctg: 100,
                originBlockHash: bytes32(type(uint256).max),
                sources: sources
            }),
            coreState: IInbox.CoreState({
                proposalHead: type(uint40).max,
                proposalHeadContainerBlock: type(uint40).max,
                finalizationHead: type(uint40).max,
                synchronizationHead: type(uint40).max,
                finalizationHeadTransitionHash: bytes27(type(uint216).max),
                aggregatedBondInstructionsHash: bytes32(type(uint256).max)
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory encoded = LibProposedEventCodec.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventCodec.decode(encoded);

        assertEq(decoded.proposal.id, type(uint40).max, "Max proposal ID should be preserved");
        assertEq(decoded.proposal.timestamp, type(uint40).max, "Max timestamp should be preserved");
        assertEq(
            decoded.derivation.originBlockNumber,
            type(uint40).max,
            "Max origin block number should be preserved"
        );
    }

    function test_calculateProposedEventSize_empty() public pure {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](0);
        uint256 size = LibProposedEventCodec.calculateProposedEventSize(sources);

        // Fixed size is 250 bytes with no sources
        assertEq(size, 250, "Empty sources should have fixed size of 250 bytes");
    }

    function test_calculateProposedEventSize_withSources() public pure {
        bytes32[] memory blobHashes1 = new bytes32[](2);
        bytes32[] memory blobHashes2 = new bytes32[](1);

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](2);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes1, offset: 0, timestamp: 0 })
        });
        sources[1] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes2, offset: 0, timestamp: 0 })
        });

        uint256 size = LibProposedEventCodec.calculateProposedEventSize(sources);

        // Fixed size: 250
        // Source 0: 11 + (2 * 32) = 75 bytes
        // Source 1: 11 + (1 * 32) = 43 bytes
        // Total: 250 + 75 + 43 = 368 bytes
        assertEq(size, 368, "Size calculation mismatch");
    }

    function test_encoding_determinism() public pure {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](0);

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 1,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 18_000_000,
                basefeeSharingPctg: 50,
                originBlockHash: bytes32(uint256(444)),
                sources: sources
            }),
            coreState: IInbox.CoreState({
                proposalHead: 10,
                proposalHeadContainerBlock: 999,
                finalizationHead: 9,
                synchronizationHead: 8,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory encoded1 = LibProposedEventCodec.encode(payload);
        bytes memory encoded2 = LibProposedEventCodec.encode(payload);

        assertEq(keccak256(encoded1), keccak256(encoded2), "Encoding should be deterministic");
    }

    function test_encoding_size_optimization() public pure {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = bytes32(uint256(1));

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes, offset: 100, timestamp: 1_700_000_000 })
        });

        IInbox.ProposedEventPayload memory payload = IInbox.ProposedEventPayload({
            proposal: IInbox.Proposal({
                id: 1,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            derivation: IInbox.Derivation({
                originBlockNumber: 18_000_000,
                basefeeSharingPctg: 50,
                originBlockHash: bytes32(uint256(444)),
                sources: sources
            }),
            coreState: IInbox.CoreState({
                proposalHead: 10,
                proposalHeadContainerBlock: 999,
                finalizationHead: 9,
                synchronizationHead: 8,
                finalizationHeadTransitionHash: bytes27(0),
                aggregatedBondInstructionsHash: bytes32(0)
            }),
            transitions: new IInbox.Transition[](0)
        });

        bytes memory optimized = LibProposedEventCodec.encode(payload);
        bytes memory standard = abi.encode(payload);

        assertLt(
            optimized.length,
            standard.length,
            "Optimized encoding should be smaller than ABI encoding"
        );
    }
}
