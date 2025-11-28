// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibProposedEventEncoder } from "src/layer1/core/libs/LibProposedEventEncoder.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibProposedEventEncoderFuzzTest
/// @notice Comprehensive fuzz tests for LibProposedEventEncoder
/// @custom:security-contact security@taiko.xyz
contract LibProposedEventEncoderFuzzTest is Test {
    uint256 constant MAX_BLOB_HASHES = 100;
    uint48 constant MAX_UINT48 = type(uint48).max;
    uint24 constant MAX_UINT24 = type(uint24).max;

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
        payload.derivation.basefeeSharingPctg = _basefeeSharingPctg;

        // Create sources array with single source
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: _isForcedInclusion,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: new bytes32[](0), offset: 0, timestamp: 0 })
        });
        payload.derivation.sources = sources;

        payload.bondInstructions = new LibBonds.BondInstruction[](1);
        payload.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: _id,
            bondType: LibBonds.BondType(uint8(_basefeeSharingPctg % 3)),
            payer: _proposer,
            payee: address(uint160(uint256(_coreStateHash)))
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
        assertEq(decoded.derivation.basefeeSharingPctg, payload.derivation.basefeeSharingPctg);
        assertEq(decoded.derivation.sources.length, 1);
        assertEq(
            decoded.derivation.sources[0].isForcedInclusion,
            payload.derivation.sources[0].isForcedInclusion
        );

        assertEq(decoded.bondInstructions.length, 1);
        assertEq(decoded.bondInstructions[0].proposalId, _id);
        assertEq(uint8(decoded.bondInstructions[0].bondType), uint8(_basefeeSharingPctg % 3));
        assertEq(decoded.bondInstructions[0].payer, _proposer);
        assertEq(decoded.bondInstructions[0].payee, address(uint160(uint256(_coreStateHash))));
    }

    function testFuzz_encodeDecodeCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        uint48 _lastCheckpointTimestamp,
        bytes32 _lastFinalizedTransitionHash,
        bytes32 _bondInstructionsHash
    )
        public
        pure
    {
        IInbox.ProposedEventPayload memory payload;

        // Create empty sources array
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](0);
        payload.derivation.sources = sources;

        payload.coreState.nextProposalId = _nextProposalId;
        payload.coreState.lastFinalizedProposalId = _lastFinalizedProposalId;
        payload.coreState.lastCheckpointTimestamp = _lastCheckpointTimestamp;
        payload.coreState.lastFinalizedTransitionHash = _lastFinalizedTransitionHash;
        payload.coreState.bondInstructionsHash = _bondInstructionsHash;

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        assertEq(decoded.coreState.nextProposalId, payload.coreState.nextProposalId);
        assertEq(
            decoded.coreState.lastFinalizedProposalId, payload.coreState.lastFinalizedProposalId
        );
        assertEq(
            decoded.coreState.lastCheckpointTimestamp, payload.coreState.lastCheckpointTimestamp
        );
        assertEq(
            decoded.coreState.lastFinalizedTransitionHash,
            payload.coreState.lastFinalizedTransitionHash
        );
        assertEq(decoded.coreState.bondInstructionsHash, payload.coreState.bondInstructionsHash);
        assertEq(decoded.bondInstructions.length, 0);
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

        // Create sources array with single source containing blob slice
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes, offset: _offset, timestamp: _timestamp
            })
        });
        payload.derivation.sources = sources;

        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);

        assertEq(decoded.derivation.sources.length, 1);
        assertEq(
            decoded.derivation.sources[0].blobSlice.offset,
            payload.derivation.sources[0].blobSlice.offset
        );
        assertEq(
            decoded.derivation.sources[0].blobSlice.timestamp,
            payload.derivation.sources[0].blobSlice.timestamp
        );
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

        assertEq(decoded.bondInstructions.length, 0);
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
        payload.derivation.basefeeSharingPctg = uint8(uint256(keccak256(abi.encode(_id))) % 101);

        // Create BlobSlice with derived values
        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", _id, i));
        }

        // Create sources array with single source
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: (_id % 2 == 0),
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: uint24(uint256(keccak256(abi.encode(_id))) % MAX_UINT24),
                timestamp: uint48(uint256(keccak256(abi.encode(_timestamp))) % MAX_UINT48)
            })
        });
        payload.derivation.sources = sources;

        uint256 instructionCount = _blobHashCount % 5;
        payload.bondInstructions = new LibBonds.BondInstruction[](instructionCount);
        for (uint256 i; i < instructionCount; ++i) {
            payload.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(uint256(keccak256(abi.encode(_id, i)))),
                bondType: LibBonds.BondType(uint8(i % 3)),
                payer: address(uint160(uint256(keccak256(abi.encode(_proposer, i))))),
                payee: address(uint160(uint256(keccak256(abi.encode(_timestamp, i)))))
            });
        }

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
        assertEq(decoded.derivation.basefeeSharingPctg, payload.derivation.basefeeSharingPctg);
        assertEq(decoded.derivation.sources.length, 1);
        assertEq(
            decoded.derivation.sources[0].isForcedInclusion,
            payload.derivation.sources[0].isForcedInclusion
        );
        assertEq(
            decoded.derivation.sources[0].blobSlice.offset,
            payload.derivation.sources[0].blobSlice.offset
        );
        assertEq(
            decoded.derivation.sources[0].blobSlice.timestamp,
            payload.derivation.sources[0].blobSlice.timestamp
        );
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
        assertEq(decoded.bondInstructions.length, instructionCount);
        for (uint256 i; i < instructionCount; ++i) {
            assertEq(decoded.bondInstructions[i].proposalId, payload.bondInstructions[i].proposalId);
            assertEq(
                uint8(decoded.bondInstructions[i].bondType),
                uint8(payload.bondInstructions[i].bondType)
            );
            assertEq(decoded.bondInstructions[i].payer, payload.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].payee, payload.bondInstructions[i].payee);
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
        original.derivation.basefeeSharingPctg = uint8(_id % 101);

        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }

        // Create sources array with single source
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: (_id % 2 == 0),
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes, offset: uint24(_id % MAX_UINT24), timestamp: _timestamp
            })
        });
        original.derivation.sources = sources;

        original.coreState.nextProposalId = _nextProposalId;
        original.coreState.lastFinalizedProposalId = _lastFinalizedProposalId;
        original.coreState.lastFinalizedTransitionHash = keccak256(abi.encode("finalized", _id));
        original.coreState.bondInstructionsHash = keccak256(abi.encode("bonds", _id));

        uint256 instructionCount = (_blobHashCount % 4);
        original.bondInstructions = new LibBonds.BondInstruction[](instructionCount);
        for (uint256 i; i < instructionCount; ++i) {
            original.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(uint256(keccak256(abi.encode(_id, i)))),
                bondType: LibBonds.BondType(uint8(i % 3)),
                payer: address(uint160(uint256(keccak256(abi.encode(_proposer, i))))),
                payee: address(uint160(uint256(keccak256(abi.encode(_timestamp, i)))))
            });
        }

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
        assertEq(decoded1.bondInstructions.length, instructionCount);
        assertEq(decoded2.bondInstructions.length, instructionCount);
        for (uint256 i; i < instructionCount; ++i) {
            assertEq(
                decoded1.bondInstructions[i].proposalId, decoded2.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decoded1.bondInstructions[i].bondType),
                uint8(decoded2.bondInstructions[i].bondType)
            );
            assertEq(decoded1.bondInstructions[i].payer, decoded2.bondInstructions[i].payer);
            assertEq(decoded1.bondInstructions[i].payee, decoded2.bondInstructions[i].payee);
        }
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
        payload.derivation.basefeeSharingPctg = 50;

        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }

        // Create sources array with single source
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes, offset: 1024, timestamp: 1_000_001
            })
        });
        payload.derivation.sources = sources;

        payload.coreState.nextProposalId = 124;
        payload.coreState.lastFinalizedProposalId = 120;
        payload.coreState.lastFinalizedTransitionHash = keccak256("finalized");
        payload.coreState.bondInstructionsHash = keccak256("bonds");

        payload.bondInstructions = new LibBonds.BondInstruction[](2);
        payload.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111),
            payee: address(0x2222)
        });
        payload.bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 2,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333),
            payee: address(0x4444)
        });
    }
}
