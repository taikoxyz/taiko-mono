// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibHashOptimized
/// @notice Optimized hashing functions using Solady's EfficientHashLib for IInbox structs
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
    // Singular Hashing Functions
    // ---------------------------------------------------------------

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
            bytes32(uint256(_coreState.proposalHead)),
            bytes32(uint256(_coreState.proposalHeadContainerBlock)),
            bytes32(uint256(_coreState.finalizationHead)),
            bytes32(uint256(_coreState.synchronizationHead)),
            _coreState.finalizationHeadTransitionHash,
            _coreState.aggregatedBondInstructionsHash
        );
    }

    /// @notice Optimized hashing for Derivation structs
    /// @dev Efficiently packs derivation fields before hashing
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivation(IInbox.Derivation memory _derivation) internal pure returns (bytes32) {
        unchecked {
            // Pack origin block number (uint40 = 40 bits) and basefee sharing percentage (uint8 = 8 bits)
            bytes32 packedFields = bytes32(
                (uint256(_derivation.originBlockNumber) << 216)
                    | (uint256(_derivation.basefeeSharingPctg) << 208)
            );

            // Hash the sources array
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
        unchecked {
            // Pack numeric fields together (each uint40 = 40 bits)
            bytes32 packedFields = bytes32(
                (uint256(_proposal.id) << 216) | (uint256(_proposal.timestamp) << 176)
                    | (uint256(_proposal.endOfSubmissionWindowTimestamp) << 136)
            );

            return EfficientHashLib.hash(
                packedFields,
                bytes32(uint256(uint160(_proposal.proposer))),
                _proposal.coreStateHash,
                _proposal.derivationHash,
                _proposal.parentProposalHash
            );
        }
    }

    /// @notice Optimized hashing for Transition structs
    /// @dev Uses EfficientHashLib to hash transition fields
    /// @param _transition The transition to hash
    /// @return The hash truncated to bytes27 for storage optimization
    function hashTransition(IInbox.Transition memory _transition) internal pure returns (bytes27) {
        return bytes27(
            EfficientHashLib.hash(_transition.bondInstructionHash, _transition.checkpointHash)
        );
    }

    /// @notice Safely hashes a single bond instruction to avoid collisions
    /// @dev Internal helper to avoid code duplication and prevent hash collisions
    /// @param _instruction The bond instruction to hash
    /// @return The hash of the bond instruction
    function hashBondInstruction(LibBonds.BondInstruction memory _instruction)
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            bytes32(uint256(_instruction.proposalId)),
            bytes32(uint256(uint8(_instruction.bondType))),
            bytes32(uint256(uint160(_instruction.payer))),
            bytes32(uint256(uint160(_instruction.payee)))
        );
    }

    /// @notice Hashes a BondInstructionMessage struct for L2 signaling
    /// @dev Used to signal bond instruction changes to L2 via the signal service
    /// @param _change The bond instruction hash change to hash
    /// @return The hash of the change
    function hashBondInstructionMessage(IInbox.BondInstructionMessage memory _change)
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            bytes32(uint256(_change.startProposalId)),
            bytes32(uint256(_change.endProposalId)),
            _change.aggregatedBondInstructionsHash
        );
    }

    /// @notice Aggregates bond instruction hashes into a rolling hash
    /// @dev Used to track all bond instructions across finalized proposals
    /// @param _aggregatedBondInstructionsHash The current aggregated hash
    /// @param _bondInstructionHash The new bond instruction hash to aggregate
    /// @return The new aggregated hash
    function hashAggregatedBondInstructionsHash(
        bytes32 _aggregatedBondInstructionsHash,
        bytes32 _bondInstructionHash
    )
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(_aggregatedBondInstructionsHash, _bondInstructionHash);
    }

    // ---------------------------------------------------------------
    // Array Hashing Functions
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

    /// @notice Optimized hashing for ProveInput array
    /// @dev Efficiently hashes an array of prove inputs
    /// @param _inputs The prove inputs array to hash
    /// @return The hash of the prove inputs array
    function hashProveInputArray(IInbox.ProveInput[] memory _inputs)
        internal
        pure
        returns (bytes32)
    {
        unchecked {
            uint256 length = _inputs.length;
            if (length == 0) {
                return EMPTY_BYTES_HASH;
            }

            if (length == 1) {
                return EfficientHashLib.hash(bytes32(length), _hashProveInput(_inputs[0]));
            }

            if (length == 2) {
                return EfficientHashLib.hash(
                    bytes32(length), _hashProveInput(_inputs[0]), _hashProveInput(_inputs[1])
                );
            }

            bytes32[] memory buffer = EfficientHashLib.malloc(length + 1);
            EfficientHashLib.set(buffer, 0, bytes32(length));

            for (uint256 i; i < length; ++i) {
                EfficientHashLib.set(buffer, i + 1, _hashProveInput(_inputs[i]));
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
    /// @param _parentTransitionHash Hash of the parent transition
    /// @return The composite key for storage mapping
    function composeTransitionKey(
        uint40 _proposalId,
        bytes27 _parentTransitionHash
    )
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(bytes32(uint256(_proposalId)), bytes32(_parentTransitionHash));
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

    /// @notice Hashes a single ProveInput efficiently
    /// @dev Internal helper to hash ProveInput struct
    /// @param _input The prove input to hash
    /// @return The hash of the prove input
    function _hashProveInput(IInbox.ProveInput memory _input) private pure returns (bytes32) {
        bytes32 proposalHash = hashProposal(_input.proposal);
        bytes32 checkpointHash = hashCheckpoint(_input.checkpoint);
        bytes32 metadataHash = _hashTransitionMetadata(_input.metadata);

        return EfficientHashLib.hash(
            proposalHash, checkpointHash, metadataHash, bytes32(_input.parentTransitionHash)
        );
    }

    /// @notice Hashes a single metadata efficiently
    /// @dev Internal helper to hash metadata struct
    /// @param _metadata The metadata to hash
    /// @return The hash of the metadata
    function _hashTransitionMetadata(IInbox.TransitionMetadata memory _metadata)
        private
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            bytes32(uint256(uint160(_metadata.designatedProver))),
            bytes32(uint256(uint160(_metadata.actualProver)))
        );
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InconsistentLengths();
}
