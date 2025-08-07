// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EssentialContract } from "contracts/shared/common/EssentialContract.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { ISyncedBlockManager } from "contracts/shared/shasta/iface/ISyncedBlockManager.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibDecoder } from "../libs/LibDecoder.sol";
import { LibBondOperation } from "contracts/shared/shasta/libs/LibBondOperation.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture.
/// @custom:security-contact security@taiko.xyz

contract Inbox is EssentialContract, IInbox {
    using LibDecoder for bytes;

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

    uint256 public constant REWARD_FRACTION = 2;

    uint48 public immutable provabilityBondGwei;
    uint48 public immutable livenessBondGwei;
    uint48 public immutable provingWindow;
    uint48 public immutable extendedProvingWindow;
    uint256 public immutable minBondBalance;
    uint256 public immutable maxFinalizationCount;
    uint256 public immutable ringBufferSize;

    /// @notice The bond manager contract
    IBondManager public immutable bondManager;

    /// @notice The synced block manager contract
    ISyncedBlockManager public immutable syncedBlockManager;

    /// @notice The proof verifier contract
    IProofVerifier public immutable proofVerifier;

    /// @notice The proposer checker contract
    IProposerChecker public immutable proposerChecker;

    /// @notice The forced inclusion store contract
    IForcedInclusionStore public immutable forcedInclusionStore;

    bytes32 private immutable _DEFAULT_SLOT_HASH = bytes32(uint256(1));

    /// @notice The hash of the core state.
    bytes32 private coreStateHash;

    /// @notice Ring buffer for storing proposal records.
    /// @dev Key is proposalId % ringBufferSize
    mapping(uint256 bufferSlot => ProposalRecord proposalRecord) private proposalRingBuffer;

    uint256[48] private __gap;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Initializes the Inbox contract with configuration parameters
    /// @param _provabilityBondGwei The bond required for block provability
    /// @param _livenessBondGwei The bond required for prover liveness
    /// @param _provingWindow The initial proving window duration
    /// @param _extendedProvingWindow The extended proving window duration
    /// @param _minBondBalance The minimum bond balance required for proposers
    /// @param _maxFinalizationCount The maximum number of finalizations allowed
    /// @param _ringBufferSize The size of the ring buffer (must be > 0)
    /// @param _bondManager The address of the bond manager contract
    /// @param _syncedBlockManager The address of the synced block manager contract
    /// @param _proofVerifier The address of the proof verifier contract
    /// @param _proposerChecker The address of the proposer checker contract
    /// @param _forcedInclusionStore The address of the forced inclusion store contract
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
            LibBlobs.BlobReference memory blobReference,
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

            (coreState, proposal) = _propose(coreState, forcedInclusion.blobSlice, true);
            emit Proposed(proposal, coreState);
        }

        // Create regular proposal
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(blobReference);
        (coreState, proposal) = _propose(coreState, blobSlice, false);
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
            // TODO: emit Proved event for aggregated claim records
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

    /// @notice Gets the hash of the core state.
    /// @return coreStateHash_ The hash of the current core state.
    function getCoreStateHash() public view returns (bytes32 coreStateHash_) {
        coreStateHash_ = coreStateHash;
    }

    /// @notice Gets the proposal hash for a given proposal ID.
    /// @param _proposalId The proposal ID to look up.
    /// @return proposalHash_ The hash stored at the proposal's ring buffer slot.
    function getProposalHash(uint48 _proposalId) public view returns (bytes32 proposalHash_) {
        uint256 bufferSlot = _proposalId % ringBufferSize;
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

    /// @notice Gets the capacity for unfinalized proposals.
    /// @return _ The maximum number of unfinalized proposals that can exist.
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

    /// @dev Sets the hash of the core state.
    function _setCoreStateHash(bytes32 _coreStateHash) internal {
        coreStateHash = _coreStateHash;
    }

    /// @dev Sets the proposal hash for a given proposal ID.
    function _setProposalHash(uint48 _proposalId, bytes32 _proposalHash) internal {
        uint256 bufferSlot = _proposalId % ringBufferSize;
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

    /// @dev Aggregates consecutive claim records to reduce gas costs
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
    /// @return _ Array of proposal IDs (first ID of each aggregated group)
    /// @return _ Array of aggregated claim records
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

    /// @dev Checks if two claim records can be aggregated for gas optimization
    /// @notice Aggregation rules ensure that only compatible records are combined:
    /// - Records must be consecutive (recordA.nextProposalId == proposalBId)
    /// - Must share the same parent claim hash (same chain)
    /// - Must have the same bond decision
    /// - For certain bond decisions, must have the same prover
    /// - Liveness bond sum must not overflow uint48
    /// @param _recordA The first claim record
    /// @param _recordB The second claim record
    /// @param _proposalBId The proposal ID of the second claim record
    /// @return _ True if the records can be aggregated, false otherwise
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

    /// @dev Proposes a new proposal of L2 blocks.
    /// @param _coreState The core state of the inbox.
    /// @param _blobSlice The blob slice of the proposal.
    /// @param _isForcedInclusion Whether the proposal is a forced inclusion.
    /// @return coreState_ The updated core state.
    /// @return proposal_ The created proposal.
    function _propose(
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
            provabilityBondGwei: provabilityBondGwei,
            livenessBondGwei: livenessBondGwei,
            originTimestamp: originTimestamp,
            originBlockNumber: originBlockNumber,
            blobSlice: _blobSlice,
            isForcedInclusion: _isForcedInclusion
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal_));

        _setProposalHash(proposalId, proposalHash);

        return (_coreState, proposal_);
    }

    /// @dev Builds a claim record for a single proposal.
    /// @param _proposal The proposal to prove.
    /// @param _claim The claim containing the proof details.
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

    /// @dev Calculates the bond decision based on proof timing and prover identity
    /// @notice Bond decisions determine how provability and liveness bonds are handled:
    /// - On-time proofs: Bonds may be refunded or remain unchanged
    /// - Late proofs: Liveness bonds may be slashed and redistributed
    /// - Very late proofs: Provability bonds may also be slashed
    /// The decision affects whether claim records can be aggregated
    /// @param _claim The claim containing prover information
    /// @param _proposal The proposal containing timing and proposer information
    /// @return bondDecision_ The bond decision that affects aggregation eligibility
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

    /// @dev Finalizes proposals by verifying claim records and updating state.
    /// @param _coreState The current core state.
    /// @param _claimRecords The claim records to finalize.
    /// @return coreState_ The updated core state
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

        uint48 proposalId = _coreState.lastFinalizedProposalId + 1;

        for (uint256 i; i < maxFinalizationCount; ++i) {
            // Id for the next proposal to be finalized.

            // There is no more unfinalized proposals
            if (proposalId >= _coreState.nextProposalId) break;

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
            _coreState.bondOperationsHash =
                _processBonds(proposalId, claimRecord, _coreState.bondOperationsHash);

            proposalId = _claimRecords[i].nextProposalId;
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

    /// @dev Handles bond refunds and penalties based on the bond decision
    /// @notice Processes bonds for potentially aggregated claim records. When a claim
    /// record represents multiple aggregated proposals, liveness bonds are summed
    /// and processed together, reducing the number of bond operations
    /// @param _proposalId The first proposal ID in the aggregated record
    /// @param _claimRecord The claim record (may represent multiple proposals)
    /// @param _bondOperationsHash The current hash of bond operations
    /// @return bondOperationsHash_ The updated hash including this operation
    function _processBonds(
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

        emit BondRequest(bondOperation);

        return LibBondOperation.aggregateBondOperation(_bondOperationsHash, bondOperation);
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
