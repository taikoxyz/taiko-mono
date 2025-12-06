// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibHashOptimized
/// @notice Optimized hashing functions using Solady's EfficientHashLib
/// @dev This library provides gas-optimized implementations of all hashing functions
///      used in the Inbox contract, replacing standard keccak256(abi.encode(...)) calls
///      with more efficient alternatives from Solady's EfficientHashLib.
/// @custom:security-contact security@taiko.xyz
library LibHashOptimized {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Precomputed hash of empty bytes for gas optimization
    bytes32 private constant EMPTY_BYTES_HASH = keccak256("");

    // ---------------------------------------------------------------
    // Core Structure Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Optimized hashing for blob hashes array
    /// @dev Efficiently hashes an array of blob hashes with explicit length inclusion
    /// @param _blobHashes The blob hashes array to hash
    /// @return The hash of the blob hashes array
    function hashBlobHashesArray(bytes32[] memory _blobHashes) internal pure returns (bytes32) {
        unchecked {
            uint256 length = _blobHashes.length;
            if (length == 0) {
                return EMPTY_BYTES_HASH;
            }

            if (length == 1) {
                return EfficientHashLib.hash(bytes32(length), _blobHashes[0]);
            }

            if (length == 2) {
                return EfficientHashLib.hash(bytes32(length), _blobHashes[0], _blobHashes[1]);
            }

            bytes32[] memory buffer = EfficientHashLib.malloc(length + 1);
            EfficientHashLib.set(buffer, 0, bytes32(length));

            for (uint256 i; i < length; ++i) {
                EfficientHashLib.set(buffer, i + 1, _blobHashes[i]);
            }

            bytes32 result = EfficientHashLib.hash(buffer);
            EfficientHashLib.free(buffer);
            return result;
        }
    }

    /// @notice Optimized hashing for Checkpoint structs
    /// @dev Efficiently hashes the 3 main fields of a checkpoint
    /// @param _checkpoint The checkpoint to hash
    /// @return The hash of the checkpoint
    function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            bytes32(uint256(_checkpoint.blockNumber)), _checkpoint.blockHash, _checkpoint.stateRoot
        );
    }

    /// @notice Optimized hashing for CoreState structs
    /// @dev Efficiently packs and hashes all core state fields
    /// @param _coreState The core state to hash
    /// @return The hash of the core state
    function hashCoreState(IInbox.CoreState memory _coreState) internal pure returns (bytes32) {
        // Struct fields are encoded directly to keep compatibility if ordering changes.
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_coreState));
    }

    /// @notice Optimized hashing for Derivation structs
    /// @dev Manually constructs the ABI-encoded layout to avoid nested abi.encode calls
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivation(IInbox.Derivation memory _derivation) internal pure returns (bytes32) {
        unchecked {
            IInbox.DerivationSource[] memory sources = _derivation.sources;
            uint256 sourcesLength = sources.length;

            // Base words:
            // [0] offset to tuple head (0x20)
            // [1] originBlockNumber
            // [2] originBlockHash
            // [3] basefeeSharingPctg
            // [4] offset to sources (0x80)
            // [5] sources length
            uint256 totalWords = 6 + sourcesLength;

            // Each source contributes: element head (2) + blobSlice head (3) + blobHashes length (1)
            // + blobHashes entries
            for (uint256 i; i < sourcesLength; ++i) {
                totalWords += 6 + sources[i].blobSlice.blobHashes.length;
            }

            bytes32[] memory buffer = EfficientHashLib.malloc(totalWords);

            EfficientHashLib.set(buffer, 0, bytes32(uint256(0x20)));
            EfficientHashLib.set(buffer, 1, bytes32(uint256(_derivation.originBlockNumber)));
            EfficientHashLib.set(buffer, 2, _derivation.originBlockHash);
            EfficientHashLib.set(buffer, 3, bytes32(uint256(_derivation.basefeeSharingPctg)));
            EfficientHashLib.set(buffer, 4, bytes32(uint256(0x80)));
            EfficientHashLib.set(buffer, 5, bytes32(sourcesLength));

            uint256 offsetsBase = 6;
            uint256 dataCursor = offsetsBase + sourcesLength;

            for (uint256 i; i < sourcesLength; ++i) {
                IInbox.DerivationSource memory source = sources[i];
                EfficientHashLib.set(
                    buffer, offsetsBase + i, bytes32((dataCursor - offsetsBase) << 5)
                );

                // DerivationSource head
                EfficientHashLib.set(
                    buffer, dataCursor, bytes32(uint256(source.isForcedInclusion ? 1 : 0))
                );
                EfficientHashLib.set(buffer, dataCursor + 1, bytes32(uint256(0x40)));

                // BlobSlice head
                uint256 blobSliceBase = dataCursor + 2;
                EfficientHashLib.set(buffer, blobSliceBase, bytes32(uint256(0x60)));
                EfficientHashLib.set(
                    buffer, blobSliceBase + 1, bytes32(uint256(source.blobSlice.offset))
                );
                EfficientHashLib.set(
                    buffer, blobSliceBase + 2, bytes32(uint256(source.blobSlice.timestamp))
                );

                // Blob hashes array
                bytes32[] memory blobHashes = source.blobSlice.blobHashes;
                uint256 blobHashesLength = blobHashes.length;
                uint256 blobHashesBase = blobSliceBase + 3;
                EfficientHashLib.set(buffer, blobHashesBase, bytes32(blobHashesLength));

                for (uint256 j; j < blobHashesLength; ++j) {
                    EfficientHashLib.set(buffer, blobHashesBase + 1 + j, blobHashes[j]);
                }

                dataCursor = blobHashesBase + 1 + blobHashesLength;
            }

            bytes32 result = EfficientHashLib.hash(buffer);
            EfficientHashLib.free(buffer);
            return result;
        }
    }

    /// @notice Optimized hashing for Proposal structs
    /// @dev Uses efficient multi-field hashing for all proposal fields
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        bytes32[] memory buffer = EfficientHashLib.malloc(5);

        EfficientHashLib.set(buffer, 0, bytes32(uint256(_proposal.id)));
        EfficientHashLib.set(buffer, 1, bytes32(uint256(_proposal.timestamp)));
        EfficientHashLib.set(buffer, 2, bytes32(uint256(_proposal.endOfSubmissionWindowTimestamp)));
        EfficientHashLib.set(buffer, 3, bytes32(uint256(uint160(_proposal.proposer))));
        EfficientHashLib.set(buffer, 4, _proposal.derivationHash);

        bytes32 result = EfficientHashLib.hash(buffer);
        EfficientHashLib.free(buffer);
        return result;
    }

    /// @notice Optimized hashing for Transition structs
    /// @dev Uses EfficientHashLib to hash transition fields
    /// @param _transition The transition to hash
    /// @return The hash of the transition
    function hashTransition(IInbox.Transition memory _transition) internal pure returns (bytes32) {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_transition));
    }

    /// @notice Memory-optimized hashing for arrays of Transitions
    /// @dev Pre-allocates scratch buffer and prefixes array length to prevent hash collisions.
    /// @param _transitions The transitions array to hash
    /// @return The hash of the transitions array
    function hashTransitions(IInbox.Transition[] memory _transitions)
        internal
        pure
        returns (bytes32)
    {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_transitions));
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @notice Hashes a single derivation source efficiently
    /// @dev Internal helper to hash DerivationSource struct with BlobSlice
    /// @param _source The derivation source to hash
    /// @return The hash of the derivation source
    function _hashDerivationSource(IInbox.DerivationSource memory _source)
        private
        pure
        returns (bytes32)
    {
        // Hash blob slice fields - BlobSlice has blobHashes array, offset, and timestamp
        bytes32 blobHashesHash = hashBlobHashesArray(_source.blobSlice.blobHashes);

        bytes32 blobSliceHash = EfficientHashLib.hash(
            blobHashesHash,
            bytes32(uint256(_source.blobSlice.offset)),
            bytes32(uint256(_source.blobSlice.timestamp))
        );

        return
            EfficientHashLib.hash(
                bytes32(uint256(_source.isForcedInclusion ? 1 : 0)), blobSliceHash
            );
    }
}
