// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibHashOptimized } from "src/layer1/core/libs/LibHashOptimized.sol";

/// @notice Fuzz tests to verify hashProposal produces identical results
/// between the reference implementation (keccak256(abi.encode)) and any optimized version.
contract InboxHashFuzzTest is Test {
    /// @notice Reference implementation: keccak256(abi.encode(proposal))
    function _hashProposalReference(IInbox.Proposal memory _proposal)
        internal
        pure
        returns (bytes32)
    {
        /// forge-lint: disable-start(asm-keccak256)
        return keccak256(abi.encode(_proposal));
    }

    /// @notice Fuzz test: hashProposal with single source / single blob hash
    function test_fuzz_hashProposal_singleSource(
        uint48 _id,
        uint48 _timestamp,
        uint48 _endOfSubmission,
        address _proposer,
        bytes32 _parentHash,
        uint48 _originBlockNumber,
        bytes32 _originBlockHash,
        uint8 _basefeePctg,
        bytes32 _blobHash,
        uint24 _offset,
        uint48 _blobTimestamp
    )
        public
        pure
    {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = _blobHash;
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes, offset: _offset, timestamp: _blobTimestamp
            })
        });

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: _id,
            timestamp: _timestamp,
            endOfSubmissionWindowTimestamp: _endOfSubmission,
            proposer: _proposer,
            parentProposalHash: _parentHash,
            originBlockNumber: _originBlockNumber,
            originBlockHash: _originBlockHash,
            basefeeSharingPctg: _basefeePctg,
            sources: sources
        });

        bytes32 refHash = _hashProposalReference(proposal);
        bytes32 optHash = LibHashOptimized.hashProposal(proposal);
        assertEq(optHash, refHash, "hash mismatch");
    }

    /// @notice Fuzz test: hashProposal with multiple sources (forced + normal)
    function test_fuzz_hashProposal_multipleSources(
        uint48 _id,
        uint48 _timestamp,
        address _proposer,
        bytes32 _parentHash,
        bytes32 _originBlockHash,
        bytes32 _forcedBlobHash,
        bytes32 _normalBlobHash,
        uint48 _forcedTimestamp,
        uint48 _normalTimestamp
    )
        public
        pure
    {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](2);

        // Forced inclusion source
        bytes32[] memory forcedHashes = new bytes32[](1);
        forcedHashes[0] = _forcedBlobHash;
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: forcedHashes, offset: 0, timestamp: _forcedTimestamp
            })
        });

        // Normal source
        bytes32[] memory normalHashes = new bytes32[](1);
        normalHashes[0] = _normalBlobHash;
        sources[1] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: normalHashes, offset: 0, timestamp: _normalTimestamp
            })
        });

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: _id,
            timestamp: _timestamp,
            endOfSubmissionWindowTimestamp: 0,
            proposer: _proposer,
            parentProposalHash: _parentHash,
            originBlockNumber: 100,
            originBlockHash: _originBlockHash,
            basefeeSharingPctg: 75,
            sources: sources
        });

        bytes32 refHash = _hashProposalReference(proposal);
        bytes32 optHash = LibHashOptimized.hashProposal(proposal);
        assertEq(optHash, refHash, "hash mismatch");
    }

    /// @notice Fuzz test: hashProposal with multiple blob hashes per source
    function test_fuzz_hashProposal_multipleBlobs(
        uint48 _id,
        address _proposer,
        bytes32 _parentHash,
        bytes32 _blob0,
        bytes32 _blob1,
        bytes32 _blob2
    )
        public
        pure
    {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        bytes32[] memory blobHashes = new bytes32[](3);
        blobHashes[0] = _blob0;
        blobHashes[1] = _blob1;
        blobHashes[2] = _blob2;
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes, offset: 0, timestamp: 1000 })
        });

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: _id,
            timestamp: 1000,
            endOfSubmissionWindowTimestamp: 0,
            proposer: _proposer,
            parentProposalHash: _parentHash,
            originBlockNumber: 100,
            originBlockHash: bytes32(uint256(1)),
            basefeeSharingPctg: 75,
            sources: sources
        });

        bytes32 refHash = _hashProposalReference(proposal);
        bytes32 optHash = LibHashOptimized.hashProposal(proposal);
        assertEq(optHash, refHash, "hash mismatch");
    }

    /// @notice Reference implementation of validateBlobReference (original Solidity)
    function _validateBlobReferenceReference(LibBlobs.BlobReference memory _blobReference)
        internal
        view
        returns (LibBlobs.BlobSlice memory)
    {
        require(_blobReference.numBlobs > 0);

        bytes32[] memory blobHashes = new bytes32[](_blobReference.numBlobs);
        for (uint256 i; i < _blobReference.numBlobs; ++i) {
            blobHashes[i] = blobhash(_blobReference.blobStartIndex + i);
            require(blobHashes[i] != 0);
        }

        return LibBlobs.BlobSlice({
            blobHashes: blobHashes,
            offset: _blobReference.offset,
            timestamp: uint48(block.timestamp)
        });
    }

    /// @notice Fuzz test: assembly validateBlobReference vs reference Solidity
    function test_fuzz_validateBlobReference(
        uint16 _blobStartIndex,
        uint24 _offset
    )
        public
    {
        // Use 1-3 blobs (bounded to avoid huge arrays)
        uint16 numBlobs = uint16(bound(uint256(_blobStartIndex) % 3 + 1, 1, 3));
        _blobStartIndex = 0; // blobhash only works with index starting from 0 in tests

        // Set up blob hashes
        bytes32[] memory hashes = new bytes32[](numBlobs);
        for (uint256 i; i < numBlobs; ++i) {
            hashes[i] = keccak256(abi.encode("blob", i, _offset));
        }
        vm.blobhashes(hashes);

        LibBlobs.BlobReference memory ref =
            LibBlobs.BlobReference({ blobStartIndex: _blobStartIndex, numBlobs: numBlobs, offset: _offset });

        LibBlobs.BlobSlice memory refSlice = _validateBlobReferenceReference(ref);
        LibBlobs.BlobSlice memory optSlice = LibBlobs.validateBlobReference(ref);

        // Compare all fields
        assertEq(optSlice.blobHashes.length, refSlice.blobHashes.length, "blobHashes length mismatch");
        for (uint256 i; i < refSlice.blobHashes.length; ++i) {
            assertEq(optSlice.blobHashes[i], refSlice.blobHashes[i], "blobHash mismatch");
        }
        assertEq(optSlice.offset, refSlice.offset, "offset mismatch");
        assertEq(optSlice.timestamp, refSlice.timestamp, "timestamp mismatch");
    }

    /// @notice Gas benchmark: hashProposal for single source, single blob
    function test_hashProposal_gas_singleSource() public {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = bytes32(uint256(0xBEEF));
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes, offset: 0, timestamp: 1000 })
        });

        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 1,
            timestamp: 100,
            endOfSubmissionWindowTimestamp: 200,
            proposer: address(0xABC),
            parentProposalHash: bytes32(uint256(0xDEAD)),
            originBlockNumber: 50,
            originBlockHash: bytes32(uint256(0xCAFE)),
            basefeeSharingPctg: 75,
            sources: sources
        });

        vm.startSnapshotGas("hash-proposal", "singleSource");
        LibHashOptimized.hashProposal(proposal);
        vm.stopSnapshotGas();
    }
}
