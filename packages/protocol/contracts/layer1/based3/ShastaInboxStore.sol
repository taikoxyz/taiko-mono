// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IShastaInboxStore } from "./IShastaInboxStore.sol";

/// @title ShastaInboxStore
/// @notice Contract for managing ShastaInbox state data with access control
/// @custom:security-contact security@taiko.xyz
contract ShastaInboxStore is IShastaInboxStore {
    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    address public immutable inbox;

    // Slot 1: 48 + 48 + 48 = 144 bits
    uint48 private nextProposalId;
    uint48 private lastFinalizedProposalId;
    uint48 private lastL2BlockNumber;
    // Remaining 112 bits unused
    // Slot 2
    bytes32 private lastFinalizedClaimHash;
    // Slot 3
    bytes32 private lastL2BlockHash;
    // Slot 4
    bytes32 private lastL2StateRoot;
    // Slot 5
    bytes32 private l2BondPaymentsHash;
    // Mappings (separate storage)
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

    function getNextProposalId() external view returns (uint48 nextProposalId_) {
        nextProposalId_ = nextProposalId;
    }

    function getLastFinalizedProposalId() external view returns (uint48 lastFinalizedProposalId_) {
        lastFinalizedProposalId_ = lastFinalizedProposalId;
    }

    function getLastFinalizedClaimHash() external view returns (bytes32 lastFinalizedClaimHash_) {
        lastFinalizedClaimHash_ = lastFinalizedClaimHash;
    }

    function getLastL2BlockNumber() external view returns (uint48 lastL2BlockNumber_) {
        lastL2BlockNumber_ = lastL2BlockNumber;
    }

    function getLastL2BlockHash() external view returns (bytes32 lastL2BlockHash_) {
        lastL2BlockHash_ = lastL2BlockHash;
    }

    function getLastL2StateRoot() external view returns (bytes32 lastL2StateRoot_) {
        lastL2StateRoot_ = lastL2StateRoot;
    }

    function getL2BondPaymentHash() external view returns (bytes32 l2BondPaymentsHash_) {
        l2BondPaymentsHash_ = l2BondPaymentsHash;
    }

    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_) {
        proposalHash_ = proposalRegistry[_proposalId];
    }

    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimRecordHash
    )
        external
        view
        returns (bytes32 claimRecordHash_)
    {
        claimRecordHash_ = claimRecordHashLookup[_proposalId][_parentClaimRecordHash];
    }

    // -------------------------------------------------------------------------
    // External transactional (restricted to inbox)
    // -------------------------------------------------------------------------

    function initialize() external onlyInbox {
        nextProposalId = 1;
    }

    function incrementAndGetProposalId() external onlyInbox returns (uint48 proposalId_) {
        proposalId_ = nextProposalId++;
    }

    function setLastFinalized(uint48 _proposalId, bytes32 _claimRecordHash) external onlyInbox {
        lastFinalizedProposalId = _proposalId;
        lastFinalizedClaimHash = _claimRecordHash;
    }

    function setLastL2BlockData(
        uint48 _blockNumber,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        external
        onlyInbox
    {
        lastL2BlockNumber = _blockNumber;
        lastL2BlockHash = _blockHash;
        lastL2StateRoot = _stateRoot;
    }

    function aggregateL2BondPayment(bytes32 _l2BondPaymentHash) external onlyInbox {
        l2BondPaymentsHash = keccak256(abi.encode(l2BondPaymentsHash, _l2BondPaymentHash));
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
}
