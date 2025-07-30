// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ShastaInboxState
/// @notice Library for managing ShastaInbox state with read/write functions
/// @custom:security-contact security@taiko.xyz
library ShastaInboxState {
    struct State {
        // Slot 1: 48 + 48 + 48 = 144 bits
        uint48 nextProposalId;
        uint48 lastFinalizedProposalId;
        uint48 lastL2BlockNumber;
        // Remaining 112 bits unused
        // Slot 2
        bytes32 lastFinalizedClaimHash;
        // Slot 3
        bytes32 lastL2BlockHash;
        // Slot 4
        bytes32 lastL2StateRoot;
        // Slot 5
        bytes32 l2BondRefundsHash;
        // Mappings (separate storage)
        mapping(uint48 proposalId => bytes32 proposalHash) proposalRegistry;
        mapping(
            uint48 proposalId => mapping(bytes32 parentClaimRecordHash => bytes32 claimRecordHash)
        ) claimRecordHashLookup;
    }

    // -------------------------------------------------------------------------
    // Read Functions
    // -------------------------------------------------------------------------

    function getNextProposalId(State storage _state)
        internal
        view
        returns (uint48 nextProposalId_)
    {
        nextProposalId_ = _state.nextProposalId;
    }

    function getLastFinalizedProposalId(State storage _state)
        internal
        view
        returns (uint48 lastFinalizedProposalId_)
    {
        lastFinalizedProposalId_ = _state.lastFinalizedProposalId;
    }

    function getLastFinalizedClaimHash(State storage _state)
        internal
        view
        returns (bytes32 lastFinalizedClaimHash_)
    {
        lastFinalizedClaimHash_ = _state.lastFinalizedClaimHash;
    }

    function getLastL2BlockNumber(State storage _state)
        internal
        view
        returns (uint48 lastL2BlockNumber_)
    {
        lastL2BlockNumber_ = _state.lastL2BlockNumber;
    }

    function getLastL2BlockHash(State storage _state)
        internal
        view
        returns (bytes32 lastL2BlockHash_)
    {
        lastL2BlockHash_ = _state.lastL2BlockHash;
    }

    function getLastL2StateRoot(State storage _state)
        internal
        view
        returns (bytes32 lastL2StateRoot_)
    {
        lastL2StateRoot_ = _state.lastL2StateRoot;
    }

    function getL2BondRefundHash(State storage _state)
        internal
        view
        returns (bytes32 l2BondRefundsHash_)
    {
        l2BondRefundsHash_ = _state.l2BondRefundsHash;
    }

    function getProposalHash(
        State storage _state,
        uint48 _proposalId
    )
        internal
        view
        returns (bytes32 proposalHash_)
    {
        proposalHash_ = _state.proposalRegistry[_proposalId];
    }

    function getClaimRecordHash(
        State storage _state,
        uint48 _proposalId,
        bytes32 _parentClaimRecordHash
    )
        internal
        view
        returns (bytes32 claimRecordHash_)
    {
        claimRecordHash_ = _state.claimRecordHashLookup[_proposalId][_parentClaimRecordHash];
    }

    // -------------------------------------------------------------------------
    // Write Functions
    // -------------------------------------------------------------------------

    function initialize(State storage _state) internal {
        _state.nextProposalId = 1;
    }

    function incrementAndGetProposalId(State storage _state)
        internal
        returns (uint48 proposalId_)
    {
        proposalId_ = _state.nextProposalId++;
    }

    function setLastFinalized(
        State storage _state,
        uint48 _proposalId,
        bytes32 _claimRecordHash
    )
        internal
    {
        _state.lastFinalizedProposalId = _proposalId;
        _state.lastFinalizedClaimHash = _claimRecordHash;
    }

    function setLastL2BlockData(
        State storage _state,
        uint48 _blockNumber,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        internal
    {
        _state.lastL2BlockNumber = _blockNumber;
        _state.lastL2BlockHash = _blockHash;
        _state.lastL2StateRoot = _stateRoot;
    }

    function setL2BondRefundsHash(State storage _state, bytes32 _hash) internal {
        _state.l2BondRefundsHash = _hash;
    }

    function setProposalHash(
        State storage _state,
        uint48 _proposalId,
        bytes32 _proposalHash
    )
        internal
    {
        _state.proposalRegistry[_proposalId] = _proposalHash;
    }

    function setClaimRecordHash(
        State storage _state,
        uint48 _proposalId,
        bytes32 _parentClaimRecordHash,
        bytes32 _claimRecordHash
    )
        internal
    {
        _state.claimRecordHashLookup[_proposalId][_parentClaimRecordHash] = _claimRecordHash;
    }
}
