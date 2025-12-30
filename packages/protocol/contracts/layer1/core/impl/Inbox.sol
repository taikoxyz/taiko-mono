// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ICodec } from "../iface/ICodec.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { IProverAuction } from "../iface/IProverAuction.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibCodec } from "../libs/LibCodec.sol";
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { LibHashOptimized } from "../libs/LibHashOptimized.sol";
import { LibInboxSetup } from "../libs/LibInboxSetup.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

/// @title Inbox
/// @notice Core contract for managing L2 proposals, proof verification, and forced inclusion in
/// Taiko's based rollup architecture.
/// @dev The Pacaya inbox contract is not being upgraded to the Shasta implementation;
///      instead, Shasta uses a separate inbox address.
/// @dev This contract implements the fundamental inbox logic including:
///      - Proposal submission with forced inclusion support
///      - Sequential proof verification
///      - Ring buffer storage for efficient state management
///      - Finalization of proven proposals with checkpoint rate limiting
/// @custom:security-contact security@taiko.xyz
contract Inbox is IInbox, ICodec, IForcedInclusionStore, EssentialContract {
    using LibAddress for address;
    using LibMath for uint48;
    using LibMath for uint256;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Result from consuming forced inclusions
    struct ConsumptionResult {
        DerivationSource[] sources;
        bool allowsPermissionless;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event InboxActivated(bytes32 lastPacayaBlockHash);

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The proof verifier contract.
    IProofVerifier internal immutable _proofVerifier;

    /// @notice The proposer checker contract.
    IProposerChecker internal immutable _proposerChecker;

    /// @notice The prover auction contract.
    IProverAuction internal immutable _proverAuction;

    /// @notice Signal service responsible for checkpoints.
    ISignalService internal immutable _signalService;

    /// @notice The proving window in seconds.
    uint48 internal immutable _provingWindow;

    /// @notice Maximum delay allowed between sequential proofs to remain on time.
    uint48 internal immutable _maxProofSubmissionDelay;

    /// @notice The ring buffer size for storing proposal hashes.
    uint256 internal immutable _ringBufferSize;

    /// @notice The percentage of basefee paid to coinbase.
    uint8 internal immutable _basefeeSharingPctg;

    /// @notice The minimum number of forced inclusions that the proposer is forced to process if
    /// they are due.
    uint256 internal immutable _minForcedInclusionCount;

    /// @notice The delay for forced inclusions measured in seconds.
    uint16 internal immutable _forcedInclusionDelay;

    /// @notice The base fee for forced inclusions in Gwei.
    uint64 internal immutable _forcedInclusionFeeInGwei;

    /// @notice Queue size at which the fee doubles. See Config for formula details.
    uint64 internal immutable _forcedInclusionFeeDoubleThreshold;

    /// @notice The minimum delay between checkpoints in seconds.
    uint16 internal immutable _minCheckpointDelay;

    /// @notice The multiplier to determine when a forced inclusion is too old so that proposing
    /// becomes permissionless
    uint8 internal immutable _permissionlessInclusionMultiplier;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The timestamp when the first activation occurred.
    uint48 public activationTimestamp;

    /// @notice Persisted core state.
    CoreState internal _coreState;

    /// @dev Ring buffer for storing proposal hashes indexed by buffer slot
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - proposalHash: The keccak256 hash of the Proposal struct
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev Storage for forced inclusion requests
    /// @dev 2 slots used
    LibForcedInclusion.Storage private _forcedInclusionStorage;

    uint256[44] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    /// @param _config Configuration struct containing all constructor parameters
    constructor(Config memory _config) {
        LibInboxSetup.validateConfig(_config);

        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _proposerChecker = IProposerChecker(_config.proposerChecker);
        _proverAuction = IProverAuction(_config.proverAuction);
        _signalService = ISignalService(_config.signalService);
        _provingWindow = _config.provingWindow;
        _maxProofSubmissionDelay = _config.maxProofSubmissionDelay;
        _ringBufferSize = _config.ringBufferSize;
        _basefeeSharingPctg = _config.basefeeSharingPctg;
        _minForcedInclusionCount = _config.minForcedInclusionCount;
        _forcedInclusionDelay = _config.forcedInclusionDelay;
        _forcedInclusionFeeInGwei = _config.forcedInclusionFeeInGwei;
        _forcedInclusionFeeDoubleThreshold = _config.forcedInclusionFeeDoubleThreshold;
        _minCheckpointDelay = _config.minCheckpointDelay;
        _permissionlessInclusionMultiplier = _config.permissionlessInclusionMultiplier;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the owner of the inbox.
    /// @param _owner The owner of this contract
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Activates the inbox so that it can start accepting proposals.
    /// @dev Can be called multiple times within the activation window to handle reorgs. When
    /// reactivated, proposal history is cleared while the forced inclusion queue is preserved.
    /// @param _lastPacayaBlockHash The block hash of the last Pacaya block
    function activate(bytes32 _lastPacayaBlockHash) external onlyOwner {
        bool wasActivated = activationTimestamp != 0;
        (
            uint48 newActivationTimestamp,
            CoreState memory state,
            Proposal memory proposal,
            bytes32 genesisProposalHash
        ) = LibInboxSetup.activate(_lastPacayaBlockHash, activationTimestamp);

        activationTimestamp = newActivationTimestamp;
        _coreState = state;
        if (wasActivated) _clearProposalHashes();
        _setProposalHash(0, genesisProposalHash);
        emit Proposed(proposal.id, LibCodec.encodeProposal(proposal));
        emit InboxActivated(_lastPacayaBlockHash);
    }

    /// @inheritdoc IInbox
    /// @notice Proposes new L2 blocks and forced inclusions to the rollup using blobs for DA.
    /// @dev Key behaviors:
    ///      1. Validates proposer authorization via `IProposerChecker`
    ///      2. Process `input.numForcedInclusions` forced inclusions. The proposer is forced to
    ///         process at least `config.minForcedInclusionCount` if they are due.
    ///      3. Updates core state and emits `Proposed` event
    /// NOTE: This function can only be called once per block to prevent spams that can fill the
    /// ring buffer.
    function propose(
        bytes calldata _lookahead,
        bytes calldata _data
    )
        external
        payable
        nonReentrant
    {
        unchecked {
            ProposeInput memory input = LibCodec.decodeProposeInput(_data);
            _validateProposeInput(input);

            uint48 nextProposalId = _coreState.nextProposalId;
            uint48 lastProposalBlockId = _coreState.lastProposalBlockId;
            uint48 lastFinalizedProposalId = _coreState.lastFinalizedProposalId;
            require(nextProposalId > 0, ActivationRequired());

            (address designatedProver, uint32 feeInGwei) =
                _resolveDesignatedProver(input.isSelfProving);

            uint256 feeRefund = _collectProverFee(designatedProver, feeInGwei);

            (Proposal memory proposal, uint256 forcedFees) = _buildProposal(
                input,
                _lookahead,
                nextProposalId,
                lastProposalBlockId,
                lastFinalizedProposalId,
                designatedProver,
                feeInGwei
            );

            // Single payout to proposer for fee refund + forced inclusion fees.
            uint256 payout = feeRefund + forcedFees;
            if (payout > 0) {
                msg.sender.sendEtherAndVerify(payout);
            }

            _coreState.nextProposalId = nextProposalId + 1;
            _coreState.lastProposalBlockId = uint48(block.number);
            _setProposalHash(proposal.id, LibHashOptimized.hashProposal(proposal));

            emit Proposed(proposal.id, LibCodec.encodeProposal(proposal));
        }
    }

    /// @inheritdoc IInbox
    ///
    /// @dev The proof covers a contiguous range of proposals. The input contains an array of
    /// Transition structs, each with the proposal's metadata and checkpoint hash. The proof range
    /// can start at or before the last finalized proposal to handle race conditions where
    /// proposals get finalized between proof generation and submission.
    ///
    /// Example: Proving proposals 3-7 when lastFinalizedProposalId=4
    ///
    ///       lastFinalizedProposalId                nextProposalId
    ///                             ┆                             ┆
    ///                             ▼                             ▼
    ///     0     1     2     3     4     5     6     7     8     9
    ///     ■─────■─────■─────■─────■─────□─────□─────□─────□─────
    ///                       ▲           ▲                 ▲
    ///                       ┆<-offset-> ┆                 ┆
    ///                       ┆                             ┆
    ///                       ┆<-    input.transitions[]   ->┆
    ///         firstProposalId                             lastProposalId
    ///
    /// Key validation rules:
    /// 1. firstProposalId <= lastFinalizedProposalId + 1 (can overlap with finalized range)
    /// 2. lastProposalId < nextProposalId (cannot prove unproposed blocks)
    /// 3. lastProposalId >= lastFinalizedProposalId + 1 (must advance at least one proposal)
    /// 4. The block hash must link to the lastFinalizedBlockHash
    ///
    /// @param _data Encoded ProveInput struct
    /// @param _proof Validity proof for the batch of proposals
    function prove(bytes calldata _data, bytes calldata _proof) external {
        unchecked {
            CoreState memory state = _coreState;
            ProveInput memory input = LibCodec.decodeProveInput(_data);

            // -------------------------------------------------------------------------------
            // 1. Validate batch bounds and calculate offset of the first unfinalized proposal
            // -------------------------------------------------------------------------------
            Commitment memory commitment = input.commitment;

            // `offset` is the index of the next-to-finalize proposal in the transitions array.
            (uint256 numProposals, uint256 lastProposalId, uint48 offset) =
                _validateCommitment(state, commitment);

            // ---------------------------------------------------------
            // 2. Verify checkpoint hash continuity and last proposal hash
            // ---------------------------------------------------------
            // The parent block hash must match the stored lastFinalizedBlockHash.
            bytes32 expectedParentHash = offset == 0
                ? commitment.firstProposalParentBlockHash
                : commitment.transitions[offset - 1].blockHash;
            require(state.lastFinalizedBlockHash == expectedParentHash, ParentBlockHashMismatch());

            require(
                commitment.lastProposalHash == getProposalHash(lastProposalId),
                LastProposalHashMismatch()
            );

            // ---------------------------------------------------------
            // 3. Slash late proofs (auction-based)
            // ---------------------------------------------------------
            _maybeSlashLateProof(commitment, offset, state.lastFinalizedTimestamp);

            // -----------------------------------------------------------------------------
            // 4. Sync checkpoint
            // -----------------------------------------------------------------------------
            bool checkpointSynced = input.forceCheckpointSync
                || block.timestamp >= state.lastCheckpointTimestamp + _minCheckpointDelay;

            if (checkpointSynced) {
                _signalService.saveCheckpoint(
                    ICheckpointStore.Checkpoint({
                        blockNumber: commitment.endBlockNumber,
                        stateRoot: commitment.endStateRoot,
                        blockHash: commitment.transitions[numProposals - 1].blockHash
                    })
                );
                state.lastCheckpointTimestamp = uint48(block.timestamp);
            }

            // ---------------------------------------------------------
            // 5. Compute proposalAge (for single-proposal proofs only)
            // ---------------------------------------------------------
            uint256 proposalAge;
            if (numProposals == 1) {
                // We count proposalAge as the time since it became available for proving.
                proposalAge = block.timestamp
                    - commitment.transitions[offset].timestamp.max(state.lastFinalizedTimestamp);
            }

            // ---------------------------------------------------------
            // 6. Update core state and emit event
            // ---------------------------------------------------------
            state.lastFinalizedProposalId = uint48(lastProposalId);
            state.lastFinalizedTimestamp = uint48(block.timestamp);
            state.lastFinalizedBlockHash = commitment.transitions[numProposals - 1].blockHash;

            _coreState = state;

            emit Proved(
                uint48(lastProposalId),
                commitment.firstProposalId,
                commitment.firstProposalId + offset,
                commitment.actualProver,
                checkpointSynced
            );

            // ---------------------------------------------------------
            // 7. Verify the proof
            // ---------------------------------------------------------
            _proofVerifier.verifyProof(
                proposalAge, LibHashOptimized.hashCommitment(commitment), _proof
            );
        }
    }

    /// @inheritdoc IForcedInclusionStore
    /// @dev This function will revert if called before the first non-activation proposal is
    /// submitted to make sure blocks have been produced already and the derivation can use the
    /// parent's block timestamp.
    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable {
        bytes32 proposalHash = _proposalHashes[1];
        require(proposalHash != bytes32(0), IncorrectProposalCount());

        uint256 refund = LibForcedInclusion.saveForcedInclusion(
            _forcedInclusionStorage,
            _forcedInclusionFeeInGwei,
            _forcedInclusionFeeDoubleThreshold,
            _blobReference
        );

        // Refund excess payment to the sender
        if (refund > 0) {
            msg.sender.sendEtherAndVerify(refund);
        }
    }

    /// @inheritdoc ICodec
    function encodeProposeInput(IInbox.ProposeInput calldata _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibCodec.encodeProposeInput(_input);
    }

    /// @inheritdoc ICodec
    function decodeProposeInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        return LibCodec.decodeProposeInput(_data);
    }

    /// @inheritdoc ICodec
    function encodeProposal(IInbox.Proposal calldata _proposal)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibCodec.encodeProposal(_proposal);
    }

    /// @inheritdoc ICodec
    function decodeProposal(
        uint48 _proposalId,
        bytes calldata _data
    )
        external
        pure
        returns (IInbox.Proposal memory proposal_)
    {
        return LibCodec.decodeProposal(_proposalId, _data);
    }

    /// @inheritdoc ICodec
    function encodeProveInput(IInbox.ProveInput calldata _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibCodec.encodeProveInput(_input);
    }

    /// @inheritdoc ICodec
    function decodeProveInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProveInput memory input_)
    {
        return LibCodec.decodeProveInput(_data);
    }

    /// @inheritdoc ICodec
    function hashProposal(IInbox.Proposal calldata _proposal) external pure returns (bytes32) {
        return LibHashOptimized.hashProposal(_proposal);
    }

    /// @inheritdoc ICodec
    function hashCommitment(IInbox.Commitment calldata _commitment)
        external
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashCommitment(_commitment);
    }

    // ---------------------------------------------------------------
    // External and Public View Functions
    // ---------------------------------------------------------------
    /// @inheritdoc IForcedInclusionStore
    function getCurrentForcedInclusionFee() external view returns (uint64 feeInGwei_) {
        return LibForcedInclusion.getCurrentForcedInclusionFee(
            _forcedInclusionStorage, _forcedInclusionFeeInGwei, _forcedInclusionFeeDoubleThreshold
        );
    }

    /// @inheritdoc IForcedInclusionStore
    function getForcedInclusions(
        uint48 _start,
        uint48 _maxCount
    )
        external
        view
        returns (IForcedInclusionStore.ForcedInclusion[] memory inclusions_)
    {
        return LibForcedInclusion.getForcedInclusions(_forcedInclusionStorage, _start, _maxCount);
    }

    /// @inheritdoc IForcedInclusionStore
    function getForcedInclusionState() external view returns (uint48 head_, uint48 tail_) {
        return LibForcedInclusion.getForcedInclusionState(_forcedInclusionStorage);
    }

    /// @inheritdoc IInbox
    function getConfig() external view returns (Config memory config_) {
        config_ = Config({
            proofVerifier: address(_proofVerifier),
            proposerChecker: address(_proposerChecker),
            proverAuction: address(_proverAuction),
            signalService: address(_signalService),
            provingWindow: _provingWindow,
            maxProofSubmissionDelay: _maxProofSubmissionDelay,
            ringBufferSize: _ringBufferSize,
            basefeeSharingPctg: _basefeeSharingPctg,
            minForcedInclusionCount: _minForcedInclusionCount,
            forcedInclusionDelay: _forcedInclusionDelay,
            forcedInclusionFeeInGwei: _forcedInclusionFeeInGwei,
            forcedInclusionFeeDoubleThreshold: _forcedInclusionFeeDoubleThreshold,
            minCheckpointDelay: _minCheckpointDelay,
            permissionlessInclusionMultiplier: _permissionlessInclusionMultiplier
        });
    }

    /// @inheritdoc IInbox
    function getCoreState() external view returns (CoreState memory) {
        return _coreState;
    }

    /// @inheritdoc IInbox
    /// @dev Note that due to the ring buffer nature of the `_proposalHashes` mapping proposals
    /// may have been overwritten by a new one. You should verify that the hash matches the
    /// expected proposal.
    function getProposalHash(uint256 _proposalId) public view returns (bytes32) {
        return _proposalHashes[_proposalId % _ringBufferSize];
    }

    // ---------------------------------------------------------------
    // Private State-Changing Functions
    // ---------------------------------------------------------------

    /// @dev Builds proposal and derivation data. It also checks if `msg.sender` can propose.
    /// @param _input The propose input data.
    /// @param _lookahead Encoded data forwarded to the proposer checker (i.e. lookahead payloads).
    /// @param _nextProposalId The proposal ID to assign.
    /// @param _lastProposalBlockId The last block number where a proposal was made.
    /// @param _lastFinalizedProposalId The ID of the last finalized proposal.
    /// @return proposal_ The proposal with final endOfSubmissionWindowTimestamp set.
    /// @return forcedFees_ Total forced inclusion fees in wei to pay the proposer.
    function _buildProposal(
        ProposeInput memory _input,
        bytes calldata _lookahead,
        uint48 _nextProposalId,
        uint48 _lastProposalBlockId,
        uint48 _lastFinalizedProposalId,
        address _designatedProver,
        uint32 _feeInGwei
    )
        private
        returns (Proposal memory proposal_, uint256 forcedFees_)
    {
        unchecked {
            // Enforce one propose call per Ethereum block to prevent spam attacks that could
            // deplete the ring buffer
            require(block.number > _lastProposalBlockId, CannotProposeInCurrentBlock());
            require(
                _getAvailableCapacity(_nextProposalId, _lastFinalizedProposalId) > 0,
                NotEnoughCapacity()
            );

            ConsumptionResult memory result;
            (result, forcedFees_) =
                _consumeForcedInclusions(_input.numForcedInclusions);

            result.sources[result.sources.length - 1] =
                DerivationSource(false, LibBlobs.validateBlobReference(_input.blobReference));

            // If forced inclusion is old enough, allow anyone to propose
            // and set endOfSubmissionWindowTimestamp = 0
            // Otherwise, only the current preconfer can propose
            uint48 endOfSubmissionWindowTimestamp = result.allowsPermissionless
                ? 0
                : _proposerChecker.checkProposer(msg.sender, _lookahead);

            // Use previous block as the origin for the proposal to be able to call `blockhash`
            uint256 parentBlockNumber = block.number - 1;
            proposal_ = Proposal({
                id: _nextProposalId,
                timestamp: uint48(block.timestamp),
                endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
                proposer: msg.sender,
                designatedProver: _designatedProver,
                feeInGwei: _feeInGwei,
                parentProposalHash: getProposalHash(_nextProposalId - 1),
                originBlockNumber: uint48(parentBlockNumber),
                originBlockHash: blockhash(parentBlockNumber),
                basefeeSharingPctg: _basefeeSharingPctg,
                sources: result.sources
            });
        }
    }

    /// @dev Resolves and validates the designated prover for the proposal.
    /// @param _isSelfProving True if the proposer intends to self-prove.
    /// @return designatedProver_ The designated prover address.
    function _resolveDesignatedProver(bool _isSelfProving)
        private
        returns (address designatedProver_, uint32 feeInGwei_)
    {
        if (_isSelfProving) {
            bool ok = _proverAuction.checkBondDeferWithdrawal(msg.sender);
            require(ok, InsufficientBondForSelfProving());
            return (msg.sender, 0);
        }

        (address currentProver, uint32 feeInGwei) = _proverAuction.getCurrentProver();
        require(currentProver != address(0), NoActiveAuctionProver());
        return (currentProver, feeInGwei);
    }

    /// @dev Collects the prover fee in ETH (Gwei units) and returns refund in wei.
    /// @dev Fee payment is best-effort: proposal should not revert if the prover rejects ETH.
    /// The refund is paid once by the caller, alongside forced inclusion fees.
    /// @param _designatedProver The designated prover for this proposal.
    /// @param _feeInGwei The prover fee in Gwei.
    function _collectProverFee(address _designatedProver, uint32 _feeInGwei)
        private
        returns (uint256 refund_)
    {
        unchecked {
            // Safe math: feeWei is bounded by uint32 * 1 gwei, and msg.value >= feeWei
            // is enforced before subtracting.
            refund_ = msg.value;

            if (_feeInGwei > 0 && msg.sender != _designatedProver) {
                uint256 feeWei = uint256(_feeInGwei) * 1 gwei;
                require(msg.value >= feeWei, ProverFeeNotPaid());

                (bool paid,) = payable(_designatedProver).call{ value: feeWei }("");
                // If prover refuses payment, refund full msg.value to proposer.
                if (paid) {
                    refund_ = msg.value - feeWei;
                }
            }
        }
    }

    /// @dev Applies late-proof slashing using the prover auction.
    /// @param _commitment The commitment data.
    /// @param _offset The offset to the first unfinalized proposal.
    /// @param _lastFinalizedTimestamp The last finalized proposal timestamp.
    function _maybeSlashLateProof(
        Commitment memory _commitment,
        uint48 _offset,
        uint48 _lastFinalizedTimestamp
    )
        private
    {
        unchecked {
            uint256 livenessWindowDeadline = (uint256(_commitment.transitions[_offset].timestamp)
                + _provingWindow).max(uint256(_lastFinalizedTimestamp) + _maxProofSubmissionDelay);
            bool isOnTime = block.timestamp <= livenessWindowDeadline;

            if (isOnTime) {
                return;
            }

            address designatedProver = _commitment.transitions[_offset].designatedProver;
            address actualProver = _commitment.actualProver;

            // Slash designated prover even if they submit late themselves;
            // they receive the reward but still incur net penalty.
            _proverAuction.slashProver(designatedProver, actualProver);
        }
    }


    /// @dev Stores a proposal hash in the ring buffer
    /// Overwrites any existing hash at the calculated buffer slot
    function _setProposalHash(uint48 _proposalId, bytes32 _proposalHash) private {
        _proposalHashes[_proposalId % _ringBufferSize] = _proposalHash;
    }

    /// @dev Clears the proposal hash ring buffer.
    function _clearProposalHashes() private {
        unchecked {
            for (uint256 i; i < _ringBufferSize; ++i) {
                _proposalHashes[i] = bytes32(0);
            }
        }
    }

    /// @dev Consumes forced inclusions from the queue and returns result with extra slot for normal
    /// source
    /// @param _numForcedInclusionsRequested Maximum number of forced inclusions to consume
    /// @return result_ ConsumptionResult with sources array (size: processed + 1, last slot empty)
    /// and whether permissionless proposals are allowed
    /// @return totalFees_ Total forced inclusion fees in wei
    function _consumeForcedInclusions(uint256 _numForcedInclusionsRequested)
        private
        returns (ConsumptionResult memory result_, uint256 totalFees_)
    {
        unchecked {
            LibForcedInclusion.Storage storage $ = _forcedInclusionStorage;

            // Load storage once
            (uint48 head, uint48 tail) = ($.head, $.tail);

            uint256 available = tail - head;
            uint256 toProcess = _numForcedInclusionsRequested > available
                ? available
                : _numForcedInclusionsRequested;

            result_.sources = new DerivationSource[](toProcess + 1);

            uint48 oldestTimestamp;
            (oldestTimestamp, head, totalFees_) =
                _dequeueAndProcessForcedInclusions($, result_.sources, head, toProcess);

            // We check the following conditions are met:
            // 1. Proposer is willing to include at least the minimum required
            // (_minForcedInclusionCount) OR
            // 2. Proposer included all available inclusions that are due
            if (_numForcedInclusionsRequested < _minForcedInclusionCount && available > toProcess) {
                bool isOldestInclusionDue = LibForcedInclusion.isOldestForcedInclusionDue(
                    $, head, tail, _forcedInclusionDelay
                );
                require(!isOldestInclusionDue, UnprocessedForcedInclusionIsDue());
            }

            uint256 permissionlessTimestamp = uint256(_forcedInclusionDelay)
                * _permissionlessInclusionMultiplier + oldestTimestamp;
            result_.allowsPermissionless = block.timestamp > permissionlessTimestamp;
        }
    }

    /// @dev Dequeues and processes forced inclusions from the queue without checking if they exist
    /// @param $ Storage reference
    /// @param _sources Array to populate with derivation sources
    /// @param _head Current queue head position
    /// @param _toProcess Number of inclusions to process
    /// @return oldestTimestamp_ Oldest timestamp from processed inclusions.
    /// `type(uint48).max` if no inclusions were processed
    /// @return head_ Updated head position
    /// @return totalFees_ Total forced inclusion fees in wei
    function _dequeueAndProcessForcedInclusions(
        LibForcedInclusion.Storage storage $,
        DerivationSource[] memory _sources,
        uint48 _head,
        uint256 _toProcess
    )
        private
        returns (uint48 oldestTimestamp_, uint48 head_, uint256 totalFees_)
    {
        unchecked {
            if (_toProcess == 0) {
                return (type(uint48).max, _head, 0);
            }

            // Process inclusions and accumulate fees in gwei
            for (uint256 i; i < _toProcess; ++i) {
                IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[_head + i];
                _sources[i] = IInbox.DerivationSource(true, inclusion.blobSlice);
                totalFees_ += inclusion.feeInGwei;
            }

            totalFees_ *= 1 gwei;

            // Oldest timestamp is the timestamp of the first inclusion
            oldestTimestamp_ = uint48(_sources[0].blobSlice.timestamp);

            // Update queue position
            head_ = _head + uint48(_toProcess);

            // Write to storage once
            $.head = head_;
        }
    }


    // ---------------------------------------------------------------
    // Private View/Pure Functions
    // ---------------------------------------------------------------

    /// @dev Calculates remaining capacity for new proposals
    /// Subtracts unfinalized proposals from total capacity
    /// @param _nextProposalId The next proposal ID
    /// @param _lastFinalizedProposalId The ID of the last finalized proposal
    /// @return _ Number of additional proposals that can be submitted
    function _getAvailableCapacity(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId
    )
        private
        view
        returns (uint256)
    {
        unchecked {
            if (_nextProposalId <= _lastFinalizedProposalId) revert InvalidCoreState();

            uint256 numUnfinalizedProposals = _nextProposalId - _lastFinalizedProposalId - 1;
            if (numUnfinalizedProposals >= _ringBufferSize) revert InvalidCoreState();

            return _ringBufferSize - 1 - numUnfinalizedProposals;
        }
    }

    /// @dev Validates propose function inputs.
    /// @param _input The ProposeInput to validate
    function _validateProposeInput(ProposeInput memory _input) private view {
        require(_input.deadline == 0 || block.timestamp <= _input.deadline, DeadlineExceeded());
    }

    /// @dev Validates the batch bounds in the Commitment and calculates the offset
    ///      to the first unfinalized proposal.
    /// @param _state The core state.
    /// @param _commitment The commitment data.
    /// @return numProposals_ The number of proposals in the batch.
    /// @return lastProposalId_ The ID of the last proposal in the batch.
    /// @return offset_ The offset to the first unfinalized proposal.
    function _validateCommitment(
        CoreState memory _state,
        Commitment memory _commitment
    )
        private
        pure
        returns (uint256 numProposals_, uint256 lastProposalId_, uint48 offset_)
    {
        unchecked {
            uint256 firstUnfinalizedId = _state.lastFinalizedProposalId + 1;

            numProposals_ = _commitment.transitions.length;
            require(numProposals_ > 0, EmptyBatch());
            require(_commitment.firstProposalId <= firstUnfinalizedId, FirstProposalIdTooLarge());

            lastProposalId_ = _commitment.firstProposalId + numProposals_ - 1;
            require(lastProposalId_ < _state.nextProposalId, LastProposalIdTooLarge());
            require(lastProposalId_ >= firstUnfinalizedId, LastProposalAlreadyFinalized());

            // Calculate offset to first unfinalized proposal.
            // Some proposals in _commitment.transitions[] may already be finalized.
            // The offset points to the first proposal that will be finalized.
            offset_ = uint48(firstUnfinalizedId - _commitment.firstProposalId);
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------
    error ActivationRequired();
    error CannotProposeInCurrentBlock();
    error CheckpointDelayHasPassed();
    error DeadlineExceeded();
    error EmptyBatch();
    error FirstProposalIdTooLarge();
    error IncorrectProposalCount();
    error InsufficientBondForSelfProving();
    error InvalidCoreState();
    error LastProposalAlreadyFinalized();
    error LastProposalHashMismatch();
    error LastProposalIdTooLarge();
    error NoActiveAuctionProver();
    error NotEnoughCapacity();
    error ParentBlockHashMismatch();
    error ProverFeeNotPaid();
    error UnprocessedForcedInclusionIsDue();
}
