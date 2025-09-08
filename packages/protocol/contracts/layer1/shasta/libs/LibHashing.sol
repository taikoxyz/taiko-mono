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
/// @dev Key optimizations:
///      - Uses EfficientHashLib for multi-argument hashing with reduced gas costs
///      - Optimizes struct field ordering for better packing
///      - Minimizes memory allocations and ABI encoding overhead
/// @custom:security-contact security@taiko.xyz
library LibHashing {
    using EfficientHashLib for *;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Precomputed hash of empty bytes for gas optimization
    bytes32 private constant EMPTY_BYTES_HASH = keccak256("");

    // ---------------------------------------------------------------
    // Core Structure Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Optimized hashing for Transition structs
    /// @dev Uses EfficientHashLib for efficient 2-field hashing
    /// @param _transition The transition to hash
    /// @return The hash of the transition
    function hashTransition(IInbox.Transition memory _transition) internal pure returns (bytes32) {
        return EfficientHashLib.hash(_transition.proposalHash, _transition.parentTransitionHash);
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
            bytes32(uint256(_checkpoint.blockNumber)),
            _checkpoint.blockHash,
            _checkpoint.stateRoot
        );
    }

    /// @notice Optimized hashing for CoreState structs
    /// @dev Efficiently packs and hashes all core state fields
    /// @param _coreState The core state to hash
    /// @return The hash of the core state
    function hashCoreState(IInbox.CoreState memory _coreState) internal pure returns (bytes32) {
        return EfficientHashLib.hash(
            bytes32(uint256(_coreState.nextProposalId)),
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
        // Pack the timestamp fields and proposer address efficiently
        bytes32 packedFields1 = bytes32(
            (uint256(_proposal.id) << 208) | (uint256(_proposal.timestamp) << 160)
                | (uint256(_proposal.lookaheadSlotTimestamp) << 112)
                | uint256(uint160(_proposal.proposer))
        );

        return EfficientHashLib.hash(
            packedFields1, _proposal.coreStateHash, _proposal.derivationHash
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
        bytes32 blobSliceHash = EfficientHashLib.hash(
            keccak256(abi.encodePacked(_derivation.blobSlice.blobHashes)),
            bytes32(uint256(_derivation.blobSlice.offset)),
            bytes32(uint256(_derivation.blobSlice.timestamp))
        );

        return EfficientHashLib.hash(
            packedFields, _derivation.originBlockHash, blobSliceHash
        );
    }

    // ---------------------------------------------------------------
    // Array and Complex Structure Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Optimized hashing for arrays of Transitions
    /// @dev Uses more efficient approach than standard abi.encode for arrays
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

        // For small arrays (most common case), use direct hashing
        if (_transitions.length == 1) {
            return hashTransition(_transitions[0]);
        }

        if (_transitions.length == 2) {
            return EfficientHashLib.hash(
                hashTransition(_transitions[0]), hashTransition(_transitions[1])
            );
        }

        // For larger arrays, fall back to optimized encoding
        bytes memory encoded;
        for (uint256 i; i < _transitions.length; ++i) {
            encoded = abi.encodePacked(encoded, hashTransition(_transitions[i]));
        }
        return keccak256(encoded);
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
        // Hash bond instructions efficiently
        bytes32 bondInstructionsHash;
        if (_transitionRecord.bondInstructions.length == 0) {
            bondInstructionsHash = EMPTY_BYTES_HASH;
        } else if (_transitionRecord.bondInstructions.length == 1) {
            bondInstructionsHash = _hashSingleBondInstruction(_transitionRecord.bondInstructions[0]);
        } else {
            // For multiple instructions, use packed encoding
            bytes memory encoded;
            for (uint256 i; i < _transitionRecord.bondInstructions.length; ++i) {
                encoded = abi.encodePacked(
                    encoded, _hashSingleBondInstruction(_transitionRecord.bondInstructions[i])
                );
            }
            bondInstructionsHash = keccak256(encoded);
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
    function composeTransitionKey(uint48 _proposalId, bytes32 _parentTransitionHash)
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
}