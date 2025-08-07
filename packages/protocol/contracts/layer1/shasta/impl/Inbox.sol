// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { ISyncedBlockManager } from "../../../shared/shasta/iface/ISyncedBlockManager.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibDecoder } from "../lib/LibDecoder.sol";
import { EssentialContract } from "contracts/shared/common/EssentialContract.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture.
/// @custom:security-contact security@taiko.xyz

contract Inbox is EssentialContract, IInbox {
    using LibDecoder for bytes;

    struct BondOperation {
        uint48 proposalId;
        address receiver;
        uint256 credit;
    }

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

    uint48 public immutable provabilityBond;
    uint48 public immutable livenessBond;
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
    /// @param _provabilityBond The bond required for block provability
    /// @param _livenessBond The bond required for prover liveness
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
        uint48 _provabilityBond,
        uint48 _livenessBond,
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
    ) {
        if (_ringBufferSize == 0) revert RingBufferSizeZero();
        provabilityBond = _provabilityBond;
        livenessBond = _livenessBond;
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
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IInbox
    function propose(bytes calldata, /*_lookahead*/ bytes calldata _data) external nonReentrant {
        proposerChecker.checkProposer(msg.sender);
        if (bondManager.getBondBalance(msg.sender) < minBondBalance) revert InsufficientBond();

        (
            CoreState memory coreState,
            BlobLocator memory blobLocator,
            Frame memory forcedInclusionFrame,
            ClaimRecord[] memory claimRecords
        ) = _data.decodeProposeData();

        if (keccak256(abi.encode(coreState)) != getCoreStateHash()) {
            revert InvalidState();
        }

        // Check if new proposals would exceed the unfinalized proposal capacity
        uint256 unfinalizedProposalCapacity = getCapacity();

        if (
            coreState.nextProposalId - coreState.lastFinalizedProposalId
                > unfinalizedProposalCapacity
        ) {
            revert ExceedsUnfinalizedProposalCapacity();
        }

        // Create regular proposal
        Frame memory frame = _validateBlobLocator(blobLocator);
        Proposal memory proposal;
        (coreState, proposal) = _propose(coreState, frame, false);

        // Handle forced inclusion if required
        Proposal memory forcedInclusionProposal;
        bool hasForcedInclusion = forcedInclusionFrame.blobHashes.length > 0;

        if (hasForcedInclusion) {
            (coreState, forcedInclusionProposal) =
                _processForcedInclusion(coreState, forcedInclusionFrame);
        } else {
            // Ensure no forced inclusion is due when none is provided
            _ensureNoForcedInclusionDue();
        }

        // Build proposals array
        Proposal[] memory proposals =
            _buildProposalsArray(proposal, forcedInclusionProposal, hasForcedInclusion);

        // Finalize proved proposals
        coreState = _finalize(coreState, claimRecords);

        _setCoreStateHash(keccak256(abi.encode(coreState)));

        emit Proposed(proposals, coreState);
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        (Proposal[] memory proposals, Claim[] memory claims) = _data.decodeProveData();

        if (proposals.length != claims.length) revert InconsistentParams();

        for (uint256 i; i < proposals.length; ++i) {
            _prove(proposals[i], claims[i]);
        }

        bytes32 claimsHash = keccak256(abi.encode(claims));
        proofVerifier.verifyProof(claimsHash, _proof);
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @dev Proposes a new proposal of L2 blocks.
    /// @param _coreState The core state of the inbox.
    /// @param _frame The frame of the proposal.
    /// @param _isForcedInclusion Whether the proposal is a forced inclusion.
    /// @return coreState_ The updated core state.
    /// @return proposal_ The created proposal.
    function _propose(
        CoreState memory _coreState,
        Frame memory _frame,
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
            provabilityBond: provabilityBond,
            livenessBond: livenessBond,
            originTimestamp: originTimestamp,
            originBlockNumber: originBlockNumber,
            frame: _frame,
            isForcedInclusion: _isForcedInclusion
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal_));
        _setProposalHash(proposalId, proposalHash);

        return (_coreState, proposal_);
    }

    /// @dev Proves a single proposal by validating the claim and storing the claim record.
    /// @param _proposal The proposal to prove.
    /// @param _claim The claim containing the proof details.
    function _prove(Proposal memory _proposal, Claim memory _claim) private {
        bytes32 proposalHash = keccak256(abi.encode(_proposal));
        if (proposalHash != _claim.proposalHash) revert ProposalHashMismatch();
        if (proposalHash != getProposalHash(_proposal.id)) {
            revert ProposalHashMismatch();
        }

        ProofTiming proofTiming = block.timestamp <= _proposal.originTimestamp + provingWindow
            ? ProofTiming.InProvingWindow
            : block.timestamp <= _proposal.originTimestamp + extendedProvingWindow
                ? ProofTiming.InExtendedProvingWindow
                : ProofTiming.OutOfExtendedProvingWindow;

        ClaimRecord memory claimRecord = ClaimRecord({
            claim: _claim,
            proposer: _proposal.proposer,
            livenessBond: _proposal.livenessBond,
            provabilityBond: _proposal.provabilityBond,
            proofTiming: proofTiming
        });

        bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
        _setClaimRecordHash(_proposal.id, _claim.parentClaimHash, claimRecordHash);
        emit Proved(_proposal, claimRecord);
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
            _coreState.bondOperationsHash =
                _processBonds(proposalId, claimRecord, _coreState.bondOperationsHash);
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

    /// @dev Handles bond refunds and penalties based on proof timing and prover identity.
    /// @param _proposalId The ID of the proposal.
    /// @param _claimRecord The claim record containing bond and timing information.
    /// @param _bondOperationsHash The hash of the bond operations.
    /// @return bondOperationsHash_ The updated hash of the bond operations.
    function _processBonds(
        uint48 _proposalId,
        ClaimRecord memory _claimRecord,
        bytes32 _bondOperationsHash
    )
        private
        returns (bytes32 bondOperationsHash_)
    {
        uint48 credit;
        address receiver;

        Claim memory claim = _claimRecord.claim;
        uint256 livenessBondWei = uint256(_claimRecord.livenessBond) * 1 gwei;
        uint256 provabilityBondWei = uint256(_claimRecord.provabilityBond) * 1 gwei;

        if (_claimRecord.proofTiming == ProofTiming.InProvingWindow) {
            // Proof submitted within the designated proving window (on-time proof)
            // The designated prover successfully proved the block on time

            if (claim.designatedProver != _claimRecord.proposer) {
                // Proposer and designated prover are different entities
                // The designated prover paid a liveness bond on L2 that needs to be refunded
                credit = _claimRecord.livenessBond;
                receiver = claim.designatedProver;
            }
        } else if (_claimRecord.proofTiming == ProofTiming.InExtendedProvingWindow) {
            // Proof submitted during extended window (late but acceptable proof)
            // The designated prover failed to prove on time, but another prover stepped in

            if (claim.designatedProver == _claimRecord.proposer) {
                bondManager.debitBond(_claimRecord.proposer, livenessBondWei);
                // Proposer was also the designated prover who failed to prove on time
                // Forfeit their liveness bond but reward the actual prover with half
                bondManager.creditBond(claim.actualProver, livenessBondWei / 2);
            } else {
                // Reward the actual prover with half of the liveness bond on L2
                credit = _claimRecord.livenessBond / 2;
                receiver = claim.actualProver;
            }
        } else {
            // Proof submitted after extended window (very late proof)
            // Block was difficult to prove, forfeit provability bond but reward prover
            bondManager.debitBond(_claimRecord.proposer, provabilityBondWei);
            bondManager.creditBond(claim.actualProver, provabilityBondWei / 2);

            // Forfeit proposer's provability bond but give half to the actual prover
            if (claim.designatedProver != _claimRecord.proposer) {
                // Proposer and designated prover are different entities
                // Refund the designated prover's L2 liveness bond
                credit = _claimRecord.livenessBond;
                receiver = claim.designatedProver;
            }
        }

        if (credit == 0) {
            return _bondOperationsHash;
        } else {
            BondOperation memory bondOperation =
                BondOperation({ proposalId: _proposalId, receiver: receiver, credit: credit });

            return keccak256(abi.encode(_bondOperationsHash, bondOperation));
        }
    }

    /// @dev Validates a blob locator and converts it to a frame.
    /// @param _blobLocator The blob locator to validate.
    /// @return frame_ The frame.
    function _validateBlobLocator(BlobLocator memory _blobLocator)
        private
        view
        returns (Frame memory frame_)
    {
        if (_blobLocator.numBlobs == 0) revert InvalidBlobLocator();

        bytes32[] memory blobHashes = new bytes32[](_blobLocator.numBlobs);
        for (uint48 i; i < _blobLocator.numBlobs; ++i) {
            blobHashes[i] = blobhash(_blobLocator.blobStartIndex + i);
            if (blobHashes[i] == 0) revert BlobNotFound();
        }

        return Frame({ blobHashes: blobHashes, offset: _blobLocator.offset });
    }

    /// @dev Processes a forced inclusion proposal and validates it against the stored data on the
    /// `ForcedInclusionStore` contract
    /// @param _coreState The current core state
    /// @param _forcedInclusionFrame The frame containing forced inclusion data
    /// @return coreState_ Updated core state
    /// @return proposal_ The created forced inclusion proposal
    function _processForcedInclusion(
        CoreState memory _coreState,
        Frame memory _forcedInclusionFrame
    )
        private
        returns (CoreState memory coreState_, Proposal memory proposal_)
    {
        // Create the forced inclusion proposal
        (coreState_, proposal_) = _propose(_coreState, _forcedInclusionFrame, true);

        // Consume and validate the oldest forced inclusion
        IForcedInclusionStore.ForcedInclusion memory consumed =
            forcedInclusionStore.consumeOldestForcedInclusion(msg.sender);

        _validateForcedInclusion(consumed, _forcedInclusionFrame);
    }

    /// @dev Validates that a consumed forced inclusion matches the provided frame
    /// @param _consumed The consumed forced inclusion from storage
    /// @param _frame The frame provided by the proposer
    function _validateForcedInclusion(
        IForcedInclusionStore.ForcedInclusion memory _consumed,
        Frame memory _frame
    )
        private
        pure
    {
        if (_consumed.blobHash != _frame.blobHashes[0]) {
            revert InvalidForcedInclusion();
        }
        if (_consumed.blobByteOffset != _frame.offset) {
            revert InvalidForcedInclusion();
        }
    }

    /// @dev Ensures no forced inclusion is due when none is provided
    function _ensureNoForcedInclusionDue() private view {
        if (forcedInclusionStore.isOldestForcedInclusionDue()) {
            revert InvalidForcedInclusion();
        }
    }

    /// @dev Builds the proposals array based on whether forced inclusion exists
    /// @param _proposal The regular proposal
    /// @param _forcedInclusionProposal The forced inclusion proposal (if any)
    /// @param _hasForcedInclusion Whether a forced inclusion exists
    /// @return proposals_ Array containing one or two proposals
    function _buildProposalsArray(
        Proposal memory _proposal,
        Proposal memory _forcedInclusionProposal,
        bool _hasForcedInclusion
    )
        private
        pure
        returns (Proposal[] memory proposals_)
    {
        if (_hasForcedInclusion) {
            proposals_ = new Proposal[](2);
            proposals_[0] = _proposal;
            proposals_[1] = _forcedInclusionProposal;
        } else {
            proposals_ = new Proposal[](1);
            proposals_[0] = _proposal;
        }
    }

    // -------------------------------------------------------------------------
    // Public View Functions
    // -------------------------------------------------------------------------

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
    // Internal State Management Functions
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

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error BlobNotFound();
    error ClaimRecordHashMismatch();
    error ClaimRecordNotProvided();
    error ExceedsUnfinalizedProposalCapacity();
    error InconsistentParams();
    error InsufficientBond();
    error InvalidBlobLocator();
    error InvalidState();
    error ProposalHashMismatch();
    error RingBufferSizeZero();
    error Unauthorized();
    error InvalidForcedInclusion();
}
