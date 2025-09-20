// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { Inbox } from "./Inbox.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";
import { LibBondsL1 } from "../libs/LibBondsL1.sol";

/// @title InboxOptimized1
/// @notice First optimization layer for the Inbox contract focusing on storage efficiency and
/// transition aggregation
/// @dev Key optimizations:
///      - Reusable transition record slots to reduce storage operations
///      - Transition aggregation for consecutive proposals to minimize gas costs
///      - Partial parent transition hash matching for storage optimization
///      - Inline bond instruction merging to reduce function calls
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized1 is Inbox {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Optimized storage for frequently accessed transition records
    /// @dev Stores the first transition record for each proposal to reduce gas costs.
    ///      Uses a ring buffer pattern with proposal ID modulo ring buffer size.
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
    /// @dev Ring buffer implementation with collision handling that falls back to composite key
    /// mapping
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
    /// @dev Aggregation strategy:
    ///      - Groups consecutive proposal IDs into single transition records
    ///      - Merges bond instructions for aggregated transitions
    ///      - Updates end block header for each aggregation
    ///      - Saves aggregated records with increased span value
    /// @param _input ProveInput containing arrays of proposals and transitions to process
    function _buildAndSaveTransitionRecords(ProveInput memory _input) internal override {
        if (_input.proposals.length == 0) return;

        // Validate first proposal
        _validateTransition(_input.proposals[0], _input.transitions[0]);

        // Initialize current aggregation state
        TransitionRecord memory currentRecord = TransitionRecord({
            span: 1,
            bondInstructions: LibBondsL1.calculateBondInstructions(
                _provingWindow, _extendedProvingWindow, _input.proposals[0], _input.metadata[0]
            ),
            transitionHash: _hashTransition(_input.transitions[0]),
            checkpointHash: _hashCheckpoint(_input.transitions[0].checkpoint)
        });

        uint48 currentGroupStartId = _input.proposals[0].id;
        Transition memory firstTransitionInGroup = _input.transitions[0];
        TransitionMetadata memory firstMetadataInGroup = _input.metadata[0];

        // Process remaining proposals
        for (uint256 i = 1; i < _input.proposals.length; ++i) {
            _validateTransition(_input.proposals[i], _input.transitions[i]);

            // Check if current proposal can be aggregated with the previous group
            if (_input.proposals[i].id == currentGroupStartId + currentRecord.span) {
                // Aggregate with current record
                LibBonds.BondInstruction[] memory newInstructions = LibBondsL1
                    .calculateBondInstructions(
                    _provingWindow, _extendedProvingWindow, _input.proposals[i], _input.metadata[i]
                );

                if (newInstructions.length > 0) {
                    // Use LibBonds merge function for cleaner code organization
                    currentRecord.bondInstructions = currentRecord.bondInstructions.length == 0
                        ? newInstructions
                        : LibBondsL1.mergeBondInstructions(
                            currentRecord.bondInstructions, newInstructions
                        );
                }

                // Update the transition hash and checkpoint hash for the aggregated
                // record
                currentRecord.transitionHash = _hashTransition(_input.transitions[i]);
                currentRecord.checkpointHash = _hashCheckpoint(_input.transitions[i].checkpoint);

                // Increment span to include this aggregated proposal
                currentRecord.span++;
            } else {
                // Save the current aggregated record before starting a new one
                // For aggregated records, use the metadata from the first transition in the group
                _setTransitionRecordHashAndDeadline(
                    currentGroupStartId, firstTransitionInGroup, firstMetadataInGroup, currentRecord
                );

                // Start a new record for non-continuous proposal
                currentGroupStartId = _input.proposals[i].id;
                firstTransitionInGroup = _input.transitions[i];
                firstMetadataInGroup = _input.metadata[i];

                currentRecord = TransitionRecord({
                    span: 1,
                    bondInstructions: LibBondsL1.calculateBondInstructions(
                        _provingWindow, _extendedProvingWindow, _input.proposals[i], _input.metadata[i]
                    ),
                    transitionHash: _hashTransition(_input.transitions[i]),
                    checkpointHash: _hashCheckpoint(_input.transitions[i].checkpoint)
                });
            }
        }

        // Save the final aggregated record
        // For the final record, use metadata from the first transition in the last group
        _setTransitionRecordHashAndDeadline(
            currentGroupStartId, firstTransitionInGroup, firstMetadataInGroup, currentRecord
        );
    }

    /// @inheritdoc Inbox
    /// @dev Retrieves transition record hash with storage optimization
    /// @notice Optimization strategy:
    ///         1. First checks reusable slot for matching proposal ID
    ///         2. Performs partial parent transition hash comparison
    ///         3. Falls back to composite key mapping if no match
    /// @param _proposalId The proposal ID to look up
    /// @param _parentTransitionHash Parent transition hash for verification
    /// @return TransitionRecordHashAndDeadline containing the record hash and finalization deadline
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

        bytes memory payload = _encodeProvedEventData(
            ProvedEventPayload({
                proposalId: _proposalId,
                transition: _transition,
                transitionRecord: _transitionRecord,
                metadata: _metadata
            })
        );
        emit Proved(payload);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------
}
