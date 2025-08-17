// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProposedEventCodec } from "contracts/layer1/shasta/libs/LibProposedEventCodec.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "contracts/layer1/shasta/libs/LibBlobs.sol";

/// @title LibProposedEventCodecTest
/// @notice Comprehensive tests for LibProposedEventCodec encoding/decoding
/// @custom:security-contact security@taiko.xyz
contract LibProposedEventCodecTest is Test {
    function test_encodeDecodeProposedEvent_minimal() public pure {
        // Create minimal proposed event (no blob hashes)
        IInbox.Proposal memory originalProposal;
        originalProposal.id = 1;
        originalProposal.proposer = address(0x1234567890123456789012345678901234567890);
        originalProposal.originTimestamp = 1000;
        originalProposal.originBlockNumber = 2000;
        originalProposal.isForcedInclusion = false;
        originalProposal.basefeeSharingPctg = 50;
        originalProposal.blobSlice.blobHashes = new bytes32[](0);
        originalProposal.blobSlice.offset = 100;
        originalProposal.blobSlice.timestamp = 3000;
        originalProposal.coreStateHash = keccak256("coreState");

        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId = 2;
        originalCoreState.lastFinalizedProposalId = 0;
        originalCoreState.lastFinalizedClaimHash = keccak256("lastClaim");
        originalCoreState.bondInstructionsHash = keccak256("bondInstructions");

        // Encode
        bytes memory encoded = LibProposedEventCodec.encode(originalProposal, originalCoreState);

        // Verify size (128 bytes for minimal config)
        // Proposal: 6+20+6+6+1+1 = 40
        // BlobSlice: 3+0+3+6 = 12
        // coreStateHash: 32
        // CoreState: 6+6+32+32 = 76
        // Total: 40+12+32+76 = 160
        assertEq(encoded.length, 160);

        // Decode
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibProposedEventCodec.decode(encoded);

        // Verify proposal fields
        assertEq(decodedProposal.id, originalProposal.id);
        assertEq(decodedProposal.proposer, originalProposal.proposer);
        assertEq(decodedProposal.originTimestamp, originalProposal.originTimestamp);
        assertEq(decodedProposal.originBlockNumber, originalProposal.originBlockNumber);
        assertEq(decodedProposal.isForcedInclusion, originalProposal.isForcedInclusion);
        assertEq(decodedProposal.basefeeSharingPctg, originalProposal.basefeeSharingPctg);
        assertEq(decodedProposal.blobSlice.blobHashes.length, 0);
        assertEq(decodedProposal.blobSlice.offset, originalProposal.blobSlice.offset);
        assertEq(decodedProposal.blobSlice.timestamp, originalProposal.blobSlice.timestamp);
        assertEq(decodedProposal.coreStateHash, originalProposal.coreStateHash);

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
        originalProposal.originTimestamp = 999_999;
        originalProposal.originBlockNumber = 888_888;
        originalProposal.isForcedInclusion = true;
        originalProposal.basefeeSharingPctg = 75;

        // Add 3 blob hashes
        originalProposal.blobSlice.blobHashes = new bytes32[](3);
        originalProposal.blobSlice.blobHashes[0] = keccak256("blob1");
        originalProposal.blobSlice.blobHashes[1] = keccak256("blob2");
        originalProposal.blobSlice.blobHashes[2] = keccak256("blob3");
        originalProposal.blobSlice.offset = 65_535; // Max uint24 - 1
        originalProposal.blobSlice.timestamp = 777_777;
        originalProposal.coreStateHash = keccak256("coreStateHash");

        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId = 54_321;
        originalCoreState.lastFinalizedProposalId = 54_320;
        originalCoreState.lastFinalizedClaimHash = keccak256("finalizedClaim");
        originalCoreState.bondInstructionsHash = keccak256("bondInstructionsHash");

        // Encode
        bytes memory encoded = LibProposedEventCodec.encode(originalProposal, originalCoreState);

        // Verify size (160 + 3*32 = 256 bytes)
        assertEq(encoded.length, 256);

        // Decode
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibProposedEventCodec.decode(encoded);

        // Verify proposal fields
        assertEq(decodedProposal.id, originalProposal.id);
        assertEq(decodedProposal.proposer, originalProposal.proposer);
        assertEq(decodedProposal.originTimestamp, originalProposal.originTimestamp);
        assertEq(decodedProposal.originBlockNumber, originalProposal.originBlockNumber);
        assertEq(decodedProposal.isForcedInclusion, originalProposal.isForcedInclusion);
        assertEq(decodedProposal.basefeeSharingPctg, originalProposal.basefeeSharingPctg);
        assertEq(decodedProposal.blobSlice.blobHashes.length, 3);
        assertEq(decodedProposal.blobSlice.blobHashes[0], originalProposal.blobSlice.blobHashes[0]);
        assertEq(decodedProposal.blobSlice.blobHashes[1], originalProposal.blobSlice.blobHashes[1]);
        assertEq(decodedProposal.blobSlice.blobHashes[2], originalProposal.blobSlice.blobHashes[2]);
        assertEq(decodedProposal.blobSlice.offset, originalProposal.blobSlice.offset);
        assertEq(decodedProposal.blobSlice.timestamp, originalProposal.blobSlice.timestamp);
        assertEq(decodedProposal.coreStateHash, originalProposal.coreStateHash);

        // Verify core state fields
        assertEq(decodedCoreState.nextProposalId, originalCoreState.nextProposalId);
        assertEq(
            decodedCoreState.lastFinalizedProposalId, originalCoreState.lastFinalizedProposalId
        );
        assertEq(decodedCoreState.lastFinalizedClaimHash, originalCoreState.lastFinalizedClaimHash);
        assertEq(decodedCoreState.bondInstructionsHash, originalCoreState.bondInstructionsHash);
    }

    function test_encodeDecodeProposedEvent_maxValues() public pure {
        // Test with maximum values for each field type
        IInbox.Proposal memory originalProposal;
        originalProposal.id = type(uint48).max;
        originalProposal.proposer = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        originalProposal.originTimestamp = type(uint48).max;
        originalProposal.originBlockNumber = type(uint48).max;
        originalProposal.isForcedInclusion = true;
        originalProposal.basefeeSharingPctg = type(uint8).max;

        // Add one blob hash
        originalProposal.blobSlice.blobHashes = new bytes32[](1);
        originalProposal.blobSlice.blobHashes[0] = bytes32(type(uint256).max);
        originalProposal.blobSlice.offset = type(uint24).max;
        originalProposal.blobSlice.timestamp = type(uint48).max;
        originalProposal.coreStateHash = bytes32(type(uint256).max);

        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId = type(uint48).max;
        originalCoreState.lastFinalizedProposalId = type(uint48).max;
        originalCoreState.lastFinalizedClaimHash = bytes32(type(uint256).max);
        originalCoreState.bondInstructionsHash = bytes32(type(uint256).max);

        // Encode
        bytes memory encoded = LibProposedEventCodec.encode(originalProposal, originalCoreState);

        // Verify size (160 + 1*32 = 192 bytes)
        assertEq(encoded.length, 192);

        // Decode
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibProposedEventCodec.decode(encoded);

        // Verify all max values are preserved
        assertEq(decodedProposal.id, type(uint48).max);
        assertEq(decodedProposal.proposer, address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF));
        assertEq(decodedProposal.originTimestamp, type(uint48).max);
        assertEq(decodedProposal.originBlockNumber, type(uint48).max);
        assertEq(decodedProposal.isForcedInclusion, true);
        assertEq(decodedProposal.basefeeSharingPctg, type(uint8).max);
        assertEq(decodedProposal.blobSlice.blobHashes[0], bytes32(type(uint256).max));
        assertEq(decodedProposal.blobSlice.offset, type(uint24).max);
        assertEq(decodedProposal.blobSlice.timestamp, type(uint48).max);
        assertEq(decodedProposal.coreStateHash, bytes32(type(uint256).max));
        assertEq(decodedCoreState.nextProposalId, type(uint48).max);
        assertEq(decodedCoreState.lastFinalizedProposalId, type(uint48).max);
        assertEq(decodedCoreState.lastFinalizedClaimHash, bytes32(type(uint256).max));
        assertEq(decodedCoreState.bondInstructionsHash, bytes32(type(uint256).max));
    }

    function test_encodeDecodeProposedEvent_zeroValues() public pure {
        // Test with zero/empty values
        IInbox.Proposal memory originalProposal;
        originalProposal.id = 0;
        originalProposal.proposer = address(0);
        originalProposal.originTimestamp = 0;
        originalProposal.originBlockNumber = 0;
        originalProposal.isForcedInclusion = false;
        originalProposal.basefeeSharingPctg = 0;
        originalProposal.blobSlice.blobHashes = new bytes32[](0);
        originalProposal.blobSlice.offset = 0;
        originalProposal.blobSlice.timestamp = 0;
        originalProposal.coreStateHash = bytes32(0);

        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId = 0;
        originalCoreState.lastFinalizedProposalId = 0;
        originalCoreState.lastFinalizedClaimHash = bytes32(0);
        originalCoreState.bondInstructionsHash = bytes32(0);

        // Encode
        bytes memory encoded = LibProposedEventCodec.encode(originalProposal, originalCoreState);

        // Decode
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibProposedEventCodec.decode(encoded);

        // Verify all zero values are preserved
        assertEq(decodedProposal.id, 0);
        assertEq(decodedProposal.proposer, address(0));
        assertEq(decodedProposal.originTimestamp, 0);
        assertEq(decodedProposal.originBlockNumber, 0);
        assertEq(decodedProposal.isForcedInclusion, false);
        assertEq(decodedProposal.basefeeSharingPctg, 0);
        assertEq(decodedProposal.blobSlice.blobHashes.length, 0);
        assertEq(decodedProposal.blobSlice.offset, 0);
        assertEq(decodedProposal.blobSlice.timestamp, 0);
        assertEq(decodedProposal.coreStateHash, bytes32(0));
        assertEq(decodedCoreState.nextProposalId, 0);
        assertEq(decodedCoreState.lastFinalizedProposalId, 0);
        assertEq(decodedCoreState.lastFinalizedClaimHash, bytes32(0));
        assertEq(decodedCoreState.bondInstructionsHash, bytes32(0));
    }

    function testFuzz_encodeDecodeProposedEvent_proposal(
        uint48 _proposalId,
        address _proposer,
        uint48 _originTimestamp,
        uint48 _originBlockNumber,
        bool _isForcedInclusion,
        uint8 _basefeeSharingPctg,
        uint24 _blobOffset,
        uint48 _blobTimestamp,
        bytes32 _coreStateHash
    )
        public
        pure
    {
        // Create proposal with single blob hash
        IInbox.Proposal memory originalProposal;
        originalProposal.id = _proposalId;
        originalProposal.proposer = _proposer;
        originalProposal.originTimestamp = _originTimestamp;
        originalProposal.originBlockNumber = _originBlockNumber;
        originalProposal.isForcedInclusion = _isForcedInclusion;
        originalProposal.basefeeSharingPctg = _basefeeSharingPctg;
        originalProposal.blobSlice.blobHashes = new bytes32[](1);
        originalProposal.blobSlice.blobHashes[0] = keccak256(abi.encode("blob", _proposalId));
        originalProposal.blobSlice.offset = _blobOffset;
        originalProposal.blobSlice.timestamp = _blobTimestamp;
        originalProposal.coreStateHash = _coreStateHash;

        // Create core state with fixed values
        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId =
            _proposalId < type(uint48).max ? _proposalId + 1 : _proposalId;
        originalCoreState.lastFinalizedProposalId = _proposalId > 0 ? _proposalId - 1 : 0;
        originalCoreState.lastFinalizedClaimHash = keccak256(abi.encode("claim", _proposalId));
        originalCoreState.bondInstructionsHash = keccak256(abi.encode("bonds", _proposalId));

        // Encode
        bytes memory encoded = LibProposedEventCodec.encode(originalProposal, originalCoreState);

        // Verify expected size (160 + 32 = 192 bytes for 1 blob hash)
        assertEq(encoded.length, 192);

        // Decode
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibProposedEventCodec.decode(encoded);

        // Verify proposal fields
        assertEq(decodedProposal.id, originalProposal.id);
        assertEq(decodedProposal.proposer, originalProposal.proposer);
        assertEq(decodedProposal.originTimestamp, originalProposal.originTimestamp);
        assertEq(decodedProposal.originBlockNumber, originalProposal.originBlockNumber);
        assertEq(decodedProposal.isForcedInclusion, originalProposal.isForcedInclusion);
        assertEq(decodedProposal.basefeeSharingPctg, originalProposal.basefeeSharingPctg);
        assertEq(decodedProposal.blobSlice.blobHashes.length, 1);
        assertEq(decodedProposal.blobSlice.blobHashes[0], originalProposal.blobSlice.blobHashes[0]);
        assertEq(decodedProposal.blobSlice.offset, originalProposal.blobSlice.offset);
        assertEq(decodedProposal.blobSlice.timestamp, originalProposal.blobSlice.timestamp);
        assertEq(decodedProposal.coreStateHash, originalProposal.coreStateHash);

        // Verify core state fields
        assertEq(decodedCoreState.nextProposalId, originalCoreState.nextProposalId);
        assertEq(
            decodedCoreState.lastFinalizedProposalId, originalCoreState.lastFinalizedProposalId
        );
        assertEq(decodedCoreState.lastFinalizedClaimHash, originalCoreState.lastFinalizedClaimHash);
        assertEq(decodedCoreState.bondInstructionsHash, originalCoreState.bondInstructionsHash);
    }

    function testFuzz_encodeDecodeProposedEvent_coreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedClaimHash,
        bytes32 _bondInstructionsHash
    )
        public
        pure
    {
        // Create proposal with fixed values
        IInbox.Proposal memory originalProposal;
        originalProposal.id = 100;
        originalProposal.proposer = address(0x1234567890123456789012345678901234567890);
        originalProposal.originTimestamp = 1000;
        originalProposal.originBlockNumber = 2000;
        originalProposal.isForcedInclusion = false;
        originalProposal.basefeeSharingPctg = 50;
        originalProposal.blobSlice.blobHashes = new bytes32[](0);
        originalProposal.blobSlice.offset = 100;
        originalProposal.blobSlice.timestamp = 3000;
        originalProposal.coreStateHash = keccak256("coreState");

        // Create core state with fuzzed values
        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId = _nextProposalId;
        originalCoreState.lastFinalizedProposalId = _lastFinalizedProposalId;
        originalCoreState.lastFinalizedClaimHash = _lastFinalizedClaimHash;
        originalCoreState.bondInstructionsHash = _bondInstructionsHash;

        // Encode
        bytes memory encoded = LibProposedEventCodec.encode(originalProposal, originalCoreState);

        // Verify expected size (160 bytes for 0 blob hashes)
        assertEq(encoded.length, 160);

        // Decode
        (, IInbox.CoreState memory decodedCoreState) = LibProposedEventCodec.decode(encoded);

        // Verify core state fields
        assertEq(decodedCoreState.nextProposalId, originalCoreState.nextProposalId);
        assertEq(
            decodedCoreState.lastFinalizedProposalId, originalCoreState.lastFinalizedProposalId
        );
        assertEq(decodedCoreState.lastFinalizedClaimHash, originalCoreState.lastFinalizedClaimHash);
        assertEq(decodedCoreState.bondInstructionsHash, originalCoreState.bondInstructionsHash);
    }

    function test_gasComparison_abiEncode() public {
        // Create test data
        IInbox.Proposal memory proposal;
        proposal.id = 12_345;
        proposal.proposer = address(0x1234567890123456789012345678901234567890);
        proposal.originTimestamp = 999_999;
        proposal.originBlockNumber = 888_888;
        proposal.isForcedInclusion = true;
        proposal.basefeeSharingPctg = 75;
        proposal.blobSlice.blobHashes = new bytes32[](2);
        proposal.blobSlice.blobHashes[0] = keccak256("blob1");
        proposal.blobSlice.blobHashes[1] = keccak256("blob2");
        proposal.blobSlice.offset = 1000;
        proposal.blobSlice.timestamp = 777_777;
        proposal.coreStateHash = keccak256("coreState");

        IInbox.CoreState memory coreState;
        coreState.nextProposalId = 12_346;
        coreState.lastFinalizedProposalId = 12_344;
        coreState.lastFinalizedClaimHash = keccak256("lastClaim");
        coreState.bondInstructionsHash = keccak256("bondInstructions");

        // Measure gas for abi.encode
        uint256 gasBefore = gasleft();
        bytes memory abiEncoded = abi.encode(proposal, coreState);
        uint256 gasAbiEncode = gasBefore - gasleft();

        // Measure gas for LibCodec encode
        gasBefore = gasleft();
        bytes memory libCodecEncoded = LibProposedEventCodec.encode(proposal, coreState);
        uint256 gasLibCodec = gasBefore - gasleft();

        // Log results for comparison
        emit log_named_uint("abi.encode gas", gasAbiEncode);
        emit log_named_uint("LibCodec encode gas", gasLibCodec);
        emit log_named_uint("abi.encode size", abiEncoded.length);
        emit log_named_uint("LibCodec size", libCodecEncoded.length);

        // LibCodec should be more compact
        assertLt(libCodecEncoded.length, abiEncoded.length);
    }
}
