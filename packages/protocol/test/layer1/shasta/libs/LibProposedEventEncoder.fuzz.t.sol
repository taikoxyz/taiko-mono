// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProposedEventEncoder } from "src/layer1/shasta/libs/LibProposedEventEncoder.sol";
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
        uint48 _originTimestamp,
        uint48 _originBlockNumber,
        bool _isForcedInclusion,
        uint8 _basefeeSharingPctg,
        bytes32 _coreStateHash
    )
        public
        pure
    {
        IInbox.Proposal memory original;
        original.id = _id;
        original.proposer = _proposer;
        original.originTimestamp = _originTimestamp;
        original.originBlockNumber = _originBlockNumber;
        original.isForcedInclusion = _isForcedInclusion;
        original.basefeeSharingPctg = _basefeeSharingPctg;
        original.coreStateHash = _coreStateHash;

        IInbox.CoreState memory coreState;

        bytes memory encoded = LibProposedEventEncoder.encode(original, coreState);
        (IInbox.Proposal memory decoded,) = LibProposedEventEncoder.decode(encoded);

        assertEq(decoded.id, original.id);
        assertEq(decoded.proposer, original.proposer);
        assertEq(decoded.originTimestamp, original.originTimestamp);
        assertEq(decoded.originBlockNumber, original.originBlockNumber);
        assertEq(decoded.isForcedInclusion, original.isForcedInclusion);
        assertEq(decoded.basefeeSharingPctg, original.basefeeSharingPctg);
        assertEq(decoded.coreStateHash, original.coreStateHash);
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
        IInbox.CoreState memory original;
        original.nextProposalId = _nextProposalId;
        original.lastFinalizedProposalId = _lastFinalizedProposalId;
        original.lastFinalizedClaimHash = _lastFinalizedClaimHash;
        original.bondInstructionsHash = _bondInstructionsHash;

        bytes memory encoded = LibProposedEventEncoder.encode(proposal, original);
        (, IInbox.CoreState memory decoded) = LibProposedEventEncoder.decode(encoded);

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

        IInbox.Proposal memory original;
        original.blobSlice.offset = _offset;
        original.blobSlice.timestamp = _timestamp;

        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }
        original.blobSlice.blobHashes = blobHashes;

        IInbox.CoreState memory coreState;

        bytes memory encoded = LibProposedEventEncoder.encode(original, coreState);
        (IInbox.Proposal memory decoded,) = LibProposedEventEncoder.decode(encoded);

        assertEq(decoded.blobSlice.offset, original.blobSlice.offset);
        assertEq(decoded.blobSlice.timestamp, original.blobSlice.timestamp);
        assertEq(decoded.blobSlice.blobHashes.length, original.blobSlice.blobHashes.length);

        for (uint256 i = 0; i < _blobHashCount; i++) {
            assertEq(decoded.blobSlice.blobHashes[i], original.blobSlice.blobHashes[i]);
        }
    }

    function testFuzz_completeEncodeDecode_part1(
        uint48 _id,
        address _proposer,
        uint48 _originTimestamp,
        uint48 _originBlockNumber,
        bool _isForcedInclusion,
        uint8 _basefeeSharingPctg
    )
        public
        pure
    {
        IInbox.Proposal memory originalProposal;
        originalProposal.id = _id;
        originalProposal.proposer = _proposer;
        originalProposal.originTimestamp = _originTimestamp;
        originalProposal.originBlockNumber = _originBlockNumber;
        originalProposal.isForcedInclusion = _isForcedInclusion;
        originalProposal.basefeeSharingPctg = _basefeeSharingPctg;

        IInbox.CoreState memory originalCoreState;

        bytes memory encoded = LibProposedEventEncoder.encode(originalProposal, originalCoreState);
        (IInbox.Proposal memory decodedProposal,) = LibProposedEventEncoder.decode(encoded);

        assertEq(decodedProposal.id, originalProposal.id);
        assertEq(decodedProposal.proposer, originalProposal.proposer);
        assertEq(decodedProposal.originTimestamp, originalProposal.originTimestamp);
        assertEq(decodedProposal.originBlockNumber, originalProposal.originBlockNumber);
        assertEq(decodedProposal.isForcedInclusion, originalProposal.isForcedInclusion);
        assertEq(decodedProposal.basefeeSharingPctg, originalProposal.basefeeSharingPctg);
    }

    function testFuzz_completeEncodeDecode_part2(
        uint24 _blobOffset,
        uint48 _blobTimestamp,
        bytes32 _coreStateHash,
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedClaimHash,
        bytes32 _bondInstructionsHash,
        uint8 _blobHashCount
    )
        public
        pure
    {
        vm.assume(_blobHashCount <= 10);

        IInbox.Proposal memory originalProposal;
        originalProposal.coreStateHash = _coreStateHash;
        originalProposal.blobSlice.offset = _blobOffset;
        originalProposal.blobSlice.timestamp = _blobTimestamp;

        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode(_coreStateHash, i));
        }
        originalProposal.blobSlice.blobHashes = blobHashes;

        IInbox.CoreState memory originalCoreState;
        originalCoreState.nextProposalId = _nextProposalId;
        originalCoreState.lastFinalizedProposalId = _lastFinalizedProposalId;
        originalCoreState.lastFinalizedClaimHash = _lastFinalizedClaimHash;
        originalCoreState.bondInstructionsHash = _bondInstructionsHash;

        bytes memory encoded = LibProposedEventEncoder.encode(originalProposal, originalCoreState);

        uint256 expectedSize = LibProposedEventEncoder.calculateProposedEventSize(_blobHashCount);
        assertEq(encoded.length, expectedSize);

        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibProposedEventEncoder.decode(encoded);

        assertEq(decodedProposal.coreStateHash, originalProposal.coreStateHash);
        assertEq(decodedProposal.blobSlice.offset, originalProposal.blobSlice.offset);
        assertEq(decodedProposal.blobSlice.timestamp, originalProposal.blobSlice.timestamp);
        assertEq(
            decodedProposal.blobSlice.blobHashes.length,
            originalProposal.blobSlice.blobHashes.length
        );

        for (uint256 i = 0; i < _blobHashCount; i++) {
            assertEq(
                decodedProposal.blobSlice.blobHashes[i], originalProposal.blobSlice.blobHashes[i]
            );
        }

        assertEq(decodedCoreState.nextProposalId, originalCoreState.nextProposalId);
        assertEq(
            decodedCoreState.lastFinalizedProposalId, originalCoreState.lastFinalizedProposalId
        );
        assertEq(decodedCoreState.lastFinalizedClaimHash, originalCoreState.lastFinalizedClaimHash);
        assertEq(decodedCoreState.bondInstructionsHash, originalCoreState.bondInstructionsHash);
    }

    function testFuzz_calculateSize(uint256 _blobHashCount) public pure {
        vm.assume(_blobHashCount <= MAX_UINT24);

        uint256 expectedSize = 160 + (_blobHashCount * 32);
        uint256 calculatedSize = LibProposedEventEncoder.calculateProposedEventSize(_blobHashCount);
        assertEq(calculatedSize, expectedSize);
    }

    function testFuzz_encodeDecodeWithRandomBlobHashes(
        bytes32[10] memory _randomHashes,
        uint8 _hashCount
    )
        public
        pure
    {
        vm.assume(_hashCount <= 10);

        IInbox.Proposal memory original;
        bytes32[] memory blobHashes = new bytes32[](_hashCount);
        for (uint256 i = 0; i < _hashCount; i++) {
            blobHashes[i] = _randomHashes[i];
        }
        original.blobSlice.blobHashes = blobHashes;

        IInbox.CoreState memory coreState;

        bytes memory encoded = LibProposedEventEncoder.encode(original, coreState);
        (IInbox.Proposal memory decoded,) = LibProposedEventEncoder.decode(encoded);

        assertEq(decoded.blobSlice.blobHashes.length, _hashCount);
        for (uint256 i = 0; i < _hashCount; i++) {
            assertEq(decoded.blobSlice.blobHashes[i], _randomHashes[i]);
        }
    }

    function testFuzz_edgeCases_maxValues() public pure {
        IInbox.Proposal memory original;
        original.id = MAX_UINT48;
        original.proposer = address(type(uint160).max);
        original.originTimestamp = MAX_UINT48;
        original.originBlockNumber = MAX_UINT48;
        original.isForcedInclusion = true;
        original.basefeeSharingPctg = MAX_UINT8;
        original.coreStateHash = bytes32(type(uint256).max);

        original.blobSlice.offset = MAX_UINT24;
        original.blobSlice.timestamp = MAX_UINT48;

        IInbox.CoreState memory coreState;
        coreState.nextProposalId = MAX_UINT48;
        coreState.lastFinalizedProposalId = MAX_UINT48;
        coreState.lastFinalizedClaimHash = bytes32(type(uint256).max);
        coreState.bondInstructionsHash = bytes32(type(uint256).max);

        bytes memory encoded = LibProposedEventEncoder.encode(original, coreState);
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibProposedEventEncoder.decode(encoded);

        assertEq(decodedProposal.id, MAX_UINT48);
        assertEq(decodedProposal.proposer, address(type(uint160).max));
        assertEq(decodedProposal.originTimestamp, MAX_UINT48);
        assertEq(decodedProposal.originBlockNumber, MAX_UINT48);
        assertEq(decodedProposal.isForcedInclusion, true);
        assertEq(decodedProposal.basefeeSharingPctg, MAX_UINT8);
        assertEq(decodedProposal.coreStateHash, bytes32(type(uint256).max));
        assertEq(decodedProposal.blobSlice.offset, MAX_UINT24);
        assertEq(decodedProposal.blobSlice.timestamp, MAX_UINT48);

        assertEq(decodedCoreState.nextProposalId, MAX_UINT48);
        assertEq(decodedCoreState.lastFinalizedProposalId, MAX_UINT48);
        assertEq(decodedCoreState.lastFinalizedClaimHash, bytes32(type(uint256).max));
        assertEq(decodedCoreState.bondInstructionsHash, bytes32(type(uint256).max));
    }

    function testFuzz_edgeCases_zeroValues() public pure {
        IInbox.Proposal memory original;
        IInbox.CoreState memory coreState;

        bytes memory encoded = LibProposedEventEncoder.encode(original, coreState);
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibProposedEventEncoder.decode(encoded);

        assertEq(decodedProposal.id, 0);
        assertEq(decodedProposal.proposer, address(0));
        assertEq(decodedProposal.originTimestamp, 0);
        assertEq(decodedProposal.originBlockNumber, 0);
        assertEq(decodedProposal.isForcedInclusion, false);
        assertEq(decodedProposal.basefeeSharingPctg, 0);
        assertEq(decodedProposal.coreStateHash, bytes32(0));
        assertEq(decodedProposal.blobSlice.offset, 0);
        assertEq(decodedProposal.blobSlice.timestamp, 0);
        assertEq(decodedProposal.blobSlice.blobHashes.length, 0);

        assertEq(decodedCoreState.nextProposalId, 0);
        assertEq(decodedCoreState.lastFinalizedProposalId, 0);
        assertEq(decodedCoreState.lastFinalizedClaimHash, bytes32(0));
        assertEq(decodedCoreState.bondInstructionsHash, bytes32(0));
    }

    function testFuzz_consistency_multipleEncodings(
        uint48 _id,
        address _proposer,
        uint8 _blobCount
    )
        public
        pure
    {
        vm.assume(_blobCount <= 10);

        IInbox.Proposal memory proposal;
        proposal.id = _id;
        proposal.proposer = _proposer;
        proposal.blobSlice.blobHashes = new bytes32[](_blobCount);

        for (uint256 i = 0; i < _blobCount; i++) {
            proposal.blobSlice.blobHashes[i] = keccak256(abi.encode(i));
        }

        IInbox.CoreState memory coreState;

        bytes memory encoded1 = LibProposedEventEncoder.encode(proposal, coreState);
        bytes memory encoded2 = LibProposedEventEncoder.encode(proposal, coreState);

        assertEq(keccak256(encoded1), keccak256(encoded2));

        (IInbox.Proposal memory decoded1, IInbox.CoreState memory decodedState1) =
            LibProposedEventEncoder.decode(encoded1);
        (IInbox.Proposal memory decoded2, IInbox.CoreState memory decodedState2) =
            LibProposedEventEncoder.decode(encoded2);

        assertEq(decoded1.id, decoded2.id);
        assertEq(decoded1.proposer, decoded2.proposer);
        assertEq(decoded1.blobSlice.blobHashes.length, decoded2.blobSlice.blobHashes.length);

        assertEq(decodedState1.nextProposalId, decodedState2.nextProposalId);
    }
}
