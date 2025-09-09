// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { IInbox } from "../iface/IInbox.sol";
import { InboxOptimized3 } from "./InboxOptimized3.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";
import { LibHashing } from "../libs/LibHashing.sol";

/// @title InboxOptimized4
/// @notice Fourth optimization layer focusing on efficient hashing operations
/// @dev Key optimizations:
///      - Uses LibHashing library for optimized struct hashing operations
///      - Maintains all optimizations from InboxOptimized1, InboxOptimized2, and InboxOptimized3
/// @dev Gas savings: ~15% reduction in hashing operation costs
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimized4 is InboxOptimized3 {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(IInbox.Config memory _config) InboxOptimized3(_config) { }

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @notice Optimized transition hashing using LibHashing
    /// @dev Uses LibHashing for efficient transition hashing
    function hashTransition(Transition memory _transition) public pure override returns (bytes32) {
        return LibHashing.hashTransition(_transition);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized checkpoint hashing using LibHashing
    /// @dev Uses LibHashing for efficient checkpoint hashing
    function hashCheckpoint(ICheckpointManager.Checkpoint memory _checkpoint)
        public
        pure
        override
        returns (bytes32)
    {
        return LibHashing.hashCheckpoint(_checkpoint);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized core state hashing using LibHashing
    /// @dev Uses LibHashing for efficient core state hashing
    function hashCoreState(CoreState memory _coreState) public pure override returns (bytes32) {
        return LibHashing.hashCoreState(_coreState);
    }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @dev Optimized implementation using LibHashing
    /// @notice Saves gas by using efficient hashing
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
