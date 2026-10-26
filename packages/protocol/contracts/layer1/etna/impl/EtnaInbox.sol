// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { LibEtnaForcedInclusion } from "../libs/LibEtnaForcedInclusion.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
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
    function init(InitParams calldata) external notImplemented { }

    /// @inheritdoc IEtnaInbox
    function land(LandInput calldata, bytes32[] calldata, bytes calldata)
        external
        notImplemented
    { }

    /// @inheritdoc IEtnaInbox
    function saveForcedInclusion(bytes calldata) external payable notImplemented { }

    /// @inheritdoc IEtnaInbox
    function sweepProtocolFees() external notImplemented { }

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
}
