// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IInbox.sol";

/// @title LibState
/// @notice Library for managing ShastaInbox state data.
/// @custom:security-contact security@taiko.xyz
library LibState {
    // -------------------------------------------------------------------------
    // State Management Functions
    // -------------------------------------------------------------------------

    /// @notice Initializes the state.
    /// @param _state The state to initialize.
    function initialize(IInbox.State storage _state) internal {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: 0,
            bondOperationsHash: 0
        });
        _state.coreStateHash = keccak256(abi.encode(coreState));
    }

    /// @notice Sets the hash of the core state.
    /// @param _state The state to update.
    /// @param _coreStateHash The hash of the core state.
    function setCoreStateHash(IInbox.State storage _state, bytes32 _coreStateHash) internal {
        _state.coreStateHash = _coreStateHash;
    }

    /// @notice Sets the synced block.
    /// @param _state The state to update.
    /// @param _syncedBlock The synced block data.
    function setSyncedBlock(
        IInbox.State storage _state,
        IInbox.SyncedBlock memory _syncedBlock
    )
        internal
    {
        _state.syncedBlock = _syncedBlock;
    }

    /// @notice Sets the proposal hash for a given proposal ID.
    /// @param _state The state to update.
    /// @param _proposalId The proposal ID.
    /// @param _proposalHash The proposal hash.
    function setProposalHash(
        IInbox.State storage _state,
        uint48 _proposalId,
        bytes32 _proposalHash
    )
        internal
    {
        _state.proposalRegistry[_proposalId] = _proposalHash;
    }

    /// @notice Sets the claim record hash for a given proposal and parent claim.
    /// @param _state The state to update.
    /// @param _proposalId The proposal ID.
    /// @param _parentClaimHash The parent claim hash.
    /// @param _claimRecordHash The claim record hash.
    function setClaimRecordHash(
        IInbox.State storage _state,
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
    {
        _state.claimRecordHashLookup[_proposalId][_parentClaimHash] = _claimRecordHash;
    }

    /// @notice Sets the L2 bond credits hash.
    /// @param _state The state to update.
    /// @param _l2BondCreditsHash The L2 bond credits hash.
    function setL2BondCreditsHash(
        IInbox.State storage _state,
        bytes32 _l2BondCreditsHash
    )
        internal
    {
        _state.l2BondCreditsHash = _l2BondCreditsHash;
    }

    // -------------------------------------------------------------------------
    // View Functions
    // -------------------------------------------------------------------------

    /// @notice Gets the hash of the core state.
    /// @param _state The state to read from.
    /// @return coreStateHash_ The hash of the core state.
    function getCoreStateHash(IInbox.State storage _state)
        internal
        view
        returns (bytes32 coreStateHash_)
    {
        coreStateHash_ = _state.coreStateHash;
    }

    /// @notice Gets the synced block.
    /// @param _state The state to read from.
    /// @return syncedBlock_ The synced block data.
    function getSyncedBlock(IInbox.State storage _state)
        internal
        view
        returns (IInbox.SyncedBlock memory syncedBlock_)
    {
        syncedBlock_ = _state.syncedBlock;
    }

    /// @notice Gets the proposal hash for a given proposal ID.
    /// @param _state The state to read from.
    /// @param _proposalId The proposal ID.
    /// @return proposalHash_ The hash of the proposal.
    function getProposalHash(
        IInbox.State storage _state,
        uint48 _proposalId
    )
        internal
        view
        returns (bytes32 proposalHash_)
    {
        proposalHash_ = _state.proposalRegistry[_proposalId];
    }

    /// @notice Gets the claim record hash for a given proposal and parent claim.
    /// @param _state The state to read from.
    /// @param _proposalId The proposal ID.
    /// @param _parentClaimHash The parent claim hash.
    /// @return claimRecordHash_ The claim record hash.
    function getClaimRecordHash(
        IInbox.State storage _state,
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        internal
        view
        returns (bytes32 claimRecordHash_)
    {
        claimRecordHash_ = _state.claimRecordHashLookup[_proposalId][_parentClaimHash];
    }

    /// @notice Gets the L2 bond credits hash.
    /// @param _state The state to read from.
    /// @return l2BondCreditsHash_ The L2 bond credits hash.
    function getL2BondCreditsHash(IInbox.State storage _state)
        internal
        view
        returns (bytes32 l2BondCreditsHash_)
    {
        l2BondCreditsHash_ = _state.l2BondCreditsHash;
    }
}
