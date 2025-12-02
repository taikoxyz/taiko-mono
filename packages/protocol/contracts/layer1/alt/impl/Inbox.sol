// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBondInstruction } from "../libs/LibBondInstruction.sol";
import { LibHashOptimized } from "../libs/LibHashOptimized.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";
import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { IProposerChecker2 } from "src/layer1/core/iface/IProposerChecker.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibForcedInclusion } from "src/layer1/core/libs/LibForcedInclusion.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

import "src/layer1/alt/impl/Inbox_Layout.sol"; // DO NOT DELETE

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

    /// @dev Stores the first transition record for each proposal to reduce gas costs.
    ///      Uses a ring buffer pattern with proposal ID modulo ring buffer size.
    ///      Uses multiple storage slots for the struct (48 + 26*8 + 26 + 48 = 304 bits)
    struct FirstTransitionRecord {
        uint48 proposalId;
        bytes26 partialParentTransitionHash;
        TransitionRecord record;
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
    IProposerChecker2 internal immutable _proposerChecker;

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

    /// @notice The minimum delay between syncs in seconds.
    uint16 internal immutable _minSyncDelay;

    /// @notice The multiplier to determine when a forced inclusion is too old so that proposing
    /// becomes permissionless
    uint8 internal immutable _permissionlessInclusionMultiplier;

    uint8 internal immutable _maxHeadForwardingCount;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The timestamp when the first activation occurred.
    uint40 public activationTimestamp;

    /// @dev Ring buffer for storing proposal hashes indexed by buffer slot
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - proposalHash: The keccak256 hash of the Proposal struct
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev Simple mapping for storing transition record hashes
    /// @dev We do not use a ring buffer for this mapping, since a nested mapping does not benefit
    /// from it
    /// @dev Stores transition records for proposals with different parent transitions
    /// - compositeKey: Keccak256 hash of (proposalId, parentTransitionHash)
    /// - value: The struct contains the finalization deadline and the hash of the Transition
    mapping(bytes32 compositeKey => TransitionRecord record) internal _records;

    /// @dev Storage for forced inclusion requests
    /// @dev 2 slots used
    LibForcedInclusion.Storage private _forcedInclusionStorage;

    /// @dev Storage for default transition records to optimize gas usage
    /// @notice Stores one transition record per buffer slot for gas optimization
    /// @dev Ring buffer implementation with collision handling that falls back to the composite key
    /// mapping from the parent contract
    mapping(uint256 bufferSlot => FirstTransitionRecord firstRecord) internal
        _firstTransitionRecords;

    uint256[36] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    /// @param _config Configuration struct containing all constructor parameters
    constructor(IInbox.Config memory _config) {
        require(_config.checkpointStore != address(0), ZERO_ADDRESS());
        require(_config.ringBufferSize != 0, RingBufferSizeZero());

        _codec = _config.codec;
        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _proposerChecker = IProposerChecker2(_config.proposerChecker);
        _checkpointStore = ICheckpointStore(_config.checkpointStore);
        _signalService = ISignalService(_config.signalService);
        _provingWindow = _config.provingWindow;
        _extendedProvingWindow = _config.extendedProvingWindow;
        _maxFinalizationCount = _config.maxFinalizationCount;
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
    /// @notice Proposes new L2 blocks and forced inclusions to the rollup using blobs for DA.
    /// @dev Key behaviors:
    ///      1. Validates proposer authorization via `IProposerChecker`
    ///      2. Finalizes eligible proposals up to `config.maxFinalizationCount` to free ring buffer
    ///         space.
    ///      3. Process `input.numForcedInclusions` forced inclusions. The proposer is forced to
    ///         process at least `config.minForcedInclusionCount` if they are due.
    ///      4. Updates core state and emits `Proposed` event
    /// NOTE: This function can only be called once per block to prevent spams that can fill the ring buffer.
    function propose(bytes calldata _lookahead, bytes calldata _data) external nonReentrant {
        unchecked {
            // Decode and validate input data
            ProposeInput memory input = _decodeProposeInput(_data);

            // Validate proposal input data
            require(input.deadline == 0 || block.timestamp <= input.deadline, DeadlineExceeded());

            // Enforce one propose call per Ethereum block to prevent spam attacks that could
            // deplete the ring buffer
            require(
                block.number > input.coreState.lastProposalBlockId, CannotProposeInCurrentBlock()
            );

            // Verify parentProposals[0] is the last proposal stored on-chain.
            bytes32 headProposalHash = _verifyHeadProposal(input.headProposalAndProof);

            require(
                _hashCoreState(input.coreState) == input.headProposalAndProof[0].coreStateHash,
                InvalidState()
            );

            // Finalize proposals before proposing a new one to free ring buffer space and prevent deadlock
            (CoreState memory coreState, LibBonds.BondInstruction[] memory bondInstructions) =
                _finalize(input);

            coreState.lastProposalBlockId = uint40(block.number);

            // Verify capacity for new proposals
            require(_getAvailableCapacity(coreState) > 0, NotEnoughCapacity());

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

            // Increment nextProposalId (lastProposalBlockId was already set above)
            Proposal memory proposal = Proposal({
                id: coreState.nextProposalId++,
                timestamp: uint40(block.timestamp),
                endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
                proposer: msg.sender,
                coreStateHash: _hashCoreState(coreState),
                derivationHash: _hashDerivation(derivation),
                parentProposalHash: headProposalHash
            });

            _proposalHashes[proposal.id % _ringBufferSize] = _hashProposal(proposal);
            _emitProposedEvent(proposal, derivation, coreState, bondInstructions);
        }
    }

    /// @inheritdoc IInbox
    /// @notice Proves the validity of proposed L2 blocks
    /// @dev Validates transitions, calculates bond instructions, and verifies proofs
    /// NOTE: this function sends the proposal age to the proof verifier when proving a single proposal.
    /// This can be used by the verifier system to change its behavior
    /// if the proposal is too old(e.g. this can serve as a signal that a prover killer proposal was produced)
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        unchecked {
            ProveInput[] memory inputs = _decodeProveInput(_data);
            require(inputs.length != 0, EmptyProveInputs());
            uint40 finalizationDeadline = uint40(block.timestamp + _finalizationGracePeriod);

            ProveInput memory input;

            for (uint256 i; i < inputs.length; ++i) {
                input = inputs[i];
                _checkProposalHash(input.proposal);

                LibBonds.BondInstruction[] memory bondInstructions =
                    LibBondInstruction.calculateBondInstructions(
                        _provingWindow,
                        _extendedProvingWindow,
                        input.proposal.id,
                        input.proofMetadata
                    );
                Transition memory transition = Transition({
                    bondInstructionsHash: _hashBondInstructionArray(bondInstructions),
                    checkpointHash: _hashCheckpoint(input.checkpoint)
                });

                TransitionRecord memory record = TransitionRecord({
                    transitionHash: _hashTransition(transition),
                    finalizationDeadline: finalizationDeadline
                });


                _storeTransitionRecord(input.proposal.id, input.parentTransitionHash, record);

                _emitProvedEvent(
                    input,
                    finalizationDeadline,
                    bondInstructions
                );
            }

            uint256 proposalAge;
            if (inputs.length == 1) {
                proposalAge = block.timestamp - inputs[0].proposal.timestamp;
            }

            _proofVerifier.verifyProof(proposalAge, _hashProveInputArray(inputs), _proof);
        }
    }

    /// @dev Stores transition record hash with optimized slot reuse.
    ///      Storage strategy:
    ///      1. New proposal ID: overwrite the reusable slot.
    ///      2. Same ID and parent: update accordingly.
    ///      3. Same ID but different parent: fall back to the composite key mapping.
    /// @param _startProposalId The proposal ID for this transition record
    /// @param _parentTransitionHash Parent transition hash used as part of the key
    /// @param _record The finalization metadata to persist
    function _storeTransitionRecord(
        uint48 _startProposalId,
        bytes32 _parentTransitionHash,
        TransitionRecord memory _record
    )
        internal
    {
        FirstTransitionRecord storage firstRecord =
            _firstTransitionRecords[_startProposalId % _ringBufferSize];
        // Truncation keeps 208 bits of Keccak security; practical collision risk within the proving
        // horizon is negligible.
        // See ../../../docs/analysis/InboxOptimized1-bytes26-Analysis.md for detailed analysis
        bytes26 partialParentHash = bytes26(_parentTransitionHash);

        if (firstRecord.proposalId != _startProposalId) {
            // New proposal, overwrite slot
            firstRecord.proposalId = _startProposalId;
            firstRecord.partialParentTransitionHash = partialParentHash;
            firstRecord.record = _record;
        } else if (firstRecord.partialParentTransitionHash != partialParentHash) {
            // Collision: fallback to composite key mapping
            TransitionRecord storage record = _recordFor(_startProposalId, _parentTransitionHash);

            if (record.transitionHash !=0) {
            record.transitionHash = _record.transitionHash;
            record.finalizationDeadline = _record.finalizationDeadline;
            }
        }
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
    function getProposalHash(uint40 _proposalId) external view returns (bytes32 proposalHash_) {
        return _loadProposalHash(_proposalId);
    }

    /// @notice Retrieves the transition record hash for a specific proposal and parent transition
    /// @param _proposalId The ID of the proposal containing the transition
    /// @param _parentTransitionHash The hash of the parent transition in the proof chain
    /// @return record_ The transition record metadata.
    function getTransitionRecord(
        uint40 _proposalId,
        bytes32 _parentTransitionHash
    )
        external
        view
        returns (TransitionRecord memory record_)
    {
        return _loadTransitionRecord(_proposalId, _parentTransitionHash);
    }

    /// @inheritdoc IInbox
    function getConfig() external view returns (IInbox.Config memory config_) {
        config_ = IInbox.Config({
            codec: _codec,
            proofVerifier: address(_proofVerifier),
            proposerChecker: address(_proposerChecker),
            checkpointStore: address(_checkpointStore),
            signalService: address(_signalService),
            provingWindow: _provingWindow,
            extendedProvingWindow: _extendedProvingWindow,
            maxFinalizationCount: _maxFinalizationCount,
            finalizationGracePeriod: _finalizationGracePeriod,
            ringBufferSize: _ringBufferSize,
            basefeeSharingPctg: _basefeeSharingPctg,
            minForcedInclusionCount: _minForcedInclusionCount,
            forcedInclusionDelay: _forcedInclusionDelay,
            forcedInclusionFeeInGwei: _forcedInclusionFeeInGwei,
            forcedInclusionFeeDoubleThreshold: _forcedInclusionFeeDoubleThreshold,
            minSyncDelay: _minSyncDelay,
            permissionlessInclusionMultiplier: _permissionlessInclusionMultiplier,
            maxHeadForwardingCount: _maxHeadForwardingCount
        });
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Activates the inbox with genesis state so that it can start accepting proposals.
    /// Sets up the initial proposal and core state with genesis block.
    /// Can be called multiple times to handle L1 reorgs or correct incorrect values.
    /// Resets state variables to allow fresh start.
    /// @param _lastPacayaBlockHash The hash of the last Pacaya block
    function _activateInbox(bytes32 _lastPacayaBlockHash) internal {
        ICheckpointStore.Checkpoint memory checkpoint;
        checkpoint.blockHash = _lastPacayaBlockHash;

        Transition memory transition;
        transition.checkpointHash = _hashCheckpoint(checkpoint);

        CoreState memory coreState;
        coreState.nextProposalId = 1;

        // Set lastProposalBlockId to 1 to ensure the first proposal happens at block 2 or later.
        // This prevents reading blockhash(0) in propose(), which would return 0x0 and create
        // an invalid origin block hash. The EVM hardcodes blockhash(0) to 0x0, so we must
        // ensure proposals never reference the genesis block.
        coreState.lastProposalBlockId = 1;
        coreState.lastFinalizedTransitionHash = _hashTransition(transition);

        Proposal memory proposal;
        proposal.coreStateHash = _hashCoreState(coreState);

        Derivation memory derivation;
        proposal.derivationHash = _hashDerivation(derivation);

        _proposalHashes[0] = _hashProposal(proposal);

        _emitProposedEvent(proposal, derivation, coreState, new LibBonds.BondInstruction[](0));
    }

    /// @dev Loads proposal hash from storage.
    /// @param _proposalId The proposal identifier.
    /// @return proposalHash_ The proposal hash.
    function _loadProposalHash(uint48 _proposalId) internal view returns (bytes32 proposalHash_) {
        return _proposalHashes[_proposalId % _ringBufferSize];
    }

    /// @dev Optimized retrieval using ring buffer with collision detection.
    ///      Lookup strategy (gas-optimized order):
    ///      1. Ring buffer slot lookup (single SLOAD).
    ///      2. Proposal ID verification (cached in memory).
    ///      3. Partial parent hash comparison (single comparison).
    ///      4. Fallback to composite key mapping (most expensive).
    /// @param _proposalId The proposal ID to look up
    /// @param _parentTransitionHash Parent transition hash for verification
    /// @return record_ The transition record metadata.
    function _loadTransitionRecord(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        returns (TransitionRecord memory record_)
    {
        FirstTransitionRecord storage firstRecord =
            _firstTransitionRecords[_proposalId % _ringBufferSize];

        if (firstRecord.proposalId != _proposalId) {
            return TransitionRecord({ transitionHash: 0, finalizationDeadline: 0 });
        } else if (firstRecord.partialParentTransitionHash == bytes26(_parentTransitionHash)) {
            return firstRecord.record;
        } else {
            return _recordFor(_proposalId, _parentTransitionHash);
        }
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
        bytes32 storedProposalHash = _loadProposalHash(_proposal.id);
        require(proposalHash_ == storedProposalHash, ProposalHashMismatch());
    }

    /// @dev Computes composite key for transition record storage
    /// Creates unique identifier for proposal-parent transition pairs
    /// @param _proposalId The ID of the proposal
    /// @param _parentTransitionHash Hash of the parent transition
    /// @return _ Keccak256 hash of encoded parameters
    function _composeTransitionKey(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        pure
        returns (bytes32)
    {
        return LibHashOptimized.composeTransitionKey(_proposalId, _parentTransitionHash);
    }

    // ---------------------------------------------------------------
    // Encoder and Decoder Functions
    // ---------------------------------------------------------------

    /// @dev Encodes the proposed event data
    /// @param _payload The ProposedEventPayload object
    /// @return The encoded data
    function _encodeProposedEventData(ProposedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory)
    {
        return LibProposedEventEncoder.encode(_payload);
    }

    /// @dev Encodes the proved event data
    /// @param _payload The ProvedEventPayload object
    /// @return The encoded data
    function _encodeProvedEventData(ProvedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory)
    {
        return LibProvedEventEncoder.encode(_payload);
    }

    /// @dev Decodes proposal input data
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput struct containing all proposal data
    function _decodeProposeInput(bytes calldata _data) internal pure returns (ProposeInput memory) {
        return LibProposeInputDecoder.decode(_data);
    }

    /// @dev Decodes prove input data
    /// @param _data The encoded data
    /// @return _ The decoded ProveInput struct containing proposals and transitions
    function _decodeProveInput(bytes calldata _data) internal pure returns (ProveInput[] memory) {
        return LibProveInputDecoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // Singular Hashing Functions (synced with LibHashOptimized order)
    // ---------------------------------------------------------------

    /// @dev Hashes a Checkpoint struct.
    /// @param _checkpoint The checkpoint to hash.
    /// @return _ The hash of the checkpoint.
    function _hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashCheckpoint(_checkpoint);
    }

    /// @dev Hashes a CoreState struct.
    /// @param _coreState The core state to hash.
    /// @return _ The hash of the core state.
    function _hashCoreState(CoreState memory _coreState) internal pure returns (bytes32) {
        return LibHashOptimized.hashCoreState(_coreState);
    }

    /// @dev Hashes a Derivation struct.
    /// @param _derivation The derivation to hash.
    /// @return _ The hash of the derivation.
    function _hashDerivation(Derivation memory _derivation) internal pure returns (bytes32) {
        return LibHashOptimized.hashDerivation(_derivation);
    }

    /// @dev Hashes a Proposal struct.
    /// @param _proposal The proposal to hash.
    /// @return _ The hash of the proposal.
    function _hashProposal(Proposal memory _proposal) internal pure returns (bytes32) {
        return LibHashOptimized.hashProposal(_proposal);
    }

    /// @dev Hashes a Transition struct.
    /// @param _transition The transition record to hash.
    /// @return _ The hash of the transition record.
    function _hashTransition(Transition memory _transition) internal pure returns (bytes26) {
        return LibHashOptimized.hashTransition(_transition);
    }

    /// @dev Hashes a BondInstructionHashChange struct.
    /// @param _hashChange The bond instruction hash change to hash.
    /// @return _ The hash of the bond instruction hash change.
    function _hashBondInstructionHashChange(BondInstructionHashChange memory _hashChange)
        internal
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashBondInstructionHashChange(_hashChange);
    }

    // ---------------------------------------------------------------
    // Array Hashing Functions (synced with LibHashOptimized order)
    // ---------------------------------------------------------------

    /// @dev Hashes blob hashes array.
    /// @param _blobHashes The blob hashes array to hash.
    /// @return _ The hash of the blob hashes array.
    function _hashBlobHashesArray(bytes32[] memory _blobHashes) internal pure returns (bytes32) {
        return LibHashOptimized.hashBlobHashesArray(_blobHashes);
    }

    /// @dev Hashes ProveInput array for proof verification.
    /// @param _inputs The prove inputs to hash.
    /// @return _ The hash of the prove inputs.
    function _hashProveInputArray(ProveInput[] memory _inputs) internal pure returns (bytes32) {
        return LibHashOptimized.hashProveInputArray(_inputs);
    }

    /// @dev Hashes bond instructions array.
    /// @param _bondInstructions The bond instructions to hash.
    /// @return _ The hash of the bond instructions.
    function _hashBondInstructionArray(LibBonds.BondInstruction[] memory _bondInstructions)
        internal
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashBondInstructionArray(_bondInstructions);
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
            uint256 toProcess = _numForcedInclusionsRequested.min(available);

            // Allocate array with extra slot for normal source
            result_.sources = new IInbox.DerivationSource[](toProcess + 1);

            // Process inclusions if any
            uint48 oldestTimestamp;
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
        IInbox.DerivationSource[] memory _sources,
        uint48 _head,
        uint48 _lastProcessedAt,
        uint256 _toProcess
    )
        private
        returns (uint48 oldestTimestamp_, uint48 head_, uint48 lastProcessedAt_)
    {
        if (_toProcess > 0) {
            // Process inclusions and accumulate fees
            uint256 totalFees;
            unchecked {
                for (uint256 i; i < _toProcess; ++i) {
                    IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[_head + i];
                    _sources[i] = IInbox.DerivationSource(true, inclusion.blobSlice);
                    totalFees += inclusion.feeInGwei;
                }
            }

            // Transfer accumulated fees
            if (totalFees > 0) {
                _feeRecipient.sendEtherAndVerify(totalFees * 1 gwei);
            }

            // Oldest timestamp is max of first inclusion timestamp and last processed time
            oldestTimestamp_ = uint40(_sources[0].blobSlice.timestamp.max(_lastProcessedAt));

            // Update queue position and last processed time
            head_ = _head + uint48(_toProcess);
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

    /// @dev Finalizes proven proposals and updates checkpoints with rate limiting.
    /// Checkpoints are only saved if minSyncDelay seconds have passed since the last save,
    /// reducing SSTORE operations but making L2 checkpoints less frequently available on L1.
    /// Set minSyncDelay to 0 to disable rate limiting.
    /// @param _input Contains transition records and the end block header.
    /// @return coreState_ Updated core state with new finalization counters.
    /// @return bondInstructions_ Array of bond instructions from finalized proposals.
    function _finalize(ProposeInput memory _input)
        private
        returns (CoreState memory coreState_, LibBonds.BondInstruction[] memory bondInstructions_)
    {
        unchecked {
            CoreState memory coreState = _input.coreState;
            uint40 proposalId = coreState.lastFinalizedProposalId + 1;
            uint256 lastFinalizedIdx;
            uint256 finalizedCount;
            uint256 transitionCount = _input.transitions.length;

            for (uint256 i; i < _maxFinalizationCount; ++i) {
                // Check if there are more proposals to finalize
                if (proposalId >= coreState.nextProposalId) break;

                // Try to finalize the current proposal
                TransitionRecord memory record =
                    _loadTransitionRecord(proposalId, coreState.lastFinalizedTransitionHash);

                if (record.transitionHash == 0) break;

                if (i >= transitionCount) {
                    require(block.timestamp < record.finalizationDeadline, TransitionNotProvided());
                    break;
                }

                require(
                    _hashTransition(_input.transitions[i]) == record.transitionHash,
                    TransitionHashMismatchWithStorage()
                );

                coreState.lastFinalizedProposalId = proposalId;
                coreState.lastFinalizedTransitionHash = record.transitionHash;

                proposalId += 1;
                finalizedCount += 1;
                lastFinalizedIdx = i;
            }

            // Update checkpoint if any proposals were finalized and minimum delay has passed
            if (finalizedCount > 0) {
                Transition memory lastFinalizedTransition = _input.transitions[lastFinalizedIdx];
                coreState.bondInstructionsHashNew = lastFinalizedTransition.bondInstructionsHash;

                _syncToLayer2(_input.checkpoint, lastFinalizedTransition.checkpointHash, coreState);
            }

            return (coreState, bondInstructions_);
        }
    }

    /// @dev Syncs checkpoint to L1 storage and signals bond instruction changes to L2.
    ///      Rate-limited by minSyncDelay to reduce SSTORE operations.
    ///      When sync occurs:
    ///      1. Updates lastSyncTimestamp in core state
    ///      2. Validates and persists checkpoint to checkpoint store
    ///      3. If bond instructions changed, sends signal to L2 via signal service
    /// @param _checkpoint The checkpoint data to persist
    /// @param _lastVerifiedCheckpointHash Expected hash for checkpoint validation
    /// @param _coreState Core state to update (lastSyncTimestamp, bondInstructionsHashOld)
    function _syncToLayer2(
        ICheckpointStore.Checkpoint memory _checkpoint,
        bytes32 _lastVerifiedCheckpointHash,
        CoreState memory _coreState
    )
        private
    {
        // Rate limit: skip if minimum delay hasn't elapsed since last sync
        if (block.timestamp < uint256(_coreState.lastSyncTimestamp) + _minSyncDelay) return;

        _coreState.lastSyncTimestamp = uint40(block.timestamp);

        // Validate and persist checkpoint
        bytes32 checkpointHash = _hashCheckpoint(_checkpoint);
        require(checkpointHash == _lastVerifiedCheckpointHash, CheckpointMismatch());
        _checkpointStore.saveCheckpoint(_checkpoint);

        // Signal bond instruction changes to L2 if any occurred
        if (_coreState.bondInstructionsHashOld == _coreState.bondInstructionsHashNew) return;

        BondInstructionHashChange memory hashChange = BondInstructionHashChange({
            lastFinalizedProposalId: _coreState.lastFinalizedProposalId,
            bondInstructionsHashOld: _coreState.bondInstructionsHashOld,
            bondInstructionsHashNew: _coreState.bondInstructionsHashNew
        });

        _signalService.sendSignal(_hashBondInstructionHashChange(hashChange));

        _coreState.bondInstructionsHashOld = _coreState.bondInstructionsHashNew;
    }

    /// @dev Emits a Proposed event when a new proposal is submitted.
    ///      Packs all proposal data into a ProposedEventPayload struct to avoid stack depth issues.
    /// @param _proposal The newly created proposal containing ID, timestamps, proposer, and hashes
    /// @param _derivation The derivation data specifying origin block and data sources
    /// @param _coreState The updated core state after this proposal
    /// @param _bondInstructions Bond instructions from finalized proposals during this call
    function _emitProposedEvent(
        Proposal memory _proposal,
        Derivation memory _derivation,
        CoreState memory _coreState,
        LibBonds.BondInstruction[] memory _bondInstructions
    )
        private
    {
        ProposedEventPayload memory payload = ProposedEventPayload({
            proposal: _proposal,
            derivation: _derivation,
            coreState: _coreState,
            bondInstructions: _bondInstructions
        });
        emit Proposed(_encodeProposedEventData(payload));
    }

    /// @dev Emits a Proved event when a transition proof is submitted.
    ///      Contains all data needed by off-chain indexers to track proof status.
    /// @param _input The prove input
    /// @param _finalizationDeadline Timestamp after which this transition can be finalized
    /// @param _bondInstructions Calculated bond instructions for the proven proposals
    function _emitProvedEvent(
        ProveInput memory _input,
        uint40 _finalizationDeadline,
        LibBonds.BondInstruction[] memory _bondInstructions
    )
        private
    {
        ProvedEventPayload memory payload = ProvedEventPayload({
            proposalId: _input.proposal.id,
            parentTransitionHash: _input.parentTransitionHash,
            finalizationDeadline: _finalizationDeadline,
            checkpoint: _input.checkpoint,
            bondInstructions: _bondInstructions
        });
        emit Proved(_encodeProvedEventData(payload));
    }

    /// @dev Calculates remaining ring buffer capacity for new proposals.
    ///      Ring buffer reserves one slot to distinguish full from empty state.
    ///      Formula: capacity = ringBufferSize + lastFinalizedProposalId - nextProposalId
    /// @param _coreState Current state containing proposal counters
    /// @return _ Number of additional proposals that can be submitted before buffer is full
    function _getAvailableCapacity(CoreState memory _coreState) private view returns (uint256) {
        unchecked {
            return _ringBufferSize + _coreState.lastFinalizedProposalId - _coreState.nextProposalId;
        }
    }

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
                require(_headProposalAndProof.length == 1, IncorrectProposalCount());
            } else {
                // Next slot is occupied due to ring buffer wrap-around.
                // Must prove the occupant has a larger ID (i.e., it's an older proposal
                // that wrapped around, not a newer one after our claimed head).
                require(_headProposalAndProof.length == 2, IncorrectProposalCount());
                Proposal memory proofProposal = _headProposalAndProof[1];
                require(headProposal.id > proofProposal.id, InvalidLastProposalProof());
                require(nextSlotHash == _hashProposal(proofProposal), NextProposalHashMismatch());
            }
        }
    }

    function _recordFor(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        private
        view
        returns (TransitionRecord storage)
    {
        bytes32 compositeKey = _composeTransitionKey(_proposalId, _parentTransitionHash);
        return _records[compositeKey];
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ActivationPeriodExpired();
    error CannotProposeInCurrentBlock();
    error CheckpointMismatch();
    error DeadlineExceeded();
    error EmptyProofMetadata();
    error EmptyProposals();
    error EmptyProveInputs();
    error IncorrectProposalCount();
    error InvalidproposalId();
    error InvalidLastPacayaBlockHash();
    error InvalidLastProposalProof();
    error InvalidState();
    error NextProposalHashMismatch();
    error NotEnoughCapacity();
    error ProposalHashMismatch();
    error RingBufferSizeZero();
    error TooManyProofMetadata();
    error TransitionHashMismatchWithStorage();
    error TransitionNotProvided();
    error UnprocessedForcedInclusionIsDue();
}
