// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IInboxStateManager
/// @notice Interface for managing Inbox state data.
/// @custom:security-contact security@taiko.xyz
interface IInboxStateManager {
    // -------------------------------------------------------------------------
    // State Management Functions
    // -------------------------------------------------------------------------

    /// @notice Sets the hash of the core state.
    /// @param _coreStateHash The hash of the core state.
    function setCoreStateHash(bytes32 _coreStateHash) external;

    /// @notice Sets the proposal hash for a given proposal ID.
    /// @param _proposalId The proposal ID.
    /// @param _proposalHash The proposal hash.
    function setProposalHash(uint48 _proposalId, bytes32 _proposalHash) external;

    /// @notice Sets the claim record hash for a given proposal and parent claim.
    /// @param _proposalId The proposal ID.
    /// @param _parentClaimHash The parent claim hash.
    /// @param _claimRecordHash The claim record hash.
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
    /// @return coreStateHash_ The hash of the core state.
    function getCoreStateHash() external view returns (bytes32 coreStateHash_);

    /// @notice Gets the proposal hash for a given proposal ID.
    /// @param _proposalId The proposal ID.
    /// @return proposalHash_ The hash of the proposal.
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_);

    /// @notice Gets the claim record hash for a given proposal and parent claim.
    /// @param _proposalId The proposal ID.
    /// @param _parentClaimHash The parent claim hash.
    /// @return claimRecordHash_ The claim record hash.
    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        external
        view
        returns (bytes32 claimRecordHash_);
}
