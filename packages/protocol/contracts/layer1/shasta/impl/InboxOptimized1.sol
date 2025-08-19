// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Inbox} from "./Inbox.sol";
import {LibBonds} from "src/shared/based/libs/LibBonds.sol";

/// @title InboxOptimized1
/// @notice Inbox optimized to allow slot reuse and claim aggregation.
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimized1 is Inbox {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    bytes32 private constant _DEFAULT_SLOT_HASH = bytes32(uint256(1));

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() Inbox() {}

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @dev Builds then saves claim records for multiple proposals and claims with aggregation for
    /// continuous proposals
    function _buildAndSaveClaimRecords(
        Config memory _config,
        Proposal[] memory _proposals,
        Claim[] memory _claims
    ) internal override {
        if (_proposals.length == 0) return;

        // Validate first proposal and create initial claim record
        _validateClaim(_config, _proposals[0], _claims[0]);
        LibBonds.BondInstruction[]
            memory currentInstructions = _calculateBondInstructions(
                _config,
                _proposals[0],
                _claims[0]
            );

        // Initialize current aggregation state
        ClaimRecord memory currentRecord = ClaimRecord({
            span: 1,
            bondInstructions: currentInstructions,
            parentClaimHash: _claims[0].parentClaimHash,
            claimHash: _hashClaim(_claims[0]),
            endBlockMiniHeaderHash: keccak256(
                abi.encode(_claims[0].endBlockMiniHeader)
            )
        });

        uint48 currentGroupStartId = _proposals[0].id;

        // Process remaining proposals
        for (uint256 i = 1; i < _proposals.length; ++i) {
            require(
                _claims[i].parentClaimHash != _DEFAULT_SLOT_HASH,
                InvalidParentClaimHash()
            );
            _validateClaim(_config, _proposals[i], _claims[i]);

            // Check if current proposal can be aggregated with the previous group
            // The next expected proposal ID is: start of current group + current span
            uint48 nextExpectedId = currentGroupStartId + currentRecord.span;
            if (_proposals[i].id == nextExpectedId) {
                // Aggregate with current record
                LibBonds.BondInstruction[]
                    memory newInstructions = _calculateBondInstructions(
                        _config,
                        _proposals[i],
                        _claims[i]
                    );

                if (newInstructions.length > 0) {
                    // Create new array with combined size
                    uint256 oldLen = currentRecord.bondInstructions.length;
                    uint256 newLen = oldLen + newInstructions.length;
                    LibBonds.BondInstruction[]
                        memory aggregatedInstructions = new LibBonds.BondInstruction[](
                            newLen
                        );

                    // Copy existing instructions
                    for (uint256 j = 0; j < oldLen; ++j) {
                        aggregatedInstructions[j] = currentRecord
                            .bondInstructions[j];
                    }

                    // Copy new instructions
                    for (uint256 j = 0; j < newInstructions.length; ++j) {
                        aggregatedInstructions[oldLen + j] = newInstructions[j];
                    }

                    // Update the bond instructions in the current record
                    currentRecord.bondInstructions = aggregatedInstructions;
                }

                // Update the claim hash and end block mini header hash for the aggregated record
                currentRecord.claimHash = _hashClaim(_claims[i]);
                currentRecord.endBlockMiniHeaderHash = keccak256(
                    abi.encode(_claims[i].endBlockMiniHeader)
                );

                // Increment span to include this aggregated proposal
                currentRecord.span++;
            } else {
                // Save the current aggregated record before starting a new one
                bytes32 recordHash = keccak256(abi.encode(currentRecord));
                _setClaimRecordHash(
                    _config,
                    currentGroupStartId,
                    currentRecord.parentClaimHash,
                    recordHash
                );
                emit Proved(encodeProveEventData(currentRecord));

                // Start a new record for non-continuous proposal
                LibBonds.BondInstruction[]
                    memory instructions = _calculateBondInstructions(
                        _config,
                        _proposals[i],
                        _claims[i]
                    );

                currentGroupStartId = _proposals[i].id;
                currentRecord = ClaimRecord({
                    span: 1,
                    bondInstructions: instructions,
                    parentClaimHash: _claims[i].parentClaimHash,
                    claimHash: _hashClaim(_claims[i]),
                    endBlockMiniHeaderHash: keccak256(
                        abi.encode(_claims[i].endBlockMiniHeader)
                    )
                });
            }
        }

        // Save the final aggregated record
        bytes32 claimRecordHash = keccak256(abi.encode(currentRecord));
        _setClaimRecordHash(
            _config,
            currentGroupStartId,
            currentRecord.parentClaimHash,
            claimRecordHash
        );
        emit Proved(encodeProveEventData(currentRecord));
    }

    /// @dev Gets the claim record hash for a given proposal and parent claim.
    /// @notice This implementation tries to reuse a default slot to save gas.
    function _getClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash
    ) internal view override returns (bytes32 claimRecordHash_) {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        ExtendedClaimRecord storage record = _claimHashLookup[bufferSlot][
            _DEFAULT_SLOT_HASH
        ];

        (
            uint48 proposalId,
            bytes32 partialParentClaimHash
        ) = _decodeSlotReuseMarker(record.slotReuseMarker);

        // If the reusable slot's proposal ID does not match the given proposal ID, it indicates
        // that there are no claims associated with this proposal at all.
        if (proposalId != _proposalId) return bytes32(0);

        // If there's a record in the default slot with matching parent claim hash, return it
        if (
            _isPartialParentClaimHashMatch(
                partialParentClaimHash,
                _parentClaimHash
            )
        ) {
            return record.claimRecordHash;
        }

        // Otherwise check the direct mapping
        return _claimHashLookup[bufferSlot][_parentClaimHash].claimRecordHash;
    }

    /// @dev Sets the claim record hash for a given proposal and parent claim.
    /// @notice This implementation tries to reuse a default slot to save gas.
    function _setClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    ) internal override {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        ExtendedClaimRecord storage record = _claimHashLookup[bufferSlot][
            _DEFAULT_SLOT_HASH
        ];

        (
            uint48 proposalId,
            bytes32 partialParentClaimHash
        ) = _decodeSlotReuseMarker(record.slotReuseMarker);

        // Check if we need to use the default slot
        if (proposalId != _proposalId) {
            // Different proposal ID, so we can use the default slot
            record.claimRecordHash = _claimRecordHash;
            record.slotReuseMarker = _encodeSlotReuseMarker(
                _proposalId,
                _parentClaimHash
            );
        } else if (
            _isPartialParentClaimHashMatch(
                partialParentClaimHash,
                _parentClaimHash
            )
        ) {
            // Same proposal ID and same parent claim hash (partial match), update the default slot
            record.claimRecordHash = _claimRecordHash;
        } else {
            // Same proposal ID but different parent claim hash, use direct mapping
            _claimHashLookup[bufferSlot][_parentClaimHash]
                .claimRecordHash = _claimRecordHash;
        }
    }

    // ---------------------------------------------------------------
    // Private Functions - Slot Reuse Helpers
    // ---------------------------------------------------------------

    /// @dev Decodes a slot reuse marker into proposal ID and partial parent claim hash.
    function _decodeSlotReuseMarker(
        uint256 _slotReuseMarker
    )
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
    ) private pure returns (uint256 slotReuseMarker_) {
        slotReuseMarker_ =
            (uint256(_proposalId) << 208) |
            (uint256(_parentClaimHash) >> 48);
    }

    /// @dev Checks if two parent claim hashes match in their high 208 bits.
    function _isPartialParentClaimHashMatch(
        bytes32 _partialParentClaimHash,
        bytes32 _parentClaimHash
    ) private pure returns (bool) {
        return
            _partialParentClaimHash >> 48 ==
            bytes32(uint256(_parentClaimHash) >> 48);
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidParentClaimHash();
}
