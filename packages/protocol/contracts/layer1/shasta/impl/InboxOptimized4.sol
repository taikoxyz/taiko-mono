// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { IInbox } from "../iface/IInbox.sol";
import { InboxOptimized3 } from "./InboxOptimized3.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";

/// @title InboxOptimized4
/// @notice Fourth optimization layer focusing on efficient hashing operations
/// @dev Key optimizations:
///      - Efficient hashing using Solady's EfficientHashLib for struct hashing operations
///      - Optimized hash computations for transitions, checkpoints, and core state
///      - Reduced gas costs for frequently called hashing functions
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
    /// @notice Optimized transition hashing using EfficientHashLib
    /// @dev Hashes a single Transition struct (2 bytes32 fields)
    function hashTransition(Transition memory _transition) public pure override returns (bytes32) {
        return EfficientHashLib.hash(_transition.proposalHash, _transition.parentTransitionHash);
    }

    /// @inheritdoc Inbox
    /// @notice Optimized checkpoint hashing using EfficientHashLib
    /// @dev Efficiently hashes Checkpoint struct
    function hashCheckpoint(ICheckpointManager.Checkpoint memory _checkpoint)
        public
        pure
        override
        returns (bytes32)
    {
        // Checkpoint has: blockNumber, blockHash, stateRoot
        return EfficientHashLib.hash(
            bytes32(uint256(_checkpoint.blockNumber)), _checkpoint.blockHash, _checkpoint.stateRoot
        );
    }

    /// @inheritdoc Inbox
    /// @notice Optimized core state hashing using EfficientHashLib
    /// @dev Efficiently hashes a CoreState struct
    function hashCoreState(CoreState memory _coreState) public pure override returns (bytes32) {
        // CoreState: nextProposalId, lastFinalizedProposalId, lastFinalizedTransitionHash,
        // bondInstructionsHash
        return EfficientHashLib.hash(
            bytes32(uint256(_coreState.nextProposalId)),
            bytes32(uint256(_coreState.lastFinalizedProposalId)),
            _coreState.lastFinalizedTransitionHash,
            _coreState.bondInstructionsHash
        );
    }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @dev Optimized implementation using EfficientHashLib
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
        return EfficientHashLib.hash(uint256(_proposalId), uint256(_parentTransitionHash));
    }
}
