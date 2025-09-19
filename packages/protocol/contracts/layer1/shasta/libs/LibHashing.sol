// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";
import { IInbox } from "../iface/IInbox.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

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

    /// @notice Optimized hashing for Checkpoint structs
    /// @dev Efficiently hashes the 3 main fields of a checkpoint
    /// @param _checkpoint The checkpoint to hash
    /// @return The hash of the checkpoint
    function hashCheckpoint(ICheckpointManager.Checkpoint memory _checkpoint)
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

    /// @notice Optimized hashing for Derivation structs
    /// @dev Efficiently packs derivation fields before hashing
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivation(IInbox.Derivation memory _derivation) internal pure returns (bytes32) {
        // Pack origin block number, forced inclusion flag, and basefee sharing percentage
        bytes32 packedFields = bytes32(
            (uint256(_derivation.originBlockNumber) << 208)
                | (uint256(_derivation.isForcedInclusion ? 1 : 0) << 200)
                | (uint256(_derivation.basefeeSharingPctg) << 192)
        );

        // Hash blob slice fields - BlobSlice has blobHashes array, offset, and timestamp
        // Explicitly include blobHashes array length to prevent collisions
        bytes32 blobHashesHash;
        if (_derivation.blobSlice.blobHashes.length == 0) {
            blobHashesHash = EMPTY_BYTES_HASH;
        } else {
            // Memory-optimized approach: pre-allocate buffer for length + hashes
            uint256 arrayLength = _derivation.blobSlice.blobHashes.length;
            uint256 bufferSize = 32 + (arrayLength * 32);
            bytes memory buffer = new bytes(bufferSize);

            assembly {
                // Write array length at start of buffer
                mstore(add(buffer, 0x20), arrayLength)
            }

            // Write each blob hash directly to buffer
            for (uint256 i; i < arrayLength; ++i) {
                bytes32 blobHash = _derivation.blobSlice.blobHashes[i];
                assembly {
                    let offset := add(0x40, mul(i, 0x20)) // 0x20 for bytes length + 0x20 for array
                        // length + i*32
                    mstore(add(buffer, offset), blobHash)
                }
            }

            // Use assembly keccak256
            assembly {
                blobHashesHash := keccak256(add(buffer, 0x20), mload(buffer))
            }
        }

        bytes32 blobSliceHash = EfficientHashLib.hash(
            blobHashesHash,
            bytes32(uint256(_derivation.blobSlice.offset)),
            bytes32(uint256(_derivation.blobSlice.timestamp))
        );

        return EfficientHashLib.hash(packedFields, _derivation.originBlockHash, blobSliceHash);
    }

    // ---------------------------------------------------------------
    // Array and Complex Structure Hashing Functions
    // ---------------------------------------------------------------

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

        // For small arrays (most common case), use direct hashing with length
        if (_transitions.length == 1) {
            return EfficientHashLib.hash(
                bytes32(uint256(_transitions.length)), hashTransition(_transitions[0])
            );
        }

        if (_transitions.length == 2) {
            return EfficientHashLib.hash(
                bytes32(uint256(_transitions.length)),
                hashTransition(_transitions[0]),
                hashTransition(_transitions[1])
            );
        }

        // For larger arrays, use memory-optimized approach
        // Pre-allocate exact buffer size: 32 bytes for length + 32 bytes per hash
        uint256 arrayLength = _transitions.length;
        uint256 bufferSize = 32 + (arrayLength * 32);
        bytes memory buffer = new bytes(bufferSize);

        assembly {
            // Write array length at start of buffer
            mstore(add(buffer, 0x20), arrayLength)
        }

        // Write each transition hash directly to buffer
        for (uint256 i; i < arrayLength; ++i) {
            bytes32 transitionHash = hashTransition(_transitions[i]);
            assembly {
                let offset := add(0x40, mul(i, 0x20)) // 0x20 for bytes length + 0x20 for array
                    // length + i*32
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

    /// @notice Optimized hashing for TransitionRecord structs
    /// @dev Efficiently hashes transition records with variable-length bond instructions
    /// @param _transitionRecord The transition record to hash
    /// @return The hash truncated to bytes26 for storage optimization
    function hashTransitionRecord(IInbox.TransitionRecord memory _transitionRecord)
        internal
        pure
        returns (bytes26)
    {
        // Hash bond instructions efficiently with explicit length inclusion
        bytes32 bondInstructionsHash;
        if (_transitionRecord.bondInstructions.length == 0) {
            bondInstructionsHash = EMPTY_BYTES_HASH;
        } else if (_transitionRecord.bondInstructions.length == 1) {
            bondInstructionsHash = EfficientHashLib.hash(
                bytes32(uint256(_transitionRecord.bondInstructions.length)),
                _hashSingleBondInstruction(_transitionRecord.bondInstructions[0])
            );
        } else {
            // Memory-optimized approach for multiple instructions
            // Pre-allocate buffer: 32 bytes for length + 32 bytes per instruction hash
            uint256 arrayLength = _transitionRecord.bondInstructions.length;
            uint256 bufferSize = 32 + (arrayLength * 32);
            bytes memory buffer = new bytes(bufferSize);

            assembly {
                // Write array length at start of buffer
                mstore(add(buffer, 0x20), arrayLength)
            }

            // Write each bond instruction hash directly to buffer
            for (uint256 i; i < arrayLength; ++i) {
                bytes32 instructionHash =
                    _hashSingleBondInstruction(_transitionRecord.bondInstructions[i]);
                assembly {
                    let offset := add(0x40, mul(i, 0x20)) // 0x20 for bytes length + 0x20 for array
                        // length + i*32
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

    // ---------------------------------------------------------------
    // Unoptimized Versions (Reference Implementations)
    // ---------------------------------------------------------------

    /// @notice Unoptimized reference implementation for Transition hashing
    /// @dev Uses standard keccak256(abi.encode(...)) - kept for comparison and testing
    /// @param _transition The transition to hash
    /// @return The hash of the transition
    function hashTransitionUnoptimized(IInbox.Transition memory _transition) internal pure returns (bytes32) {
        return keccak256(abi.encode(_transition));
    }

    /// @notice Unoptimized reference implementation for Checkpoint hashing
    /// @dev Uses standard keccak256(abi.encode(...)) - kept for comparison and testing
    /// @param _checkpoint The checkpoint to hash
    /// @return The hash of the checkpoint
    function hashCheckpointUnoptimized(ICheckpointManager.Checkpoint memory _checkpoint)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_checkpoint));
    }

    /// @notice Unoptimized reference implementation for CoreState hashing
    /// @dev Uses standard keccak256(abi.encode(...)) - kept for comparison and testing
    /// @param _coreState The core state to hash
    /// @return The hash of the core state
    function hashCoreStateUnoptimized(IInbox.CoreState memory _coreState) internal pure returns (bytes32) {
        return keccak256(abi.encode(_coreState));
    }

    /// @notice Unoptimized reference implementation for Proposal hashing
    /// @dev Uses standard keccak256(abi.encode(...)) - kept for comparison and testing
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposalUnoptimized(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        return keccak256(abi.encode(_proposal));
    }

    /// @notice Unoptimized reference implementation for Derivation hashing
    /// @dev Uses standard keccak256(abi.encode(...)) - kept for comparison and testing
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivationUnoptimized(IInbox.Derivation memory _derivation)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_derivation));
    }

    /// @notice Unoptimized reference implementation for transitions array hashing
    /// @dev Uses standard keccak256(abi.encode(...)) - kept for comparison and testing
    /// @param _transitions The transitions array to hash
    /// @return The hash of the transitions array
    function hashTransitionsArrayUnoptimized(IInbox.Transition[] memory _transitions)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_transitions));
    }

    /// @notice Unoptimized reference implementation for TransitionRecord hashing
    /// @dev Uses standard keccak256(abi.encode(...)) - kept for comparison and testing
    /// @param _transitionRecord The transition record to hash
    /// @return The hash truncated to bytes26
    function hashTransitionRecordUnoptimized(IInbox.TransitionRecord memory _transitionRecord)
        internal
        pure
        returns (bytes26)
    {
        return bytes26(keccak256(abi.encode(_transitionRecord)));
    }

    /// @notice Unoptimized reference implementation for transition key composition
    /// @dev Uses standard keccak256(abi.encodePacked(...)) - kept for comparison and testing
    /// @param _proposalId The ID of the proposal
    /// @param _parentTransitionHash Hash of the parent transition
    /// @return The composite key for storage mapping
    function composeTransitionKeyUnoptimized(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("TRANSITION_RECORD", _proposalId, _parentTransitionHash));
    }
}
