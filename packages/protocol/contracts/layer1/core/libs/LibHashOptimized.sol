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
            // Uses raw assembly keccak256 to avoid EfficientHashLib malloc/set/hash/free overhead
            if (sources.length == 1 && sources[0].blobSlice.blobHashes.length == 1) {
                bytes32 result;
                assembly {
                    let ptr := mload(0x40) // scratch space at free memory pointer

                    // Proposal static fields (9 words)
                    mstore(ptr, mload(_proposal)) // id
                    mstore(add(ptr, 0x20), mload(add(_proposal, 0x20))) // timestamp
                    mstore(add(ptr, 0x40), mload(add(_proposal, 0x40))) // endOfSubmissionWindowTimestamp
                    mstore(add(ptr, 0x60), mload(add(_proposal, 0x60))) // proposer
                    mstore(add(ptr, 0x80), mload(add(_proposal, 0x80))) // parentProposalHash
                    mstore(add(ptr, 0xa0), mload(add(_proposal, 0xa0))) // originBlockNumber
                    mstore(add(ptr, 0xc0), mload(add(_proposal, 0xc0))) // originBlockHash
                    mstore(add(ptr, 0xe0), mload(add(_proposal, 0xe0))) // basefeeSharingPctg
                    mstore(add(ptr, 0x100), 0x120) // offset to sources array

                    // Sources array header (2 words)
                    mstore(add(ptr, 0x120), 1) // length = 1
                    mstore(add(ptr, 0x140), 0x20) // offset to sources[0]

                    // sources[0] DerivationSource (2 words)
                    let sourcesArr := mload(add(_proposal, 0x100))
                    let src0 := mload(add(sourcesArr, 0x20))
                    mstore(add(ptr, 0x160), mload(src0)) // isForcedInclusion
                    mstore(add(ptr, 0x180), 0x40) // offset to blobSlice

                    // BlobSlice (3 words)
                    let blobSlice := mload(add(src0, 0x20))
                    mstore(add(ptr, 0x1a0), 0x60) // offset to blobHashes
                    mstore(add(ptr, 0x1c0), mload(add(blobSlice, 0x20))) // offset
                    mstore(add(ptr, 0x1e0), mload(add(blobSlice, 0x40))) // timestamp

                    // blobHashes array (2 words)
                    let blobHashesArr := mload(blobSlice)
                    mstore(add(ptr, 0x200), 1) // length = 1
                    mstore(add(ptr, 0x220), mload(add(blobHashesArr, 0x20))) // blobHashes[0]

                    result := keccak256(ptr, 0x240) // 18 * 32 = 576
                }
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

            // Fast path: single transition (common prove_single case)
            // Uses raw assembly to avoid EfficientHashLib overhead
            if (transitionsLength == 1) {
                bytes32 result;
                assembly {
                    let ptr := mload(0x40)

                    // [0] offset to commitment (0x20)
                    mstore(ptr, 0x20)
                    // Commitment static fields [1-7]
                    mstore(add(ptr, 0x20), mload(_commitment)) // firstProposalId
                    mstore(add(ptr, 0x40), mload(add(_commitment, 0x20))) // firstProposalParentBlockHash
                    mstore(add(ptr, 0x60), mload(add(_commitment, 0x40))) // lastProposalHash
                    mstore(add(ptr, 0x80), mload(add(_commitment, 0x60))) // actualProver
                    mstore(add(ptr, 0xa0), mload(add(_commitment, 0x80))) // endBlockNumber
                    mstore(add(ptr, 0xc0), mload(add(_commitment, 0xa0))) // endStateRoot
                    mstore(add(ptr, 0xe0), 0xe0) // offset to transitions

                    // Transitions array [8-11]
                    mstore(add(ptr, 0x100), 1) // length = 1
                    // transitions[0]: pointer chase from transitions array
                    let t0 := mload(add(transitions, 0x20))
                    mstore(add(ptr, 0x120), mload(t0)) // proposer
                    mstore(add(ptr, 0x140), mload(add(t0, 0x20))) // timestamp
                    mstore(add(ptr, 0x160), mload(add(t0, 0x40))) // blockHash

                    result := keccak256(ptr, 0x180) // 12 * 32 = 384
                }
                return result;
            }

            // General case: variable-length transitions
            // abi.encode layout: 9 fixed words + 3 words per transition
            uint256 totalWords = 9 + transitionsLength * 3;

            bytes32[] memory buffer = EfficientHashLib.malloc(totalWords);

            EfficientHashLib.set(buffer, 0, bytes32(uint256(0x20)));
            EfficientHashLib.set(buffer, 1, bytes32(uint256(_commitment.firstProposalId)));
            EfficientHashLib.set(buffer, 2, _commitment.firstProposalParentBlockHash);
            EfficientHashLib.set(buffer, 3, _commitment.lastProposalHash);
            EfficientHashLib.set(buffer, 4, bytes32(uint256(uint160(_commitment.actualProver))));
            EfficientHashLib.set(buffer, 5, bytes32(uint256(_commitment.endBlockNumber)));
            EfficientHashLib.set(buffer, 6, _commitment.endStateRoot);
            EfficientHashLib.set(buffer, 7, bytes32(uint256(0xe0)));
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
