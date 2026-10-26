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
    function land(LandInput calldata, bytes32[] calldata, bytes calldata)
        external
        notImplemented
    { }

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
    function sweepProtocolFees() external nonReentrant {
        uint256 amount = address(this).balance;
        emit ProtocolFeesSwept(amount);
        _protocolFeeRecipient.sendEtherAndVerify(amount);
    }

    /// @inheritdoc IEtnaInbox
    function recover(
        uint48,
        uint256,
        Exclusion[] calldata,
        uint256[] calldata
    )
        external
        notImplemented
    { }

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
