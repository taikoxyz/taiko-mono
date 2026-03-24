// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBondManager } from "../iface/IBondManager.sol";
import { ICodec } from "../iface/ICodec.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { IProverWhitelist } from "../iface/IProverWhitelist.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds } from "../libs/LibBonds.sol";
import { LibCodec } from "../libs/LibCodec.sol";
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { LibHashOptimized } from "../libs/LibHashOptimized.sol";
import { LibInboxSetup } from "../libs/LibInboxSetup.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
///      - Bond accounting and liveness bond processing
///      - Finalization of proven proposals with checkpoint syncing
/// @custom:security-contact security@taiko.xyz
contract Inbox is IInbox, ICodec, IForcedInclusionStore, IBondManager, EssentialContract {
    using LibAddress for address;
    using LibBonds for LibBonds.Storage;
    using LibForcedInclusion for LibForcedInclusion.Storage;
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
    // Constants
    // ---------------------------------------------------------------

    /// @notice Maximum number of forced inclusions processed per proposal.
    /// @dev Must be < 12 to avoid derived block timestamps drifting into the future when proposals
    /// happen every L1 slot (Derivation enforces 1s block times).
    uint256 internal constant MAX_FORCED_INCLUSIONS_PER_PROPOSAL = 10;

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The proof verifier contract.
    IProofVerifier internal immutable _proofVerifier;

    /// @notice The proposer checker contract.
    IProposerChecker internal immutable _proposerChecker;

    /// @notice The prover whitelist contract (address(0) means no whitelist)
    IProverWhitelist internal immutable _proverWhitelist;

    /// @notice Signal service responsible for checkpoints.
    ISignalService internal immutable _signalService;

    /// @notice ERC20 token used as bond.
    IERC20 internal immutable _bondToken;

    /// @notice Minimum bond the proposer is required to have in gwei.
    uint64 internal immutable _minBond;

    /// @notice Liveness bond amount in gwei.
    uint64 internal immutable _livenessBond;

    /// @notice Time delay required before withdrawal after request.
    uint48 internal immutable _withdrawalDelay;

    /// @notice The proving window in seconds.
    uint48 internal immutable _provingWindow;

    /// @notice The delay after which proving becomes permissionless when whitelist is enabled.
    uint48 internal immutable _permissionlessProvingDelay;

    /// @notice Maximum delay allowed between sequential proofs to remain on time.
    uint48 internal immutable _maxProofSubmissionDelay;

    /// @notice The ring buffer size for storing proposal hashes.
    uint48 internal immutable _ringBufferSize;

    /// @notice The percentage of basefee paid to coinbase.
    uint8 internal immutable _basefeeSharingPctg;

    /// @notice The delay for forced inclusions measured in seconds.
    uint16 internal immutable _forcedInclusionDelay;

    /// @notice The base fee for forced inclusions in Gwei.
    uint64 internal immutable _forcedInclusionFeeInGwei;

    /// @notice Queue size at which the fee doubles. See Config for formula details.
    uint64 internal immutable _forcedInclusionFeeDoubleThreshold;

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

    /// @dev Storage for bond balances.
    LibBonds.Storage private _bondStorage;

    uint256[43] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    /// @param _config Configuration struct containing all constructor parameters
    constructor(Config memory _config) {
        LibInboxSetup.validateConfig(_config);

        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _proposerChecker = IProposerChecker(_config.proposerChecker);
        _proverWhitelist = IProverWhitelist(_config.proverWhitelist);
        _signalService = ISignalService(_config.signalService);
        _bondToken = IERC20(_config.bondToken);
        _minBond = _config.minBond;
        _livenessBond = _config.livenessBond;
        _withdrawalDelay = _config.withdrawalDelay;
        _provingWindow = _config.provingWindow;
        _permissionlessProvingDelay = _config.permissionlessProvingDelay;
        _maxProofSubmissionDelay = _config.maxProofSubmissionDelay;
        _ringBufferSize = _config.ringBufferSize;
        _basefeeSharingPctg = _config.basefeeSharingPctg;
        _forcedInclusionDelay = _config.forcedInclusionDelay;
        _forcedInclusionFeeInGwei = _config.forcedInclusionFeeInGwei;
        _forcedInclusionFeeDoubleThreshold = _config.forcedInclusionFeeDoubleThreshold;
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
    /// @param _lastPacayaBlockHash The block hash of the last Pacaya block
    function activate(bytes32 _lastPacayaBlockHash) external onlyOwner {
        (
            uint48 newActivationTimestamp,
            CoreState memory state,
            Proposal memory proposal,
            bytes32 genesisProposalHash
        ) = LibInboxSetup.activate(_lastPacayaBlockHash, activationTimestamp);

        activationTimestamp = newActivationTimestamp;
        _coreState = state;
        _setProposalHash(0, genesisProposalHash);
        _emitProposedEvent(proposal);
        emit InboxActivated(_lastPacayaBlockHash);
    }

    /// @inheritdoc IInbox
    /// @notice Proposes new L2 blocks and forced inclusions to the rollup using blobs for DA.
    /// @dev Key behaviors:
    ///      1. Validates proposer authorization via `IProposerChecker`
    ///      2. Processes up to `min(input.numForcedInclusions, MAX_FORCED_INCLUSIONS_PER_PROPOSAL)`
    ///         forced inclusions. If forced inclusions are due, the proposer must request at least
    ///         `min(numDue, MAX_FORCED_INCLUSIONS_PER_PROPOSAL)` forced inclusions.
    ///      3. Updates core state and emits `Proposed` event
    /// NOTE: This function can only be called once per block to prevent spams that can fill the
    /// ring buffer.
    function propose(bytes calldata _lookahead, bytes calldata _data) external nonReentrant {
        unchecked {
            ProposeInput memory input = _decodeProposeInputCalldata(_data);
            require(input.deadline == 0 || block.timestamp <= input.deadline, DeadlineExceeded());

            uint48 nextProposalId;
            uint48 lastProposalBlockId;
            uint48 lastFinalizedProposalId;
            uint256 coreSlot;
            assembly {
                coreSlot := sload(_coreState.slot)
                nextProposalId := and(coreSlot, 0xffffffffffff)
                lastProposalBlockId := and(shr(48, coreSlot), 0xffffffffffff)
                lastFinalizedProposalId := and(shr(96, coreSlot), 0xffffffffffff)
            }
            require(nextProposalId > 0, ActivationRequired());

            Proposal memory proposal = _buildProposal(
                input, _lookahead, nextProposalId, lastProposalBlockId, lastFinalizedProposalId
            );

            // Update nextProposalId and lastProposalBlockId in the packed slot
            assembly {
                // Clear bits 0-95 (nextProposalId + lastProposalBlockId) and set new values
                let cleared := and(coreSlot, not(0xffffffffffffffffffffffff))
                let newValue :=
                    or(or(cleared, add(nextProposalId, 1)), shl(48, and(number(), 0xffffffffffff)))
                sstore(_coreState.slot, newValue)
            }
            _proposalHashes[nextProposalId % _ringBufferSize] =
                LibHashOptimized.hashProposal(proposal);

            emit Proposed(
                nextProposalId,
                msg.sender,
                proposal.parentProposalHash,
                proposal.endOfSubmissionWindowTimestamp,
                _basefeeSharingPctg,
                proposal.sources
            );
        }
    }

    /// @inheritdoc IInbox
    /// @dev When the prover whitelist is enabled, only whitelisted
    ///      provers may prove until a proposal becomes older than `permissionlessProvingDelay`,
    ///      after which proving becomes permissionless for that proposal.
    /// @dev The proof covers a contiguous range of proposals. The input contains an array of
    ///      Transition structs, each with the proposal metadata and end block hash. The proof
    ///      range can start at or before the last finalized proposal to handle race conditions
    ///      where proposals get finalized between proof generation and submission.
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

            // Read packed _coreState slot via assembly to avoid memory struct allocation
            uint256 coreSlot0;
            assembly {
                coreSlot0 := sload(_coreState.slot)
            }

            // -------------------------------------------------------------------------------
            // 1. Validate batch bounds and calculate offset of the first unfinalized proposal
            // -------------------------------------------------------------------------------
            Commitment memory commitment = _decodeCommitmentCalldata(_data);

            uint256 numProposals = commitment.transitions.length;
            require(numProposals > 0, EmptyBatch());
            // lastFinalizedProposalId at bits 96-143, nextProposalId at bits 0-47
            require(
                commitment.firstProposalId <= ((coreSlot0 >> 96) & 0xffffffffffff) + 1,
                FirstProposalIdTooLarge()
            );

            uint256 lastProposalId = commitment.firstProposalId + numProposals - 1;
            require(lastProposalId < (coreSlot0 & 0xffffffffffff), LastProposalIdTooLarge());
            require(
                lastProposalId >= ((coreSlot0 >> 96) & 0xffffffffffff) + 1,
                LastProposalAlreadyFinalized()
            );

            uint48 offset =
                uint48(((coreSlot0 >> 96) & 0xffffffffffff) + 1 - commitment.firstProposalId);

            uint256 proposalAge = block.timestamp - commitment.transitions[offset].timestamp;
            bool isWhitelistEnabled;
            {
                IProverWhitelist pw = _proverWhitelist;
                if (address(pw) != address(0)) {
                    (bool isWhitelisted, uint256 proverCount) =
                        pw.isProverWhitelisted(msg.sender);
                    if (proverCount > 0) {
                        if (!isWhitelisted) {
                            require(
                                proposalAge > uint256(_permissionlessProvingDelay),
                                ProverNotWhitelisted()
                            );
                        }
                        isWhitelistEnabled = true;
                    }
                }
            }

            // ---------------------------------------------------------
            // 2. Verify parent block-hash continuity and last proposal hash
            // ---------------------------------------------------------
            // The parent block hash must match the stored lastFinalizedBlockHash.
            bytes32 expectedParentHash = offset == 0
                ? commitment.firstProposalParentBlockHash
                : commitment.transitions[offset - 1].blockHash;
            require(
                _coreState.lastFinalizedBlockHash == expectedParentHash, ParentBlockHashMismatch()
            );

            require(
                commitment.lastProposalHash
                    == _proposalHashes[lastProposalId % _ringBufferSize],
                LastProposalHashMismatch()
            );

            // ---------------------------------------------------------
            // 3. Process bond instruction
            // ---------------------------------------------------------
            // Bond transfers only apply when whitelist is not enabled.
            if (!isWhitelistEnabled) {
                uint256 a = (block.timestamp - proposalAge) + _provingWindow;
                // lastFinalizedTimestamp is at bits 144-191
                uint256 b = ((coreSlot0 >> 144) & 0xffffffffffff) + _maxProofSubmissionDelay;
                uint256 livenessWindowDeadline = a > b ? a : b;

                if (block.timestamp > livenessWindowDeadline) {
                    _bondStorage.settleLivenessBond(
                        commitment.transitions[offset].proposer,
                        commitment.actualProver,
                        _livenessBond
                    );
                }
            }

            // -----------------------------------------------------------------------------
            // 4. Sync checkpoint
            // -----------------------------------------------------------------------------
            bytes32 lastBlockHash = commitment.transitions[numProposals - 1].blockHash;
            _signalService.saveCheckpoint(
                ICheckpointStore.Checkpoint({
                    blockNumber: commitment.endBlockNumber,
                    stateRoot: commitment.endStateRoot,
                    blockHash: lastBlockHash
                })
            );
            // ---------------------------------------------------------
            // 5. Update core state and emit event
            // ---------------------------------------------------------
            // Write packed slot 252: preserve nextProposalId (bits 0-47) and
            // lastProposalBlockId (bits 48-95), update lastFinalizedProposalId (96-143),
            // lastFinalizedTimestamp (144-191), lastCheckpointTimestamp (192-239)
            {
                uint256 ts48 = block.timestamp & 0xffffffffffff;
                assembly {
                    // Preserve bits 0-95 (nextProposalId + lastProposalBlockId) from cached read
                    let preserved := and(coreSlot0, 0xffffffffffffffffffffffff)
                    let newSlot :=
                        or(
                            or(
                                or(preserved, shl(96, and(lastProposalId, 0xffffffffffff))),
                                shl(144, ts48)
                            ),
                            shl(192, ts48)
                        )
                    sstore(_coreState.slot, newSlot)
                    // Write slot 253: lastFinalizedBlockHash
                    sstore(add(_coreState.slot, 1), lastBlockHash)
                }
            }

            emit Proved(
                commitment.firstProposalId,
                commitment.firstProposalId + offset,
                uint48(lastProposalId),
                commitment.actualProver
            );

            // ---------------------------------------------------------
            // 6. Verify the proof
            // ---------------------------------------------------------
            // For multi-proposal batches (more than 1 unfinalized proposal), pass 0 to verifier.
            // Single-proposal proofs pass actual age for age-based verification logic.
            _proofVerifier.verifyProof(
                numProposals - offset == 1 ? proposalAge : 0,
                LibHashOptimized.hashCommitment(commitment),
                _proof
            );
        }
    }

    /// @inheritdoc IBondManager
    function deposit(uint64 _amount) external nonReentrant {
        _bondStorage.deposit(_bondToken, msg.sender, msg.sender, _amount, true);
    }

    /// @inheritdoc IBondManager
    function depositTo(address _recipient, uint64 _amount) external nonReentrant {
        _bondStorage.deposit(_bondToken, msg.sender, _recipient, _amount, false);
    }

    /// @inheritdoc IBondManager
    function withdraw(address _to, uint64 _amount) external nonReentrant {
        _bondStorage.withdraw(_bondToken, msg.sender, _to, _amount, _minBond, _withdrawalDelay);
    }

    /// @inheritdoc IBondManager
    function requestWithdrawal() external nonReentrant {
        _bondStorage.requestWithdrawal(msg.sender, _withdrawalDelay);
    }

    /// @inheritdoc IBondManager
    function cancelWithdrawal() external nonReentrant {
        _bondStorage.cancelWithdrawal(msg.sender);
    }

    /// @inheritdoc IForcedInclusionStore
    /// @dev This function will revert if called before the first non-activation proposal is
    /// submitted to make sure blocks have been produced already and the derivation can use the
    /// parent's block timestamp.
    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable {
        bytes32 proposalHash = _proposalHashes[1];
        require(proposalHash != bytes32(0), IncorrectProposalCount());

        uint256 refund = _forcedInclusionStorage.saveForcedInclusion(
            _forcedInclusionFeeInGwei, _forcedInclusionFeeDoubleThreshold, _blobReference
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
    /// @inheritdoc IBondManager
    function getBond(address _address) external view returns (Bond memory bond_) {
        return _bondStorage.getBond(_address);
    }

    /// @inheritdoc IForcedInclusionStore
    function getCurrentForcedInclusionFee() external view returns (uint64 feeInGwei_) {
        return _forcedInclusionStorage.getCurrentForcedInclusionFee(
            _forcedInclusionFeeInGwei, _forcedInclusionFeeDoubleThreshold
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
        return _forcedInclusionStorage.getForcedInclusions(_start, _maxCount);
    }

    /// @inheritdoc IForcedInclusionStore
    function getForcedInclusionState() external view returns (uint48 head_, uint48 tail_) {
        return _forcedInclusionStorage.getForcedInclusionState();
    }

    /// @inheritdoc IInbox
    function getConfig() external view returns (Config memory config_) {
        config_ = Config({
            proofVerifier: address(_proofVerifier),
            proposerChecker: address(_proposerChecker),
            proverWhitelist: address(_proverWhitelist),
            signalService: address(_signalService),
            bondToken: address(_bondToken),
            minBond: _minBond,
            livenessBond: _livenessBond,
            withdrawalDelay: _withdrawalDelay,
            provingWindow: _provingWindow,
            permissionlessProvingDelay: _permissionlessProvingDelay,
            maxProofSubmissionDelay: _maxProofSubmissionDelay,
            ringBufferSize: _ringBufferSize,
            basefeeSharingPctg: _basefeeSharingPctg,
            forcedInclusionDelay: _forcedInclusionDelay,
            forcedInclusionFeeInGwei: _forcedInclusionFeeInGwei,
            forcedInclusionFeeDoubleThreshold: _forcedInclusionFeeDoubleThreshold,
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

    /// @dev Builds proposal and derivation data.
    /// This function also checks:
    /// - If `msg.sender` can propose.
    /// - If `msg.sender` has sufficient bond.
    /// @param _input The propose input data.
    /// @param _lookahead Encoded data forwarded to the proposer checker (i.e. lookahead payloads).
    /// @param _nextProposalId The proposal ID to assign.
    /// @param _lastProposalBlockId The last block number where a proposal was made.
    /// @param _lastFinalizedProposalId The ID of the last finalized proposal.
    /// @return proposal_ The proposal with final endOfSubmissionWindowTimestamp set.
    function _buildProposal(
        ProposeInput memory _input,
        bytes calldata _lookahead,
        uint48 _nextProposalId,
        uint48 _lastProposalBlockId,
        uint48 _lastFinalizedProposalId
    )
        private
        returns (Proposal memory proposal_)
    {
        unchecked {
            // Enforce one propose call per Ethereum block to prevent spam attacks that could
            // deplete the ring buffer
            require(block.number > _lastProposalBlockId, CannotProposeInCurrentBlock());
            require(
                _ringBufferSize > _nextProposalId - _lastFinalizedProposalId, NotEnoughCapacity()
            );

            ConsumptionResult memory result =
                _consumeForcedInclusions(msg.sender, _input.numForcedInclusions);

            result.sources[result.sources.length - 1] =
                DerivationSource(false, LibBlobs.validateBlobReference(_input.blobReference));

            // If forced inclusion is old enough, allow anyone to propose
            // set endOfSubmissionWindowTimestamp = 0, and do not require a bond
            // Otherwise, only the current preconfer can propose
            uint48 endOfSubmissionWindowTimestamp;
            if (!result.allowsPermissionless) {
                endOfSubmissionWindowTimestamp =
                    _proposerChecker.checkProposer(msg.sender, _lookahead);
                if (_minBond > 0) {
                    // Only if there is a minimum bond set, execute this check
                    require(
                        _bondStorage.hasSufficientBond(msg.sender, _minBond), InsufficientBond()
                    );
                }
            }

            // Use previous block as the origin for the proposal to be able to call `blockhash`
            uint256 parentBlockNumber = block.number - 1;
            proposal_ = Proposal({
                id: _nextProposalId,
                timestamp: uint48(block.timestamp),
                endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
                proposer: msg.sender,
                parentProposalHash: _proposalHashes[(_nextProposalId - 1) % _ringBufferSize],
                originBlockNumber: uint48(parentBlockNumber),
                originBlockHash: blockhash(parentBlockNumber),
                basefeeSharingPctg: _basefeeSharingPctg,
                sources: result.sources
            });
        }
    }

    /// @dev Stores a proposal hash in the ring buffer
    /// Overwrites any existing hash at the calculated buffer slot
    function _setProposalHash(uint48 _proposalId, bytes32 _proposalHash) private {
        _proposalHashes[_proposalId % _ringBufferSize] = _proposalHash;
    }

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
            (uint48 head, uint48 tail) = ($.head, $.tail);

            uint256 available = tail - head;

            // Fast path: empty queue — no forced inclusions to inspect or process
            if (available == 0) {
                result_.sources = new DerivationSource[](1);
                return result_;
            }

            uint256 dueToProcess;
            uint256 maxToInspect = available.min(MAX_FORCED_INCLUSIONS_PER_PROPOSAL);
            for (uint256 i; i < maxToInspect; ++i) {
                IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[head + i];
                uint256 timestamp = inclusion.blobSlice.timestamp;
                if (timestamp == 0 || block.timestamp < timestamp + uint256(_forcedInclusionDelay))
                {
                    break;
                }
                ++dueToProcess;
            }
            require(
                _numForcedInclusionsRequested >= dueToProcess, UnprocessedForcedInclusionIsDue()
            );

            uint256 toProcess = _numForcedInclusionsRequested.min(available)
                .min(MAX_FORCED_INCLUSIONS_PER_PROPOSAL);

            result_.sources = new DerivationSource[](toProcess + 1);

            if (toProcess != 0) {
                uint48 oldestTimestamp;
                (oldestTimestamp, head) = _dequeueAndProcessForcedInclusions(
                    $, _feeRecipient, result_.sources, head, toProcess
                );

                uint256 permissionlessTimestamp = uint256(_forcedInclusionDelay)
                    * _permissionlessInclusionMultiplier + oldestTimestamp;
                result_.allowsPermissionless = block.timestamp > permissionlessTimestamp;
            }
        }
    }

    /// @dev Dequeues and processes forced inclusions from the queue without checking if they exist
    /// @param $ Storage reference
    /// @param _feeRecipient Address to receive fees
    /// @param _sources Array to populate with derivation sources
    /// @param _head Current queue head position
    /// @param _toProcess Number of inclusions to process
    /// @return oldestTimestamp_ Oldest timestamp from processed inclusions.
    /// `type(uint48).max` if no inclusions were processed
    /// @return head_ Updated head position
    function _dequeueAndProcessForcedInclusions(
        LibForcedInclusion.Storage storage $,
        address _feeRecipient,
        DerivationSource[] memory _sources,
        uint48 _head,
        uint256 _toProcess
    )
        private
        returns (uint48 oldestTimestamp_, uint48 head_)
    {
        unchecked {
            if (_toProcess == 0) {
                return (type(uint48).max, _head);
            }

            // Process inclusions and accumulate fees
            uint256 totalFees;
            for (uint256 i; i < _toProcess; ++i) {
                IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[_head + i];
                _sources[i] = IInbox.DerivationSource(true, inclusion.blobSlice);
                totalFees += inclusion.feeInGwei;
            }

            // Transfer accumulated fees
            _feeRecipient.sendEtherAndVerify(totalFees * 1 gwei);

            // Oldest timestamp is the timestamp of the first inclusion
            oldestTimestamp_ = uint48(_sources[0].blobSlice.timestamp);

            // Update queue position
            head_ = _head + uint48(_toProcess);

            // Write to storage once
            $.head = head_;
        }
    }

    /// @dev Emits the Proposed event
    function _emitProposedEvent(Proposal memory _proposal) private {
        emit Proposed(
            _proposal.id,
            _proposal.proposer,
            _proposal.parentProposalHash,
            _proposal.endOfSubmissionWindowTimestamp,
            _proposal.basefeeSharingPctg,
            _proposal.sources
        );
    }

    // ---------------------------------------------------------------
    // Private Pure Functions
    // ---------------------------------------------------------------

    /// @dev Decodes ProposeInput directly from calldata using assembly,
    /// avoiding the calldata→memory copy overhead of LibCodec.decodeProposeInput.
    /// Packed format (15 bytes): deadline(6) | blobStartIndex(2) | numBlobs(2) | offset(3) |
    /// numForcedInclusions(2)
    function _decodeProposeInputCalldata(bytes calldata _data)
        private
        pure
        returns (ProposeInput memory input_)
    {
        assembly {
            let word := calldataload(_data.offset)
            // deadline: top 6 bytes (bits 255-208)
            mstore(input_, shr(208, word))
            // numForcedInclusions: 2 bytes at offset 13 (bits 151-136)
            mstore(add(input_, 0x40), and(shr(136, word), 0xffff))
            // BlobReference: pointer is pre-allocated at input_ + 0x20
            let blobRef := mload(add(input_, 0x20))
            // blobStartIndex: 2 bytes at offset 6 (bits 207-192)
            mstore(blobRef, and(shr(192, word), 0xffff))
            // numBlobs: 2 bytes at offset 8 (bits 191-176)
            mstore(add(blobRef, 0x20), and(shr(176, word), 0xffff))
            // offset: 3 bytes at offset 10 (bits 175-152)
            mstore(add(blobRef, 0x40), and(shr(152, word), 0xffffff))
        }
    }

    /// @dev Decodes Commitment directly from calldata using assembly,
    /// avoiding the calldata→memory copy of LibCodec.decodeProveInput.
    /// Packed format: firstProposalId(6) | firstProposalParentBlockHash(32) | lastProposalHash(32)
    /// | actualProver(20) | endBlockNumber(6) | endStateRoot(32) | transitionsLength(2)
    /// | [proposer(20) | timestamp(6) | blockHash(32)] per transition
    function _decodeCommitmentCalldata(bytes calldata _data)
        private
        pure
        returns (Commitment memory c_)
    {
        assembly {
            let off := _data.offset

            // Static fields
            mstore(c_, shr(208, calldataload(off))) // firstProposalId (6 bytes)
            off := add(off, 6)
            mstore(add(c_, 0x20), calldataload(off)) // firstProposalParentBlockHash (32 bytes)
            off := add(off, 32)
            mstore(add(c_, 0x40), calldataload(off)) // lastProposalHash (32 bytes)
            off := add(off, 32)
            mstore(add(c_, 0x60), shr(96, calldataload(off))) // actualProver (20 bytes)
            off := add(off, 20)
            mstore(add(c_, 0x80), shr(208, calldataload(off))) // endBlockNumber (6 bytes)
            off := add(off, 6)
            mstore(add(c_, 0xa0), calldataload(off)) // endStateRoot (32 bytes)
            off := add(off, 32)

            // Transitions array
            let tLen := shr(240, calldataload(off)) // transitionsLength (2 bytes)
            off := add(off, 2)

            // Allocate transitions array: [length, ptr0, ptr1, ...]
            let fmp := mload(0x40)
            let arrPtr := fmp
            mstore(arrPtr, tLen) // array length
            fmp := add(arrPtr, add(0x20, mul(tLen, 0x20))) // space for length + pointers

            // Allocate and populate each Transition struct
            for { let i := 0 } lt(i, tLen) { i := add(i, 1) } {
                let tPtr := fmp
                // Store pointer in array
                mstore(add(arrPtr, add(0x20, mul(i, 0x20))), tPtr)

                // proposer (20 bytes)
                mstore(tPtr, shr(96, calldataload(off)))
                off := add(off, 20)
                // timestamp (6 bytes)
                mstore(add(tPtr, 0x20), shr(208, calldataload(off)))
                off := add(off, 6)
                // blockHash (32 bytes)
                mstore(add(tPtr, 0x40), calldataload(off))
                off := add(off, 32)

                fmp := add(fmp, 0x60) // 3 words per Transition
            }

            // Store transitions array pointer in commitment
            mstore(add(c_, 0xc0), arrPtr)
            // Update free memory pointer
            mstore(0x40, fmp)
        }
    }

    // ---------------------------------------------------------------
    // Reentrancy Guard Override (Transient Storage)
    // ---------------------------------------------------------------

    /// @dev Override to use transient storage for reentrancy guard, saving ~5700 gas per call.
    /// Uses slot keccak256("inbox.reentrancy.lock") to avoid collisions.
    function _storeReentryLock(uint8 _reentry) internal virtual override {
        assembly {
            // keccak256("inbox.reentrancy.lock")
            tstore(0x691f39feb0fa536d498d67e7a80a2cc597ecf24f8dbb2e2d1c0d4bb3e5cfe1be, _reentry)
        }
    }

    /// @dev Override to use transient storage for reentrancy guard.
    function _loadReentryLock() internal view virtual override returns (uint8 reentry_) {
        assembly {
            reentry_ := tload(
                0x691f39feb0fa536d498d67e7a80a2cc597ecf24f8dbb2e2d1c0d4bb3e5cfe1be
            )
        }
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
    error InsufficientBond();
    error LastProposalAlreadyFinalized();
    error LastProposalHashMismatch();
    error LastProposalIdTooLarge();
    error NotEnoughCapacity();
    error ParentBlockHashMismatch();
    error ProverNotWhitelisted();
    error UnprocessedForcedInclusionIsDue();
}
