// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox2 } from "../iface/IInbox2.sol";
import { LibBonds2 } from "src/shared/libs/LibBonds2.sol";
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

    function hashProveInputArray(IInbox2.ProveInput[] memory _inputs)
        internal
        pure
        returns (bytes32)
    {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_inputs));
    }

    /// @notice Simple hashing for BondInstruction array
    /// @dev Uses standard keccak256(abi.encode(...)) for the bond instructions
    /// @param _bondInstructions The bond instructions array to hash
    /// @return The hash of the bond instructions
    function hashBondInstructions(LibBonds2.BondInstruction[] memory _bondInstructions)
        internal
        pure
        returns (bytes32)
    {
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(_bondInstructions));
    }

    /// @notice Simple hashing for TransitionRecord structs
    /// @dev Uses standard keccak256(abi.encode(...)) for the transition record
    /// @param _transition The transition to hash
    /// @return The hash truncated to bytes26 for storage optimization
    function hashTransition(IInbox2.Transition memory _transition) internal pure returns (bytes26) {
        /// forge-lint: disable-next-line(asm-keccak256)
        return bytes26(keccak256(abi.encode(_transition)));
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
