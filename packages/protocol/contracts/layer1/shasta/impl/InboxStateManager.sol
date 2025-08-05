// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxStateManager } from "../iface/IInboxStateManager.sol";
import { IInbox } from "../iface/IInbox.sol";

/// @title InboxStateManager
/// @notice Manages state storage for the Inbox contract using a ring buffer pattern.
/// @dev This contract implements efficient storage for proposal and claim data using:
/// - Ring buffer: Fixed-size circular storage that overwrites old data when full
/// - Packed encoding: Stores proposal ID and partial parent claim hash in a single uint256
/// - Gas optimization: Uses a default slot for first claim to reduce storage operations
///
/// The ring buffer size determines how many proposals can be stored before old ones are
/// overwritten. Each slot can store one proposal hash and multiple claim records indexed
/// by parent claim hash.
/// @custom:security-contact security@taiko.xyz
contract InboxStateManager is IInboxStateManager {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Extended claim record that stores both the claim hash and encoded metadata.
    /// @dev The metadata includes the proposal ID and partial parent claim hash for efficient
    /// lookups.
    struct ExtendedClaimRecord {
        bytes32 claimRecordHash;
        uint256 slotReuseMarker;
    }

    /// @notice Stores proposal data and associated claim records.
    /// @dev Each proposal can have multiple claims associated with it, indexed by parent claim
    /// hash.
    struct ProposalRecord {
        /// @dev Hash of the proposal data
        bytes32 proposalHash;
        /// @dev Maps parent claim hashes to their corresponding claim record hashes
        mapping(bytes32 parentClaimHash => ExtendedClaimRecord claimRecordHash) claimHashLookup;
    }

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------
    bytes32 private immutable _DEFAULT_SLOT_HASH = bytes32(uint256(1));

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
        ProposalRecord storage proposalRecord = proposalRingBuffer[_proposalId % ringBufferSize];

        ExtendedClaimRecord storage record = proposalRecord.claimHashLookup[_DEFAULT_SLOT_HASH];

        (uint48 proposalId, bytes32 partialParentClaimHash) =
            _decodeSlotReuseMarker(record.slotReuseMarker);

        // Check if we need to use the default slot
        if (proposalId != _proposalId) {
            // Different proposal ID, so we can use the default slot
            record.claimRecordHash = _claimRecordHash;
            record.slotReuseMarker = _encodeSlotReuseMarker(_proposalId, _parentClaimHash);
        } else if (partialParentClaimHash >> 48 == bytes32(uint256(_parentClaimHash) >> 48)) {
            // Same proposal ID and same parent claim hash (partial match), update the default slot
            record.claimRecordHash = _claimRecordHash;
        } else {
            // Same proposal ID but different parent claim hash, use direct mapping
            proposalRecord.claimHashLookup[_parentClaimHash].claimRecordHash = _claimRecordHash;
        }
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

        ExtendedClaimRecord storage record =
            proposalRingBuffer[bufferSlot].claimHashLookup[_DEFAULT_SLOT_HASH];

        (uint48 proposalId, bytes32 partialParentClaimHash) =
            _decodeSlotReuseMarker(record.slotReuseMarker);

        // If there's a record in the default slot with matching parent claim hash, return it
        if (
            proposalId != 0
                && partialParentClaimHash == bytes32(uint256(_parentClaimHash) >> 48 << 48)
        ) {
            return record.claimRecordHash;
        }

        // Otherwise check the direct mapping
        return proposalRingBuffer[bufferSlot].claimHashLookup[_parentClaimHash].claimRecordHash;
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Decodes a slot reuse marker into proposal ID and partial parent claim hash.
    /// @dev The encoding format:
    ///      - Bits 255-208 (48 bits): Proposal ID
    ///      - Bits 207-0 (208 bits): Highest 208 bits of parent claim hash
    /// @param _slotReuseMarker The packed value to decode
    /// @return proposalId_ The decoded proposal ID
    /// @return partialParentClaimHash_ The decoded partial parent claim hash (low 48 bits zeroed)
    function _decodeSlotReuseMarker(uint256 _slotReuseMarker)
        internal
        pure
        returns (uint48 proposalId_, bytes32 partialParentClaimHash_)
    {
        proposalId_ = uint48(_slotReuseMarker >> 208);
        partialParentClaimHash_ = bytes32(_slotReuseMarker << 48);
    }

    /// @notice Encodes a proposal ID and parent claim hash into a slot reuse marker.
    /// @dev The encoding format:
    ///      - Bits 255-208 (48 bits): Proposal ID
    ///      - Bits 207-0 (208 bits): Highest 208 bits of parent claim hash
    ///      This encoding allows us to store both values efficiently in a single storage slot.
    /// @param _proposalId The proposal ID to encode (max 48 bits)
    /// @param _parentClaimHash The parent claim hash (only highest 208 bits are stored)
    /// @return slotReuseMarker_ The packed encoded value
    function _encodeSlotReuseMarker(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        internal
        pure
        returns (uint256 slotReuseMarker_)
    {
        slotReuseMarker_ = (uint256(_proposalId) << 208) | (uint256(_parentClaimHash) >> 48);
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error InvalidInboxAddress();
    error InvalidRingBufferSize();
    error Unauthorized();
}
