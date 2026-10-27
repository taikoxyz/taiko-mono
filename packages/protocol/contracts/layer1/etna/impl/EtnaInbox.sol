// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { LibEtnaForcedInclusion } from "../libs/LibEtnaForcedInclusion.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

import "./EtnaInbox_Layout.sol"; // DO NOT DELETE

/// @title EtnaInbox
/// @notice The L1 Inbox of an Etna PoS chain starting at L2 block 0; see `IEtnaInbox`.
/// @dev The proxy first runs `EtnaInboxBootstrap`; its owner then upgrades to this contract and
/// calls `init`. Storage follows spec appendix B exactly: the slots from 251 on are reserved or
/// named as listed there, and reserved slots 283, 286-289 and 291 are never read or written.
/// @custom:security-contact security@taiko.xyz
// solhint-disable-next-line max-states-count
contract EtnaInbox is IEtnaInbox, EssentialContract {
    using LibAddress for address;
    using LibEtnaForcedInclusion for LibEtnaForcedInclusion.Storage;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev Slot 282: the genesis forced inclusion parameters in seconds, packed from the
    /// least-significant bit.
    struct ForcedInclusionConfig {
        uint48 delay;
        uint48 maxAnchorAge;
    }

    /// @dev The 21 static words of the landing statement in appendix A order; its ABI encoding is
    /// the 672-byte statement preimage.
    struct LandStatement {
        bytes32 tag;
        uint256 l1ChainId;
        uint256 l2ChainId;
        address inbox;
        address stakingRegistry;
        uint256 generation;
        uint256 parentHeight;
        bytes32 parentHash;
        bytes32 parentCometHash;
        bytes32 committeeConfigHash;
        uint256 lastHeight;
        bytes32 lastBlockHash;
        bytes32 lastCometHash;
        bytes32 lastStateRoot;
        uint256 l1ReferenceBlockNumber;
        bytes32 l1ReferenceBlockHash;
        bytes32 blobHashesHash;
        uint256 forcedInclusionHeadBefore;
        uint256 forcedInclusionHeadAfter;
        uint256 activeCommitteeSnapshot;
        bytes32 cutHash;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice `K`: landings end only at heights that are multiples of this (spec 6.1).
    uint256 public constant GRID_INTERVAL = 6;

    /// @notice The landing statement version emitted by `Landed`.
    uint8 public constant VERSION = 1;

    /// @notice The maximum byte length of a forced transaction (spec 7.1).
    uint256 public constant MAX_FORCED_TX_BYTES = 8192;

    /// @notice The maximum number of blobs of a landing (spec 6.1).
    uint256 public constant MAX_BLOBS = 6;

    /// @notice The slot 258 value once initialized.
    uint8 public constant INITIALIZED_STATUS = 3;

    /// @dev The domain tag of `committeeConfigHash` (appendix A).
    bytes32 private constant _COMMITTEE_CONFIG_TAG = bytes32("ETNA_PARENT_ANCHOR_V1");

    /// @dev The minimum epoch length `L` in L2 blocks (spec 10).
    uint256 private constant _MIN_EPOCH_LEN_L2 = 3;

    /// @dev The minimum `maxAnchorAge` in seconds (spec 10).
    uint256 private constant _MIN_MAX_ANCHOR_AGE = 1152;

    /// @dev The minimum `vp_unit`, which keeps the committee's total voting power from overflowing
    /// (spec 4.3).
    uint256 private constant _MIN_VP_UNIT = 867_361_738;

    /// @dev The maximum `n_max`, the registry's capacity.
    uint256 private constant _MAX_COMMITTEE_SIZE = 4096;

    /// @dev The maximum `U`, the largest multiple of 6 below 2^16 (spec 10).
    uint256 private constant _MAX_UNSETTLED_LIMIT = 65_532;

    /// @dev The domain tag of the landing statement (appendix A).
    bytes32 private constant _LAND_STATEMENT_TAG = bytes32("TAIKO_ETNA_LAND_V1");

    /// @dev The domain tag of `cutHash` (appendix A).
    bytes32 private constant _LAND_CUTS_TAG = bytes32("ETNA_LAND_CUTS_V1");

    /// @dev Every landed height is below 2^48, the width of a height in slots 270 and 285.
    uint256 private constant _HEIGHT_LIMIT = 2 ** 48;

    /// @dev The number of most recent L1 blocks whose hash `blockhash` returns.
    uint256 private constant _BLOCKHASH_WINDOW = 256;

    /// @dev The EIP-2935 history storage contract.
    address private constant _HISTORY_STORAGE_ADDRESS = 0x0000F90827F1C53a10cb7A02335B175320002935;

    /// @dev The number of most recent L1 blocks whose hash the EIP-2935 contract serves.
    uint256 private constant _HISTORY_SERVE_WINDOW = 8191;

    /// @dev keccak256(""): the txHash recovery writes over a blanked forced inclusion (spec 8
    /// step 3).
    bytes32 private constant _BLANK_TX_HASH = keccak256("");

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @dev The verifier of `land` proofs.
    IProofVerifier internal immutable _proofVerifier;

    /// @dev The L1 SignalService that stores the landed checkpoints.
    ISignalService internal immutable _signalService;

    /// @dev The staking registry.
    IEtnaStakingRegistry internal immutable _stakingRegistry;

    /// @dev The chain id of the Etna L2.
    uint64 internal immutable _l2ChainId;

    /// @dev The maximum `h - p` of one landing.
    uint64 internal immutable _maxBatchBlocks;

    /// @dev The forced inclusion fee in Gwei with an empty queue.
    uint64 internal immutable _forcedInclusionFeeInGwei;

    /// @dev The number of pending forced inclusions at which the fee doubles.
    uint64 internal immutable _forcedInclusionFeeDoubleThreshold;

    /// @dev The DAO treasury that receives the swept forced inclusion fees.
    address internal immutable _protocolFeeRecipient;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Slots 251-257: reserved.
    uint256[7] private __reserved251;

    /// @dev Slot 258: `INITIALIZED_STATUS` once initialized; zero before.
    uint8 private _initStatus;

    /// @dev Slots 259-267: reserved.
    uint256[9] private __reserved259;

    /// @dev Slot 268: the recovery generation.
    uint48 private _recoveryGeneration;

    /// @dev Slot 269: the committee configuration hash.
    bytes32 private _committeeConfigHash;

    /// @dev Slots 270-271: the latest landed checkpoint.
    LandedCheckpoint private _lastCheckpoint;

    /// @dev Slots 272-274: the genesis record.
    GenesisRecord private _genesis;

    /// @dev Slots 275-277: reserved.
    uint256[3] private __reserved275;

    /// @dev Slot 278: the committee 0 record hash.
    bytes32 private _genesisCommitteeRecordHash;

    /// @dev Slot 279: the registry snapshot block of committee 0.
    uint48 private _genesisCutoff;

    /// @dev Slots 280-281: the forced inclusion queue and its packed head and tail.
    LibEtnaForcedInclusion.Storage private _forcedInclusions;

    /// @dev Slot 282: the forced inclusion delay and the maximum anchor age.
    ForcedInclusionConfig private _forcedInclusionConfig;

    /// @dev Slot 283: reserved; never read or written.
    uint256 private __reserved283;

    /// @dev Slot 284: the selection snapshot of the committee that signed the latest checkpoint.
    uint256 private _activeCommitteeSnapshot;

    /// @dev Slot 285: the landing record of every checkpoint height.
    mapping(uint256 height => Landing landing) private _landings;

    /// @dev Slots 286-289: reserved; never read or written.
    uint256[4] private __reserved286;

    /// @dev Slot 290: the fixed origin of every recovery generation.
    mapping(uint256 generation => Origin origin) private _origins;

    /// @dev Slot 291: reserved; never read or written.
    uint256 private __reserved291;

    uint256[9] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the implementation's immutable parameters.
    /// @param _config The configuration: non-zero addresses and L2 chain id, `maxBatchBlocks` of
    /// at least 6 and non-zero forced inclusion fee parameters.
    constructor(Config memory _config) {
        require(_config.proofVerifier != address(0), ZERO_ADDRESS());
        require(_config.signalService != address(0), ZERO_ADDRESS());
        require(_config.stakingRegistry != address(0), ZERO_ADDRESS());
        require(_config.protocolFeeRecipient != address(0), ZERO_ADDRESS());
        require(_config.l2ChainId != 0, ZERO_VALUE());
        require(_config.maxBatchBlocks >= GRID_INTERVAL, InvalidMaxBatchBlocks());
        require(_config.forcedInclusionFeeInGwei != 0, ForcedInclusionFeeZero());
        require(
            _config.forcedInclusionFeeDoubleThreshold != 0, ForcedInclusionFeeDoubleThresholdZero()
        );

        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _signalService = ISignalService(_config.signalService);
        _stakingRegistry = IEtnaStakingRegistry(_config.stakingRegistry);
        _l2ChainId = _config.l2ChainId;
        _maxBatchBlocks = _config.maxBatchBlocks;
        _forcedInclusionFeeInGwei = _config.forcedInclusionFeeInGwei;
        _forcedInclusionFeeDoubleThreshold = _config.forcedInclusionFeeDoubleThreshold;
        _protocolFeeRecipient = _config.protocolFeeRecipient;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IEtnaInbox
    /// @dev Writes only the non-zero appendix B values: a proxy that has only run the bootstrap
    /// holds zero in every other Inbox slot, which is the remaining initial state (generation 0,
    /// checkpoint height 0, an empty queue and the zero fields of landings[0] and origins[0]).
    function init(InitParams calldata _params) external reinitializer(2) onlyOwner {
        _validateInitParams(_params);

        bytes32 configHash = _hashCommitteeConfig(_params.committeeConfig);
        bytes32 genesisBlockHash = _params.genesisBlockHash;
        uint48 l1Block = uint48(block.number);
        uint48 cutoff = uint48(_params.genesisCutoff);

        _initStatus = INITIALIZED_STATUS;
        _committeeConfigHash = configHash;
        _lastCheckpoint.blockHash = genesisBlockHash;
        _genesis = GenesisRecord({
            genesisHeight: 0,
            l1Block: l1Block,
            epochLenL2: uint48(_params.epochLenL2),
            genesisBlockHash: genesisBlockHash,
            genesisStateRoot: _params.genesisStateRoot
        });
        _genesisCommitteeRecordHash = _params.committeeRecordHash;
        _genesisCutoff = cutoff;
        _forcedInclusionConfig = ForcedInclusionConfig({
            delay: uint48(_params.forcedInclusionDelay), maxAnchorAge: uint48(_params.maxAnchorAge)
        });
        _activeCommitteeSnapshot = cutoff;
        _landings[0].elHash = genesisBlockHash;
        Origin storage origin = _origins[0];
        origin.l1BlockNumber = l1Block;
        origin.l1Timestamp = block.timestamp;

        _signalService.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: genesisBlockHash, stateRoot: _params.genesisStateRoot
            })
        );

        emit EtnaInitialized(
            genesisBlockHash,
            _params.genesisStateRoot,
            l1Block,
            _params.epochLenL2,
            cutoff,
            _params.committeeRecordHash,
            configHash
        );
    }

    /// @inheritdoc IEtnaInbox
    /// @dev Requires initialization, then follows the spec 6.1 reference Solidity: its checks in
    /// its order, all before any write. Unaffected by pause. The only external calls are the proof
    /// verifier and the EIP-2935 history contract (both static) and the SignalService.
    function land(
        LandInput calldata _input,
        bytes32[] calldata _leaves,
        bytes calldata _proof
    )
        external
        nonReentrant
    {
        require(_initStatus == INITIALIZED_STATUS, NotInitialized());
        uint48 generation = _recoveryGeneration;
        uint256 c = _lastCheckpoint.height;

        // Steps 1-4.
        Landing memory origin = _checkRangeAndOrigin(_input, c, generation);
        uint256 headAfter = _checkLeavesAndHead(_input, _leaves, c);

        // Steps 5 and 6: the statement reads and checks the reference block and the blobs.
        bytes32 cutHash = keccak256(
            abi.encode(
                _LAND_CUTS_TAG,
                uint256(generation),
                _input.parentHeight,
                _input.lastHeight,
                keccak256(abi.encodePacked(_leaves))
            )
        );
        _proofVerifier.verifyProof(
            0, _hashLandStatement(_input, origin, generation, cutHash), _proof
        );

        // Step 7.
        _settle(_input, c, generation, headAfter, cutHash);
    }

    /// @inheritdoc IEtnaInbox
    /// @dev Unaffected by pause. The refund is the last step, after every write and the event, and
    /// a failed refund reverts the whole submission.
    function saveForcedInclusion(bytes calldata _tx) external payable nonReentrant {
        require(_initStatus == INITIALIZED_STATUS, NotInitialized());
        require(_tx.length <= MAX_FORCED_TX_BYTES, ForcedTransactionTooLarge());

        uint256 feeWei = uint256(
            _forcedInclusions.currentFee(
                _forcedInclusionFeeInGwei, _forcedInclusionFeeDoubleThreshold
            )
        ) * 1 gwei;
        require(msg.value >= feeWei, InsufficientFee());

        uint48 index = _forcedInclusions.tail;
        _forcedInclusions.queue[index] = ForcedInclusion({
            txHash: keccak256(_tx),
            timestamp: _toUint48(block.timestamp),
            l1Block: _toUint48(block.number)
        });
        _forcedInclusions.tail = index + 1;

        emit ForcedInclusionSaved(index, _tx, feeWei);

        msg.sender.sendEtherAndVerify(msg.value - feeWei);
    }

    /// @inheritdoc IEtnaInbox
    /// @dev Also sweeps ETH forced into the Inbox without a call. A zero balance transfers nothing.
    /// Unaffected by pause.
    function sweepProtocolFees() external nonReentrant {
        uint256 amount = address(this).balance;
        emit ProtocolFeesSwept(amount);
        _protocolFeeRecipient.sendEtherAndVerify(amount);
    }

    /// @inheritdoc IEtnaInbox
    /// @dev The Inbox makes all of its own checks (initialization, the expected values, the 48-bit
    /// bounds, both lists and the unwritten origin) before any effect. The effects then run in
    /// this order: `forceExit` per exclusion, the blanking, the generation and origin writes, then
    /// the event. The registry checks each exclusion inside its `forceExit`, after the earlier
    /// exclusions have been applied; the call is atomic, so a failing `forceExit` reverts them
    /// all. Unaffected by pause. The only external calls are `forceExit` on the fixed registry. At
    /// block.number == 2^48 - 1 recovery passes its own bound but any exclusion reverts in the
    /// registry, which stores no L1 block at its no-exit sentinel.
    function recover(
        uint48 _expectedGeneration,
        uint256 _expectedC,
        Exclusion[] calldata _exclusions,
        uint256[] calldata _fiToClear
    )
        external
        onlyOwner
        nonReentrant
    {
        require(_initStatus == INITIALIZED_STATUS, NotInitialized());
        uint48 generation = _recoveryGeneration;
        require(_expectedGeneration == generation, GenerationMismatch());
        uint48 c = _lastCheckpoint.height;
        require(_expectedC == c, CheckpointMismatch());

        // The new generation (slot 268) and the origin's L1 block number and timestamp must fit
        // 48 bits; c already does.
        uint48 newGeneration = _toUint48(uint256(generation) + 1);
        require(
            block.number <= type(uint48).max && block.timestamp <= type(uint48).max, ValueOverflow()
        );
        _checkRecoveryLists(_exclusions, _fiToClear);
        Origin storage origin = _origins[newGeneration];
        require(
            origin.startHeight == 0 && origin.l1BlockNumber == 0 && origin.l1Timestamp == 0,
            OriginAlreadyWritten()
        );

        for (uint256 i; i < _exclusions.length; ++i) {
            _stakingRegistry.forceExit(_exclusions[i].bondId, _exclusions[i].entryKey, block.number);
        }
        for (uint256 i; i < _fiToClear.length; ++i) {
            _forcedInclusions.queue[_fiToClear[i]].txHash = _BLANK_TX_HASH;
        }
        _recoveryGeneration = newGeneration;
        _origins[newGeneration] =
            Origin({ startHeight: c, l1BlockNumber: block.number, l1Timestamp: block.timestamp });

        emit Recovered(newGeneration, c, block.number, block.timestamp, _exclusions, _fiToClear);
    }

    /// @inheritdoc IEtnaInbox
    function isInitialized() external view returns (bool) {
        return _initStatus == INITIALIZED_STATUS;
    }

    /// @inheritdoc IEtnaInbox
    function recoveryGeneration() external view returns (uint48) {
        return _recoveryGeneration;
    }

    /// @inheritdoc IEtnaInbox
    function committeeConfigHash() external view returns (bytes32) {
        return _committeeConfigHash;
    }

    /// @inheritdoc IEtnaInbox
    function lastCheckpoint() external view returns (LandedCheckpoint memory) {
        return _lastCheckpoint;
    }

    /// @inheritdoc IEtnaInbox
    function genesis() external view returns (GenesisRecord memory) {
        return _genesis;
    }

    /// @inheritdoc IEtnaInbox
    function genesisCommitteeRecordHash() external view returns (bytes32) {
        return _genesisCommitteeRecordHash;
    }

    /// @inheritdoc IEtnaInbox
    function genesisCutoff() external view returns (uint48) {
        return _genesisCutoff;
    }

    /// @inheritdoc IEtnaInbox
    function forcedInclusionDelay() external view returns (uint48) {
        return _forcedInclusionConfig.delay;
    }

    /// @inheritdoc IEtnaInbox
    function maxAnchorAge() external view returns (uint48) {
        return _forcedInclusionConfig.maxAnchorAge;
    }

    /// @inheritdoc IEtnaInbox
    function activeCommitteeSnapshot() external view returns (uint256) {
        return _activeCommitteeSnapshot;
    }

    /// @inheritdoc IEtnaInbox
    function landings(uint256 _height) external view returns (Landing memory) {
        return _landings[_height];
    }

    /// @inheritdoc IEtnaInbox
    function origins(uint256 _generation) external view returns (Origin memory) {
        return _origins[_generation];
    }

    /// @inheritdoc IEtnaInbox
    function generationStartHeight() external view returns (uint256) {
        return _origins[_recoveryGeneration].startHeight;
    }

    /// @inheritdoc IEtnaInbox
    function recoverySnapshot() external view returns (uint256) {
        return _origins[_recoveryGeneration].l1BlockNumber;
    }

    /// @inheritdoc IEtnaInbox
    function getForcedInclusionState() external view returns (uint48 head_, uint48 tail_) {
        return (_forcedInclusions.head, _forcedInclusions.tail);
    }

    /// @inheritdoc IEtnaInbox
    function getForcedInclusion(uint48 _index) external view returns (ForcedInclusion memory) {
        return _forcedInclusions.queue[_index];
    }

    /// @inheritdoc IEtnaInbox
    function getForcedInclusions(
        uint48 _start,
        uint48 _maxCount
    )
        external
        view
        returns (ForcedInclusion[] memory)
    {
        return _forcedInclusions.getForcedInclusions(_start, _maxCount);
    }

    /// @inheritdoc IEtnaInbox
    function getCurrentForcedInclusionFee() external view returns (uint64 feeInGwei_) {
        return _forcedInclusions.currentFee(
            _forcedInclusionFeeInGwei, _forcedInclusionFeeDoubleThreshold
        );
    }

    /// @inheritdoc IEtnaInbox
    function stakingRegistry() external view returns (address) {
        return address(_stakingRegistry);
    }

    /// @inheritdoc IEtnaInbox
    function signalService() external view returns (address) {
        return address(_signalService);
    }

    /// @inheritdoc IEtnaInbox
    function proofVerifier() external view returns (address) {
        return address(_proofVerifier);
    }

    /// @inheritdoc IEtnaInbox
    function l2ChainId() external view returns (uint64) {
        return _l2ChainId;
    }

    /// @inheritdoc IEtnaInbox
    function maxBatchBlocks() external view returns (uint64) {
        return _maxBatchBlocks;
    }

    /// @inheritdoc IEtnaInbox
    function forcedInclusionFeeInGwei() external view returns (uint64) {
        return _forcedInclusionFeeInGwei;
    }

    /// @inheritdoc IEtnaInbox
    function forcedInclusionFeeDoubleThreshold() external view returns (uint64) {
        return _forcedInclusionFeeDoubleThreshold;
    }

    /// @inheritdoc IEtnaInbox
    function protocolFeeRecipient() external view returns (address) {
        return _protocolFeeRecipient;
    }

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @notice Upgrades the implementation and calls `_data` on it, without accepting ETH.
    /// @dev Only `saveForcedInclusion` accepts ETH (spec 7.1). The override must stay payable, so
    /// it rejects a non-zero `msg.value` itself; the owner check is unchanged.
    /// @param _newImplementation The new implementation.
    /// @param _data The call to delegate to the new implementation.
    function upgradeToAndCall(
        address _newImplementation,
        bytes memory _data
    )
        public
        payable
        override
    {
        require(msg.value == 0, EtherNotAccepted());
        super.upgradeToAndCall(_newImplementation, _data);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Spec 6.1 steps 1 and 2: generationStartHeight() <= p <= c < h < 2^48, p and h on the
    /// grid, h - p <= maxBatchBlocks, and a retained origin record in the current generation
    /// unless p is the generation's start height.
    /// @param _input The landing inputs.
    /// @param _c The checkpoint height.
    /// @param _generation The recovery generation.
    /// @return origin_ The landing record at p.
    function _checkRangeAndOrigin(
        LandInput calldata _input,
        uint256 _c,
        uint48 _generation
    )
        private
        view
        returns (Landing memory origin_)
    {
        uint256 p = _input.parentHeight;
        uint256 h = _input.lastHeight;
        uint256 startHeight = _origins[_generation].startHeight;

        require(_c < h, AlreadySettled());
        require(startHeight <= p && p <= _c && h < _HEIGHT_LIMIT, InvalidRange());
        require(p % GRID_INTERVAL == 0 && h % GRID_INTERVAL == 0, OffGrid());
        require(h - p <= _maxBatchBlocks, BatchTooLarge());

        origin_ = _landings[p];
        // A written record never has a zero EL hash: `init` rejects a zero genesis hash, and
        // `land` saves each hash as a SignalService checkpoint, which rejects a zero hash.
        require(origin_.elHash != 0, MissingOrigin());
        require(origin_.generation == _generation || p == startHeight, ForeignGeneration());
    }

    /// @dev Spec 6.1 steps 3 and 4: exactly the (h - p) / 6 - 1 grid-point leaves, c's recorded
    /// queue head equal to the queue head, the leaf at c equal to cutLeaf(c) over c's record if
    /// c > p, and a new queue head in [head, tail] at most h - c past the head.
    /// @param _input The landing inputs.
    /// @param _leaves The cut leaves at the grid points in (p, h).
    /// @param _c The checkpoint height.
    /// @return headAfter_ The new queue head.
    function _checkLeavesAndHead(
        LandInput calldata _input,
        bytes32[] calldata _leaves,
        uint256 _c
    )
        private
        view
        returns (uint256 headAfter_)
    {
        uint256 p = _input.parentHeight;
        uint256 h = _input.lastHeight;
        require(_leaves.length == (h - p) / GRID_INTERVAL - 1, LeafCountMismatch());

        Landing storage cur = _landings[_c];
        uint256 head = cur.head;
        require(head == _forcedInclusions.head, ForcedInclusionHeadMismatch());
        if (_c > p) {
            require(
                _leaves[(_c - p) / GRID_INTERVAL - 1]
                    == keccak256(abi.encode(_c, cur.elHash, cur.cometHash, head)),
                FrontierLeafMismatch()
            );
        }

        headAfter_ = _input.forcedInclusionHead;
        require(
            head <= headAfter_ && headAfter_ <= _forcedInclusions.tail
                && headAfter_ - head <= h - _c,
            InvalidForcedInclusionHead()
        );
    }

    /// @dev Spec 8 steps 1-3: exclusions sorted strictly by bond id, then queue indices strictly
    /// increasing and within [head, tail). Strict order makes the first and last indices bound
    /// the whole list.
    /// @param _exclusions The entries to force out.
    /// @param _fiToClear The queue indices to blank.
    function _checkRecoveryLists(
        Exclusion[] calldata _exclusions,
        uint256[] calldata _fiToClear
    )
        private
        view
    {
        for (uint256 i = 1; i < _exclusions.length; ++i) {
            require(_exclusions[i - 1].bondId < _exclusions[i].bondId, ExclusionsNotSorted());
        }

        uint256 count = _fiToClear.length;
        if (count == 0) return;
        for (uint256 i = 1; i < count; ++i) {
            require(_fiToClear[i - 1] < _fiToClear[i], FiToClearNotSorted());
        }
        require(
            _fiToClear[0] >= _forcedInclusions.head
                && _fiToClear[count - 1] < _forcedInclusions.tail,
            FiIndexOutOfRange()
        );
    }

    /// @dev Builds the landing statement (appendix A) and hashes its 21 words. Runs spec 6.1
    /// step 5: reads the reference block hash and the blob hashes, reverting if either is
    /// unavailable. A separate frame keeps `land` within the non-IR compiler's stack limit.
    /// @param _input The landing inputs.
    /// @param _origin The landing record at p: the source of parentHash, parentCometHash and
    /// headBefore.
    /// @param _generation The recovery generation.
    /// @param _cutHash The cut hash.
    /// @return The statement hash.
    function _hashLandStatement(
        LandInput calldata _input,
        Landing memory _origin,
        uint48 _generation,
        bytes32 _cutHash
    )
        private
        view
        returns (bytes32)
    {
        LandStatement memory statement;
        statement.tag = _LAND_STATEMENT_TAG;
        statement.l1ChainId = block.chainid;
        statement.l2ChainId = _l2ChainId;
        statement.inbox = address(this);
        statement.stakingRegistry = address(_stakingRegistry);
        statement.generation = _generation;
        statement.parentHeight = _input.parentHeight;
        statement.parentHash = _origin.elHash;
        statement.parentCometHash = _origin.cometHash;
        statement.committeeConfigHash = _committeeConfigHash;
        statement.lastHeight = _input.lastHeight;
        statement.lastBlockHash = _input.lastBlockHash;
        statement.lastCometHash = _input.lastCometHash;
        statement.lastStateRoot = _input.lastStateRoot;
        statement.l1ReferenceBlockNumber = _input.l1ReferenceBlockNumber;
        statement.l1ReferenceBlockHash = _readL1ReferenceBlockHash(_input.l1ReferenceBlockNumber);
        statement.blobHashesHash = _hashBlobHashes();
        statement.forcedInclusionHeadBefore = _origin.head;
        statement.forcedInclusionHeadAfter = _input.forcedInclusionHead;
        statement.activeCommitteeSnapshot = _input.activeCommitteeSnapshot;
        statement.cutHash = _cutHash;
        return keccak256(abi.encode(statement));
    }

    /// @dev Spec 6.1 step 7: moves the checkpoint to h, stores the proven snapshot and the new
    /// queue head, writes landings[h] with the actual parent c, saves the SignalService
    /// checkpoint and emits `Landed`. Every narrowing below is exact: h < 2^48 and the new head
    /// is at most the 48-bit tail.
    /// @param _input The landing inputs.
    /// @param _c The checkpoint height the landing settles on.
    /// @param _generation The recovery generation.
    /// @param _headAfter The new queue head.
    /// @param _cutHash The cut hash.
    function _settle(
        LandInput calldata _input,
        uint256 _c,
        uint48 _generation,
        uint256 _headAfter,
        bytes32 _cutHash
    )
        private
    {
        uint48 h = uint48(_input.lastHeight);
        bytes32 lastBlockHash = _input.lastBlockHash;

        _lastCheckpoint = LandedCheckpoint({ height: h, blockHash: lastBlockHash });
        _activeCommitteeSnapshot = _input.activeCommitteeSnapshot;
        _forcedInclusions.head = uint48(_headAfter);
        _landings[h] = Landing({
            parentHeight: uint48(_c),
            generation: _generation,
            head: uint48(_headAfter),
            elHash: lastBlockHash,
            cometHash: _input.lastCometHash
        });

        _signalService.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: h, blockHash: lastBlockHash, stateRoot: _input.lastStateRoot
            })
        );

        emit Landed(_input.parentHeight, _c, h, _cutHash, _input.activeCommitteeSnapshot, VERSION);
    }

    /// @dev Returns the hash of L1 block `_number`: from `blockhash` up to 256 blocks back, from
    /// the EIP-2935 history contract up to 8191 blocks back. The number is a full word, so a
    /// value of 2^64 or more is never in the past.
    /// @param _number The L1 block number.
    /// @return hash_ The block hash; reverts with `ReferenceBlockUnavailable` unless the block is
    /// in the past, within the window and its hash non-zero.
    function _readL1ReferenceBlockHash(uint256 _number) private view returns (bytes32 hash_) {
        require(_number < block.number, ReferenceBlockUnavailable());
        uint256 age = block.number - _number;
        if (age <= _BLOCKHASH_WINDOW) {
            hash_ = blockhash(_number);
        } else {
            require(age <= _HISTORY_SERVE_WINDOW, ReferenceBlockUnavailable());
            (bool success, bytes memory data) =
                _HISTORY_STORAGE_ADDRESS.staticcall(abi.encode(_number));
            require(success && data.length == 32, ReferenceBlockUnavailable());
            hash_ = abi.decode(data, (bytes32));
        }
        require(hash_ != 0, ReferenceBlockUnavailable());
    }

    /// @dev Returns keccak256(abi.encodePacked(blobHashes)) over the transaction's versioned blob
    /// hashes in index order, up to the first zero.
    /// @return The hash of the blob hash list; reverts with `InvalidBlobCount` unless there are
    /// 1 to 6 blobs.
    function _hashBlobHashes() private view returns (bytes32) {
        uint256 count;
        while (count <= MAX_BLOBS && blobhash(count) != 0) {
            ++count;
        }
        require(count != 0 && count <= MAX_BLOBS, InvalidBlobCount());

        bytes32[] memory hashes = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            hashes[i] = blobhash(i);
        }
        return keccak256(abi.encodePacked(hashes));
    }

    /// @dev Checks the spec 10 deployment constraints `init` can check. Every stored 48-bit field
    /// fits once these pass: the cutoff is below `block.number`, itself below 2^48.
    /// @param _params The genesis inputs.
    function _validateInitParams(InitParams calldata _params) private view {
        require(_params.genesisBlockHash != 0 && _params.genesisStateRoot != 0, InvalidGenesis());
        require(_params.committeeRecordHash != 0, ZeroCommitteeRecord());
        // L + 1 < 2^48.
        require(
            _params.epochLenL2 >= _MIN_EPOCH_LEN_L2 && _params.epochLenL2 < type(uint48).max,
            InvalidEpochLength()
        );
        require(_isValidCommitteeConfig(_params.committeeConfig), InvalidCommitteeConfig());
        require(
            _params.forcedInclusionDelay != 0 && _params.forcedInclusionDelay <= type(uint48).max,
            InvalidForcedInclusionDelay()
        );
        require(
            _params.maxAnchorAge >= _MIN_MAX_ANCHOR_AGE && _params.maxAnchorAge <= type(uint48).max,
            InvalidMaxAnchorAge()
        );
        require(
            block.number <= type(uint48).max && block.timestamp <= type(uint48).max, ValueOverflow()
        );
        // The registry must be this Inbox's before its checkpoints are trusted (spec 4.1).
        require(
            _stakingRegistry.inbox() == address(this) && _stakingRegistry.l2ChainId() == _l2ChainId,
            RegistryMismatch()
        );
        require(_isValidGenesisCutoff(_params.genesisCutoff), InvalidGenesisCutoff());
    }

    /// @dev Returns whether `_cutoff` is a past L1 block at or after the registry's first
    /// checkpoint; a registry without checkpoints accepts none.
    /// @param _cutoff The genesis cutoff.
    /// @return Whether the cutoff is valid.
    function _isValidGenesisCutoff(uint256 _cutoff) private view returns (bool) {
        return _cutoff < block.number && _stakingRegistry.checkpointCount() != 0
            && _cutoff >= _stakingRegistry.checkpointAt(0).l1Block;
    }

    /// @dev Returns whether the committee configuration is within the spec 10 bounds:
    /// 6 <= U <= 65,532 with U a multiple of 6, vp_unit >= 867,361,738, s_min >= vp_unit and
    /// 1 <= n_max <= 4096.
    /// @param _config The committee configuration.
    /// @return Whether the configuration is valid.
    function _isValidCommitteeConfig(CommitteeConfig calldata _config) private pure returns (bool) {
        uint256 unsettledLimit = _config.unsettledLimit;
        return unsettledLimit >= GRID_INTERVAL && unsettledLimit <= _MAX_UNSETTLED_LIMIT
            && unsettledLimit % GRID_INTERVAL == 0 && _config.vpUnit >= _MIN_VP_UNIT
            && _config.sMin >= _config.vpUnit && _config.nMax != 0
            && _config.nMax <= _MAX_COMMITTEE_SIZE;
    }

    /// @dev Narrows `_value` to a 48-bit storage field (appendix B).
    /// @param _value The value to store.
    /// @return The value as a `uint48`; reverts with `ValueOverflow` if it is 2^48 or more.
    function _toUint48(uint256 _value) private pure returns (uint48) {
        require(_value <= type(uint48).max, ValueOverflow());
        return uint48(_value);
    }

    /// @dev Returns `committeeConfigHash`: keccak256 over the seven words (224 bytes) of the tag,
    /// the L2 chain id, the registry and the four configuration values (appendix A).
    /// @param _config The committee configuration.
    /// @return The configuration hash.
    function _hashCommitteeConfig(CommitteeConfig calldata _config) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _COMMITTEE_CONFIG_TAG,
                uint256(_l2ChainId),
                address(_stakingRegistry),
                _config.vpUnit,
                _config.sMin,
                _config.nMax,
                _config.unsettledLimit
            )
        );
    }
}
