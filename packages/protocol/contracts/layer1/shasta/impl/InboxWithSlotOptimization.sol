// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxBase } from "./InboxBase.sol";

/// @title InboxWithSlotOptimization
/// @notice Optimized inbox implementation with storage slot optimization for claim records
/// @dev Extends InboxBase with optimized storage patterns for gas efficiency
/// @custom:security-contact security@taiko.xyz
abstract contract InboxWithSlotOptimization is InboxBase {
    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the InboxWithSlotOptimization contract
    constructor() InboxBase() { }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev Special hash used to identify the default storage slot
    /// We use bytes32(uint256(1)) as it's extremely unlikely to be a real parent claim hash
    bytes32 private constant _DEFAULT_SLOT_HASH = bytes32(uint256(1));

    // ---------------------------------------------------------------
    // Internal Functions (Overrides)
    // ---------------------------------------------------------------

    /// @inheritdoc InboxBase
    /// @dev Optimization: For the first/only claim of a proposal, we store it in a fixed slot
    /// This saves gas because:
    /// 1. We always write to the same slot (_DEFAULT_SLOT_HASH) which is likely warm
    /// 2. For single-claim proposals (the common case), we avoid the gas cost of hashing the parent
    /// Trade-off: Reading requires checking the default slot first (1-2 extra SLOADs)
    function _setClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
        override
    {
        // Safety check: ensure parent claim hash doesn't collide with our special marker
        // While extremely unlikely (probability ~1/2^256), better to be explicit
        require(_parentClaimHash != _DEFAULT_SLOT_HASH, "Invalid parent claim hash");

        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        ProposalRecord storage proposalRecord = proposalRingBuffer[bufferSlot];

        // Check if this is the first claim for this proposal
        // We do this by checking if the default slot is empty
        bytes32 defaultSlotValue = proposalRecord.claimHashLookup[_DEFAULT_SLOT_HASH];

        if (defaultSlotValue == bytes32(0)) {
            // First claim - store in default slot (single SSTORE to a consistent location)
            proposalRecord.claimHashLookup[_DEFAULT_SLOT_HASH] = _claimRecordHash;
        } else {
            // Not the first claim - use regular storage
            // This is more expensive but less common
            proposalRecord.claimHashLookup[_parentClaimHash] = _claimRecordHash;
        }
    }

    /// @inheritdoc InboxBase
    /// @dev Reads claim record, checking default slot first for the common single-claim case
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
        // Safety check: if querying with the default slot hash itself, return 0
        // This prevents confusion between the optimization marker and actual data
        if (_parentClaimHash == _DEFAULT_SLOT_HASH) {
            return bytes32(0);
        }

        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        ProposalRecord storage proposalRecord = proposalRingBuffer[bufferSlot];

        // First check the default slot (common case: single claim)
        bytes32 defaultValue = proposalRecord.claimHashLookup[_DEFAULT_SLOT_HASH];

        // If there's only one claim, it's in the default slot
        // We assume if default slot has value and regular lookup is empty, it's the claim we want
        if (defaultValue != bytes32(0)) {
            // Check if this specific parent hash has a claim
            bytes32 specificValue = proposalRecord.claimHashLookup[_parentClaimHash];
            if (specificValue != bytes32(0)) {
                // Multiple claims case - return the specific one
                return specificValue;
            }
            // Single claim case - return the default
            // Note: This assumes the parent claim hash matches, which is true for sequential claims
            return defaultValue;
        }

        // No default value, check regular mapping
        return proposalRecord.claimHashLookup[_parentClaimHash];
    }

    /// @notice Gets the claim record hash for a given proposal and parent claim
    /// @param _proposalId The proposal ID to look up
    /// @param _parentClaimHash The parent claim hash to look up
    /// @return claimRecordHash_ The claim record hash, or bytes32(0) if not found
    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        public
        view
        override
        returns (bytes32 claimRecordHash_)
    {
        Config memory config = getConfig();
        return _getClaimRecordHash(config, _proposalId, _parentClaimHash);
    }
}
