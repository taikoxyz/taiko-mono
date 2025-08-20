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
        Proposal[] memory _proposals,
        Claim[] memory _claims
    )
        internal
        override
    {
        if (_proposals.length == 0) return;

        // Validate first proposal

        _validateClaim(_config, _proposals[0], _claims[0]);

        // Initialize current aggregation state
        ClaimRecord memory currentRecord = ClaimRecord({
            span: 1,
            bondInstructions: _calculateBondInstructions(_config, _proposals[0], _claims[0]),
            claimHash: _hashClaim(_claims[0]),
            endBlockMiniHeaderHash: _hashBlockMiniHeader(_claims[0].endBlockMiniHeader)
        });

        uint48 currentGroupStartId = _proposals[0].id;
        Claim memory firstClaimInGroup = _claims[0];

        // Process remaining proposals
        for (uint256 i = 1; i < _proposals.length; ++i) {
            _validateClaim(_config, _proposals[i], _claims[i]);

            // Check if current proposal can be aggregated with the previous group
            if (_proposals[i].id == currentGroupStartId + currentRecord.span) {
                // Aggregate with current record
                LibBonds.BondInstruction[] memory newInstructions =
                    _calculateBondInstructions(_config, _proposals[i], _claims[i]);

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
                currentRecord.claimHash = _hashClaim(_claims[i]);
                currentRecord.endBlockMiniHeaderHash =
                    _hashBlockMiniHeader(_claims[i].endBlockMiniHeader);

                // Increment span to include this aggregated proposal
                currentRecord.span++;
            } else {
                // Save the current aggregated record before starting a new one
                _setClaimRecordHash(_config, currentGroupStartId, firstClaimInGroup, currentRecord);

                // Start a new record for non-continuous proposal
                currentGroupStartId = _proposals[i].id;
                firstClaimInGroup = _claims[i];

                currentRecord = ClaimRecord({
                    span: 1,
                    bondInstructions: _calculateBondInstructions(_config, _proposals[i], _claims[i]),
                    claimHash: _hashClaim(_claims[i]),
                    endBlockMiniHeaderHash: _hashBlockMiniHeader(_claims[i].endBlockMiniHeader)
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
        ExtendedClaimRecord storage record = _defaultRecords[bufferSlot];

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
        bytes32 compositeKey = _composeClaimKey(_proposalId, _parentClaimHash);
        return _claimHashLookup[bufferSlot][compositeKey].claimRecordHash;
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
        ExtendedClaimRecord storage record = _defaultRecords[bufferSlot];

        (uint48 proposalId, bytes32 partialParentClaimHash) =
            _decodeSlotReuseMarker(record.slotReuseMarker);

        // Check if we need to use the default slot
        if (proposalId != _proposalId) {
            // Different proposal ID, so we can use the default slot
            record.claimRecordHash = claimRecordHash;
            record.slotReuseMarker = _encodeSlotReuseMarker(_proposalId, _claim.parentClaimHash);
        } else if (_isPartialParentClaimHashMatch(partialParentClaimHash, _claim.parentClaimHash)) {
            // Same proposal ID and same parent claim hash (partial match), update the default slot
            record.claimRecordHash = claimRecordHash;
        } else {
            // Same proposal ID but different parent claim hash, use direct mapping
            bytes32 compositeKey = _composeClaimKey(_proposalId, _claim.parentClaimHash);
            _claimHashLookup[bufferSlot][compositeKey].claimRecordHash = claimRecordHash;
        }

        bytes memory payload = encodeProvedEventData(
            ProvedEventPayload({ proposalId: _proposalId, claim: _claim, claimRecord: _claimRecord })
        );
        emit Proved(payload);
    }

    /// @dev Validates that a claim is valid for a given proposal.
    /// @param _config The configuration parameters.
    /// @param _proposal The proposal to validate.
    /// @param _claim The claim to validate.
    function _validateClaim(
        Config memory _config,
        Proposal memory _proposal,
        Claim memory _claim
    )
        internal
        view
        virtual
        override
    {
        super._validateClaim(_config, _proposal, _claim);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Computes the composite key for claim record lookups.
    /// @param _proposalId The proposal ID.
    /// @param _parentClaimHash The parent claim hash.
    /// @return _ The composite key for the mapping.
    function _composeClaimKey(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_proposalId, _parentClaimHash));
    }

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
