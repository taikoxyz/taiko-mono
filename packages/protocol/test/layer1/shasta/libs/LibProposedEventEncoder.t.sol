// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProposedEventEncoder } from "src/layer1/shasta/libs/LibProposedEventEncoder.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

/// @title LibProposedEventEncoderTest
/// @notice Tests for LibProposedEventEncoder
/// @custom:security-contact security@taiko.xyz
contract LibProposedEventEncoderTest is Test {
    function test_encodeDecodeProposedEvent_minimal() public pure {
        // Create minimal proposed event
        IInbox.Proposal memory originalProposal;
        originalProposal.id = 1;
        originalProposal.proposer = address(0x1234567890123456789012345678901234567890);
        originalProposal.timestamp = 1000;
        originalProposal.coreStateHash = keccak256("coreState");
        originalProposal.derivationHash = keccak256("derivation");

        IInbox.Derivation memory originalDerivation;
        originalDerivation.originBlockNumber = 2000;
        originalDerivation.originBlockHash = bytes32(uint256(2000));
        originalDerivation.isForcedInclusion = false;
        originalDerivation.basefeeSharingPctg = 50;
        originalDerivation.blobSlice.blobHashes = new bytes32[](0);
        originalDerivation.blobSlice.offset = 100;
        originalDerivation.blobSlice.timestamp = 3000;

        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId = 2;
        originalCoreState.lastFinalizedProposalId = 0;
        originalCoreState.lastFinalizedClaimHash = keccak256("lastClaim");
        originalCoreState.bondInstructionsHash = keccak256("bondInstructions");

        // Encode
        bytes memory encoded =
            LibProposedEventEncoder.encode(originalProposal, originalDerivation, originalCoreState);

        // Verify size calculation is correct
        uint256 expectedSize = LibProposedEventEncoder.calculateProposedEventSize(0);
        assertEq(encoded.length, expectedSize);

        // Decode
        (
            IInbox.Proposal memory decodedProposal,
            IInbox.Derivation memory decodedDerivation,
            IInbox.CoreState memory decodedCoreState
        ) = LibProposedEventEncoder.decode(encoded);

        // Verify proposal fields
        assertEq(decodedProposal.id, originalProposal.id);
        assertEq(decodedProposal.proposer, originalProposal.proposer);
        assertEq(decodedProposal.timestamp, originalProposal.timestamp);
        assertEq(decodedProposal.coreStateHash, originalProposal.coreStateHash);
        // Note: derivationHash is not preserved by the encoder

        // Verify derivation fields
        assertEq(decodedDerivation.originBlockNumber, originalDerivation.originBlockNumber);
        // originBlockHash is not preserved by encoder
        assertEq(decodedDerivation.isForcedInclusion, originalDerivation.isForcedInclusion);
        assertEq(decodedDerivation.basefeeSharingPctg, originalDerivation.basefeeSharingPctg);
        assertEq(decodedDerivation.blobSlice.blobHashes.length, 0);
        assertEq(decodedDerivation.blobSlice.offset, originalDerivation.blobSlice.offset);
        assertEq(decodedDerivation.blobSlice.timestamp, originalDerivation.blobSlice.timestamp);

        // Verify core state fields
        assertEq(decodedCoreState.nextProposalId, originalCoreState.nextProposalId);
        assertEq(
            decodedCoreState.lastFinalizedProposalId, originalCoreState.lastFinalizedProposalId
        );
        assertEq(decodedCoreState.lastFinalizedClaimHash, originalCoreState.lastFinalizedClaimHash);
        assertEq(decodedCoreState.bondInstructionsHash, originalCoreState.bondInstructionsHash);
    }

    function test_encodeDecodeProposedEvent_withBlobHashes() public pure {
        // Create proposed event with blob hashes
        IInbox.Proposal memory originalProposal;
        originalProposal.id = 12_345;
        originalProposal.proposer = address(0xabCDEF1234567890ABcDEF1234567890aBCDeF12);
        originalProposal.timestamp = 999_999;
        originalProposal.coreStateHash = keccak256("coreStateHash");
        originalProposal.derivationHash = keccak256("derivationHash");

        IInbox.Derivation memory originalDerivation;
        originalDerivation.originBlockNumber = 888_888;
        originalDerivation.originBlockHash = bytes32(uint256(888_888));
        originalDerivation.isForcedInclusion = true;
        originalDerivation.basefeeSharingPctg = 75;

        // Add 3 blob hashes
        originalDerivation.blobSlice.blobHashes = new bytes32[](3);
        originalDerivation.blobSlice.blobHashes[0] = keccak256("blob1");
        originalDerivation.blobSlice.blobHashes[1] = keccak256("blob2");
        originalDerivation.blobSlice.blobHashes[2] = keccak256("blob3");
        originalDerivation.blobSlice.offset = 65_535; // Max uint24 - 1
        originalDerivation.blobSlice.timestamp = 777_777;

        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId = 54_321;
        originalCoreState.lastFinalizedProposalId = 54_320;
        originalCoreState.lastFinalizedClaimHash = keccak256("finalizedClaim");
        originalCoreState.bondInstructionsHash = keccak256("bondInstructionsHash");

        // Encode
        bytes memory encoded =
            LibProposedEventEncoder.encode(originalProposal, originalDerivation, originalCoreState);

        // Verify size calculation is correct
        uint256 expectedSize = LibProposedEventEncoder.calculateProposedEventSize(3);
        assertEq(encoded.length, expectedSize);

        // Decode
        (
            IInbox.Proposal memory decodedProposal,
            IInbox.Derivation memory decodedDerivation,
            IInbox.CoreState memory decodedCoreState
        ) = LibProposedEventEncoder.decode(encoded);

        // Verify proposal fields
        assertEq(decodedProposal.id, originalProposal.id);
        assertEq(decodedProposal.proposer, originalProposal.proposer);
        assertEq(decodedProposal.timestamp, originalProposal.timestamp);
        assertEq(decodedProposal.coreStateHash, originalProposal.coreStateHash);
        // Note: derivationHash is not preserved by the encoder

        // Verify derivation fields
        assertEq(decodedDerivation.originBlockNumber, originalDerivation.originBlockNumber);
        // originBlockHash is not preserved by encoder
        assertEq(decodedDerivation.isForcedInclusion, originalDerivation.isForcedInclusion);
        assertEq(decodedDerivation.basefeeSharingPctg, originalDerivation.basefeeSharingPctg);
        assertEq(decodedDerivation.blobSlice.blobHashes.length, 3);
        assertEq(
            decodedDerivation.blobSlice.blobHashes[0], originalDerivation.blobSlice.blobHashes[0]
        );
        assertEq(
            decodedDerivation.blobSlice.blobHashes[1], originalDerivation.blobSlice.blobHashes[1]
        );
        assertEq(
            decodedDerivation.blobSlice.blobHashes[2], originalDerivation.blobSlice.blobHashes[2]
        );
        assertEq(decodedDerivation.blobSlice.offset, originalDerivation.blobSlice.offset);
        assertEq(decodedDerivation.blobSlice.timestamp, originalDerivation.blobSlice.timestamp);

        // Verify core state fields
        assertEq(decodedCoreState.nextProposalId, originalCoreState.nextProposalId);
        assertEq(
            decodedCoreState.lastFinalizedProposalId, originalCoreState.lastFinalizedProposalId
        );
        assertEq(decodedCoreState.lastFinalizedClaimHash, originalCoreState.lastFinalizedClaimHash);
        assertEq(decodedCoreState.bondInstructionsHash, originalCoreState.bondInstructionsHash);
    }

    function test_encodeDecodeProposedEvent_maxValues() public pure {
        // Test with maximum values for all uint types
        IInbox.Proposal memory originalProposal;
        originalProposal.id = type(uint48).max;
        originalProposal.proposer = address(type(uint160).max);
        originalProposal.timestamp = type(uint48).max;
        originalProposal.coreStateHash = bytes32(type(uint256).max);
        originalProposal.derivationHash = bytes32(type(uint256).max);

        IInbox.Derivation memory originalDerivation;
        originalDerivation.originBlockNumber = type(uint48).max;
        originalDerivation.originBlockHash = bytes32(type(uint256).max);
        originalDerivation.isForcedInclusion = true;
        originalDerivation.basefeeSharingPctg = type(uint8).max;
        originalDerivation.blobSlice.blobHashes = new bytes32[](0);
        originalDerivation.blobSlice.offset = type(uint24).max;
        originalDerivation.blobSlice.timestamp = type(uint48).max;

        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId = type(uint48).max;
        originalCoreState.lastFinalizedProposalId = type(uint48).max;
        originalCoreState.lastFinalizedClaimHash = bytes32(type(uint256).max);
        originalCoreState.bondInstructionsHash = bytes32(type(uint256).max);

        // Encode
        bytes memory encoded =
            LibProposedEventEncoder.encode(originalProposal, originalDerivation, originalCoreState);

        // Decode
        (
            IInbox.Proposal memory decodedProposal,
            IInbox.Derivation memory decodedDerivation,
            IInbox.CoreState memory decodedCoreState
        ) = LibProposedEventEncoder.decode(encoded);

        // Verify all max values are preserved
        assertEq(decodedProposal.id, type(uint48).max);
        assertEq(decodedProposal.proposer, address(type(uint160).max));
        assertEq(decodedProposal.timestamp, type(uint48).max);
        assertEq(decodedProposal.coreStateHash, bytes32(type(uint256).max));
        // derivationHash is not preserved
        assertEq(decodedDerivation.originBlockNumber, type(uint48).max);
        // originBlockHash is not preserved by encoder
        assertEq(decodedDerivation.isForcedInclusion, true);
        assertEq(decodedDerivation.basefeeSharingPctg, type(uint8).max);
        assertEq(decodedDerivation.blobSlice.offset, type(uint24).max);
        assertEq(decodedDerivation.blobSlice.timestamp, type(uint48).max);
        assertEq(decodedCoreState.nextProposalId, type(uint48).max);
        assertEq(decodedCoreState.lastFinalizedProposalId, type(uint48).max);
        assertEq(decodedCoreState.lastFinalizedClaimHash, bytes32(type(uint256).max));
        assertEq(decodedCoreState.bondInstructionsHash, bytes32(type(uint256).max));
    }

    function test_calculateProposedEventSize() public pure {
        // Test size calculation for different blob hash counts
        uint256 sizeWith0Hashes = LibProposedEventEncoder.calculateProposedEventSize(0);
        uint256 sizeWith1Hash = LibProposedEventEncoder.calculateProposedEventSize(1);
        uint256 sizeWith10Hashes = LibProposedEventEncoder.calculateProposedEventSize(10);

        // Each blob hash is 32 bytes
        assertEq(sizeWith1Hash - sizeWith0Hashes, 32);
        assertEq(sizeWith10Hashes - sizeWith0Hashes, 320);

        // Verify actual encoding matches calculated size
        for (uint256 i = 0; i <= 5; i++) {
            IInbox.Proposal memory proposal;
            IInbox.Derivation memory derivation;
            derivation.blobSlice.blobHashes = new bytes32[](i);
            for (uint256 j = 0; j < i; j++) {
                derivation.blobSlice.blobHashes[j] = keccak256(abi.encode(j));
            }
            IInbox.CoreState memory coreState;

            bytes memory encoded = LibProposedEventEncoder.encode(proposal, derivation, coreState);
            uint256 expectedSize = LibProposedEventEncoder.calculateProposedEventSize(i);

            assertEq(encoded.length, expectedSize);
        }
    }

    function test_encodeDecodeProposedEvent_largeBlobArray() public pure {
        // Test with a large blob array (50 blobs)
        uint256 blobCount = 50;

        IInbox.Proposal memory originalProposal;
        originalProposal.id = 999;
        originalProposal.proposer = address(0x123);
        originalProposal.timestamp = 12_345;
        originalProposal.coreStateHash = keccak256("core");
        originalProposal.derivationHash = keccak256("deriv");

        IInbox.Derivation memory originalDerivation;
        originalDerivation.originBlockNumber = 5000;
        originalDerivation.originBlockHash = bytes32(uint256(5000));
        originalDerivation.isForcedInclusion = false;
        originalDerivation.basefeeSharingPctg = 10;
        originalDerivation.blobSlice.blobHashes = new bytes32[](blobCount);
        for (uint256 i = 0; i < blobCount; i++) {
            originalDerivation.blobSlice.blobHashes[i] = keccak256(abi.encode("blob", i));
        }
        originalDerivation.blobSlice.offset = 2048;
        originalDerivation.blobSlice.timestamp = 67_890;

        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId = 1000;
        originalCoreState.lastFinalizedProposalId = 998;
        originalCoreState.lastFinalizedClaimHash = keccak256("lastFinalized");
        originalCoreState.bondInstructionsHash = keccak256("bonds");

        // Encode
        bytes memory encoded =
            LibProposedEventEncoder.encode(originalProposal, originalDerivation, originalCoreState);

        // Verify size
        uint256 expectedSize = LibProposedEventEncoder.calculateProposedEventSize(blobCount);
        assertEq(encoded.length, expectedSize);

        // Decode
        (, IInbox.Derivation memory decodedDerivation,) = LibProposedEventEncoder.decode(encoded);

        // Verify all blob hashes
        assertEq(decodedDerivation.blobSlice.blobHashes.length, blobCount);
        for (uint256 i = 0; i < blobCount; i++) {
            assertEq(
                decodedDerivation.blobSlice.blobHashes[i],
                originalDerivation.blobSlice.blobHashes[i]
            );
        }
    }

    function test_encodeDecodeProposedEvent_zeroAddress() public pure {
        // Test with zero address proposer
        IInbox.Proposal memory originalProposal;
        originalProposal.proposer = address(0);

        IInbox.Derivation memory originalDerivation;
        originalDerivation.blobSlice.blobHashes = new bytes32[](0);

        IInbox.CoreState memory originalCoreState;

        // Encode and decode
        bytes memory encoded =
            LibProposedEventEncoder.encode(originalProposal, originalDerivation, originalCoreState);
        (IInbox.Proposal memory decodedProposal,,) = LibProposedEventEncoder.decode(encoded);

        // Verify zero address is preserved
        assertEq(decodedProposal.proposer, address(0));
    }

    function test_encodeDecodeProposedEvent_differentFieldCombinations() public pure {
        // Test various field combinations

        // Case 1: Zero proposal ID with max core state
        IInbox.Proposal memory proposal1;
        proposal1.id = 0;

        IInbox.Derivation memory derivation1;
        derivation1.blobSlice.blobHashes = new bytes32[](0);

        IInbox.CoreState memory coreState1;
        coreState1.nextProposalId = type(uint48).max;
        coreState1.lastFinalizedProposalId = type(uint48).max;

        bytes memory encoded1 = LibProposedEventEncoder.encode(proposal1, derivation1, coreState1);
        (IInbox.Proposal memory decoded1,, IInbox.CoreState memory decodedCS1) =
            LibProposedEventEncoder.decode(encoded1);

        assertEq(decoded1.id, 0);
        assertEq(decodedCS1.nextProposalId, type(uint48).max);
        assertEq(decodedCS1.lastFinalizedProposalId, type(uint48).max);

        // Case 2: Max proposal ID with zero core state
        IInbox.Proposal memory proposal2;
        proposal2.id = type(uint48).max;

        IInbox.Derivation memory derivation2;
        derivation2.blobSlice.blobHashes = new bytes32[](0);

        IInbox.CoreState memory coreState2;

        bytes memory encoded2 = LibProposedEventEncoder.encode(proposal2, derivation2, coreState2);
        (IInbox.Proposal memory decoded2,, IInbox.CoreState memory decodedCS2) =
            LibProposedEventEncoder.decode(encoded2);

        assertEq(decoded2.id, type(uint48).max);
        assertEq(decodedCS2.nextProposalId, 0);
        assertEq(decodedCS2.lastFinalizedProposalId, 0);
    }
}
