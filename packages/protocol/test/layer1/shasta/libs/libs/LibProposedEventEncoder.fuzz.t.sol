// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProposedEventEncoder } from "src/layer1/shasta/libs/LibProposedEventEncoder.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";

/// @title LibProposedEventEncoderFuzzTest
/// @notice Comprehensive fuzz tests for LibProposedEventEncoder
/// @custom:security-contact security@taiko.xyz
contract LibProposedEventEncoderFuzzTest is Test {
    uint256 constant MAX_BLOB_HASHES = 100;
    uint48 constant MAX_UINT48 = type(uint48).max;
    uint24 constant MAX_UINT24 = type(uint24).max;
    uint8 constant MAX_UINT8 = type(uint8).max;

    function testFuzz_encodeDecodeProposal_basicFields(
        uint48 _id,
        address _proposer,
        uint48 _timestamp,
        bytes32 _coreStateHash,
        bytes32 _derivationHash,
        uint48 _originBlockNumber,
        bytes32 _originBlockHash,
        bool _isForcedInclusion,
        uint8 _basefeeSharingPctg
    )
        public
        pure
    {
        IInbox.Proposal memory proposal;
        proposal.id = _id;
        proposal.proposer = _proposer;
        proposal.timestamp = _timestamp;
        proposal.coreStateHash = _coreStateHash;
        proposal.derivationHash = _derivationHash;

        IInbox.Derivation memory derivation;
        derivation.originBlockNumber = _originBlockNumber;
        derivation.originBlockHash = _originBlockHash;
        derivation.isForcedInclusion = _isForcedInclusion;
        derivation.basefeeSharingPctg = _basefeeSharingPctg;
        derivation.blobSlice.blobHashes = new bytes32[](0);

        IInbox.CoreState memory coreState;

        bytes memory encoded = LibProposedEventEncoder.encode(proposal, derivation, coreState);
        (IInbox.Proposal memory decodedProposal, IInbox.Derivation memory decodedDerivation,) =
            LibProposedEventEncoder.decode(encoded);

        // Verify Proposal fields
        assertEq(decodedProposal.id, proposal.id);
        assertEq(decodedProposal.proposer, proposal.proposer);
        assertEq(decodedProposal.timestamp, proposal.timestamp);
        assertEq(decodedProposal.coreStateHash, proposal.coreStateHash);
        // derivationHash is not preserved by encoder

        // Verify Derivation fields
        assertEq(decodedDerivation.originBlockNumber, derivation.originBlockNumber);
        // originBlockHash is not preserved by encoder
        assertEq(decodedDerivation.isForcedInclusion, derivation.isForcedInclusion);
        assertEq(decodedDerivation.basefeeSharingPctg, derivation.basefeeSharingPctg);
    }

    function testFuzz_encodeDecodeCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedClaimHash,
        bytes32 _bondInstructionsHash
    )
        public
        pure
    {
        IInbox.Proposal memory proposal;
        IInbox.Derivation memory derivation;
        derivation.blobSlice.blobHashes = new bytes32[](0);

        IInbox.CoreState memory original;
        original.nextProposalId = _nextProposalId;
        original.lastFinalizedProposalId = _lastFinalizedProposalId;
        original.lastFinalizedClaimHash = _lastFinalizedClaimHash;
        original.bondInstructionsHash = _bondInstructionsHash;

        bytes memory encoded = LibProposedEventEncoder.encode(proposal, derivation, original);
        (,, IInbox.CoreState memory decoded) = LibProposedEventEncoder.decode(encoded);

        assertEq(decoded.nextProposalId, original.nextProposalId);
        assertEq(decoded.lastFinalizedProposalId, original.lastFinalizedProposalId);
        assertEq(decoded.lastFinalizedClaimHash, original.lastFinalizedClaimHash);
        assertEq(decoded.bondInstructionsHash, original.bondInstructionsHash);
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

        IInbox.Proposal memory proposal;
        IInbox.Derivation memory derivation;
        derivation.blobSlice.offset = _offset;
        derivation.blobSlice.timestamp = _timestamp;

        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }
        derivation.blobSlice.blobHashes = blobHashes;

        IInbox.CoreState memory coreState;

        bytes memory encoded = LibProposedEventEncoder.encode(proposal, derivation, coreState);
        (, IInbox.Derivation memory decodedDerivation,) = LibProposedEventEncoder.decode(encoded);

        assertEq(decodedDerivation.blobSlice.offset, derivation.blobSlice.offset);
        assertEq(decodedDerivation.blobSlice.timestamp, derivation.blobSlice.timestamp);
        assertEq(
            decodedDerivation.blobSlice.blobHashes.length, derivation.blobSlice.blobHashes.length
        );

        for (uint256 i = 0; i < _blobHashCount; i++) {
            assertEq(decodedDerivation.blobSlice.blobHashes[i], derivation.blobSlice.blobHashes[i]);
        }
    }

    function testFuzz_encodeDecodeComplete(
        uint48 _id,
        address _proposer,
        uint48 _timestamp,
        uint8 _blobHashCount
    )
        public
        pure
    {
        vm.assume(_blobHashCount <= MAX_BLOB_HASHES);

        // Create Proposal with derived values to avoid stack too deep
        IInbox.Proposal memory proposal;
        proposal.id = _id;
        proposal.proposer = _proposer;
        proposal.timestamp = _timestamp;
        proposal.coreStateHash = keccak256(abi.encode("core", _id));
        proposal.derivationHash = keccak256(abi.encode("deriv", _id));

        // Create Derivation with derived values
        IInbox.Derivation memory derivation;
        derivation.originBlockNumber = _timestamp / 2;
        derivation.originBlockHash = bytes32(uint256(_timestamp));
        derivation.isForcedInclusion = (_id % 2 == 0);
        derivation.basefeeSharingPctg = uint8(_id % 100);

        // Create BlobSlice
        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i, _id));
        }
        derivation.blobSlice = LibBlobs.BlobSlice({
            blobHashes: blobHashes,
            offset: uint24(_timestamp % 1000),
            timestamp: _timestamp < type(uint48).max ? _timestamp + 1 : _timestamp
        });

        // Create CoreState with derived values
        IInbox.CoreState memory coreState;
        coreState.nextProposalId = _id < type(uint48).max ? _id + 1 : _id;
        coreState.lastFinalizedProposalId = _id > 0 ? _id - 1 : 0;
        coreState.lastFinalizedClaimHash = keccak256(abi.encode("finalized", _id));
        coreState.bondInstructionsHash = keccak256(abi.encode("bonds", _id));

        // Encode and decode
        bytes memory encoded = LibProposedEventEncoder.encode(proposal, derivation, coreState);
        (
            IInbox.Proposal memory decodedProposal,
            IInbox.Derivation memory decodedDerivation,
            IInbox.CoreState memory decodedCoreState
        ) = LibProposedEventEncoder.decode(encoded);

        // Verify Proposal
        assertEq(decodedProposal.id, proposal.id);
        assertEq(decodedProposal.proposer, proposal.proposer);
        assertEq(decodedProposal.timestamp, proposal.timestamp);
        assertEq(decodedProposal.coreStateHash, proposal.coreStateHash);
        // derivationHash is not preserved by encoder

        // Verify Derivation
        assertEq(decodedDerivation.originBlockNumber, derivation.originBlockNumber);
        // originBlockHash is not preserved by encoder
        assertEq(decodedDerivation.isForcedInclusion, derivation.isForcedInclusion);
        assertEq(decodedDerivation.basefeeSharingPctg, derivation.basefeeSharingPctg);

        // Verify BlobSlice
        assertEq(decodedDerivation.blobSlice.offset, derivation.blobSlice.offset);
        assertEq(decodedDerivation.blobSlice.timestamp, derivation.blobSlice.timestamp);
        assertEq(
            decodedDerivation.blobSlice.blobHashes.length, derivation.blobSlice.blobHashes.length
        );
        for (uint256 i = 0; i < _blobHashCount; i++) {
            assertEq(decodedDerivation.blobSlice.blobHashes[i], derivation.blobSlice.blobHashes[i]);
        }

        // Verify CoreState
        assertEq(decodedCoreState.nextProposalId, coreState.nextProposalId);
        assertEq(decodedCoreState.lastFinalizedProposalId, coreState.lastFinalizedProposalId);
        assertEq(decodedCoreState.lastFinalizedClaimHash, coreState.lastFinalizedClaimHash);
        assertEq(decodedCoreState.bondInstructionsHash, coreState.bondInstructionsHash);
    }

    function testFuzz_encodeDecodeBoundaryValues() public pure {
        // Test with maximum values
        IInbox.Proposal memory proposal;
        proposal.id = MAX_UINT48;
        proposal.proposer = address(type(uint160).max);
        proposal.timestamp = MAX_UINT48;
        proposal.coreStateHash = bytes32(type(uint256).max);
        proposal.derivationHash = bytes32(type(uint256).max);

        IInbox.Derivation memory derivation;
        derivation.originBlockNumber = MAX_UINT48;
        derivation.originBlockHash = bytes32(type(uint256).max);
        derivation.isForcedInclusion = true;
        derivation.basefeeSharingPctg = MAX_UINT8;
        derivation.blobSlice.offset = MAX_UINT24;
        derivation.blobSlice.timestamp = MAX_UINT48;
        derivation.blobSlice.blobHashes = new bytes32[](0);

        IInbox.CoreState memory coreState;
        coreState.nextProposalId = MAX_UINT48;
        coreState.lastFinalizedProposalId = MAX_UINT48;
        coreState.lastFinalizedClaimHash = bytes32(type(uint256).max);
        coreState.bondInstructionsHash = bytes32(type(uint256).max);

        bytes memory encoded = LibProposedEventEncoder.encode(proposal, derivation, coreState);
        (
            IInbox.Proposal memory decodedProposal,
            IInbox.Derivation memory decodedDerivation,
            IInbox.CoreState memory decodedCoreState
        ) = LibProposedEventEncoder.decode(encoded);

        // Verify all fields preserved at maximum values
        assertEq(decodedProposal.id, MAX_UINT48);
        assertEq(decodedProposal.proposer, address(type(uint160).max));
        assertEq(decodedProposal.timestamp, MAX_UINT48);
        assertEq(decodedDerivation.originBlockNumber, MAX_UINT48);
        assertEq(decodedDerivation.basefeeSharingPctg, MAX_UINT8);
        assertEq(decodedDerivation.blobSlice.offset, MAX_UINT24);
        assertEq(decodedDerivation.blobSlice.timestamp, MAX_UINT48);
        assertEq(decodedCoreState.nextProposalId, MAX_UINT48);
        assertEq(decodedCoreState.lastFinalizedProposalId, MAX_UINT48);
    }

    function testFuzz_encodeDecodeEmptyBlobHashes() public pure {
        IInbox.Proposal memory proposal;
        IInbox.Derivation memory derivation;
        derivation.blobSlice.blobHashes = new bytes32[](0);
        IInbox.CoreState memory coreState;

        bytes memory encoded = LibProposedEventEncoder.encode(proposal, derivation, coreState);
        (, IInbox.Derivation memory decodedDerivation,) = LibProposedEventEncoder.decode(encoded);

        assertEq(decodedDerivation.blobSlice.blobHashes.length, 0);
    }

    function testFuzz_calculateSizeConsistency(uint8 _blobHashCount) public pure {
        vm.assume(_blobHashCount <= MAX_BLOB_HASHES);

        uint256 expectedSize = LibProposedEventEncoder.calculateProposedEventSize(_blobHashCount);

        // Create test data
        IInbox.Proposal memory proposal;
        IInbox.Derivation memory derivation;
        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode(i));
        }
        derivation.blobSlice.blobHashes = blobHashes;
        IInbox.CoreState memory coreState;

        bytes memory encoded = LibProposedEventEncoder.encode(proposal, derivation, coreState);

        assertEq(encoded.length, expectedSize);
    }
}
