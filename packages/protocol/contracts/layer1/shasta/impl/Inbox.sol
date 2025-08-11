// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "contracts/shared/common/EssentialContract.sol";
import { IBondManagerL1 } from "../iface/IBondManagerL1.sol";
import { ISyncedBlockManager } from "contracts/shared/shasta/iface/ISyncedBlockManager.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../lib/LibBlobs.sol";
import { LibBondOperation } from "contracts/shared/shasta/libs/LibBondOperation.sol";
import { LibDecoder } from "../lib/LibDecoder.sol";

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

    struct PacayaStats2 {
        uint64 numBatches;
        uint64 lastVerifiedBatchId;
        bool paused;
        uint56 lastProposedIn;
        uint64 lastUnpausedAt;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    uint256 public constant REWARD_FRACTION = 2;
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

    PacayaStats2 private _pacayaStats2;

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
        require(IBondManager(config.bondManager).isProposerActive(msg.sender), ProposerNotActive());

        (
            CoreState memory coreState,
            LibBlobs.BlobLocator memory blobLocator,
            ClaimRecord[] memory claimRecords
        ) = _data.decodeProposeData();

        require(keccak256(abi.encode(coreState)) == coreStateHash, InvalidState());

        // Check if new proposals would exceed the unfinalized proposal capacity
        require(
            coreState.nextProposalId - coreState.lastFinalizedProposalId <= getCapacity(),
            ExceedsUnfinalizedProposalCapacity()
        );

        Proposal memory proposal;

        // Handle forced inclusion if required
        IForcedInclusionStore forcedInclusionStore =
            IForcedInclusionStore(config.forcedInclusionStore);
        if (forcedInclusionStore.isOldestForcedInclusionDue()) {
            IForcedInclusionStore.ForcedInclusion memory forcedInclusion =
                forcedInclusionStore.consumeOldestForcedInclusion(msg.sender);

            (coreState, proposal) = _propose(config, coreState, forcedInclusion.frame, true);
            emit Proposed(proposal, coreState);
        }

        // Create regular proposal
        LibBlobs.BlobFrame memory frame = LibBlobs.validateBlobLocator(blobLocator);
        (coreState, proposal) = _propose(config, coreState, frame, false);
        // Finalize proved proposals
        coreState = _finalize(config, coreState, claimRecords);
        emit Proposed(proposal, coreState);

        _setCoreStateHash(keccak256(abi.encode(coreState)));
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        Config memory config = getConfig();
        (Proposal[] memory proposals, Claim[] memory claims) = _data.decodeProveData();

        require(proposals.length == claims.length, InconsistentParams());
        require(proposals.length != 0, EmptyProposals());

        ClaimRecord[] memory claimRecords = new ClaimRecord[](proposals.length);

        for (uint256 i; i < proposals.length; ++i) {
            claimRecords[i] = _buildClaimRecord(config, proposals[i], claims[i]);
        }

        _aggregateAndSaveClaimRecords(proposals, claimRecords);

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
        // The ring buffer can hold ringBufferSize proposals total, but we need to ensure
        // unfinalized proposals are not overwritten. Therefore, the maximum number of
        // unfinalized proposals is ringBufferSize - 1.
        unchecked {
            return config.ringBufferSize - 1;
        }
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
        Config memory _cfg,
        uint48 _proposalId,
        bytes32 _proposalHash
    )
        internal
    {
        uint256 bufferSlot = _proposalId % _cfg.ringBufferSize;
        proposalRingBuffer[bufferSlot].proposalHash = _proposalHash;
    }

    /// @dev Sets the claim record hash for a given proposal and parent claim.
    function _setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
    {
        Config memory config = getConfig();
        ProposalRecord storage proposalRecord =
            proposalRingBuffer[_proposalId % config.ringBufferSize];

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

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Aggregates and saves consecutive claim records to reduce gas costs
    /// @notice This function is a key gas optimization that combines multiple claim records
    /// into fewer records when they share compatible properties:
    /// - Same parent claim hash (ensures they're part of the same chain)
    /// - Same bond decision (ensures consistent bond handling)
    /// - Same designated prover (for L2RefundLiveness decisions)
    /// - Same actual prover (for L2RewardProver decisions)
    ///
    /// Gas savings example: If 10 consecutive proposals are proven by the same prover,
    /// they can be stored as 1 aggregated record instead of 10 individual records
    /// @param _proposals Array of proposals being proven
    /// @param _claimRecords Array of claim records to aggregate
    function _aggregateAndSaveClaimRecords(
        Proposal[] memory _proposals,
        ClaimRecord[] memory _claimRecords
    )
        private
    {
        unchecked {
            // Track the first proposal for each aggregated record
            Proposal[] memory firstProposals = new Proposal[](_claimRecords.length);
            firstProposals[0] = _proposals[0];

            // Reuse _claimRecords array for aggregation
            uint256 writeIndex = 0;
            uint256 readIdx = 1;
            uint48 lastAggregatedProposalId = _proposals[0].id;

            while (readIdx < _claimRecords.length) {
                if (
                    _canAggregate(
                        _claimRecords[writeIndex],
                        _claimRecords[readIdx],
                        lastAggregatedProposalId,
                        _proposals[readIdx].id
                    )
                ) {
                    // Update the aggregated record at writeIndex to span multiple proposals
                    _claimRecords[writeIndex].nextProposalId = _claimRecords[readIdx].nextProposalId;
                    _claimRecords[writeIndex].claim.endBlockNumber =
                        _claimRecords[readIdx].claim.endBlockNumber;
                    _claimRecords[writeIndex].claim.endBlockHash =
                        _claimRecords[readIdx].claim.endBlockHash;
                    _claimRecords[writeIndex].claim.endStateRoot =
                        _claimRecords[readIdx].claim.endStateRoot;

                    // Aggregate liveness bonds for decisions that require it
                    if (
                        _claimRecords[writeIndex].bondDecision == BondDecision.L2RefundLiveness
                            || _claimRecords[writeIndex].bondDecision == BondDecision.L2RewardProver
                    ) {
                        _claimRecords[writeIndex].livenessBondGwei +=
                            _claimRecords[readIdx].livenessBondGwei;
                    }

                    // Update the last aggregated proposal ID
                    lastAggregatedProposalId = _proposals[readIdx].id;
                } else {
                    // Move to next write position and copy the current record
                    writeIndex++;
                    if (writeIndex != readIdx) {
                        _claimRecords[writeIndex] = _claimRecords[readIdx];
                    }
                    firstProposals[writeIndex] = _proposals[readIdx];

                    // Update the last aggregated proposal ID for the new write position
                    lastAggregatedProposalId = _proposals[readIdx].id;
                }
                readIdx++;
            }

            // Final aggregated count
            uint256 aggregatedCount = writeIndex + 1;

            // Emit events and set hashes for all aggregated records
            for (uint256 i; i < aggregatedCount; ++i) {
                _setClaimRecordHash(
                    firstProposals[i].id,
                    _claimRecords[i].claim.parentClaimHash,
                    keccak256(abi.encode(_claimRecords[i]))
                );
                emit Proved(firstProposals[i], _claimRecords[i]);
            }
        }
    }

    /// @dev Checks if two claim records can be aggregated for gas optimization
    /// @notice Aggregation rules ensure that only compatible records are combined:
    /// - Proposals must be consecutive
    /// - Records must be consecutive (recordA.nextProposalId == proposalBId)
    /// - Must share the same parent claim hash (same chain)
    /// - Must have the same bond decision
    /// - For certain bond decisions, must have the same prover
    /// - Liveness bond sum must not overflow uint48
    /// @param _recordA The first claim record
    /// @param _recordB The second claim record
    /// @param _lastAggregatedProposalId The last proposal ID that was aggregated
    /// @param _proposalBId The proposal ID of the second claim record
    /// @return _ True if the records can be aggregated, false otherwise
    function _canAggregate(
        ClaimRecord memory _recordA,
        ClaimRecord memory _recordB,
        uint48 _lastAggregatedProposalId,
        uint48 _proposalBId
    )
        private
        pure
        returns (bool)
    {
        // Check if proposals are consecutive
        if (_proposalBId != _lastAggregatedProposalId + 1) return false;

        // Check if a.nextProposalId equals the proposal id of b
        // Since ClaimRecord stores nextProposalId which is proposalId + 1,
        // we need to check if a.nextProposalId == b's implied proposalId
        // b's proposalId = b.nextProposalId - 1
        if (_recordA.nextProposalId != _proposalBId) return false;

        // Check if parentClaimHash matches (required for valid aggregation)
        if (_recordA.claim.parentClaimHash != _recordB.claim.parentClaimHash) return false;

        // Check if bondDecision matches
        if (_recordA.bondDecision != _recordB.bondDecision) return false;

        // Check specific conditions for aggregation
        if (_recordA.bondDecision == BondDecision.NoOp) return true;

        // For other decions, we need to aggregate the liveness bonds. We need to make sure the sum
        // does not overflow.
        if (uint256(_recordA.livenessBondGwei) + _recordB.livenessBondGwei > type(uint48).max) {
            return false;
        }

        // For L2RefundLiveness, we need to make sure the designated prover is the same.
        if (
            _recordA.bondDecision == BondDecision.L2RefundLiveness
                && _recordA.claim.designatedProver == _recordB.claim.designatedProver
        ) return true;

        // For L2RewardProver, we need to make sure the actual prover is the same.
        if (
            _recordA.bondDecision == BondDecision.L2RewardProver
                && _recordA.claim.actualProver == _recordB.claim.actualProver
        ) return true;

        return false;
    }

    /// @dev Proposes a new proposal of L2 blocks.
    /// @param _cfg The configuration of the inbox.
    /// @param _coreState The core state of the inbox.
    /// @param _frame The frame of the proposal.
    /// @param _isForcedInclusion Whether the proposal is a forced inclusion.
    /// @return coreState_ The updated core state.
    /// @return proposal_ The created proposal.
    function _propose(
        Config memory _cfg,
        CoreState memory _coreState,
        LibBlobs.BlobFrame memory _frame,
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
            provabilityBondGwei: _cfg.provabilityBondGwei,
            livenessBondGwei: _cfg.livenessBondGwei,
            originTimestamp: originTimestamp,
            originBlockNumber: originBlockNumber,
            frame: _frame,
            isForcedInclusion: _isForcedInclusion
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal_));

        _setProposalHash(_cfg, proposalId, proposalHash);

        return (_coreState, proposal_);
    }

    /// @dev Builds a claim record for a single proposal.
    /// @param _cfg The configuration of the inbox.
    /// @param _proposal The proposal to prove.
    /// @param _claim The claim containing the proof details.
    function _buildClaimRecord(
        Config memory _cfg,
        Proposal memory _proposal,
        Claim memory _claim
    )
        private
        view
        returns (ClaimRecord memory claimRecord_)
    {
        bytes32 proposalHash = keccak256(abi.encode(_proposal));
        require(proposalHash == _claim.proposalHash, ProposalHashMismatch());
        require(proposalHash == getProposalHash(_proposal.id), ProposalHashMismatch());

        BondDecision bondDecision = _calculateBondDecision(_cfg, _claim, _proposal);

        claimRecord_ = ClaimRecord({
            claim: _claim,
            proposer: _proposal.proposer,
            livenessBondGwei: _proposal.livenessBondGwei,
            provabilityBondGwei: _proposal.provabilityBondGwei,
            bondDecision: bondDecision,
            nextProposalId: _proposal.id + 1
        });
    }

    /// @dev Calculates the bond decision based on proof timing and prover identity
    /// @notice Bond decisions determine how provability and liveness bonds are handled:
    /// - On-time proofs: Bonds may be refunded or remain unchanged
    /// - Late proofs: Liveness bonds may be slashed and redistributed
    /// - Very late proofs: Provability bonds may also be slashed
    /// The decision affects whether claim records can be aggregated
    /// @param _cfg The configuration of the inbox.
    /// @param _claim The claim containing prover information
    /// @param _proposal The proposal containing timing and proposer information
    /// @return bondDecision_ The bond decision that affects aggregation eligibility
    function _calculateBondDecision(
        Config memory _cfg,
        Claim memory _claim,
        Proposal memory _proposal
    )
        private
        view
        returns (BondDecision bondDecision_)
    {
        unchecked {
            if (block.timestamp <= _proposal.originTimestamp + _cfg.provingWindow) {
                // Proof submitted within the designated proving window (on-time proof)
                return _claim.designatedProver != _proposal.proposer
                    ? BondDecision.L2RefundLiveness
                    : BondDecision.NoOp;
            }

            if (block.timestamp <= _proposal.originTimestamp + _cfg.extendedProvingWindow) {
                // Proof submitted during extended window (late but acceptable proof)
                return _claim.designatedProver == _proposal.proposer
                    ? BondDecision.L1SlashLivenessRewardProver
                    : BondDecision.L2RewardProver;
            }

            // Proof submitted after extended window (very late proof)
            return _claim.designatedProver != _proposal.proposer
                ? BondDecision.L1SlashProvabilityRewardProverL2RefundLiveness
                : BondDecision.L1SlashProvabilityRewardProver;
        }
    }

    /// @dev Finalizes proposals by verifying claim records and updating state.
    /// @param _cfg The configuration of the inbox.
    /// @param _coreState The current core state.
    /// @param _claimRecords The claim records to finalize.
    /// @return coreState_ The updated core state
    function _finalize(
        Config memory _cfg,
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

        for (uint256 i; i < _cfg.maxFinalizationCount; ++i) {
            // Id for the next proposal to be finalized.

            // There is no more unfinalized proposals
            if (proposalId >= _coreState.nextProposalId) break;

            bytes32 storedClaimRecordHash =
                getClaimRecordHash(proposalId, _coreState.lastFinalizedClaimHash);

            // The next proposal cannot be finalized as there is no claim record to link the chain
            if (storedClaimRecordHash == 0) break;

            // There is no claim record provided for the next proposal.
            require(i < _claimRecords.length, ClaimRecordNotProvided());

            claimRecord = _claimRecords[i];

            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
            require(claimRecordHash == storedClaimRecordHash, ClaimRecordHashMismatch());

            _coreState.lastFinalizedProposalId = proposalId;
            _coreState.lastFinalizedClaimHash = keccak256(abi.encode(claimRecord.claim));
            _coreState.bondOperationsHash =
                _processBonds(_cfg, proposalId, claimRecord, _coreState.bondOperationsHash);

            proposalId = _claimRecords[i].nextProposalId;
            hasFinalized = true;
        }

        if (hasFinalized) {
            ISyncedBlockManager(_cfg.syncedBlockManager).saveSyncedBlock(
                ISyncedBlockManager.SyncedBlock({
                    blockNumber: claimRecord.claim.endBlockNumber,
                    blockHash: claimRecord.claim.endBlockHash,
                    stateRoot: claimRecord.claim.endStateRoot
                })
            );
        }

        return _coreState;
    }

    /// @dev Handles bond refunds and penalties based on the bond decision
    /// @notice Processes bonds for potentially aggregated claim records. When a claim
    /// record represents multiple aggregated proposals, liveness bonds are summed
    /// and processed together, reducing the number of bond operations
    /// @param _cfg The configuration of the inbox.
    /// @param _proposalId The first proposal ID in the aggregated record
    /// @param _claimRecord The claim record (may represent multiple proposals)
    /// @param _bondOperationsHash The current hash of bond operations
    /// @return bondOperationsHash_ The updated hash including this operation
    function _processBonds(
        Config memory _cfg,
        uint48 _proposalId,
        ClaimRecord memory _claimRecord,
        bytes32 _bondOperationsHash
    )
        private
        returns (bytes32 bondOperationsHash_)
    {
        LibBondOperation.BondOperation memory bondOperation;
        bondOperation.proposalId = _proposalId;

        Claim memory claim = _claimRecord.claim;
        uint96 livenessBondWei = _claimRecord.livenessBondGwei * 1 gwei;
        uint96 provabilityBondWei = _claimRecord.provabilityBondGwei * 1 gwei;

        if (_claimRecord.bondDecision == BondDecision.NoOp) {
            // No bond operations needed
        } else if (_claimRecord.bondDecision == BondDecision.L2RefundLiveness) {
            // Proposer and designated prover are different entities
            // The designated prover paid a liveness bond on L2 that needs to be refunded
            bondOperation.credit = livenessBondWei;
            bondOperation.receiver = claim.designatedProver;
        } else if (_claimRecord.bondDecision == BondDecision.L1SlashLivenessRewardProver) {
            // Proposer was also the designated prover who failed to prove on time
            // Forfeit their liveness bond but reward the actual prover with half
            IBondManager(_cfg.bondManager).debitBond(_claimRecord.proposer, livenessBondWei);
            IBondManager(_cfg.bondManager).creditBond(
                claim.actualProver, livenessBondWei / REWARD_FRACTION
            );
        } else if (_claimRecord.bondDecision == BondDecision.L2RewardProver) {
            // Reward the actual prover with half of the liveness bond on L2
            bondOperation.credit = livenessBondWei / REWARD_FRACTION;
            bondOperation.receiver = claim.actualProver;
        } else if (
            _claimRecord.bondDecision == BondDecision.L1SlashProvabilityRewardProverL2RefundLiveness
        ) {
            // Proof submitted after extended window (very late proof)
            // Block was difficult to prove, forfeit provability bond but reward prover
            IBondManager(_cfg.bondManager).debitBond(_claimRecord.proposer, provabilityBondWei);
            IBondManager(_cfg.bondManager).creditBond(
                claim.actualProver, provabilityBondWei / REWARD_FRACTION
            );
            // Proposer and designated prover are different entities
            // Refund the designated prover's L2 liveness bond
            bondOperation.credit = livenessBondWei;
            bondOperation.receiver = claim.designatedProver;
        } else if (_claimRecord.bondDecision == BondDecision.L1SlashProvabilityRewardProver) {
            // Proof submitted after extended window, proposer and designated prover are same
            // Forfeit provability bond but reward the actual prover
            IBondManager(_cfg.bondManager).debitBond(_claimRecord.proposer, provabilityBondWei);
            IBondManager(_cfg.bondManager).creditBond(
                claim.actualProver, provabilityBondWei / REWARD_FRACTION
            );
        }

        return LibBondOperation.aggregateBondOperation(_bondOperationsHash, bondOperation);
    }

    function _isForkActive(Config memory _cfg) internal view returns (bool) {
        return _cfg.forkActivationHeight == 0
            || _pacayaStats2.numBatches + 1 == _cfg.forkActivationHeight;
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
    error ProposerNotActive();
    error RingBufferSizeZero();
    error Unauthorized();
}
