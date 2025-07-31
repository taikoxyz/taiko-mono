// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IShastaInboxStore
/// @notice Interface for managing ShastaInbox state data in a separate contract
/// @dev It will be idea not to import structs defined in the IShastaInbox interface here to avoid
/// storing anything but hashes.
/// @custom:security-contact security@taiko.xyz
interface IShastaInboxStore {
    // -------------------------------------------------------------------------
    // External view
    // -------------------------------------------------------------------------

    /// @notice Gets the next proposal ID
    /// @return nextProposalId_ The next proposal ID to be used
    function getNextProposalId() external view returns (uint48 nextProposalId_);

    /// @notice Gets the last finalized proposal ID
    /// @return lastFinalizedProposalId_ The ID of the last finalized proposal
    function getLastFinalizedProposalId() external view returns (uint48 lastFinalizedProposalId_);

    /// @notice Gets the hash of the last finalized claim
    /// @return lastFinalizedClaimHash_ The hash of the last finalized claim record
    function getLastFinalizedClaimHash() external view returns (bytes32 lastFinalizedClaimHash_);

    /// @notice Gets the last L2 block number
    /// @return lastL2BlockNumber_ The number of the last L2 block
    function getLastL2BlockNumber() external view returns (uint48 lastL2BlockNumber_);

    /// @notice Gets the last L2 block hash
    /// @return lastL2BlockHash_ The hash of the last L2 block
    function getLastL2BlockHash() external view returns (bytes32 lastL2BlockHash_);

    /// @notice Gets the last L2 state root
    /// @return lastL2StateRoot_ The state root of the last L2 block
    function getLastL2StateRoot() external view returns (bytes32 lastL2StateRoot_);

    /// @notice Gets the L2 bond refunds hash
    /// @return l2BondPaymentsHash_ The cumulative hash of bond refunds
    function getL2BondPaymentHash() external view returns (bytes32 l2BondPaymentsHash_);

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

    // -------------------------------------------------------------------------
    // External transactional (restricted to inbox contract)
    // -------------------------------------------------------------------------

    /// @notice Initializes the store
    /// @dev Only callable by the inbox contract
    function initialize() external;

    /// @notice Increments and returns the next proposal ID
    /// @dev Only callable by the inbox contract
    /// @return proposalId_ The newly incremented proposal ID
    function incrementAndGetProposalId() external returns (uint48 proposalId_);

    /// @notice Sets the last finalized proposal ID and claim hash
    /// @dev Only callable by the inbox contract
    /// @param _proposalId The finalized proposal ID
    /// @param _claimRecordHash The finalized claim record hash
    function setLastFinalized(uint48 _proposalId, bytes32 _claimRecordHash) external;

    /// @notice Sets the last L2 block data
    /// @dev Only callable by the inbox contract
    /// @param _blockNumber The L2 block number
    /// @param _blockHash The L2 block hash
    /// @param _stateRoot The L2 state root
    function setLastL2BlockData(
        uint48 _blockNumber,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        external;

    /// @notice Sets the L2 bond refunds hash
    /// @dev Only callable by the inbox contract
    /// @param _l2BondPaymentHash The bond payment hash to aggregate
    function aggregateL2BondPayment(bytes32 _l2BondPaymentHash) external;

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
    // Errors
    // -------------------------------------------------------------------------

    error Unauthorized();
}
