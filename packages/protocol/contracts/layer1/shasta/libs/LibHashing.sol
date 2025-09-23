// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";
import { IInbox } from "../iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";

/// @title LibHashing
/// @notice Optimized hashing functions using Solady's EfficientHashLib
/// @dev This library provides gas-optimized implementations of all hashing functions
///      used in the Inbox contract, replacing standard keccak256(abi.encode(...)) calls
///      with more efficient alternatives from Solady's EfficientHashLib.
/// @custom:security-contact security@taiko.xyz
library LibHashing {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Precomputed hash of empty bytes for gas optimization
    bytes32 private constant EMPTY_BYTES_HASH = keccak256("");

    // ---------------------------------------------------------------
    // Core Structure Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Optimized hashing for blob hashes array
    /// @dev Uses shared helper for consistent uint16 encoding
    /// @param _blobHashes The blob hashes array to hash
    /// @return The hash of the blob hashes array
    function hashBlobHashesArray(bytes32[] memory _blobHashes) internal pure returns (bytes32) {
        return _encodeAndHashBytes32Array(_blobHashes);
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
            bytes32(uint256(_coreState.nextProposalBlockId)),
            bytes32(uint256(_coreState.lastFinalizedProposalId)),
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

    /// @notice Memory-optimized hashing for arrays of Transitions
    /// @dev Hashes each transition and uses shared helper for uint16 encoding
    /// @param _transitions The transitions array to hash
    /// @return The hash of the transitions array
    function hashTransitionsArray(IInbox.Transition[] memory _transitions)
        internal
        pure
        returns (bytes32)
    {
        unchecked {
            uint256 length = _transitions.length;
            if (length == 0) {
                return EMPTY_BYTES_HASH;
            }

            // Hash each transition into a bytes32 array
            bytes32[] memory hashedTransitions = new bytes32[](length);
            for (uint256 i; i < length; ++i) {
                hashedTransitions[i] = hashTransition(_transitions[i]);
            }

            // Use the shared helper for consistent uint16 encoding
            return _encodeAndHashBytes32Array(hashedTransitions);
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
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(bytes32(uint256(_proposalId)), _parentTransitionHash);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @notice Shared helper function to encode and hash a bytes32 array with uint16 length prefix
    /// @param _array The bytes32 array to encode and hash
    /// @return The hash of the encoded array
    function _encodeAndHashBytes32Array(bytes32[] memory _array) private pure returns (bytes32) {
        unchecked {
            uint256 arrayLength = _array.length;

            // For empty arrays, return the standard empty bytes hash
            if (arrayLength == 0) {
                return EMPTY_BYTES_HASH;
            }

            // Calculate size: 2 bytes for uint16 + 32 bytes per element
            uint256 bufferSize = 2 + (arrayLength * 32);
            bytes memory buffer = new bytes(bufferSize);

            // Encode array length as uint16 using assembly
            assembly {
                let lengthBytes := and(arrayLength, 0xFFFF)
                mstore8(add(buffer, 0x20), shr(8, lengthBytes))
                mstore8(add(buffer, 0x21), lengthBytes)
            }

            // Copy array elements
            for (uint256 i; i < arrayLength; ++i) {
                uint256 destOffset = 2 + (i * 32);
                bytes32 element = _array[i];
                assembly {
                    mstore(add(add(buffer, 0x20), destOffset), element)
                }
            }

            return keccak256(buffer);
        }
    }

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

        return EfficientHashLib.hash(
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
            bytes32(uint256(uint160(_instruction.receiver)))
        );
    }
}
