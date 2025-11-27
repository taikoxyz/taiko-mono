// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBondInstruction } from "../libs/LibBondInstruction.sol";
import { Inbox } from "./Inbox.sol";

import "./InboxOptimized1_Layout.sol"; // DO NOT DELETE

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
    ///      Uses two storage slots: (48 + 208 = 256 bits) + (256 bits) = 512 bits
    struct ReusableTransitionSnippet {
        uint48 proposalId;
        bytes26 partialParentTransitionHash;
        bytes32 snippetEncoded;
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Storage for default transition records to optimize gas usage
    /// @notice Stores one transition record per buffer slot for gas optimization
    /// @dev Ring buffer implementation with collision handling that falls back to the composite key
    /// mapping from the parent contract
    mapping(uint256 bufferSlot => ReusableTransitionSnippet snippet) internal
        _reusableTransitionSnippets;

    uint256[49] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(IInbox.Config memory _config) Inbox(_config) { }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @dev Optimized transition record building with automatic aggregation.
    ///      Strategy:
    ///      - Single transitions: use the parent implementation's optimized lookup
    ///      - Multiple transitions: aggregate consecutive proposals into a single record
    ///      - Aggregation merges bond instructions and increases the span value
    /// @param _input ProveInput containing arrays of proposals and transitions to process
    function _buildAndSaveTransitionRecords(ProveInput memory _input) internal override {
        if (_input.proposals.length == 0) return;

        if (_input.proposals.length == 1) {
            _processSingleTransitionAtIndex(_input, 0);
        } else {
            _buildAndSaveAggregatedTransitionRecords(_input);
        }
    }

    /// @inheritdoc Inbox
    /// @dev Stores transition record hash with optimized slot reuse.
    ///      Storage strategy:
    ///      1. New proposal ID: overwrite the reusable slot.
    ///      2. Same ID and parent: detect duplicates or conflicts and update accordingly.
    ///      3. Same ID but different parent: fall back to the composite key mapping.
    /// @param _proposalId The proposal ID for this transition record
    /// @param _parentTransitionHash Parent transition hash used as part of the key
    /// @param _snippet The finalization metadata to persist
    function _storeTransitionSnippet(
        uint48 _proposalId,
        bytes32 _parentTransitionHash,
        TransitionSnippet memory _snippet
    )
        internal
        override
    {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        ReusableTransitionSnippet storage snippet = _reusableTransitionSnippets[bufferSlot];
        // Truncation keeps 208 bits of Keccak security; practical collision risk within the proving
        // horizon is negligible.
        // See ../../../docs/analysis/InboxOptimized1-bytes26-Analysis.md for detailed analysis
        bytes26 partialParentHash = bytes26(_parentTransitionHash);

        if (snippet.proposalId != _proposalId) {
            // New proposal ID - use reusable slot
            snippet.proposalId = _proposalId;
            snippet.partialParentTransitionHash = partialParentHash;
            snippet.snippetEncoded = _encodeTransitionSnippet(_snippet);
        } else if (snippet.partialParentTransitionHash == partialParentHash) {
            // Same proposal and parent hash - check for duplicate or conflict
            TransitionSnippet memory existing = _decodeTransitionSnippet(snippet.snippetEncoded);

            if (existing.recordHash == 0) {
                snippet.snippetEncoded = _encodeTransitionSnippet(_snippet);
            } else if (existing.recordHash == _snippet.recordHash) {
                emit TransitionDuplicateDetected();
            } else {
                emit TransitionConflictDetected();
                conflictingTransitionDetected = true;
                // Set deadline to max while preserving other fields
                snippet.snippetEncoded = _encodeTransitionSnippet(
                    TransitionSnippet({
                        recordHash: existing.recordHash,
                        transitionSpan: existing.transitionSpan,
                        finalizationDeadline: type(uint40).max
                    })
                );
            }
        } else {
            super._storeTransitionSnippet(_proposalId, _parentTransitionHash, _snippet);
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
    /// @return snippet_ The decoded TransitionSnippet struct
    function _getTransitionSnippet(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        override
        returns (TransitionSnippet memory snippet_)
    {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        ReusableTransitionSnippet storage reusable = _reusableTransitionSnippets[bufferSlot];

        // Fast path: ring buffer hit (single SLOAD + memory comparison)
        if (
            reusable.proposalId == _proposalId
                && reusable.partialParentTransitionHash == bytes26(_parentTransitionHash)
        ) {
            return _decodeTransitionSnippet(reusable.snippetEncoded);
        }

        // Slow path: composite key mapping (additional SLOAD)
        return super._getTransitionSnippet(_proposalId, _parentTransitionHash);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Handles multi-transition aggregation logic
    /// @param _input ProveInput containing multiple proposals and transitions to aggregate
    function _buildAndSaveAggregatedTransitionRecords(ProveInput memory _input) private {
        // Validate all transitions upfront using shared function
        unchecked {
            for (uint256 i; i < _input.proposals.length; ++i) {
                _validateTransition(_input.proposals[i], _input.transitions[i]);
            }

            // Initialize aggregation state from first proposal
            TransitionRecord memory currentRecord = _buildTransitionRecord(
                _input.proposals[0], _input.transitions[0], _input.metadata[0]
            );

            uint48 groupStartProposalId = _input.proposals[0].id;
            uint256 firstIndex;

            // Process remaining proposals with optimized loop
            for (uint256 i = 1; i < _input.proposals.length; ++i) {
                // Check for consecutive proposal aggregation
                if (_input.proposals[i].id == groupStartProposalId + currentRecord.span) {
                    TransitionRecord memory nextRecord = _buildTransitionRecord(
                        _input.proposals[i], _input.transitions[i], _input.metadata[i]
                    );
                    if (nextRecord.bondInstructions.length == 0) {
                        // Keep current instructions unchanged
                    } else if (currentRecord.bondInstructions.length == 0) {
                        currentRecord.bondInstructions = nextRecord.bondInstructions;
                    } else {
                        currentRecord.bondInstructions = LibBondInstruction.mergeBondInstructions(
                            currentRecord.bondInstructions, nextRecord.bondInstructions
                        );
                    }
                    currentRecord.transitionHash = nextRecord.transitionHash;
                    currentRecord.checkpointHash = nextRecord.checkpointHash;
                    currentRecord.span++;
                } else {
                    // Save current group and start new one
                    _setAggregatedTransitionSnippet(
                        _input, groupStartProposalId, firstIndex, currentRecord
                    );

                    // Reset for new group
                    groupStartProposalId = _input.proposals[i].id;
                    firstIndex = i;
                    currentRecord = _buildTransitionRecord(
                        _input.proposals[i], _input.transitions[i], _input.metadata[i]
                    );
                }
            }

            // Save the final aggregation group
            _setAggregatedTransitionSnippet(
                _input, groupStartProposalId, firstIndex, currentRecord
            );
        }
    }

    /// @dev Sets the aggregated transition record hash and deadline
    /// @param _input Original prove input
    /// @param _groupStartProposalId First proposal ID in the group
    /// @param _firstIndex Index of first transition in the group
    /// @param _record Aggregated transition record for the group
    function _setAggregatedTransitionSnippet(
        ProveInput memory _input,
        uint48 _groupStartProposalId,
        uint256 _firstIndex,
        TransitionRecord memory _record
    )
        private
    {
        unchecked {
            if (_record.span > 1) {
                // Use first transition but replace checkpoint with the last one
                uint256 lastIndex = _firstIndex + _record.span - 1;
                _input.transitions[_firstIndex].checkpoint =
                _input.transitions[lastIndex].checkpoint;
            }
            _setTransitionSnippet(
                _groupStartProposalId,
                _input.transitions[_firstIndex],
                _input.metadata[_firstIndex],
                _record
            );
        }
    }
}
