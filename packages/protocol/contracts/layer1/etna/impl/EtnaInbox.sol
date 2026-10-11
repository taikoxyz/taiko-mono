// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

import "./EtnaInbox_Layout.sol"; // DO NOT DELETE

/// @title EtnaInbox
/// @notice The L1 anchor of an Etna PoS chain starting at L2 block 0. A fresh proxy records its
/// genesis checkpoint and initial committee in one initialization, then lands proven batches.
/// @dev Uses the existing ABCI storage interface without any Shasta state or migration logic.
/// Slots 251–257, 259–267, 269 and 275–277 are reserved to keep the node-facing slots unchanged.
/// @custom:security-contact security@taiko.xyz
contract EtnaInbox is IEtnaInbox, EssentialContract {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev The V3 statement in wire order. All fields are static, so abi.encode of this
    /// memory-only struct is the same sixteen-word encoding as the flat field list. Building
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
        bytes32 startCommitteeRecordHash;
        uint64 lastHeight;
        bytes32 lastBlockHash;
        bytes32 lastStateRoot;
        uint64 anchorNumber;
        bytes32 anchorHash;
        bytes32 recordsHash;
        bytes32 blobHashesHash;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev The initialized status value expected by the ABCI node.
    uint8 private constant _ETNA_ACTIVE = 3;

    /// @dev The smallest epoch length in L2 blocks.
    uint64 private constant _MIN_EPOCH_LEN_L2 = 3;

    /// @dev The domain tag of the landing statement.
    bytes32 private constant _LAND_STATEMENT_TAG = bytes32("TAIKO_ETNA_LAND_V3");

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

    /// @dev Slot 269: reserved (PARAM-04 config registry).
    uint256 private __reservedConfigRegistry;

    /// @dev Slots 270–271: the latest landed L2 block.
    LandedCheckpoint private _lastCheckpoint;

    /// @dev Slots 272–274: the genesis record at the existing activation-record slots.
    Activation private _activation;

    /// @dev Slots 275–277: reserved (#22262 publication register).
    uint256[3] private __reservedPublications;

    /// @dev Slot 278: the committee record hash of each epoch.
    mapping(uint64 epoch => bytes32 recordHash) private _committee;

    /// @dev Slot 279: the L1 block of the epoch-0 committee snapshot.
    uint64 private _genesisCutoff;

    uint256[21] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the implementation's immutable parameters.
    /// @param _config The configuration; addresses, `l2ChainId` and `maxBatchBlocks` must be
    /// non-zero.
    constructor(Config memory _config) {
        require(_config.proofVerifier != address(0), ZERO_ADDRESS());
        require(_config.signalService != address(0), ZERO_ADDRESS());
        require(_config.stakingRegistry != address(0), ZERO_ADDRESS());
        require(_config.l2ChainId != 0, ZERO_VALUE());
        require(_config.maxBatchBlocks != 0, ZERO_VALUE());

        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _signalService = ISignalService(_config.signalService);
        _stakingRegistry = IEtnaStakingRegistry(_config.stakingRegistry);
        _l2ChainId = _config.l2ChainId;
        _maxBatchBlocks = _config.maxBatchBlocks;
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
        _committee[0] = _params.committeeRecordHash;
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

        // The first block is parent.height + 1; epoch e starts at 1 + e * epochLenL2.
        // Read the trusted starting record before accepting any new committee outputs.
        bytes32 startCommitteeRecordHash = _committee[parent.height / _activation.epochLenL2];
        require(startCommitteeRecordHash != 0, StartingCommitteeNotRecorded());
        _recordCommittees(parent.height, lastHeight, _input.records);

        bytes32 statementHash = _hashLandStatement(
            _recoveryGeneration,
            parent.height,
            parent.blockHash,
            startCommitteeRecordHash,
            _input,
            _readAnchorHash(_input.anchorNumber),
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
            _input.anchorNumber,
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
        bytes32 _startCommitteeRecordHash,
        LandInput calldata _input,
        bytes32 _anchorHash,
        bytes32[] calldata _blobHashes
    )
        external
        view
        returns (bytes32)
    {
        return _hashLandStatement(
            _generation,
            _parentHeight,
            _parentHash,
            _startCommitteeRecordHash,
            _input,
            _anchorHash,
            _blobHashes
        );
    }

    /// @inheritdoc IEtnaInbox
    function lastCheckpoint() external view returns (LandedCheckpoint memory) {
        return _lastCheckpoint;
    }

    /// @inheritdoc IEtnaInbox
    function committee(uint64 _epoch) external view returns (bytes32) {
        return _committee[_epoch];
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
    function migrationState() external view returns (uint8) {
        return _status;
    }

    /// @inheritdoc IEtnaInbox
    function recoveryGeneration() external view returns (uint64) {
        return _recoveryGeneration;
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
    /// @param _startCommitteeRecordHash The on-chain record hash of the first block's committee.
    /// @param _input The batch.
    /// @param _anchorHash The L1 block hash of `_input.anchorNumber`.
    /// @param _blobHashes The versioned hashes of the batch's blobs.
    /// @return The landing statement hash.
    function _hashLandStatement(
        uint64 _generation,
        uint64 _parentHeight,
        bytes32 _parentHash,
        bytes32 _startCommitteeRecordHash,
        LandInput calldata _input,
        bytes32 _anchorHash,
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
        statement.startCommitteeRecordHash = _startCommitteeRecordHash;
        statement.lastHeight = _input.lastHeight;
        statement.lastBlockHash = _input.lastBlockHash;
        statement.lastStateRoot = _input.lastStateRoot;
        statement.anchorNumber = _input.anchorNumber;
        statement.anchorHash = _anchorHash;
        statement.recordsHash = keccak256(abi.encode(_input.records));
        statement.blobHashesHash = keccak256(abi.encodePacked(_blobHashes));
        return keccak256(abi.encode(statement));
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Checks that `_records` holds exactly one non-zero record, keyed `e + 1` and in
    /// ascending order, for every epoch `e` whose first block lies in
    /// `(_parentHeight, _lastHeight]`, and stores each as `committee[e + 1]`.
    /// @param _parentHeight The height of the block the batch builds on, starting at 0.
    /// @param _lastHeight The height of the batch's last block.
    /// @param _records The batch's committee records.
    function _recordCommittees(
        uint64 _parentHeight,
        uint64 _lastHeight,
        CommitteeRecord[] calldata _records
    )
        private
    {
        uint256 epochLen = _activation.epochLenL2;

        // Epoch e starts at height 1 + e * epochLen. The first one above the parent is
        // ceil(parentHeight / epochLen); uint256 arithmetic keeps the sum in range.
        uint256 epoch = (uint256(_parentHeight) + epochLen - 1) / epochLen;
        uint256 firstHeight = 1 + epoch * epochLen;
        uint256 count = _records.length;
        uint256 i;
        for (; firstHeight <= _lastHeight; ++i) {
            require(i < count, CommitteeRecordsMismatch());
            // `epoch` stays below `type(uint48).max`, as `firstHeight` does.
            uint64 recordEpoch = uint64(epoch + 1);
            bytes32 recordHash = _records[i].recordHash;
            require(_records[i].epoch == recordEpoch && recordHash != 0, CommitteeRecordsMismatch());
            // Batches are contiguous, so each epoch's first block is landed once.
            require(_committee[recordEpoch] == 0, CommitteeAlreadyRecorded());

            _committee[recordEpoch] = recordHash;
            emit CommitteeRecorded(recordEpoch, recordHash);

            ++epoch;
            firstHeight += epochLen;
        }
        require(i == count, CommitteeRecordsMismatch());
    }

    /// @dev Returns the hash of L1 block `_anchorNumber`: from `blockhash` for the last 256
    /// blocks, from the EIP-2935 history contract for the last 8191; reverts otherwise or if the
    /// hash is zero.
    /// @param _anchorNumber The L1 block number.
    /// @return anchorHash_ The L1 block hash.
    function _readAnchorHash(uint64 _anchorNumber) private view returns (bytes32 anchorHash_) {
        require(_anchorNumber < block.number, AnchorUnavailable());
        uint256 age = block.number - _anchorNumber;
        if (age <= _BLOCKHASH_WINDOW) {
            anchorHash_ = blockhash(_anchorNumber);
        } else {
            require(age <= _HISTORY_SERVE_WINDOW, AnchorUnavailable());
            (bool success, bytes memory data) =
                _HISTORY_STORAGE_ADDRESS.staticcall(abi.encode(uint256(_anchorNumber)));
            require(success && data.length == 32, AnchorUnavailable());
            anchorHash_ = abi.decode(data, (bytes32));
        }
        require(anchorHash_ != 0, AnchorUnavailable());
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
    error CommitteeAlreadyRecorded();
    error CommitteeRecordsMismatch();
    error EtnaNotActive();
    error InvalidGenesis();
    error HeightOverflow();
    error InvalidEpochLength();
    error InvalidGenesisCutoff();
    error NoProgress();
    error StartingCommitteeNotRecorded();
    error ZeroCommitteeRecord();
}
