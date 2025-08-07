// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EssentialContract } from "contracts/shared/common/EssentialContract.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { ISyncedBlockManager } from "contracts/shared/shasta/iface/ISyncedBlockManager.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../lib/LibBlobs.sol";
import { LibBondOperation } from "contracts/shared/shasta/libs/LibBondOperation.sol";
import { LibDecoder } from "../lib/LibDecoder.sol";

/// @title Inbox
/// @notice Core contract managing L2 block proposals, proofs, and finalization for Taiko's based
/// rollup
/// @dev Implements gas-efficient claim aggregation and ring buffer storage for proposal management
/// @custom:security-contact security@taiko.xyz
contract Inbox is EssentialContract, IInbox {
    using LibDecoder for bytes;

    /// @dev Extended claim record with slot reuse optimization
    /// @dev Uses 256-bit packing: 48-bit proposalId + 208-bit partial parent claim hash
    struct ExtendedClaimRecord {
        bytes32 claimRecordHash;
        uint256 slotReuseMarker;
    }

    /// @dev Proposal storage with optimized claim lookup
    /// @dev Uses default slot optimization to reduce storage costs for common case
    struct ProposalRecord {
        bytes32 proposalHash;
        /// @dev Maps parent claim hash to claim record, with _DEFAULT_SLOT_HASH for optimization
        mapping(bytes32 parentClaimHash => ExtendedClaimRecord claimRecordHash) claimHashLookup;
    }

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    /// @notice Fraction divisor for reward calculations (rewards = bond / REWARD_FRACTION)
    uint256 public constant REWARD_FRACTION = 2;

    /// @notice Bond amount in gwei ensuring proposals can be proven
    uint48 public immutable provabilityBondGwei;
    /// @notice Bond amount in gwei ensuring timely proof submission
    uint48 public immutable livenessBondGwei;
    /// @notice Duration in seconds for designated prover to submit proof
    uint48 public immutable provingWindow;
    /// @notice Extended duration in seconds for any prover to submit proof
    uint48 public immutable extendedProvingWindow;
    /// @notice Minimum bond balance required for proposers
    uint256 public immutable minBondBalance;
    /// @notice Maximum number of proposals to finalize per transaction
    uint256 public immutable maxFinalizationCount;
    /// @notice Size of the ring buffer for proposal storage
    uint256 public immutable ringBufferSize;

    /// @notice Bond manager for handling bond operations
    IBondManager public immutable bondManager;

    /// @notice Manager for synced L2 block state
    ISyncedBlockManager public immutable syncedBlockManager;

    /// @notice Verifier for validity proofs
    IProofVerifier public immutable proofVerifier;

    /// @notice Checker for proposer eligibility
    IProposerChecker public immutable proposerChecker;

    /// @notice Store for forced inclusion transactions
    IForcedInclusionStore public immutable forcedInclusionStore;

    /// @dev Default slot key for storage optimization
    bytes32 private immutable _DEFAULT_SLOT_HASH = bytes32(uint256(1));

    /// @dev Hash of the core state for atomic updates
    bytes32 private coreStateHash;

    /// @dev Ring buffer for proposal storage with automatic slot reuse
    mapping(uint256 bufferSlot => ProposalRecord proposalRecord) private proposalRingBuffer;

    uint256[48] private __gap;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Initializes the Inbox contract with configuration parameters
    /// @param _provabilityBondGwei Bond amount ensuring proposals can be proven
    /// @param _livenessBondGwei Bond amount ensuring timely proof submission
    /// @param _provingWindow Duration for designated prover priority
    /// @param _extendedProvingWindow Duration for open proof submission
    /// @param _minBondBalance Minimum bond balance required for proposers
    /// @param _maxFinalizationCount Maximum proposals to finalize per transaction
    /// @param _ringBufferSize Size of the proposal ring buffer
    /// @param _bondManager Address of the bond manager contract
    /// @param _syncedBlockManager Address of the synced block manager
    /// @param _proofVerifier Address of the proof verifier
    /// @param _proposerChecker Address of the proposer checker
    /// @param _forcedInclusionStore Address of the forced inclusion store
    constructor(
        uint48 _provabilityBondGwei,
        uint48 _livenessBondGwei,
        uint48 _provingWindow,
        uint48 _extendedProvingWindow,
        uint256 _minBondBalance,
        uint256 _maxFinalizationCount,
        uint256 _ringBufferSize,
        address _bondManager,
        address _syncedBlockManager,
        address _proofVerifier,
        address _proposerChecker,
        address _forcedInclusionStore
    )
        EssentialContract()
    {
        provabilityBondGwei = _provabilityBondGwei;
        livenessBondGwei = _livenessBondGwei;
        provingWindow = _provingWindow;
        extendedProvingWindow = _extendedProvingWindow;
        minBondBalance = _minBondBalance;
        maxFinalizationCount = _maxFinalizationCount;
        ringBufferSize = _ringBufferSize;
        bondManager = IBondManager(_bondManager);
        syncedBlockManager = ISyncedBlockManager(_syncedBlockManager);
        proofVerifier = IProofVerifier(_proofVerifier);
        proposerChecker = IProposerChecker(_proposerChecker);
        forcedInclusionStore = IForcedInclusionStore(_forcedInclusionStore);
    }

    /// @notice Initializes the contract with genesis state
    /// @param _owner Owner address for contract administration
    /// @param _genesisBlockHash Initial L2 block hash to start the chain
    function init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Essential_init(_owner);

        Claim memory claim;
        claim.endBlockHash = _genesisBlockHash;

        CoreState memory coreState;
        coreState.nextProposalId = 1;
        coreState.lastFinalizedClaimHash = keccak256(abi.encode(claim));
        coreStateHash = keccak256(abi.encode(coreState));
    }

    // -------------------------------------------------------------------------
    // External & Public Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IInbox
    function propose(bytes calldata, /*_lookahead*/ bytes calldata _data) external nonReentrant {
        proposerChecker.checkProposer(msg.sender);
        if (bondManager.getBondBalance(msg.sender) < minBondBalance) revert InsufficientBond();

        (
            CoreState memory coreState,
            LibBlobs.BlobLocator memory blobLocator,
            ClaimRecord[] memory claimRecords
        ) = _data.decodeProposeData();

        if (keccak256(abi.encode(coreState)) != coreStateHash) {
            revert InvalidState();
        }

        // Check if new proposals would exceed the unfinalized proposal capacity
        if (coreState.nextProposalId - coreState.lastFinalizedProposalId > getCapacity()) {
            revert ExceedsUnfinalizedProposalCapacity();
        }

        Proposal memory proposal;

        // Handle forced inclusion if required
        if (forcedInclusionStore.isOldestForcedInclusionDue()) {
            IForcedInclusionStore.ForcedInclusion memory forcedInclusion =
                forcedInclusionStore.consumeOldestForcedInclusion(msg.sender);

            (coreState, proposal) = _propose(coreState, forcedInclusion.frame, true);
            emit Proposed(proposal, coreState);
        }

        // Create regular proposal
        LibBlobs.BlobFrame memory frame = LibBlobs.validateBlobLocator(blobLocator);
        (coreState, proposal) = _propose(coreState, frame, false);
        // Finalize proved proposals
        coreState = _finalize(coreState, claimRecords);
        emit Proposed(proposal, coreState);

        _setCoreStateHash(keccak256(abi.encode(coreState)));
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        (Proposal[] memory proposals, Claim[] memory claims) = _data.decodeProveData();

        if (proposals.length != claims.length) revert InconsistentParams();

        ClaimRecord[] memory claimRecords = new ClaimRecord[](proposals.length);

        for (uint256 i; i < proposals.length; ++i) {
            claimRecords[i] = _buildClaimRecord(proposals[i], claims[i]);
            emit Proved(proposals[i], claimRecords[i]);
        }

        (uint48[] memory proposalIds, ClaimRecord[] memory aggregatedClaimRecords) =
            _aggregateClaimRecords(proposals, claimRecords);

        for (uint256 i; i < aggregatedClaimRecords.length; ++i) {
            bytes32 claimRecordHash = keccak256(abi.encode(aggregatedClaimRecords[i]));
            // Use the parentClaimHash from the aggregated claim record
            _setClaimRecordHash(
                proposalIds[i], aggregatedClaimRecords[i].claim.parentClaimHash, claimRecordHash
            );
        }

        bytes32 claimsHash = keccak256(abi.encode(claims));
        proofVerifier.verifyProof(claimsHash, _proof);
    }

    /// @notice Returns the current core state hash
    /// @return coreStateHash_ Hash of the current core state
    function getCoreStateHash() public view returns (bytes32 coreStateHash_) {
        coreStateHash_ = coreStateHash;
    }

    /// @notice Retrieves the proposal hash from the ring buffer
    /// @param _proposalId Proposal ID to look up
    /// @return proposalHash_ Hash of the proposal, or zero if slot is empty/reused
    function getProposalHash(uint48 _proposalId) public view returns (bytes32 proposalHash_) {
        uint256 bufferSlot = _proposalId % ringBufferSize;
        proposalHash_ = proposalRingBuffer[bufferSlot].proposalHash;
    }

    /// @notice Retrieves claim record hash for a specific proposal and parent claim
    /// @dev Uses slot reuse optimization for gas efficiency
    /// @param _proposalId Proposal ID to query
    /// @param _parentClaimHash Parent claim hash for chain continuity
    /// @return claimRecordHash_ Hash of the claim record, or zero if not found
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

    /// @notice Returns the maximum number of unfinalized proposals
    /// @dev One slot is reserved to prevent overwriting unfinalized proposals
    /// @return _ Maximum unfinalized proposal capacity (ringBufferSize - 1)
    function getCapacity() public view returns (uint256) {
        // The ring buffer can hold ringBufferSize proposals total, but we need to ensure
        // unfinalized proposals are not overwritten. Therefore, the maximum number of
        // unfinalized proposals is ringBufferSize - 1.
        unchecked {
            return ringBufferSize - 1;
        }
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @dev Updates the core state hash
    function _setCoreStateHash(bytes32 _coreStateHash) internal {
        coreStateHash = _coreStateHash;
    }

    /// @dev Stores proposal hash in the ring buffer
    function _setProposalHash(uint48 _proposalId, bytes32 _proposalHash) internal {
        uint256 bufferSlot = _proposalId % ringBufferSize;
        proposalRingBuffer[bufferSlot].proposalHash = _proposalHash;
    }

    /// @dev Stores claim record hash with slot reuse optimization
    function _setClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
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
        } else if (_isPartialParentClaimHashMatch(partialParentClaimHash, _parentClaimHash)) {
            // Same proposal ID and same parent claim hash (partial match), update the default slot
            record.claimRecordHash = _claimRecordHash;
        } else {
            // Same proposal ID but different parent claim hash, use direct mapping
            proposalRecord.claimHashLookup[_parentClaimHash].claimRecordHash = _claimRecordHash;
        }
    }

    /// @dev Unpacks slot reuse marker into components
    function _decodeSlotReuseMarker(uint256 _slotReuseMarker)
        internal
        pure
        returns (uint48 proposalId_, bytes32 partialParentClaimHash_)
    {
        proposalId_ = uint48(_slotReuseMarker >> 208);
        partialParentClaimHash_ = bytes32(_slotReuseMarker << 48);
    }

    /// @dev Packs proposal ID and parent claim hash for storage optimization
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

    /// @dev Compares high 208 bits of parent claim hashes
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

    /// @dev Aggregates consecutive claim records for gas optimization
    /// @dev Combines claims with matching parent hash, bond decision, and prover
    /// @dev Example: 10 consecutive claims by same prover = 1 aggregated record
    /// @param _proposals Proposals being proven
    /// @param _claimRecords Claim records to aggregate
    /// @return _ Proposal IDs for each aggregated group
    /// @return _ Aggregated claim records
    function _aggregateClaimRecords(
        Proposal[] memory _proposals,
        ClaimRecord[] memory _claimRecords
    )
        private
        pure
        returns (uint48[] memory, ClaimRecord[] memory)
    {
        unchecked {
            if (_claimRecords.length == 0) {
                return (new uint48[](0), new ClaimRecord[](0));
            }

            // Allocate proposal IDs array with max possible size
            uint48[] memory proposalIds = new uint48[](_claimRecords.length);
            proposalIds[0] = _proposals[0].id;

            // Reuse _claimRecords array for aggregation
            uint256 writeIndex = 0;
            uint256 readIndex = 1;

            while (readIndex < _claimRecords.length) {
                ClaimRecord memory writeRecord = _claimRecords[writeIndex];
                ClaimRecord memory readRecord = _claimRecords[readIndex];

                if (_canAggregate(writeRecord, readRecord, _proposals[readIndex].id)) {
                    // Update the aggregated record at writeIndex to span multiple proposals
                    writeRecord.nextProposalId = readRecord.nextProposalId;
                    writeRecord.claim.endBlockNumber = readRecord.claim.endBlockNumber;
                    writeRecord.claim.endBlockHash = readRecord.claim.endBlockHash;
                    writeRecord.claim.endStateRoot = readRecord.claim.endStateRoot;

                    if (
                        writeRecord.bondDecision == BondDecision.L2RefundLiveness
                            || writeRecord.bondDecision == BondDecision.L2RewardProver
                    ) {
                        writeRecord.livenessBondGwei += readRecord.livenessBondGwei;
                    } else {
                        // assert(writeRecord.bondDecision == BondDecision.NoOp);
                        writeRecord.livenessBondGwei = 0;
                    }
                } else {
                    // Move to next write position and copy the current record
                    writeIndex++;
                    if (writeIndex != readIndex) {
                        _claimRecords[writeIndex] = _claimRecords[readIndex];
                    }
                    proposalIds[writeIndex] = _proposals[readIndex].id;
                }
                readIndex++;
            }

            // Final aggregated count
            uint256 aggregatedCount = writeIndex + 1;

            // Set the correct length for proposalIds array using assembly
            assembly {
                mstore(proposalIds, aggregatedCount)
                mstore(_claimRecords, aggregatedCount)
            }
            return (proposalIds, _claimRecords);
        }
    }

    /// @dev Checks if two claim records can be aggregated
    /// @dev Requirements: consecutive, same parent/decision, no overflow
    /// @param _recordA First claim record
    /// @param _recordB Second claim record
    /// @param _proposalBId Proposal ID of second record
    /// @return _ True if aggregatable
    function _canAggregate(
        ClaimRecord memory _recordA,
        ClaimRecord memory _recordB,
        uint48 _proposalBId
    )
        private
        pure
        returns (bool)
    {
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

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @dev Creates a new proposal and updates state
    /// @param _coreState Current core state
    /// @param _frame Blob frame with L2 block data
    /// @param _isForcedInclusion Flag for forced inclusion
    /// @return coreState_ Updated core state
    /// @return proposal_ Created proposal
    function _propose(
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
            provabilityBondGwei: provabilityBondGwei,
            livenessBondGwei: livenessBondGwei,
            originTimestamp: originTimestamp,
            originBlockNumber: originBlockNumber,
            frame: _frame,
            isForcedInclusion: _isForcedInclusion
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal_));

        _setProposalHash(proposalId, proposalHash);

        return (_coreState, proposal_);
    }

    /// @dev Constructs claim record with bond decision
    /// @param _proposal Proposal being proven
    /// @param _claim Claim with proof details
    function _buildClaimRecord(
        Proposal memory _proposal,
        Claim memory _claim
    )
        private
        view
        returns (ClaimRecord memory claimRecord_)
    {
        bytes32 proposalHash = keccak256(abi.encode(_proposal));
        if (proposalHash != _claim.proposalHash) revert ProposalHashMismatch();
        if (proposalHash != getProposalHash(_proposal.id)) revert ProposalHashMismatch();

        BondDecision bondDecision = _calculateBondDecision(_claim, _proposal);

        claimRecord_ = ClaimRecord({
            claim: _claim,
            proposer: _proposal.proposer,
            livenessBondGwei: _proposal.livenessBondGwei,
            provabilityBondGwei: _proposal.provabilityBondGwei,
            bondDecision: bondDecision,
            nextProposalId: _proposal.id + 1
        });
    }

    /// @dev Determines bond handling based on proof timing and prover
    /// @dev On-time: refund/no-op, Late: slash liveness, Very late: slash provability
    /// @param _claim Claim with prover information
    /// @param _proposal Proposal with timing data
    /// @return bondDecision_ Bond decision for this proof
    function _calculateBondDecision(
        Claim memory _claim,
        Proposal memory _proposal
    )
        private
        view
        returns (BondDecision bondDecision_)
    {
        unchecked {
            if (block.timestamp <= _proposal.originTimestamp + provingWindow) {
                // Proof submitted within the designated proving window (on-time proof)
                return _claim.designatedProver != _proposal.proposer
                    ? BondDecision.L2RefundLiveness
                    : BondDecision.NoOp;
            }

            if (block.timestamp <= _proposal.originTimestamp + extendedProvingWindow) {
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

    /// @dev Finalizes proposals by verifying claims and processing bonds
    /// @param _coreState Current core state
    /// @param _claimRecords Claims to verify and finalize
    /// @return coreState_ Updated core state after finalization
    function _finalize(
        CoreState memory _coreState,
        ClaimRecord[] memory _claimRecords
    )
        private
        returns (CoreState memory coreState_)
    {
        // The last finalized claim record.
        ClaimRecord memory claimRecord;
        bool hasFinalized;

        for (uint256 i; i < maxFinalizationCount; ++i) {
            // Id for the next proposal to be finalized.
            uint48 proposalId = _coreState.lastFinalizedProposalId + 1;

            // There is no more unfinalized proposals
            if (proposalId == _coreState.nextProposalId) break;

            bytes32 storedClaimRecordHash =
                getClaimRecordHash(proposalId, _coreState.lastFinalizedClaimHash);

            // The next proposal cannot be finalized as there is no claim record to link the chain
            if (storedClaimRecordHash == 0) break;

            // There is no claim record provided for the next proposal.
            if (i >= _claimRecords.length) revert ClaimRecordNotProvided();

            claimRecord = _claimRecords[i];

            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
            if (claimRecordHash != storedClaimRecordHash) revert ClaimRecordHashMismatch();

            _coreState.lastFinalizedProposalId = proposalId;
            _coreState.lastFinalizedClaimHash = keccak256(abi.encode(claimRecord.claim));
            _coreState.bondOperationAggregationHash =
                _processBonds(proposalId, claimRecord, _coreState.bondOperationAggregationHash);
            hasFinalized = true;
        }

        if (hasFinalized) {
            syncedBlockManager.saveSyncedBlock(
                ISyncedBlockManager.SyncedBlock({
                    blockNumber: claimRecord.claim.endBlockNumber,
                    blockHash: claimRecord.claim.endBlockHash,
                    stateRoot: claimRecord.claim.endStateRoot
                })
            );
        }

        return _coreState;
    }

    /// @dev Processes bond operations based on bond decision
    /// @dev Handles aggregated bonds for multiple proposals efficiently
    /// @param _proposalId First proposal ID in aggregated record
    /// @param _claimRecord Claim record (may be aggregated)
    /// @param _bondOperationAggregationHash Current bond operations hash
    /// @return bondOperationAggregationHash_ Updated hash with new operation
    function _processBonds(
        uint48 _proposalId,
        ClaimRecord memory _claimRecord,
        bytes32 _bondOperationAggregationHash
    )
        private
        returns (bytes32 bondOperationAggregationHash_)
    {
        LibBondOperation.BondOperation memory bondOperation;
        bondOperation.proposalId = _proposalId;

        Claim memory claim = _claimRecord.claim;
        uint256 livenessBondWei = uint256(_claimRecord.livenessBondGwei) * 1 gwei;
        uint256 provabilityBondWei = uint256(_claimRecord.provabilityBondGwei) * 1 gwei;

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
            bondManager.debitBond(_claimRecord.proposer, livenessBondWei);
            bondManager.creditBond(claim.actualProver, livenessBondWei / REWARD_FRACTION);
        } else if (_claimRecord.bondDecision == BondDecision.L2RewardProver) {
            // Reward the actual prover with half of the liveness bond on L2
            bondOperation.credit = livenessBondWei / REWARD_FRACTION;
            bondOperation.receiver = claim.actualProver;
        } else if (
            _claimRecord.bondDecision == BondDecision.L1SlashProvabilityRewardProverL2RefundLiveness
        ) {
            // Proof submitted after extended window (very late proof)
            // Block was difficult to prove, forfeit provability bond but reward prover
            bondManager.debitBond(_claimRecord.proposer, provabilityBondWei);
            bondManager.creditBond(claim.actualProver, provabilityBondWei / REWARD_FRACTION);
            // Proposer and designated prover are different entities
            // Refund the designated prover's L2 liveness bond
            bondOperation.credit = livenessBondWei;
            bondOperation.receiver = claim.designatedProver;
        } else if (_claimRecord.bondDecision == BondDecision.L1SlashProvabilityRewardProver) {
            // Proof submitted after extended window, proposer and designated prover are same
            // Forfeit provability bond but reward the actual prover
            bondManager.debitBond(_claimRecord.proposer, provabilityBondWei);
            bondManager.creditBond(claim.actualProver, provabilityBondWei / REWARD_FRACTION);
        }

        return LibBondOperation.aggregateBondOperation(_bondOperationAggregationHash, bondOperation);
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ClaimRecordHashMismatch();
    error ClaimRecordNotProvided();
    error ExceedsUnfinalizedProposalCapacity();
    error InconsistentParams();
    error InsufficientBond();
    error InvalidState();
    error ProposalHashMismatch();
    error RingBufferSizeZero();
    error Unauthorized();
    error InvalidForcedInclusion();
}
