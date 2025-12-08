// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { LibHashOptimized } from "../libs/LibHashOptimized.sol";
import { LibProposeInputCodec } from "../libs/LibProposeInputCodec.sol";
import { LibProposedEventCodec } from "../libs/LibProposedEventCodec.sol";
import { LibProveInputCodec } from "../libs/LibProveInputCodec.sol";
import { LibProvedEventCodec } from "../libs/LibProvedEventCodec.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

import "./Inbox_Layout.sol"; // DO NOT DELETE

/// @title Inbox
/// @notice Core contract for managing L2 proposals, proof verification, and forced inclusion in
/// Taiko's based rollup architecture.
/// @dev The Pacaya inbox contract is not being upgraded to the Shasta implementation;
///      instead, Shasta uses a separate inbox address.
/// @dev This contract implements the fundamental inbox logic including:
///      - Proposal submission with forced inclusion support
///      - Sequential proof verification
///      - Ring buffer storage for efficient state management
///      - Bond instruction calculation(but actual funds are managed on L2)
///      - Finalization of proven proposals with checkpoint rate limiting
/// @custom:security-contact security@taiko.xyz
contract Inbox is IInbox, IForcedInclusionStore, EssentialContract {
    using LibAddress for address;
    using LibMath for uint48;
    using LibMath for uint256;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    uint256 private constant _ACTIVATION_WINDOW = 2 hours;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Result from consuming forced inclusions
    struct ConsumptionResult {
        IInbox.DerivationSource[] sources;
        bool allowsPermissionless;
    }

    /// @notice Result of preparing proof verification and finalization data
    struct ProofResult {
        CoreState newState;
        LibBonds.BondInstruction bondInstruction;
        uint256 proposalAge;
        uint256 firstProvenIndex;
        bytes32 aggregatedTransitionHash;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event InboxActivated(bytes32 lastPacayaBlockHash);

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The codec used for encoding and hashing.
    address private immutable _codec;

    /// @notice The proof verifier contract.
    IProofVerifier internal immutable _proofVerifier;

    /// @notice The proposer checker contract.
    IProposerChecker internal immutable _proposerChecker;

    /// @notice The proving window in seconds.
    uint48 internal immutable _provingWindow;

    /// @notice The extended proving window in seconds.
    uint48 internal immutable _extendedProvingWindow;

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

    /// @notice Queue size at which the fee doubles. See IInbox.Config for formula details.
    uint64 internal immutable _forcedInclusionFeeDoubleThreshold;

    /// @notice The minimum delay between checkpoints in seconds.
    uint16 internal immutable _minCheckpointDelay;

    /// @notice The multiplier to determine when a forced inclusion is too old so that proposing
    /// becomes permissionless
    uint8 internal immutable _permissionlessInclusionMultiplier;

    /// @notice Signal service responsible for checkpoints and bond signals.
    ISignalService internal immutable _signalService;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The timestamp when the first activation occurred.
    uint48 public activationTimestamp;

    /// @notice Persisted core state.
    CoreState internal _state;

    /// @dev Ring buffer for storing proposal hashes indexed by buffer slot
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - proposalHash: The keccak256 hash of the Proposal struct
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev Storage for forced inclusion requests
    /// @dev 2 slots used
    LibForcedInclusion.Storage private _forcedInclusionStorage;

    uint256[37] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    /// @param _config Configuration struct containing all constructor parameters
    constructor(IInbox.Config memory _config) {
        require(_config.signalService != address(0), ZERO_ADDRESS());
        require(_config.ringBufferSize != 0, RingBufferSizeZero());

        _codec = _config.codec;
        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _proposerChecker = IProposerChecker(_config.proposerChecker);
        _signalService = ISignalService(_config.signalService);
        _provingWindow = _config.provingWindow;
        _extendedProvingWindow = _config.extendedProvingWindow;
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
    /// @dev Can be called multiple times within the activation window to handle reorgs.
    /// @param _lastPacayaBlockHash The hash of the last Pacaya block
    function activate(bytes32 _lastPacayaBlockHash) external onlyOwner {
        require(_lastPacayaBlockHash != 0, InvalidLastPacayaBlockHash());
        if (activationTimestamp == 0) {
            activationTimestamp = uint48(block.timestamp);
        } else {
            require(
                block.timestamp <= _ACTIVATION_WINDOW + activationTimestamp,
                ActivationPeriodExpired()
            );
        }
        _activateInbox(_lastPacayaBlockHash);
        emit InboxActivated(_lastPacayaBlockHash);
    }

    /// @inheritdoc IInbox
    /// @notice Proposes new L2 blocks and forced inclusions to the rollup using blobs for DA.
    /// @dev Key behaviors:
    ///      1. Validates proposer authorization via `IProposerChecker`
    ///      2. Process `input.numForcedInclusions` forced inclusions. The proposer is forced to
    ///         process at least `config.minForcedInclusionCount` if they are due.
    ///      3. Updates core state and emits `Proposed` event
    /// NOTE: This function can only be called once per block to prevent spams that can fill the ring buffer.
    function propose(bytes calldata _lookahead, bytes calldata _data) external nonReentrant {
        unchecked {
            ProposeInput memory input = LibProposeInputCodec.decode(_data);
            _validateProposeInput(input);

            uint48 nextProposalId = _state.nextProposalId;
            uint48 lastProposalBlockId = _state.lastProposalBlockId;
            uint48 lastFinalizedProposalId = _state.lastFinalizedProposalId;

            (Proposal memory proposal, Derivation memory derivation) = _buildProposal(
                input, _lookahead, nextProposalId, lastProposalBlockId, lastFinalizedProposalId
            );

            _state.nextProposalId = nextProposalId + 1;
            _state.lastProposalBlockId = uint48(block.number);
            _setProposalHash(proposal.id, LibHashOptimized.hashProposal(proposal));

            _emitProposedEvent(proposal, derivation);
        }
    }

    /// @inheritdoc IInbox
    /// @notice Proves the validity of proposed L2 blocks and finalizes them in-order.
    /// @dev This function allows proofs that have proposals older than `lastFinalizedProposalId`
    /// to be submitted as long as they advance the chain. This is necessary to avoid wasted prover work
    /// or transactions reverting.
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        // Decode and validate input
        ProveInput memory input = LibProveInputCodec.decode(_data);
        _validateProveInput(input);

        ProofResult memory result = _processProof(_state, input);

        bytes32 bondSignal;
        if (result.bondInstruction.bondType != LibBonds.BondType.NONE) {
            bondSignal = _sendBondSignal(result.bondInstruction);
        }

        _state = result.newState;

        _emitProvedEvent(input, result, bondSignal);
        _proofVerifier.verifyProof(result.proposalAge, result.aggregatedTransitionHash, _proof);
    }

    /// @notice Input data for the prove function
    struct ProveInput2 {
        uint48 lastProposalId;
        ICheckpointStore.Checkpoint lastCheckpoint;
        bytes32[] transitionHashs;
    }

    function prove2(bytes calldata _data, bytes calldata _proof) external nonReentrant {


        //                         lastFinalizedProposalId       nextProposalId
        //                         ⇣                             ⇣
        // 0     1     2     3     4     5     6     7     8     9                             
        // ■-----■-----■-----■-----■-----□-----□-----□-----□-----
        //             ⇡     |⇠ proof coverage[3->7]⇢|
        //             firstProposalParentId              

        // In the above exampl, the last finalized proposal is 4, the next proposal is 9. A prover can submit a proof that covers proposal 3 to 7, 
        // and finalize the chain up to 7. We need to verify that the last finalized proposal 4's transition hash is containsd in the proof input.

        CoreState memory state = _state;
        ProveInput2 memory input = abi.decode(_data, (ProveInput2));

        // The hash of the last finalized proposal must match one of the transition hashes provided in the input, but cannot be the last one in the array.
        require(input.transitionHashs.length > 1, "need at least 2 elements");

        uint48 numProvedProposals = uint48(input.transitionHashs.length - 1);
        // The id of the parent proposal of the first proposal being proved
        uint256 firstProposalParentId = input.lastProposalId - numProvedProposals;

        require(
            firstProposalParentId <= state.lastFinalizedProposalId,
            "firstProposal's parent proposal id too big"
        );
        require(
            input.lastProposalId > state.lastFinalizedProposalId, "lastProposalId must progress"
        );
        require(input.lastProposalId < state.nextProposalId, "lastProposalId too big");

        uint256 lastFinalizedProposalIdLocalIndex =
            state.lastFinalizedProposalId - firstProposalParentId;

        require(
            input.transitionHashs[lastFinalizedProposalIdLocalIndex]
                == state.lastFinalizedTransitionHash,
            "lastFinalizedTransitionHash mismatch"
        );

       

        _state.lastFinalizedProposalId = input.lastProposalId;
        _state.lastFinalizedTransitionHash = input.transitionHashs[numProvedProposals];
        _state.lastFinalizedTimestamp = uint48(block.timestamp);

        if (block.timestamp >= state.lastCheckpointTimestamp + _minCheckpointDelay) {
            _signalService.saveCheckpoint(input.lastCheckpoint);
            _state.lastCheckpointTimestamp = uint48(block.timestamp);
        }

        uint256 proposalAge;
        if (numProvedProposals == 1) {
            proposalAge = block.timestamp - uint256(state.lastFinalizedTimestamp);
        }

        // verifier
        bytes32 lastProposalHash = _proposalHashes[input.lastProposalId % _ringBufferSize];
        bytes32 verifierInputHash = keccak256(abi.encode(lastProposalHash, input));
        _proofVerifier.verifyProof(proposalAge, verifierInputHash, _proof);
    }

    /// @inheritdoc IForcedInclusionStore
    /// @dev This function will revert if called before the first non-activation proposal is submitted
    /// to make sure blocks have been produced already and the derivation can use the parent's block timestamp.
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

    // ---------------------------------------------------------------
    // External View Functions
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
    function getForcedInclusionState()
        external
        view
        returns (uint48 head_, uint48 tail_, uint48 lastProcessedAt_)
    {
        return LibForcedInclusion.getForcedInclusionState(_forcedInclusionStorage);
    }

    /// @notice Retrieves the proposal hash for a given proposal ID
    /// @dev Note that due to the ring buffer nature of the `_proposalHashes` mapping proposals may
    /// have been overwritten by a new one. You should verify that the hash matches the expected proposal.
    /// @param _proposalId The ID of the proposal to query
    /// @return proposalHash_ The keccak256 hash of the Proposal struct at the ring buffer slot
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_) {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        proposalHash_ = _proposalHashes[bufferSlot];
    }

    /// @inheritdoc IInbox
    function getConfig() external view returns (IInbox.Config memory config_) {
        config_ = IInbox.Config({
            signalService: address(_signalService),
            proofVerifier: address(_proofVerifier),
            proposerChecker: address(_proposerChecker),
            provingWindow: _provingWindow,
            extendedProvingWindow: _extendedProvingWindow,
            ringBufferSize: _ringBufferSize,
            basefeeSharingPctg: _basefeeSharingPctg,
            codec: _codec,
            minForcedInclusionCount: _minForcedInclusionCount,
            forcedInclusionDelay: _forcedInclusionDelay,
            forcedInclusionFeeInGwei: _forcedInclusionFeeInGwei,
            forcedInclusionFeeDoubleThreshold: _forcedInclusionFeeDoubleThreshold,
            minCheckpointDelay: _minCheckpointDelay,
            permissionlessInclusionMultiplier: _permissionlessInclusionMultiplier
        });
    }

    /// @inheritdoc IInbox
    function getState() external view returns (CoreState memory state_) {
        state_ = _state;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Bootstraps genesis state and emits the initial Proposed event.
    /// @param _lastPacayaBlockHash The hash of the last Pacaya block
    function _activateInbox(bytes32 _lastPacayaBlockHash) internal {
        Transition memory transition;
        transition.checkpoint.blockHash = _lastPacayaBlockHash;

        // Set lastProposalBlockId to 1 to ensure the first proposal happens at block 2 or later.
        // This prevents reading blockhash(0) in propose(), which would return 0x0 and create
        // an invalid origin block hash. The EVM hardcodes blockhash(0) to 0x0, so we must
        // ensure proposals never reference the genesis block.
        CoreState memory state;
        state.nextProposalId = 1;
        state.lastProposalBlockId = 1;
        state.lastFinalizedTimestamp = uint48(block.timestamp);
        state.lastFinalizedTransitionHash = LibHashOptimized.hashTransition(transition);

        Proposal memory proposal;
        Derivation memory derivation;
        proposal.derivationHash = LibHashOptimized.hashDerivation(derivation);

        _state = state;
        _setProposalHash(0, LibHashOptimized.hashProposal(proposal));

        _emitProposedEvent(proposal, derivation);
    }

    /// @dev Builds proposal and derivation data. It also checks if `msg.sender` can propose.
    /// @param _input The propose input data.
    /// @param _lookahead Encoded data forwarded to the proposer checker (i.e. lookahead payloads).
    /// @param _nextProposalId The proposal ID to assign.
    /// @param _lastProposalBlockId The last block number where a proposal was made.
    /// @param _lastFinalizedProposalId The ID of the last finalized proposal.
    /// @return proposal_ The proposal with final endOfSubmissionWindowTimestamp and derivation hash set.
    /// @return derivation_ The derivation data for the proposal.
    function _buildProposal(
        ProposeInput memory _input,
        bytes calldata _lookahead,
        uint48 _nextProposalId,
        uint48 _lastProposalBlockId,
        uint48 _lastFinalizedProposalId
    )
        private
        returns (Proposal memory proposal_, Derivation memory derivation_)
    {
        unchecked {
            // Enforce one propose call per Ethereum block to prevent spam attacks that could
            // deplete the ring buffer
            require(block.number > _lastProposalBlockId, CannotProposeInCurrentBlock());
            require(
                _getAvailableCapacity(_nextProposalId, _lastFinalizedProposalId) > 0,
                NotEnoughCapacity()
            );

            ConsumptionResult memory result =
                _consumeForcedInclusions(msg.sender, _input.numForcedInclusions);

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
            derivation_ = Derivation({
                originBlockNumber: uint48(parentBlockNumber),
                originBlockHash: blockhash(parentBlockNumber),
                basefeeSharingPctg: _basefeeSharingPctg,
                sources: result.sources
            });

            proposal_ = Proposal({
                id: _nextProposalId,
                timestamp: uint48(block.timestamp),
                endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
                proposer: msg.sender,
                derivationHash: LibHashOptimized.hashDerivation(derivation_)
            });
        }
    }

    /// @dev Processes sequential proofs, calculates the bond instruction and the resulting state
    /// @param _stateBefore The state before the proof is processed
    /// @param _input The input containing the proposals and transitions
    /// @return result_ Aggregated result containing new state, bond instruction, verifier hash, and indexes.
    function _processProof(
        CoreState memory _stateBefore,
        ProveInput memory _input
    )
        private
        returns (ProofResult memory result_)
    {
        unchecked {
            result_.newState = _stateBefore;

            uint48 expectedId = _stateBefore.lastFinalizedProposalId + 1;
            uint256 count = _input.proposals.length;
            bytes32 parentHash = _stateBefore.lastFinalizedTransitionHash;
            uint48 firstReadyTimestamp;

            // Find the index of the first proposal that still has not been proven
            // This help if the array includes older proposals that have already been proven
            result_.firstProvenIndex = _findFirstIndexToProve(_stateBefore, _input);

            for (uint256 i = result_.firstProvenIndex; i < count; ++i) {
                Proposal memory proposal = _input.proposals[i];
                require(proposal.id == expectedId, InvalidProposalId());

                bytes32 proposalHash = _checkProposalHash(proposal);
                Transition memory transition = _input.transitions[i];
                require(
                    proposalHash == transition.proposalHash, ProposalHashMismatchWithTransition()
                );
                require(transition.parentTransitionHash == parentHash, InvalidParentTransition());

                if (i == result_.firstProvenIndex) {
                    firstReadyTimestamp = _computeReadyTimestamp(
                        proposal.timestamp, _stateBefore.lastFinalizedTimestamp
                    );
                }

                parentHash = LibHashOptimized.hashTransition(transition);
                ++expectedId;
            }

            // Only the first unproven proposal in a sequential prove can be late; later proposals
            // become proveable when the previous one finalizes within this transaction.
            result_.bondInstruction = _calculateBondInstruction(
                _input.proposals[result_.firstProvenIndex],
                _input.transitions[result_.firstProvenIndex],
                firstReadyTimestamp
            );

            result_.newState.lastFinalizedProposalId = expectedId - 1;
            result_.newState.lastFinalizedTimestamp = uint48(block.timestamp);
            result_.newState.lastFinalizedTransitionHash = parentHash;

            _syncCheckpointIfNeeded(
                _input.syncCheckpoint,
                _input.transitions[_input.transitions.length - 1],
                result_.newState
            );

            uint256 proposalsProven = count - result_.firstProvenIndex;
            if (proposalsProven == 1) {
                result_.proposalAge = block.timestamp - uint256(firstReadyTimestamp);
            }

            result_.aggregatedTransitionHash = LibHashOptimized.hashTransitions(_input.transitions);
        }
    }

    /// @dev Finds the index of the first proposal that will be used for proving.
    /// When there are no new proposals to be proven, this function still returns 0.
    /// @param _stateBefore The state before processing the proof
    /// @param _input The prove input
    /// @return  Index of the first proposal to process. Returning 0 does not guarantee that all the proposal are valid.
    function _findFirstIndexToProve(
        CoreState memory _stateBefore,
        ProveInput memory _input
    )
        private
        pure
        returns (uint256)
    {
        unchecked {
            uint48 lastFinalizedId = _stateBefore.lastFinalizedProposalId;
            bytes32 lastFinalizedHash = _stateBefore.lastFinalizedTransitionHash;
            uint256 count = _input.proposals.length;

            // We iterate until the second to last proposal, because if the last one is the current,
            // `lastFinalizedProposalId` then there's nothing else to prove
            for (uint256 i; i < count - 1; ++i) {
                if (
                    _input.proposals[i].id == lastFinalizedId
                        && LibHashOptimized.hashTransition(_input.transitions[i])
                            == lastFinalizedHash
                ) {
                    return i + 1;
                }
            }

            return 0;
        }
    }

    /// @dev Stores a proposal hash in the ring buffer
    /// Overwrites any existing hash at the calculated buffer slot
    function _setProposalHash(uint48 _proposalId, bytes32 _proposalHash) internal {
        _proposalHashes[_proposalId % _ringBufferSize] = _proposalHash;
    }

    /// @dev Calculates the timestamp when a proposal was ready to be proven.
    /// This is used for bond calculation.
    /// @param _proposalTimestamp The timestamp of the proposal
    /// @param _priorFinalizedTimestamp The timestamp of the last finalized proposal
    function _computeReadyTimestamp(
        uint48 _proposalTimestamp,
        uint48 _priorFinalizedTimestamp
    )
        private
        pure
        returns (uint48)
    {
        return _proposalTimestamp > _priorFinalizedTimestamp
            ? _proposalTimestamp
            : _priorFinalizedTimestamp;
    }

    /// @dev Validates proposal hash against stored value
    /// Reverts with ProposalHashMismatch if hashes don't match
    /// @param _proposal The proposal to validate
    /// @return proposalHash_ The computed hash of the proposal
    function _checkProposalHash(Proposal memory _proposal)
        internal
        view
        returns (bytes32 proposalHash_)
    {
        proposalHash_ = LibHashOptimized.hashProposal(_proposal);
        bytes32 storedProposalHash = _proposalHashes[_proposal.id % _ringBufferSize];
        require(proposalHash_ == storedProposalHash, ProposalHashMismatch());
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Consumes forced inclusions from the queue and returns result with extra slot for normal
    /// source
    /// @param _feeRecipient Address to receive accumulated fees
    /// @param _numForcedInclusionsRequested Maximum number of forced inclusions to consume
    /// @return result_ ConsumptionResult with sources array (size: processed + 1, last slot empty)
    /// and whether permissionless proposals are allowed
    function _consumeForcedInclusions(
        address _feeRecipient,
        uint256 _numForcedInclusionsRequested
    )
        private
        returns (ConsumptionResult memory result_)
    {
        unchecked {
            LibForcedInclusion.Storage storage $ = _forcedInclusionStorage;

            // Load storage once
            (uint48 head, uint48 tail, uint48 lastProcessedAt) = ($.head, $.tail, $.lastProcessedAt);

            uint256 available = tail - head;
            uint256 toProcess = _numForcedInclusionsRequested > available
                ? available
                : _numForcedInclusionsRequested;

            result_.sources = new IInbox.DerivationSource[](toProcess + 1);

            uint48 oldestTimestamp;
            (oldestTimestamp, head, lastProcessedAt) = _dequeueAndProcessForcedInclusions(
                $, _feeRecipient, result_.sources, head, lastProcessedAt, toProcess
            );

            if (_numForcedInclusionsRequested < _minForcedInclusionCount && available > toProcess) {
                bool isOldestInclusionDue = LibForcedInclusion.isOldestForcedInclusionDue(
                    $, head, tail, lastProcessedAt, _forcedInclusionDelay
                );
                require(!isOldestInclusionDue, UnprocessedForcedInclusionIsDue());
            }

            uint256 permissionlessTimestamp = uint256(_forcedInclusionDelay)
                * _permissionlessInclusionMultiplier + oldestTimestamp;
            result_.allowsPermissionless = block.timestamp > permissionlessTimestamp;
        }
    }

    /// @dev Dequeues and processes forced inclusions from the queue
    function _dequeueAndProcessForcedInclusions(
        LibForcedInclusion.Storage storage $,
        address _feeRecipient,
        IInbox.DerivationSource[] memory _sources,
        uint48 _head,
        uint48 _lastProcessedAt,
        uint256 _toProcess
    )
        private
        returns (uint48 oldestTimestamp_, uint48 head_, uint48 lastProcessedAt_)
    {
        if (_toProcess > 0) {
            uint256 totalFees;
            unchecked {
                for (uint256 i; i < _toProcess; ++i) {
                    IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[_head + i];
                    _sources[i] = IInbox.DerivationSource(true, inclusion.blobSlice);
                    totalFees += inclusion.feeInGwei;
                }
            }

            if (totalFees > 0) {
                _feeRecipient.sendEtherAndVerify(totalFees * 1 gwei);
            }

            oldestTimestamp_ = uint48(_sources[0].blobSlice.timestamp.max(_lastProcessedAt));

            head_ = _head + uint48(_toProcess);
            lastProcessedAt_ = uint48(block.timestamp);

            ($.head, $.lastProcessedAt) = (head_, lastProcessedAt_);
        } else {
            oldestTimestamp_ = type(uint48).max;
            head_ = _head;
            lastProcessedAt_ = _lastProcessedAt;
        }
    }

    /// @dev Emits the Proposed event
    function _emitProposedEvent(
        Proposal memory _proposal,
        Derivation memory _derivation
    )
        private
    {
        ProposedEventPayload memory payload =
            ProposedEventPayload({ proposal: _proposal, derivation: _derivation });
        emit Proposed(LibProposedEventCodec.encode(payload));
    }

    /// @dev Emits the Proved event for the first proven proposal in the batch.
    /// @param _input The prove input containing proposals and transitions.
    /// @param _result Prepared proof result data.
    /// @param _bondSignal The bond signal hash emitted to L2 (zero when unused).
    function _emitProvedEvent(
        ProveInput memory _input,
        ProofResult memory _result,
        bytes32 _bondSignal
    )
        private
    {
        ProvedEventPayload memory payload = ProvedEventPayload({
            proposalId: _input.proposals[_result.firstProvenIndex].id,
            transition: _input.transitions[_result.firstProvenIndex],
            bondInstruction: _result.bondInstruction,
            bondSignal: _bondSignal
        });
        emit Proved(LibProvedEventCodec.encode(payload));
    }

    /// @dev Syncs checkpoint to storage when voluntary or forced sync conditions are met.
    /// @param _syncCheckpoint Whether to persist the checkpoint from the last transition.
    /// @param _lastTransition The last transition in the proven batch (source of checkpoint).
    /// @param _coreState Core state to update with new checkpoint timestamp.
    function _syncCheckpointIfNeeded(
        bool _syncCheckpoint,
        Transition memory _lastTransition,
        CoreState memory _coreState
    )
        private
    {
        if (_syncCheckpoint) {
            ICheckpointStore.Checkpoint memory checkpoint = _lastTransition.checkpoint;
            require(checkpoint.blockHash != 0, CheckpointMismatch());

            _signalService.saveCheckpoint(checkpoint);
            _coreState.lastCheckpointTimestamp = uint48(block.timestamp);
        } else {
            require(
                block.timestamp < _coreState.lastCheckpointTimestamp + _minCheckpointDelay,
                CheckpointNotProvided()
            );
        }
    }

    /// @dev Sends a bond instruction signal to L2.
    /// @param _bondInstruction The bond instruction to encode into the signal.
    /// @return signal_ The signal hash emitted to the signal service.
    function _sendBondSignal(LibBonds.BondInstruction memory _bondInstruction)
        private
        returns (bytes32 signal_)
    {
        signal_ = LibHashOptimized.hashBondInstruction(_bondInstruction);
        _signalService.sendSignal(signal_);
    }

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
            uint256 numUnfinalizedProposals = _nextProposalId - _lastFinalizedProposalId - 1;
            return _ringBufferSize - 1 - numUnfinalizedProposals;
        }
    }

    /// @dev Validates prove function inputs.
    /// @param _input The ProveInput to validate
    function _validateProveInput(ProveInput memory _input) private pure {
        require(_input.proposals.length != 0, EmptyProposals());
        require(_input.proposals.length == _input.transitions.length, InconsistentParams());
    }

    /// @dev Validates propose function inputs.
    /// @param _input The ProposeInput to validate
    function _validateProposeInput(ProposeInput memory _input) private view {
        require(_input.deadline == 0 || block.timestamp <= _input.deadline, DeadlineExceeded());
    }

    /// @dev Calculates bond instruction for a sequential prove call.
    /// @dev Bond instruction rules:
    ///         - On-time (within provingWindow): No bond changes.
    ///         - Late (within extendedProvingWindow): Liveness bond transfer if prover differs
    ///           from designated prover of the first transition.
    ///         - Very late (after extendedProvingWindow): Provability bond transfer if prover
    ///           differs from proposer of the first transition.
    /// @param _firstProposal The first proposal proven in the batch.
    /// @param _firstTransition The transition for the first proposal.
    /// @param _readyTimestamp Timestamp when the first proposal became proveable.
    /// @return bondInstruction_ A bond transfer instruction, or a BondType.NONE instruction when
    ///         no transfer is required.
    function _calculateBondInstruction(
        Proposal memory _firstProposal,
        Transition memory _firstTransition,
        uint48 _readyTimestamp
    )
        private
        view
        returns (LibBonds.BondInstruction memory bondInstruction_)
    {
        unchecked {
            uint256 proofTimestamp = block.timestamp;
            uint256 windowEnd = uint256(_readyTimestamp) + _provingWindow;

            // On-time proof - no bond instructions needed.
            if (proofTimestamp <= windowEnd) {
                return bondInstruction_;
            }

            uint256 extendedWindowEnd = uint256(_readyTimestamp) + _extendedProvingWindow;
            bool isWithinExtendedWindow = proofTimestamp <= extendedWindowEnd;

            address payer = isWithinExtendedWindow
                ? _firstTransition.designatedProver
                : _firstProposal.proposer;
            address payee = _firstTransition.actualProver;

            // If payer and payee are identical, there is no bond movement.
            if (payer == payee) {
                return bondInstruction_;
            }

            bondInstruction_ = LibBonds.BondInstruction({
                proposalId: _firstProposal.id,
                bondType: isWithinExtendedWindow
                    ? LibBonds.BondType.LIVENESS
                    : LibBonds.BondType.PROVABILITY,
                payer: payer,
                payee: payee
            });
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ActivationPeriodExpired();
    error CannotProposeInCurrentBlock();
    error CheckpointMismatch();
    error CheckpointNotProvided();
    error DeadlineExceeded();
    error EmptyProposals();
    error InconsistentParams();
    error IncorrectProposalCount();
    error InvalidLastPacayaBlockHash();
    error InvalidParentTransition();
    error InvalidProposalId();
    error NotEnoughCapacity();
    error ProposalHashMismatch();
    error ProposalHashMismatchWithTransition();
    error RingBufferSizeZero();
    error UnprocessedForcedInclusionIsDue();
}
