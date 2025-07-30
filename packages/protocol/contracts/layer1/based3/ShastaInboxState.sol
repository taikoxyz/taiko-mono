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
        bytes32 bondRefundsHash;
        // Mappings (separate storage)
        mapping(uint48 proposalId => bytes32 proposalHash) proposalRegistry;
        mapping(uint48 proposalId => mapping(bytes32 parentClaimHash => bytes32 claimRecordHash))
            claimRecordHashLookup;
    }

    // -------------------------------------------------------------------------
    // Read Functions
    // -------------------------------------------------------------------------

    function getNextProposalId(State storage _state) internal view returns (uint48) {
        return _state.nextProposalId;
    }

    function getLastFinalizedProposalId(State storage _state) internal view returns (uint48) {
        return _state.lastFinalizedProposalId;
    }

    function getLastFinalizedClaimHash(State storage _state) internal view returns (bytes32) {
        return _state.lastFinalizedClaimHash;
    }

    function getLastL2BlockNumber(State storage _state) internal view returns (uint48) {
        return _state.lastL2BlockNumber;
    }

    function getLastL2BlockHash(State storage _state) internal view returns (bytes32) {
        return _state.lastL2BlockHash;
    }

    function getLastL2StateRoot(State storage _state) internal view returns (bytes32) {
        return _state.lastL2StateRoot;
    }

    function getBondRefundsHash(State storage _state) internal view returns (bytes32) {
        return _state.bondRefundsHash;
    }

    function getProposalHash(
        State storage _state,
        uint48 _proposalId
    )
        internal
        view
        returns (bytes32)
    {
        return _state.proposalRegistry[_proposalId];
    }

    function getClaimRecordHash(
        State storage _state,
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        internal
        view
        returns (bytes32)
    {
        return _state.claimRecordHashLookup[_proposalId][_parentClaimHash];
    }

    // -------------------------------------------------------------------------
    // Write Functions
    // -------------------------------------------------------------------------

    function initialize(State storage _state) internal {
        _state.nextProposalId = 1;
    }

    function incrementAndGetProposalId(State storage _state) internal returns (uint48) {
        return _state.nextProposalId++;
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

    function setBondRefundsHash(State storage _state, bytes32 _hash) internal {
        _state.bondRefundsHash = _hash;
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
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
    {
        _state.claimRecordHashLookup[_proposalId][_parentClaimHash] = _claimRecordHash;
    }
}
