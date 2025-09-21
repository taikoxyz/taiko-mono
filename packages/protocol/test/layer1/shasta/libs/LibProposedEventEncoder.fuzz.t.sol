// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProposedEventEncoder } from "src/layer1/shasta/libs/LibProposedEventEncoder.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";

/// @title LibProposedEventEncoderFuzzTest
/// @notice Comprehensive fuzz tests for LibProposedEventEncoder
/// @custom:security-contact security@taiko.xyz
contract LibProposedEventEncoderFuzzTest is Test {
    uint256 constant MAX_BLOB_HASHES = 10; // Reasonable limit for testing

    function testFuzz_encodeDecodeBasicFields(
        uint48 _id,
        address _proposer,
        uint48 _timestamp,
        uint48 _endOfSubmissionWindowTimestamp,
        uint48 _originBlockNumber,
        bytes32 _originBlockHash,
        bool _isForcedInclusion,
        uint8 _basefeeSharingPctg,
        bytes32 _coreStateHash,
        bytes32 _derivationHash
    )
        public
        pure
    {
        IInbox.ProposedEventPayload memory payload;

        payload.proposal.id = _id;
        payload.proposal.proposer = _proposer;
        payload.proposal.timestamp = _timestamp;
        payload.proposal.endOfSubmissionWindowTimestamp = _endOfSubmissionWindowTimestamp;
        payload.proposal.coreStateHash = _coreStateHash;
        payload.proposal.derivationHash = _derivationHash;

        payload.derivation.originBlockNumber = _originBlockNumber;
        payload.derivation.originBlockHash = _originBlockHash;
        payload.derivation.basefeeSharingPctg = _basefeeSharingPctg;
        // Create single source for this test
        payload.derivation.sources = new IInbox.DerivationSource[](1);
        payload.derivation.sources[0] = IInbox.DerivationSource({
            isForcedInclusion: _isForcedInclusion,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: new bytes32[](0),
                offset: 0,
                timestamp: 0
            })
        });

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify Proposal fields
        assertEq(decoded.proposal.id, payload.proposal.id);
        assertEq(decoded.proposal.proposer, payload.proposal.proposer);
        assertEq(decoded.proposal.timestamp, payload.proposal.timestamp);
        assertEq(
            decoded.proposal.endOfSubmissionWindowTimestamp,
            payload.proposal.endOfSubmissionWindowTimestamp
        );
        assertEq(decoded.proposal.coreStateHash, payload.proposal.coreStateHash);
        assertEq(decoded.proposal.derivationHash, payload.proposal.derivationHash);

        // Verify Derivation fields
        assertEq(decoded.derivation.originBlockNumber, payload.derivation.originBlockNumber);
        assertEq(decoded.derivation.originBlockHash, payload.derivation.originBlockHash);
        assertEq(decoded.derivation.sources[0].isForcedInclusion, payload.derivation.sources[0].isForcedInclusion);
        assertEq(decoded.derivation.basefeeSharingPctg, payload.derivation.basefeeSharingPctg);

        // Verify sources array
        assertEq(decoded.derivation.sources.length, payload.derivation.sources.length);
        assertEq(
            decoded.derivation.sources[0].blobSlice.blobHashes.length,
            payload.derivation.sources[0].blobSlice.blobHashes.length
        );
    }

    function testFuzz_encodeDecodeCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedTransitionHash,
        bytes32 _bondInstructionsHash
    )
        public
        pure
    {
        IInbox.ProposedEventPayload memory payload;
        // Initialize with empty sources array
        payload.derivation.sources = new IInbox.DerivationSource[](0);

        payload.coreState.nextProposalId = _nextProposalId;
        payload.coreState.lastFinalizedProposalId = _lastFinalizedProposalId;
        payload.coreState.lastFinalizedTransitionHash = _lastFinalizedTransitionHash;
        payload.coreState.bondInstructionsHash = _bondInstructionsHash;

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        assertEq(decoded.coreState.nextProposalId, payload.coreState.nextProposalId);
        assertEq(
            decoded.coreState.lastFinalizedProposalId, payload.coreState.lastFinalizedProposalId
        );
        assertEq(
            decoded.coreState.lastFinalizedTransitionHash,
            payload.coreState.lastFinalizedTransitionHash
        );
        assertEq(decoded.coreState.bondInstructionsHash, payload.coreState.bondInstructionsHash);
    }

    function testFuzz_encodeDecodeBlobSlice(
        uint24 _offset,
        uint48 _timestamp,
        uint8 _blobHashCount
    )
        public
        pure
    {
        vm.assume(_blobHashCount <= MAX_BLOB_HASHES);

        IInbox.ProposedEventPayload memory payload;
        
        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }
        
        // Create single source with the blob slice
        payload.derivation.sources = new IInbox.DerivationSource[](1);
        payload.derivation.sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: _offset,
                timestamp: _timestamp
            })
        });

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        assertEq(decoded.derivation.sources[0].blobSlice.offset, payload.derivation.sources[0].blobSlice.offset);
        assertEq(decoded.derivation.sources[0].blobSlice.timestamp, payload.derivation.sources[0].blobSlice.timestamp);
        assertEq(decoded.derivation.sources.length, payload.derivation.sources.length);
        assertEq(
            decoded.derivation.sources[0].blobSlice.blobHashes.length,
            payload.derivation.sources[0].blobSlice.blobHashes.length
        );

        for (uint256 i = 0; i < _blobHashCount; i++) {
            assertEq(
                decoded.derivation.sources[0].blobSlice.blobHashes[i],
                payload.derivation.sources[0].blobSlice.blobHashes[i]
            );
        }
    }

    function testFuzz_encodeDecodeComplete(
        uint48 _id,
        address _proposer,
        uint48 _timestamp,
        uint48 _endOfSubmissionWindowTimestamp,
        uint48 _originBlockNumber,
        bytes32 _originBlockHash,
        bool _isForcedInclusion,
        uint8 _basefeeSharingPctg,
        bytes32 _coreStateHash,
        bytes32 _derivationHash,
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedTransitionHash,
        bytes32 _bondInstructionsHash,
        uint8 _blobHashCount
    )
        public
        pure
    {
        vm.assume(_blobHashCount <= MAX_BLOB_HASHES);

        IInbox.ProposedEventPayload memory payload;

        // Set all fields
        payload.proposal.id = _id;
        payload.proposal.proposer = _proposer;
        payload.proposal.timestamp = _timestamp;
        payload.proposal.endOfSubmissionWindowTimestamp = _endOfSubmissionWindowTimestamp;
        payload.proposal.coreStateHash = _coreStateHash;
        payload.proposal.derivationHash = _derivationHash;

        payload.derivation.originBlockNumber = _originBlockNumber;
        payload.derivation.originBlockHash = _originBlockHash;
        payload.derivation.basefeeSharingPctg = _basefeeSharingPctg;
        
        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }
        
        // Create single source with blob data
        payload.derivation.sources = new IInbox.DerivationSource[](1);
        payload.derivation.sources[0] = IInbox.DerivationSource({
            isForcedInclusion: _isForcedInclusion,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: uint24(_blobHashCount % (2 ** 24)),
                timestamp: uint48(_blobHashCount % (2 ** 48))
            })
        });

        payload.coreState.nextProposalId = _nextProposalId;
        payload.coreState.lastFinalizedProposalId = _lastFinalizedProposalId;
        payload.coreState.lastFinalizedTransitionHash = _lastFinalizedTransitionHash;
        payload.coreState.bondInstructionsHash = _bondInstructionsHash;

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify all fields
        assertEq(decoded.proposal.id, payload.proposal.id);
        assertEq(decoded.proposal.proposer, payload.proposal.proposer);
        assertEq(decoded.proposal.timestamp, payload.proposal.timestamp);
        assertEq(
            decoded.proposal.endOfSubmissionWindowTimestamp,
            payload.proposal.endOfSubmissionWindowTimestamp
        );
        assertEq(decoded.proposal.coreStateHash, payload.proposal.coreStateHash);
        assertEq(decoded.proposal.derivationHash, payload.proposal.derivationHash);

        assertEq(decoded.derivation.originBlockNumber, payload.derivation.originBlockNumber);
        assertEq(decoded.derivation.originBlockHash, payload.derivation.originBlockHash);
        assertEq(decoded.derivation.sources[0].isForcedInclusion, payload.derivation.sources[0].isForcedInclusion);
        assertEq(decoded.derivation.basefeeSharingPctg, payload.derivation.basefeeSharingPctg);
        assertEq(decoded.derivation.sources[0].blobSlice.offset, payload.derivation.sources[0].blobSlice.offset);
        assertEq(decoded.derivation.sources[0].blobSlice.timestamp, payload.derivation.sources[0].blobSlice.timestamp);

        assertEq(decoded.coreState.nextProposalId, payload.coreState.nextProposalId);
        assertEq(
            decoded.coreState.lastFinalizedProposalId, payload.coreState.lastFinalizedProposalId
        );
        assertEq(
            decoded.coreState.lastFinalizedTransitionHash,
            payload.coreState.lastFinalizedTransitionHash
        );
        assertEq(decoded.coreState.bondInstructionsHash, payload.coreState.bondInstructionsHash);

        assertEq(decoded.derivation.sources.length, payload.derivation.sources.length);
        assertEq(
            decoded.derivation.sources[0].blobSlice.blobHashes.length,
            payload.derivation.sources[0].blobSlice.blobHashes.length
        );

        for (uint256 i = 0; i < _blobHashCount; i++) {
            assertEq(
                decoded.derivation.sources[0].blobSlice.blobHashes[i],
                payload.derivation.sources[0].blobSlice.blobHashes[i]
            );
        }
    }

    /// @notice Test round-trip encoding/decoding with exact expected values
    function test_encodeDecodeExactValues() public pure {
        IInbox.ProposedEventPayload memory payload;

        // Set exact proposal values
        payload.proposal.id = 12_345;
        payload.proposal.proposer = address(0x1234567890123456789012345678901234567890);
        payload.proposal.timestamp = 1_700_000_000;
        payload.proposal.endOfSubmissionWindowTimestamp = 1_700_000_012;
        payload.proposal.coreStateHash = keccak256("coreState");
        payload.proposal.derivationHash = keccak256("derivation");

        // Set exact derivation values
        payload.derivation.originBlockNumber = 18_000_000;
        payload.derivation.originBlockHash = bytes32(uint256(18_000_000));
        payload.derivation.basefeeSharingPctg = 75;
        
        // Create multiple sources to test multi-source encoding
        bytes32[] memory blobHashes1 = new bytes32[](2);
        blobHashes1[0] = keccak256("blob1");
        blobHashes1[1] = keccak256("blob2");
        
        bytes32[] memory blobHashes2 = new bytes32[](1);
        blobHashes2[0] = keccak256("blob3");
        
        payload.derivation.sources = new IInbox.DerivationSource[](2);
        payload.derivation.sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes1,
                offset: 100,
                timestamp: 1_700_000_100
            })
        });
        payload.derivation.sources[1] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes2,
                offset: 200,
                timestamp: 1_700_000_200
            })
        });

        // Set exact core state values
        payload.coreState.nextProposalId = 12_346;
        payload.coreState.nextProposalBlockId = 1_234_600;
        payload.coreState.lastFinalizedProposalId = 12_340;
        payload.coreState.lastFinalizedTransitionHash = keccak256("lastFinalized");
        payload.coreState.bondInstructionsHash = keccak256("bondInstructions");

        // Encode and decode
        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify exact values
        assertEq(decoded.proposal.id, 12_345);
        assertEq(
            decoded.proposal.proposer, address(0x1234567890123456789012345678901234567890)
        );
        assertEq(decoded.proposal.timestamp, 1_700_000_000);
        assertEq(decoded.proposal.endOfSubmissionWindowTimestamp, 1_700_000_012);
        assertEq(decoded.proposal.coreStateHash, keccak256("coreState"));
        assertEq(decoded.proposal.derivationHash, keccak256("derivation"));

        assertEq(decoded.derivation.originBlockNumber, 18_000_000);
        assertEq(decoded.derivation.originBlockHash, bytes32(uint256(18_000_000)));
        assertEq(decoded.derivation.basefeeSharingPctg, 75);

        // Verify sources
        assertEq(decoded.derivation.sources.length, 2);
        assertEq(decoded.derivation.sources[0].isForcedInclusion, false);
        assertEq(decoded.derivation.sources[1].isForcedInclusion, true);
        
        assertEq(decoded.derivation.sources[0].blobSlice.offset, 100);
        assertEq(decoded.derivation.sources[0].blobSlice.timestamp, 1_700_000_100);
        assertEq(decoded.derivation.sources[0].blobSlice.blobHashes.length, 2);
        assertEq(decoded.derivation.sources[0].blobSlice.blobHashes[0], keccak256("blob1"));
        assertEq(decoded.derivation.sources[0].blobSlice.blobHashes[1], keccak256("blob2"));
        
        assertEq(decoded.derivation.sources[1].blobSlice.offset, 200);
        assertEq(decoded.derivation.sources[1].blobSlice.timestamp, 1_700_000_200);
        assertEq(decoded.derivation.sources[1].blobSlice.blobHashes.length, 1);
        assertEq(decoded.derivation.sources[1].blobSlice.blobHashes[0], keccak256("blob3"));

        assertEq(decoded.coreState.nextProposalId, 12_346);
        assertEq(decoded.coreState.nextProposalBlockId, 1_234_600);
        assertEq(decoded.coreState.lastFinalizedProposalId, 12_340);
        assertEq(decoded.coreState.lastFinalizedTransitionHash, keccak256("lastFinalized"));
        assertEq(decoded.coreState.bondInstructionsHash, keccak256("bondInstructions"));
    }

    /// @notice Test encoding/decoding with maximum values to verify bounds
    function test_encodeDecodeMaxValues() public pure {
        IInbox.ProposedEventPayload memory payload;

        // Set maximum values for all fields
        payload.proposal.id = type(uint48).max;
        payload.proposal.proposer = address(type(uint160).max);
        payload.proposal.timestamp = type(uint48).max;
        payload.proposal.endOfSubmissionWindowTimestamp = type(uint48).max;
        payload.proposal.coreStateHash = bytes32(type(uint256).max);
        payload.proposal.derivationHash = bytes32(type(uint256).max);

        payload.derivation.originBlockNumber = type(uint48).max;
        payload.derivation.originBlockHash = bytes32(type(uint256).max);
        payload.derivation.basefeeSharingPctg = type(uint8).max;
        
        bytes32[] memory blobHashes = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            blobHashes[i] = bytes32(type(uint256).max - i);
        }
        
        payload.derivation.sources = new IInbox.DerivationSource[](1);
        payload.derivation.sources[0] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 1024,
                timestamp: 1_000_001
            })
        });

        payload.coreState.nextProposalId = type(uint48).max;
        payload.coreState.nextProposalBlockId = type(uint48).max;
        payload.coreState.lastFinalizedProposalId = type(uint48).max;
        payload.coreState.lastFinalizedTransitionHash = bytes32(type(uint256).max);
        payload.coreState.bondInstructionsHash = bytes32(type(uint256).max);

        // Encode and decode
        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify all max values are preserved
        assertEq(decoded.proposal.id, type(uint48).max);
        assertEq(decoded.proposal.proposer, address(type(uint160).max));
        assertEq(decoded.proposal.timestamp, type(uint48).max);
        assertEq(decoded.proposal.endOfSubmissionWindowTimestamp, type(uint48).max);
        assertEq(decoded.proposal.coreStateHash, bytes32(type(uint256).max));
        assertEq(decoded.proposal.derivationHash, bytes32(type(uint256).max));

        assertEq(decoded.derivation.originBlockNumber, type(uint48).max);
        assertEq(decoded.derivation.originBlockHash, bytes32(type(uint256).max));
        assertEq(decoded.derivation.basefeeSharingPctg, type(uint8).max);

        assertEq(decoded.coreState.nextProposalId, type(uint48).max);
        assertEq(decoded.coreState.nextProposalBlockId, type(uint48).max);
        assertEq(decoded.coreState.lastFinalizedProposalId, type(uint48).max);
        assertEq(decoded.coreState.lastFinalizedTransitionHash, bytes32(type(uint256).max));
        assertEq(decoded.coreState.bondInstructionsHash, bytes32(type(uint256).max));
    }
}