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
    ///      2. Same ID and parent: return on duplicates, revert on mismatched records.
    ///      3. Same ID but different parent: fall back to the composite key mapping.
    /// @param _proposalId The proposal ID for this transition record
    /// @param _parentTransitionHash Parent transition hash used as part of the key
    /// @param _recordHash The keccak hash representing the transition record
    /// @param _hashAndDeadline The finalization metadata to persist
    function _storeTransitionRecord(
        uint48 _proposalId,
        bytes32 _parentTransitionHash,
        bytes26 _recordHash,
        TransitionRecordHashAndDeadline memory _hashAndDeadline,
        bytes26 _prefixHash
    )
        internal
        override
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
            // Same proposal and parent hash - handle duplicates/upgrades
            bytes26 recordHash = record.hashAndDeadline.recordHash;

            if (recordHash == 0) {
                record.hashAndDeadline = _hashAndDeadline;
            } else if (recordHash == _recordHash) {
                return;
            } else {
                require(_hashAndDeadline.span > record.hashAndDeadline.span, TransitionRecordHashMismatchWithStorage());
                require(_prefixHash == recordHash && _prefixHash != 0, TransitionRecordHashMismatchWithStorage());
                record.hashAndDeadline = _hashAndDeadline;
            }
        } else {
            super._storeTransitionRecord(
                _proposalId, _parentTransitionHash, _recordHash, _hashAndDeadline, _prefixHash
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

        // Fast path: ring buffer hit (single SLOAD + memory comparison)
        if (
            record.proposalId == _proposalId
                && record.partialParentTransitionHash == bytes26(_parentTransitionHash)
        ) {
            return (record.hashAndDeadline.recordHash, record.hashAndDeadline.finalizationDeadline);
        }

        // Slow path: composite key mapping (additional SLOAD)
        return super._getTransitionRecordHashAndDeadline(_proposalId, _parentTransitionHash);
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
            TransitionRecord memory currentRecord =
                _buildTransitionRecord(_input.proposals[0], _input.transitions[0], _input.metadata[0]);

            uint48 currentGroupStartId = _input.proposals[0].id;
            uint256 firstIndex;

            // Process remaining proposals with optimized loop
            for (uint256 i = 1; i < _input.proposals.length; ++i) {
                // Check for consecutive proposal aggregation
                // Cap at 255 proposals per record to prevent uint8 span overflow
                if (
                    _input.proposals[i].id == currentGroupStartId + currentRecord.span
                        && currentRecord.span < type(uint8).max
                ) {
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
                    _storeAggregatedRecord(_input, firstIndex, currentRecord, currentGroupStartId);

                    // Reset for new group
                    currentGroupStartId = _input.proposals[i].id;
                    firstIndex = i;
                    currentRecord = _buildTransitionRecord(
                        _input.proposals[i], _input.transitions[i], _input.metadata[i]
                    );
                }
            }

            // Save the final aggregated record
            _storeAggregatedRecord(_input, firstIndex, currentRecord, currentGroupStartId);
        }
    }

    /// @dev Stores an aggregated record allowing overwrite when the new record strictly extends an
    /// existing compatible record.
    function _storeAggregatedRecord(
        ProveInput memory _input,
        uint256 _startIndex,
        TransitionRecord memory _record,
        uint48 _startProposalId
    )
        private
    {
        bytes32 parentTransitionHash = _input.transitions[_startIndex].parentTransitionHash;
        (bytes26 recordHash, TransitionRecordHashAndDeadline memory hashAndDeadline) =
            _computeTransitionRecordHashAndDeadline(_record);

        // Fetch existing record data (ring buffer fast path)
        uint256 bufferSlot = _startProposalId % _ringBufferSize;
        ReusableTransitionRecord storage reusable = _reusableTransitionRecords[bufferSlot];
        bool useReusable = reusable.proposalId == _startProposalId
            && reusable.partialParentTransitionHash == bytes26(parentTransitionHash);
        bytes26 storedHash = useReusable ? reusable.hashAndDeadline.recordHash : bytes26(0);
        uint8 storedSpan = useReusable ? reusable.hashAndDeadline.span : 0;

        if (!useReusable) {
            bytes32 compositeKey = _composeTransitionKey(_startProposalId, parentTransitionHash);
            TransitionRecordHashAndDeadline storage entry = _transitionRecordHashAndDeadline[compositeKey];
            storedHash = entry.recordHash;
            storedSpan = entry.span;
        }

        bytes26 prefixHash;
        if (storedHash != 0 && storedHash != recordHash) {
            require(hashAndDeadline.span > storedSpan, TransitionRecordHashMismatchWithStorage());
            TransitionRecord memory prefixRecord =
                _buildAggregatedRecordForSpan(_input, _startIndex, storedSpan);
            prefixHash = _hashTransitionRecord(prefixRecord);
        }

        _storeTransitionRecord(
            _startProposalId, parentTransitionHash, recordHash, hashAndDeadline, prefixHash
        );

        ProvedEventPayload memory payload = ProvedEventPayload({
            proposalId: _startProposalId,
            transition: _input.transitions[_startIndex],
            transitionRecord: _record,
            metadata: _input.metadata[_startIndex]
        });
        emit Proved(_encodeProvedEventData(payload));
    }

    /// @dev Reconstructs an aggregated TransitionRecord for a prefix of the current group.
    function _buildAggregatedRecordForSpan(
        ProveInput memory _input,
        uint256 _startIndex,
        uint256 _span
    )
        private
        view
        returns (TransitionRecord memory record)
    {
        record = _buildTransitionRecord(
            _input.proposals[_startIndex], _input.transitions[_startIndex], _input.metadata[_startIndex]
        );

        uint256 end = _startIndex + _span;
        for (uint256 i = _startIndex + 1; i < end; ++i) {
            TransitionRecord memory nextRecord = _buildTransitionRecord(
                _input.proposals[i], _input.transitions[i], _input.metadata[i]
            );
            if (nextRecord.bondInstructions.length == 0) {
                // keep
            } else if (record.bondInstructions.length == 0) {
                record.bondInstructions = nextRecord.bondInstructions;
            } else {
                record.bondInstructions =
                    LibBondInstruction.mergeBondInstructions(record.bondInstructions, nextRecord.bondInstructions);
            }
            record.transitionHash = nextRecord.transitionHash;
            record.checkpointHash = nextRecord.checkpointHash;
            record.span++;
        }
    }
}
