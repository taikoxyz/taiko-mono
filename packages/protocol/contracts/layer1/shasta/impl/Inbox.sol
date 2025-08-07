// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { IInboxStateManager } from "../iface/IInboxStateManager.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { ISyncedBlockManager } from "../../../shared/shasta/iface/ISyncedBlockManager.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibDecoder } from "../lib/LibDecoder.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture.
/// @custom:security-contact security@taiko.xyz

contract Inbox is IInbox {
    using LibDecoder for bytes;

    struct BondOperation {
        uint48 proposalId;
        address receiver;
        uint256 credit;
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

    /// @notice The bond manager contract
    IBondManager public immutable bondManager;

    /// @notice The state manager contract
    IInboxStateManager public immutable inboxStateManager;

    /// @notice The synced block manager contract
    ISyncedBlockManager public immutable syncedBlockManager;

    /// @notice The proof verifier contract
    IProofVerifier public immutable proofVerifier;

    /// @notice The proposer checker contract
    IProposerChecker public immutable proposerChecker;

    /// @notice The forced inclusion store contract
    IForcedInclusionStore public immutable forcedInclusionStore;

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
    /// @param _stateManager The address of the state manager contract
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
        address _stateManager,
        address _bondManager,
        address _syncedBlockManager,
        address _proofVerifier,
        address _proposerChecker,
        address _forcedInclusionStore
    ) {
        provabilityBond = _provabilityBond;
        livenessBond = _livenessBond;
        provingWindow = _provingWindow;
        extendedProvingWindow = _extendedProvingWindow;
        minBondBalance = _minBondBalance;
        maxFinalizationCount = _maxFinalizationCount;
        inboxStateManager = IInboxStateManager(_stateManager);
        bondManager = IBondManager(_bondManager);
        syncedBlockManager = ISyncedBlockManager(_syncedBlockManager);
        proofVerifier = IProofVerifier(_proofVerifier);
        proposerChecker = IProposerChecker(_proposerChecker);
        forcedInclusionStore = IForcedInclusionStore(_forcedInclusionStore);
    }

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IInbox
    function propose(bytes calldata, /*_lookahead*/ bytes calldata _data) external {
        proposerChecker.checkProposer(msg.sender);
        if (bondManager.getBondBalance(msg.sender) < minBondBalance) revert InsufficientBond();

        (
            CoreState memory coreState,
            BlobLocator memory blobLocator,
            Frame memory forcedInclusionFrame,
            ClaimRecord[] memory claimRecords
        ) = _data.decodeProposeData();

        if (keccak256(abi.encode(coreState)) != inboxStateManager.getCoreStateHash()) {
            revert InvalidState();
        }

        // Check if new proposals would exceed the unfinalized proposal capacity
        uint256 unfinalizedProposalCapacity = inboxStateManager.getCapacity();

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

        inboxStateManager.setCoreStateHash(keccak256(abi.encode(coreState)));

        emit Proposed(proposals, coreState);
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external {
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
        inboxStateManager.setProposalHash(proposalId, proposalHash);

        return (_coreState, proposal_);
    }

    /// @dev Proves a single proposal by validating the claim and storing the claim record.
    /// @param _proposal The proposal to prove.
    /// @param _claim The claim containing the proof details.
    function _prove(Proposal memory _proposal, Claim memory _claim) private {
        bytes32 proposalHash = keccak256(abi.encode(_proposal));
        if (proposalHash != _claim.proposalHash) revert ProposalHashMismatch();
        if (proposalHash != inboxStateManager.getProposalHash(_proposal.id)) {
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
        inboxStateManager.setClaimRecordHash(_proposal.id, _claim.parentClaimHash, claimRecordHash);
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
                inboxStateManager.getClaimRecordHash(proposalId, _coreState.lastFinalizedClaimHash);

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
        if (_blobLocator.blobs.length == 0) {
            // Full blobs mode
            return _validateFullBlobs(_blobLocator);
        } else {
            // Blob sharing mode
            return _validateBlobSharing(_blobLocator);
        }
    }

    /// @dev Validates full blobs mode - uses consecutive full blobs with no offsets/sizes.
    /// @param _blobLocator The blob locator to validate.
    /// @return The frame with blob hashes only.
    function _validateFullBlobs(BlobLocator memory _blobLocator)
        private
        view
        returns (Frame memory)
    {
        uint256 numBlobs = _blobLocator.numBlobs;
        if (numBlobs == 0) revert InvalidBlobLocator();

        bytes32[] memory blobHashes = new bytes32[](numBlobs);

        unchecked {
            for (uint256 i; i < _blobLocator.numBlobs; ++i) {
                uint48 blobIndex = _blobLocator.blobStartIndex + uint48(i);
                bytes32 hash = blobhash(blobIndex);
                if (hash == 0) revert BlobNotFound();
                blobHashes[i] = hash;
            }
        }

        // Return frame with empty offsets and sizes arrays for full blobs mode
        return Frame({ blobHashes: blobHashes, offsets: new uint32[](0), sizes: new uint32[](0) });
    }

    /// @dev Validates blob sharing mode - allows custom offset/size per blob.
    /// @param _blobLocator The blob locator to validate.
    /// @return The frame with blob hashes, offsets, and sizes.
    function _validateBlobSharing(BlobLocator memory _blobLocator)
        private
        view
        returns (Frame memory)
    {
        uint256 numBlobs = _blobLocator.blobs.length;

        bytes32[] memory blobHashes = new bytes32[](numBlobs);
        uint32[] memory offsets = new uint32[](numBlobs);
        uint32[] memory sizes = new uint32[](numBlobs);

        for (uint256 i; i < numBlobs; ++i) {
            BlobDescriptor memory descriptor = _blobLocator.blobs[i];

            // Validate blob exists
            bytes32 hash = blobhash(descriptor.blobIndex);
            if (hash == 0) revert BlobNotFound();

            blobHashes[i] = hash;
            offsets[i] = descriptor.offset;
            sizes[i] = descriptor.size;
        }

        return Frame({ blobHashes: blobHashes, offsets: offsets, sizes: sizes });
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
    /// @dev The frame is always assumed to be using the shared blob format(offsets and sizes are
    /// not empty)
    /// @param _consumed The consumed forced inclusion from storage
    /// @param _frame The frame provided by the proposer
    function _validateForcedInclusion(
        IForcedInclusionStore.ForcedInclusion memory _consumed,
        Frame memory _frame
    )
        private
        pure
    {
        // Forced inclusions are limited to 1 blob only
        require(_consumed.blobHash == _frame.blobHashes[0], InvalidForcedInclusion());
        require(_consumed.blobByteOffset == _frame.offsets[0], InvalidForcedInclusion());
        require(_consumed.blobByteSize == _frame.sizes[0], InvalidForcedInclusion());
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
    error Unauthorized();
    error InvalidForcedInclusion();
}
