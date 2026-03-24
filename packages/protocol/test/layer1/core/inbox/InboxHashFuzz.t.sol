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
