// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxStateManager } from "../iface/IInboxStateManager.sol";
import { IInbox } from "../iface/IInbox.sol";

/// @title InboxStateManager
/// @notice Implementation for managing Inbox state data.
/// @custom:security-contact security@taiko.xyz
abstract contract InboxStateManager is IInboxStateManager {
    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    /// @notice The address of the inbox contract that can modify state.
    address public immutable inbox;

    /// @notice The complete protocol state.
    IInbox.State private state;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    /// @notice Ensures only the inbox contract can call the function.
    modifier onlyInbox() {
        if (msg.sender != inbox) revert Unauthorized();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Initializes the InboxStateManager with the inbox address and genesis block hash
    /// @param _inbox The address of the inbox contract
    /// @param _genesisBlockHash The genesis block hash
    constructor(address _inbox, bytes32 _genesisBlockHash) {
        inbox = _inbox;

        IInbox.Claim memory claim;
        claim.endBlockHash = _genesisBlockHash;

        IInbox.CoreState memory coreState;
        coreState.nextProposalId = 1;
        coreState.lastFinalizedClaimHash = keccak256(abi.encode(claim));
        state.coreStateHash = keccak256(abi.encode(coreState));
    }

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IInboxStateManager
    function setCoreStateHash(bytes32 _coreStateHash) external onlyInbox {
        state.coreStateHash = _coreStateHash;
    }

    /// @inheritdoc IInboxStateManager
    function setProposalHash(uint48 _proposalId, bytes32 _proposalHash) external onlyInbox {
        state.proposalRegistry[_proposalId] = _proposalHash;
    }

    /// @inheritdoc IInboxStateManager
    function setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        external
        onlyInbox
    {
        state.claimRecordHashLookup[_proposalId][_parentClaimHash] = _claimRecordHash;
    }

    /// @inheritdoc IInboxStateManager
    function getCoreStateHash() public view returns (bytes32 coreStateHash_) {
        coreStateHash_ = state.coreStateHash;
    }

    /// @inheritdoc IInboxStateManager
    function getProposalHash(uint48 _proposalId) public view returns (bytes32 proposalHash_) {
        proposalHash_ = state.proposalRegistry[_proposalId];
    }

    /// @inheritdoc IInboxStateManager
    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        public
        view
        returns (bytes32 claimRecordHash_)
    {
        claimRecordHash_ = state.claimRecordHashLookup[_proposalId][_parentClaimHash];
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error InvalidInboxAddress();
    error Unauthorized();
}
