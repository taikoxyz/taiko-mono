// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox2 } from "../iface/IInbox2.sol";
import { Inbox2 } from "./Inbox2.sol";

import "./InboxOptimized1_Layout.sol"; // DO NOT DELETE

/// @title InboxOptimized1
/// @notice Gas-optimized Inbox implementation with ring buffer storage
/// @dev Key optimizations implemented:
///      - Ring buffer pattern for frequently accessed transition records (reduces SSTORE
/// operations)
///      - Partial parent hash matching to minimize storage slot usage
///      - Optimized memory allocation and reuse patterns
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized1A is Inbox2 {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev Stores the first transition record for each proposal to reduce gas costs.
    ///      Uses a ring buffer pattern with proposal ID modulo ring buffer size.
    ///      Uses multiple storage slots for the struct (48 + 26*8 + 26 + 48 = 304 bits)
    struct FirstTransitionRecord {
        uint48 proposalId;
        bytes26 partialParentTransitionHash;
        TransitionRecord transitionRecord;
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

    constructor(IInbox2.Config memory _config) Inbox2(_config) { }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox2
    /// @dev Stores transition record hash with optimized slot reuse.
    ///      Storage strategy:
    ///      1. New proposal ID: overwrite the reusable slot.
    ///      2. Same ID and parent: update accordingly.
    ///      3. Same ID but different parent: fall back to the composite key mapping.
    /// @param _startProposalId The proposal ID for this transition record
    /// @param _parentTransitionHash Parent transition hash used as part of the key
    /// @param _transitionRecord The finalization metadata to persist
    function _storeTransitionRecord(
        uint48 _startProposalId,
        bytes32 _parentTransitionHash,
        TransitionRecord memory _transitionRecord
    )
        internal
        override
    {
        FirstTransitionRecord storage firstRecord =
            _firstTransitionRecord[_startProposalId % _ringBufferSize];
        // Truncation keeps 208 bits of Keccak security; practical collision risk within the proving
        // horizon is negligible.
        // See ../../../docs/analysis/InboxOptimized1-bytes26-Analysis.md for detailed analysis
        bytes26 partialParentHash = bytes26(_parentTransitionHash);

        if (firstRecord.proposalId != _startProposalId) {
            // New proposal, overwrite slot
            firstRecord.proposalId = _startProposalId;
            firstRecord.partialParentTransitionHash = partialParentHash;
            firstRecord.transitionRecord = _transitionRecord;
        } else if (firstRecord.partialParentTransitionHash == partialParentHash) {
            // Only update if new span is larger
            if (_transitionRecord.span > firstRecord.transitionRecord.span) {
                firstRecord.transitionRecord = _transitionRecord;
            }
        } else {
            // Collision: fallback to parent contract logic
            super._storeTransitionRecord(_startProposalId, _parentTransitionHash, _transitionRecord);
        }
    }

    // ---------------------------------------------------------------
    // Internal View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox2
    /// @dev Optimized retrieval using ring buffer with collision detection.
    ///      Lookup strategy (gas-optimized order):
    ///      1. Ring buffer slot lookup (single SLOAD).
    ///      2. Proposal ID verification (cached in memory).
    ///      3. Partial parent hash comparison (single comparison).
    ///      4. Fallback to composite key mapping (most expensive).
    /// @param _proposalId The proposal ID to look up
    /// @param _parentTransitionHash Parent transition hash for verification
    function _loadTransitionRecord(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        override
        returns (TransitionRecord memory record_)
    {
        FirstTransitionRecord storage firstRecord =
            _firstTransitionRecord[_proposalId % _ringBufferSize];

        if (firstRecord.proposalId != _proposalId) {
            return TransitionRecord({ transitionHash: 0, span: 0, finalizationDeadline: 0 });
        } else if (firstRecord.partialParentTransitionHash == bytes26(_parentTransitionHash)) {
            return firstRecord.transitionRecord;
        } else {
            return super._loadTransitionRecord(_proposalId, _parentTransitionHash);
        }
    }
}
