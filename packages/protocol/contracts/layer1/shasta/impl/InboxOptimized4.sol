// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { Inbox } from "./Inbox.sol";
import { InboxOptimized3 } from "./InboxOptimized3.sol";
import { LibHashing } from "../libs/LibHashing.sol";

/// @title InboxOptimized4
/// @notice Fourth optimization layer focusing on efficient hashing operations
/// @dev Key optimizations:
///      - Uses LibHashing library for optimized struct hashing operations
///      - Maintains all optimizations from InboxOptimized1, InboxOptimized2, and InboxOptimized3
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized4 is InboxOptimized3 {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(IInbox.Config memory _config) InboxOptimized3(_config) { }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

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
}
