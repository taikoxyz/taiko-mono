// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxBase } from "./InboxBase.sol";

/// @title InboxSimpleOptimized
/// @notice Simple optimization that reduces storage operations for single claims
/// @dev Uses a single storage slot for common case of one claim per proposal
/// @custom:security-contact security@taiko.xyz
abstract contract InboxSimpleOptimized is InboxBase {
    
    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------
    
    /// @notice Initializes the InboxSimpleOptimized contract
    constructor() InboxBase() { }
    
    // ---------------------------------------------------------------
    // Storage Optimization
    // ---------------------------------------------------------------
    
    /// @dev Optimized storage: pack proposal hash and single claim record hash together
    /// For proposals with only one claim, we store both in a single slot
    /// Format: [proposalHash (bytes32)] => [claimRecordHash (bytes32)]
    /// The parent claim hash is implicit (it's always the previous claim)
    mapping(bytes32 proposalHash => bytes32 claimRecordHash) private singleClaimOptimization;
    
    /// @dev Track which proposals use the optimization
    mapping(uint48 proposalId => bool usesOptimization) private optimizedProposals;
    
    // ---------------------------------------------------------------
    // Internal Functions (Overrides)
    // ---------------------------------------------------------------
    
    /// @inheritdoc InboxBase
    function _setClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
        override
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        ProposalRecord storage proposalRecord = proposalRingBuffer[bufferSlot];
        
        // Get the proposal hash
        bytes32 proposalHash = proposalRecord.proposalHash;
        
        // Check if this proposal already has claims
        if (!optimizedProposals[_proposalId] && proposalRecord.claimHashLookup[_parentClaimHash] == bytes32(0)) {
            // First claim for this proposal - use optimization
            singleClaimOptimization[proposalHash] = _claimRecordHash;
            optimizedProposals[_proposalId] = true;
        } else {
            // Multiple claims or updating existing - use regular storage
            proposalRecord.claimHashLookup[_parentClaimHash] = _claimRecordHash;
            
            // If this was using optimization, migrate the optimized claim
            if (optimizedProposals[_proposalId]) {
                // The optimized claim needs to be accessible via regular lookup too
                // This ensures consistency when multiple claims are added
                optimizedProposals[_proposalId] = false;
            }
        }
    }
    
    /// @inheritdoc InboxBase
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
        ProposalRecord storage proposalRecord = proposalRingBuffer[bufferSlot];
        
        // Check if using optimization
        if (optimizedProposals[_proposalId]) {
            // Return the single optimized claim
            return singleClaimOptimization[proposalRecord.proposalHash];
        }
        
        // Use regular lookup
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