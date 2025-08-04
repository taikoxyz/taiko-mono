// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IShastaInboxStore.sol";

/// @title ShastaInboxStore
/// @notice Contract for managing ShastaInbox state data with access control
/// @custom:security-contact security@taiko.xyz
contract ShastaInboxStore is IShastaInboxStore {
    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    address public immutable inbox;

    bytes32 private stateHash;
    IShastaInbox.SyncedBlock private syncedBlock;
    mapping(uint48 proposalId => bytes32 proposalHash) private proposalRegistry;
    mapping(uint48 proposalId => mapping(bytes32 parentClaimRecordHash => bytes32 claimRecordHash))
        private claimRecordHashLookup;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyInbox() {
        if (msg.sender != inbox) revert Unauthorized();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _inbox) {
        inbox = _inbox;
    }

    // -------------------------------------------------------------------------
    // External view
    // -------------------------------------------------------------------------

    function getStateHash() external view returns (bytes32) {
        return stateHash;
    }

    function getSyncedBlock() external view returns (IShastaInbox.SyncedBlock memory) {
        return syncedBlock;
    }

    function getProposalHash(uint48 _proposalId) external view returns (bytes32) {
        return proposalRegistry[_proposalId];
    }

    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimRecordHash
    )
        external
        view
        returns (bytes32)
    {
        return claimRecordHashLookup[_proposalId][_parentClaimRecordHash];
    }

    // -------------------------------------------------------------------------
    // External transactional (restricted to inbox)
    // -------------------------------------------------------------------------

    function initialize() external onlyInbox {
        IShastaInbox.State memory state = IShastaInbox.State({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: 0,
            bondOperationsHash: 0
        });
        stateHash = keccak256(abi.encode(state));
    }

    function setStateHash(bytes32 _stateHash) external onlyInbox {
        stateHash = _stateHash;
    }

    function setSyncedBlock(IShastaInbox.SyncedBlock memory _syncedBlock) external onlyInbox {
        syncedBlock = _syncedBlock;
    }

    function setProposalHash(uint48 _proposalId, bytes32 _proposalHash) external onlyInbox {
        proposalRegistry[_proposalId] = _proposalHash;
    }

    function setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimRecordHash,
        bytes32 _claimRecordHash
    )
        external
        onlyInbox
    {
        claimRecordHashLookup[_proposalId][_parentClaimRecordHash] = _claimRecordHash;
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error Unauthorized();
}
