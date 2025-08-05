// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IInboxStateManager
/// @notice Interface for managing Inbox state data with a ring buffer storage pattern.
/// @dev This interface defines methods for storing and retrieving proposal and claim data
/// using a ring buffer approach. When the buffer is full, old proposals are automatically
/// overwritten by new ones based on modulo arithmetic (proposalId % ringBufferSize).
/// @custom:security-contact security@taiko.xyz
interface IInboxStateManager {
    // -------------------------------------------------------------------------
    // State Management Functions
    // -------------------------------------------------------------------------

    /// @notice Sets the hash of the core state.
    /// @dev Only callable by the authorized inbox contract.
    /// @param _coreStateHash The hash of the core state containing nextProposalId,
    /// lastFinalizedProposalId, lastFinalizedClaimHash, and bondOperationsHash.
    function setCoreStateHash(bytes32 _coreStateHash) external;

    /// @notice Sets the proposal hash for a given proposal ID.
    /// @dev Uses ring buffer storage: the proposal is stored at index (proposalId %
    /// ringBufferSize).
    /// Old proposals at the same index are automatically overwritten.
    /// Only callable by the authorized inbox contract.
    /// @param _proposalId The unique identifier for the proposal.
    /// @param _proposalHash The hash of the proposal data.
    function setProposalHash(uint48 _proposalId, bytes32 _proposalHash) external;

    /// @notice Sets the claim record hash for a given proposal and parent claim.
    /// @dev Stores the claim record in the ring buffer at the proposal's slot.
    /// If the proposal has been overwritten in the ring buffer, this will associate
    /// the claim with whatever proposal currently occupies that slot.
    /// Only callable by the authorized inbox contract.
    /// @param _proposalId The proposal ID this claim is associated with.
    /// @param _parentClaimHash The hash of the parent claim in the claim chain.
    /// @param _claimRecordHash The hash of the claim record data.
    function setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        external;

    // -------------------------------------------------------------------------
    // View Functions
    // -------------------------------------------------------------------------

    /// @notice Gets the hash of the core state.
    /// @dev The core state includes critical inbox parameters like the next proposal ID
    /// and finalization status.
    /// @return coreStateHash_ The hash of the current core state.
    function getCoreStateHash() external view returns (bytes32 coreStateHash_);

    /// @notice Gets the proposal hash for a given proposal ID.
    /// @dev Retrieves from ring buffer at index (proposalId % ringBufferSize).
    /// Note: If the proposal has been overwritten, this returns the hash of whatever
    /// proposal currently occupies that buffer slot, or bytes32(0) if the slot is empty.
    /// @param _proposalId The proposal ID to look up.
    /// @return proposalHash_ The hash stored at the proposal's ring buffer slot.
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_);

    /// @notice Gets the claim record hash for a given proposal and parent claim.
    /// @dev Retrieves from the ring buffer slot calculated as (proposalId % ringBufferSize).
    /// Note: If the original proposal has been overwritten, this returns claim data
    /// associated with whatever proposal currently occupies that buffer slot.
    /// @param _proposalId The proposal ID to look up.
    /// @param _parentClaimHash The parent claim hash to look up.
    /// @return claimRecordHash_ The claim record hash, or bytes32(0) if not found.
    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        external
        view
        returns (bytes32 claimRecordHash_);

    /// @notice Gets the capacity for unfinalized proposals.
    /// @dev The difference between nextProposalId and lastFinalizedProposalId cannot exceed
    /// this capacity.
    /// @return _ The maximum number of unfinalized proposals that can exist.
    function getUnfinalizedProposalCapacity() external view returns (uint256);
}
