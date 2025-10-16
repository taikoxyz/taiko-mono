// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBondInstruction } from "../libs/LibBondInstruction.sol";
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { LibHashSimple } from "../libs/LibHashSimple.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title Inbox
/// @notice Core contract for managing L2 proposals, proofs, verification and forced inclusion in
/// Taiko's based rollup architecture.
/// @dev This contract implements the fundamental inbox logic including:
///      - Proposal submission with forced inclusion support
///      - Proof verification with transition record management
///      - Ring buffer storage for efficient state management
///      - Bond instruction processing for economic security
///      - Finalization of proven proposals with checkpoint rate limiting
/// @custom:security-contact security@taiko.xyz
contract Inbox is IInbox, IForcedInclusionStore, EssentialContract {
    using LibAddress for address;
    using LibMath for uint48;
    using LibMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice Struct for storing transition effective timestamp and hash.
    /// @dev Stores transition record hash and finalization deadline
    struct TransitionRecordHashAndDeadline {
        bytes26 recordHash;
        uint48 finalizationDeadline;
    }

    /// @notice Result from consuming forced inclusions
    struct ConsumptionResult {
        IInbox.DerivationSource[] sources;
        bool allowsPermissionless;
    }

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

    /// @notice The maximum number of proposals that can be finalized in one finalization call.
    uint256 internal immutable _maxFinalizationCount;

    /// @notice The finalization grace period in seconds.
    uint48 internal immutable _finalizationGracePeriod;

    /// @notice The ring buffer size for storing proposal hashes.
    uint256 internal immutable _ringBufferSize;

    /// @notice The percentage of basefee paid to coinbase.
    uint8 internal immutable _basefeeSharingPctg;

    /// @notice The minimum number of forced inclusions that the proposer is forced to process if
    /// they are due.
    uint256 internal immutable _minForcedInclusionCount;

    /// @notice The delay for forced inclusions measured in seconds.
    uint16 internal immutable _forcedInclusionDelay;

    /// @notice The fee for forced inclusions in Gwei.
    uint64 internal immutable _forcedInclusionFeeInGwei;

    /// @notice The minimum delay between checkpoints in seconds.
    uint16 internal immutable _minCheckpointDelay;

    /// @notice The multiplier to determine when a forced inclusion is too old so that proposing
    /// becomes permissionless
    uint8 internal immutable _permissionlessInclusionMultiplier;

    /// @notice Version identifier for composite key generation
    /// @dev Used to invalidate all proved but unfinalized transition records to recover from
    /// potential proof verifier bugs
    uint16 internal immutable _compositeKeyVersion;

    /// @notice Checkpoint store responsible for checkpoints
    ICheckpointStore internal immutable _checkpointStore;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev The address responsible for calling `activate` on the inbox.
    address internal _shastaInitializer;

    /// @notice Flag indicating whether a conflicting transition record has been detected
    bool public conflictingTransitionDetected;

    /// @dev Ring buffer for storing proposal hashes indexed by buffer slot
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - proposalHash: The keccak256 hash of the Proposal struct
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev Simple mapping for storing transition record hashes
    /// @dev We do not use a ring buffer for this mapping, since a nested mapping does not benefit
    /// from it
    /// @dev Stores transition records for proposals with different parent transitions
    /// - compositeKey: Keccak256 hash of (proposalId, parentTransitionHash)
    /// - value: The struct contains the finalization deadline and the hash of the TransitionRecord
    mapping(bytes32 compositeKey => TransitionRecordHashAndDeadline hashAndDeadline) internal
        _transitionRecordHashAndDeadline;

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
        _maxFinalizationCount = _config.maxFinalizationCount;
        _finalizationGracePeriod = _config.finalizationGracePeriod;
        _ringBufferSize = _config.ringBufferSize;
        _basefeeSharingPctg = _config.basefeeSharingPctg;
        _minForcedInclusionCount = _config.minForcedInclusionCount;
        _forcedInclusionDelay = _config.forcedInclusionDelay;
        _forcedInclusionFeeInGwei = _config.forcedInclusionFeeInGwei;
        _minCheckpointDelay = _config.minCheckpointDelay;
        _permissionlessInclusionMultiplier = _config.permissionlessInclusionMultiplier;
        _compositeKeyVersion = _config.compositeKeyVersion;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the owner of the inbox. The inbox then needs to be activated by the
    /// `shastaInitializer` later in order to start accepting proposals.
    /// @param _owner The owner of this contract
    function init(address _owner, address shastaInitializer) external initializer {
        __Essential_init(_owner);
        _shastaInitializer = shastaInitializer;
    }

    /// @notice Activates the inbox so that it can start accepting proposals.
    ///         This function can only be called once.
    /// @dev Only the `shastaInitializer` can call this function.
    /// @param _genesisBlockHash The hash of the genesis block
    function activate(bytes32 _genesisBlockHash) external {
        require(msg.sender == _shastaInitializer, ACCESS_DENIED());
        _activateInbox(_genesisBlockHash);

        // Set the shastaInitializer to zero to prevent further calls to `activate`
        _shastaInitializer = address(0);
    }

    /// @inheritdoc IInbox
    /// @notice Proposes new L2 blocks and forced inclusions to the rollup using blobs for DA.
    /// @dev Key behaviors:
    ///      1. Validates proposer authorization via ProposerChecker
    ///      2. Finalizes eligible proposals up to `config.maxFinalizationCount` to free ring buffer
    ///         space.
    ///      3. Process `input.numForcedInclusions` forced inclusions. The proposer is forced to
    ///         process at least `config.minForcedInclusionCount` if they are due.
    ///      4. Updates core state and emits `Proposed` event
    /// @dev IMPORTANT: The regular proposal might not be included if there is not enough capacity
    ///      available(i.e forced inclusions are prioritized).
    function propose(bytes calldata _lookahead, bytes calldata _data) external nonReentrant {
        unchecked {
            // Decode and validate input data
            ProposeInput memory input = _decodeProposeInput(_data);

            _validateProposeInput(input);

            // Verify parentProposals[0] is actually the last proposal stored on-chain.
            _verifyChainHead(input.parentProposals);

            // IMPORTANT: Finalize first to free ring buffer space and prevent deadlock
            CoreState memory coreState = _finalize(input);

            // Enforce one propose call per Ethereum block to prevent spam attacks that could
            // deplete the ring buffer
            coreState.lastProposalBlockId = uint48(block.number);

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

            // Increment nextProposalId (lastProposalBlockId was already set above)
            Proposal memory proposal = Proposal({
                id: coreState.nextProposalId++,
                timestamp: uint48(block.timestamp),
                endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
                proposer: msg.sender,
                coreStateHash: _hashCoreState(coreState),
                derivationHash: _hashDerivation(derivation)
            });

            _setProposalHash(proposal.id, _hashProposal(proposal));
            _emitProposedEvent(proposal, derivation, coreState);
        }
    }

    /// @inheritdoc IInbox
    /// @notice Proves the validity of proposed L2 blocks
    /// @dev Validates transitions, calculates bond instructions, and verifies proofs
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        // Decode and validate input
        ProveInput memory input = _decodeProveInput(_data);
        require(input.proposals.length != 0, EmptyProposals());
        require(input.proposals.length == input.transitions.length, InconsistentParams());
        require(input.transitions.length == input.metadata.length, InconsistentParams());

        // Build transition records with validation and bond calculations
        _buildAndSaveTransitionRecords(input);

        uint256 proposalAge;
        if (input.proposals.length == 1) {
            unchecked {
                // proposalAge will only be used by the proof verifier for single-proposal.
                proposalAge = block.timestamp - input.proposals[0].timestamp;
            }
        }

        bytes32 aggregatedProvingHash =
            _hashTransitionsWithMetadata(input.transitions, input.metadata);

        _proofVerifier.verifyProof(proposalAge, aggregatedProvingHash, _proof);
    }

    /// @inheritdoc IForcedInclusionStore
    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable {
        LibForcedInclusion.saveForcedInclusion(
            _forcedInclusionStorage, _forcedInclusionFeeInGwei, _blobReference
        );
    }

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IForcedInclusionStore
    function isOldestForcedInclusionDue() external view returns (bool) {
        return LibForcedInclusion.isOldestForcedInclusionDue(
            _forcedInclusionStorage, _forcedInclusionDelay
        );
    }

    /// @notice Retrieves the proposal hash for a given proposal ID
    /// @param _proposalId The ID of the proposal to query
    /// @return proposalHash_ The keccak256 hash of the Proposal struct at the ring buffer slot
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_) {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        proposalHash_ = _proposalHashes[bufferSlot];
    }

    /// @notice Retrieves the transition record hash for a specific proposal and parent transition
    /// @param _proposalId The ID of the proposal containing the transition
    /// @param _parentTransitionHash The hash of the parent transition in the proof chain
    /// @return finalizationDeadline_ The timestamp when finalization is enforced
    /// @return recordHash_ The hash of the transition record
    function getTransitionRecordHash(uint48 _proposalId, bytes32 _parentTransitionHash)
        external
        view
        returns (uint48 finalizationDeadline_, bytes26 recordHash_)
    {
        TransitionRecordHashAndDeadline memory hashAndDeadline =
            _getTransitionRecordHashAndDeadline(_proposalId, _parentTransitionHash);
        return (hashAndDeadline.finalizationDeadline, hashAndDeadline.recordHash);
    }

    /// @inheritdoc IInbox
    function getConfig() external view returns (IInbox.Config memory config_) {
        config_ = IInbox.Config({
            codec: _codec,
            bondToken: address(_bondToken),
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
            minCheckpointDelay: _minCheckpointDelay,
            permissionlessInclusionMultiplier: _permissionlessInclusionMultiplier,
            compositeKeyVersion: _compositeKeyVersion
        });
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Activates the inbox with genesis state so that it can start accepting proposals.
    /// @notice Sets up the initial proposal and core state with genesis block
    /// @param _genesisBlockHash The hash of the genesis block
    function _activateInbox(bytes32 _genesisBlockHash) internal {
        Transition memory transition;
        transition.checkpoint.blockHash = _genesisBlockHash;

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

        _setProposalHash(0, _hashProposal(proposal));

        _emitProposedEvent(proposal, derivation, coreState);
    }

    /// @dev Builds and persists transition records for batch proof submissions
    /// @notice Validates transitions, calculates bond instructions, and stores records
    /// @dev Virtual function that can be overridden for optimization (e.g., transition aggregation)
    /// @param _input The ProveInput containing arrays of proposals, transitions, and metadata
    function _buildAndSaveTransitionRecords(ProveInput memory _input) internal virtual {
        for (uint256 i; i < _input.proposals.length; ++i) {
            _processSingleTransitionAtIndex(_input, i);
        }
    }

    /// @dev Processes a single transition at the specified index
    /// @notice Reusable function for validating, building, and storing individual transitions
    /// @param _input The ProveInput containing all transition data
    /// @param _index The index of the transition to process
    function _processSingleTransitionAtIndex(ProveInput memory _input, uint256 _index) internal {
        _validateTransition(_input.proposals[_index], _input.transitions[_index]);

        TransitionRecord memory transitionRecord = _buildTransitionRecord(
            _input.proposals[_index], _input.transitions[_index], _input.metadata[_index]
        );

        _setTransitionRecordHashAndDeadline(
            _input.proposals[_index].id,
            _input.transitions[_index],
            _input.metadata[_index],
            transitionRecord
        );
    }

    /// @dev Stores a proposal hash in the ring buffer
    /// @notice Overwrites any existing hash at the calculated buffer slot
    function _setProposalHash(uint48 _proposalId, bytes32 _proposalHash) internal {
        _proposalHashes[_proposalId % _ringBufferSize] = _proposalHash;
    }

    /// @dev Stores transition record hash and emits Proved event
    /// @notice Virtual function to allow optimization in derived contracts
    /// @dev Uses composite key for unique transition identification
    /// @param _proposalId The ID of the proposal being proven
    /// @param _transition The transition data to include in the event
    /// @param _metadata The metadata containing prover information to include in the event
    /// @param _transitionRecord The transition record to hash and store
    function _setTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        Transition memory _transition,
        TransitionMetadata memory _metadata,
        TransitionRecord memory _transitionRecord
    )
        internal
        virtual
    {
        (bytes26 transitionRecordHash, TransitionRecordHashAndDeadline memory hashAndDeadline) =
            _computeTransitionRecordHashAndDeadline(_transitionRecord);

        _storeTransitionRecord(
            _proposalId, _transition.parentTransitionHash, transitionRecordHash, hashAndDeadline
        );

        ProvedEventPayload memory payload = ProvedEventPayload({
            proposalId: _proposalId,
            transition: _transition,
            transitionRecord: _transitionRecord,
            metadata: _metadata
        });
        emit Proved(_encodeProvedEventData(payload));
    }

    /// @dev Persists transition record metadata in storage.
    /// @notice Returns false when an identical record already exists, avoiding redundant event
    /// emissions.
    /// @param _proposalId The proposal identifier.
    /// @param _parentTransitionHash Hash of the parent transition for uniqueness.
    /// @param _recordHash The keccak hash representing the transition record.
    /// @param _hashAndDeadline The finalization metadata to store alongside the hash.
    function _storeTransitionRecord(
        uint48 _proposalId,
        bytes32 _parentTransitionHash,
        bytes26 _recordHash,
        TransitionRecordHashAndDeadline memory _hashAndDeadline
    )
        internal
        virtual
    {
        bytes32 compositeKey = _composeTransitionKey(_proposalId, _parentTransitionHash);
        TransitionRecordHashAndDeadline storage entry =
            _transitionRecordHashAndDeadline[compositeKey];
        bytes26 recordHash = entry.recordHash;

        if (recordHash == 0) {
            entry.recordHash = _recordHash;
            entry.finalizationDeadline = _hashAndDeadline.finalizationDeadline;
        } else if (recordHash == _recordHash) {
            emit TransitionDuplicateDetected();
        } else {
            emit TransitionConflictDetected();
            conflictingTransitionDetected = true;
            entry.finalizationDeadline = type(uint48).max;
        }
    }

    /// @dev Loads transition record metadata from storage.
    /// @param _proposalId The proposal identifier.
    /// @param _parentTransitionHash Hash of the parent transition used as lookup key.
    /// @return hashAndDeadline_ Stored metadata for the given proposal/parent pair.
    function _getTransitionRecordHashAndDeadline(uint48 _proposalId, bytes32 _parentTransitionHash)
        internal
        view
        virtual
        returns (TransitionRecordHashAndDeadline memory hashAndDeadline_)
    {
        bytes32 compositeKey = _composeTransitionKey(_proposalId, _parentTransitionHash);
        hashAndDeadline_ = _transitionRecordHashAndDeadline[compositeKey];
    }

    /// @dev Validates transition consistency with its corresponding proposal
    /// @notice Ensures the transition references the correct proposal hash
    /// @param _proposal The proposal being proven
    /// @param _transition The transition to validate against the proposal
    function _validateTransition(Proposal memory _proposal, Transition memory _transition)
        internal
        view
    {
        bytes32 proposalHash = _checkProposalHash(_proposal);
        require(proposalHash == _transition.proposalHash, ProposalHashMismatchWithTransition());
    }

    /// @dev Validates proposal hash against stored value
    /// @notice Reverts with ProposalHashMismatch if hashes don't match
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

    /// @dev Builds a transition record for a proposal, transition, and metadata tuple.
    /// @param _proposal The proposal the transition is proving.
    /// @param _transition The transition associated with the proposal.
    /// @param _metadata The metadata describing the prover and additional context.
    /// @return record The constructed transition record with span set to one.
    function _buildTransitionRecord(
        Proposal memory _proposal,
        Transition memory _transition,
        TransitionMetadata memory _metadata
    )
        internal
        view
        returns (TransitionRecord memory record)
    {
        record.span = 1;
        record.bondInstructions = LibBondInstruction.calculateBondInstructions(
            _provingWindow, _extendedProvingWindow, _proposal, _metadata
        );
        record.transitionHash = _hashTransition(_transition);
        record.checkpointHash = _hashCheckpoint(_transition.checkpoint);
    }

    /// @dev Computes the hash and finalization deadline for a transition record.
    /// @param _transitionRecord The transition record to hash.
    /// @return recordHash_ The keccak hash of the transition record.
    /// @return hashAndDeadline_ The struct containing the hash and deadline to persist.
    function _computeTransitionRecordHashAndDeadline(TransitionRecord memory _transitionRecord)
        internal
        view
        returns (bytes26 recordHash_, TransitionRecordHashAndDeadline memory hashAndDeadline_)
    {
        unchecked {
            recordHash_ = _hashTransitionRecord(_transitionRecord);
            hashAndDeadline_ = TransitionRecordHashAndDeadline({
                finalizationDeadline: uint48(block.timestamp + _finalizationGracePeriod),
                recordHash: recordHash_
            });
        }
    }

    /// @dev Computes composite key for transition record storage
    /// @notice Creates unique identifier for proposal-parent transition pairs
    /// @param _proposalId The ID of the proposal
    /// @param _parentTransitionHash Hash of the parent transition
    /// @return _ Keccak256 hash of encoded parameters
    function _composeTransitionKey(uint48 _proposalId, bytes32 _parentTransitionHash)
        internal
        view
        virtual
        returns (bytes32)
    {
        return LibHashSimple.composeTransitionKey(
            _proposalId, _compositeKeyVersion, _parentTransitionHash
        );
    }

    // ---------------------------------------------------------------
    // Encoder Functions
    // ---------------------------------------------------------------

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
        returns (ProveInput memory)
    {
        return abi.decode(_data, (ProveInput));
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
        return LibHashSimple.hashBlobHashesArray(_blobHashes);
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
        return LibHashSimple.hashCheckpoint(_checkpoint);
    }

    /// @dev Hashes a CoreState struct.
    /// @param _coreState The core state to hash.
    /// @return _ The hash of the core state.
    function _hashCoreState(CoreState memory _coreState) internal pure virtual returns (bytes32) {
        return LibHashSimple.hashCoreState(_coreState);
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
        return LibHashSimple.hashDerivation(_derivation);
    }

    /// @dev Hashes a Proposal struct.
    /// @param _proposal The proposal to hash.
    /// @return _ The hash of the proposal.
    function _hashProposal(Proposal memory _proposal) internal pure virtual returns (bytes32) {
        return LibHashSimple.hashProposal(_proposal);
    }

    /// @dev Hashes a Transition struct.
    /// @param _transition The transition to hash.
    /// @return _ The hash of the transition.
    function _hashTransition(Transition memory _transition)
        internal
        pure
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
        pure
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
        pure
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
    function _consumeForcedInclusions(address _feeRecipient, uint256 _numForcedInclusionsRequested)
        private
        returns (ConsumptionResult memory result_)
    {
        unchecked {
            LibForcedInclusion.Storage storage $ = _forcedInclusionStorage;

            // Load storage once
            (uint48 head, uint48 tail, uint48 lastProcessedAt) = ($.head, $.tail, $.lastProcessedAt);

            uint256 available = tail - head;
            uint256 toProcess =
                _numForcedInclusionsRequested > available
                ? available
                : _numForcedInclusionsRequested;

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
            uint256 permissionlessTimestamp =
                uint256(_forcedInclusionDelay) * _permissionlessInclusionMultiplier
                + oldestTimestamp;
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
            oldestTimestamp_ = uint48(_sources[0].blobSlice.timestamp.max(_lastProcessedAt));

            // Update queue position and last processed time
            head_ = _head + uint48(_toProcess);
            lastProcessedAt_ = uint48(block.timestamp);

            // Write to storage once
            ($.head, $.lastProcessedAt) = (head_, lastProcessedAt_);
        } else {
            // No inclusions processed
            oldestTimestamp_ = type(uint48).max;
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
        CoreState memory _coreState
    )
        private
    {
        ProposedEventPayload memory payload = ProposedEventPayload({
            proposal: _proposal, derivation: _derivation, coreState: _coreState
        });
        emit Proposed(_encodeProposedEventData(payload));
    }

    /// @dev Finalizes proven proposals and updates checkpoints with rate limiting.
    /// Checkpoints are only saved if minCheckpointDelay seconds have passed since the last save,
    /// reducing SSTORE operations but making L2 checkpoints less frequently available on L1.
    /// Set minCheckpointDelay to 0 to disable rate limiting.
    /// @param _input Contains transition records and the end block header.
    /// @return _ Updated core state with new finalization counters.
    function _finalize(ProposeInput memory _input) private returns (CoreState memory) {
        unchecked {
            CoreState memory coreState = _input.coreState;
            TransitionRecord memory lastFinalizedRecord;
            TransitionRecord memory emptyRecord;
            uint48 proposalId = coreState.lastFinalizedProposalId + 1;
            uint256 finalizedCount;

            for (uint256 i; i < _maxFinalizationCount; ++i) {
                // Check if there are more proposals to finalize
                if (proposalId >= coreState.nextProposalId) break;

                // Try to finalize the current proposal
                bool hasRecord = i < _input.transitionRecords.length;

                TransitionRecord memory transitionRecord =
                    hasRecord ? _input.transitionRecords[i] : emptyRecord;

                bool finalized;
                (finalized, proposalId) =
                    _finalizeProposal(coreState, proposalId, transitionRecord, hasRecord);

                if (!finalized) break;

                // Update state for successful finalization
                lastFinalizedRecord = _input.transitionRecords[i];
                ++finalizedCount;
            }

            // Update checkpoint if any proposals were finalized and minimum delay has passed
            if (finalizedCount > 0) {
                _syncCheckpointIfNeeded(
                    _input.checkpoint, lastFinalizedRecord.checkpointHash, coreState
                );
            }

            return coreState;
        }
    }

    /// @dev Syncs checkpoint to storage if conditions are met (voluntary or forced sync).
    /// @notice Validates checkpoint hash and updates checkpoint storage and timestamp.
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
        // Check if checkpoint sync should occur:
        // 1. Voluntary: proposer provided a checkpoint (blockHash != 0)
        // 2. Forced: minimum delay elapsed since last checkpoint
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
    /// @notice Subtracts unfinalized proposals from total capacity
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
    /// @notice Checks deadline, proposal array, and state consistency
    /// @param _input The ProposeInput to validate
    function _validateProposeInput(ProposeInput memory _input) private view {
        require(_input.deadline == 0 || block.timestamp <= _input.deadline, DeadlineExceeded());
        require(_input.parentProposals.length > 0, EmptyProposals());
        require(block.number > _input.coreState.lastProposalBlockId, CannotProposeInCurrentBlock());
        require(
            _hashCoreState(_input.coreState) == _input.parentProposals[0].coreStateHash,
            InvalidState()
        );
    }

    /// @dev Verifies that parentProposals[0] is the current chain head
    /// @notice Requires 1 element if next slot empty, 2 if occupied with older proposal
    /// @param _parentProposals Array of 1-2 proposals to verify chain head
    function _verifyChainHead(Proposal[] memory _parentProposals) private view {
        unchecked {
            // First verify parentProposals[0] matches what's stored on-chain
            _checkProposalHash(_parentProposals[0]);

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

    /// @dev Attempts to finalize a single proposal
    /// @notice Updates core state and processes bond instructions if successful
    /// @param _coreState Core state to update (passed by reference)
    /// @param _proposalId The ID of the proposal to finalize
    /// @param _transitionRecord The expected transition record for verification
    /// @param _hasTransitionRecord Whether a transition record was provided in input
    /// @return finalized_ True if proposal was successfully finalized
    /// @return nextProposalId_ Next proposal ID to process (current + span)
    function _finalizeProposal(
        CoreState memory _coreState,
        uint48 _proposalId,
        TransitionRecord memory _transitionRecord,
        bool _hasTransitionRecord
    )
        private
        view
        returns (bool finalized_, uint48 nextProposalId_)
    {
        // Check if transition record exists in storage
        TransitionRecordHashAndDeadline memory hashAndDeadline = _getTransitionRecordHashAndDeadline(
            _proposalId, _coreState.lastFinalizedTransitionHash
        );

        if (hashAndDeadline.recordHash == 0) return (false, _proposalId);

        // If transition record is provided, allow finalization regardless of finalization grace
        // period
        // If not provided, and finalization grace period has passed, revert
        if (!_hasTransitionRecord) {
            // Check if finalization grace period has passed for forcing
            if (block.timestamp < hashAndDeadline.finalizationDeadline) {
                // Cooldown not passed, don't force finalization
                return (false, _proposalId);
            }
            // Cooldown passed, force finalization
            revert TransitionRecordNotProvided();
        }

        // Verify transition record hash matches
        require(
            _hashTransitionRecord(_transitionRecord) == hashAndDeadline.recordHash,
            TransitionRecordHashMismatchWithStorage()
        );

        // Update core state
        _coreState.lastFinalizedProposalId = _proposalId;

        // Reconstruct the Checkpoint from the transition record hash
        // Note: We need to decode the checkpointHash to get the actual header
        // For finalization, we create a transition with empty block header since we only have the
        // hash
        _coreState.lastFinalizedTransitionHash = _transitionRecord.transitionHash;

        // Process bond instructions
        for (uint256 i; i < _transitionRecord.bondInstructions.length; ++i) {
            _coreState.bondInstructionsHash = LibBonds.aggregateBondInstruction(
                _coreState.bondInstructionsHash, _transitionRecord.bondInstructions[i]
            );
        }

        // Validate and calculate next proposal ID
        require(_transitionRecord.span > 0, InvalidSpan());
        nextProposalId_ = _proposalId + _transitionRecord.span;
        require(nextProposalId_ <= _coreState.nextProposalId, SpanOutOfBounds());

        return (true, nextProposalId_);
    }
}

// ---------------------------------------------------------------
// Errors
// ---------------------------------------------------------------

error CannotProposeInCurrentBlock();
error CheckpointMismatch();
error CheckpointNotProvided();
error DeadlineExceeded();
error EmptyProposals();
error ForkNotActive();
error InconsistentParams();
error IncorrectProposalCount();
error InsufficientBond();
error InvalidLastProposalProof();
error InvalidSpan();
error InvalidState();
error LastProposalHashMismatch();
error LastProposalProofNotEmpty();
error NextProposalHashMismatch();
error NoBondToWithdraw();
error NotEnoughCapacity();
error ProposalHashMismatch();
error ProposalHashMismatchWithStorage();
error ProposalHashMismatchWithTransition();
error ProposalIdMismatch();
error ProposerBondInsufficient();
error RingBufferSizeZero();
error SpanOutOfBounds();
error TransitionRecordHashMismatchWithStorage();
error TransitionRecordNotProvided();
error UnprocessedForcedInclusionIsDue();
