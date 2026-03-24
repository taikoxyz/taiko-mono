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

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event InboxActivated(bytes32 lastPacayaBlockHash);

    /// @notice Gas-efficient Proposed event for the fast path (single blob, no forced inclusions).
    /// @dev Minimal data: parentProposalHash and endOfSubmissionWindowTimestamp are derivable
    ///      on-chain (from previous proposal and proposerChecker state respectively).
    ///      Off-chain indexers should handle both Proposed and ProposedFast events.
    event ProposedFast(
        uint48 indexed id,
        bytes32 blobHash,
        uint256 packed // bfsPctg(8) | blobOffset(24) | blobTimestamp(48) in top 80 bits
    );

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
            // Decode calldata as raw word — avoid ProposeInput struct allocation in fast path
            uint256 calldataWord;
            assembly {
                calldataWord := calldataload(_data.offset)
                let dl := shr(208, calldataWord)
                // require(deadline == 0 || block.timestamp <= deadline)
                if dl {
                    if gt(timestamp(), dl) {
                        mstore(0x00, 0x559895a3) // DeadlineExceeded()
                        revert(0x1c, 0x04)
                    }
                }
            }

            uint48 nextProposalId;
            uint256 coreSlot;
            uint256 rbs = _ringBufferSize;
            bool queueEmpty;
            assembly {
                coreSlot := sload(_coreState.slot)
                nextProposalId := and(coreSlot, 0xffffffffffff)
                // require(nextProposalId > 0)
                if iszero(nextProposalId) {
                    mstore(0x00, 0xba74d80f) // ActivationRequired()
                    revert(0x1c, 0x04)
                }
                // require(block.number > lastProposalBlockId)
                if iszero(gt(number(), and(shr(48, coreSlot), 0xffffffffffff))) {
                    mstore(0x00, 0x92a2f43a) // CannotProposeInCurrentBlock()
                    revert(0x1c, 0x04)
                }
                // require(rbs > nextProposalId - lastFinalizedProposalId)
                if iszero(gt(rbs, sub(nextProposalId, and(shr(96, coreSlot), 0xffffffffffff)))) {
                    mstore(0x00, 0xeaabac9b) // NotEnoughCapacity()
                    revert(0x1c, 0x04)
                }
                // Check if forced inclusion queue is empty (head == tail)
                let packed := sload(add(_forcedInclusionStorage.slot, 1))
                queueEmpty := eq(and(packed, 0xffffffffffff), and(shr(48, packed), 0xffffffffffff))
            }

            // Fast path: empty queue + single blob — build entire sources chain in assembly
            DerivationSource[] memory sources;
            bool allowsPermissionless;
            {
                if (queueEmpty) {
                    // Minimal blob construction: only store values at offsets expected by
                    // hash and emit assembly blocks (sub(sources, 0xc0/0x80/0x60))
                    assembly {
                        // Decode blob fields directly from calldataWord — skip struct
                        let blobStartIndex := and(shr(192, calldataWord), 0xffff)
                        let numBlobs := and(shr(176, calldataWord), 0xffff)
                        let blobOffset := and(shr(152, calldataWord), 0xffffff)

                        // require(numBlobs > 0)
                        if iszero(numBlobs) {
                            mstore(0x00, 0x27a0cc69) // NoBlobs()
                            revert(0x1c, 0x04)
                        }

                        let fmp := mload(0x40)

                        // Single-blob fast path: skip struct chain, store raw values
                        // Memory layout: [.][blobHash0][.][offset][timestamp][...] sources@fmp+0xe0
                        // Hash/emit read: sub(sources,0xc0)=fmp+0x20, sub(sources,0x80)=fmp+0x60,
                        //                 sub(sources,0x60)=fmp+0x80
                        let h := blobhash(blobStartIndex)
                        if iszero(h) {
                            mstore(0x00, 0x8f84fb24) // BlobNotFound()
                            revert(0x1c, 0x04)
                        }
                        mstore(add(fmp, 0x20), h) // blobHash0
                        mstore(add(fmp, 0x60), blobOffset) // blobSlice.offset
                        mstore(add(fmp, 0x80), timestamp()) // blobSlice.timestamp

                        // Validate remaining blobs if multi-blob
                        for { let i := 1 } lt(i, numBlobs) { i := add(i, 1) } {
                            if iszero(blobhash(add(blobStartIndex, i))) {
                                mstore(0x00, 0x8f84fb24) // BlobNotFound()
                                revert(0x1c, 0x04)
                            }
                        }

                        sources := add(fmp, 0xe0)
                        mstore(0x40, add(fmp, 0x100))
                    }
                } else {
                    // Slow path: reconstruct ProposeInput from calldataWord
                    ProposeInput memory input;
                    assembly {
                        let blobRef := mload(add(input, 0x20))
                        mstore(blobRef, and(shr(192, calldataWord), 0xffff))
                        mstore(add(blobRef, 0x20), and(shr(176, calldataWord), 0xffff))
                        mstore(add(blobRef, 0x40), and(shr(152, calldataWord), 0xffffff))
                        mstore(add(input, 0x40), and(shr(136, calldataWord), 0xffff))
                    }
                    LibBlobs.BlobSlice memory blobSlice =
                        LibBlobs.validateBlobReference(input.blobReference);
                    (sources, allowsPermissionless) =
                        _consumeForcedInclusions(msg.sender, input.numForcedInclusions);
                    sources[sources.length - 1] = DerivationSource(false, blobSlice);
                }
            }

            uint48 endOfSubmissionWindowTimestamp;
            if (!allowsPermissionless) {
                endOfSubmissionWindowTimestamp = _checkProposer(msg.sender, _lookahead);
                if (_minBond > 0) {
                    require(
                        _bondStorage.hasSufficientBond(msg.sender, _minBond), InsufficientBond()
                    );
                }
            }

            // Build keccak256 hash buffer directly — skip Proposal struct allocation
            // Layout matches abi.encode(Proposal) for 1-source-1-blobHash case
            uint8 bfsPctg = _basefeeSharingPctg;
            bytes32 parentProposalHash;
            assembly {
                // Read parent proposal hash from ring buffer
                mstore(0x00, mod(sub(nextProposalId, 1), rbs))
                mstore(0x20, _proposalHashes.slot)
                parentProposalHash := sload(keccak256(0x00, 0x40))
                // Note: 0x20 still contains _proposalHashes.slot for reuse below

                let ptr := mload(0x40) // scratch space

                // Proposal static fields (9 words)
                mstore(ptr, nextProposalId) // id
                mstore(add(ptr, 0x20), timestamp()) // timestamp
                mstore(add(ptr, 0x40), endOfSubmissionWindowTimestamp)
                mstore(add(ptr, 0x60), caller()) // proposer
                mstore(add(ptr, 0x80), parentProposalHash)
                let pbn := sub(number(), 1)
                mstore(add(ptr, 0xa0), pbn) // originBlockNumber
                mstore(add(ptr, 0xc0), blockhash(pbn)) // originBlockHash
                mstore(add(ptr, 0xe0), bfsPctg) // basefeeSharingPctg
                mstore(add(ptr, 0x100), 0x120) // offset to sources array

                // Sources array header (2 words)
                mstore(add(ptr, 0x120), 1) // length = 1
                mstore(add(ptr, 0x140), 0x20) // offset to sources[0]

                // Fast path: known contiguous memory layout from blob assembly above.
                // Layout (numBlobs=1): [blobHashes(2w)] [BlobSlice(3w)] [DS(2w)] [sources(2w)]
                // sources = fmp + 0xe0, so fixed offsets from sources:
                mstore(add(ptr, 0x160), 0) // isForcedInclusion = false
                mstore(add(ptr, 0x180), 0x40) // offset to blobSlice
                mstore(add(ptr, 0x1a0), 0x60) // offset to blobHashes
                mstore(add(ptr, 0x1c0), mload(sub(sources, 0x80))) // BlobSlice.offset
                mstore(add(ptr, 0x1e0), mload(sub(sources, 0x60))) // BlobSlice.timestamp
                mstore(add(ptr, 0x200), 1) // blobHashes length = 1
                mstore(add(ptr, 0x220), mload(sub(sources, 0xc0))) // blobHashes[0]

                let proposalHash := keccak256(ptr, 0x240)

                // Update coreState: nextProposalId and lastProposalBlockId
                let cleared := and(coreSlot, not(0xffffffffffffffffffffffff))
                let newValue :=
                    or(or(cleared, add(nextProposalId, 1)), shl(48, number()))
                sstore(_coreState.slot, newValue)

                // Write proposal hash to mapping: _proposalHashes[nextProposalId % rbs]
                // 0x20 still has _proposalHashes.slot from parent hash read above
                mstore(0x00, mod(nextProposalId, rbs))
                sstore(keccak256(0x00, 0x40), proposalHash)

                // ProposedFast: LOG2 — proposer derivable from tx sender
                if queueEmpty {
                    mstore(ptr, mload(sub(sources, 0xc0))) // blobHash
                    mstore(
                        add(ptr, 0x20),
                        or(
                            or(shl(248, bfsPctg), shl(224, mload(sub(sources, 0x80)))),
                            shl(176, mload(sub(sources, 0x60)))
                        )
                    ) // packed: bfsPctg(8)|blobOffset(24)|blobTimestamp(48)
                    log2(
                        ptr,
                        0x40,
                        0xd87c354a13242c4a737f6bbfff109ce25d17029ec59fe72d5f7fd7d7288010bb,
                        nextProposalId
                    )
                }
            }

            if (!queueEmpty) {
                emit Proposed(
                    nextProposalId,
                    msg.sender,
                    parentProposalHash,
                    endOfSubmissionWindowTimestamp,
                    _basefeeSharingPctg,
                    sources
                );
            }
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
            uint256 lastProposalId;
            uint48 offset;
            assembly {
                // require(numProposals > 0)
                if iszero(numProposals) {
                    mstore(0x00, 0xc2e5347d) // EmptyBatch()
                    revert(0x1c, 0x04)
                }
                lastProposalId := add(sub(numProposals, 1), mload(commitment))
                let lfpi := and(shr(96, coreSlot0), 0xffffffffffff)
                let lfpiPlus1 := add(lfpi, 1)
                // require(firstProposalId <= lfpi + 1)
                if gt(mload(commitment), lfpiPlus1) {
                    mstore(0x00, 0x63db3a41) // FirstProposalIdTooLarge()
                    revert(0x1c, 0x04)
                }
                // require(lastProposalId < nextProposalId)
                if iszero(lt(lastProposalId, and(coreSlot0, 0xffffffffffff))) {
                    mstore(0x00, 0x677c56f1) // LastProposalIdTooLarge()
                    revert(0x1c, 0x04)
                }
                // require(lastProposalId >= lfpi + 1)
                if lt(lastProposalId, lfpiPlus1) {
                    mstore(0x00, 0x302865ce) // LastProposalAlreadyFinalized()
                    revert(0x1c, 0x04)
                }
                offset := sub(lfpiPlus1, mload(commitment))
            }

            uint256 transitionTimestamp;
            assembly {
                // transitions = commitment.transitions (pointer at offset 0xc0)
                let transitions := mload(add(commitment, 0xc0))
                // transitions[offset] pointer (skip length word + offset pointers)
                let tPtr := mload(add(transitions, add(0x20, mul(offset, 0x20))))
                // timestamp is at offset 0x20 in Transition struct
                transitionTimestamp := mload(add(tPtr, 0x20))
            }
            bool isWhitelistEnabled;
            {
                IProverWhitelist pw = _proverWhitelist;
                if (address(pw) != address(0)) {
                    (bool isWhitelisted, uint256 proverCount) =
                        pw.isProverWhitelisted(msg.sender);
                    if (proverCount > 0) {
                        if (!isWhitelisted) {
                            require(
                                block.timestamp > transitionTimestamp + uint256(_permissionlessProvingDelay),
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
            bytes32 expectedParentHash;
            assembly {
                let transitions := mload(add(commitment, 0xc0))
                switch offset
                case 0 {
                    expectedParentHash := mload(add(commitment, 0x20))
                }
                default {
                    let tPtr := mload(add(transitions, add(0x20, mul(sub(offset, 1), 0x20))))
                    expectedParentHash := mload(add(tPtr, 0x40)) // blockHash
                }
            }
            {
                uint256 rbs = _ringBufferSize;
                assembly {
                    // require(_coreState.lastFinalizedBlockHash == expectedParentHash)
                    if iszero(eq(sload(add(_coreState.slot, 1)), expectedParentHash)) {
                        mstore(0x00, 0x198070b3) // ParentBlockHashMismatch()
                        revert(0x1c, 0x04)
                    }
                    // require(commitment.lastProposalHash == _proposalHashes[lastProposalId % rbs])
                    mstore(0x00, mod(lastProposalId, rbs))
                    mstore(0x20, _proposalHashes.slot)
                    if iszero(eq(mload(add(commitment, 0x40)), sload(keccak256(0x00, 0x40)))) {
                        mstore(0x00, 0xf904c2fd) // LastProposalHashMismatch()
                        revert(0x1c, 0x04)
                    }
                }
            }

            // ---------------------------------------------------------
            // 3. Process bond instruction
            // ---------------------------------------------------------
            // Bond transfers only apply when whitelist is not enabled.
            if (!isWhitelistEnabled) {
                uint256 a = transitionTimestamp + _provingWindow;
                // lastFinalizedTimestamp is at bits 144-191
                uint256 b = ((coreSlot0 >> 144) & 0xffffffffffff) + _maxProofSubmissionDelay;
                uint256 livenessWindowDeadline = a > b ? a : b;

                if (block.timestamp > livenessWindowDeadline) {
                    address proposer;
                    assembly {
                        let transitions := mload(add(commitment, 0xc0))
                        let tPtr := mload(add(transitions, add(0x20, mul(offset, 0x20))))
                        proposer := mload(tPtr) // proposer at offset 0
                    }
                    _bondStorage.settleLivenessBond(
                        proposer, commitment.actualProver, _livenessBond
                    );
                }
            }

            // -----------------------------------------------------------------------------
            // 4. Sync checkpoint
            // -----------------------------------------------------------------------------
            bytes32 lastBlockHash;
            assembly {
                let transitions := mload(add(commitment, 0xc0))
                let tPtr := mload(add(transitions, add(0x20, mul(sub(numProposals, 1), 0x20))))
                lastBlockHash := mload(add(tPtr, 0x40))
            }
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
                assembly {
                    // Preserve bits 0-95 (nextProposalId + lastProposalBlockId) from cached read
                    let preserved := and(coreSlot0, 0xffffffffffffffffffffffff)
                    let ts := timestamp()
                    let newSlot :=
                        or(
                            or(
                                or(preserved, shl(96, lastProposalId)),
                                shl(144, ts)
                            ),
                            shl(192, ts)
                        )
                    sstore(_coreState.slot, newSlot)
                    // Write slot 253: lastFinalizedBlockHash
                    sstore(add(_coreState.slot, 1), lastBlockHash)
                }
            }

            assembly {
                let fpi := mload(commitment)
                let fmp := mload(0x40)
                mstore(fmp, fpi)
                mstore(add(fmp, 0x20), add(fpi, offset))
                mstore(add(fmp, 0x40), lastProposalId)
                log2(
                    fmp,
                    0x60,
                    0xa274dcaff3629ec7d69d144038e97732516ff306fcbf8a2bc9423d106779a2f0,
                    mload(add(commitment, 0x60))
                )
            }

            // ---------------------------------------------------------
            // 6. Verify the proof
            // ---------------------------------------------------------
            // For multi-proposal batches (more than 1 unfinalized proposal), pass 0 to verifier.
            // Single-proposal proofs pass actual age for age-based verification logic.
            if (numProposals == 1) {
                bytes32 commitmentHash;
                assembly {
                    let ptr := mload(0x40)
                    mstore(ptr, 0x20)
                    mstore(add(ptr, 0x20), mload(commitment))
                    mstore(add(ptr, 0x40), mload(add(commitment, 0x20)))
                    mstore(add(ptr, 0x60), mload(add(commitment, 0x40)))
                    mstore(add(ptr, 0x80), mload(add(commitment, 0x60)))
                    mstore(add(ptr, 0xa0), mload(add(commitment, 0x80)))
                    mstore(add(ptr, 0xc0), mload(add(commitment, 0xa0)))
                    mstore(add(ptr, 0xe0), 0xe0)
                    mstore(add(ptr, 0x100), 1)
                    let transitions := mload(add(commitment, 0xc0))
                    let t0 := mload(add(transitions, 0x20))
                    mstore(add(ptr, 0x120), mload(t0))
                    mstore(add(ptr, 0x140), mload(add(t0, 0x20)))
                    mstore(add(ptr, 0x160), mload(add(t0, 0x40)))
                    commitmentHash := keccak256(ptr, 0x180)
                }
                // Single proposal: numProposals - offset is always 1 when offset == 0
                _proofVerifier.verifyProof(block.timestamp - transitionTimestamp, commitmentHash, _proof);
            } else {
                uint256 proposalAge = block.timestamp - transitionTimestamp;
                _proofVerifier.verifyProof(
                    numProposals - offset == 1 ? proposalAge : 0,
                    LibHashOptimized.hashCommitment(commitment),
                    _proof
                );
            }
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

    /// @dev Stores a proposal hash in the ring buffer
    /// Overwrites any existing hash at the calculated buffer slot
    function _setProposalHash(uint48 _proposalId, bytes32 _proposalHash) private {
        _proposalHashes[_proposalId % _ringBufferSize] = _proposalHash;
    }

    /// @dev Consumes forced inclusions from the queue and returns result with extra slot for normal
    /// source
    /// @param _feeRecipient Address to receive accumulated fees
    /// @param _numForcedInclusionsRequested Maximum number of forced inclusions to consume
    /// @return sources_ Sources array (size: processed + 1, last slot empty for normal source)
    /// @return allowsPermissionless_ Whether permissionless proposals are allowed
    function _consumeForcedInclusions(
        address _feeRecipient,
        uint256 _numForcedInclusionsRequested
    )
        private
        returns (DerivationSource[] memory sources_, bool allowsPermissionless_)
    {
        unchecked {
            LibForcedInclusion.Storage storage $ = _forcedInclusionStorage;

            // Load head and tail from storage — both are packed in a single slot
            uint48 head;
            uint48 tail;
            assembly {
                // Storage layout: mapping(slot 0) + head(6 bytes) + tail(6 bytes) at slot 1
                // $.slot points to the mapping; head/tail are at $.slot + 1
                let packed := sload(add($.slot, 1))
                head := and(packed, 0xffffffffffff)
                tail := and(shr(48, packed), 0xffffffffffff)
            }

            uint256 available = tail - head;

            // Fast path: empty queue — no forced inclusions to inspect or process
            if (available == 0) {
                sources_ = new DerivationSource[](1);
                return (sources_, false);
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

            sources_ = new DerivationSource[](toProcess + 1);

            if (toProcess != 0) {
                uint48 oldestTimestamp;
                (oldestTimestamp, head) = _dequeueAndProcessForcedInclusions(
                    $, _feeRecipient, sources_, head, toProcess
                );

                uint256 permissionlessTimestamp = uint256(_forcedInclusionDelay)
                    * _permissionlessInclusionMultiplier + oldestTimestamp;
                allowsPermissionless_ = block.timestamp > permissionlessTimestamp;
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

    /// @dev Virtual hook for proposer authorization check. Default uses high-level external call.
    /// Override in subcontracts for optimized implementations (e.g., assembly STATICCALL).
    function _checkProposer(
        address _sender,
        bytes calldata _lookahead
    )
        internal
        virtual
        returns (uint48)
    {
        return _proposerChecker.checkProposer(_sender, _lookahead);
    }

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
