// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibBondsL1 } from "../libs/LibBondsL1.sol";
import { LibTransitionRecords } from "../libs/LibTransitionRecords.sol";

/// @title InboxOptimized1
/// @notice Gas-optimized Inbox implementation with ring buffer storage and transition aggregation
/// @dev Key optimizations implemented:
///      - Ring buffer pattern for frequently accessed transition records (reduces SSTORE
/// operations)
///      - Transition aggregation for consecutive proposals (reduces transaction overhead)
///      - Partial parent hash matching to minimize storage slot usage
///      - Optimized memory allocation and reuse patterns
///      - Separated single vs multi-transition logic paths for gas efficiency
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized1 is Inbox {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Optimized storage for frequently accessed transition records
    /// @dev Stores the first transition record for each proposal to reduce gas costs.
    ///      Uses a ring buffer pattern with proposal ID modulo ring buffer size.
    ///      Packed to fit in single storage slot (32 + 48 + 208 = 288 bits < 256*2)
    struct ReusableTransitionRecord {
        uint48 proposalId;
        bytes26 partialParentTransitionHash;
        TransitionRecordHashAndDeadline hashAndDeadline;
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Storage for default transition records to optimize gas usage
    /// @notice Stores the most common transition record for each buffer slot
    /// @dev Ring buffer implementation with collision handling that falls back to composite key
    /// mapping
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
    /// @notice Optimized transition record building with automatic aggregation
    /// @dev Optimization strategy:
    ///      - Single transitions: Use inherited base functionality (eliminates code duplication)
    ///      - Multiple transitions: Apply aggregation to group consecutive proposals
    ///      - Aggregation: Merges bond instructions and increases span value
    /// @param _input ProveInput containing arrays of proposals and transitions to process
    function _buildAndSaveTransitionRecords(ProveInput memory _input) internal override {
        if (_input.proposals.length == 0) return;

        if (_input.proposals.length == 1) {
            // Use inherited single-transition logic to eliminate duplication
            _processSingleTransitionInherited(_input);
        } else {
            _buildAndSaveAggregatedTransitionRecords(_input);
        }
    }

    /// @dev Processes a single transition using inherited base functionality
    /// @param _input ProveInput containing one proposal and transition
    function _processSingleTransitionInherited(ProveInput memory _input) private {
        _validateTransition(_input.proposals[0], _input.transitions[0]);

        TransitionRecord memory transitionRecord =
            _buildTransitionRecord(_input.proposals[0], _input.transitions[0], _input.metadata[0]);

        _setTransitionRecordHashAndDeadline(
            _input.proposals[0].id, _input.transitions[0], _input.metadata[0], transitionRecord
        );
    }

    /// @dev Handles multi-transition aggregation logic
    /// @param _input ProveInput containing multiple proposals and transitions to aggregate
    function _buildAndSaveAggregatedTransitionRecords(ProveInput memory _input) private {
        // Initialize aggregation state from first proposal
        _validateTransition(_input.proposals[0], _input.transitions[0]);

        TransitionRecord memory currentRecord =
            _buildTransitionRecord(_input.proposals[0], _input.transitions[0], _input.metadata[0]);

        uint48 currentGroupStartId = _input.proposals[0].id;
        uint256 firstIndex = 0;

        // Process remaining proposals with optimized loop
        for (uint256 i = 1; i < _input.proposals.length; ++i) {
            _validateTransition(_input.proposals[i], _input.transitions[i]);

            // Check for consecutive proposal aggregation
            if (_input.proposals[i].id == currentGroupStartId + currentRecord.span) {
                _aggregateTransition(_input, i, currentRecord);
            } else {
                // Save current group and start new one
                _saveTransitionRecord(currentGroupStartId, _input, firstIndex, currentRecord);

                // Reset for new group
                currentGroupStartId = _input.proposals[i].id;
                firstIndex = i;
                currentRecord = _buildTransitionRecord(
                    _input.proposals[i], _input.transitions[i], _input.metadata[i]
                );
            }
        }

        // Save the final aggregated record
        _saveTransitionRecord(currentGroupStartId, _input, firstIndex, currentRecord);
    }

    /// @inheritdoc Inbox
    /// @dev Optimized retrieval using ring buffer with collision detection
    /// @notice Lookup strategy (gas-optimized order):
    ///         1. Ring buffer slot lookup (cheapest - single SLOAD)
    ///         2. Proposal ID verification (cached in memory)
    ///         3. Partial parent hash comparison (single comparison)
    ///         4. Fallback to composite key mapping (most expensive)
    /// @param _proposalId The proposal ID to look up
    /// @param _parentTransitionHash Parent transition hash for verification
    /// @return hashAndDeadline The transition record hash and finalization deadline
    function _getTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        override
        returns (TransitionRecordHashAndDeadline memory hashAndDeadline)
    {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        ReusableTransitionRecord storage record = _reusableTransitionRecords[bufferSlot];

        // Fast path: ring buffer hit (single SLOAD + memory comparison)
        if (
            record.proposalId == _proposalId
                && record.partialParentTransitionHash == bytes26(_parentTransitionHash)
        ) {
            return record.hashAndDeadline;
        }

        // Slow path: composite key mapping (additional SLOAD)
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
    /// @param _proposalId The proposal ID for this transition record
    /// @param _transition The transition data containing parent transition hash
    /// @param _metadata The metadata containing prover information
    /// @param _transitionRecord The complete transition record to store
    function _setTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        Transition memory _transition,
        TransitionMetadata memory _metadata,
        TransitionRecord memory _transitionRecord
    )
        internal
        override
    {
        (, TransitionRecordHashAndDeadline memory hashAndDeadline) =
            _computeTransitionRecordHashAndDeadline(_transitionRecord);
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        ReusableTransitionRecord storage record = _reusableTransitionRecords[bufferSlot];

        bytes26 partialParentHash = bytes26(_transition.parentTransitionHash);

        if (record.proposalId != _proposalId) {
            // New proposal ID - use reusable slot
            record.hashAndDeadline = hashAndDeadline;
            record.proposalId = _proposalId;
            record.partialParentTransitionHash = partialParentHash;
        } else if (record.partialParentTransitionHash == partialParentHash) {
            // Same proposal and parent hash - update reusable slot
            record.hashAndDeadline = hashAndDeadline;
        } else {
            // Collision: same proposal ID, different parent hash - use composite mapping
            _transitionRecordHashAndDeadline[_composeTransitionKey(
                _proposalId, _transition.parentTransitionHash
            )] = hashAndDeadline;
        }

        emit Proved(
            _encodeProvedEventData(
                ProvedEventPayload({
                    proposalId: _proposalId,
                    transition: _transition,
                    transitionRecord: _transitionRecord,
                    metadata: _metadata
                })
            )
        );
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Aggregates a transition into the current record
    /// @param _input The prove input containing all data
    /// @param _index The index of the transition to aggregate
    /// @param _currentRecord The current transition record to update
    function _aggregateTransition(
        ProveInput memory _input,
        uint256 _index,
        TransitionRecord memory _currentRecord
    )
        private
        view
    {
        TransitionRecord memory nextRecord = _buildTransitionRecord(
            _input.proposals[_index], _input.transitions[_index], _input.metadata[_index]
        );

        if (nextRecord.bondInstructions.length > 0) {
            _currentRecord.bondInstructions = _currentRecord.bondInstructions.length == 0
                ? nextRecord.bondInstructions
                : LibBondsL1.mergeBondInstructions(
                    _currentRecord.bondInstructions, nextRecord.bondInstructions
                );
        }

        _currentRecord.transitionHash = nextRecord.transitionHash;
        _currentRecord.checkpointHash = nextRecord.checkpointHash;
        _currentRecord.span++;
    }

    /// @dev Saves a transition record using the first transition's metadata
    /// @param _proposalId The starting proposal ID for the group
    /// @param _input The prove input containing all data
    /// @param _firstIndex The index of the first transition in the group
    /// @param _transitionRecord The transition record to save
    function _saveTransitionRecord(
        uint48 _proposalId,
        ProveInput memory _input,
        uint256 _firstIndex,
        TransitionRecord memory _transitionRecord
    )
        private
    {
        _setTransitionRecordHashAndDeadline(
            _proposalId,
            _input.transitions[_firstIndex],
            _input.metadata[_firstIndex],
            _transitionRecord
        );
    }
}
