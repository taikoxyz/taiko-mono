// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
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
        return EfficientHashLib.hash(
            bytes32(uint256(_coreState.nextProposalId)),
            bytes32(uint256(_coreState.lastProposalBlockId)),
            bytes32(uint256(_coreState.lastFinalizedProposalId)),
            bytes32(uint256(_coreState.lastCheckpointTimestamp)),
            _coreState.lastFinalizedTransitionHash,
            _coreState.bondInstructionsHash
        );
    }

    /// @notice Optimized hashing for Derivation structs
    /// @dev Efficiently packs derivation fields before hashing
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivation(IInbox.Derivation memory _derivation) internal pure returns (bytes32) {
        // Pack origin block number and basefee sharing percentage
        unchecked {
            bytes32 packedFields = bytes32(
                (uint256(_derivation.originBlockNumber) << 208)
                    | (uint256(_derivation.basefeeSharingPctg) << 192)
            );

            // Hash the sources array - each source contains isForcedInclusion flag and blobSlice
            bytes32 sourcesHash;
            uint256 sourcesLength = _derivation.sources.length;
            if (sourcesLength == 0) {
                sourcesHash = EMPTY_BYTES_HASH;
            } else if (sourcesLength == 1) {
                sourcesHash = EfficientHashLib.hash(
                    bytes32(sourcesLength), _hashDerivationSource(_derivation.sources[0])
                );
            } else if (sourcesLength == 2) {
                sourcesHash = EfficientHashLib.hash(
                    bytes32(sourcesLength),
                    _hashDerivationSource(_derivation.sources[0]),
                    _hashDerivationSource(_derivation.sources[1])
                );
            } else {
                bytes32[] memory buffer = EfficientHashLib.malloc(sourcesLength + 1);
                EfficientHashLib.set(buffer, 0, bytes32(sourcesLength));

                for (uint256 i; i < sourcesLength; ++i) {
                    EfficientHashLib.set(
                        buffer, i + 1, _hashDerivationSource(_derivation.sources[i])
                    );
                }

                sourcesHash = EfficientHashLib.hash(buffer);
                EfficientHashLib.free(buffer);
            }

            return EfficientHashLib.hash(packedFields, _derivation.originBlockHash, sourcesHash);
        }
    }

    /// @notice Optimized hashing for Proposal structs
    /// @dev Uses efficient multi-field hashing for all proposal fields
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        // Use separate field packing to avoid address truncation
        // Pack numeric fields together
        unchecked {
            bytes32 packedFields = bytes32(
                (uint256(_proposal.id) << 208) | (uint256(_proposal.timestamp) << 160)
                    | (uint256(_proposal.endOfSubmissionWindowTimestamp) << 112)
            );

            return EfficientHashLib.hash(
                packedFields,
                bytes32(uint256(uint160(_proposal.proposer))), // Full 160-bit address
                _proposal.coreStateHash,
                _proposal.derivationHash
            );
        }
    }

    /// @notice Optimized hashing for Transition structs
    /// @dev Uses EfficientHashLib to hash transition fields
    /// @param _transition The transition to hash
    /// @return The hash of the transition
    function hashTransition(IInbox.Transition memory _transition) internal pure returns (bytes32) {
        return EfficientHashLib.hash(
            _transition.proposalHash,
            _transition.parentTransitionHash,
            hashCheckpoint(_transition.checkpoint)
        );
    }

    /// @notice Optimized hashing for TransitionRecord structs
    /// @dev Efficiently hashes transition records with variable-length bond instructions
    /// @param _transitionRecord The transition record to hash
    /// @return The hash truncated to bytes26 for storage optimization
    function hashTransitionRecord(IInbox.TransitionRecord memory _transitionRecord)
        internal
        pure
        returns (bytes26)
    {
        unchecked {
            // Hash bond instructions with explicit length prefix to avoid collisions
            bytes32 bondInstructionsHash;
            uint256 instructionsLength = _transitionRecord.bondInstructions.length;
            if (instructionsLength == 0) {
                bondInstructionsHash = EMPTY_BYTES_HASH;
            } else if (instructionsLength == 1) {
                bondInstructionsHash = EfficientHashLib.hash(
                    bytes32(instructionsLength),
                    _hashSingleBondInstruction(_transitionRecord.bondInstructions[0])
                );
            } else if (instructionsLength == 2) {
                bondInstructionsHash = EfficientHashLib.hash(
                    bytes32(instructionsLength),
                    _hashSingleBondInstruction(_transitionRecord.bondInstructions[0]),
                    _hashSingleBondInstruction(_transitionRecord.bondInstructions[1])
                );
            } else {
                bytes32[] memory buffer = EfficientHashLib.malloc(instructionsLength + 1);
                EfficientHashLib.set(buffer, 0, bytes32(instructionsLength));

                for (uint256 i; i < instructionsLength; ++i) {
                    EfficientHashLib.set(
                        buffer,
                        i + 1,
                        _hashSingleBondInstruction(_transitionRecord.bondInstructions[i])
                    );
                }

                bondInstructionsHash = EfficientHashLib.hash(buffer);
                EfficientHashLib.free(buffer);
            }

            bytes32 fullHash = EfficientHashLib.hash(
                bytes32(uint256(_transitionRecord.span)),
                bondInstructionsHash,
                _transitionRecord.transitionHash,
                _transitionRecord.checkpointHash
            );

            return bytes26(fullHash);
        }
    }

    /// @notice Memory-optimized hashing for arrays of Transitions with metadata
    /// @dev Pre-allocates scratch buffer and prefixes array length to prevent hash collisions
    ///      Hashes each transition with its corresponding metadata first, then aggregates
    /// @param _transitions The transitions array to hash
    /// @param _metadata The metadata array to hash
    /// @return The hash of the transitions with metadata array
    function hashTransitionsWithMetadata(
        IInbox.Transition[] memory _transitions,
        IInbox.TransitionMetadata[] memory _metadata
    )
        internal
        pure
        returns (bytes32)
    {
        require(_transitions.length == _metadata.length, InconsistentLengths());
        unchecked {
            uint256 length = _transitions.length;
            if (length == 0) {
                return EMPTY_BYTES_HASH;
            }

            if (length == 1) {
                bytes32 transitionWithMetadataHash =
                    _hashTransitionWithMetadata(_transitions[0], _metadata[0]);
                return EfficientHashLib.hash(bytes32(length), transitionWithMetadataHash);
            }

            if (length == 2) {
                bytes32 hash0 = _hashTransitionWithMetadata(_transitions[0], _metadata[0]);
                bytes32 hash1 = _hashTransitionWithMetadata(_transitions[1], _metadata[1]);
                return EfficientHashLib.hash(bytes32(length), hash0, hash1);
            }

            bytes32[] memory buffer = EfficientHashLib.malloc(length + 1);
            EfficientHashLib.set(buffer, 0, bytes32(length));

            for (uint256 i; i < length; ++i) {
                EfficientHashLib.set(
                    buffer, i + 1, _hashTransitionWithMetadata(_transitions[i], _metadata[i])
                );
            }

            bytes32 result = EfficientHashLib.hash(buffer);
            EfficientHashLib.free(buffer);
            return result;
        }
    }

    // ---------------------------------------------------------------
    // Utility Functions
    // ---------------------------------------------------------------

    /// @notice Computes optimized composite key for transition record storage
    /// @dev Creates unique identifier using efficient hashing
    /// @param _proposalId The ID of the proposal
    /// @param _compositeKeyVersion Version identifier for key generation
    /// @param _parentTransitionHash Hash of the parent transition
    /// @return The composite key for storage mapping
    function composeTransitionKey(
        uint48 _proposalId,
        uint16 _compositeKeyVersion,
        bytes32 _parentTransitionHash
    )
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            bytes32(uint256(_proposalId)),
            bytes32(uint256(_compositeKeyVersion)),
            _parentTransitionHash
        );
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

    /// @notice Safely hashes a single bond instruction to avoid collisions
    /// @dev Internal helper to avoid code duplication and prevent hash collisions
    /// @param _instruction The bond instruction to hash
    /// @return The hash of the bond instruction
    function _hashSingleBondInstruction(LibBonds.BondInstruction memory _instruction)
        private
        pure
        returns (bytes32)
    {
        // Use EfficientHashLib to safely hash all fields without collision risk
        return EfficientHashLib.hash(
            bytes32(uint256(_instruction.proposalId)),
            bytes32(uint256(uint8(_instruction.bondType))),
            bytes32(uint256(uint160(_instruction.payer))),
            bytes32(uint256(uint160(_instruction.payee)))
        );
    }

    /// @notice Gas-optimized hashing of a transition with its metadata
    /// @dev Hashes transition first, then combines with metadata fields using packed encoding
    /// @param _transition The transition to hash
    /// @param _metadata The metadata to combine with the transition
    /// @return The hash of the transition combined with metadata
    function _hashTransitionWithMetadata(
        IInbox.Transition memory _transition,
        IInbox.TransitionMetadata memory _metadata
    )
        private
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            _transition.proposalHash,
            _transition.parentTransitionHash,
            hashCheckpoint(_transition.checkpoint),
            bytes32(uint256(uint160(_metadata.designatedProver))),
            bytes32(uint256(uint160(_metadata.actualProver)))
        );
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InconsistentLengths();
}
