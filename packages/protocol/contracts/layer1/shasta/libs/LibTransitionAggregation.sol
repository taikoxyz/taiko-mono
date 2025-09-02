// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibBondsL1 } from "./LibBondsL1.sol";

/// @title LibTransitionAggregation
/// @notice Library for aggregating consecutive transition records to optimize storage and gas usage
/// @dev Implements the core aggregation logic for grouping consecutive proposal IDs into single
/// transition records with increased span values
/// @custom:security-contact security@taiko.xyz
library LibTransitionAggregation {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Represents an aggregated transition record ready for storage
    struct AggregatedRecord {
        /// @notice The starting proposal ID of this aggregated record
        uint48 startProposalId;
        /// @notice The first transition in the aggregated group (needed for storage key)
        IInbox.Transition firstTransition;
        /// @notice The aggregated transition record
        IInbox.TransitionRecord record;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Aggregates consecutive transitions into optimized records
    /// @dev Groups consecutive proposal IDs into single records with merged bond instructions
    /// @dev NOTE: That using a view function here instead of manipulating storage directly on the inbox
    /// or passing a storage pointer is slightly less efficient, but for non extremely large number of transitions, it's a small difference and the readability is much better.
    /// @param _proposals Array of proposals to aggregate
    /// @param _transitions Array of transitions corresponding to proposals
    /// @param _config Configuration parameters for bond calculations
    /// @return records_ Array of aggregated records ready for storage
    function aggregateTransitions(
        IInbox.Proposal[] memory _proposals,
        IInbox.Transition[] memory _transitions,
        IInbox.Config memory _config
    )
        internal
        view
        returns (AggregatedRecord[] memory records_)
    {
        if (_proposals.length == 0) {
            return new AggregatedRecord[](0);
        }

        // Pre-allocate maximum possible records (worst case: no aggregation)
        AggregatedRecord[] memory tempRecords = new AggregatedRecord[](_proposals.length);
        uint256 recordCount = 0;

        // Initialize first aggregation group
        IInbox.TransitionRecord memory currentRecord = IInbox.TransitionRecord({
            span: 1,
            bondInstructions: LibBondsL1.calculateBondInstructions(_config, _proposals[0], _transitions[0]),
            transitionHash: keccak256(abi.encode(_transitions[0])),
            checkpointHash: keccak256(abi.encode(_transitions[0].checkpoint))
        });

        uint48 currentGroupStartId = _proposals[0].id;
        IInbox.Transition memory firstTransitionInGroup = _transitions[0];

        // Process remaining proposals for aggregation
        for (uint256 i = 1; i < _proposals.length; ++i) {
            // Check if current proposal can be aggregated with previous group
            if (canAggregate(currentGroupStartId, currentRecord.span, _proposals[i].id)) {
                // Aggregate with current record
                LibBonds.BondInstruction[] memory newInstructions =
                    LibBondsL1.calculateBondInstructions(_config, _proposals[i], _transitions[i]);

                // Merge bond instructions if any exist
                if (newInstructions.length > 0) {
                    currentRecord.bondInstructions =
                        mergeInstructions(currentRecord.bondInstructions, newInstructions);
                }

                // Update record with latest transition data
                currentRecord.transitionHash = keccak256(abi.encode(_transitions[i]));
                currentRecord.checkpointHash = keccak256(abi.encode(_transitions[i].checkpoint));
                currentRecord.span++;
            } else {
                // Save current aggregated record
                tempRecords[recordCount] = AggregatedRecord({
                    startProposalId: currentGroupStartId,
                    firstTransition: firstTransitionInGroup,
                    record: currentRecord
                });
                recordCount++;

                // Start new aggregation group
                currentGroupStartId = _proposals[i].id;
                firstTransitionInGroup = _transitions[i];

                currentRecord = IInbox.TransitionRecord({
                    span: 1,
                    bondInstructions: LibBondsL1.calculateBondInstructions(_config, _proposals[i], _transitions[i]),
                    transitionHash: keccak256(abi.encode(_transitions[i])),
                    checkpointHash: keccak256(abi.encode(_transitions[i].checkpoint))
                });
            }
        }

        // Save the final aggregated record
        tempRecords[recordCount] = AggregatedRecord({
            startProposalId: currentGroupStartId,
            firstTransition: firstTransitionInGroup,
            record: currentRecord
        });
        recordCount++;

        // Copy to correctly sized array
        records_ = new AggregatedRecord[](recordCount);
        for (uint256 i = 0; i < recordCount; ++i) {
            records_[i] = tempRecords[i];
        }
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Checks if a proposal can be aggregated with the current group
    /// @dev Proposals can be aggregated if they have consecutive IDs
    /// @param _currentGroupStartId The starting proposal ID of the current group
    /// @param _currentSpan The current span of the aggregation group
    /// @param _nextProposalId The proposal ID to check for aggregation
    /// @return canAggregate_ True if the proposal can be aggregated
    function canAggregate(
        uint48 _currentGroupStartId,
        uint8 _currentSpan,
        uint48 _nextProposalId
    )
        private
        pure
        returns (bool canAggregate_)
    {
        canAggregate_ = _nextProposalId == _currentGroupStartId + _currentSpan;
    }

    /// @dev Merges two arrays of bond instructions
    /// @dev Creates a new array containing all instructions from both inputs
    /// @param _existing Array of existing bond instructions
    /// @param _newInstructions Array of new bond instructions to merge
    /// @return merged_ New array containing all instructions
    function mergeInstructions(
        LibBonds.BondInstruction[] memory _existing,
        LibBonds.BondInstruction[] memory _newInstructions
    )
        private
        pure
        returns (LibBonds.BondInstruction[] memory merged_)
    {
        uint256 existingLen = _existing.length;
        uint256 newLen = _newInstructions.length;
        
        merged_ = new LibBonds.BondInstruction[](existingLen + newLen);

        // Copy existing instructions
        for (uint256 i = 0; i < existingLen; ++i) {
            merged_[i] = _existing[i];
        }

        // Copy new instructions
        for (uint256 i = 0; i < newLen; ++i) {
            merged_[existingLen + i] = _newInstructions[i];
        }
    }

}