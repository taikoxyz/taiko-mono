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
        IInbox.ProposedEventPayload memory payload;

        payload.proposal.id = _id;
        payload.proposal.proposer = _proposer;
        payload.proposal.timestamp = _timestamp;
        payload.proposal.endOfSubmissionWindowTimestamp =
            _timestamp < type(uint48).max - 1000 ? _timestamp + 1000 : _timestamp;
        payload.proposal.coreStateHash = _coreStateHash;
        payload.proposal.derivationHash = _derivationHash;

        payload.derivation.originBlockNumber = _originBlockNumber;
        payload.derivation.originBlockHash = _originBlockHash;
        payload.derivation.isForcedInclusion = _isForcedInclusion;
        payload.derivation.basefeeSharingPctg = _basefeeSharingPctg;
        payload.derivation.blobSlice.blobHashes = new bytes32[](0);

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
        assertEq(decoded.derivation.isForcedInclusion, payload.derivation.isForcedInclusion);
        assertEq(decoded.derivation.basefeeSharingPctg, payload.derivation.basefeeSharingPctg);
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
        payload.derivation.blobSlice.blobHashes = new bytes32[](0);

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
        payload.derivation.blobSlice.offset = _offset;
        payload.derivation.blobSlice.timestamp = _timestamp;

        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }
        payload.derivation.blobSlice.blobHashes = blobHashes;

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        assertEq(decoded.derivation.blobSlice.offset, payload.derivation.blobSlice.offset);
        assertEq(decoded.derivation.blobSlice.timestamp, payload.derivation.blobSlice.timestamp);
        assertEq(
            decoded.derivation.blobSlice.blobHashes.length,
            payload.derivation.blobSlice.blobHashes.length
        );

        for (uint256 i = 0; i < _blobHashCount; i++) {
            assertEq(
                decoded.derivation.blobSlice.blobHashes[i],
                payload.derivation.blobSlice.blobHashes[i]
            );
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

        IInbox.ProposedEventPayload memory payload;

        // Create Proposal with derived values to avoid stack too deep
        payload.proposal.id = _id;
        payload.proposal.proposer = _proposer;
        payload.proposal.timestamp = _timestamp;
        payload.proposal.endOfSubmissionWindowTimestamp =
            _timestamp < type(uint48).max - 1000 ? _timestamp + 1000 : _timestamp;
        payload.proposal.coreStateHash = keccak256(abi.encode("core", _id));
        payload.proposal.derivationHash = keccak256(abi.encode("deriv", _id));

        // Create Derivation with derived values
        payload.derivation.originBlockNumber =
            uint48(uint256(keccak256(abi.encode(_id))) % MAX_UINT48);
        payload.derivation.originBlockHash = keccak256(abi.encode("origin", _id));
        payload.derivation.isForcedInclusion = (_id % 2 == 0);
        payload.derivation.basefeeSharingPctg = uint8(uint256(keccak256(abi.encode(_id))) % 101);

        // Create BlobSlice with derived values
        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", _id, i));
        }
        payload.derivation.blobSlice.blobHashes = blobHashes;
        payload.derivation.blobSlice.offset =
            uint24(uint256(keccak256(abi.encode(_id))) % MAX_UINT24);
        payload.derivation.blobSlice.timestamp =
            uint48(uint256(keccak256(abi.encode(_timestamp))) % MAX_UINT48);

        // Create CoreState with derived values
        payload.coreState.nextProposalId =
            uint48(uint256(keccak256(abi.encode("next", _id))) % MAX_UINT48);
        payload.coreState.lastFinalizedProposalId =
            uint48(uint256(keccak256(abi.encode("last", _id))) % MAX_UINT48);
        payload.coreState.lastFinalizedTransitionHash = keccak256(abi.encode("finalized", _id));
        payload.coreState.bondInstructionsHash = keccak256(abi.encode("bonds", _id));

        // Encode and decode
        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        // Verify all preserved fields
        assertEq(decoded.proposal.id, payload.proposal.id);
        assertEq(decoded.proposal.proposer, payload.proposal.proposer);
        assertEq(decoded.proposal.timestamp, payload.proposal.timestamp);
        assertEq(
            decoded.proposal.endOfSubmissionWindowTimestamp,
            payload.proposal.endOfSubmissionWindowTimestamp
        );
        assertEq(decoded.proposal.coreStateHash, payload.proposal.coreStateHash);
        assertEq(decoded.derivation.originBlockNumber, payload.derivation.originBlockNumber);
        assertEq(decoded.derivation.isForcedInclusion, payload.derivation.isForcedInclusion);
        assertEq(decoded.derivation.basefeeSharingPctg, payload.derivation.basefeeSharingPctg);
        assertEq(decoded.derivation.blobSlice.offset, payload.derivation.blobSlice.offset);
        assertEq(decoded.derivation.blobSlice.timestamp, payload.derivation.blobSlice.timestamp);
        assertEq(
            decoded.derivation.blobSlice.blobHashes.length,
            payload.derivation.blobSlice.blobHashes.length
        );
        for (uint256 i = 0; i < _blobHashCount; i++) {
            assertEq(
                decoded.derivation.blobSlice.blobHashes[i],
                payload.derivation.blobSlice.blobHashes[i]
            );
        }
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

    function testFuzz_encodedSizeIsOptimal(uint8 _blobHashCount) public pure {
        vm.assume(_blobHashCount <= MAX_BLOB_HASHES);

        IInbox.ProposedEventPayload memory payload = _createPayload(_blobHashCount);

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        bytes memory abiEncoded = abi.encode(payload);

        // Compact encoding should be smaller than ABI encoding
        assertLt(encoded.length, abiEncoded.length);
    }

    function testFuzz_roundTripPreservesData(
        uint48 _id,
        address _proposer,
        uint48 _timestamp,
        uint8 _blobHashCount,
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId
    )
        public
        pure
    {
        vm.assume(_blobHashCount <= 10); // Keep small for efficiency

        IInbox.ProposedEventPayload memory original;

        original.proposal.id = _id;
        original.proposal.proposer = _proposer;
        original.proposal.timestamp = _timestamp;
        original.proposal.endOfSubmissionWindowTimestamp =
            _timestamp < type(uint48).max - 1000 ? _timestamp + 1000 : _timestamp;
        original.proposal.coreStateHash = keccak256(abi.encode("core", _id));
        original.proposal.derivationHash = keccak256(abi.encode("deriv", _id));

        original.derivation.originBlockNumber = _timestamp;
        original.derivation.originBlockHash = keccak256(abi.encode("origin", _id));
        original.derivation.isForcedInclusion = (_id % 2 == 0);
        original.derivation.basefeeSharingPctg = uint8(_id % 101);

        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }
        original.derivation.blobSlice.blobHashes = blobHashes;
        original.derivation.blobSlice.offset = uint24(_id % MAX_UINT24);
        original.derivation.blobSlice.timestamp = _timestamp;

        original.coreState.nextProposalId = _nextProposalId;
        original.coreState.lastFinalizedProposalId = _lastFinalizedProposalId;
        original.coreState.lastFinalizedTransitionHash = keccak256(abi.encode("finalized", _id));
        original.coreState.bondInstructionsHash = keccak256(abi.encode("bonds", _id));

        // First round trip
        bytes memory encoded1 = LibProposedEventEncoder.encode(original);
        IInbox.ProposedEventPayload memory decoded1 = LibProposedEventEncoder.decode(encoded1);

        // Second round trip
        bytes memory encoded2 = LibProposedEventEncoder.encode(decoded1);
        IInbox.ProposedEventPayload memory decoded2 = LibProposedEventEncoder.decode(encoded2);

        // Verify data is preserved through multiple round trips
        assertEq(decoded1.proposal.id, decoded2.proposal.id);
        assertEq(decoded1.proposal.proposer, decoded2.proposal.proposer);
        assertEq(decoded1.proposal.timestamp, decoded2.proposal.timestamp);
        assertEq(
            decoded1.proposal.endOfSubmissionWindowTimestamp,
            decoded2.proposal.endOfSubmissionWindowTimestamp
        );
        assertEq(decoded1.coreState.nextProposalId, decoded2.coreState.nextProposalId);
        assertEq(
            decoded1.coreState.lastFinalizedProposalId, decoded2.coreState.lastFinalizedProposalId
        );
        assertEq(encoded1, encoded2);
    }

    function _createPayload(uint8 _blobHashCount)
        private
        pure
        returns (IInbox.ProposedEventPayload memory payload)
    {
        payload.proposal.id = 123;
        payload.proposal.proposer = address(0x1234);
        payload.proposal.timestamp = 1_000_000;
        payload.proposal.endOfSubmissionWindowTimestamp = 1_100_000;
        payload.proposal.coreStateHash = keccak256("core");
        payload.proposal.derivationHash = keccak256("deriv");

        payload.derivation.originBlockNumber = 5_000_000;
        payload.derivation.originBlockHash = keccak256("origin");
        payload.derivation.isForcedInclusion = false;
        payload.derivation.basefeeSharingPctg = 50;

        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }
        payload.derivation.blobSlice.blobHashes = blobHashes;
        payload.derivation.blobSlice.offset = 1024;
        payload.derivation.blobSlice.timestamp = 1_000_001;

        payload.coreState.nextProposalId = 124;
        payload.coreState.lastFinalizedProposalId = 120;
        payload.coreState.lastFinalizedTransitionHash = keccak256("finalized");
        payload.coreState.bondInstructionsHash = keccak256("bonds");
    }
}
