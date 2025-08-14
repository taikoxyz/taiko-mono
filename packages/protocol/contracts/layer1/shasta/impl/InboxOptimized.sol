// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Inbox.sol";

/// @title InboxOptimized
/// @notice Combines slot reuse and claim aggregation optimizations for the Inbox contract
/// @dev This contract merges the optimizations from InboxWithSlotReuse and
/// InboxWithClaimAggregation
/// to provide both storage optimization through slot reuse and gas optimization through claim
/// aggregation
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimized is Inbox {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    bytes32 private constant _DEFAULT_SLOT_HASH = bytes32(uint256(1));

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() Inbox() { }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @dev Builds claim records for multiple proposals and claims with aggregation for continuous
    /// proposals
    /// @param _config The configuration parameters.
    /// @param _proposals The proposals to prove.
    /// @param _claims The claims containing the proof details.
    /// @return claimRecords_ The built claim records with aggregated bond instructions for
    /// continuous proposals.
    function _buildClaimRecords(
        Config memory _config,
        Proposal[] memory _proposals,
        Claim[] memory _claims
    )
        internal
        view
        override
        returns (ClaimRecord[] memory claimRecords_)
    {
        // Start with array sized for all proposals
        claimRecords_ = new ClaimRecord[](_proposals.length);

        if (_proposals.length == 0) return claimRecords_;

        // Validate first proposal and create initial claim record
        _validateProposal(_config, _proposals[0], _claims[0]);
        LibBonds.BondInstruction[] memory currentInstructions =
            _calculateBondInstructions(_config, _proposals[0], _claims[0]);

        claimRecords_[0] =
            ClaimRecord({ claim: _claims[0], span: 1, bondInstructions: currentInstructions });

        uint256 finalRecordCount = 1;
        uint256 currentRecordIndex;
        uint48 currentGroupStartId = _proposals[0].id;

        // Process remaining proposals
        for (uint256 i = 1; i < _proposals.length; ++i) {
            _validateProposal(_config, _proposals[i], _claims[i]);

            // Check if current proposal can be aggregated with the previous group
            // The next expected proposal ID is: start of current group + current span
            uint48 nextExpectedId = currentGroupStartId + claimRecords_[currentRecordIndex].span;
            if (_proposals[i].id == nextExpectedId) {
                // Aggregate with current record
                LibBonds.BondInstruction[] memory newInstructions =
                    _calculateBondInstructions(_config, _proposals[i], _claims[i]);

                if (newInstructions.length > 0) {
                    // Get current instructions from the record
                    LibBonds.BondInstruction[] memory aggregatedInstructions =
                        claimRecords_[currentRecordIndex].bondInstructions;

                    // Resize and append using assembly
                    uint256 oldLen = aggregatedInstructions.length;
                    uint256 newLen = oldLen + newInstructions.length;

                    assembly {
                        // Update the length of aggregatedInstructions array
                        mstore(aggregatedInstructions, newLen)
                    }

                    // Copy new instructions to the resized array
                    for (uint256 j = 0; j < newInstructions.length; ++j) {
                        aggregatedInstructions[oldLen + j] = newInstructions[j];
                    }

                    // Update the bond instructions in the current record
                    claimRecords_[currentRecordIndex].bondInstructions = aggregatedInstructions;
                }

                // Increment span to include this aggregated proposal
                claimRecords_[currentRecordIndex].span++;
            } else {
                // Start a new record for non-continuous proposal
                LibBonds.BondInstruction[] memory instructions =
                    _calculateBondInstructions(_config, _proposals[i], _claims[i]);

                currentRecordIndex = finalRecordCount;
                currentGroupStartId = _proposals[i].id;
                claimRecords_[currentRecordIndex] =
                    ClaimRecord({ claim: _claims[i], span: 1, bondInstructions: instructions });
                finalRecordCount++;
            }
        }

        // Resize the claimRecords_ array to final size using assembly
        assembly {
            mstore(claimRecords_, finalRecordCount)
        }
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

        ExtendedClaimRecord storage record =
            proposalRingBuffer[bufferSlot].claimHashLookup[_DEFAULT_SLOT_HASH];

        (uint48 proposalId, bytes32 partialParentClaimHash) =
            _decodeSlotReuseMarker(record.slotReuseMarker);

        // If the reusable slot's proposal ID does not match the given proposal ID, it indicates
        // that there are no claims associated with this proposal at all.
        if (proposalId != _proposalId) return bytes32(0);

        // If there's a record in the default slot with matching parent claim hash, return it
        if (_isPartialParentClaimHashMatch(partialParentClaimHash, _parentClaimHash)) {
            return record.claimRecordHash;
        }

        // Otherwise check the direct mapping
        return proposalRingBuffer[bufferSlot].claimHashLookup[_parentClaimHash].claimRecordHash;
    }

    /// @dev Sets the claim record hash for a given proposal and parent claim.
    /// @notice This implementation tries to reuse a default slot to save gas.
    function _setClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
        override
    {
        ProposalRecord storage proposalRecord =
            proposalRingBuffer[_proposalId % _config.ringBufferSize];

        ExtendedClaimRecord storage record = proposalRecord.claimHashLookup[_DEFAULT_SLOT_HASH];

        (uint48 proposalId, bytes32 partialParentClaimHash) =
            _decodeSlotReuseMarker(record.slotReuseMarker);

        // Check if we need to use the default slot
        if (proposalId != _proposalId) {
            // Different proposal ID, so we can use the default slot
            record.claimRecordHash = _claimRecordHash;
            record.slotReuseMarker = _encodeSlotReuseMarker(_proposalId, _parentClaimHash);
        } else if (_isPartialParentClaimHashMatch(partialParentClaimHash, _parentClaimHash)) {
            // Same proposal ID and same parent claim hash (partial match), update the default slot
            record.claimRecordHash = _claimRecordHash;
        } else {
            // Same proposal ID but different parent claim hash, use direct mapping
            proposalRecord.claimHashLookup[_parentClaimHash].claimRecordHash = _claimRecordHash;
        }
    }

    // ---------------------------------------------------------------
    // Private Functions - Slot Reuse Helpers
    // ---------------------------------------------------------------

    /// @dev Decodes a slot reuse marker into proposal ID and partial parent claim hash.
    function _decodeSlotReuseMarker(uint256 _slotReuseMarker)
        private
        pure
        returns (uint48 proposalId_, bytes32 partialParentClaimHash_)
    {
        proposalId_ = uint48(_slotReuseMarker >> 208);
        partialParentClaimHash_ = bytes32(_slotReuseMarker << 48);
    }

    /// @dev Encodes a proposal ID and parent claim hash into a slot reuse marker.
    function _encodeSlotReuseMarker(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        private
        pure
        returns (uint256 slotReuseMarker_)
    {
        slotReuseMarker_ = (uint256(_proposalId) << 208) | (uint256(_parentClaimHash) >> 48);
    }

    /// @dev Checks if two parent claim hashes match in their high 208 bits.
    function _isPartialParentClaimHashMatch(
        bytes32 _partialParentClaimHash,
        bytes32 _parentClaimHash
    )
        private
        pure
        returns (bool)
    {
        return _partialParentClaimHash >> 48 == bytes32(uint256(_parentClaimHash) >> 48);
    }
}
