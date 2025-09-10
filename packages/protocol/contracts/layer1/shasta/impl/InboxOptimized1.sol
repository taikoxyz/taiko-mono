// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibTransitionAggregation } from "../libs/LibTransitionAggregation.sol";

/// @title InboxOptimized1
/// @notice First optimization layer for the Inbox contract focusing on storage efficiency and
/// transition
/// aggregation
/// @dev Key optimizations:
///      - Reusable transition record slots to reduce storage operations
///      - Transition aggregation for consecutive proposals to minimize gas costs
///      - Partial parent transition hash matching (26 bytes) for storage optimization
///      - Inline bond instruction merging to reduce function calls
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized1 is Inbox {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Optimized storage for frequently accessed transition records
    /// @dev Stores the first transition record for each proposal to reduce gas costs
    struct ReusableTransitionRecord {
        TransitionRecordHashAndDeadline hashAndDeadline;
        uint48 proposalId;
        bytes26 partialParentTransitionHash;
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Storage for default transition records to optimize gas usage
    /// @notice Stores the most common transition record for each buffer slot
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - reusableTransitionRecord: The default transition record for quick access
    mapping(uint256 bufferSlot => ReusableTransitionRecord reusableTransitionRecord) internal
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
    /// @notice Optimized transition record building with automatic aggregation
    /// @dev Uses LibTransitionAggregation to group consecutive proposal IDs into single
    ///      transition records with merged bond instructions and increased span values
    function _buildAndSaveTransitionRecords(ProveInput memory _input) internal override {
        if (_input.proposals.length == 0) return;

        // Validate all transitions first
        for (uint256 i = 0; i < _input.proposals.length; ++i) {
            _validateTransition(_input.proposals[i], _input.transitions[i]);
        }

        // Aggregate transitions using library
        LibTransitionAggregation.AggregatedRecord[] memory aggregatedRecords =
        LibTransitionAggregation.aggregateTransitions(
            _input.proposals, _input.transitions, _provingWindow, _extendedProvingWindow
        );

        // Save all aggregated records to storage
        for (uint256 i = 0; i < aggregatedRecords.length; ++i) {
            _setTransitionRecordHashAndDeadline(
                aggregatedRecords[i].startProposalId,
                aggregatedRecords[i].firstTransition,
                aggregatedRecords[i].record
            );
        }
    }

    /// @inheritdoc Inbox
    /// @dev Retrieves transition record hash with storage optimization
    /// @notice Gas optimization strategy:
    ///         1. First checks reusable slot for matching proposal ID
    ///         2. Performs partial parent transition hash comparison (26 bytes)
    ///         3. Falls back to composite key mapping if no match
    /// @dev Reduces storage reads by ~50% for common case (single transition per proposal)
    function _getTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        override
        returns (TransitionRecordHashAndDeadline memory)
    {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        ReusableTransitionRecord storage record = _reusableTransitionRecords[bufferSlot];

        // Check if this is the default record for this proposal and if parent transition hash
        // matches (partial match)
        if (
            record.proposalId == _proposalId
                && record.partialParentTransitionHash == bytes26(_parentTransitionHash)
        ) {
            return record.hashAndDeadline;
        }

        // Otherwise check the direct mapping
        return _transitionRecordHashAndDeadline[_composeTransitionKey(
            _proposalId, _parentTransitionHash
        )];
    }

    /// @inheritdoc Inbox
    /// @dev Stores transition record hash with optimized slot reuse
    /// @notice Storage strategy:
    ///         1. New proposal ID: Overwrites reusable slot
    ///         2. Same ID, same parent: Updates reusable slot
    ///         3. Same ID, different parent: Uses composite key mapping
    /// @dev Saves ~20,000 gas for common case by avoiding mapping writes
    function _setTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        Transition memory _transition,
        TransitionRecord memory _transitionRecord
    )
        internal
        override
    {
        bytes26 transitionRecordHash = _hashTransitionRecord(_transitionRecord);
        ReusableTransitionRecord storage record =
            _reusableTransitionRecords[_proposalId % _ringBufferSize];

        uint48 finalizationDeadline = uint48(block.timestamp + _finalizationGracePeriod);

        // Check if we can use the default slot
        if (record.proposalId != _proposalId) {
            // Different proposal ID, so we can use the default slot
            record.hashAndDeadline = TransitionRecordHashAndDeadline({
                finalizationDeadline: finalizationDeadline,
                recordHash: transitionRecordHash
            });
            record.proposalId = _proposalId;
            record.partialParentTransitionHash = bytes26(_transition.parentTransitionHash);
        } else if (record.partialParentTransitionHash == bytes26(_transition.parentTransitionHash))
        {
            // Different proposal ID, so we can use the default slot
            record.hashAndDeadline = TransitionRecordHashAndDeadline({
                finalizationDeadline: finalizationDeadline,
                recordHash: transitionRecordHash
            });
        } else {
            // Same proposal ID but different parent transition hash, use direct mapping
            bytes32 compositeKey =
                _composeTransitionKey(_proposalId, _transition.parentTransitionHash);
            _transitionRecordHashAndDeadline[compositeKey] = TransitionRecordHashAndDeadline({
                finalizationDeadline: finalizationDeadline,
                recordHash: transitionRecordHash
            });
        }

        bytes memory payload = encodeProvedEventData(
            ProvedEventPayload({
                proposalId: _proposalId,
                transition: _transition,
                transitionRecord: _transitionRecord
            })
        );
        emit Proved(payload);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------
}
