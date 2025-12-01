// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox2 } from "../iface/IInbox2.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibHashSimple2
/// @notice Simple hashing functions using standard keccak256(abi.encode(...))
/// @dev This library provides standard implementations of all hashing functions
///      used in the Inbox contract, using the original keccak256(abi.encode(...)) pattern
///      from the base Inbox.sol implementation.
/// @custom:security-contact security@taiko.xyz
library LibHashSimple2 {
    // ---------------------------------------------------------------
    // Core Structure Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Simple hashing for blob hashes array
    /// @dev Uses standard keccak256(abi.encode(...)) for the blob hashes array
    /// @param _blobHashes The blob hashes array to hash
    /// @return The hash of the blob hashes array
    function hashBlobHashesArray(bytes32[] memory _blobHashes) internal pure returns (bytes32) {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_blobHashes));
    }

    /// @notice Simple hashing for Checkpoint structs
    /// @dev Uses standard keccak256(abi.encode(...)) for the checkpoint
    /// @param _checkpoint The checkpoint to hash
    /// @return The hash of the checkpoint
    function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        returns (bytes32)
    {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_checkpoint));
    }

    /// @notice Simple hashing for CoreState structs
    /// @dev Uses standard keccak256(abi.encode(...)) for the core state
    /// @param _coreState The core state to hash
    /// @return The hash of the core state
    function hashCoreState(IInbox2.CoreState memory _coreState) internal pure returns (bytes32) {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_coreState));
    }

    /// @notice Simple hashing for Derivation structs
    /// @dev Uses standard keccak256(abi.encode(...)) for the derivation
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivation(IInbox2.Derivation memory _derivation) internal pure returns (bytes32) {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_derivation));
    }

    /// @notice Simple hashing for Proposal structs
    /// @dev Uses standard keccak256(abi.encode(...)) for the proposal
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox2.Proposal memory _proposal) internal pure returns (bytes32) {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_proposal));
    }

    /// @notice Simple hashing for Transition structs
    /// @dev Uses standard keccak256(abi.encode(...)) for the transition
    /// @param _transition The transition to hash
    /// @return The hash of the transition
    function hashTransition(IInbox2.Transition memory _transition) internal pure returns (bytes32) {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_transition));
    }

    /// @notice Simple hashing for TransitionRecord structs
    /// @dev Uses standard keccak256(abi.encode(...)) for the transition record
    /// @param _transitionRecord The transition record to hash
    /// @return The hash truncated to bytes26 for storage optimization
    function hashTransitionRecord(IInbox2.TransitionRecord memory _transitionRecord)
        internal
        pure
        returns (bytes26)
    {
        /// forge-lint: disable-next-line(asm-keccak256)
        return bytes26(keccak256(abi.encode(_transitionRecord)));
    }

    /// @notice Simple hashing for arrays of Transitions with metadata
    /// @dev Uses standard keccak256(abi.encode(...)) for the transitions array
    /// @param _transitions The transitions array to hash
    /// @param _proofMetadata The proof metadata array to hash
    /// @return The hash of the transitions array
    function hashTransitionsWithMetadata(
        IInbox2.Transition[] memory _transitions,
        IInbox2.ProofMetadata[] memory _proofMetadata
    )
        internal
        pure
        returns (bytes32)
    {
        require(_transitions.length == _proofMetadata.length, InconsistentLengths());
        bytes32[] memory transitionHashes = new bytes32[](_transitions.length);

        for (uint256 i; i < _transitions.length; ++i) {
            transitionHashes[i] = keccak256(
                abi.encodePacked(
                    hashTransition(_transitions[i]),
                    _proofMetadata[i].designatedProver,
                    _proofMetadata[i].actualProver
                )
            );
        }
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(transitionHashes));
    }

    // ---------------------------------------------------------------
    // Utility Functions
    // ---------------------------------------------------------------

    /// @notice Computes simple composite key for transition record storage
    /// @dev Creates unique identifier using standard keccak256(abi.encode(...))
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
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_proposalId, _parentTransitionHash));
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InconsistentLengths();
}
