// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibProposalCoreStateCodec } from "src/layer1/shasta/libs/LibProposalCoreStateCodec.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title LibProposalCoreStateCodec_Fuzz
/// @notice Comprehensive fuzz tests for LibProposalCoreStateCodec encoding/decoding functions
/// @custom:security-contact security@taiko.xyz
contract LibProposalCoreStateCodec_Fuzz is CommonTest {
    // ---------------------------------------------------------------
    // Fuzz tests for basic types
    // ---------------------------------------------------------------

    /// @notice Fuzz test for empty array encoding/decoding
    function testFuzz_emptyArray(
        uint48 _id,
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
        // Bound values to respect validation limits
        _basefeeSharingPctg = uint8(bound(_basefeeSharingPctg, 0, 100));

        // Create proposal with EMPTY blob hash array
        bytes32[] memory blobHashes = new bytes32[](0);

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            originTimestamp: _originTimestamp,
            originBlockNumber: _originBlockNumber,
            isForcedInclusion: _isForcedInclusion,
            basefeeSharingPctg: _basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: _blobOffset,
                timestamp: _blobTimestamp
            }),
            coreStateHash: _coreStateHash
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: _id < type(uint48).max ? _id + 1 : _id,
            lastFinalizedProposalId: _id > 0 ? _id - 1 : 0,
            lastFinalizedClaimHash: keccak256(abi.encode(_id)),
            bondInstructionsHash: keccak256(abi.encode(_proposer))
        });

        // Test optimized encoding/decoding with empty array
        bytes memory encoded = LibProposalCoreStateCodec.encode(proposal, coreState);
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibProposalCoreStateCodec.decode(encoded);

        // Verify correctness
        _verifyProposal(proposal, decodedProposal);
        _verifyCoreState(coreState, decodedCoreState);

        // Verify empty array was preserved
        assertEq(decodedProposal.blobSlice.blobHashes.length, 0, "Empty array should be preserved");
    }

    /// @notice Fuzz test for single proposal encoding/decoding
    function testFuzz_singleProposal(
        uint48 _id,
        address _proposer,
        uint48 _originTimestamp,
        uint48 _originBlockNumber,
        bool _isForcedInclusion,
        uint8 _basefeeSharingPctg,
        uint24 _blobOffset,
        uint48 _blobTimestamp,
        bytes32 _coreStateHash,
        uint8 _numHashes
    )
        public
        pure
    {
        // Bound values to respect validation limits
        _basefeeSharingPctg = uint8(bound(_basefeeSharingPctg, 0, 100));
        _blobTimestamp = uint48(bound(_blobTimestamp, 0, type(uint48).max));
        _numHashes = uint8(bound(_numHashes, 0, 64)); // Include empty arrays

        // Create a proposal with variable number of blob hashes
        bytes32[] memory blobHashes = new bytes32[](_numHashes);
        for (uint256 i = 0; i < _numHashes; i++) {
            blobHashes[i] = keccak256(abi.encode(_id, _proposer, i));
        }

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            originTimestamp: _originTimestamp,
            originBlockNumber: _originBlockNumber,
            isForcedInclusion: _isForcedInclusion,
            basefeeSharingPctg: _basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: _blobOffset,
                timestamp: _blobTimestamp
            }),
            coreStateHash: _coreStateHash
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: _id < type(uint48).max ? _id + 1 : _id,
            lastFinalizedProposalId: _id > 0 ? _id - 1 : 0,
            lastFinalizedClaimHash: keccak256(abi.encode(_id)),
            bondInstructionsHash: keccak256(abi.encode(_proposer))
        });

        // Test optimized encoding/decoding
        bytes memory encoded = LibProposalCoreStateCodec.encode(proposal, coreState);
        (IInbox.Proposal memory decodedProposal, IInbox.CoreState memory decodedCoreState) =
            LibProposalCoreStateCodec.decode(encoded);

        // Verify correctness
        _verifyProposal(proposal, decodedProposal);
        _verifyCoreState(coreState, decodedCoreState);

        // Compare sizes with baseline
        bytes memory baselineEncoded = abi.encode(proposal, coreState);
        assertTrue(encoded.length <= baselineEncoded.length, "Optimized should be smaller or equal");
    }

    /// @notice Fuzz test with variable array sizes including empty arrays
    function testFuzz_variableArraySizes(
        uint48 _id,
        address _proposer,
        uint8 _arraySize,
        uint48 _timestamp,
        bool _isForcedInclusion,
        uint8 _basefeeSharingPctg
    )
        public
        view
    {
        // Bound array size from 0 to 64 to include empty arrays
        _arraySize = uint8(bound(_arraySize, 0, 64));
        _basefeeSharingPctg = uint8(bound(_basefeeSharingPctg, 0, 100));
        _timestamp = uint48(bound(_timestamp, 0, type(uint48).max - 1));

        // Create proposal with variable blob hash array
        bytes32[] memory blobHashes = new bytes32[](_arraySize);
        for (uint256 i = 0; i < _arraySize; i++) {
            blobHashes[i] = keccak256(abi.encode(_id, i));
        }

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            originTimestamp: _timestamp,
            originBlockNumber: uint48(block.number),
            isForcedInclusion: _isForcedInclusion,
            basefeeSharingPctg: _basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 0,
                timestamp: _timestamp + 1
            }),
            coreStateHash: keccak256(abi.encode(_id))
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: _id < type(uint48).max ? _id + 1 : _id,
            lastFinalizedProposalId: _id,
            lastFinalizedClaimHash: bytes32(uint256(_id)),
            bondInstructionsHash: bytes32(uint256(uint160(_proposer)))
        });

        // Encode and decode
        bytes memory encoded = LibProposalCoreStateCodec.encode(proposal, coreState);
        (IInbox.Proposal memory decoded, IInbox.CoreState memory decodedCore) =
            LibProposalCoreStateCodec.decode(encoded);

        // Verify
        _verifyProposal(proposal, decoded);
        _verifyCoreState(coreState, decodedCore);
    }

    /// @notice Fuzz test with extreme values
    function testFuzz_extremeValues(bool _useMaxValues) public pure {
        IInbox.Proposal memory proposal;
        IInbox.CoreState memory coreState;

        if (_useMaxValues) {
            // Test with maximum values
            bytes32[] memory blobHashes = new bytes32[](64); // Max array size
            for (uint256 i = 0; i < 64; i++) {
                blobHashes[i] = bytes32(type(uint256).max - i);
            }

            proposal = IInbox.Proposal({
                id: type(uint48).max,
                proposer: address(type(uint160).max),
                originTimestamp: type(uint48).max,
                originBlockNumber: type(uint48).max,
                isForcedInclusion: true,
                basefeeSharingPctg: 100,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: type(uint24).max,
                    timestamp: type(uint48).max
                }),
                coreStateHash: bytes32(type(uint256).max)
            });

            coreState = IInbox.CoreState({
                nextProposalId: type(uint48).max,
                lastFinalizedProposalId: type(uint48).max,
                lastFinalizedClaimHash: bytes32(type(uint256).max),
                bondInstructionsHash: bytes32(type(uint256).max)
            });
        } else {
            // Test with minimum values
            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = bytes32(0);

            proposal = IInbox.Proposal({
                id: 0,
                proposer: address(0),
                originTimestamp: 0,
                originBlockNumber: 0,
                isForcedInclusion: false,
                basefeeSharingPctg: 0,
                blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes, offset: 0, timestamp: 0 }),
                coreStateHash: bytes32(0)
            });

            coreState = IInbox.CoreState({
                nextProposalId: 0,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: bytes32(0),
                bondInstructionsHash: bytes32(0)
            });
        }

        // Test both implementations
        bytes memory encoded = LibProposalCoreStateCodec.encode(proposal, coreState);
        (IInbox.Proposal memory decoded, IInbox.CoreState memory decodedCore) =
            LibProposalCoreStateCodec.decode(encoded);

        _verifyProposal(proposal, decoded);
        _verifyCoreState(coreState, decodedCore);

        // Verify against baseline
        bytes memory baselineEncoded = abi.encode(proposal, coreState);
        (IInbox.Proposal memory baselineDecoded, IInbox.CoreState memory baselineDecodedCore) =
            abi.decode(baselineEncoded, (IInbox.Proposal, IInbox.CoreState));

        _verifyProposal(proposal, baselineDecoded);
        _verifyCoreState(coreState, baselineDecodedCore);
    }

    /// @notice Fuzz test for hash collision resistance
    function testFuzz_hashCollisionResistance(bytes32 _seed, uint8 _iterations) public pure {
        _iterations = uint8(bound(_iterations, 1, 10));

        for (uint256 i = 0; i < _iterations; i++) {
            bytes32 uniqueSeed = keccak256(abi.encode(_seed, i));

            bytes32[] memory blobHashes = new bytes32[](2);
            blobHashes[0] = uniqueSeed;
            blobHashes[1] = keccak256(abi.encode(uniqueSeed));

            IInbox.Proposal memory proposal = IInbox.Proposal({
                id: uint48(uint256(uniqueSeed) % type(uint48).max),
                proposer: address(uint160(uint256(uniqueSeed))),
                originTimestamp: uint48((uint256(uniqueSeed) >> 48) % type(uint48).max),
                originBlockNumber: uint48((uint256(uniqueSeed) >> 96) % type(uint48).max),
                isForcedInclusion: uint256(uniqueSeed) % 2 == 0,
                basefeeSharingPctg: uint8(uint256(uniqueSeed) % 101),
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: uint24(uint256(uniqueSeed) % type(uint24).max),
                    timestamp: uint48((uint256(uniqueSeed) >> 144) % type(uint48).max)
                }),
                coreStateHash: uniqueSeed
            });

            IInbox.CoreState memory coreState = IInbox.CoreState({
                nextProposalId: uint48((uint256(uniqueSeed) >> 192) % type(uint48).max),
                lastFinalizedProposalId: uint48((uint256(uniqueSeed) >> 240) % type(uint48).max),
                lastFinalizedClaimHash: keccak256(abi.encode(uniqueSeed, "claim")),
                bondInstructionsHash: keccak256(abi.encode(uniqueSeed, "bond"))
            });

            bytes memory encoded = LibProposalCoreStateCodec.encode(proposal, coreState);
            (IInbox.Proposal memory decoded, IInbox.CoreState memory decodedCore) =
                LibProposalCoreStateCodec.decode(encoded);

            _verifyProposal(proposal, decoded);
            _verifyCoreState(coreState, decodedCore);
        }
    }

    /// @notice Differential fuzz test comparing optimized vs baseline
    function testFuzz_differential(
        uint48 _id,
        address _proposer,
        uint48 _timestamp,
        uint48 _blockNumber,
        bool _isForcedInclusion,
        uint8 _basefeeSharingPctg,
        uint8 _numHashes,
        bytes32 _coreStateHash,
        uint48 _nextId,
        uint48 _lastFinalizedId,
        bytes32 _lastClaimHash,
        bytes32 _bondHash
    )
        public
        pure
    {
        // Bound inputs
        _basefeeSharingPctg = uint8(bound(_basefeeSharingPctg, 0, 100));
        _numHashes = uint8(bound(_numHashes, 1, 64));
        _timestamp = uint48(bound(_timestamp, 0, type(uint48).max - 1));

        // Create blob hashes
        bytes32[] memory blobHashes = new bytes32[](_numHashes);
        for (uint256 i = 0; i < _numHashes; i++) {
            blobHashes[i] = keccak256(abi.encode(_coreStateHash, i));
        }

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: _id,
            proposer: _proposer,
            originTimestamp: _timestamp,
            originBlockNumber: _blockNumber,
            isForcedInclusion: _isForcedInclusion,
            basefeeSharingPctg: _basefeeSharingPctg,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: uint24(uint256(_coreStateHash) % type(uint24).max),
                timestamp: _timestamp + 1
            }),
            coreStateHash: _coreStateHash
        });

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: _nextId,
            lastFinalizedProposalId: _lastFinalizedId,
            lastFinalizedClaimHash: _lastClaimHash,
            bondInstructionsHash: _bondHash
        });

        // Encode with both methods
        bytes memory optimizedEncoded = LibProposalCoreStateCodec.encode(proposal, coreState);
        bytes memory baselineEncoded = abi.encode(proposal, coreState);

        // Decode with respective methods
        (IInbox.Proposal memory optimizedDecoded, IInbox.CoreState memory optimizedDecodedCore) =
            LibProposalCoreStateCodec.decode(optimizedEncoded);
        (IInbox.Proposal memory baselineDecoded, IInbox.CoreState memory baselineDecodedCore) =
            abi.decode(baselineEncoded, (IInbox.Proposal, IInbox.CoreState));

        // Both should decode to the same values
        _verifyProposal(proposal, optimizedDecoded);
        _verifyCoreState(coreState, optimizedDecodedCore);
        _verifyProposal(proposal, baselineDecoded);
        _verifyCoreState(coreState, baselineDecodedCore);

        // Optimized should be more efficient
        assertTrue(
            optimizedEncoded.length <= baselineEncoded.length,
            "Optimized encoding should not be larger than baseline"
        );
    }

    // ---------------------------------------------------------------
    // Helper functions
    // ---------------------------------------------------------------

    function _verifyProposal(
        IInbox.Proposal memory _expected,
        IInbox.Proposal memory _actual
    )
        private
        pure
    {
        assertEq(_expected.id, _actual.id, "id mismatch");
        assertEq(_expected.proposer, _actual.proposer, "proposer mismatch");
        assertEq(_expected.originTimestamp, _actual.originTimestamp, "originTimestamp mismatch");
        assertEq(
            _expected.originBlockNumber, _actual.originBlockNumber, "originBlockNumber mismatch"
        );
        assertEq(
            _expected.isForcedInclusion, _actual.isForcedInclusion, "isForcedInclusion mismatch"
        );
        assertEq(
            _expected.basefeeSharingPctg, _actual.basefeeSharingPctg, "basefeeSharingPctg mismatch"
        );
        assertEq(_expected.coreStateHash, _actual.coreStateHash, "coreStateHash mismatch");

        // Verify blob slice
        assertEq(_expected.blobSlice.offset, _actual.blobSlice.offset, "blobSlice.offset mismatch");
        assertEq(
            _expected.blobSlice.timestamp,
            _actual.blobSlice.timestamp,
            "blobSlice.timestamp mismatch"
        );
        assertEq(
            _expected.blobSlice.blobHashes.length,
            _actual.blobSlice.blobHashes.length,
            "blobHashes length mismatch"
        );

        for (uint256 i = 0; i < _expected.blobSlice.blobHashes.length; i++) {
            assertEq(
                _expected.blobSlice.blobHashes[i],
                _actual.blobSlice.blobHashes[i],
                string(abi.encodePacked("blobHash[", vm.toString(i), "] mismatch"))
            );
        }
    }

    function _verifyCoreState(
        IInbox.CoreState memory _expected,
        IInbox.CoreState memory _actual
    )
        private
        pure
    {
        assertEq(_expected.nextProposalId, _actual.nextProposalId, "nextProposalId mismatch");
        assertEq(
            _expected.lastFinalizedProposalId,
            _actual.lastFinalizedProposalId,
            "lastFinalizedProposalId mismatch"
        );
        assertEq(
            _expected.lastFinalizedClaimHash,
            _actual.lastFinalizedClaimHash,
            "lastFinalizedClaimHash mismatch"
        );
        assertEq(
            _expected.bondInstructionsHash,
            _actual.bondInstructionsHash,
            "bondInstructionsHash mismatch"
        );
    }
}
