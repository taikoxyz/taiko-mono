// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibBondsL1 } from "contracts/layer1/shasta/libs/LibBondsL1.sol";

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
    ///      - Single transitions: Use optimized storage lookup
    ///      - Multiple transitions: Apply aggregation to group consecutive proposals
    ///      - Aggregation: Merges bond instructions and increases span value
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
    /// @dev Optimized retrieval using ring buffer with collision detection
    /// @notice Lookup strategy (gas-optimized order):
    ///         1. Ring buffer slot lookup (cheapest - single SLOAD)
    ///         2. Proposal ID verification (cached in memory)
    ///         3. Partial parent hash comparison (single comparison)
    ///         4. Fallback to composite key mapping (most expensive)
    /// @param _proposalId The proposal ID to look up
    /// @param _parentTransitionHash Parent transition hash for verification
    /// @return finalizationDeadline_ The deadline associated with the cached transition record
    /// @return recordHash_ The transition record hash stored in the cache or fallback mapping
    function _getTransitionRecordHash(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        override
        returns (uint48 finalizationDeadline_, bytes26 recordHash_)
    {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        ReusableTransitionRecord storage record = _reusableTransitionRecords[bufferSlot];

        // Fast path: ring buffer hit (single SLOAD + memory comparison)
        if (
            record.proposalId == _proposalId
                && record.partialParentTransitionHash == bytes26(_parentTransitionHash)
        ) {
            return (record.hashAndDeadline.finalizationDeadline, record.hashAndDeadline.recordHash);
        }

        // Slow path: composite key mapping (additional SLOAD)
        return super._getTransitionRecordHash(_proposalId, _parentTransitionHash);
    }

    /// @inheritdoc Inbox
    /// @dev Stores transition record hash with optimized slot reuse
    /// @notice Storage strategy:
    ///         1. New proposal ID: Overwrites reusable slot
    ///         2. Same ID, same parent: Updates reusable slot
    ///         3. Same ID, different parent: Uses composite key mapping
    /// @param _proposalId The proposal ID for this transition record
    /// @param _parentTransitionHash Parent transition hash used as part of the key
    /// @param _recordHash The keccak hash representing the transition record
    /// @param _finalizationDeadline The finalization metadata to persist
    /// @return stored_ True if the caller should emit the Proved event
    function _storeTransitionRecord(
        uint48 _proposalId,
        bytes32 _parentTransitionHash,
        bytes26 _recordHash,
        uint48 _finalizationDeadline
    )
        internal
        override
        returns (bool stored_)
    {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        ReusableTransitionRecord storage record = _reusableTransitionRecords[bufferSlot];
        bytes26 partialParentHash = bytes26(_parentTransitionHash);

        if (record.proposalId != _proposalId) {
            // New proposal ID - use reusable slot
            record.proposalId = _proposalId;
            record.partialParentTransitionHash = partialParentHash;
            record.hashAndDeadline.recordHash = _recordHash;
            record.hashAndDeadline.finalizationDeadline = _finalizationDeadline;
            return true;
        }

        if (record.partialParentTransitionHash == partialParentHash) {
            // Same proposal and parent hash - update reusable slot
            record.hashAndDeadline.recordHash = _recordHash;
            record.hashAndDeadline.finalizationDeadline = _finalizationDeadline;
            return true;
        }

        // Collision: same proposal ID, different parent hash - use composite mapping
        return super._storeTransitionRecord(
            _proposalId, _parentTransitionHash, _recordHash, _finalizationDeadline
        );
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Handles multi-transition aggregation logic
    /// @param _input ProveInput containing multiple proposals and transitions to aggregate
    function _buildAndSaveAggregatedTransitionRecords(ProveInput memory _input) private {
        uint256 total = _input.proposals.length;

        // Validate all transitions upfront using shared function
        for (uint256 i; i < total; ++i) {
            _validateTransition(_input.proposals[i], _input.transitions[i]);
        }

        // Initialize aggregation state from first proposal
        TransitionRecord memory currentRecord =
            _buildTransitionRecord(_input.proposals[0], _input.transitions[0], _input.metadata[0]);

        uint48 currentGroupStartId = _input.proposals[0].id;
        uint256 firstIndex = 0;

        LibBonds.BondInstruction[] memory instructionBuffer = new LibBonds.BondInstruction[](total);
        uint256 instructionCount =
            _copyBondInstructions(currentRecord.bondInstructions, instructionBuffer);
        currentRecord.bondInstructions = instructionBuffer;

        // Process remaining proposals with optimized loop
        for (uint256 i = 1; i < total; ++i) {
            Proposal memory proposal = _input.proposals[i];

            // Check for consecutive proposal aggregation
            if (proposal.id == currentGroupStartId + currentRecord.span) {
                instructionCount = _appendBondInstruction(
                    instructionBuffer, instructionCount, proposal, _input.metadata[i]
                );

                Transition memory transition = _input.transitions[i];
                currentRecord.transitionHash = _hashTransition(transition);
                currentRecord.checkpointHash = _hashCheckpoint(transition.checkpoint);
                currentRecord.span++;
            } else {
                // Save current group and start new one
                _finalizeAggregatedRecord(
                    currentGroupStartId, firstIndex, currentRecord, instructionCount, _input
                );

                // Reset for new group
                currentGroupStartId = proposal.id;
                firstIndex = i;
                currentRecord =
                    _buildTransitionRecord(proposal, _input.transitions[i], _input.metadata[i]);

                instructionBuffer = new LibBonds.BondInstruction[](total - i);
                instructionCount =
                    _copyBondInstructions(currentRecord.bondInstructions, instructionBuffer);
                currentRecord.bondInstructions = instructionBuffer;
            }
        }

        // Save the final aggregated record
        _finalizeAggregatedRecord(
            currentGroupStartId, firstIndex, currentRecord, instructionCount, _input
        );
    }

    /// @dev Copies the existing bond instructions into the provided buffer.
    /// @return count_ The number of meaningful instructions copied into the buffer.
    function _copyBondInstructions(
        LibBonds.BondInstruction[] memory _source,
        LibBonds.BondInstruction[] memory _destination
    )
        private
        pure
        returns (uint256 count_)
    {
        count_ = _source.length;
        for (uint256 i; i < count_; ++i) {
            _destination[i] = _source[i];
        }
    }

    /// @dev Appends an optional bond instruction into the aggregation buffer.
    /// @return nextIndex_ Updated count of valid instructions stored in the buffer.
    function _appendBondInstruction(
        LibBonds.BondInstruction[] memory _buffer,
        uint256 _currentIndex,
        Proposal memory _proposal,
        TransitionMetadata memory _metadata
    )
        private
        view
        returns (uint256 nextIndex_)
    {
        LibBonds.BondInstruction[] memory instructions = LibBondsL1.calculateBondInstructions(
            _provingWindow, _extendedProvingWindow, _proposal, _metadata
        );

        if (instructions.length == 0) return _currentIndex;

        _buffer[_currentIndex] = instructions[0];
        return _currentIndex + 1;
    }

    /// @dev Finalizes the current aggregation group and persists the transition record.
    function _finalizeAggregatedRecord(
        uint48 _groupStartId,
        uint256 _firstIndex,
        TransitionRecord memory _record,
        uint256 _instructionCount,
        ProveInput memory _input
    )
        private
    {
        LibBonds.BondInstruction[] memory instructions = _record.bondInstructions;
        assembly ("memory-safe") {
            mstore(instructions, _instructionCount)
        }

        _setTransitionRecordHashAndDeadline(
            _groupStartId, _input.transitions[_firstIndex], _input.metadata[_firstIndex], _record
        );
    }
}
