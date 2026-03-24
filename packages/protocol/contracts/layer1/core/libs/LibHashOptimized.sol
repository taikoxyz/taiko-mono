// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "./LibBlobs.sol";
import { IInbox } from "../iface/IInbox.sol";
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

    /// @notice Hashing for proposal data.
    /// @dev Fast path for the common case (1 source, 1 blobHash) uses EfficientHashLib
    /// with a pre-computed 18-word abi.encode layout. Falls back to keccak256(abi.encode(...))
    /// for other cases.
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        unchecked {
            IInbox.DerivationSource[] memory sources = _proposal.sources;

            // Fast path: 1 source with exactly 1 blobHash (the common case)
            if (sources.length == 1 && sources[0].blobSlice.blobHashes.length == 1) {
                // abi.encode layout for Proposal with 1 source, 1 blobHash = 18 words
                bytes32[] memory buf = EfficientHashLib.malloc(18);

                // Proposal static fields
                EfficientHashLib.set(buf, 0, bytes32(uint256(_proposal.id)));
                EfficientHashLib.set(buf, 1, bytes32(uint256(_proposal.timestamp)));
                EfficientHashLib.set(
                    buf, 2, bytes32(uint256(_proposal.endOfSubmissionWindowTimestamp))
                );
                EfficientHashLib.set(buf, 3, bytes32(uint256(uint160(_proposal.proposer))));
                EfficientHashLib.set(buf, 4, _proposal.parentProposalHash);
                EfficientHashLib.set(buf, 5, bytes32(uint256(_proposal.originBlockNumber)));
                EfficientHashLib.set(buf, 6, _proposal.originBlockHash);
                EfficientHashLib.set(buf, 7, bytes32(uint256(_proposal.basefeeSharingPctg)));
                EfficientHashLib.set(buf, 8, bytes32(uint256(0x120))); // offset to sources

                // Sources array header
                EfficientHashLib.set(buf, 9, bytes32(uint256(1))); // length
                EfficientHashLib.set(buf, 10, bytes32(uint256(0x20))); // offset to sources[0]

                // sources[0] (DerivationSource)
                IInbox.DerivationSource memory src = sources[0];
                EfficientHashLib.set(buf, 11, bytes32(uint256(src.isForcedInclusion ? 1 : 0)));
                EfficientHashLib.set(buf, 12, bytes32(uint256(0x40))); // offset to blobSlice

                // BlobSlice fields
                EfficientHashLib.set(buf, 13, bytes32(uint256(0x60))); // offset to blobHashes
                EfficientHashLib.set(buf, 14, bytes32(uint256(src.blobSlice.offset)));
                EfficientHashLib.set(buf, 15, bytes32(uint256(src.blobSlice.timestamp)));

                // blobHashes array
                EfficientHashLib.set(buf, 16, bytes32(uint256(1))); // length
                EfficientHashLib.set(buf, 17, src.blobSlice.blobHashes[0]);

                bytes32 result = EfficientHashLib.hash(buf);
                EfficientHashLib.free(buf);
                return result;
            }

            // Fallback: general case
            /// forge-lint: disable-start(asm-keccak256)
            return keccak256(abi.encode(_proposal));
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
