// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICodec } from "../iface/ICodec.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { LibHashOptimized as H } from "../libs/LibHashOptimized.sol";
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
///      - Proof verification with transition record management
///      - Ring buffer storage for efficient state management
///      - Bond instruction calculation(but actual funds are managed on L2)
///      - Finalization of proven proposals with checkpoint rate limiting
/// @custom:security-contact security@taiko.xyz
contract Inbox is IInbox, IForcedInclusionStore, EssentialContract {
    using LibAddress for address;
    using LibMath for uint40;
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
        DerivationSource[] sources;
        bool allowsPermissionless;
    }

    /// @dev Stores the first transition record for each proposal to reduce gas costs.
    ///      Uses a ring buffer pattern with proposal ID modulo ring buffer size.
    ///      Uses multiple storage slots for the struct (48 + 26*8 + 26 + 48 = 304 bits)
    struct FirstTransitionStorage {
        uint40 proposalId;
        bytes27 parentTransitionHash;
        TransitionRecord record;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event InboxActivated(bytes32 lastPacayaBlockHash);

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The codec contract for encoding/decoding and hashing.
    ICodec internal immutable _codec;

    /// @notice The proof verifier contract.
    IProofVerifier internal immutable _proofVerifier;

    /// @notice The proposer checker contract.
    IProposerChecker internal immutable _proposerChecker;

    /// @notice Checkpoint store responsible for checkpoints
    ICheckpointStore internal immutable _checkpointStore;

    /// @notice Signal service for cross-chain messaging
    ISignalService internal immutable _signalService;

    /// @notice The proving window in seconds.
    uint40 internal immutable _provingWindow;

    /// @notice The extended proving window in seconds.
    uint40 internal immutable _extendedProvingWindow;

    /// @notice The maximum number of proposals that can be finalized in one finalization call.
    uint256 internal immutable _maxFinalizationCount;

    /// @notice The cooldown period in seconds before a proven transition can be finalized.
    uint40 internal immutable _transitionCooldown;

    /// @notice The finalization grace period in seconds.
    uint40 internal immutable _finalizationGracePeriod;

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

    /// @notice The minimum delay in proposals between two syncs
    uint16 internal immutable _minSyncDelay;

    /// @notice The multiplier to determine when a forced inclusion is too old so that proposing
    /// becomes permissionless
    uint8 internal immutable _permissionlessInclusionMultiplier;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The timestamp when the first activation occurred.
    uint40 public activationTimestamp;

    /// @dev Ring buffer for storing proposal hashes indexed by buffer slot
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - proposalHash: The keccak256 hash of the Proposal struct
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev Stores the first transition record for each proposal in a compact ring buffer.
    ///      This ring buffer approach optimizes gas by reusing storage slots.
    mapping(uint256 bufferSlot => FirstTransitionStorage firstRecord) internal
        _firstTransitionStorages;

    /// @dev Stores all non-first transition records for proposals in dedicated, non-reusable storage slots.
    ///      No ring buffer is used here; each record is always stored in its unique slot.
    mapping(bytes32 compositeKey => TransitionRecord record) internal _transitionRecords;

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
        require(_config.checkpointStore != address(0), ZERO_ADDRESS());
        require(_config.ringBufferSize != 0, RingBufferSizeZero());

        _codec = ICodec(_config.codec);
        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _proposerChecker = IProposerChecker(_config.proposerChecker);
        _checkpointStore = ICheckpointStore(_config.checkpointStore);
        _signalService = ISignalService(_config.signalService);
        _provingWindow = _config.provingWindow;
        _extendedProvingWindow = _config.extendedProvingWindow;
        _maxFinalizationCount = _config.maxFinalizationCount;
        _transitionCooldown = _config.transitionCooldown;
        _finalizationGracePeriod = _config.finalizationGracePeriod;
        _ringBufferSize = _config.ringBufferSize;
        _basefeeSharingPctg = _config.basefeeSharingPctg;
        _minForcedInclusionCount = _config.minForcedInclusionCount;
        _forcedInclusionDelay = _config.forcedInclusionDelay;
        _forcedInclusionFeeInGwei = _config.forcedInclusionFeeInGwei;
        _forcedInclusionFeeDoubleThreshold = _config.forcedInclusionFeeDoubleThreshold;
        _minSyncDelay = _config.minSyncDelay;
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
    /// @dev The `propose` function implicitly checks that activation has occurred by verifying
    ///      the genesis proposal (ID 0) exists in storage via `_verifyHeadProposal` →
    ///      `_checkProposalHash`. If `activate` hasn't been called, the genesis proposal won't
    ///      exist and `propose` will revert with `ProposalHashMismatch()`.
    ///      This function can be called multiple times to handle L1 reorgs where the last Pacaya
    ///      block may change after this function is called.
    /// @param _lastPacayaBlockHash The hash of the last Pacaya block
    function activate(bytes32 _lastPacayaBlockHash) external onlyOwner {
        require(_lastPacayaBlockHash != 0, InvalidLastPacayaBlockHash());

        if (activationTimestamp == 0) {
            activationTimestamp = uint40(block.timestamp);
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
    function propose(bytes calldata _lookahead, bytes calldata _data) external nonReentrant {
        unchecked {
            // Decode and validate input data
            ProposeInput memory input = LibProposeInputCodec.decode(_data);

            // Validate proposal input data
            require(input.deadline == 0 || block.timestamp <= input.deadline, DeadlineExceeded());

            // Enforce one propose call per Ethereum block to prevent spam attacks that could
            // deplete the ring buffer
            require(
                block.number > input.coreState.proposalHeadContainerBlock,
                CannotProposeInCurrentBlock()
            );

            // Verify parentProposals[0] is the head proposal
            bytes32 headProposalHash = _verifyHeadProposal(input.headProposalAndProof);

            require(
                H.hashCoreState(input.coreState) == input.headProposalAndProof[0].coreStateHash,
                InvalidState()
            );

            // Finalize proposals before proposing a new one to free ring buffer space and prevent deadlock
            CoreState memory coreState = _finalize(input);

            // Verify capacity for new proposals
            require(_getAvailableCapacity(coreState) > 0, NoCapacity());

            // Consume forced inclusions (validation happens inside)
            ConsumptionResult memory result =
                _consumeForcedInclusions(msg.sender, input.numForcedInclusions);

            // Add normal proposal source in last slot
            result.sources[result.sources.length - 1] =
                DerivationSource(false, LibBlobs.validateBlobReference(input.blobReference));

            // If forced inclusion is old enough, allow anyone to propose
            // and set endOfSubmissionWindowTimestamp = 0
            // Otherwise, only the current preconfer can propose
            uint40 endOfSubmissionWindowTimestamp;

            if (!result.allowsPermissionless) {
                endOfSubmissionWindowTimestamp =
                    _proposerChecker.checkProposer(msg.sender, _lookahead);
            }

            // Create single proposal with multi-source derivation
            // Use previous block as the origin for the proposal to be able to call `blockhash`
            uint256 parentBlockNumber = block.number - 1;

            Derivation memory derivation = Derivation({
                originBlockNumber: uint40(parentBlockNumber),
                originBlockHash: blockhash(parentBlockNumber),
                basefeeSharingPctg: _basefeeSharingPctg,
                sources: result.sources
            });

            coreState.proposalHeadContainerBlock = uint40(block.number);
            coreState.proposalHead += 1;

            Proposal memory proposal = Proposal({
                id: coreState.proposalHead,
                timestamp: uint40(block.timestamp),
                endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
                proposer: msg.sender,
                coreStateHash: H.hashCoreState(coreState),
                derivationHash: H.hashDerivation(derivation),
                parentProposalHash: headProposalHash
            });

            _proposalHashes[proposal.id % _ringBufferSize] = H.hashProposal(proposal);
            _emitProposedEvent(proposal, derivation, coreState, input.transitions);
        }
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        unchecked {
            ProveInput[] memory inputs = LibProveInputCodec.decode(_data);
            require(inputs.length != 0, EmptyProveInputs());

            for (uint256 i; i < inputs.length; ++i) {
                _checkProposalHash(inputs[i].proposal);

                LibBonds.BondInstruction[] memory bondInstructions =
                    _calculateBondInstructions(inputs[i]);

                bytes32 bondInstructionHash = bondInstructions.length == 0
                    ? bytes32(0)
                    : H.hashBondInstruction(bondInstructions[0]);

                Transition memory transition = Transition({
                    bondInstructionHash: bondInstructionHash,
                    checkpointHash: H.hashCheckpoint(inputs[i].checkpoint)
                });

                TransitionRecord memory record = TransitionRecord({
                    transitionHash: H.hashTransition(transition), timestamp: uint40(block.timestamp)
                });

                _storeTransitionRecord(
                    inputs[i].proposal.id, inputs[i].parentTransitionHash, record
                );

                _emitProvedEvent(inputs[i], bondInstructions);
            }

            uint256 proposalAge;
            if (inputs.length == 1) {
                proposalAge = block.timestamp - inputs[0].proposal.timestamp;
            }

            _proofVerifier.verifyProof(proposalAge, H.hashProveInputArray(inputs), _proof);
        }
    }

    /// @inheritdoc IForcedInclusionStore
    /// @dev This function will revert if called before the first non-activation proposal is submitted
    /// to make sure blocks have been produced already and the derivation can use the parent's block timestamp.
    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable {
        bytes32 proposalHash = _proposalHashes[1];
        require(proposalHash != bytes32(0), NoProposalExists());

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
        uint40 _start,
        uint40 _maxCount
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
        returns (uint40 head_, uint40 tail_, uint40 lastProcessedAt_)
    {
        return LibForcedInclusion.getForcedInclusionState(_forcedInclusionStorage);
    }

    /// @notice Returns the stored hash at the proposal ring buffer slot for a given proposal ID.
    /// @dev Does not verify the stored hash against the full Proposal struct.
    /// @param _proposalId The ID of the proposal to query
    /// @return proposalHash_ The keccak256 hash of the Proposal struct at the ring buffer slot
    function getProposalHash(uint40 _proposalId) external view returns (bytes32 proposalHash_) {
        return _loadProposalHash(_proposalId);
    }

    /// @notice Retrieves the transition record hash for a specific proposal and parent transition
    /// @param _proposalId The ID of the proposal containing the transition
    /// @param _parentTransitionHash The hash of the parent transition in the proof chain
    /// @return record_ The transition record metadata.
    function getTransitionRecord(
        uint40 _proposalId,
        bytes27 _parentTransitionHash
    )
        external
        view
        returns (TransitionRecord memory record_)
    {
        return _loadTransitionRecord(_proposalId, _parentTransitionHash);
    }

    /// @inheritdoc IInbox
    function getConfig() external view returns (Config memory config_) {
        config_ = Config({
            codec: address(_codec),
            proofVerifier: address(_proofVerifier),
            proposerChecker: address(_proposerChecker),
            checkpointStore: address(_checkpointStore),
            signalService: address(_signalService),
            provingWindow: _provingWindow,
            extendedProvingWindow: _extendedProvingWindow,
            maxFinalizationCount: _maxFinalizationCount,
            transitionCooldown: _transitionCooldown,
            finalizationGracePeriod: _finalizationGracePeriod,
            ringBufferSize: _ringBufferSize,
            basefeeSharingPctg: _basefeeSharingPctg,
            minForcedInclusionCount: _minForcedInclusionCount,
            forcedInclusionDelay: _forcedInclusionDelay,
            forcedInclusionFeeInGwei: _forcedInclusionFeeInGwei,
            forcedInclusionFeeDoubleThreshold: _forcedInclusionFeeDoubleThreshold,
            minSyncDelay: _minSyncDelay,
            permissionlessInclusionMultiplier: _permissionlessInclusionMultiplier
        });
    }

    // ---------------------------------------------------------------
    // Private Functions - Activation
    // ---------------------------------------------------------------

    /// @dev Activates the inbox with genesis state so that it can start accepting proposals.
    /// Sets up the initial proposal and core state with genesis block.
    /// Can be called multiple times to handle L1 reorgs or correct incorrect values.
    /// Resets state variables to allow fresh start.
    /// @param _lastPacayaBlockHash The hash of the last Pacaya block
    function _activateInbox(bytes32 _lastPacayaBlockHash) private {
        ICheckpointStore.Checkpoint memory checkpoint;
        checkpoint.blockHash = _lastPacayaBlockHash;

        Transition memory transition;
        transition.checkpointHash = H.hashCheckpoint(checkpoint);

        CoreState memory coreState;
        coreState.proposalHead = 0;

        // Set proposalHeadContainerBlock to 1 to ensure the first proposal happens at block 2 or later.
        // This prevents reading blockhash(0) in propose(), which would return 0x0 and create
        // an invalid origin block hash. The EVM hardcodes blockhash(0) to 0x0, so we must
        // ensure proposals never reference the genesis block.
        coreState.proposalHeadContainerBlock = 1;
        coreState.finalizationHeadTransitionHash = H.hashTransition(transition);

        Proposal memory proposal;
        proposal.coreStateHash = H.hashCoreState(coreState);

        Derivation memory derivation;
        proposal.derivationHash = H.hashDerivation(derivation);

        _proposalHashes[0] = H.hashProposal(proposal);

        _emitProposedEvent(proposal, derivation, coreState, new Transition[](0));
    }

    // ---------------------------------------------------------------
    // Private Functions - Proposal Flow
    // ---------------------------------------------------------------

    /// @dev Verifies that the first element of _headProposalAndProof is the current chain head.
    ///      Uses ring buffer semantics: if the next slot is occupied, it must contain a proposal
    ///      with a small ID (meaning the buffer wrapped around and we're at the true head).
    /// @param _headProposalAndProof Array of 1-2 proposals:
    ///        - [0]: The claimed head proposal (must match on-chain storage)
    ///        - [1]: Optional proof proposal (required only if next slot is occupied)
    /// @return headProposalHash_ The verified hash of the head proposal
    function _verifyHeadProposal(Proposal[] memory _headProposalAndProof)
        private
        view
        returns (bytes32 headProposalHash_)
    {
        unchecked {
            require(_headProposalAndProof.length != 0, EmptyProposals());
            Proposal memory headProposal = _headProposalAndProof[0];

            // Verify the claimed head proposal matches on-chain storage
            headProposalHash_ = _checkProposalHash(headProposal);

            // Check the next buffer slot to confirm this is truly the chain head
            bytes32 nextSlotHash = _loadProposalHash(headProposal.id + 1);

            if (nextSlotHash == 0) {
                // Next slot is empty, so head proposal is definitely the latest
                require(_headProposalAndProof.length == 1, TooManyProofProposals());
            } else {
                // Next slot is occupied due to ring buffer wrap-around.
                // Must prove the occupant has a larger ID (i.e., it's an older proposal
                // that wrapped around, not a newer one after our claimed head).
                require(_headProposalAndProof.length == 2, MissingProofProposal());
                Proposal memory proofProposal = _headProposalAndProof[1];
                require(headProposal.id > proofProposal.id, InvalidLastProposalProof());
                require(nextSlotHash == H.hashProposal(proofProposal), NextProposalHashMismatch());
            }
        }
    }

    /// @dev Calculates remaining capacity for new proposals
    /// Subtracts unfinalized proposals from total capacity
    /// @param _coreState Current state with proposal counters
    /// @return _ Number of additional proposals that can be submitted
    function _getAvailableCapacity(CoreState memory _coreState) private view returns (uint256) {
        unchecked {
            return _ringBufferSize + _coreState.finalizationHead - _coreState.proposalHead - 1;
        }
    }

    // ---------------------------------------------------------------
    // Private Functions - Forced Inclusion Flow
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
            (uint40 head, uint40 tail, uint40 lastProcessedAt) = ($.head, $.tail, $.lastProcessedAt);

            uint256 available = tail - head;
            uint256 toProcess = _numForcedInclusionsRequested.min(available);

            // Allocate array with extra slot for normal source
            result_.sources = new DerivationSource[](toProcess + 1);

            // Process inclusions if any
            uint40 oldestTimestamp;
            (oldestTimestamp, head, lastProcessedAt) = _dequeueAndProcessForcedInclusions(
                $, _feeRecipient, result_.sources, head, lastProcessedAt, toProcess
            );

            // We check the following conditions are met:
            // 1. Proposer is willing to include at least the minimum required
            // (_minForcedInclusionCount)
            // 2. Proposer included all available inclusions
            // 3. The oldest inclusion is not due
            if (_numForcedInclusionsRequested < _minForcedInclusionCount && available > toProcess) {
                bool isOldestInclusionDue = LibForcedInclusion.isOldestForcedInclusionDue(
                    $, head, tail, lastProcessedAt, _forcedInclusionDelay
                );
                require(!isOldestInclusionDue, UnprocessedForcedInclusionIsDue());
            }

            // Check if permissionless proposals are allowed
            uint256 permissionlessTimestamp = uint256(_forcedInclusionDelay)
                * _permissionlessInclusionMultiplier + oldestTimestamp;
            result_.allowsPermissionless = block.timestamp > permissionlessTimestamp;
        }
    }

    /// @dev Dequeues and processes forced inclusions from the queue
    /// @param $ Storage reference
    /// @param _feeRecipient Address to receive fees
    /// @param _sources Array to populate with derivation sources
    /// @param _head Current queue head position
    /// @param _lastProcessedAt Timestamp of last processing
    /// @param _toProcess Number of inclusions to process
    /// @return oldestTimestamp_ Oldest timestamp from processed inclusions
    /// @return head_ Updated head position
    /// @return lastProcessedAt_ Updated last processed timestamp
    function _dequeueAndProcessForcedInclusions(
        LibForcedInclusion.Storage storage $,
        address _feeRecipient,
        DerivationSource[] memory _sources,
        uint40 _head,
        uint40 _lastProcessedAt,
        uint256 _toProcess
    )
        private
        returns (uint40 oldestTimestamp_, uint40 head_, uint40 lastProcessedAt_)
    {
        unchecked {
            if (_toProcess > 0) {
                // Process inclusions and accumulate fees
                uint256 totalFees;
                for (uint256 i; i < _toProcess; ++i) {
                    IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[_head + i];
                    _sources[i] = DerivationSource(true, inclusion.blobSlice);
                    totalFees += inclusion.feeInGwei;
                }

                // Transfer accumulated fees
                if (totalFees > 0) {
                    _feeRecipient.sendEtherAndVerify(totalFees * 1 gwei);
                }

                // Oldest timestamp is max of first inclusion timestamp and last processed time
                oldestTimestamp_ = uint40(_sources[0].blobSlice.timestamp.max(_lastProcessedAt));

                // Update queue position and last processed time
                head_ = _head + uint40(_toProcess);
                lastProcessedAt_ = uint40(block.timestamp);

                // Write to storage once
                ($.head, $.lastProcessedAt) = (head_, lastProcessedAt_);
            } else {
                // No inclusions processed
                oldestTimestamp_ = type(uint40).max;
                head_ = _head;
                lastProcessedAt_ = _lastProcessedAt;
            }
        }
    }

    // ---------------------------------------------------------------
    // Private Functions - Finalization Flow
    // ---------------------------------------------------------------

    /// @dev Finalizes proven proposals and updates checkpoints with rate limiting.
    /// Checkpoints are only saved if minSyncDelay seconds have passed since the last save,
    /// reducing SSTORE operations but making L2 checkpoints less frequently available on L1.
    /// Set minSyncDelay to 0 to disable rate limiting.
    /// @param _input Contains transition records and the end block header.
    /// @return coreState_ Updated core state with new finalization counters.
    function _finalize(ProposeInput memory _input) private returns (CoreState memory coreState_) {
        unchecked {
            coreState_ = _input.coreState;
            uint40 proposalId = coreState_.finalizationHead + 1;
            uint256 lastFinalizedIdx;
            uint256 finalizedCount;
            uint256 transitionCount = _input.transitions.length;

            for (uint256 i; i < _maxFinalizationCount; ++i) {
                // Check if there are more proposals to finalize
                if (proposalId > coreState_.proposalHead) break;

                // Try to finalize the current proposal
                TransitionRecord memory record =
                    _loadTransitionRecord(proposalId, coreState_.finalizationHeadTransitionHash);

                if (record.transitionHash == 0) break;

                // Break if a conflicting transition was detected (timestamp set to max)
                if (record.timestamp == type(uint40).max) break;

                // Check if transition is still cooling down
                if (block.timestamp < uint256(record.timestamp) + _transitionCooldown) {
                    revert TransitionCoolingDown();
                }

                // Calculate finalization deadline from timestamp
                if (i >= transitionCount) {
                    uint256 finalizationDeadline =
                        uint256(record.timestamp) + _finalizationGracePeriod;
                    require(block.timestamp < finalizationDeadline, TransitionNotProvided());
                    break;
                }

                require(
                    H.hashTransition(_input.transitions[i]) == record.transitionHash,
                    TransitionHashMismatchWithStorage()
                );

                coreState_.finalizationHead = proposalId;
                coreState_.finalizationHeadTransitionHash = record.transitionHash;

                // Aggregate bond instruction hash
                if (_input.transitions[i].bondInstructionHash != 0) {
                    coreState_.aggregatedBondInstructionsHash = H.hashAggregatedBondInstructionsHash(
                        coreState_.aggregatedBondInstructionsHash,
                        _input.transitions[i].bondInstructionHash
                    );
                }

                proposalId += 1;
                finalizedCount += 1;
                lastFinalizedIdx = i;
            }

            require(finalizedCount == transitionCount, IncorrectTransitionCount());

            // Update checkpoint if any proposals were finalized and minimum delay has passed
            if (finalizedCount == 0) {
                require(
                    _input.checkpoint.blockNumber == 0 && _input.checkpoint.blockHash == 0
                        && _input.checkpoint.stateRoot == 0,
                    InvalidCheckpoint()
                );
            } else {
                // Validate and checkpoint
                bytes32 checkpointHash = H.hashCheckpoint(_input.checkpoint);
                require(
                    checkpointHash == _input.transitions[lastFinalizedIdx].checkpointHash,
                    CheckpointMismatch()
                );

                if (coreState_.finalizationHead > coreState_.synchronizationHead + _minSyncDelay) {
                    _syncToLayer2(_input.checkpoint, coreState_);
                }
            }
        }
    }

    /// @dev Syncs checkpoint to L1 storage and signals bond instruction changes to L2.
    ///      Rate-limited by minSyncDelay to reduce SSTORE operations.
    ///      When sync occurs:
    ///      1. Updates lastSyncTimestamp in core state
    ///      2. Validates and persists checkpoint to checkpoint store
    ///      3. If bond instructions changed, sends signal to L2 via signal service
    /// @param _checkpoint The checkpoint data to persist
    /// @param _coreState Core state to update (synchronizationHead, aggregatedBondInstructionsHash)
    function _syncToLayer2(
        ICheckpointStore.Checkpoint memory _checkpoint,
        CoreState memory _coreState
    )
        private
    {
        unchecked {
            _checkpointStore.saveCheckpoint(_checkpoint);

            // Signal bond instruction changes to L2 if any occurred
            if (_coreState.aggregatedBondInstructionsHash != 0) {
                BondInstructionMessage memory message = BondInstructionMessage({
                    firstProposalId: _coreState.synchronizationHead + 1,
                    lastProposalId: _coreState.finalizationHead,
                    aggregatedBondInstructionsHash: _coreState.aggregatedBondInstructionsHash
                });
                _signalService.sendSignal(H.hashBondInstructionMessage(message));
                _coreState.aggregatedBondInstructionsHash = 0;
            }

            _coreState.synchronizationHead = _coreState.finalizationHead;
        }
    }

    // ---------------------------------------------------------------
    // Private Functions - Proving Flow
    // ---------------------------------------------------------------

    /// @notice Calculates bond instructions based on proof timing and prover identity
    /// @dev Bond instruction rules:
    ///         - On-time (within provingWindow): No bond changes
    ///         - Late (within extendedProvingWindow): Liveness bond transfer if prover differs from
    ///           designated
    ///         - Very late (after extendedProvingWindow): Provability bond transfer if prover
    ///           differs from proposer
    /// @param _input The prove input
    /// @return bondInstructions_ Array of bond transfer instructions (empty if on-time or same
    /// prover)
    function _calculateBondInstructions(ProveInput memory _input)
        private
        view
        returns (LibBonds.BondInstruction[] memory bondInstructions_)
    {
        unchecked {
            uint256 windowEnd = _input.proposal.timestamp + _provingWindow;
            if (block.timestamp <= windowEnd) return new LibBonds.BondInstruction[](0);

            uint256 extendedWindowEnd = _input.proposal.timestamp + _extendedProvingWindow;
            bool isWithinExtendedWindow = block.timestamp <= extendedWindowEnd;

            bool needsBondInstruction = isWithinExtendedWindow
                ? (_input.metadata.actualProver != _input.metadata.designatedProver)
                : (_input.metadata.actualProver != _input.proposal.proposer);

            if (!needsBondInstruction) return new LibBonds.BondInstruction[](0);

            bondInstructions_ = new LibBonds.BondInstruction[](1);
            bondInstructions_[0] = LibBonds.BondInstruction({
                proposalId: _input.proposal.id,
                bondType: isWithinExtendedWindow
                    ? LibBonds.BondType.LIVENESS
                    : LibBonds.BondType.PROVABILITY,
                payer: isWithinExtendedWindow
                    ? _input.metadata.designatedProver
                    : _input.proposal.proposer,
                payee: _input.metadata.actualProver
            });
        }
    }

    /// @dev Stores transition record hash with optimized slot reuse.
    /// Detects duplicate and conflicting transition records.
    /// On conflict, stores the new transitionHash but sets timestamp to max
    /// to block finalization until the conflict is resolved.
    /// @param _proposalId The proposal ID
    /// @param _parentTransitionHash Parent transition hash used as part of the key
    /// @param _record The finalization metadata to persist
    function _storeTransitionRecord(
        uint40 _proposalId,
        bytes27 _parentTransitionHash,
        TransitionRecord memory _record
    )
        private
    {
        FirstTransitionStorage storage firstStorage =
            _firstTransitionStorages[_proposalId % _ringBufferSize];

        if (firstStorage.proposalId != _proposalId) {
            // New proposal, overwrite slot
            firstStorage.proposalId = _proposalId;
            firstStorage.parentTransitionHash = _parentTransitionHash;
            firstStorage.record = _record;
        } else if (firstStorage.parentTransitionHash == _parentTransitionHash) {
            _writeOrDetectConflict(_proposalId, _parentTransitionHash, firstStorage.record, _record);
        } else {
            _writeOrDetectConflict(
                _proposalId,
                _parentTransitionHash,
                _transitionRecordFor(_proposalId, _parentTransitionHash),
                _record
            );
        }
    }

    /// @dev Writes a new transition record or detects duplicate/conflict.
    /// On conflict, stores the new transitionHash but sets timestamp to max.
    /// @param _proposalId The proposal ID for event emission
    /// @param _parentTransitionHash The parent transition hash for event emission
    /// @param _existingRecord Storage pointer to the existing transition record
    /// @param _newRecord The new transition record to write
    function _writeOrDetectConflict(
        uint40 _proposalId,
        bytes27 _parentTransitionHash,
        TransitionRecord storage _existingRecord,
        TransitionRecord memory _newRecord
    )
        private
    {
        bytes27 existingHash = _existingRecord.transitionHash;

        if (existingHash == 0) {
            _existingRecord.transitionHash = _newRecord.transitionHash;
            _existingRecord.timestamp = _newRecord.timestamp;
        } else if (existingHash == _newRecord.transitionHash) {
            emit DuplicateTransitionSkipped(_proposalId, _parentTransitionHash);
        } else {
            // Conflict: use new transitionHash but set timestamp to max to block finalization
            emit ConflictingTransitionDetected(
                _proposalId, _parentTransitionHash, existingHash, _newRecord.transitionHash
            );
            _existingRecord.transitionHash = _newRecord.transitionHash;
            _existingRecord.timestamp = type(uint40).max;
        }
    }

    // ---------------------------------------------------------------
    // Private Functions - Storage Access
    // ---------------------------------------------------------------

    /// @dev Loads proposal hash from storage.
    /// @param _proposalId The proposal identifier.
    /// @return proposalHash_ The proposal hash.
    function _loadProposalHash(uint40 _proposalId) private view returns (bytes32 proposalHash_) {
        return _proposalHashes[_proposalId % _ringBufferSize];
    }

    /// @dev Optimized retrieval using ring buffer with collision detection.
    ///      Lookup strategy (gas-optimized order):
    ///      1. Ring buffer slot lookup (single SLOAD).
    ///      2. Proposal ID verification (cached in memory).
    ///      3. Parent hash comparison (single comparison).
    ///      4. Fallback to composite key mapping (most expensive).
    /// @param _proposalId The proposal ID to look up
    /// @param _parentTransitionHash Parent transition hash for verification
    /// @return record_ The transition record metadata.
    function _loadTransitionRecord(
        uint40 _proposalId,
        bytes27 _parentTransitionHash
    )
        private
        view
        returns (TransitionRecord memory record_)
    {
        FirstTransitionStorage storage firstStorage =
            _firstTransitionStorages[_proposalId % _ringBufferSize];

        if (firstStorage.proposalId != _proposalId) {
            return TransitionRecord({ transitionHash: 0, timestamp: 0 });
        } else if (firstStorage.parentTransitionHash == _parentTransitionHash) {
            return firstStorage.record;
        } else {
            return _transitionRecordFor(_proposalId, _parentTransitionHash);
        }
    }

    /// @dev Validates proposal hash against stored value
    /// Reverts with ProposalHashMismatch if hashes don't match
    /// @param _proposal The proposal to validate
    /// @return proposalHash_ The computed hash of the proposal
    function _checkProposalHash(Proposal memory _proposal)
        private
        view
        returns (bytes32 proposalHash_)
    {
        proposalHash_ = H.hashProposal(_proposal);
        bytes32 storedProposalHash = _loadProposalHash(_proposal.id);
        require(proposalHash_ == storedProposalHash, ProposalHashMismatch());
    }

    function _transitionRecordFor(
        uint40 _proposalId,
        bytes27 _parentTransitionHash
    )
        private
        view
        returns (TransitionRecord storage)
    {
        bytes32 compositeKey = H.composeTransitionKey(_proposalId, _parentTransitionHash);
        return _transitionRecords[compositeKey];
    }

    // ---------------------------------------------------------------
    // Private Functions - Event Emission
    // ---------------------------------------------------------------

    /// @dev Emits a Proposed event when a new proposal is submitted.
    ///      Packs all proposal data into a ProposedEventPayload struct to avoid stack depth issues.
    /// @param _proposal The newly created proposal containing ID, timestamps, proposer, and hashes
    /// @param _derivation The derivation data specifying origin block and data sources
    /// @param _coreState The updated core state after this proposal
    function _emitProposedEvent(
        Proposal memory _proposal,
        Derivation memory _derivation,
        CoreState memory _coreState,
        Transition[] memory _transitions
    )
        private
    {
        ProposedEventPayload memory payload = ProposedEventPayload({
            proposal: _proposal,
            derivation: _derivation,
            coreState: _coreState,
            transitions: _transitions
        });
        emit Proposed(_proposal.id, LibProposedEventCodec.encode(payload));
    }

    /// @dev Emits a Proved event when a transition proof is submitted.
    ///      Contains all data needed by off-chain indexers to track proof status.
    /// @param _input The prove input
    /// @param _bondInstructions Calculated bond instructions for the proven proposals
    function _emitProvedEvent(
        ProveInput memory _input,
        LibBonds.BondInstruction[] memory _bondInstructions
    )
        private
    {
        ProvedEventPayload memory payload = ProvedEventPayload({
            checkpoint: _input.checkpoint, bondInstructions: _bondInstructions
        });
        emit Proved(
            _input.proposal.id, _input.parentTransitionHash, LibProvedEventCodec.encode(payload)
        );
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ActivationPeriodExpired();
    error CannotProposeInCurrentBlock();
    error CheckpointMismatch();
    error DeadlineExceeded();
    error EmptyProposals();
    error EmptyProveInputs();
    error IncorrectTransitionCount();
    error InvalidCheckpoint();
    error InvalidLastPacayaBlockHash();
    error InvalidLastProposalProof();
    error InvalidState();
    error MissingProofProposal();
    error NextProposalHashMismatch();
    error NoProposalExists();
    error NoCapacity();
    error ProposalHashMismatch();
    error RingBufferSizeZero();
    error TooManyProofProposals();
    error TransitionCoolingDown();
    error TransitionHashMismatchWithStorage();
    error TransitionNotProvided();
    error UnprocessedForcedInclusionIsDue();
}
