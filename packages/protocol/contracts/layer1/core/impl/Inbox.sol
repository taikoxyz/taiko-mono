// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBondInstruction } from "../libs/LibBondInstruction.sol";
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { LibHashOptimized } from "../libs/LibHashOptimized.sol";
import { LibInboxSetup } from "../libs/LibInboxSetup.sol";
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

    /// @notice The codec used for encoding and hashing.
    address internal immutable _codec;

    /// @notice The proof verifier contract.
    IProofVerifier internal immutable _proofVerifier;

    /// @notice The proposer checker contract.
    IProposerChecker internal immutable _proposerChecker;

    /// @notice Signal service responsible for checkpoints and bond signals.
    ISignalService internal immutable _signalService;

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

    /// @notice Queue size at which the fee doubles. See Config for formula details.
    uint64 internal immutable _forcedInclusionFeeDoubleThreshold;

    /// @notice The minimum delay between checkpoints in seconds.
    uint16 internal immutable _minCheckpointDelay;

    /// @notice The multiplier to determine when a forced inclusion is too old so that proposing
    /// becomes permissionless
    uint8 internal immutable _permissionlessInclusionMultiplier;

    /// @notice The minimum number of proposals that must be finalized in a single prove call.
    uint8 internal immutable _minProposalsToFinalize;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The timestamp when the first activation occurred.
    uint48 public activationTimestamp;

    /// @notice Persisted core state (all uint48 fields packed into single slot).
    CoreState public coreState;

    /// @notice The hash of the last finalized block (separate slot for gas optimization).
    bytes32 public lastFinalizedBlockHash;

    /// @dev Ring buffer for storing proposal hashes indexed by buffer slot
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - proposalHash: The keccak256 hash of the Proposal struct
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev Storage for forced inclusion requests
    /// @dev 2 slots used
    LibForcedInclusion.Storage private _forcedInclusionStorage;

    uint256[36] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    /// @param _config Configuration struct containing all constructor parameters
    constructor(Config memory _config) {
        LibInboxSetup.validateConfig(_config);

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
        _minProposalsToFinalize = _config.minProposalsToFinalize;
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
        (
            uint48 newActivationTimestamp,
            CoreState memory state,
            Derivation memory derivation,
            Proposal memory proposal,
            bytes32 genesisProposalHash
        ) = LibInboxSetup.activate(_lastPacayaBlockHash, activationTimestamp);

        activationTimestamp = newActivationTimestamp;
        coreState = state;
        lastFinalizedBlockHash = _lastPacayaBlockHash;
        _setProposalHash(0, genesisProposalHash);
        _emitProposedEvent(proposal, derivation);
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
    function propose(bytes calldata _lookahead, bytes calldata _data) external nonReentrant {
        unchecked {
            ProposeInput memory input = LibProposeInputCodec.decode(_data);
            _validateProposeInput(input);

            // Load entire CoreState into memory once (single SLOAD for the packed slot)
            CoreState memory state = coreState;
            require(state.nextProposalId != 0, ActivationRequired());

            (Proposal memory proposal, Derivation memory derivation) = _buildProposal(
                input,
                _lookahead,
                state.nextProposalId,
                state.lastProposalBlockId,
                state.lastFinalizedProposalId
            );

            // Update memory struct
            state.nextProposalId += 1;
            state.lastProposalBlockId = uint48(block.number);

            // Write entire CoreState back once (single SSTORE for the packed slot)
            coreState = state;
            _setProposalHash(proposal.id, LibHashOptimized.hashProposal(proposal));

            _emitProposedEvent(proposal, derivation);
        }
    }

    /// @dev Verifies a batch proof covering multiple consecutive proposals and finalizes them.
    ///
    /// The proof covers a contiguous range of proposals. The input contains an array of
    /// ProposalState structs, each with the proposal's metadata and block hash. The proof range
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
    ///                       ┆<-  input.proposalStates[] ->┆
    ///         firstProposalId                             lastProposalId
    ///
    /// Key validation rules:
    /// 1. firstProposalId <= lastFinalizedProposalId + 1 (can overlap with finalized range)
    /// 2. lastProposalId < nextProposalId (cannot prove unproposed blocks)
    /// 3. lastProposalId >= lastFinalizedProposalId + minProposalsToFinalize (must advance enough)
    /// 4. The block hash chain must link to the stored lastFinalizedBlockHash
    ///
    /// @param _data Encoded ProveInput struct
    /// @param _proof Validity proof for the batch of proposals
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        unchecked {
            // Load entire CoreState into memory once (single SLOAD for the packed slot)
            CoreState memory state = coreState;
            require(state.nextProposalId != 0, ActivationRequired());

            ProveInput memory input = LibProveInputCodec.decode(_data);

            // ---------------------------------------------------------
            // 1. Validate batch bounds
            // ---------------------------------------------------------
            uint256 numProposals = input.proposalStates.length;
            require(numProposals > 0, EmptyBatch());
            require(
                input.firstProposalId <= state.lastFinalizedProposalId + 1,
                FirstProposalIdTooLarge()
            );

            uint256 lastProposalId = input.firstProposalId + numProposals - 1;
            require(lastProposalId < state.nextProposalId, LastProposalIdTooLarge());
            require(
                lastProposalId >= state.lastFinalizedProposalId + _minProposalsToFinalize,
                LastProposalIdTooSmall()
            );

            // ---------------------------------------------------------
            // 2. Calculate offset to first unfinalized proposal
            // ---------------------------------------------------------
            // Some proposals in input.proposalStates[] may already be finalized.
            // The offset points to the first proposal that will be newly finalized.
            uint48 offset = state.lastFinalizedProposalId + 1 - input.firstProposalId;

            // ---------------------------------------------------------
            // 3. Verify block hash continuity
            // ---------------------------------------------------------
            // The parent block hash must match the stored lastFinalizedBlockHash.
            {
                bytes32 expectedParentHash = offset == 0
                    ? input.firstProposalParentBlockHash
                    : input.proposalStates[offset - 1].blockHash;
                require(lastFinalizedBlockHash == expectedParentHash, ParentBlockHashMismatch());
            }

            // ---------------------------------------------------------
            // 4. Verify the last proposal hash
            // ---------------------------------------------------------
            require(
                input.lastProposalHash == _proposalHashes[lastProposalId % _ringBufferSize],
                LastProposalHashMismatch()
            );

            // ---------------------------------------------------------
            // 5. Calculate proposal age and bond instruction
            // ---------------------------------------------------------
            uint256 proposalAge;
            {
                ProposalState memory firstProposal = input.proposalStates[offset];
                proposalAge =
                    block.timestamp - firstProposal.timestamp.max(state.lastFinalizedTimestamp);

                // Bond transfers only apply to the first newly-finalized proposal.
                LibBonds.BondInstruction memory bondInstruction =
                    LibBondInstruction.calculateBondInstruction(
                        input.firstProposalId + offset,
                        proposalAge,
                        firstProposal.proposer,
                        firstProposal.designatedProver,
                        input.actualProver,
                        _provingWindow,
                        _extendedProvingWindow
                    );
                if (bondInstruction.bondType != LibBonds.BondType.NONE) {
                    _signalService.sendSignal(LibBonds.hashBondInstruction(bondInstruction));
                    emit BondInstructionCreated(bondInstruction.proposalId, bondInstruction);
                }
            }

            // ---------------------------------------------------------
            // 6. Sync checkpoint if minimum delay has passed
            // ---------------------------------------------------------
            if (block.timestamp >= state.lastCheckpointTimestamp + _minCheckpointDelay) {
                _signalService.saveCheckpoint(
                    ICheckpointStore.Checkpoint({
                        blockNumber: input.lastBlockNumber,
                        blockHash: input.proposalStates[numProposals - 1].blockHash,
                        stateRoot: input.lastStateRoot
                    })
                );
                state.lastCheckpointTimestamp = uint48(block.timestamp);
            }

            // ---------------------------------------------------------
            // 7. Update core state and emit event
            // ---------------------------------------------------------
            state.lastFinalizedProposalId = uint48(lastProposalId);
            state.lastFinalizedTimestamp = uint48(block.timestamp);

            // Write entire CoreState back once (single SSTORE for the packed slot)
            coreState = state;
            // Write lastFinalizedBlockHash separately (separate storage slot)
            lastFinalizedBlockHash = input.proposalStates[numProposals - 1].blockHash;

            emit Proved(LibProvedEventCodec.encode(ProvedEventPayload({ input: input })));

            // ---------------------------------------------------------
            // 8. Verify the proof
            // ---------------------------------------------------------
            _proofVerifier.verifyProof(proposalAge, LibHashOptimized.hashProveInput(input), _proof);
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
    /// @dev Note that due to the ring buffer nature of the `_proposalHashes` mapping proposals
    /// may have been overwritten by a new one. You should verify that the hash matches the
    /// expected proposal.
    /// @param _proposalId The ID of the proposal to query
    /// @return proposalHash_ The keccak256 hash of the Proposal struct at the ring buffer slot
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_) {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        proposalHash_ = _proposalHashes[bufferSlot];
    }

    /// @inheritdoc IInbox
    function getConfig() external view returns (Config memory config_) {
        config_ = Config({
            codec: _codec,
            proofVerifier: address(_proofVerifier),
            proposerChecker: address(_proposerChecker),
            signalService: address(_signalService),
            provingWindow: _provingWindow,
            extendedProvingWindow: _extendedProvingWindow,
            ringBufferSize: _ringBufferSize,
            basefeeSharingPctg: _basefeeSharingPctg,
            minForcedInclusionCount: _minForcedInclusionCount,
            forcedInclusionDelay: _forcedInclusionDelay,
            forcedInclusionFeeInGwei: _forcedInclusionFeeInGwei,
            forcedInclusionFeeDoubleThreshold: _forcedInclusionFeeDoubleThreshold,
            minCheckpointDelay: _minCheckpointDelay,
            permissionlessInclusionMultiplier: _permissionlessInclusionMultiplier,
            minProposalsToFinalize: _minProposalsToFinalize
        });
    }

    /// @notice Returns the core state as a struct (convenience wrapper for tests).
    /// @dev The public `coreState` variable returns a tuple; this returns the struct.
    function getCoreState() external view returns (CoreState memory) {
        return coreState;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Builds proposal and derivation data. It also checks if `msg.sender` can propose.
    /// @param _input The propose input data.
    /// @param _lookahead Encoded data forwarded to the proposer checker (i.e. lookahead payloads).
    /// @param _nextProposalId The proposal ID to assign.
    /// @param _lastProposalBlockId The last block number where a proposal was made.
    /// @param _lastFinalizedProposalId The ID of the last finalized proposal.
    /// @return proposal_ The proposal with final endOfSubmissionWindowTimestamp and derivation
    /// hash set.
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

            // Get the parent proposal hash from the ring buffer
            bytes32 parentProposalHash = _proposalHashes[(_nextProposalId - 1) % _ringBufferSize];

            proposal_ = Proposal({
                id: _nextProposalId,
                timestamp: uint48(block.timestamp),
                endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
                proposer: msg.sender,
                parentProposalHash: parentProposalHash,
                derivationHash: LibHashOptimized.hashDerivation(derivation_)
            });
        }
    }

    /// @dev Stores a proposal hash in the ring buffer
    /// Overwrites any existing hash at the calculated buffer slot
    function _setProposalHash(uint48 _proposalId, bytes32 _proposalHash) internal {
        _proposalHashes[_proposalId % _ringBufferSize] = _proposalHash;
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

            result_.sources = new DerivationSource[](toProcess + 1);

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
        DerivationSource[] memory _sources,
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
                    _sources[i] = DerivationSource(true, inclusion.blobSlice);
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

    /// @dev Validates propose function inputs.
    /// @param _input The ProposeInput to validate
    function _validateProposeInput(ProposeInput memory _input) private view {
        require(_input.deadline == 0 || block.timestamp <= _input.deadline, DeadlineExceeded());
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------
    error ActivationRequired();
    error CannotProposeInCurrentBlock();
    error DeadlineExceeded();
    error EmptyBatch();
    error FirstProposalIdTooLarge();
    error IncorrectProposalCount();
    error LastProposalIdTooLarge();
    error LastProposalHashMismatch();
    error LastProposalIdTooSmall();
    error NotEnoughCapacity();
    error ParentBlockHashMismatch();
    error UnprocessedForcedInclusionIsDue();
}
