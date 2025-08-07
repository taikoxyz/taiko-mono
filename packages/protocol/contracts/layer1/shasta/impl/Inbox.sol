// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBlobs } from "../lib/LibBlobs.sol";
import { IInboxStateManager } from "../iface/IInboxStateManager.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { ISyncedBlockManager } from "../../../shared/shasta/iface/ISyncedBlockManager.sol";
import { LibBondOperation } from "../../../shared/shasta/libs/LibBondOperation.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibDecoder } from "../lib/LibDecoder.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture.
/// @custom:security-contact security@taiko.xyz

contract Inbox is IInbox {
    using LibDecoder for bytes;

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    uint48 public immutable provabilityBondGwei;
    uint48 public immutable livenessBondGwei;
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
    /// @param _provabilityBondGwei The bond required for block provability
    /// @param _livenessBondGwei The bond required for prover liveness
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
        uint48 _provabilityBondGwei,
        uint48 _livenessBondGwei,
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
        provabilityBondGwei = _provabilityBondGwei;
        livenessBondGwei = _livenessBondGwei;
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
            LibBlobs.BlobLocator memory blobLocator,
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

        inboxStateManager.setCoreStateHash(keccak256(abi.encode(coreState)));
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
            livenessBondGwei: _proposal.livenessBondGwei,
            provabilityBondGwei: _proposal.provabilityBondGwei,
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
        Claim memory claim = _claimRecord.claim;
        uint256 livenessBondWei = uint256(_claimRecord.livenessBondGwei) * 1 gwei;
        uint256 provabilityBondWei = uint256(_claimRecord.provabilityBondGwei) * 1 gwei;

        LibBondOperation.BondOperation memory bondOperation;
        bondOperation.proposalId = _proposalId;

        if (_claimRecord.proofTiming == ProofTiming.InProvingWindow) {
            // Proof submitted within the designated proving window (on-time proof)
            // The designated prover successfully proved the block on time

            if (claim.designatedProver != _claimRecord.proposer) {
                // Proposer and designated prover are different entities
                // The designated prover paid a liveness bond on L2 that needs to be refunded
                bondOperation.receiver = claim.designatedProver;
                bondOperation.credit = livenessBondWei;
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
                bondOperation.receiver = claim.actualProver;
                bondOperation.credit = livenessBondWei / 2;
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
                bondOperation.receiver = claim.designatedProver;
                bondOperation.credit = livenessBondWei;
            }
        }
        return LibBondOperation.aggregateBondOperation(_bondOperationsHash, bondOperation);
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

    error ClaimRecordHashMismatch();
    error ClaimRecordNotProvided();
    error ExceedsUnfinalizedProposalCapacity();
    error InconsistentParams();
    error InsufficientBond();
    error InvalidState();
    error ProposalHashMismatch();
    error Unauthorized();
}
