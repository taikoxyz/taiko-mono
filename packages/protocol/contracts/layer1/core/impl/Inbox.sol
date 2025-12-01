// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBondInstruction } from "../libs/LibBondInstruction.sol";
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { LibHashSimple } from "../libs/LibHashSimple.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

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
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    uint256 private constant ACTIVATION_WINDOW = 2 hours;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Result from consuming forced inclusions
    struct ConsumptionResult {
        IInbox.DerivationSource[] sources;
        bool allowsPermissionless;
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

    /// @notice The token used for bonds.
    IERC20 internal immutable _bondToken;

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

    /// @notice Checkpoint store responsible for checkpoints
    ICheckpointStore internal immutable _checkpointStore;

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
        require(_config.checkpointStore != address(0), ZERO_ADDRESS());
        require(_config.ringBufferSize != 0, RingBufferSizeZero());

        _codec = _config.codec;
        _bondToken = IERC20(_config.bondToken);
        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _proposerChecker = IProposerChecker(_config.proposerChecker);
        _checkpointStore = ICheckpointStore(_config.checkpointStore);
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
                block.timestamp <= ACTIVATION_WINDOW + activationTimestamp,
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
            ProposeInput memory input = _decodeProposeInput(_data);
            _validateProposeInput(input);

            // TODO: only load the necessary fields
            CoreState memory state = _state;
            require(state.nextProposalId != 0, ActivationRequired());
            // Enforce one propose call per Ethereun block to prevent span attacks that could
            // deplete the ring buffer
            require(block.number > state.lastProposalBlockId, CannotProposeInCurrentBlock());
            require(_getAvailableCapacity(state) > 0, NotEnoughCapacity());

            // Consume forced inclusions (validation happens inside)
            ConsumptionResult memory result =
                _consumeForcedInclusions(msg.sender, input.numForcedInclusions);

            // Add normal proposal source in last slot
            result.sources[result.sources.length - 1] =
                DerivationSource(false, LibBlobs.validateBlobReference(input.blobReference));

            // If forced inclusion is old enough, allow anyone to propose
            // and set endOfSubmissionWindowTimestamp = 0
            // Otherwise, only the current preconfer can propose
            uint48 endOfSubmissionWindowTimestamp = result.allowsPermissionless
                ? 0
                : _proposerChecker.checkProposer(msg.sender, _lookahead);

            // Create single proposal with multi-source derivation
            // Use previous block as the origin for the proposal to be able to call `blockhash`
            uint256 parentBlockNumber = block.number - 1;
            Derivation memory derivation = Derivation({
                originBlockNumber: uint48(parentBlockNumber),
                originBlockHash: blockhash(parentBlockNumber),
                basefeeSharingPctg: _basefeeSharingPctg,
                sources: result.sources
            });

            uint48 proposalId = state.nextProposalId;
            state.nextProposalId = proposalId + 1;
            state.lastProposalBlockId = uint48(block.number);

            Proposal memory proposal = Proposal({
                id: proposalId,
                timestamp: uint48(block.timestamp),
                endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
                proposer: msg.sender,
                coreStateHash: _hashCoreState(state),
                derivationHash: _hashDerivation(derivation)
            });

            _state = state;
            _setProposalHash(proposal.id, _hashProposal(proposal));
            _emitProposedEvent(proposal, derivation, state);
        }
    }

    /// @inheritdoc IInbox
    /// @notice Proves the validity of proposed L2 blocks and finalizes them in-order.
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        // Decode and validate input
        ProveInput memory input = _decodeProveInput(_data);
        require(input.proposals.length != 0, EmptyProposals());
        require(input.proposals.length == input.transitions.length, InconsistentParams());
        require(input.transitions.length == input.metadata.length, InconsistentParams());

        CoreState memory newState;
        TransitionRecord memory record;
        LibBonds.BondInstruction[] memory bondInstructions;
        uint48 firstReadyTimestamp;
        (newState, record, bondInstructions, firstReadyTimestamp) =
            _processProof(_state, input);

        uint256 proposalAge;
        if (input.proposals.length == 1) {
            proposalAge = block.timestamp - uint256(firstReadyTimestamp);
        }

        bytes32 aggregatedProvingHash =
            _hashTransitionsWithMetadata(input.transitions, input.metadata);

        _state = newState;
        record.bondInstructions = bondInstructions;

        _proofVerifier.verifyProof(proposalAge, aggregatedProvingHash, _proof);


        // TODO: Needs attention
        ProvedEventPayload memory payload = ProvedEventPayload({
            proposalId: input.proposals[0].id,
            transition: input.transitions[0],
            transitionRecord: record,
            metadata: input.metadata[0],
            coreState: newState
        });
        emit Proved(_encodeProvedEventData(payload));
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
    /// @param _proposalId The ID of the proposal to query
    /// @return proposalHash_ The keccak256 hash of the Proposal struct at the ring buffer slot
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_) {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        proposalHash_ = _proposalHashes[bufferSlot];
    }

    /// @inheritdoc IInbox
    function getConfig() external view returns (IInbox.Config memory config_) {
        config_ = IInbox.Config({
            bondToken: address(_bondToken),
            checkpointStore: address(_checkpointStore),
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
        state.lastFinalizedTransitionHash = _hashTransition(transition);

        Proposal memory proposal;
        proposal.coreStateHash = _hashCoreState(state);

        Derivation memory derivation;
        proposal.derivationHash = _hashDerivation(derivation);

        _state = state;
        _setProposalHash(0, _hashProposal(proposal));

        _emitProposedEvent(proposal, derivation, state);
    }

    /// @dev Processes sequential proofs, updates state, and builds the transition record.
    /// @param _stateBefore The state before the proof is processed
    /// @param _input The input containing the proposals, transitions, and metadata
    /// @return newState_ The new state after the proof is processed
    /// @return record_ The transition record containing the span, bond instructions, and hashes
    /// @return bondInstructions_ The bond instructions for the proof
    /// @return firstReadyTimestamp_ The timestamp of the first ready proposal
    function _processProof(CoreState memory _stateBefore, ProveInput memory _input)
        private
        returns (
            CoreState memory newState_,
            TransitionRecord memory record_,
            LibBonds.BondInstruction[] memory bondInstructions_,
            uint48 firstReadyTimestamp_
        )
    {
        unchecked {
            newState_ = _stateBefore;

            // The expected ID of the first proposal to be proven
            uint48 expectedId = _stateBefore.lastFinalizedProposalId + 1;
            bytes32 parentHash = _stateBefore.lastFinalizedTransitionHash;
            uint48 priorFinalizedTimestamp = _stateBefore.lastFinalizedTimestamp;
            uint256 instructionCount;

            // One bond instruction at most per proposal
            bondInstructions_ = new LibBonds.BondInstruction[](_input.proposals.length);

            uint256 count = _input.proposals.length;

            //TODO: Should we keep this restriction of span being a `uint8` now that is  not stored?
            // Limit the amount of proofs to 255 to avoid span overflow
            require(count <= type(uint8).max, SpanOutOfBounds());
            record_.span = uint8(count);

            for (uint256 i; i < count; ++i) {
                Proposal memory proposal = _input.proposals[i];
                require(proposal.id == expectedId, InvalidProposalId());

                bytes32 proposalHash = _checkProposalHash(proposal);
                Transition memory transition = _input.transitions[i];
                require(proposalHash == transition.proposalHash, ProposalHashMismatchWithTransition());
                require(transition.parentTransitionHash == parentHash, InvalidParentTransition());

                uint48 readyTimestamp = _computeReadyTimestamp(proposal.timestamp, priorFinalizedTimestamp);
                if (i == 0) {
                    firstReadyTimestamp_ = readyTimestamp;
                    // After the first proposal, all subsequent proposals in this batch
                    // have their parent finalized at block.timestamp
                    priorFinalizedTimestamp = uint48(block.timestamp);
                }

                // TODO: The way we are calculating and merging bond instructions seems very wasteful now
                LibBonds.BondInstruction[] memory instructions =
                    LibBondInstruction.calculateBondInstructions(
                        _provingWindow, _extendedProvingWindow, proposal, _input.metadata[i], readyTimestamp
                    );

                if (instructions.length != 0) {
                    bondInstructions_[instructionCount] = instructions[0];
                    newState_.bondInstructionsHash = LibBonds.aggregateBondInstruction(
                        newState_.bondInstructionsHash, instructions[0]
                    );
                    ++instructionCount;
                }

                parentHash = _hashTransition(transition);
                ++expectedId;
            }

            if (instructionCount != bondInstructions_.length) {
                LibBonds.BondInstruction[] memory trimmed =
                    new LibBonds.BondInstruction[](instructionCount);
                for (uint256 i; i < instructionCount; ++i) {
                    trimmed[i] = bondInstructions_[i];
                }
                bondInstructions_ = trimmed;
            }

            newState_.lastFinalizedProposalId = expectedId - 1;
            newState_.lastFinalizedTransitionHash = parentHash;
            newState_.lastFinalizedTimestamp = uint48(block.timestamp);

            bytes32 checkpointHash =
                _hashCheckpoint(_input.transitions[_input.transitions.length - 1].checkpoint);
            _syncCheckpointIfNeeded(_input.checkpoint, checkpointHash, newState_);

            record_.transitionHash = parentHash;
            record_.checkpointHash = checkpointHash;
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
    function _computeReadyTimestamp(uint48 _proposalTimestamp, uint48 _priorFinalizedTimestamp)
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
        proposalHash_ = _hashProposal(_proposal);
        bytes32 storedProposalHash = _proposalHashes[_proposal.id % _ringBufferSize];
        require(proposalHash_ == storedProposalHash, ProposalHashMismatch());
    }

    /// @dev Encodes the proposed event data
    /// @param _payload The ProposedEventPayload object
    /// @return The encoded data
    function _encodeProposedEventData(ProposedEventPayload memory _payload)
        internal
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(_payload);
    }

    /// @dev Encodes the proved event data
    /// @param _payload The ProvedEventPayload object
    /// @return The encoded data
    function _encodeProvedEventData(ProvedEventPayload memory _payload)
        internal
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(_payload);
    }

    /// @dev Decodes proposal input data
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput struct containing all proposal data
    function _decodeProposeInput(bytes calldata _data)
        internal
        pure
        virtual
        returns (ProposeInput memory)
    {
        return abi.decode(_data, (ProposeInput));
    }

    /// @dev Decodes prove input data
    /// @param _data The encoded data
    /// @return _ The decoded ProveInput struct containing proposals and transitions
    function _decodeProveInput(bytes calldata _data)
        internal
        pure
        virtual
        returns (ProveInput memory)
    {
        return abi.decode(_data, (ProveInput));
    }

    /// @dev Hashes a Checkpoint struct.
    /// @param _checkpoint The checkpoint to hash.
    /// @return _ The hash of the checkpoint.
    function _hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        view
        virtual
        returns (bytes32)
    {
        return LibHashSimple.hashCheckpoint(_checkpoint);
    }

    /// @dev Hashes a CoreState struct.
    /// @param _coreState The core state to hash.
    /// @return _ The hash of the core state.
    function _hashCoreState(CoreState memory _coreState) internal view virtual returns (bytes32) {
        return LibHashSimple.hashCoreState(_coreState);
    }

    /// @dev Hashes a Derivation struct.
    /// @param _derivation The derivation to hash.
    /// @return _ The hash of the derivation.
    function _hashDerivation(Derivation memory _derivation)
        internal
        view
        virtual
        returns (bytes32)
    {
        return LibHashSimple.hashDerivation(_derivation);
    }

    /// @dev Hashes a Proposal struct.
    /// @param _proposal The proposal to hash.
    /// @return _ The hash of the proposal.
    function _hashProposal(Proposal memory _proposal) internal view virtual returns (bytes32) {
        return LibHashSimple.hashProposal(_proposal);
    }

    /// @dev Hashes a Transition struct.
    /// @param _transition The transition to hash.
    /// @return _ The hash of the transition.
    function _hashTransition(Transition memory _transition)
        internal
        view
        virtual
        returns (bytes32)
    {
        return LibHashSimple.hashTransition(_transition);
    }

    /// @dev Hashes a TransitionRecord struct.
    /// @param _transitionRecord The transition record to hash.
    /// @return _ The hash of the transition record.
    function _hashTransitionRecord(TransitionRecord memory _transitionRecord)
        internal
        view
        virtual
        returns (bytes26)
    {
        return LibHashSimple.hashTransitionRecord(_transitionRecord);
    }

    /// @dev Hashes an array of Transitions.
    /// @param _transitions The transitions array to hash.
    /// @param _metadata The metadata array to hash.
    /// @return _ The hash of the transitions array.
    function _hashTransitionsWithMetadata(
        Transition[] memory _transitions,
        TransitionMetadata[] memory _metadata
    )
        internal
        view
        virtual
        returns (bytes32)
    {
        return LibHashSimple.hashTransitionsWithMetadata(_transitions, _metadata);
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
        Derivation memory _derivation,
        CoreState memory _coreState
    )
        private
    {
        ProposedEventPayload memory payload = ProposedEventPayload({
            proposal: _proposal,
            derivation: _derivation,
            coreState: _coreState
        });
        emit Proposed(_encodeProposedEventData(payload));
    }

    /// @dev Syncs checkpoint to storage when voluntary or forced sync conditions are met.
    /// @param _checkpoint The checkpoint data to sync.
    /// @param _expectedCheckpointHash The expected hash to validate against.
    /// @param _coreState Core state to update with new checkpoint timestamp.
    function _syncCheckpointIfNeeded(
        ICheckpointStore.Checkpoint memory _checkpoint,
        bytes32 _expectedCheckpointHash,
        CoreState memory _coreState
    )
        private
    {
        if (_checkpoint.blockHash != 0) {
            bytes32 checkpointHash = _hashCheckpoint(_checkpoint);
            require(checkpointHash == _expectedCheckpointHash, CheckpointMismatch());

            _checkpointStore.saveCheckpoint(_checkpoint);
            _coreState.lastCheckpointTimestamp = uint48(block.timestamp);
        } else {
            require(
                block.timestamp < _coreState.lastCheckpointTimestamp + _minCheckpointDelay,
                CheckpointNotProvided()
            );
        }
    }

    /// @dev Calculates remaining capacity for new proposals
    /// Subtracts unfinalized proposals from total capacity
    /// @param _coreState Current state with proposal counters
    /// @return _ Number of additional proposals that can be submitted
    function _getAvailableCapacity(CoreState memory _coreState) private view returns (uint256) {
        unchecked {
            uint256 numUnfinalizedProposals =
                _coreState.nextProposalId - _coreState.lastFinalizedProposalId - 1;
            return _ringBufferSize - 1 - numUnfinalizedProposals;
        }
    }

    /// @dev Validates propose function inputs
    /// @param _input The ProposeInput to validate
    function _validateProposeInput(ProposeInput memory _input) private view {
        require(_input.deadline == 0 || block.timestamp <= _input.deadline, DeadlineExceeded());
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ActivationPeriodExpired();
    error ActivationRequired();
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
    error SpanOutOfBounds();
    error UnprocessedForcedInclusionIsDue();
}
