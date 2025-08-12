// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ISyncedBlockManager } from "src/shared/based/iface/ISyncedBlockManager.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBondInstruction } from "src/shared/based/libs/LibBondInstruction.sol";
import { LibDecoder } from "../libs/LibDecoder.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture.
/// @custom:security-contact security@taiko.xyz

abstract contract Inbox is EssentialContract, IInbox {
    using LibDecoder for bytes;
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when bond is withdrawn from the contract
    /// @param user The user whose bond was withdrawn
    /// @param amount The amount of bond withdrawn
    event BondWithdrawn(address indexed user, uint256 amount);

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

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

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    bytes32 private constant _DEFAULT_SLOT_HASH = bytes32(uint256(1));

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    // 5 slots are used by the State object defined in Pacaya inbox:
    // mapping(uint256 batchId_mod_batchRingBufferSize => Batch batch) batches;
    // mapping(uint256 batchId => mapping(bytes32 parentHash => uint24 transitionId)) transitionIds;
    // mapping(uint256 batchId_mod_batchRingBufferSize => mapping(uint24 transitionId =>
    //         TransitionState ts)) transitions;
    // bytes32 __reserve1;
    // Stats1 stats1;
    uint256[5] private __slotsUsedByPacaya;

    // Reserved slot for future migration compatibility
    uint256 private __reservedSlot;

    mapping(address account => uint256 bond) public bondBalance;

    /// @dev The hash of the core state.
    bytes32 internal coreStateHash;

    /// @dev Ring buffer for storing proposal records.
    mapping(uint256 bufferSlot => ProposalRecord proposalRecord) internal proposalRingBuffer;

    uint256[41] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    constructor() EssentialContract() { }

    /// @notice Initializes the Inbox contract with genesis block
    /// @param _owner The owner of this contract
    /// @param _genesisBlockHash The hash of the genesis block
    function init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Essential_init(_owner);

        Claim memory claim;
        claim.endBlockHash = _genesisBlockHash;

        CoreState memory coreState;
        coreState.nextProposalId = 1;
        coreState.lastFinalizedClaimHash = keccak256(abi.encode(claim));
        coreStateHash = keccak256(abi.encode(coreState));

        emit CoreStateSet(coreState);
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInbox
    function propose(bytes calldata, /*_lookahead*/ bytes calldata _data) external nonReentrant {
        Config memory config = getConfig();
        require(_isForkActive(config), ForkNotActive());
        IProposerChecker(config.proposerChecker).checkProposer(msg.sender);

        (
            CoreState memory coreState,
            LibBlobs.BlobReference memory blobReference,
            ClaimRecord[] memory claimRecords
        ) = _data.decodeProposeData();

        bytes32 coreStateHash_ = keccak256(abi.encode(coreState));
        require(coreStateHash_ == coreStateHash, InvalidState());

        // Check if new proposals would exceed the unfinalized proposal capacity
        require(
            coreState.nextProposalId - coreState.lastFinalizedProposalId <= _getCapacity(config),
            ExceedsUnfinalizedProposalCapacity()
        );

        Proposal memory proposal;

        // Handle forced inclusion if required
        if (IForcedInclusionStore(config.forcedInclusionStore).isOldestForcedInclusionDue()) {
            IForcedInclusionStore.ForcedInclusion memory forcedInclusion = IForcedInclusionStore(
                config.forcedInclusionStore
            ).consumeOldestForcedInclusion(msg.sender);

            (coreState, proposal) = _propose(config, coreState, forcedInclusion.blobSlice, true);
            emit Proposed(proposal, coreState);
            coreStateHash_ = keccak256(abi.encode(coreState));
        }

        // Create regular proposal
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(blobReference);
        (coreState, proposal) = _propose(config, coreState, blobSlice, false);
        // Finalize proved proposals
        coreState = _finalize(config, coreState, claimRecords);
        emit Proposed(proposal, coreState);

        // Update stored hash with final coreState
        _setCoreStateHash(keccak256(abi.encode(coreState)));
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        Config memory config = getConfig();
        (Proposal[] memory proposals, Claim[] memory claims) = _data.decodeProveData();

        require(proposals.length == claims.length, InconsistentParams());
        require(proposals.length != 0, EmptyProposals());

        uint48[] memory proposalIds = new uint48[](proposals.length);
        ClaimRecord[] memory claimRecords = new ClaimRecord[](proposals.length);

        for (uint256 i; i < proposals.length; ++i) {
            proposalIds[i] = proposals[i].id;
            claimRecords[i] = _buildClaimRecord(config, proposals[i], claims[i]);
        }

        // Aggregate claim records to reduce SSTORE operations.
        (proposalIds, claimRecords) = _aggregateClaimRecords(proposalIds, claimRecords);

        for (uint256 i; i < claimRecords.length; ++i) {
            _setClaimRecordHash(
                config,
                proposalIds[i],
                claimRecords[i].claim.parentClaimHash,
                keccak256(abi.encode(claimRecords[i]))
            );
            emit Proved(proposals[i], claimRecords[i]);
        }

        bytes32 claimsHash = keccak256(abi.encode(claims));
        IProofVerifier(config.proofVerifier).verifyProof(claimsHash, _proof);
    }

    /// @notice Withdraws bond balance for a given user.
    /// @dev Anyone can call this function to withdraw bond for any user.
    function withdrawBond() external nonReentrant {
        uint256 amount = bondBalance[msg.sender];
        require(amount > 0, NoBondToWithdraw());

        bondBalance[msg.sender] = 0;
        Config memory config = getConfig();
        IERC20(config.bondToken).safeTransfer(msg.sender, amount);

        emit BondWithdrawn(msg.sender, amount);
    }

    /// @notice Gets the proposal hash for a given proposal ID.
    /// @param _proposalId The proposal ID to look up.
    /// @return proposalHash_ The hash stored at the proposal's ring buffer slot.
    function getProposalHash(uint48 _proposalId) public view returns (bytes32 proposalHash_) {
        Config memory config = getConfig();
        uint256 bufferSlot = _proposalId % config.ringBufferSize;
        proposalHash_ = proposalRingBuffer[bufferSlot].proposalHash;
    }

    /// @notice Gets the claim record hash for a given proposal and parent claim.
    /// @param _proposalId The proposal ID to look up.
    /// @param _parentClaimHash The parent claim hash to look up.
    /// @return claimRecordHash_ The claim record hash, or bytes32(0) if not found.
    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        public
        view
        returns (bytes32 claimRecordHash_)
    {
        Config memory config = getConfig();
        uint256 bufferSlot = _proposalId % config.ringBufferSize;

        ExtendedClaimRecord storage record =
            proposalRingBuffer[bufferSlot].claimHashLookup[_DEFAULT_SLOT_HASH];

        (uint48 proposalId, bytes32 partialParentClaimHash) =
            _decodeSlotReuseMarker(record.slotReuseMarker);

        // If the reusable slot's proposal ID does not match the given proposal ID, it indicates
        // that there are no claims associated with this proposal at all.
        if (proposalId != _proposalId) return bytes32(0);

        // If there's a record in the default slot with matching parent claim hash, return it
        if (_isPartialParentClaimHashMatch(partialParentClaimHash, _parentClaimHash)) {
            return record.claimRecordHash;
        }

        // Otherwise check the direct mapping
        return proposalRingBuffer[bufferSlot].claimHashLookup[_parentClaimHash].claimRecordHash;
    }

    /// @notice Gets the capacity for unfinalized proposals.
    /// @return _ The maximum number of unfinalized proposals that can exist.
    function getCapacity() public view returns (uint256) {
        Config memory config = getConfig();
        return _getCapacity(config);
    }

    /// @notice Gets the configuration for this Inbox contract
    /// @dev This function must be overridden by subcontracts to provide their specific
    /// configuration
    /// @return _ The configuration struct
    function getConfig() public view virtual returns (Config memory);

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Sets the hash of the core state.
    function _setCoreStateHash(bytes32 _coreStateHash) internal {
        coreStateHash = _coreStateHash;
    }

    /// @dev Sets the proposal hash for a given proposal ID.
    function _setProposalHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _proposalHash
    )
        internal
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        proposalRingBuffer[bufferSlot].proposalHash = _proposalHash;
    }

    /// @dev Sets the claim record hash for a given proposal and parent claim.
    function _setClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
    {
        ProposalRecord storage proposalRecord =
            proposalRingBuffer[_proposalId % _config.ringBufferSize];

        ExtendedClaimRecord storage record = proposalRecord.claimHashLookup[_DEFAULT_SLOT_HASH];

        (uint48 proposalId, bytes32 partialParentClaimHash) =
            _decodeSlotReuseMarker(record.slotReuseMarker);

        // Check if we need to use the default slot
        if (proposalId != _proposalId) {
            // Different proposal ID, so we can use the default slot
            record.claimRecordHash = _claimRecordHash;
            record.slotReuseMarker = _encodeSlotReuseMarker(_proposalId, _parentClaimHash);
        } else if (_isPartialParentClaimHashMatch(partialParentClaimHash, _parentClaimHash)) {
            // Same proposal ID and same parent claim hash (partial match), update the default slot
            record.claimRecordHash = _claimRecordHash;
        } else {
            // Same proposal ID but different parent claim hash, use direct mapping
            proposalRecord.claimHashLookup[_parentClaimHash].claimRecordHash = _claimRecordHash;
        }
    }

    /// @dev Decodes a slot reuse marker into proposal ID and partial parent claim hash.
    function _decodeSlotReuseMarker(uint256 _slotReuseMarker)
        internal
        pure
        returns (uint48 proposalId_, bytes32 partialParentClaimHash_)
    {
        proposalId_ = uint48(_slotReuseMarker >> 208);
        partialParentClaimHash_ = bytes32(_slotReuseMarker << 48);
    }

    /// @dev Encodes a proposal ID and parent claim hash into a slot reuse marker.
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

    /// @dev Checks if two parent claim hashes match in their high 208 bits.
    function _isPartialParentClaimHashMatch(
        bytes32 _partialParentClaimHash,
        bytes32 _parentClaimHash
    )
        internal
        pure
        returns (bool)
    {
        return _partialParentClaimHash >> 48 == bytes32(uint256(_parentClaimHash) >> 48);
    }

    /// @dev Gets the capacity for unfinalized proposals.
    function _getCapacity(Config memory _config) internal pure returns (uint256) {
        // The ring buffer can hold ringBufferSize proposals total, but we need to ensure
        // unfinalized proposals are not overwritten. Therefore, the maximum number of
        // unfinalized proposals is ringBufferSize - 1.
        unchecked {
            return _config.ringBufferSize - 1;
        }
    }

    /// @dev Gets the claim record hash for a given proposal and parent claim.
    function _getClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        internal
        view
        returns (bytes32 claimRecordHash_)
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;

        ExtendedClaimRecord storage record =
            proposalRingBuffer[bufferSlot].claimHashLookup[_DEFAULT_SLOT_HASH];

        (uint48 proposalId, bytes32 partialParentClaimHash) =
            _decodeSlotReuseMarker(record.slotReuseMarker);

        // If the reusable slot's proposal ID does not match the given proposal ID, it indicates
        // that there are no claims associated with this proposal at all.
        if (proposalId != _proposalId) return bytes32(0);

        // If there's a record in the default slot with matching parent claim hash, return it
        if (_isPartialParentClaimHashMatch(partialParentClaimHash, _parentClaimHash)) {
            return record.claimRecordHash;
        }

        // Otherwise check the direct mapping
        return proposalRingBuffer[bufferSlot].claimHashLookup[_parentClaimHash].claimRecordHash;
    }

    /// @dev Aggregates claim records into a smaller list to reduce SSTORE operations.
    /// The default implementation returns the original list.
    /// @param _proposalIds The proposal IDs to aggregate.
    /// @param _claimRecords The claim records to aggregate.
    /// @return proposalIds_  The list contains the proposal IDs of the aggregated claim records.
    /// @return claimRecords_ The list contains the aggregated claim records.
    function _aggregateClaimRecords(
        uint48[] memory _proposalIds,
        ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        virtual
        returns (uint48[] memory proposalIds_, ClaimRecord[] memory claimRecords_)
    {
        return (_proposalIds, _claimRecords);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Proposes a new proposal of L2 blocks.
    /// @param _config The configuration parameters.
    /// @param _coreState The core state of the inbox.
    /// @param _blobSlice The blob slice of the proposal.
    /// @param _isForcedInclusion Whether the proposal is a forced inclusion.
    /// @return coreState_ The updated core state.
    /// @return proposal_ The created proposal.
    function _propose(
        Config memory _config,
        CoreState memory _coreState,
        LibBlobs.BlobSlice memory _blobSlice,
        bool _isForcedInclusion
    )
        private
        returns (CoreState memory coreState_, Proposal memory proposal_)
    {
        uint48 proposalId = _coreState.nextProposalId++;
        uint48 originTimestamp = uint48(block.timestamp);
        uint48 originBlockNumber = uint48(block.number);

        proposal_ = Proposal({
            id: proposalId,
            proposer: msg.sender,
            originTimestamp: originTimestamp,
            originBlockNumber: originBlockNumber,
            isForcedInclusion: _isForcedInclusion,
            basefeeSharingPctg: _config.basefeeSharingPctg,
            blobSlice: _blobSlice
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal_));

        _setProposalHash(_config, proposalId, proposalHash);

        return (_coreState, proposal_);
    }

    /// @dev Builds a claim record for a single proposal.
    /// @param _config The configuration parameters.
    /// @param _proposal The proposal to prove.
    /// @param _claim The claim containing the proof details.
    function _buildClaimRecord(
        Config memory _config,
        Proposal memory _proposal,
        Claim memory _claim
    )
        private
        view
        returns (ClaimRecord memory claimRecord_)
    {
        bytes32 proposalHash = keccak256(abi.encode(_proposal));
        // Validate proposal hash matches claim and storage in one check
        if (proposalHash != _claim.proposalHash) revert ProposalHashMismatch();

        uint256 bufferSlot = _proposal.id % _config.ringBufferSize;
        if (proposalHash != proposalRingBuffer[bufferSlot].proposalHash) {
            revert ProposalHashMismatch();
        }

        LibBondInstruction.BondInstruction[] memory bondInstructions =
            _calculateBondInstructions(_config, _proposal, _claim);

        claimRecord_ = ClaimRecord({
            claim: _claim,
            proposer: _proposal.proposer,
            nextProposalId: _proposal.id + 1,
            bondInstructions: bondInstructions
        });
    }

    /// @dev Calculates the bond instructions based on proof timing and prover identity
    /// @notice Bond instructions determine how provability and liveness bonds are handled:
    /// - On-time proofs: Bonds may be refunded or remain unchanged
    /// - Late proofs: Liveness bonds may be slashed and redistributed
    /// - Very late proofs: Provability bonds may also be slashed and redistributed
    /// The decision affects whether claim records can be aggregated
    /// @param _config The configuration parameters.
    /// @param _proposal The proposal containing timing and proposer information
    /// @param _claim The claim containing the proof details.
    /// @return bondInstructions_ The bond instructions that affect aggregation eligibility
    function _calculateBondInstructions(
        Config memory _config,
        Proposal memory _proposal,
        Claim memory _claim
    )
        private
        view
        returns (LibBondInstruction.BondInstruction[] memory bondInstructions_)
    {
        unchecked {
            if (block.timestamp <= _proposal.originTimestamp + _config.provingWindow) {
                // Proof submitted within the designated proving window (on-time proof)
                return new LibBondInstruction.BondInstruction[](0);
            } else {
                LibBondInstruction.BondInstruction[] memory bondInstructions =
                    new LibBondInstruction.BondInstruction[](1);

                if (block.timestamp <= _proposal.originTimestamp + _config.extendedProvingWindow) {
                    bondInstructions[0] = LibBondInstruction.BondInstruction({
                        proposalId: _proposal.id,
                        isLivenessBond: true,
                        creditTo: _claim.actualProver,
                        debitFrom: _claim.designatedProver
                    });
                } else {
                    bondInstructions[0] = LibBondInstruction.BondInstruction({
                        proposalId: _proposal.id,
                        isLivenessBond: false,
                        creditTo: _claim.actualProver,
                        debitFrom: _proposal.proposer
                    });
                }
                return bondInstructions;
            }
        }
    }

    /// @dev Finalizes proposals by verifying claim records and updating state.
    /// @param _config The configuration parameters.
    /// @param _coreState The current core state.
    /// @param _claimRecords The claim records to finalize.
    /// @return coreState_ The updated core state
    function _finalize(
        Config memory _config,
        CoreState memory _coreState,
        ClaimRecord[] memory _claimRecords
    )
        private
        returns (CoreState memory coreState_)
    {
        // The last finalized claim record.
        ClaimRecord memory claimRecord;
        bool hasFinalized;

        uint48 proposalId = _coreState.lastFinalizedProposalId + 1;

        for (uint256 i; i < _config.maxFinalizationCount; ++i) {
            // Id for the next proposal to be finalized.

            // There is no more unfinalized proposals
            if (proposalId >= _coreState.nextProposalId) break;

            bytes32 storedClaimRecordHash =
                _getClaimRecordHash(_config, proposalId, _coreState.lastFinalizedClaimHash);

            // The next proposal cannot be finalized as there is no claim record to link the chain
            if (storedClaimRecordHash == 0) break;

            // There is no claim record provided for the next proposal.
            require(i < _claimRecords.length, ClaimRecordNotProvided());

            claimRecord = _claimRecords[i];

            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
            require(claimRecordHash == storedClaimRecordHash, ClaimRecordHashMismatch());

            _coreState.lastFinalizedProposalId = proposalId;
            _coreState.lastFinalizedClaimHash = keccak256(abi.encode(claimRecord.claim));

            if (claimRecord.bondInstructions.length > 0) {
                emit BondInstructed(claimRecord.bondInstructions);
                for (uint256 j; j < claimRecord.bondInstructions.length; ++j) {
                    _coreState.bondInstructionsHash = LibBondInstruction.aggregateBondInstruction(
                        _coreState.bondInstructionsHash, claimRecord.bondInstructions[j]
                    );
                }
            }

            proposalId = _claimRecords[i].nextProposalId;
            hasFinalized = true;
        }

        if (hasFinalized) {
            ISyncedBlockManager(_config.syncedBlockManager).saveSyncedBlock(
                claimRecord.claim.endBlockNumber,
                claimRecord.claim.endBlockHash,
                claimRecord.claim.endStateRoot
            );
        }

        return _coreState;
    }

    function _isForkActive(Config memory _cfg) internal pure returns (bool) {
        // Fork is active if no specific activation height is set (0 means always active)
        return _cfg.forkActivationHeight == 0;
    }
}

// ---------------------------------------------------------------
// Errors
// ---------------------------------------------------------------

error ClaimRecordHashMismatch();
error ClaimRecordNotProvided();
error EmptyProposals();
error ExceedsUnfinalizedProposalCapacity();
error ForkNotActive();
error InconsistentParams();
error InsufficientBond();
error InvalidForcedInclusion();
error InvalidState();
error NoBondToWithdraw();
error ProposalHashMismatch();
error ProposerBondInsufficient();
error RingBufferSizeZero();
error Unauthorized();
