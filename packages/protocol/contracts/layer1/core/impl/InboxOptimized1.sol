// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { Inbox } from "./Inbox.sol";

import "./InboxOptimized1_Layout.sol"; // DO NOT DELETE

/// @title InboxOptimized1
/// @notice Gas-optimized Inbox implementation with ring buffer storage
/// @dev Key optimizations implemented:
///      - Ring buffer pattern for frequently accessed transition records (reduces SSTORE
/// operations)
///      - Partial parent hash matching to minimize storage slot usage
///      - Optimized memory allocation and reuse patterns
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized1 is Inbox {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Optimized storage for frequently accessed transition records
    /// @dev Stores the first transition record for each proposal to reduce gas costs.
    ///      Uses a ring buffer pattern with proposal ID modulo ring buffer size.
    ///      Uses multiple storage slots for the struct (48 + 26*8 + 26 + 48 = 304 bits)
    struct ReusableTransitionRecord {
        uint48 proposalId;
        bytes26 partialParentTransitionHash;
        TransitionRecordHashAndDeadline hashAndDeadline;
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Storage for default transition records to optimize gas usage
    /// @notice Stores one transition record per buffer slot for gas optimization
    /// @dev Ring buffer implementation with collision handling that falls back to the composite key
    /// mapping from the parent contract
    mapping(uint256 bufferSlot => ReusableTransitionRecord record) internal
        _reusableTransitionRecords;

    uint256[49] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(IInbox.Config memory _config) Inbox(_config) { }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @dev Stores transition record hash with optimized slot reuse.
    ///      Storage strategy:
    ///      1. New proposal ID: overwrite the reusable slot.
    ///      2. Same ID and parent: detect duplicates or conflicts and update accordingly.
    ///      3. Same ID but different parent: fall back to the composite key mapping.
    /// @param _proposalId The proposal ID for this transition record
    /// @param _parentTransitionHash Parent transition hash used as part of the key
    /// @param _hashAndDeadline The finalization metadata to persist
    /// @param _overwrittenByOwner Whether this transaction is called by the owner
    /// @return isOverwrittenByOwner True if the transition was saved by owner overwrite.
    /// @return isDuplicate_ True if this is a duplicate transition (same hash already exists).
    /// @return isConflicting_ True if this is a conflicting transition (different hash for same
    /// key).
    function _storeTransitionRecord(
        uint48 _proposalId,
        bytes32 _parentTransitionHash,
        TransitionRecordHashAndDeadline memory _hashAndDeadline,
        bool _overwrittenByOwner
    )
        internal
        override
        returns (bool isOverwrittenByOwner, bool isDuplicate_, bool isConflicting_)
    {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        ReusableTransitionRecord storage record = _reusableTransitionRecords[bufferSlot];
        // Truncation keeps 208 bits of Keccak security; practical collision risk within the proving
        // horizon is negligible.
        // See ../../../docs/analysis/InboxOptimized1-bytes26-Analysis.md for detailed analysis
        bytes26 partialParentHash = bytes26(_parentTransitionHash);

        if (record.proposalId != _proposalId) {
            // New proposal ID - use reusable slot
            record.proposalId = _proposalId;
            record.partialParentTransitionHash = partialParentHash;
            record.hashAndDeadline = _hashAndDeadline;
        } else if (record.partialParentTransitionHash == partialParentHash) {
            return _updateTransitionRecord(
                record.hashAndDeadline, _hashAndDeadline, _overwrittenByOwner
            );
        } else {
            return super._storeTransitionRecord(
                _proposalId, _parentTransitionHash, _hashAndDeadline, _overwrittenByOwner
            );
        }
    }

    // ---------------------------------------------------------------
    // Internal View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @dev Optimized retrieval using ring buffer with collision detection.
    ///      Lookup strategy (gas-optimized order):
    ///      1. Ring buffer slot lookup (single SLOAD).
    ///      2. Proposal ID verification (cached in memory).
    ///      3. Partial parent hash comparison (single comparison).
    ///      4. Fallback to composite key mapping (most expensive).
    /// @param _proposalId The proposal ID to look up
    /// @param _parentTransitionHash Parent transition hash for verification
    /// @return recordHash_ The hash of the transition record
    /// @return finalizationDeadline_ The finalization deadline for the transition
    function _getTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        override
        returns (bytes26 recordHash_, uint48 finalizationDeadline_)
    {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        ReusableTransitionRecord storage record = _reusableTransitionRecords[bufferSlot];

        if (record.proposalId != _proposalId) {
            return (0, 0);
        } else if (record.partialParentTransitionHash == bytes26(_parentTransitionHash)) {
            return (record.hashAndDeadline.recordHash, record.hashAndDeadline.finalizationDeadline);
        } else {
            return super._getTransitionRecordHashAndDeadline(_proposalId, _parentTransitionHash);
        }
    }
}
