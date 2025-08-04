// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IShastaInbox.sol";

/// @title IShastaInboxStore
/// @notice Interface for managing ShastaInbox state data in a separate contract
/// @dev It will be idea not to import structs defined in the IShastaInbox interface here to avoid
/// storing anything but hashes.
/// @custom:security-contact security@taiko.xyz
interface IShastaInboxStore {
    // -------------------------------------------------------------------------
    // External transactional (restricted to inbox contract)
    // -------------------------------------------------------------------------

    /// @notice Initializes the store
    /// @dev Only callable by the inbox contract
    function initialize() external;

    /// @notice Sets the hash of the state
    /// @dev Only callable by the inbox contract
    /// @param _stateHash The hash of the state
    function setStateHash(bytes32 _stateHash) external;

    /// @notice Sets the synced state
    /// @dev Only callable by the inbox contract
    /// @param _syncedBlock The synced state
    function setSyncedBlock(IShastaInbox.SyncedBlock memory _syncedBlock) external;

    /// @notice Sets the proposal hash for a given proposal ID
    /// @dev Only callable by the inbox contract
    /// @param _proposalId The proposal ID
    /// @param _proposalHash The proposal hash
    function setProposalHash(uint48 _proposalId, bytes32 _proposalHash) external;

    /// @notice Sets the claim record hash for a given proposal and parent claim
    /// @dev Only callable by the inbox contract
    /// @param _proposalId The proposal ID
    /// @param _parentClaimHash The parent claim hash
    /// @param _claimRecordHash The claim record hash
    function setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        external;

    // -------------------------------------------------------------------------
    // External view
    // -------------------------------------------------------------------------

    /// @notice Gets the hash of the state
    /// @return stateHash_ The hash of the state
    function getStateHash() external view returns (bytes32 stateHash_);

    /// @notice Gets the synced state
    /// @return syncedBlock_ The synced state
    function getSyncedBlock()
        external
        view
        returns (IShastaInbox.SyncedBlock memory syncedBlock_);

    /// @notice Gets the proposal hash for a given proposal ID
    /// @param _proposalId The proposal ID
    /// @return proposalHash_ The hash of the proposal
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_);

    /// @notice Gets the claim record hash for a given proposal and parent claim
    /// @param _proposalId The proposal ID
    /// @param _parentClaimHash The parent claim hash
    /// @return claimRecordHash_ The claim record hash
    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        external
        view
        returns (bytes32 claimRecordHash_);
}
