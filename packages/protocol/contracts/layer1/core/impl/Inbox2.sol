// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox2 } from "../iface/IInbox2.sol";
import { IProposerChecker2 } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBondInstruction2 } from "../libs/LibBondInstruction2.sol";
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { LibHashSimple2 } from "../libs/LibHashSimple2.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibBonds2 } from "src/shared/libs/LibBonds2.sol";
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
///      - Proof verification with transition record management
///      - Ring buffer storage for efficient state management
///      - Bond instruction calculation(but actual funds are managed on L2)
///      - Finalization of proven proposals with checkpoint rate limiting
/// @custom:security-contact security@taiko.xyz
contract Inbox2 is IInbox2, IForcedInclusionStore, EssentialContract {
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
        IInbox2.DerivationSource[] sources;
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

    /// @notice The proof verifier contract.
    IProofVerifier internal immutable _proofVerifier;

    /// @notice The proposer checker contract.
    IProposerChecker2 internal immutable _proposerChecker;

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
    mapping(bytes32 compositeKey => TransitionRecord record) internal _transitionRecords;

    /// @dev Storage for forced inclusion requests
    /// @dev 2 slots used
    LibForcedInclusion.Storage private _forcedInclusionStorage;

    uint256[37] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    /// @param _config Configuration struct containing all constructor parameters
    constructor(IInbox2.Config memory _config) {
        require(_config.checkpointStore != address(0), ZERO_ADDRESS());
        require(_config.ringBufferSize != 0, RingBufferSizeZero());

        _codec = _config.codec;
        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _proposerChecker = IProposerChecker2(_config.proposerChecker);
        _checkpointStore = ICheckpointStore(_config.checkpointStore);
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
    /// @dev The `propose` function implicitly checks that activation has occurred by verifying
    ///      the genesis proposal (ID 0) exists in storage via `_verifyHeadProposal` →
    ///      `_checkProposalHash`. If `activate` hasn't been called, the genesis proposal won't
    ///      exist and `propose` will revert with `ProposalHashMismatch()`.
    ///      This function can be called multiple times to handle L1 reorgs where the last Pacaya
    ///      block may change after this function is called.
    /// @param _lastPacayaBlockHash The hash of the last Pacaya block
    // TODO:
    function activate(
        bytes32 _lastPacayaBlockHash,
        ICheckpointStore.Checkpoint memory _checkpoint
    )
        external
        onlyOwner
    {
        require(_lastPacayaBlockHash != 0, InvalidLastPacayaBlockHash());
        if (activationTimestamp == 0) {
            activationTimestamp = uint40(block.timestamp);
        } else {
            require(
                block.timestamp <= _ACTIVATION_WINDOW + activationTimestamp,
                ActivationPeriodExpired()
            );
        }
        _activateInbox(_lastPacayaBlockHash, _checkpoint);
        emit InboxActivated(_lastPacayaBlockHash);
    }

    /// @inheritdoc IInbox2
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
            require(input.parentProposals.length > 0, EmptyProposals());

            // Enforce one propose call per Ethereum block to prevent spam attacks that could
            // deplete the ring buffer
            require(
                block.number > input.coreState.lastProposalBlockId, CannotProposeInCurrentBlock()
            );
            require(
                _hashCoreState(input.coreState) == input.parentProposals[0].coreStateHash,
                InvalidState()
            );

            // Verify parentProposals[0] is the last proposal stored on-chain.
            bytes32 headProposalHash = _verifyHeadProposal(input.parentProposals);

            // Finalize proposals before proposing a new one to free ring buffer space and prevent deadlock
            (CoreState memory coreState, LibBonds2.BondInstruction[] memory bondInstructions) =
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

    /// @inheritdoc IInbox2
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
            uint8 span;

            for (uint256 i; i < inputs.length; ++i) {
                input = inputs[i];
                require(input.prposalProofMetadatas.length != 0, EmptyProofMetadata());
                require(input.prposalProofMetadatas.length <= 24, TooManyProofMetadata());
                span = uint8(input.prposalProofMetadatas.length);
                require(input.endProposal.id >= span, InvalidEndProposalId());
                _checkProposalHash(input.endProposal);

                uint40 startProposalId = input.endProposal.id - span;

                LibBonds2.BondInstruction[] memory bondInstructions =
                    LibBondInstruction2.calculateBondInstructions(
                        _provingWindow,
                        _extendedProvingWindow,
                        startProposalId,
                        input.prposalProofMetadatas
                    );
                Transition memory transition = Transition({
                    bondInstructionsHash: _hashBondInstructions(bondInstructions),
                    checkpointHash: _hashCheckpoint(input.checkpoint)
                });

                TransitionRecord storage existing =
                    _transitionMetadataFor(startProposalId, input.parentTransitionHash);

                if (existing.span >= span) continue; // TODO: emit an event?

                bytes26 transitionHash = _hashTransition(transition);

                existing.transitionHash = transitionHash;
                existing.span = span;
                existing.finalizationDeadline = finalizationDeadline;

                ProvedEventPayload memory payload = ProvedEventPayload({
                    startProposalId: startProposalId,
                    parentTransitionHash: input.parentTransitionHash,
                    span: span,
                    finalizationDeadline: finalizationDeadline,
                    checkpoint: input.checkpoint,
                    bondInstructions: bondInstructions
                });

                emit Proved(_encodeProvedEventData(payload));
            }

            uint256 proposalAge;
            // if (inputs.length == 1 && span == 1) {
            //     proposalAge = block.timestamp - input.endProposal.timestamp;
            // }

            _proofVerifier.verifyProof(proposalAge, _hashProveInputArray(inputs), _proof);
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
        return _proposalHashes[_proposalId % _ringBufferSize];
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
        return _transitionMetadataFor(_proposalId, _parentTransitionHash);
    }

    /// @inheritdoc IInbox2
    function getConfig() external view returns (IInbox2.Config memory config_) {
        config_ = IInbox2.Config({
            codec: _codec,
            checkpointStore: address(_checkpointStore),
            proofVerifier: address(_proofVerifier),
            proposerChecker: address(_proposerChecker),
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
            minCheckpointDelay: _minCheckpointDelay,
            permissionlessInclusionMultiplier: _permissionlessInclusionMultiplier
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
    /// @param _checkpoint The checkpoint of the last Pacaya block
    function _activateInbox(
        bytes32 _lastPacayaBlockHash,
        ICheckpointStore.Checkpoint memory _checkpoint
    )
        internal
    {
        Transition memory transitionRecord;
        transitionRecord.checkpointHash = _hashCheckpoint(_checkpoint);

        CoreState memory coreState;
        coreState.nextProposalId = 1;

        // Set lastProposalBlockId to 1 to ensure the first proposal happens at block 2 or later.
        // This prevents reading blockhash(0) in propose(), which would return 0x0 and create
        // an invalid origin block hash. The EVM hardcodes blockhash(0) to 0x0, so we must
        // ensure proposals never reference the genesis block.
        coreState.lastProposalBlockId = 1;
        coreState.lastFinalizedTransitionHash = _hashTransition(transitionRecord);

        Proposal memory proposal;
        proposal.coreStateHash = _hashCoreState(coreState);

        Derivation memory derivation;
        proposal.derivationHash = _hashDerivation(derivation);

        _proposalHashes[0] = _hashProposal(proposal);

        _emitProposedEvent(proposal, derivation, coreState, new LibBonds2.BondInstruction[](0));
    }

    /// @dev Loads transition record metadata from storage.
    /// @param _proposalId The proposal identifier.
    /// @param _parentTransitionHash Hash of the parent transition used as lookup key.
    /// @return record_ The transition record metadata.
    function _transitionMetadataFor(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        virtual
        returns (TransitionRecord storage record_)
    {
        bytes32 compositeKey = _composeTransitionKey(_proposalId, _parentTransitionHash);
        return _transitionRecords[compositeKey];
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
        virtual
        returns (bytes32)
    {
        return LibHashSimple2.composeTransitionKey(_proposalId, _parentTransitionHash);
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

    // ---------------------------------------------------------------
    // Decoder Functions
    // ---------------------------------------------------------------

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
        returns (ProveInput[] memory)
    {
        return abi.decode(_data, (ProveInput[]));
    }

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @dev Optimized hashing for blob hashes array to reduce stack depth
    /// @param _blobHashes The blob hashes array to hash
    /// @return The hash of the blob hashes array
    function _hashBlobHashesArray(bytes32[] memory _blobHashes)
        internal
        pure
        virtual
        returns (bytes32)
    {
        return LibHashSimple2.hashBlobHashesArray(_blobHashes);
    }

    /// @dev Hashes a Checkpoint struct.
    /// @param _checkpoint The checkpoint to hash.
    /// @return _ The hash of the checkpoint.
    function _hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        virtual
        returns (bytes32)
    {
        return LibHashSimple2.hashCheckpoint(_checkpoint);
    }

    /// @dev Hashes a CoreState struct.
    /// @param _coreState The core state to hash.
    /// @return _ The hash of the core state.
    function _hashCoreState(CoreState memory _coreState) internal pure virtual returns (bytes32) {
        return LibHashSimple2.hashCoreState(_coreState);
    }

    /// @dev Hashes a Derivation struct.
    /// @param _derivation The derivation to hash.
    /// @return _ The hash of the derivation.
    function _hashDerivation(Derivation memory _derivation)
        internal
        pure
        virtual
        returns (bytes32)
    {
        return LibHashSimple2.hashDerivation(_derivation);
    }

    /// @dev Hashes a Proposal struct.
    /// @param _proposal The proposal to hash.
    /// @return _ The hash of the proposal.
    function _hashProposal(Proposal memory _proposal) internal pure virtual returns (bytes32) {
        return LibHashSimple2.hashProposal(_proposal);
    }

    function _hashProveInputArray(ProveInput[] memory _inputs)
        internal
        pure
        virtual
        returns (bytes32)
    {
        return LibHashSimple2.hashProveInputArray(_inputs);
    }

    /// @dev Hashes a Transition struct.
    /// @param _transition The transition record to hash.
    /// @return _ The hash of the transition record.
    function _hashTransition(Transition memory _transition)
        internal
        pure
        virtual
        returns (bytes26)
    {
        return LibHashSimple2.hashTransition(_transition);
    }

    /// @dev Hashes bond instructions array.
    /// @param _bondInstructions The bond instructions to hash.
    /// @return _ The hash of the bond instructions.
    function _hashBondInstructions(LibBonds2.BondInstruction[] memory _bondInstructions)
        internal
        pure
        virtual
        returns (bytes32)
    {
        return LibHashSimple2.hashBondInstructions(_bondInstructions);
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
            result_.sources = new IInbox2.DerivationSource[](toProcess + 1);

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
        IInbox2.DerivationSource[] memory _sources,
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
                    _sources[i] = IInbox2.DerivationSource(true, inclusion.blobSlice);
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

    /// @dev Emits the Proposed event with stack-optimized approach
    /// @param _proposal The proposal data
    /// @param _derivation The derivation data
    /// @param _coreState The core state data
    function _emitProposedEvent(
        Proposal memory _proposal,
        Derivation memory _derivation,
        CoreState memory _coreState,
        LibBonds2.BondInstruction[] memory _bondInstructions
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

    /// @dev Finalizes proven proposals and updates checkpoints with rate limiting.
    /// Checkpoints are only saved if minCheckpointDelay seconds have passed since the last save,
    /// reducing SSTORE operations but making L2 checkpoints less frequently available on L1.
    /// Set minCheckpointDelay to 0 to disable rate limiting.
    /// @param _input Contains transition records and the end block header.
    /// @return coreState_ Updated core state with new finalization counters.
    /// @return bondInstructions_ Array of bond instructions from finalized proposals.
    function _finalize(ProposeInput memory _input)
        private
        returns (CoreState memory coreState_, LibBonds2.BondInstruction[] memory bondInstructions_)
    {
        //       /// @notice Input data for the propose function
        // struct ProposeInput {
        //     /// @notice The deadline timestamp for transaction inclusion (0 = no deadline).
        //     uint48 deadline;
        //     /// @notice The current core state before this proposal.
        //     CoreState coreState;
        //     /// @notice Array of existing proposals for validation (1-2 elements).
        //     Proposal[] parentProposals;
        //     /// @notice Blob reference for proposal data.
        //     LibBlobs.BlobReference blobReference;
        //     /// @notice Array of transition records for finalization.
        //     Transition[] transitionRecords;
        //     /// @notice The checkpoint for finalization.
        //     ICheckpointStore.Checkpoint checkpoint;
        //     /// @notice The number of forced inclusions that the proposer wants to process.
        //     /// @dev This can be set to 0 if no forced inclusions are due, and there's none in the queue
        //     /// that he wants to include.
        //     uint8 numForcedInclusions;
        // }

        unchecked {
            CoreState memory coreState = _input.coreState;
            uint40 proposalId = coreState.lastFinalizedProposalId + 1;
            uint256 lastFinalizedRecordIdx;
            uint256 finalizedCount;
            uint256 transitionCount = _input.transitions.length;
            uint256 currentTimestamp = block.timestamp;
            uint256 totalBondInstructionCount;

            for (uint256 i; i < _maxFinalizationCount; ++i) {
                // Check if there are more proposals to finalize
                if (proposalId >= coreState.nextProposalId) break;

                // Try to finalize the current proposal
                TransitionRecord memory record =
                    _transitionMetadataFor(proposalId, coreState.lastFinalizedTransitionHash);

                if (record.transitionHash == 0) break;

                if (i >= transitionCount) {
                    require(currentTimestamp < record.finalizationDeadline, TransitionNotProvided());
                    break;
                }

                require(
                    _hashTransition(_input.transitions[i]) == record.transitionHash,
                    TransitionHashMismatchWithStorage()
                );

                totalBondInstructionCount += _input.bondInstructions[i].length;

                coreState.lastFinalizedProposalId = proposalId;
                coreState.lastFinalizedTransitionHash = record.transitionHash;

                ++proposalId;

                // Update state for successful finalization
                lastFinalizedRecordIdx = i;
                ++finalizedCount;
            }

            // Update checkpoint if any proposals were finalized and minimum delay has passed
            if (finalizedCount > 0) {
                Transition memory lastFinalizedTransition =   _input.transitions[lastFinalizedRecordIdx];
                 coreState.bondInstructionsHashNew = lastFinalizedTransition.bondInstructionsHash;

                _syncCheckpoint(
                    _input.checkpoint,
                    lastFinalizedTransition.checkpointHash,
                    coreState
                );

                _sendBondInstructionSignal(coreState);
            }

            return (coreState, bondInstructions_);
        }
    }

    /// @dev Syncs checkpoint to storage when voluntary or forced sync conditions are met.
    ///      Validates the checkpoint hash, persists it, and refreshes the timestamp in core state.
    /// @param _checkpoint The checkpoint data to sync.
    /// @param _expectedCheckpointHash The expected hash to validate against.
    /// @param _coreState Core state to update with new checkpoint timestamp.
    function _syncCheckpoint(
        ICheckpointStore.Checkpoint memory _checkpoint,
        bytes32 _expectedCheckpointHash,
        CoreState memory _coreState
    )
        private
    {
        // Check if checkpoint sync should occur:
        // 1. Voluntary: proposer provided a checkpoint (blockHash != 0)
        // 2. Forced: minimum delay elapsed since last checkpoint
        if (_checkpoint.blockHash != 0) {
            bytes32 checkpointHash = _hashCheckpoint(_checkpoint);
            require(checkpointHash == _expectedCheckpointHash, CheckpointMismatch());

            _checkpointStore.saveCheckpoint(_checkpoint);
            _coreState.lastCheckpointTimestamp = uint40(block.timestamp);
        } else {
            require(
                block.timestamp < _coreState.lastCheckpointTimestamp + _minCheckpointDelay,
                CheckpointNotProvided()
            );
        }
    }

    function _sendBondInstructionSignal(CoreState memory _coreState) private {
        if (_coreState.bondInstructionsHashOld == _coreState.bondInstructionsHashNew) return;
        if (_coreState.lastFinalizedProposalId % 128!=0) return;

        _coreState.bondInstructionsHashOld = _coreState.bondInstructionsHashNew;
       
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

    /// @dev Verifies that parentProposals[0] is the current chain head
    /// Requires 1 element if next slot empty, 2 if occupied with older proposal
    /// @param _parentProposals Array of 1-2 proposals to verify chain head
    /// @return headProposalHash_ The hash of the head proposal
    function _verifyHeadProposal(Proposal[] memory _parentProposals)
        private
        view
        returns (bytes32 headProposalHash_)
    {
        unchecked {
            // First verify parentProposals[0] matches what's stored on-chain
            headProposalHash_ = _checkProposalHash(_parentProposals[0]);

            // Then verify it's actually the chain head
            uint256 nextBufferSlot = (_parentProposals[0].id + 1) % _ringBufferSize;
            bytes32 storedNextProposalHash = _proposalHashes[nextBufferSlot];

            if (storedNextProposalHash == bytes32(0)) {
                // Next slot in the ring buffer is empty, only one proposal expected
                require(_parentProposals.length == 1, IncorrectProposalCount());
            } else {
                // Next slot in the ring buffer is occupied, need to prove it contains a
                // proposal with a smaller id
                require(_parentProposals.length == 2, IncorrectProposalCount());
                require(_parentProposals[1].id < _parentProposals[0].id, InvalidLastProposalProof());
                require(
                    storedNextProposalHash == _hashProposal(_parentProposals[1]),
                    NextProposalHashMismatch()
                );
            }
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
    error EmptyProveInputs();
    error EmptyProofMetadata();
    error TooManyProofMetadata();
    error IncorrectProposalCount();
    error InvalidEndProposalId();
    error InvalidLastPacayaBlockHash();
    error InvalidLastProposalProof();
    error InvalidSpan();
    error InvalidState();
    error NextProposalHashMismatch();
    error NotEnoughCapacity();
    error ProposalHashMismatch();
    error RingBufferSizeZero();
    error TransitionHashMismatchWithStorage();
    error TransitionNotProvided();
    error UnprocessedForcedInclusionIsDue();
}
