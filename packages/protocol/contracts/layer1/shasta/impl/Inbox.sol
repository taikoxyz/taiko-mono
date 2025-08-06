// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { IInboxStateManager } from "../iface/IInboxStateManager.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { ISyncedBlockManager } from "../../../shared/shasta/iface/ISyncedBlockManager.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibDecoder } from "../lib/LibDecoder.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for Taiko's based rollup architecture
/// @dev This contract implements gas-efficient batch processing through claim record aggregation,
/// which allows multiple consecutive proposals with the same prover and bond decision to be
/// stored as a single record. This optimization significantly reduces gas costs for:
/// - Proof submission: Multiple proofs can be submitted and aggregated in one transaction
/// - Finalization: Aggregated claim records reduce storage operations during finalization
/// - Bond processing: Aggregated liveness bonds are processed together
///
/// Key features:
/// - Atomic propose and finalize operations
/// - Automatic claim record aggregation for gas savings
/// - Flexible bond management based on proof timing
/// - Support for batch proving of multiple proposals
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
        address _proposerChecker
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
    }

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IInbox
    /// @dev Atomically proposes a new L2 block and finalizes previously proven proposals.
    /// Gas optimization: Finalization processes aggregated claim records, reducing the
    /// number of storage operations needed compared to processing individual records
    function propose(bytes calldata, /*_lookahead*/ bytes calldata _data) external {
        proposerChecker.checkProposer(msg.sender);
        if (bondManager.getBondBalance(msg.sender) < minBondBalance) revert InsufficientBond();

        (
            CoreState memory coreState,
            BlobLocator memory blobLocator,
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

        Frame memory frame = _validateBlobLocator(blobLocator);
        (coreState, proposal) = _propose(coreState, frame);
        coreState = _finalize(coreState, claimRecords);
        emit Proposed(proposal, coreState);

        inboxStateManager.setCoreStateHash(keccak256(abi.encode(coreState)));
    }

    /// @inheritdoc IInbox
    /// @dev Proves multiple proposals in a single transaction with automatic aggregation.
    /// Gas optimization: The _aggregateClaimRecords function combines consecutive claim
    /// records that share the same prover and bond decision, significantly reducing
    /// storage costs when proving multiple proposals
    function prove(bytes calldata _data, bytes calldata _proof) external {
        (Proposal[] memory proposals, Claim[] memory claims) = _data.decodeProveData();

        if (proposals.length != claims.length) revert InconsistentParams();

        ClaimRecord[] memory claimRecords = new ClaimRecord[](proposals.length);

        for (uint256 i; i < proposals.length; ++i) {
            claimRecords[i] = _prove(proposals[i], claims[i]);
        }

        (uint48[] memory proposalIds, ClaimRecord[] memory aggregatedClaimRecords) =
            _aggregateClaimRecords(proposals, claimRecords);

        for (uint256 i; i < aggregatedClaimRecords.length; ++i) {
            bytes32 claimRecordHash = keccak256(abi.encode(aggregatedClaimRecords[i]));
            // Use the parentClaimHash from the aggregated claim record
            inboxStateManager.setClaimRecordHash(
                proposalIds[i], aggregatedClaimRecords[i].claim.parentClaimHash, claimRecordHash
            );
        }

        bytes32 claimsHash = keccak256(abi.encode(claims));
        proofVerifier.verifyProof(claimsHash, _proof);
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @dev Proposes a new L2 block and updates the inbox state
    /// @notice Creates a proposal with associated bonds and stores its hash on-chain.
    /// The proposal includes timing information used to determine bond decisions
    /// during the proving phase
    /// @param _coreState The current core state of the inbox
    /// @param _frame The frame containing blob references for the proposal data
    /// @return coreState_ The updated core state with incremented proposal ID
    /// @return proposal_ The created proposal with all metadata
    function _propose(
        CoreState memory _coreState,
        Frame memory _frame
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
            frame: _frame
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal_));
        inboxStateManager.setProposalHash(proposalId, proposalHash);

        return (_coreState, proposal_);
    }

    /// @dev Proves a single proposal by validating the claim and creating the claim record
    /// @notice This function validates the proposal hash and determines the bond decision
    /// based on proof timing. The resulting claim record may be aggregated with others
    /// for gas efficiency
    /// @param _proposal The proposal to prove
    /// @param _claim The claim containing the state transition details
    /// @return claimRecord_ The claim record that may be aggregated with others
    function _prove(
        Proposal memory _proposal,
        Claim memory _claim
    )
        private
        returns (ClaimRecord memory claimRecord_)
    {
        bytes32 proposalHash = keccak256(abi.encode(_proposal));
        if (proposalHash != _claim.proposalHash) revert ProposalHashMismatch();
        if (proposalHash != inboxStateManager.getProposalHash(_proposal.id)) {
            revert ProposalHashMismatch();
        }

        BondDecision bondDecision = _calculateBondDecision(_claim, _proposal);

        claimRecord_ = ClaimRecord({
            claim: _claim,
            proposer: _proposal.proposer,
            livenessBond: _proposal.livenessBond,
            provabilityBond: _proposal.provabilityBond,
            bondDecision: bondDecision,
            nextProposalId: _proposal.id + 1
        });

        emit Proved(_proposal, claimRecord_);
    }

    /// @dev Finalizes proposals by verifying claim records and updating state
    /// @notice Processes aggregated claim records to finalize multiple proposals efficiently.
    /// Each aggregated record may represent multiple consecutive proposals, reducing
    /// the number of storage reads and bond operations required
    /// @param _coreState The current core state
    /// @param _claimRecords The claim records to finalize (may be aggregated)
    /// @return coreState_ The updated core state with finalized proposals
    function _finalize(
        CoreState memory _coreState,
        ClaimRecord[] memory _claimRecords
    )
        private
        returns (CoreState memory coreState_)
    {
        // The last finalized claim record.
        ClaimRecord memory claimRecord;

        uint48 proposalId = _coreState.lastFinalizedProposalId + 1;

        for (uint256 i; i < maxFinalizationCount; ++i) {
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
            proposalId = claimRecord.nextProposalId;
        }

        if (proposalId != _coreState.lastFinalizedProposalId) {
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
        uint48 credit;
        address receiver;

        Claim memory claim = _claimRecord.claim;

        if (_claimRecord.bondDecision == BondDecision.NoOp) {
            // No bond operations needed
        } else if (_claimRecord.bondDecision == BondDecision.L2RefundLiveness) {
            // Proposer and designated prover are different entities
            // The designated prover paid a liveness bond on L2 that needs to be refunded
            credit = _claimRecord.livenessBond;
            receiver = claim.designatedProver;
        } else if (_claimRecord.bondDecision == BondDecision.L1SlashLivenessRewardProver) {
            // Proposer was also the designated prover who failed to prove on time
            // Forfeit their liveness bond but reward the actual prover with half
            uint256 livenessBondWei = uint256(_claimRecord.livenessBond) * 1 gwei;
            bondManager.debitBond(_claimRecord.proposer, livenessBondWei);
            bondManager.creditBond(claim.actualProver, livenessBondWei / 2);
        } else if (_claimRecord.bondDecision == BondDecision.L2RewardProver) {
            // Reward the actual prover with half of the liveness bond on L2
            credit = _claimRecord.livenessBond / 2;
            receiver = claim.actualProver;
        } else if (
            _claimRecord.bondDecision == BondDecision.L1SlashProvabilityRewardProverL2RefundLiveness
        ) {
            // Proof submitted after extended window (very late proof)
            // Block was difficult to prove, forfeit provability bond but reward prover
            uint256 provabilityBondWei = uint256(_claimRecord.provabilityBond) * 1 gwei;
            bondManager.debitBond(_claimRecord.proposer, provabilityBondWei);
            bondManager.creditBond(claim.actualProver, provabilityBondWei / 2);
            // Proposer and designated prover are different entities
            // Refund the designated prover's L2 liveness bond
            credit = _claimRecord.livenessBond;
            receiver = claim.designatedProver;
        } else if (_claimRecord.bondDecision == BondDecision.L1SlashProvabilityRewardProver) {
            // Proof submitted after extended window, proposer and designated prover are same
            // Forfeit provability bond but reward the actual prover
            uint256 provabilityBondWei = uint256(_claimRecord.provabilityBond) * 1 gwei;
            bondManager.debitBond(_claimRecord.proposer, provabilityBondWei);
            bondManager.creditBond(claim.actualProver, provabilityBondWei / 2);
        }

        BondOperation memory bondOperation =
            BondOperation({ proposalId: _proposalId, receiver: receiver, credit: credit });

        return keccak256(abi.encode(_bondOperationsHash, bondOperation));
    }

    // -------------------------------------------------------------------------
    // Private View Functions
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // Private Pure Functions
    // -------------------------------------------------------------------------

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
                        writeRecord.livenessBond += readRecord.livenessBond;
                    } else {
                        // assert(writeRecord.bondDecision == BondDecision.NoOp);
                        writeRecord.livenessBond = 0;
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

        if (uint256(_recordA.livenessBond) + _recordB.livenessBond > type(uint48).max) return false;

        if (
            _recordA.bondDecision == BondDecision.L2RefundLiveness
                && _recordA.claim.designatedProver == _recordB.claim.designatedProver
        ) return true;

        if (
            _recordA.bondDecision == BondDecision.L2RewardProver
                && _recordA.claim.actualProver == _recordB.claim.actualProver
        ) return true;

        return false;
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
}
