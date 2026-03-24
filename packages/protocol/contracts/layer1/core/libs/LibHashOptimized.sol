// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBlobs } from "./LibBlobs.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";

/// @title LibHashOptimized
/// @notice Optimized hashing functions using Solady's EfficientHashLib(when more efficient than keccak256)
/// @dev This library provides gas-optimized implementations of all hashing functions
///      used in the Inbox contract, replacing standard keccak256(abi.encode(...)) calls
///      with more efficient alternatives from Solady's EfficientHashLib(when more efficient than keccak256).
/// @custom:security-contact security@taiko.xyz
library LibHashOptimized {
    // ---------------------------------------------------------------
    // Core Structure Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Hashing for proposal data using EfficientHashLib.
    /// @dev Gas optimization: uses EfficientHashLib.malloc/free to avoid permanent memory expansion
    ///      from abi.encode. The buffer is freed after hashing, so subsequent operations (event
    ///      emission) don't pay for expanded memory. Produces identical output to
    ///      keccak256(abi.encode(_proposal)) by replicating the exact ABI encoding layout.
    ///
    ///      ABI encoding layout for abi.encode(Proposal):
    ///      [0]    outer offset (0x20)
    ///      [1-8]  static fields (id, timestamp, endOfSubmissionWindowTimestamp, proposer,
    ///             parentProposalHash, originBlockNumber, originBlockHash, basefeeSharingPctg)
    ///      [9]    offset to sources array = 0x120 (9 * 32 = 288)
    ///      [10]   sources.length
    ///      [11..] source offsets (relative to start of element encoding area)
    ///      [...] per source: (isForcedInclusion, offset_to_blobSlice=0x40,
    ///            offset_to_blobHashes=0x60, offset_val, timestamp_val,
    ///            blobHashes.length, blobHashes...)
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        unchecked {
            IInbox.DerivationSource[] memory sources = _proposal.sources;
            uint256 numSources = sources.length;

            // Calculate total words: 1 (outer offset) + 9 (head) + 1 (sources.length)
            // + numSources (offsets) + per-source: 6 + numBlobHashes
            uint256 totalWords = 11 + numSources;
            for (uint256 i; i < numSources; ++i) {
                totalWords += 6 + sources[i].blobSlice.blobHashes.length;
            }

            bytes32[] memory buffer = EfficientHashLib.malloc(totalWords);

            // Outer offset — abi.encode wraps the struct with a leading offset word
            EfficientHashLib.set(buffer, 0, bytes32(uint256(0x20)));

            // Proposal static fields
            EfficientHashLib.set(buffer, 1, bytes32(uint256(_proposal.id)));
            EfficientHashLib.set(buffer, 2, bytes32(uint256(_proposal.timestamp)));
            EfficientHashLib.set(
                buffer, 3, bytes32(uint256(_proposal.endOfSubmissionWindowTimestamp))
            );
            EfficientHashLib.set(buffer, 4, bytes32(uint256(uint160(_proposal.proposer))));
            EfficientHashLib.set(buffer, 5, _proposal.parentProposalHash);
            EfficientHashLib.set(buffer, 6, bytes32(uint256(_proposal.originBlockNumber)));
            EfficientHashLib.set(buffer, 7, _proposal.originBlockHash);
            EfficientHashLib.set(buffer, 8, bytes32(uint256(_proposal.basefeeSharingPctg)));

            // Offset to sources array tail = 9 * 32 = 288 = 0x120
            EfficientHashLib.set(buffer, 9, bytes32(uint256(0x120)));

            // Sources array: length
            EfficientHashLib.set(buffer, 10, bytes32(numSources));

            // Sources element offsets (relative to start of element encoding area)
            uint256 sourceDataOffset = numSources * 32; // skip offset words
            uint256 base = 11;
            for (uint256 i; i < numSources; ++i) {
                EfficientHashLib.set(buffer, base + i, bytes32(sourceDataOffset));
                // Each source: 6 words + numBlobHashes
                sourceDataOffset += (6 + sources[i].blobSlice.blobHashes.length) * 32;
            }
            base += numSources;

            // Sources element data
            for (uint256 i; i < numSources; ++i) {
                LibBlobs.BlobSlice memory slice = sources[i].blobSlice;
                uint256 numBlobHashes = slice.blobHashes.length;

                // DerivationSource head: (bool, offset_to_blobSlice)
                EfficientHashLib.set(
                    buffer, base, bytes32(uint256(sources[i].isForcedInclusion ? 1 : 0))
                );
                // Offset to blobSlice tail = 2 * 32 = 64 = 0x40
                EfficientHashLib.set(buffer, base + 1, bytes32(uint256(0x40)));

                // BlobSlice head: (offset_to_blobHashes, offset, timestamp)
                // Offset to blobHashes tail = 3 * 32 = 96 = 0x60
                EfficientHashLib.set(buffer, base + 2, bytes32(uint256(0x60)));
                EfficientHashLib.set(buffer, base + 3, bytes32(uint256(slice.offset)));
                EfficientHashLib.set(buffer, base + 4, bytes32(uint256(slice.timestamp)));

                // blobHashes array: length + elements
                EfficientHashLib.set(buffer, base + 5, bytes32(numBlobHashes));
                for (uint256 j; j < numBlobHashes; ++j) {
                    EfficientHashLib.set(buffer, base + 6 + j, slice.blobHashes[j]);
                }

                base += 6 + numBlobHashes;
            }

            bytes32 result = EfficientHashLib.hash(buffer);
            EfficientHashLib.free(buffer);
            return result;
        }
    }

    /// @notice Optimized hashing for commitment data.
    /// @param _commitment The commitment data to hash.
    /// @return The hash of the commitment.
    function hashCommitment(IInbox.Commitment memory _commitment) internal pure returns (bytes32) {
        unchecked {
            IInbox.Transition[] memory transitions = _commitment.transitions;
            uint256 transitionsLength = transitions.length;

            // Commitment layout (abi.encode):
            // [0] offset to commitment (0x20)
            //
            // Commitment static section (starts at word 1):
            // [1] firstProposalId
            // [2] firstProposalParentBlockHash
            // [3] lastProposalHash
            // [4] actualProver
            // [5] endBlockNumber
            // [6] endStateRoot
            // [7] offset to transitions (0xe0)
            //
            // Transitions array (starts at word 8):
            // [8] length
            // [9...] transition elements (3 words each)
            uint256 totalWords = 9 + transitionsLength * 3;

            bytes32[] memory buffer = EfficientHashLib.malloc(totalWords);

            // Top-level head
            EfficientHashLib.set(buffer, 0, bytes32(uint256(0x20)));

            // Commitment static fields
            EfficientHashLib.set(buffer, 1, bytes32(uint256(_commitment.firstProposalId)));
            EfficientHashLib.set(buffer, 2, _commitment.firstProposalParentBlockHash);
            EfficientHashLib.set(buffer, 3, _commitment.lastProposalHash);
            EfficientHashLib.set(buffer, 4, bytes32(uint256(uint160(_commitment.actualProver))));
            EfficientHashLib.set(buffer, 5, bytes32(uint256(_commitment.endBlockNumber)));
            EfficientHashLib.set(buffer, 6, _commitment.endStateRoot);
            EfficientHashLib.set(buffer, 7, bytes32(uint256(0xe0)));

            // Transitions array
            EfficientHashLib.set(buffer, 8, bytes32(transitionsLength));

            uint256 base = 9;
            for (uint256 i; i < transitionsLength; ++i) {
                IInbox.Transition memory transition = transitions[i];
                EfficientHashLib.set(buffer, base, bytes32(uint256(uint160(transition.proposer))));
                EfficientHashLib.set(buffer, base + 1, bytes32(uint256(transition.timestamp)));
                EfficientHashLib.set(buffer, base + 2, transition.blockHash);
                base += 3;
            }

            bytes32 result = EfficientHashLib.hash(buffer);
            EfficientHashLib.free(buffer);
            return result;
        }
    }
}
