// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { IUnzenProposeCutoff } from "../iface/IUnzenProposeCutoff.sol";
import { LibEtnaForcedInclusion } from "../libs/LibEtnaForcedInclusion.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibEtnaKeys } from "src/shared/etna/LibEtnaKeys.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

import "./EtnaInbox_Layout.sol"; // DO NOT DELETE

/// @title EtnaInbox
/// @notice The L1 Inbox of an Etna PoS chain; see `IEtnaInbox`.
/// @dev The proxy first runs `EtnaInboxBootstrap`; its owner then upgrades to this contract and
/// calls `init`. On a new network `init` also writes the Etna start at block 0; on a switching
/// network anyone writes it later with `setOrigin`, once the Unzen Inbox's proposals are closed
/// and fully proven. Storage follows spec appendix B
/// exactly: its named slots 258, 268-274, 278-282, 285, 290, 292 and 293 sit where it lists them,
/// the fallback key list that `getFallbackKeys` returns, which no anchor witness proves, is the
/// dynamic array at slot 275, reserved slots 283, 284, 286-289 and 291 are never read or written,
/// and slots 251-257, 259-267, 276 and 277 are unused.
/// @custom:security-contact security@taiko.xyz
// solhint-disable-next-line max-states-count
contract EtnaInbox is IEtnaInbox, EssentialContract {
    using LibAddress for address;
    using LibEtnaForcedInclusion for LibEtnaForcedInclusion.Storage;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev Slot 282: the forced inclusion parameters in seconds, packed from the
    /// least-significant bit.
    struct ForcedInclusionConfig {
        uint48 delay;
        uint48 maxAnchorAge;
    }

    /// @dev The 19 static words of the landing statement in appendix A order; its ABI encoding is
    /// the 608-byte statement preimage.
    struct LandStatement {
        bytes32 tag;
        uint256 l1ChainId;
        uint256 l2ChainId;
        address inbox;
        uint256 generation;
        uint256 parentHeight;
        bytes32 parentHash;
        bytes32 parentCometHash;
        bytes32 configHash;
        uint256 lastHeight;
        bytes32 lastBlockHash;
        bytes32 lastCometHash;
        bytes32 lastStateRoot;
        uint256 l1ReferenceBlockNumber;
        bytes32 l1ReferenceBlockHash;
        bytes32 blobHashesHash;
        uint256 forcedInclusionHeadBefore;
        uint256 forcedInclusionHeadAfter;
        bytes32 cutHash;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice The landing statement version emitted by `Landed`.
    uint8 public constant VERSION = 1;

    /// @notice The maximum byte length of a forced transaction (spec 7.1).
    uint256 public constant MAX_FORCED_TX_BYTES = 8192;

    /// @notice The maximum number of blobs of a landing (spec 6.1).
    uint256 public constant MAX_BLOBS = 6;

    /// @notice The slot 258 value once initialized.
    uint8 public constant INITIALIZED_STATUS = 3;

    /// @dev The domain tag of the config hash (appendix A).
    bytes32 private constant _CONFIG_TAG = bytes32("ETNA_CONFIG_V1");

    /// @dev The domain tag of the fallback key hash (appendix A).
    bytes32 private constant _FALLBACK_KEYS_TAG = bytes32("ETNA_FALLBACK_KEYS_V1");

    /// @dev The maximum number of fallback keys (spec 4.3).
    uint256 private constant _MAX_FALLBACK_KEYS = 128;

    /// @dev The minimum `maxAnchorAge` in seconds (spec 10).
    uint256 private constant _MIN_MAX_ANCHOR_AGE = 1152;

    /// @dev The maximum `U` (spec 10).
    uint256 private constant _MAX_UNSETTLED_LIMIT = 262_144;

    /// @dev The maximum `maxBatchBlocks` (spec 11): the largest B whose landing fits the EIP-7825
    /// per-transaction cap of 2^24 = 16,777,216 gas. A landing of B blocks carries B - 1 leaves;
    /// with a 4 KiB proof its calldata is 4,452 + 32 * (B - 1) bytes. Counting every byte as
    /// non-zero at today's EIP-7623 floor of 40 gas, B = 12,952 needs 21,000 + 40 * 418,884 =
    /// 16,776,360 gas and B + 1 needs 16,777,640. The floor sets the gas: at this limit `land`
    /// with six blobs executes in about 1.1M gas besides the verifier, and standard calldata
    /// pricing (16 gas per byte) leaves 10.05M below the floor for execution and verification. A
    /// higher calldata floor would need a lower limit.
    uint256 private constant _MAX_BATCH_BLOCKS_LIMIT = 12_952;

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

    /// @inheritdoc IEtnaInbox
    address public immutable override etnaStaking;

    /// @inheritdoc IEtnaInbox
    uint64 public immutable override l2ChainId;

    /// @inheritdoc IEtnaInbox
    uint64 public immutable override maxBatchBlocks;

    /// @inheritdoc IEtnaInbox
    uint64 public immutable override forcedInclusionFeeInGwei;

    /// @inheritdoc IEtnaInbox
    uint64 public immutable override forcedInclusionFeeDoubleThreshold;

    /// @inheritdoc IEtnaInbox
    address public immutable override protocolFeeRecipient;

    /// @inheritdoc IEtnaInbox
    address public immutable override unzenInbox;

    /// @inheritdoc IEtnaInbox
    uint48 public immutable override etnaForkTime;

    /// @inheritdoc IEtnaInbox
    uint64 public immutable override unsettledLimit;

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

    /// @dev Slot 269: the config hash.
    bytes32 private _configHash;

    /// @dev Slots 270-271: the latest landed checkpoint.
    LandedCheckpoint private _lastCheckpoint;

    /// @dev Slots 272-274: the start record.
    GenesisRecord private _genesis;

    /// @dev Slot 275: the fallback key list, two words per key from keccak256(275).
    FallbackKey[] private _fallbackKeys;

    /// @dev Slots 276-277: unused.
    uint256[2] private __reserved276;

    /// @dev Slot 278: the fallback key hash (appendix A).
    bytes32 private _fallbackKeysHash;

    /// @dev Slot 279: `minTotalStake`.
    uint256 private _minTotalStake;

    /// @dev Slots 280-281: the forced inclusion queue and its packed head and tail.
    LibEtnaForcedInclusion.Storage private _forcedInclusions;

    /// @dev Slot 282: the forced inclusion delay and the maximum anchor age.
    ForcedInclusionConfig private _forcedInclusionConfig;

    /// @dev Slots 283-284: reserved; never read or written.
    uint256[2] private __reserved283;

    /// @dev Slot 285: the landing record of every checkpoint height.
    mapping(uint256 height => Landing landing) private _landings;

    /// @dev Slots 286-289: reserved; never read or written.
    uint256[4] private __reserved286;

    /// @dev Slot 290: the fixed origin of every recovery generation.
    mapping(uint256 generation => Origin origin) private _origins;

    /// @dev Slot 291: reserved; never read or written.
    uint256 private __reserved291;

    /// @dev Slot 292: monotonic recovery authorization nonce, never restored from history.
    uint256 private _recoveryNonce;

    /// @dev Slot 293: the rules schedule.
    RulesSchedule private _rulesSchedule;

    uint256[7] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the implementation's immutable parameters.
    /// @param _config The configuration: non-zero addresses and L2 chain id, `maxBatchBlocks` in
    /// [1, 12,952], non-zero forced inclusion fee parameters, `unsettledLimit` in [1, 262,144],
    /// and either no switching parameters (a new network) or both with an Unzen Inbox that has
    /// code (a switching network).
    constructor(Config memory _config) {
        bool switching = _config.unzenInbox != address(0);
        require(
            (_config.etnaForkTime != 0) == switching
                && (!switching || _config.unzenInbox.code.length != 0),
            InvalidSwitchConfig()
        );
        require(
            _config.unsettledLimit != 0 && _config.unsettledLimit <= _MAX_UNSETTLED_LIMIT,
            InvalidUnsettledLimit()
        );
        require(_config.proofVerifier != address(0), ZERO_ADDRESS());
        require(_config.signalService != address(0), ZERO_ADDRESS());
        require(_config.etnaStaking != address(0), ZERO_ADDRESS());
        require(_config.protocolFeeRecipient != address(0), ZERO_ADDRESS());
        require(_config.l2ChainId != 0, ZERO_VALUE());
        require(
            _config.maxBatchBlocks != 0 && _config.maxBatchBlocks <= _MAX_BATCH_BLOCKS_LIMIT,
            InvalidMaxBatchBlocks()
        );
        require(_config.forcedInclusionFeeInGwei != 0, ForcedInclusionFeeZero());
        require(
            _config.forcedInclusionFeeDoubleThreshold != 0, ForcedInclusionFeeDoubleThresholdZero()
        );

        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _signalService = ISignalService(_config.signalService);
        etnaStaking = _config.etnaStaking;
        l2ChainId = _config.l2ChainId;
        maxBatchBlocks = _config.maxBatchBlocks;
        forcedInclusionFeeInGwei = _config.forcedInclusionFeeInGwei;
        forcedInclusionFeeDoubleThreshold = _config.forcedInclusionFeeDoubleThreshold;
        protocolFeeRecipient = _config.protocolFeeRecipient;
        unzenInbox = _config.unzenInbox;
        etnaForkTime = _config.etnaForkTime;
        unsettledLimit = _config.unsettledLimit;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IEtnaInbox
    /// @dev Writes only the non-zero appendix B values: a proxy that has only run the bootstrap
    /// holds zero in every other Inbox slot, which is the remaining initial state (generation 0,
    /// nonce 0, an empty queue and rules schedule 0).
    function init(InitParams calldata _params) external reinitializer(2) onlyOwner {
        _validateInitialState();
        _validateInitParams(_params);
        _checkFallbackKeys(_params.fallbackKeys);

        bytes32 hash = keccak256(
            abi.encode(_CONFIG_TAG, uint256(l2ChainId), etnaStaking, uint256(unsettledLimit))
        );

        _initStatus = INITIALIZED_STATUS;
        _configHash = hash;
        _forcedInclusionConfig = ForcedInclusionConfig({
            delay: uint48(_params.forcedInclusionDelay), maxAnchorAge: uint48(_params.maxAnchorAge)
        });
        _storeFallbackKeys(_params.fallbackKeys);
        _minTotalStake = _params.minTotalStake;
        emit MinTotalStakeUpdated(_params.minTotalStake);

        emit EtnaInitialized(hash, etnaStaking, unsettledLimit);

        if (unzenInbox == address(0)) {
            _writeStart(0, _params.genesisBlockHash, _params.genesisStateRoot);
            _signalService.saveCheckpoint(
                ICheckpointStore.Checkpoint({
                    blockNumber: 0,
                    blockHash: _params.genesisBlockHash,
                    stateRoot: _params.genesisStateRoot
                })
            );
        }
    }

    /// @inheritdoc IEtnaInbox
    /// @dev Follows the reference Solidity of the switching start check for check, plus the
    /// 48-bit checks of the start write. Unaffected by pause. Its only external calls are three
    /// static reads: the Unzen Inbox's `proposeCutoff()` and `getCoreState()` and the
    /// SignalService's `getCheckpoint(S)`.
    function setOrigin(uint48 _s) external nonReentrant {
        require(_initStatus == INITIALIZED_STATUS, NotInitialized());
        require(_genesis.startBlockHash == 0, StartAlreadyWritten());
        require(unzenInbox != address(0) && etnaForkTime != 0, NotSwitching());
        require(_s != 0, InvalidStart());
        require(block.timestamp >= etnaForkTime, BeforeEtnaForkTime());

        uint48 cutoff = IUnzenProposeCutoff(unzenInbox).proposeCutoff();
        require(cutoff != 0 && block.timestamp >= cutoff, ProposalsNotClosed());

        IInbox.CoreState memory unzen = IInbox(unzenInbox).getCoreState();
        // Activation proposal 0 counts as finalized, so a closed and fully proven proposal set
        // has nextProposalId == lastFinalizedProposalId + 1.
        require(
            uint256(unzen.nextProposalId) == uint256(unzen.lastFinalizedProposalId) + 1,
            UnzenNotFinalized()
        );
        // Reverts if the SignalService holds no checkpoint at S.
        ICheckpointStore.Checkpoint memory checkpoint = _signalService.getCheckpoint(_s);
        require(
            checkpoint.blockHash != 0 && checkpoint.blockHash == unzen.lastFinalizedBlockHash,
            UnzenStartMismatch()
        );
        require(checkpoint.stateRoot != 0, InvalidStart());
        require(
            block.number <= type(uint48).max && block.timestamp <= type(uint48).max, ValueOverflow()
        );
        _writeStart(_s, checkpoint.blockHash, checkpoint.stateRoot);
    }

    /// @notice Forwards a checkpoint from the Unzen Inbox's `prove` to the SignalService on a
    /// switching network (START-10-5). The L1 SignalService accepts checkpoints only from this
    /// Inbox, so the Unzen Inbox's final checkpoints, including the one at S, reach it here.
    /// @dev Accepts calls only from `unzenInbox`, so it always reverts on a new network. Accepts
    /// any height while slot 273 is zero and reverts at every height once it is nonzero: the
    /// start write closes the forwarder (`ForwardingClosed`). Passes the checkpoint unchanged and
    /// reverts for no other reason than these checks and the SignalService's own: it ignores
    /// pause and initialization.
    /// @param _checkpoint The checkpoint the Unzen Inbox's `prove` saves.
    function saveCheckpoint(ICheckpointStore.Checkpoint calldata _checkpoint)
        external
        onlyFrom(unzenInbox)
    {
        require(_genesis.startBlockHash == 0, ForwardingClosed());
        _signalService.saveCheckpoint(_checkpoint);
    }

    /// @inheritdoc IEtnaInbox
    /// @dev Follows the spec 6.1 reference Solidity: its checks in its order, all before any
    /// write. Before the start write it needs no extra check: c = 0 forces p = 0, and the
    /// unwritten landings[0] fails step 2. Unaffected by pause. The only external calls are the
    /// proof verifier, the EIP-2935 history contract (static) and the SignalService checkpoint
    /// write.
    function land(
        LandInput calldata _input,
        bytes32[] calldata _leaves,
        bytes calldata _proof
    )
        external
        nonReentrant
    {
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
        require(_genesis.startBlockHash != 0, StartNotWritten());
        require(_tx.length <= MAX_FORCED_TX_BYTES, ForcedTransactionTooLarge());

        uint256 feeWei =
            uint256(
                    _forcedInclusions.currentFee(
                        forcedInclusionFeeInGwei, forcedInclusionFeeDoubleThreshold
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
        protocolFeeRecipient.sendEtherAndVerify(amount);
    }

    /// @inheritdoc IEtnaInbox
    /// @dev Checks the recovery state, nonce increment, ruleset and the list before any
    /// transition. The transition blanks the listed forced inclusions, writes the generation,
    /// nonce and origin, emits `Recovered` and writes the rules schedule. A failure reverts all
    /// effects. Unaffected by pause.
    function recover(
        uint48 _expectedGeneration,
        uint256 _expectedC,
        uint256 _expectedRecoveryNonce,
        uint256 _validUntil,
        uint256[] calldata _fiToClear,
        uint48 _rules
    )
        external
        onlyOwner
        nonReentrant
    {
        (uint48 c, uint48 newGeneration) = _checkRecoveryState(
            _expectedGeneration, _expectedC, _expectedRecoveryNonce, _validUntil
        );
        RulesSchedule memory schedule = _recoveredRulesSchedule(_rules);
        _checkFiToClear(_fiToClear);
        uint256 nextNonce = _expectedRecoveryNonce + 1;

        for (uint256 i; i < _fiToClear.length; ++i) {
            _forcedInclusions.queue[_fiToClear[i]].txHash = _BLANK_TX_HASH;
        }
        bytes32 keysHash = _fallbackKeysHash;
        _recoveryGeneration = newGeneration;
        _recoveryNonce = nextNonce;
        _origins[newGeneration] = Origin({
            startHeight: c,
            l1BlockNumber: block.number,
            l1Timestamp: block.timestamp,
            fallbackKeysHash: keysHash
        });

        emit Recovered(newGeneration, c, block.number, block.timestamp, keysHash, _fiToClear);
        _setRulesSchedule(schedule);
    }

    /// @inheritdoc IEtnaInbox
    /// @dev Unaffected by pause. The promotion of a due `nextRules` happens in memory, so a failed
    /// check keeps it from being stored.
    function scheduleRules(
        uint48 _expectedGeneration,
        uint48 _rules,
        uint48 _time
    )
        external
        onlyOwner
        nonReentrant
    {
        _checkScheduleCall(_expectedGeneration);
        RulesSchedule memory schedule = _rulesSchedule;
        uint256 earliest = block.timestamp + _forcedInclusionConfig.maxAnchorAge;

        if (block.timestamp >= schedule.rulesTime) {
            schedule.activeRules = schedule.nextRules;
        } else {
            require(earliest < schedule.rulesTime, RulesLocked());
        }
        require(
            _rules == schedule.nextRules || uint256(_rules) == uint256(schedule.nextRules) + 1,
            InvalidRules()
        );
        require(_time >= earliest, InvalidScheduleTime());

        schedule.nextRules = _rules;
        schedule.rulesTime = _time;
        _setRulesSchedule(schedule);
    }

    /// @inheritdoc IEtnaInbox
    /// @dev Unaffected by pause.
    function scheduleStop(
        uint48 _expectedGeneration,
        uint48 _time
    )
        external
        onlyOwner
        nonReentrant
    {
        _checkScheduleCall(_expectedGeneration);
        RulesSchedule memory schedule = _rulesSchedule;
        uint256 earliest = block.timestamp + _forcedInclusionConfig.maxAnchorAge;

        if (schedule.stopTime != 0) require(earliest < schedule.stopTime, StopLocked());
        if (_time != 0) require(_time >= earliest, InvalidStop());

        schedule.stopTime = _time;
        _setRulesSchedule(schedule);
    }

    /// @inheritdoc IEtnaInbox
    function setFallbackKeys(FallbackKey[] calldata _keys) external onlyOwner nonReentrant {
        require(_initStatus == INITIALIZED_STATUS, NotInitialized());
        _checkFallbackKeys(_keys);
        _storeFallbackKeys(_keys);
    }

    /// @inheritdoc IEtnaInbox
    function setMinTotalStake(uint256 _value) external onlyOwner nonReentrant {
        require(_initStatus == INITIALIZED_STATUS, NotInitialized());
        _minTotalStake = _value;
        emit MinTotalStakeUpdated(_value);
    }

    /// @inheritdoc IEtnaInbox
    function invalidateRecoveryNonce(uint256 _expectedRecoveryNonce)
        external
        onlyOwner
        nonReentrant
    {
        require(_initStatus == INITIALIZED_STATUS, NotInitialized());
        require(_expectedRecoveryNonce == _recoveryNonce, RecoveryNonceMismatch());
        uint256 nextNonce = _recoveryNonce + 1;
        _recoveryNonce = nextNonce;
        emit RecoveryNonceInvalidated(_expectedRecoveryNonce, nextNonce);
    }

    /// @inheritdoc IEtnaInbox
    function recoveryNonce() external view returns (uint256 nonce_) {
        return _recoveryNonce;
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
    function configHash() external view returns (bytes32) {
        return _configHash;
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
    function etnaStart() external view returns (uint48 height_, bytes32 blockHash_) {
        return (_genesis.genesisHeight, _genesis.startBlockHash);
    }

    /// @inheritdoc IEtnaInbox
    function rulesSchedule() external view returns (RulesSchedule memory) {
        return _rulesSchedule;
    }

    /// @inheritdoc IEtnaInbox
    function getFallbackKeys() external view returns (FallbackKey[] memory) {
        return _fallbackKeys;
    }

    /// @inheritdoc IEtnaInbox
    function fallbackKeysHash() external view returns (bytes32) {
        return _fallbackKeysHash;
    }

    /// @inheritdoc IEtnaInbox
    function minTotalStake() external view returns (uint256) {
        return _minTotalStake;
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
    function landings(uint256 _height) external view returns (Landing memory) {
        return _landings[_height];
    }

    /// @inheritdoc IEtnaInbox
    function origins(uint256 _generation) external view returns (Origin memory) {
        return _origins[_generation];
    }

    /// @inheritdoc IEtnaInbox
    function generationStartHeight() external view returns (uint256) {
        require(_genesis.startBlockHash != 0, StartNotWritten());
        return _origins[_recoveryGeneration].startHeight;
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
        return
            _forcedInclusions.currentFee(
                forcedInclusionFeeInGwei, forcedInclusionFeeDoubleThreshold
            );
    }

    /// @inheritdoc IEtnaInbox
    function signalService() external view returns (address) {
        return address(_signalService);
    }

    /// @inheritdoc IEtnaInbox
    function proofVerifier() external view returns (address) {
        return address(_proofVerifier);
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

    /// @dev Spec 6.1 steps 1 and 2: generationStartHeight() <= p <= c < h < 2^48,
    /// h - p <= maxBatchBlocks, and a retained origin record in the current generation unless p is
    /// the generation's start height. The reference's `isValidLanding(p)` is the written-record
    /// check: these contracts have no rollback, so no written record is ever voided.
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
        require(h - p <= maxBatchBlocks, BatchTooLarge());

        origin_ = _landings[p];
        // A written record never has a zero EL hash: the start write rejects a zero start hash,
        // and `land` saves each hash as a SignalService checkpoint, which rejects a zero hash.
        require(origin_.elHash != 0, MissingOrigin());
        require(origin_.generation == _generation || p == startHeight, ForeignGeneration());
    }

    /// @dev Spec 6.1 steps 3 and 4: exactly the h - p - 1 leaves of the heights strictly inside
    /// (p, h), c's recorded queue head equal to the queue head, the leaf at c equal to cutLeaf(c)
    /// over c's record if c > p, and a new queue head in [head, tail] at most h - c past the head.
    /// @param _input The landing inputs.
    /// @param _leaves The cut leaves of the heights p + 1, ..., h - 1.
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
        // No underflow: the range check gives p < h.
        require(_leaves.length == h - p - 1, LeafCountMismatch());

        Landing storage cur = _landings[_c];
        uint256 head = cur.head;
        require(head == _forcedInclusions.head, ForcedInclusionHeadMismatch());
        if (_c > p) {
            require(
                _leaves[_c - p - 1] == keccak256(abi.encode(_c, cur.elHash, cur.cometHash, head)),
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

    /// @dev The start write. Writes slot 272 as (S, L1_0 = block.number), slots 273/274,
    /// generation 0's origin (S, L1_0, block.timestamp, slot 278), the checkpoint (S, hash) and
    /// landings[S] = (S, 0, 0, hash, 0), and emits `StartWritten`. Callers check that S,
    /// block.number and block.timestamp fit 48 bits.
    /// @param _height The Etna start S.
    /// @param _blockHash The EL block hash of S.
    /// @param _stateRoot The state root of S.
    function _writeStart(uint256 _height, bytes32 _blockHash, bytes32 _stateRoot) private {
        uint48 s = uint48(_height);
        _genesis = GenesisRecord({
            genesisHeight: s,
            l1Block: uint48(block.number),
            startBlockHash: _blockHash,
            startStateRoot: _stateRoot
        });
        _origins[0] = Origin({
            startHeight: _height,
            l1BlockNumber: block.number,
            l1Timestamp: block.timestamp,
            fallbackKeysHash: _fallbackKeysHash
        });
        _lastCheckpoint = LandedCheckpoint({ height: s, blockHash: _blockHash });
        _landings[_height] =
            Landing({ parentHeight: s, generation: 0, head: 0, elHash: _blockHash, cometHash: 0 });
        emit StartWritten(_height, _blockHash, _stateRoot);
    }

    /// @dev Spec 8.3: the Inbox is initialized and its start written, the expected generation,
    /// checkpoint and nonce are current, the authorization has not expired, and the new
    /// generation, block.number and block.timestamp fit 48 bits (c already does).
    /// @param _expectedGeneration The authorized generation.
    /// @param _expectedC The authorized checkpoint height.
    /// @param _expectedRecoveryNonce The authorized nonce.
    /// @param _validUntil The inclusive authorization deadline.
    /// @return c_ The checkpoint height.
    /// @return newGeneration_ The generation recovery starts.
    function _checkRecoveryState(
        uint48 _expectedGeneration,
        uint256 _expectedC,
        uint256 _expectedRecoveryNonce,
        uint256 _validUntil
    )
        private
        view
        returns (uint48 c_, uint48 newGeneration_)
    {
        require(_initStatus == INITIALIZED_STATUS, NotInitialized());
        require(_genesis.startBlockHash != 0, StartNotWritten());
        uint48 generation = _recoveryGeneration;
        require(_expectedGeneration == generation, GenerationMismatch());
        c_ = _lastCheckpoint.height;
        require(_expectedC == c_, CheckpointMismatch());
        require(_expectedRecoveryNonce == _recoveryNonce, RecoveryNonceMismatch());
        require(block.timestamp <= _validUntil, AuthorizationExpired());
        newGeneration_ = _toUint48(uint256(generation) + 1);
        // RECOV-8.4-4: an origin record is written once. Only an upgrade that wrote the next
        // generation's record without advancing the generation could trip this.
        require(_origins[newGeneration_].l1BlockNumber == 0, OriginAlreadyWritten());
        require(
            block.number <= type(uint48).max && block.timestamp <= type(uint48).max, ValueOverflow()
        );
    }

    /// @dev Spec 8 RECOV-8-47a: checks a non-zero `_rules` against nextRules + 1 and returns the
    /// schedule recovery writes: the stop cleared and, for a non-zero `_rules`, activeRules =
    /// nextRules = `_rules` with rulesTime 0.
    /// @param _rules Zero, or the new generation's ruleset.
    /// @return schedule_ The new rules schedule.
    function _recoveredRulesSchedule(uint48 _rules)
        private
        view
        returns (RulesSchedule memory schedule_)
    {
        schedule_ = _rulesSchedule;
        if (_rules != 0) {
            require(uint256(_rules) == uint256(schedule_.nextRules) + 1, InvalidRules());
            schedule_.activeRules = _rules;
            schedule_.nextRules = _rules;
            schedule_.rulesTime = 0;
        }
        schedule_.stopTime = 0;
    }

    /// @dev Stores the rules schedule in slot 293 and emits its packed word.
    /// @param _schedule The new rules schedule.
    function _setRulesSchedule(RulesSchedule memory _schedule) private {
        _rulesSchedule = _schedule;
        emit RulesScheduleUpdated(uint256(_schedule.activeRules) | uint256(_schedule.nextRules)
                << 48 | uint256(_schedule.rulesTime) << 96 | uint256(_schedule.stopTime) << 144);
    }

    /// @dev Spec 8: the queue indices to blank are strictly increasing and within [head, tail).
    /// Strict order makes the first and last indices bound the whole list.
    /// @param _fiToClear The queue indices to blank.
    function _checkFiToClear(uint256[] calldata _fiToClear) private view {
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

    /// @dev Builds the landing statement (appendix A) and hashes its 19 words. Runs spec 6.1
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
        statement.l2ChainId = l2ChainId;
        statement.inbox = address(this);
        statement.generation = _generation;
        statement.parentHeight = _input.parentHeight;
        statement.parentHash = _origin.elHash;
        statement.parentCometHash = _origin.cometHash;
        statement.configHash = _configHash;
        statement.lastHeight = _input.lastHeight;
        statement.lastBlockHash = _input.lastBlockHash;
        statement.lastCometHash = _input.lastCometHash;
        statement.lastStateRoot = _input.lastStateRoot;
        statement.l1ReferenceBlockNumber = _input.l1ReferenceBlockNumber;
        statement.l1ReferenceBlockHash = _readL1ReferenceBlockHash(_input.l1ReferenceBlockNumber);
        statement.blobHashesHash = _hashBlobHashes();
        statement.forcedInclusionHeadBefore = _origin.head;
        statement.forcedInclusionHeadAfter = _input.forcedInclusionHead;
        statement.cutHash = _cutHash;
        return keccak256(abi.encode(statement));
    }

    /// @dev Spec 6.1 step 7: moves the checkpoint to h, stores the new queue head, writes
    /// landings[h] with the actual parent c, saves the SignalService checkpoint and emits
    /// `Landed`. Every narrowing below is exact: h < 2^48 and the new head
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

        emit Landed(_input.parentHeight, _c, h, _cutHash, VERSION);
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

    /// @dev Checks the spec 10 deployment constraints `init` can check, and that the genesis hash
    /// and state root are both non-zero on a new network and both zero on a switching network.
    /// Every stored 48-bit field fits once these pass.
    /// @param _params The initialization inputs.
    function _validateInitParams(InitParams calldata _params) private view {
        bool newNetwork = unzenInbox == address(0);
        require(
            (_params.genesisBlockHash != 0) == newNetwork
                && (_params.genesisStateRoot != 0) == newNetwork,
            InvalidGenesis()
        );
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
    }

    /// @dev Rejects finite preexisting Etna state before initializing a bootstrap proxy. This
    /// does not prove every mapping entry empty: deployment provenance and DAO control must
    /// exclude arbitrary historic writes by earlier implementations. Reserved slots are never
    /// read. Slot 272 is compared as a whole word: the start write stores its two fields without
    /// clearing the bits above them, which appendix B requires to be zero.
    function _validateInitialState() private view {
        uint256 startWord;
        assembly ("memory-safe") {
            startWord := sload(_genesis.slot)
        }
        require(
            _initStatus == 0 && _recoveryGeneration == 0 && _configHash == 0
                && _lastCheckpoint.height == 0 && _lastCheckpoint.blockHash == 0 && startWord == 0
                && _genesis.startBlockHash == 0 && _genesis.startStateRoot == 0,
            DirtyInitialState()
        );
        require(
            _fallbackKeys.length == 0 && _fallbackKeysHash == 0 && _minTotalStake == 0
                && _forcedInclusions.head == 0 && _forcedInclusions.tail == 0
                && _forcedInclusionConfig.delay == 0 && _forcedInclusionConfig.maxAnchorAge == 0
                && _recoveryNonce == 0 && _rulesSchedule.activeRules == 0
                && _rulesSchedule.nextRules == 0 && _rulesSchedule.rulesTime == 0
                && _rulesSchedule.stopTime == 0,
            DirtyInitialState()
        );
        for (uint256 generation; generation < 2; ++generation) {
            Origin storage origin = _origins[generation];
            require(
                origin.startHeight == 0 && origin.l1BlockNumber == 0 && origin.l1Timestamp == 0
                    && origin.fallbackKeysHash == 0,
                DirtyInitialState()
            );
        }
    }

    /// @dev Spec 4.3: 1 to 128 keys, each a valid compressed public key, in strictly ascending
    /// order of the 33-byte big-endian value `ckPrefix ‖ ckX`, which compares the prefix first and
    /// X only between equal prefixes. Strict order makes the list and its hash unique.
    /// @param _keys The fallback key list.
    function _checkFallbackKeys(FallbackKey[] calldata _keys) private view {
        uint256 count = _keys.length;
        require(count != 0 && count <= _MAX_FALLBACK_KEYS, InvalidFallbackKeys());
        for (uint256 i; i < count; ++i) {
            FallbackKey calldata key = _keys[i];
            LibEtnaKeys.decompress(key.ckPrefix, key.ckX);
            if (i == 0) continue;
            FallbackKey calldata previous = _keys[i - 1];
            require(
                key.ckPrefix > previous.ckPrefix
                    || (key.ckPrefix == previous.ckPrefix && key.ckX > previous.ckX),
                InvalidFallbackKeys()
            );
        }
    }

    /// @dev Replaces the stored fallback key list with `_keys`, stores its hash (appendix A) and
    /// emits `FallbackKeysUpdated`. The caller has checked the list.
    /// @param _keys The fallback key list.
    function _storeFallbackKeys(FallbackKey[] calldata _keys) private {
        delete _fallbackKeys;
        for (uint256 i; i < _keys.length; ++i) {
            FallbackKey calldata key = _keys[i];
            _fallbackKeys.push(FallbackKey({ ckPrefix: key.ckPrefix, ckX: key.ckX }));
        }
        bytes32 hash = keccak256(abi.encode(_FALLBACK_KEYS_TAG, _keys));
        _fallbackKeysHash = hash;
        emit FallbackKeysUpdated(hash, _keys);
    }

    /// @dev Narrows `_value` to a 48-bit storage field (appendix B).
    /// @param _value The value to store.
    /// @return The value as a `uint48`; reverts with `ValueOverflow` if it is 2^48 or more.
    function _toUint48(uint256 _value) private pure returns (uint48) {
        require(_value <= type(uint48).max, ValueOverflow());
        return uint48(_value);
    }

    /// @dev The checks `scheduleRules` and `scheduleStop` share before reading the schedule:
    /// initialization and the authorized generation.
    /// @param _expectedGeneration The recovery generation the call was authorized for.
    function _checkScheduleCall(uint48 _expectedGeneration) private view {
        require(_initStatus == INITIALIZED_STATUS, NotInitialized());
        require(_expectedGeneration == _recoveryGeneration, GenerationMismatch());
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error DirtyInitialState();
}
