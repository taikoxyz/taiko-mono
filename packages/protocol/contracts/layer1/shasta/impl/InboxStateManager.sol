// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxStateManager } from "../iface/IInboxStateManager.sol";
import { IInbox } from "../iface/IInbox.sol";

/// @title InboxStateManager
/// @notice Abstract contract implementing ring buffer storage for Inbox state management.
/// @dev This contract uses a ring buffer pattern to efficiently store proposal and claim data.
/// The ring buffer has a fixed size, and when it fills up, new proposals overwrite the oldest
/// ones based on modulo arithmetic (proposalId % ringBufferSize). This design optimizes gas
/// costs by limiting the total storage used while maintaining recent proposal history.
/// @custom:security-contact security@taiko.xyz
contract InboxStateManager is IInboxStateManager {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Stores proposal data and associated claim records.
    /// @dev Each proposal can have multiple claims associated with it, indexed by parent claim
    /// hash.
    struct ProposalRecord {
        /// @dev Hash of the proposal data
        bytes32 proposalHash;
        /// @dev Maps parent claim hashes to their corresponding claim record hashes
        mapping(bytes32 parentClaimHash => bytes32 claimRecordHash) claimHashLookup;
    }

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    /// @notice The address of the inbox contract that can modify state.
    address public immutable inbox;

    /// @notice The size of the ring buffer for proposals.
    uint256 public immutable ringBufferSize;

    /// @notice The hash of the core state.
    bytes32 private coreStateHash;

    /// @notice Ring buffer for storing proposal records.
    /// @dev Key is proposalId % ringBufferSize
    mapping(uint256 bufferSlot => ProposalRecord proposalRecord) private proposalRingBuffer;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    /// @notice Ensures only the inbox contract can call the function.
    /// @dev Critical for maintaining state integrity - only the inbox should modify state.
    modifier onlyInbox() {
        if (msg.sender != inbox) revert Unauthorized();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Initializes the InboxStateManager with the inbox address and genesis block hash.
    /// @dev Sets up the initial core state with proposal ID 1 and the genesis block as the
    /// last finalized claim. The ring buffer size determines how many proposals can be
    /// stored before old ones are overwritten.
    /// @param _inbox The address of the authorized inbox contract.
    /// @param _genesisBlockHash The hash of the genesis block.
    /// @param _ringBufferSize The size of the ring buffer (must be > 0).
    constructor(address _inbox, bytes32 _genesisBlockHash, uint256 _ringBufferSize) {
        if (_ringBufferSize == 0) revert InvalidRingBufferSize();
        inbox = _inbox;
        ringBufferSize = _ringBufferSize;

        IInbox.Claim memory claim;
        claim.endBlockHash = _genesisBlockHash;

        IInbox.CoreState memory coreState;
        coreState.nextProposalId = 1;
        coreState.lastFinalizedClaimHash = keccak256(abi.encode(claim));
        coreStateHash = keccak256(abi.encode(coreState));
    }

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IInboxStateManager
    function setCoreStateHash(bytes32 _coreStateHash) external onlyInbox {
        coreStateHash = _coreStateHash;
    }

    /// @inheritdoc IInboxStateManager
    function setProposalHash(uint48 _proposalId, bytes32 _proposalHash) external onlyInbox {
        uint256 bufferSlot = _proposalId % ringBufferSize;
        // Overwrites any existing proposal at this slot
        proposalRingBuffer[bufferSlot].proposalHash = _proposalHash;
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
        uint256 bufferSlot = _proposalId % ringBufferSize;
        // Note: This will associate the claim with whatever proposal currently
        // occupies this slot, which may not be the original proposal if overwritten
        proposalRingBuffer[bufferSlot].claimHashLookup[_parentClaimHash] = _claimRecordHash;
    }

    /// @inheritdoc IInboxStateManager
    function getCoreStateHash() public view returns (bytes32 coreStateHash_) {
        coreStateHash_ = coreStateHash;
    }

    /// @inheritdoc IInboxStateManager
    function getProposalHash(uint48 _proposalId) public view returns (bytes32 proposalHash_) {
        uint256 bufferSlot = _proposalId % ringBufferSize;
        // Returns the hash at this slot, which may belong to a different proposal
        // if the ring buffer has wrapped around
        proposalHash_ = proposalRingBuffer[bufferSlot].proposalHash;
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
        uint256 bufferSlot = _proposalId % ringBufferSize;
        // Returns claim data from whatever proposal currently occupies this slot
        claimRecordHash_ = proposalRingBuffer[bufferSlot].claimHashLookup[_parentClaimHash];
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @dev Thrown when the inbox address is invalid (unused in current implementation)
    error InvalidInboxAddress();
    /// @dev Thrown when ring buffer size is 0 during construction
    error InvalidRingBufferSize();
    /// @dev Thrown when a function is called by an address other than the authorized inbox
    error Unauthorized();
}
