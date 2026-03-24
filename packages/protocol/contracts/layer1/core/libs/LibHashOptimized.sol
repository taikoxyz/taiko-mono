// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

    /// @notice Gas-optimized hashing for proposal data using assembly.
    /// @dev Uses direct MSTORE to build the ABI encoding buffer instead of Solidity's abi.encode.
    ///      This avoids the compiler-generated ABI encoder overhead for nested dynamic types
    ///      (DerivationSource[] containing BlobSlice with bytes32[]).
    ///      Produces identical output to keccak256(abi.encode(_proposal)).
    ///      The buffer is written at the free memory pointer without advancing it (temporary use).
    ///
    ///      ABI encoding layout (abi.encode(Proposal)):
    ///      [0]    0x20 (outer offset to tuple)
    ///      [1-8]  static fields (id..basefeeSharingPctg)
    ///      [9]    0x120 (offset to sources = 9 * 32)
    ///      [10]   sources.length
    ///      [11..] source offsets (relative to element encoding area)
    ///      per source: (isForcedInclusion, 0x40, 0x60, offset, timestamp, blobHashes.length, blobHashes...)
    /// @param _proposal The proposal to hash
    /// @return result_ The keccak256 hash matching keccak256(abi.encode(_proposal))
    function hashProposal(IInbox.Proposal memory _proposal)
        internal
        pure
        returns (bytes32 result_)
    {
        /// forge-lint: disable-start(asm-keccak256)
        assembly {
            let ptr := mload(0x40)

            // Word 0: outer offset — abi.encode wraps struct with leading 0x20
            mstore(ptr, 0x20)

            // Words 1-8: Proposal static fields read directly from memory struct.
            // Proposal memory layout: id(0x00), timestamp(0x20), endOfSubmission(0x40),
            //   proposer(0x60), parentHash(0x80), originBlockNumber(0xa0),
            //   originBlockHash(0xc0), basefeeSharingPctg(0xe0), sourcesPtr(0x100)
            mstore(add(ptr, 0x20), mload(_proposal))
            mstore(add(ptr, 0x40), mload(add(_proposal, 0x20)))
            mstore(add(ptr, 0x60), mload(add(_proposal, 0x40)))
            mstore(add(ptr, 0x80), mload(add(_proposal, 0x60)))
            mstore(add(ptr, 0xa0), mload(add(_proposal, 0x80)))
            mstore(add(ptr, 0xc0), mload(add(_proposal, 0xa0)))
            mstore(add(ptr, 0xe0), mload(add(_proposal, 0xc0)))
            mstore(add(ptr, 0x100), mload(add(_proposal, 0xe0)))

            // Word 9: offset to sources array = 9 * 32 = 0x120
            mstore(add(ptr, 0x120), 0x120)

            // Sources array
            let sourcesArrPtr := mload(add(_proposal, 0x100))
            let numSources := mload(sourcesArrPtr)

            // Word 10: sources.length
            mstore(add(ptr, 0x140), numSources)

            // Source element offsets + data
            let offsetArea := add(ptr, 0x160)
            let dataArea := add(offsetArea, mul(numSources, 0x20))
            let curDataOffset := mul(numSources, 0x20)

            for { let i := 0 } lt(i, numSources) { i := add(i, 1) } {
                // Write offset for this source (relative to element encoding start)
                mstore(add(offsetArea, mul(i, 0x20)), curDataOffset)

                // Follow pointer chain: sourcesArr -> sourceStruct -> blobSlice -> blobHashes
                let srcPtr := mload(add(add(sourcesArrPtr, 0x20), mul(i, 0x20)))
                let blobSlicePtr := mload(add(srcPtr, 0x20))
                let blobHashesPtr := mload(blobSlicePtr)
                let numHashes := mload(blobHashesPtr)

                // DerivationSource: (isForcedInclusion, offset_to_blobSlice=0x40)
                mstore(dataArea, mload(srcPtr))
                mstore(add(dataArea, 0x20), 0x40)

                // BlobSlice: (offset_to_blobHashes=0x60, offset, timestamp)
                mstore(add(dataArea, 0x40), 0x60)
                mstore(add(dataArea, 0x60), mload(add(blobSlicePtr, 0x20)))
                mstore(add(dataArea, 0x80), mload(add(blobSlicePtr, 0x40)))

                // blobHashes: (length, hash0, hash1, ...)
                mstore(add(dataArea, 0xa0), numHashes)
                for { let j := 0 } lt(j, numHashes) { j := add(j, 1) } {
                    mstore(
                        add(add(dataArea, 0xc0), mul(j, 0x20)),
                        mload(add(add(blobHashesPtr, 0x20), mul(j, 0x20)))
                    )
                }

                // Advance: each source takes (6 + numHashes) words
                let sourceBytes := mul(add(6, numHashes), 0x20)
                dataArea := add(dataArea, sourceBytes)
                curDataOffset := add(curDataOffset, sourceBytes)
            }

            result_ := keccak256(ptr, sub(dataArea, ptr))
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
