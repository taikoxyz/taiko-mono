// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IShastaInboxStore.sol";

/// @title ShastaInboxStore
/// @notice Contract for managing ShastaInbox state data with access control.
/// @custom:security-contact security@taiko.xyz
contract ShastaInboxStore is IShastaInboxStore {
    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    address public immutable inbox;

    bytes32 private stateHash;
    IShastaInbox.SyncedBlock private syncedBlock;
    /// @dev Maps proposal ID to proposal hash.
    mapping(uint48 proposalId => bytes32 proposalHash) private proposalRegistry;
    /// @dev Maps proposal ID and parent claim record hash to claim record hash.
    mapping(uint48 proposalId => mapping(bytes32 parentClaimRecordHash => bytes32 claimRecordHash))
        private claimRecordHashLookup;

    bytes32 private l2BondCreditsHash;

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
    // External View Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IShastaInboxStore
    function getStateHash() external view returns (bytes32) {
        return stateHash;
    }

    /// @inheritdoc IShastaInboxStore
    function getSyncedBlock() external view returns (IShastaInbox.SyncedBlock memory) {
        return syncedBlock;
    }

    /// @inheritdoc IShastaInboxStore
    function getProposalHash(uint48 _proposalId) external view returns (bytes32) {
        return proposalRegistry[_proposalId];
    }

    /// @inheritdoc IShastaInboxStore
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

    /// @notice Returns the hash of bond credits.
    /// @return bondCreditsHash_ The hash of bond credits.
    function getBondCreditsHash() external view returns (bytes32 bondCreditsHash_) {
        bondCreditsHash_ = l2BondCreditsHash;
    }

    // -------------------------------------------------------------------------
    // External Transactional Functions (Restricted to Inbox)
    // -------------------------------------------------------------------------

    /// @inheritdoc IShastaInboxStore
    function initialize() external onlyInbox {
        IShastaInbox.CoreState memory coreState = IShastaInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: 0,
            bondOperationsHash: 0
        });
        stateHash = keccak256(abi.encode(coreState));
    }

    /// @inheritdoc IShastaInboxStore
    function setStateHash(bytes32 _stateHash) external onlyInbox {
        stateHash = _stateHash;
    }

    /// @inheritdoc IShastaInboxStore
    function setSyncedBlock(IShastaInbox.SyncedBlock memory _syncedBlock) external onlyInbox {
        syncedBlock = _syncedBlock;
    }

    /// @inheritdoc IShastaInboxStore
    function setProposalHash(uint48 _proposalId, bytes32 _proposalHash) external onlyInbox {
        proposalRegistry[_proposalId] = _proposalHash;
    }

    /// @inheritdoc IShastaInboxStore
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
