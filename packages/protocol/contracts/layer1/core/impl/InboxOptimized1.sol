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

    /// @dev Stores the first transition record for each proposal to reduce gas costs.
    ///      Uses a ring buffer pattern with proposal ID modulo ring buffer size.
    ///      Uses multiple storage slots for the struct (48 + 26*8 + 26 + 48 = 304 bits)
    struct FirstTransitionRecord {
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
    mapping(uint256 bufferSlot => FirstTransitionRecord firstRecord) internal
        _firstTransitionRecord;

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
    ///      2. Same ID and parent: update accordingly.
    ///      3. Same ID but different parent: fall back to the composite key mapping.
    /// @param _proposalId The proposal ID for this transition record
    /// @param _parentTransitionHash Parent transition hash used as part of the key
    /// @param _hashAndDeadline The finalization metadata to persist
    function _storeTransitionRecord(
        uint48 _proposalId,
        bytes32 _parentTransitionHash,
        TransitionRecordHashAndDeadline memory _hashAndDeadline
    )
        internal
        override
    {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        FirstTransitionRecord storage firstRecord = _firstTransitionRecord[bufferSlot];
        // Truncation keeps 208 bits of Keccak security; practical collision risk within the proving
        // horizon is negligible.
        // See ../../../docs/analysis/InboxOptimized1-bytes26-Analysis.md for detailed analysis
        bytes26 partialParentHash = bytes26(_parentTransitionHash);

        if (firstRecord.proposalId != _proposalId) {
            // New proposal ID - use reusable slot
            firstRecord.proposalId = _proposalId;
            firstRecord.partialParentTransitionHash = partialParentHash;
            firstRecord.hashAndDeadline = _hashAndDeadline;
        } else if (firstRecord.partialParentTransitionHash == partialParentHash) {
            _storeTransitionRecord(
                firstRecord.hashAndDeadline,
                _hashAndDeadline
            );
        } else {
            super._storeTransitionRecord(
                _proposalId, _parentTransitionHash, _hashAndDeadline
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
    function _loadTransitionRecord(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        override
        returns (bytes26 recordHash_, uint48 finalizationDeadline_)
    {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        FirstTransitionRecord storage firstRecord = _firstTransitionRecord[bufferSlot];

        if (firstRecord.proposalId != _proposalId) {
            return (0, 0);
        } else if (firstRecord.partialParentTransitionHash == bytes26(_parentTransitionHash)) {
            return (
                firstRecord.hashAndDeadline.recordHash,
                firstRecord.hashAndDeadline.finalizationDeadline
            );
        } else {
            return super._loadTransitionRecord(_proposalId, _parentTransitionHash);
        }
    }
}
