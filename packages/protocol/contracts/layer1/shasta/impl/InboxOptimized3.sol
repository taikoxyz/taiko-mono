// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { Inbox } from "./Inbox.sol";
import { InboxOptimized2 } from "./InboxOptimized2.sol";
import { LibHashing } from "../libs/LibHashing.sol";

/// @title InboxOptimized3
/// @notice Third optimization layer focusing on efficient hashing operations
/// @dev Key optimizations:
///      - Uses LibHashing library for optimized struct hashing operations
///      - Maintains all optimizations from InboxOptimized1 and InboxOptimized2
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized3 is InboxOptimized2 {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(IInbox.Config memory _config) InboxOptimized2(_config) { }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------
    /// @inheritdoc Inbox
    /// @dev Optimized implementation using LibHashing
    /// @notice Uses efficient hashing for composite key generation
    /// @param _proposalId The proposal ID
    /// @param _parentTransitionHash The parent transition hash
    /// @return bytes32 The composite key for storage mapping
    function _composeTransitionKey(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.composeTransitionKey(_proposalId, _parentTransitionHash);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized blob hashes array hashing using LibHashing
    /// @dev Uses LibHashing for efficient blob hashes array hashing
    /// @param _blobHashes The blob hashes array to hash
    /// @return bytes32 The keccak256 hash of the blob hashes array
    function _hashBlobHashesArray(bytes32[] memory _blobHashes)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashBlobHashesArray(_blobHashes);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized checkpoint hashing using LibHashing
    /// @dev Uses LibHashing for efficient checkpoint hashing
    /// @param _checkpoint The checkpoint data to hash
    /// @return bytes32 The keccak256 hash of the checkpoint struct
    function _hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashCheckpoint(_checkpoint);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized core state hashing using LibHashing
    /// @dev Uses LibHashing for efficient core state hashing
    /// @param _coreState The core state data to hash
    /// @return bytes32 The keccak256 hash of the core state struct
    function _hashCoreState(CoreState memory _coreState) internal pure override returns (bytes32) {
        return LibHashing.hashCoreState(_coreState);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized derivation hashing using LibHashing
    /// @dev Uses LibHashing for efficient derivation hashing
    /// @param _derivation The derivation data to hash
    /// @return bytes32 The keccak256 hash of the derivation struct
    function _hashDerivation(Derivation memory _derivation)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashDerivation(_derivation);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized proposal hashing using LibHashing
    /// @dev Uses LibHashing for efficient proposal hashing
    /// @param _proposal The proposal data to hash
    /// @return bytes32 The keccak256 hash of the proposal struct
    function _hashProposal(Proposal memory _proposal) internal pure override returns (bytes32) {
        return LibHashing.hashProposal(_proposal);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized transition hashing using LibHashing
    /// @dev Uses LibHashing for efficient transition hashing
    /// @param _transition The transition data to hash
    /// @return bytes32 The keccak256 hash of the transition struct
    function _hashTransition(Transition memory _transition)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashTransition(_transition);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized transition record hashing using LibHashing
    /// @dev Uses LibHashing for efficient transition record hashing
    /// @param _transitionRecord The transition record to hash
    /// @return bytes26 The truncated keccak256 hash of the transition record
    function _hashTransitionRecord(TransitionRecord memory _transitionRecord)
        internal
        pure
        override
        returns (bytes26)
    {
        return LibHashing.hashTransitionRecord(_transitionRecord);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized transitions array hashing using LibHashing
    /// @dev Uses LibHashing for efficient array hashing
    /// @param _transitions The transitions array to hash
    /// @return bytes32 The keccak256 hash of the transitions array
    function _hashTransitionsArray(Transition[] memory _transitions)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashTransitionsArray(_transitions);
    }
}
