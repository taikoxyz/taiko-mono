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
    /// @dev Efficiently hashes an array of blob hashes with explicit length inclusion
    /// @param _blobHashes The blob hashes array to hash
    /// @return The hash of the blob hashes array
    function hashBlobHashesArray(bytes32[] memory _blobHashes) internal pure returns (bytes32) {
        if (_blobHashes.length == 0) {
            return EMPTY_BYTES_HASH;
        }

        // Always use the shared helper to ensure consistent uint16 encoding for array length
        // This matches LibProposedEventEncoder's use of uint16 for array lengths
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
        bytes32 packedFields = bytes32(
            (uint256(_derivation.originBlockNumber) << 208)
                | (uint256(_derivation.basefeeSharingPctg) << 192)
        );

        // Hash the sources array - each source contains isForcedInclusion flag and blobSlice
        bytes32 sourcesHash;
        if (_derivation.sources.length == 0) {
            sourcesHash = EMPTY_BYTES_HASH;
        } else {
            // Pre-allocate buffer for sources array length (uint16) + source hashes
            uint256 arrayLength = _derivation.sources.length;
            // Use 2 bytes for length (uint16) to match LibProposedEventEncoder
            uint256 bufferSize = 2 + (arrayLength * 32);
            bytes memory buffer = new bytes(bufferSize);

            assembly {
                // Write array length as uint16 (2 bytes) at start of buffer
                // This matches LibProposedEventEncoder's use of uint16 for array lengths
                let lengthBytes := and(arrayLength, 0xFFFF) // Ensure it fits in uint16
                mstore8(add(buffer, 0x20), shr(8, lengthBytes)) // byte 0 (high byte)
                mstore8(add(buffer, 0x21), lengthBytes) // byte 1 (low byte)
            }

            // Write each source hash directly to buffer
            for (uint256 i; i < arrayLength; ++i) {
                bytes32 sourceHash = _hashDerivationSource(_derivation.sources[i]);
                assembly {
                    // Offset: 0x20 (bytes length) + 0x02 (uint16 array length) + i*32
                    let offset := add(0x22, mul(i, 0x20))
                    mstore(add(buffer, offset), sourceHash)
                }
            }

            // Use assembly keccak256
            assembly {
                sourcesHash := keccak256(add(buffer, 0x20), mload(buffer))
            }
        }

        return EfficientHashLib.hash(packedFields, _derivation.originBlockHash, sourcesHash);
    }

    /// @notice Optimized hashing for Proposal structs
    /// @dev Uses efficient multi-field hashing for all proposal fields
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        // Use separate field packing to avoid address truncation
        // Pack numeric fields together
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
        // Hash bond instructions with uint16 length encoding to match LibProposeInputDecoder
        bytes32 bondInstructionsHash;
        if (_transitionRecord.bondInstructions.length == 0) {
            bondInstructionsHash = EMPTY_BYTES_HASH;
        } else {
            // Use consistent uint16 encoding for array length
            // Pre-allocate buffer: 2 bytes for uint16 length + 32 bytes per instruction hash
            uint256 arrayLength = _transitionRecord.bondInstructions.length;
            uint256 bufferSize = 2 + (arrayLength * 32);
            bytes memory buffer = new bytes(bufferSize);

            assembly {
                // Write array length as uint16 (2 bytes) at start of buffer
                // This matches LibProposeInputDecoder's use of uint16 for array lengths
                let lengthBytes := and(arrayLength, 0xFFFF) // Ensure it fits in uint16
                mstore8(add(buffer, 0x20), shr(8, lengthBytes)) // byte 0 (high byte)
                mstore8(add(buffer, 0x21), lengthBytes) // byte 1 (low byte)
            }

            // Write each bond instruction hash directly to buffer
            for (uint256 i; i < arrayLength; ++i) {
                bytes32 instructionHash =
                    _hashSingleBondInstruction(_transitionRecord.bondInstructions[i]);
                assembly {
                    // Offset: 0x20 (bytes length) + 0x02 (uint16 array length) + i*32
                    let offset := add(0x22, mul(i, 0x20))
                    mstore(add(buffer, offset), instructionHash)
                }
            }

            // Use assembly keccak256
            assembly {
                bondInstructionsHash := keccak256(add(buffer, 0x20), mload(buffer))
            }
        }

        bytes32 fullHash = EfficientHashLib.hash(
            bytes32(uint256(_transitionRecord.span)),
            bondInstructionsHash,
            _transitionRecord.transitionHash,
            _transitionRecord.checkpointHash
        );

        return bytes26(fullHash);
    }

    /// @notice Memory-optimized hashing for arrays of Transitions
    /// @dev Pre-allocates buffer to avoid reallocations and uses assembly for efficiency
    /// @dev Explicitly includes array length to prevent hash collisions
    /// @param _transitions The transitions array to hash
    /// @return The hash of the transitions array
    function hashTransitionsArray(IInbox.Transition[] memory _transitions)
        internal
        pure
        returns (bytes32)
    {
        if (_transitions.length == 0) {
            return EMPTY_BYTES_HASH;
        }

        // Use consistent uint16 encoding for array length
        // Pre-allocate buffer: 2 bytes for uint16 length + 32 bytes per hash
        uint256 arrayLength = _transitions.length;
        uint256 bufferSize = 2 + (arrayLength * 32);
        bytes memory buffer = new bytes(bufferSize);

        assembly {
            // Write array length as uint16 (2 bytes) at start of buffer
            // This matches LibProveInputDecoder's use of uint16 for array lengths
            let lengthBytes := and(arrayLength, 0xFFFF) // Ensure it fits in uint16
            mstore8(add(buffer, 0x20), shr(8, lengthBytes)) // byte 0 (high byte)
            mstore8(add(buffer, 0x21), lengthBytes) // byte 1 (low byte)
        }

        // Write each transition hash directly to buffer
        for (uint256 i; i < arrayLength; ++i) {
            bytes32 transitionHash = hashTransition(_transitions[i]);
            assembly {
                // Offset: 0x20 (bytes length) + 0x03 (uint24 array length) + i*32
                let offset := add(0x23, mul(i, 0x20))
                mstore(add(buffer, offset), transitionHash)
            }
        }

        // Use assembly keccak256 for final optimization
        bytes32 result;
        assembly {
            result := keccak256(add(buffer, 0x20), mload(buffer))
        }
        return result;
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
        return EfficientHashLib.hash(uint256(_proposalId), uint256(_parentTransitionHash));
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @notice Efficiently encodes and hashes a bytes32 array with its length
    /// @dev Shared helper to avoid code duplication and potential bugs
    /// @dev Uses uint16 for array length to match encoding format in LibProposedEventEncoder
    /// @param _array The bytes32 array to encode and hash
    /// @return The keccak256 hash of the encoded array (length + elements)
    function _encodeAndHashBytes32Array(bytes32[] memory _array) private pure returns (bytes32) {
        uint256 arrayLength = _array.length;
        // Use 2 bytes for length (uint16) + array elements to match encoding format
        uint256 bufferSize = 2 + (arrayLength * 32);
        bytes memory buffer = new bytes(bufferSize);

        assembly {
            // Write array length as uint16 (2 bytes) at start of buffer
            // This matches LibProposedEventEncoder's use of uint16 for array lengths
            let lengthBytes := and(arrayLength, 0xFFFF) // Ensure it fits in uint16
            mstore8(add(buffer, 0x20), shr(8, lengthBytes)) // byte 0 (high byte)
            mstore8(add(buffer, 0x21), lengthBytes) // byte 1 (low byte)
        }

        // Write each element directly to buffer
        for (uint256 i; i < arrayLength; ++i) {
            bytes32 element = _array[i];
            assembly {
                // Offset: 0x20 (bytes length) + 0x03 (uint24 array length) + i*32
                let offset := add(0x23, mul(i, 0x20))
                mstore(add(buffer, offset), element)
            }
        }

        // Use assembly keccak256 for final optimization
        bytes32 result;
        assembly {
            result := keccak256(add(buffer, 0x20), mload(buffer))
        }
        return result;
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
        bytes32 blobHashesHash;
        if (_source.blobSlice.blobHashes.length == 0) {
            blobHashesHash = EMPTY_BYTES_HASH;
        } else {
            // Use shared helper to encode and hash blob hashes array
            blobHashesHash = _encodeAndHashBytes32Array(_source.blobSlice.blobHashes);
        }

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
