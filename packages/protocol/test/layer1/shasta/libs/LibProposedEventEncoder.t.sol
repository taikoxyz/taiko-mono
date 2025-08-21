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
        IInbox.ProposedEventPayload memory original;

        original.proposal.id = 1;
        original.proposal.proposer = address(0x1234567890123456789012345678901234567890);
        original.proposal.timestamp = 1000;
        original.proposal.coreStateHash = keccak256("coreState");
        original.proposal.derivationHash = keccak256("derivation");

        original.derivation.originBlockNumber = 2000;
        original.derivation.originBlockHash = bytes32(uint256(2000));
        original.derivation.isForcedInclusion = false;
        original.derivation.basefeeSharingPctg = 50;
        original.derivation.blobSlice.blobHashes = new bytes32[](0);
        original.derivation.blobSlice.offset = 100;
        original.derivation.blobSlice.timestamp = 3000;

        original.coreState.nextProposalId = 2;
        original.coreState.lastFinalizedProposalId = 0;
        original.coreState.lastFinalizedTransitionHash = keccak256("lastTransition");
        original.coreState.bondInstructionsHash = keccak256("bondInstructions");

        // Encode
        bytes memory encoded = LibProposedEventEncoder.encode(original);

        // Verify size calculation is correct
        uint256 expectedSize = LibProposedEventEncoder.calculateProposedEventSize(0);
        assertEq(encoded.length, expectedSize);

        // Decode
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify proposal fields
        assertEq(decoded.proposal.id, original.proposal.id);
        assertEq(decoded.proposal.proposer, original.proposal.proposer);
        assertEq(decoded.proposal.timestamp, original.proposal.timestamp);
        assertEq(decoded.proposal.coreStateHash, original.proposal.coreStateHash);
        // Note: derivationHash is not preserved by the encoder

        // Verify derivation fields
        assertEq(decoded.derivation.originBlockNumber, original.derivation.originBlockNumber);
        // originBlockHash is not preserved by encoder
        assertEq(decoded.derivation.isForcedInclusion, original.derivation.isForcedInclusion);
        assertEq(decoded.derivation.basefeeSharingPctg, original.derivation.basefeeSharingPctg);
        assertEq(decoded.derivation.blobSlice.blobHashes.length, 0);
        assertEq(decoded.derivation.blobSlice.offset, original.derivation.blobSlice.offset);
        assertEq(decoded.derivation.blobSlice.timestamp, original.derivation.blobSlice.timestamp);

        // Verify core state fields
        assertEq(decoded.coreState.nextProposalId, original.coreState.nextProposalId);
        assertEq(
            decoded.coreState.lastFinalizedProposalId, original.coreState.lastFinalizedProposalId
        );
        assertEq(
            decoded.coreState.lastFinalizedTransitionHash,
            original.coreState.lastFinalizedTransitionHash
        );
        assertEq(decoded.coreState.bondInstructionsHash, original.coreState.bondInstructionsHash);
    }

    function test_encodeDecodeProposedEvent_withBlobHashes() public pure {
        // Create proposed event with blob hashes
        IInbox.ProposedEventPayload memory original;

        original.proposal.id = 12_345;
        original.proposal.proposer = address(0xabCDEF1234567890ABcDEF1234567890aBCDeF12);
        original.proposal.timestamp = 999_999;
        original.proposal.coreStateHash = keccak256("coreStateHash");
        original.proposal.derivationHash = keccak256("derivationHash");

        original.derivation.originBlockNumber = 888_888;
        original.derivation.originBlockHash = bytes32(uint256(888_888));
        original.derivation.isForcedInclusion = true;
        original.derivation.basefeeSharingPctg = 75;

        // Add 3 blob hashes
        original.derivation.blobSlice.blobHashes = new bytes32[](3);
        original.derivation.blobSlice.blobHashes[0] = keccak256("blob1");
        original.derivation.blobSlice.blobHashes[1] = keccak256("blob2");
        original.derivation.blobSlice.blobHashes[2] = keccak256("blob3");
        original.derivation.blobSlice.offset = 65_535; // Max uint24 - 1
        original.derivation.blobSlice.timestamp = 777_777;

        original.coreState.nextProposalId = 54_321;
        original.coreState.lastFinalizedProposalId = 54_320;
        original.coreState.lastFinalizedTransitionHash = keccak256("finalizedTransition");
        original.coreState.bondInstructionsHash = keccak256("bondInstructionsHash");

        // Encode
        bytes memory encoded = LibProposedEventEncoder.encode(original);

        // Verify size calculation is correct
        uint256 expectedSize = LibProposedEventEncoder.calculateProposedEventSize(3);
        assertEq(encoded.length, expectedSize);

        // Decode
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify proposal fields
        assertEq(decoded.proposal.id, original.proposal.id);
        assertEq(decoded.proposal.proposer, original.proposal.proposer);
        assertEq(decoded.proposal.timestamp, original.proposal.timestamp);
        assertEq(decoded.proposal.coreStateHash, original.proposal.coreStateHash);
        // Note: derivationHash is not preserved by the encoder

        // Verify derivation fields
        assertEq(decoded.derivation.originBlockNumber, original.derivation.originBlockNumber);
        // originBlockHash is not preserved by encoder
        assertEq(decoded.derivation.isForcedInclusion, original.derivation.isForcedInclusion);
        assertEq(decoded.derivation.basefeeSharingPctg, original.derivation.basefeeSharingPctg);
        assertEq(decoded.derivation.blobSlice.blobHashes.length, 3);
        assertEq(
            decoded.derivation.blobSlice.blobHashes[0], original.derivation.blobSlice.blobHashes[0]
        );
        assertEq(
            decoded.derivation.blobSlice.blobHashes[1], original.derivation.blobSlice.blobHashes[1]
        );
        assertEq(
            decoded.derivation.blobSlice.blobHashes[2], original.derivation.blobSlice.blobHashes[2]
        );
        assertEq(decoded.derivation.blobSlice.offset, original.derivation.blobSlice.offset);
        assertEq(decoded.derivation.blobSlice.timestamp, original.derivation.blobSlice.timestamp);

        // Verify core state fields
        assertEq(decoded.coreState.nextProposalId, original.coreState.nextProposalId);
        assertEq(
            decoded.coreState.lastFinalizedProposalId, original.coreState.lastFinalizedProposalId
        );
        assertEq(
            decoded.coreState.lastFinalizedTransitionHash,
            original.coreState.lastFinalizedTransitionHash
        );
        assertEq(decoded.coreState.bondInstructionsHash, original.coreState.bondInstructionsHash);
    }

    function test_encodeDecodeProposedEvent_maxValues() public pure {
        // Test with maximum values for various fields
        IInbox.ProposedEventPayload memory original;

        original.proposal.id = type(uint48).max;
        original.proposal.proposer = address(type(uint160).max);
        original.proposal.timestamp = type(uint48).max;
        original.proposal.coreStateHash = bytes32(type(uint256).max);
        original.proposal.derivationHash = bytes32(type(uint256).max);

        original.derivation.originBlockNumber = type(uint48).max;
        original.derivation.originBlockHash = bytes32(type(uint256).max);
        original.derivation.isForcedInclusion = true;
        original.derivation.basefeeSharingPctg = type(uint8).max;

        // Add blob hashes
        original.derivation.blobSlice.blobHashes = new bytes32[](1);
        original.derivation.blobSlice.blobHashes[0] = bytes32(type(uint256).max);
        original.derivation.blobSlice.offset = type(uint24).max;
        original.derivation.blobSlice.timestamp = type(uint48).max;

        original.coreState.nextProposalId = type(uint48).max;
        original.coreState.lastFinalizedProposalId = type(uint48).max;
        original.coreState.lastFinalizedTransitionHash = bytes32(type(uint256).max);
        original.coreState.bondInstructionsHash = bytes32(type(uint256).max);

        // Encode and decode
        bytes memory encoded = LibProposedEventEncoder.encode(original);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify all max values are preserved
        assertEq(decoded.proposal.id, type(uint48).max);
        assertEq(decoded.proposal.proposer, address(type(uint160).max));
        assertEq(decoded.proposal.timestamp, type(uint48).max);
        assertEq(decoded.proposal.coreStateHash, bytes32(type(uint256).max));
        assertEq(decoded.derivation.originBlockNumber, type(uint48).max);
        assertEq(decoded.derivation.isForcedInclusion, true);
        assertEq(decoded.derivation.basefeeSharingPctg, type(uint8).max);
        assertEq(decoded.derivation.blobSlice.blobHashes[0], bytes32(type(uint256).max));
        assertEq(decoded.derivation.blobSlice.offset, type(uint24).max);
        assertEq(decoded.derivation.blobSlice.timestamp, type(uint48).max);
        assertEq(decoded.coreState.nextProposalId, type(uint48).max);
        assertEq(decoded.coreState.lastFinalizedProposalId, type(uint48).max);
        assertEq(decoded.coreState.lastFinalizedTransitionHash, bytes32(type(uint256).max));
        assertEq(decoded.coreState.bondInstructionsHash, bytes32(type(uint256).max));
    }

    function test_encodeDecodeProposedEvent_zeroValues() public pure {
        // Test with zero/minimum values
        IInbox.ProposedEventPayload memory original;

        original.proposal.id = 0;
        original.proposal.proposer = address(0);
        original.proposal.timestamp = 0;
        original.proposal.coreStateHash = bytes32(0);
        original.proposal.derivationHash = bytes32(0);

        original.derivation.originBlockNumber = 0;
        original.derivation.originBlockHash = bytes32(0);
        original.derivation.isForcedInclusion = false;
        original.derivation.basefeeSharingPctg = 0;
        original.derivation.blobSlice.blobHashes = new bytes32[](0);
        original.derivation.blobSlice.offset = 0;
        original.derivation.blobSlice.timestamp = 0;

        original.coreState.nextProposalId = 0;
        original.coreState.lastFinalizedProposalId = 0;
        original.coreState.lastFinalizedTransitionHash = bytes32(0);
        original.coreState.bondInstructionsHash = bytes32(0);

        // Encode and decode
        bytes memory encoded = LibProposedEventEncoder.encode(original);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify all zero values are preserved
        assertEq(decoded.proposal.id, 0);
        assertEq(decoded.proposal.proposer, address(0));
        assertEq(decoded.proposal.timestamp, 0);
        assertEq(decoded.proposal.coreStateHash, bytes32(0));
        assertEq(decoded.derivation.originBlockNumber, 0);
        assertEq(decoded.derivation.isForcedInclusion, false);
        assertEq(decoded.derivation.basefeeSharingPctg, 0);
        assertEq(decoded.derivation.blobSlice.blobHashes.length, 0);
        assertEq(decoded.derivation.blobSlice.offset, 0);
        assertEq(decoded.derivation.blobSlice.timestamp, 0);
        assertEq(decoded.coreState.nextProposalId, 0);
        assertEq(decoded.coreState.lastFinalizedProposalId, 0);
        assertEq(decoded.coreState.lastFinalizedTransitionHash, bytes32(0));
        assertEq(decoded.coreState.bondInstructionsHash, bytes32(0));
    }

    function test_encodeProposedEvent_gasEfficiency() public {
        // Compare gas usage with ABI encoding
        IInbox.ProposedEventPayload memory payload;

        payload.proposal.id = 123;
        payload.proposal.proposer = address(0x1234);
        payload.proposal.timestamp = 1_000_000;
        payload.proposal.coreStateHash = keccak256("core");
        payload.proposal.derivationHash = keccak256("deriv");

        payload.derivation.originBlockNumber = 5_000_000;
        payload.derivation.originBlockHash = keccak256("origin");
        payload.derivation.isForcedInclusion = false;
        payload.derivation.basefeeSharingPctg = 50;
        payload.derivation.blobSlice.blobHashes = new bytes32[](2);
        payload.derivation.blobSlice.blobHashes[0] = keccak256("blob1");
        payload.derivation.blobSlice.blobHashes[1] = keccak256("blob2");
        payload.derivation.blobSlice.offset = 1024;
        payload.derivation.blobSlice.timestamp = 1_000_001;

        payload.coreState.nextProposalId = 124;
        payload.coreState.lastFinalizedProposalId = 120;
        payload.coreState.lastFinalizedTransitionHash = keccak256("finalized");
        payload.coreState.bondInstructionsHash = keccak256("bonds");

        // Measure encoding gas
        uint256 gasStart = gasleft();
        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        uint256 compactGas = gasStart - gasleft();

        // Measure ABI encoding gas
        gasStart = gasleft();
        bytes memory abiEncoded = abi.encode(payload);
        uint256 abiGas = gasStart - gasleft();

        // Log results
        emit log_named_uint("Compact encoding gas", compactGas);
        emit log_named_uint("ABI encoding gas", abiGas);
        emit log_named_uint("Compact encoded size", encoded.length);
        emit log_named_uint("ABI encoded size", abiEncoded.length);

        // Compact encoding should be more efficient in size
        assertLt(encoded.length, abiEncoded.length);
    }
}
