// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Inbox.sol";

/// @title InboxWithSlotReuse
/// @notice Extends Inbox to implement slot reuse optimization for claim record storage.
/// @dev This contract overrides the claim record hash getter and setter to optimize storage
/// by reusing a default slot when possible.
/// @custom:security-contact security@taiko.xyz
abstract contract InboxWithSlotReuse is Inbox {
    // -------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------

    bytes32 private constant _DEFAULT_SLOT_HASH = bytes32(uint256(1));

    // -------------------------------------------------------------------
    // Internal Functions - Overrides
    // -------------------------------------------------------------------

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

    // -------------------------------------------------------------------
    // Private Functions - Slot Reuse Helpers
    // -------------------------------------------------------------------

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
