// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { LibEtnaForcedInclusion } from "../libs/LibEtnaForcedInclusion.sol";
import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibForcedInclusion } from "src/layer1/core/libs/LibForcedInclusion.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

import "./EtnaInbox_Layout.sol"; // DO NOT DELETE

/// @title EtnaInbox
/// @notice The L1 anchor of an Etna PoS chain starting at L2 block 0. A fresh proxy records its
/// genesis checkpoint and initial committee in one initialization, then lands proven batches.
/// @dev Uses the existing ABCI storage interface without any Shasta proposal state or migration
/// logic. Slots 251–257, 259–267 and 275–277 are reserved to keep the node-facing slots unchanged.
/// The forced inclusion store reuses Shasta's queue, fee rule, events and errors; its queue lives
/// at slots 280–281 and its genesis delay and maximum anchor age at slot 282.
/// @custom:security-contact security@taiko.xyz
contract EtnaInbox is IEtnaInbox, IForcedInclusionStore, EssentialContract {
    using LibAddress for address;
    using LibEtnaForcedInclusion for LibForcedInclusion.Storage;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev The V5 statement in wire order. All fields are static, so abi.encode of this
    /// memory-only struct is the same fifteen-word encoding as the flat field list. Building
    /// it one field at a time keeps the non-IR compiler within its stack limit.
    struct LandStatement {
        bytes32 domain;
        uint256 l1ChainId;
        uint64 l2ChainId;
        address inbox;
        address stakingRegistry;
        uint64 generation;
        uint64 parentHeight;
        bytes32 parentHash;
        bytes32 committeeConfigHash;
        uint64 lastHeight;
        bytes32 lastBlockHash;
        bytes32 lastStateRoot;
        uint64 l1ReferenceBlockNumber;
        bytes32 l1ReferenceBlockHash;
        bytes32 blobHashesHash;
    }

    /// @dev The genesis forced inclusion parameters, packed into one storage word.
    struct ForcedInclusionConfig {
        uint64 delay;
        uint64 maxAnchorAge;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev The initialized status value expected by the ABCI node.
    uint8 private constant _ETNA_ACTIVE = 3;

    /// @dev The smallest epoch length in L2 blocks.
    uint64 private constant _MIN_EPOCH_LEN_L2 = 3;

    /// @dev The age at which a forced inclusion entry expires; the delay must stay below it.
    uint64 private constant _FORCED_INCLUSION_EXPIRY = 14 days;

    /// @dev The domain tag of the landing statement.
    bytes32 private constant _LAND_STATEMENT_TAG = bytes32("TAIKO_ETNA_LAND_V5");

    /// @dev The number of most recent L1 blocks whose hash `blockhash` returns.
    uint256 private constant _BLOCKHASH_WINDOW = 256;

    /// @dev The EIP-2935 history storage contract.
    address private constant _HISTORY_STORAGE_ADDRESS = 0x0000F90827F1C53a10cb7A02335B175320002935;

    /// @dev The number of most recent L1 blocks whose hash the EIP-2935 contract serves.
    uint256 private constant _HISTORY_SERVE_WINDOW = 8191;

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @dev The verifier of `land` proofs.
    IProofVerifier internal immutable _proofVerifier;

    /// @dev The L1 signal service that stores the L2 checkpoints.
    ISignalService internal immutable _signalService;

    /// @dev The Etna staking registry.
    IEtnaStakingRegistry internal immutable _stakingRegistry;

    /// @dev The chain id of the Etna L2.
    uint64 internal immutable _l2ChainId;

    /// @dev The maximum number of L2 blocks one `land` call may cover.
    uint64 internal immutable _maxBatchBlocks;

    /// @dev The forced inclusion fee in Gwei with an empty queue.
    uint64 internal immutable _forcedInclusionFeeInGwei;

    /// @dev The number of pending forced inclusions at which the fee doubles.
    uint64 internal immutable _forcedInclusionFeeDoubleThreshold;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Slots 251–257: reserved to preserve the existing ABCI storage interface.
    uint256[7] private __reservedBeforeStatus;

    /// @dev Slot 258: 3 once initialized; zero before initialization.
    uint8 private _status;

    /// @dev Slots 259–267: reserved to preserve the ABCI storage interface.
    uint256[9] private __reservedSpec;

    /// @dev Slot 268: the recovery generation (bits 0–63; the rest is reserved for GOV-04).
    uint64 private _recoveryGeneration;

    /// @dev Slot 269: the authenticated parent-anchor committee derivation configuration.
    bytes32 private _committeeConfigHash;

    /// @dev Slots 270–271: the latest landed L2 block.
    LandedCheckpoint private _lastCheckpoint;

    /// @dev Slots 272–274: the genesis record at the existing activation-record slots.
    Activation private _activation;

    /// @dev Slots 275–277: reserved (#22262 publication register).
    uint256[3] private __reservedPublications;

    /// @dev Slot 278: the genesis committee record commitment; no future epoch mapping.
    bytes32 private _genesisCommitteeRecordHash;

    /// @dev Slot 279: the L1 block of the epoch-0 committee snapshot.
    uint64 private _genesisCutoff;

    /// @dev Slots 280–281: the forced inclusion queue. Slot 280 is the `queue` mapping; slot 281
    /// packs `head` (bits 0–47) and `tail` (bits 48–95).
    LibForcedInclusion.Storage private _forcedInclusionStorage;

    /// @dev Slot 282: the forced inclusion delay (bits 0–63) and the maximum anchor age
    /// (bits 64–127), in seconds.
    ForcedInclusionConfig private _forcedInclusionConfig;

    uint256[18] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the implementation's immutable parameters.
    /// @param _config The configuration; addresses, `l2ChainId`, `maxBatchBlocks` and both
    /// forced inclusion fee parameters must be non-zero.
    constructor(Config memory _config) {
        require(_config.proofVerifier != address(0), ZERO_ADDRESS());
        require(_config.signalService != address(0), ZERO_ADDRESS());
        require(_config.stakingRegistry != address(0), ZERO_ADDRESS());
        require(_config.l2ChainId != 0, ZERO_VALUE());
        require(_config.maxBatchBlocks != 0, ZERO_VALUE());
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
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IEtnaInbox
    function init(address _owner, GenesisParams calldata _params) external initializer {
        require(_params.genesisBlockHash != 0 && _params.genesisStateRoot != 0, InvalidGenesis());
        require(
            _params.epochLenL2 >= _MIN_EPOCH_LEN_L2 && _params.epochLenL1 != 0, InvalidEpochLength()
        );
        require(_isValidGenesisCutoff(_params.genesisCutoff), InvalidGenesisCutoff());
        require(_params.committeeRecordHash != 0, ZeroCommitteeRecord());
        require(_params.committeeConfigHash != 0, ZeroCommitteeConfigHash());
        require(
            _params.forcedInclusionDelay != 0
                && _params.forcedInclusionDelay < _FORCED_INCLUSION_EXPIRY,
            InvalidForcedInclusionDelay()
        );
        require(_params.maxAnchorAge != 0, InvalidMaxAnchorAge());

        __Essential_init(_owner);
        uint64 l1Block = uint64(block.number);
        _status = _ETNA_ACTIVE;
        _activation = Activation({
            genesisHeight: 0,
            l1Block: l1Block,
            epochLenL2: _params.epochLenL2,
            epochLenL1: _params.epochLenL1,
            genesisBlockHash: _params.genesisBlockHash,
            genesisStateRoot: _params.genesisStateRoot
        });
        _genesisCutoff = _params.genesisCutoff;
        _genesisCommitteeRecordHash = _params.committeeRecordHash;
        _committeeConfigHash = _params.committeeConfigHash;
        _forcedInclusionConfig = ForcedInclusionConfig({
            delay: _params.forcedInclusionDelay, maxAnchorAge: _params.maxAnchorAge
        });
        _lastCheckpoint = LandedCheckpoint({ height: 0, blockHash: _params.genesisBlockHash });
        _signalService.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: 0,
                blockHash: _params.genesisBlockHash,
                stateRoot: _params.genesisStateRoot
            })
        );

        emit EtnaInitialized(
            _params.genesisBlockHash,
            _params.genesisStateRoot,
            l1Block,
            _params.epochLenL2,
            _params.epochLenL1,
            _params.genesisCutoff,
            _params.committeeRecordHash
        );
    }

    /// @inheritdoc IEtnaInbox
    function land(LandInput calldata _input, bytes calldata _proof) external nonReentrant {
        require(_status == _ETNA_ACTIVE, EtnaNotActive());

        LandedCheckpoint memory parent = _lastCheckpoint;
        uint64 lastHeight = _input.lastHeight;
        require(lastHeight > parent.height, NoProgress());
        require(lastHeight - parent.height <= _maxBatchBlocks, BatchTooLarge());
        require(lastHeight <= type(uint48).max, HeightOverflow());

        bytes32 statementHash = _hashLandStatement(
            _recoveryGeneration,
            parent.height,
            parent.blockHash,
            _input,
            _readL1ReferenceBlockHash(_input.l1ReferenceBlockNumber),
            _readBlobHashes()
        );

        _lastCheckpoint = LandedCheckpoint({ height: lastHeight, blockHash: _input.lastBlockHash });
        _signalService.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: uint48(lastHeight),
                blockHash: _input.lastBlockHash,
                stateRoot: _input.lastStateRoot
            })
        );
        emit BatchLanded(
            parent.height + 1,
            lastHeight,
            _input.lastBlockHash,
            _input.lastStateRoot,
            _input.l1ReferenceBlockNumber,
            statementHash,
            msg.sender
        );

        _proofVerifier.verifyProof(0, statementHash, _proof);
    }

    /// @inheritdoc IEtnaInbox
    function hashLandStatement(
        uint64 _generation,
        uint64 _parentHeight,
        bytes32 _parentHash,
        LandInput calldata _input,
        bytes32 _l1ReferenceBlockHash,
        bytes32[] calldata _blobHashes
    )
        external
        view
        returns (bytes32 statementHash_)
    {
        return _hashLandStatement(
            _generation, _parentHeight, _parentHash, _input, _l1ReferenceBlockHash, _blobHashes
        );
    }

    /// @inheritdoc IForcedInclusionStore
    /// @dev Requires the Inbox to be active. Charges and records the fee like Shasta, and refunds
    /// any excess to the caller.
    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference)
        external
        payable
        nonReentrant
    {
        require(_status == _ETNA_ACTIVE, EtnaNotActive());

        uint256 refund = _forcedInclusionStorage.save(
            _forcedInclusionFeeInGwei, _forcedInclusionFeeDoubleThreshold, _blobReference
        );
        msg.sender.sendEtherAndVerify(refund);
    }

    /// @inheritdoc IEtnaInbox
    function lastCheckpoint() external view returns (LandedCheckpoint memory) {
        return _lastCheckpoint;
    }

    /// @inheritdoc IEtnaInbox
    function committeeConfigHash() external view returns (bytes32 configHash_) {
        return _committeeConfigHash;
    }

    /// @inheritdoc IEtnaInbox
    function genesisCommitteeRecordHash() external view returns (bytes32 recordHash_) {
        return _genesisCommitteeRecordHash;
    }

    /// @inheritdoc IEtnaInbox
    function activation() external view returns (Activation memory) {
        return _activation;
    }

    /// @inheritdoc IEtnaInbox
    function genesisCutoff() external view returns (uint64) {
        return _genesisCutoff;
    }

    /// @inheritdoc IEtnaInbox
    function forcedInclusionDelay() external view returns (uint64) {
        return _forcedInclusionConfig.delay;
    }

    /// @inheritdoc IEtnaInbox
    function maxAnchorAge() external view returns (uint64) {
        return _forcedInclusionConfig.maxAnchorAge;
    }

    /// @inheritdoc IEtnaInbox
    function migrationState() external view returns (uint8) {
        return _status;
    }

    /// @inheritdoc IEtnaInbox
    function recoveryGeneration() external view returns (uint64) {
        return _recoveryGeneration;
    }

    /// @inheritdoc IForcedInclusionStore
    function getCurrentForcedInclusionFee() external view returns (uint64 feeInGwei_) {
        return _forcedInclusionStorage.currentFee(
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
        returns (ForcedInclusion[] memory inclusions_)
    {
        return LibForcedInclusion.getForcedInclusions(_forcedInclusionStorage, _start, _maxCount);
    }

    /// @inheritdoc IForcedInclusionStore
    function getForcedInclusionState() external view returns (uint48 head_, uint48 tail_) {
        return LibForcedInclusion.getForcedInclusionState(_forcedInclusionStorage);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Computes the landing statement hash; the single encoding behind `land` and
    /// `hashLandStatement`. The execution address is the Inbox proxy under delegatecall, and
    /// the registry address comes from this implementation's immutable configuration. The guest
    /// and the lander reproduce this encoding byte for byte.
    /// @param _generation The recovery generation.
    /// @param _parentHeight The height of the block the batch builds on.
    /// @param _parentHash The hash of the block the batch builds on.
    /// @param _input The batch.
    /// @param _l1ReferenceBlockHash The L1 block hash of `_input.l1ReferenceBlockNumber`.
    /// @param _blobHashes The versioned hashes of the batch's blobs.
    /// @return The landing statement hash.
    function _hashLandStatement(
        uint64 _generation,
        uint64 _parentHeight,
        bytes32 _parentHash,
        LandInput calldata _input,
        bytes32 _l1ReferenceBlockHash,
        bytes32[] memory _blobHashes
    )
        internal
        view
        returns (bytes32)
    {
        LandStatement memory statement;
        statement.domain = _LAND_STATEMENT_TAG;
        statement.l1ChainId = block.chainid;
        statement.l2ChainId = _l2ChainId;
        statement.inbox = address(this);
        statement.stakingRegistry = address(_stakingRegistry);
        statement.generation = _generation;
        statement.parentHeight = _parentHeight;
        statement.parentHash = _parentHash;
        statement.committeeConfigHash = _committeeConfigHash;
        statement.lastHeight = _input.lastHeight;
        statement.lastBlockHash = _input.lastBlockHash;
        statement.lastStateRoot = _input.lastStateRoot;
        statement.l1ReferenceBlockNumber = _input.l1ReferenceBlockNumber;
        statement.l1ReferenceBlockHash = _l1ReferenceBlockHash;
        statement.blobHashesHash = keccak256(abi.encodePacked(_blobHashes));
        return keccak256(abi.encode(statement));
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Returns the hash of L1 block `_l1ReferenceBlockNumber`: from `blockhash` for the last 256
    /// blocks, from the EIP-2935 history contract for the last 8191; reverts otherwise or if the
    /// hash is zero.
    /// @param _l1ReferenceBlockNumber The L1 block number.
    /// @return l1ReferenceBlockHash_ The L1 block hash.
    function _readL1ReferenceBlockHash(uint64 _l1ReferenceBlockNumber)
        private
        view
        returns (bytes32 l1ReferenceBlockHash_)
    {
        require(_l1ReferenceBlockNumber < block.number, AnchorUnavailable());
        uint256 age = block.number - _l1ReferenceBlockNumber;
        if (age <= _BLOCKHASH_WINDOW) {
            l1ReferenceBlockHash_ = blockhash(_l1ReferenceBlockNumber);
        } else {
            require(age <= _HISTORY_SERVE_WINDOW, AnchorUnavailable());
            (bool success, bytes memory data) =
                _HISTORY_STORAGE_ADDRESS.staticcall(abi.encode(uint256(_l1ReferenceBlockNumber)));
            require(success && data.length == 32, AnchorUnavailable());
            l1ReferenceBlockHash_ = abi.decode(data, (bytes32));
        }
        require(l1ReferenceBlockHash_ != 0, AnchorUnavailable());
    }

    /// @dev Returns the versioned hashes of the transaction's blobs; reverts if there are none.
    /// @return blobHashes_ `blobhash(0)`, `blobhash(1)`, ... up to the first zero.
    function _readBlobHashes() private view returns (bytes32[] memory blobHashes_) {
        uint256 count;
        while (blobhash(count) != 0) {
            ++count;
        }
        require(count != 0, BlobsRequired());

        blobHashes_ = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            blobHashes_[i] = blobhash(i);
        }
    }

    /// @dev Returns whether `_cutoff` is a past L1 block at or after the registry's first
    /// checkpoint, so the epoch-0 snapshot exists.
    /// @param _cutoff The genesis cutoff.
    /// @return Whether the cutoff is valid.
    function _isValidGenesisCutoff(uint64 _cutoff) private view returns (bool) {
        if (_cutoff >= block.number) return false;
        if (_stakingRegistry.checkpointCount() == 0) return false;
        return _stakingRegistry.checkpointAt(0).l1Block <= _cutoff;
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error AnchorUnavailable();
    error BatchTooLarge();
    error BlobsRequired();
    error EtnaNotActive();
    error ForcedInclusionFeeDoubleThresholdZero();
    error ForcedInclusionFeeZero();
    error InvalidGenesis();
    error HeightOverflow();
    error InvalidEpochLength();
    error InvalidForcedInclusionDelay();
    error InvalidGenesisCutoff();
    error InvalidMaxAnchorAge();
    error NoProgress();
    error ZeroCommitteeRecord();
    error ZeroCommitteeConfigHash();
}
