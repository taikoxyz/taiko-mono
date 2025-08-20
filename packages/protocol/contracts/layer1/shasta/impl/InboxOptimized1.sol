// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title InboxOptimized1
/// @notice Inbox optimized to allow slot reuse and claim aggregation.
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimized1 is Inbox {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() Inbox() { }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @dev Builds then saves claim records for multiple proposals and claims with aggregation for
    /// continuous proposals. Optimized to reduce memory allocations during bond instruction
    /// merging.
    function _buildAndSaveClaimRecords(
        Config memory _config,
        ProveInput memory _input
    )
        internal
        override
    {
        if (_input.proposals.length == 0) return;

        // Validate first proposal

        _validateClaim(_config, _input.proposals[0], _input.claims[0]);

        // Initialize current aggregation state
        ClaimRecord memory currentRecord = ClaimRecord({
            span: 1,
            bondInstructions: _calculateBondInstructions(_config, _input.proposals[0], _input.claims[0]),
            claimHash: _hashClaim(_input.claims[0]),
            endBlockMiniHeaderHash: _hashBlockMiniHeader(_input.claims[0].endBlockMiniHeader)
        });

        uint48 currentGroupStartId = _input.proposals[0].id;
        Claim memory firstClaimInGroup = _input.claims[0];

        // Process remaining proposals
        for (uint256 i = 1; i < _input.proposals.length; ++i) {
            _validateClaim(_config, _input.proposals[i], _input.claims[i]);

            // Check if current proposal can be aggregated with the previous group
            if (_input.proposals[i].id == currentGroupStartId + currentRecord.span) {
                // Aggregate with current record
                LibBonds.BondInstruction[] memory newInstructions =
                    _calculateBondInstructions(_config, _input.proposals[i], _input.claims[i]);

                if (newInstructions.length > 0) {
                    // Inline merge to avoid separate function call and reduce stack depth
                    uint256 oldLen = currentRecord.bondInstructions.length;
                    uint256 newLen = newInstructions.length;
                    LibBonds.BondInstruction[] memory merged =
                        new LibBonds.BondInstruction[](oldLen + newLen);

                    // Copy existing instructions
                    for (uint256 j; j < oldLen; ++j) {
                        merged[j] = currentRecord.bondInstructions[j];
                    }

                    // Copy new instructions
                    for (uint256 j; j < newLen; ++j) {
                        merged[oldLen + j] = newInstructions[j];
                    }
                    currentRecord.bondInstructions = merged;
                }

                // Update the claim hash and end block mini header hash for the aggregated record
                currentRecord.claimHash = _hashClaim(_input.claims[i]);
                currentRecord.endBlockMiniHeaderHash =
                    _hashBlockMiniHeader(_input.claims[i].endBlockMiniHeader);

                // Increment span to include this aggregated proposal
                currentRecord.span++;
            } else {
                // Save the current aggregated record before starting a new one
                _setClaimRecordHash(_config, currentGroupStartId, firstClaimInGroup, currentRecord);

                // Start a new record for non-continuous proposal
                currentGroupStartId = _input.proposals[i].id;
                firstClaimInGroup = _input.claims[i];

                currentRecord = ClaimRecord({
                    span: 1,
                    bondInstructions: _calculateBondInstructions(
                        _config, _input.proposals[i], _input.claims[i]
                    ),
                    claimHash: _hashClaim(_input.claims[i]),
                    endBlockMiniHeaderHash: _hashBlockMiniHeader(_input.claims[i].endBlockMiniHeader)
                });
            }
        }

        // Save the final aggregated record
        _setClaimRecordHash(_config, currentGroupStartId, firstClaimInGroup, currentRecord);
    }

    /// @dev Gets the claim record hash for a given proposal and parent claim.
    /// @notice This implementation tries to reuse a default slot to save gas.
    function _getClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        internal
        view
        override
        returns (bytes32 claimRecordHash_)
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        ReuseableClaimRecord storage record = _reuseableClaimRecords[bufferSlot];

        // Check if this is the default record for this proposal
        if (record.proposalId == _proposalId) {
            // Check if parent claim hash matches (partial match)
            if (_isPartialParentClaimHashMatch(record.partialParentClaimHash, _parentClaimHash)) {
                return record.claimRecordHash;
            }
        }

        // Otherwise check the direct mapping
        bytes32 compositeKey = _composeClaimKey(_proposalId, _parentClaimHash);
        return _claimRecordHashes[bufferSlot][compositeKey];
    }

    /// @dev Sets the claim record hash for a given proposal and parent claim, and emits the Proved
    /// event. This implementation tries to reuse a default slot to save gas.
    function _setClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        Claim memory _claim,
        ClaimRecord memory _claimRecord
    )
        internal
        override
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        bytes32 claimRecordHash = _hashClaimRecord(_claimRecord);
        ReuseableClaimRecord storage record = _reuseableClaimRecords[bufferSlot];

        // Check if we can use the default slot
        if (record.proposalId != _proposalId) {
            // Different proposal ID, so we can use the default slot
            record.claimRecordHash = claimRecordHash;
            record.proposalId = _proposalId;
            record.partialParentClaimHash = bytes26(_claim.parentClaimHash);
        } else if (
            _isPartialParentClaimHashMatch(record.partialParentClaimHash, _claim.parentClaimHash)
        ) {
            // Same proposal ID and same parent claim hash (partial match), update the default slot
            record.claimRecordHash = claimRecordHash;
        } else {
            // Same proposal ID but different parent claim hash, use direct mapping
            bytes32 compositeKey = _composeClaimKey(_proposalId, _claim.parentClaimHash);
            _claimRecordHashes[bufferSlot][compositeKey] = claimRecordHash;
        }

        bytes memory payload = encodeProvedEventData(
            ProvedEventPayload({ proposalId: _proposalId, claim: _claim, claimRecord: _claimRecord })
        );
        emit Proved(payload);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Checks if the partial parent claim hash matches the full parent claim hash.
    function _isPartialParentClaimHashMatch(
        bytes26 _partialParentClaimHash,
        bytes32 _parentClaimHash
    )
        private
        pure
        returns (bool)
    {
        return _partialParentClaimHash == bytes26(_parentClaimHash);
    }
}
