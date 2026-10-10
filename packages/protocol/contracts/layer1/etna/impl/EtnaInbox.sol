// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IBondManager } from "src/layer1/core/iface/IBondManager.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBonds } from "src/layer1/core/libs/LibBonds.sol";
import { LibForcedInclusion } from "src/layer1/core/libs/LibForcedInclusion.sol";
import { LibInboxMigration } from "src/layer1/core/libs/LibInboxMigration.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

import "./EtnaInbox_Layout.sol"; // DO NOT DELETE

/// @title EtnaInbox
/// @notice The Etna implementation of the Inbox proxy. It replaces the Shasta implementation once
/// the Shasta Inbox is frozen and drained, activates Etna from the last finalized Shasta block,
/// lands proven batches of Etna blocks, and keeps the legacy Shasta bond exit.
/// @dev Upgrades the existing, initialized Shasta Inbox proxy in place, so it has no initializer.
/// It does not carry the Shasta propose, prove, deposit, forced inclusion or codec entry points.
///
/// Storage keeps the Shasta variables at their slots (251–258) and places the Etna variables on
/// the slots the Etna node reads (268, 270–274, 278, 279). Slots 259–267, 269 and 275–277 are
/// reserved for features of the Etna specification (taikoxyz/taiko-mono#22262) not built here.
/// @custom:security-contact security@taiko.xyz
contract EtnaInbox is IEtnaInbox, EssentialContract {
    using LibBonds for LibBonds.Storage;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev The smallest epoch length in L2 blocks.
    uint64 private constant _MIN_EPOCH_LEN_L2 = 3;

    /// @dev The domain tag of the landing statement.
    bytes32 private constant _LAND_STATEMENT_TAG = bytes32("TAIKO_ETNA_LAND_V1");

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

    /// @dev The ERC20 token of the legacy Shasta bonds.
    IERC20 internal immutable _bondToken;

    /// @dev The chain id of the Etna L2.
    uint64 internal immutable _l2ChainId;

    /// @dev The maximum number of L2 blocks one `land` call may cover.
    uint64 internal immutable _maxBatchBlocks;

    /// @dev The legacy Shasta minimum bond in gwei.
    uint64 internal immutable _minBond;

    /// @dev The legacy Shasta bond withdrawal delay in seconds.
    uint48 internal immutable _withdrawalDelay;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Slot 251: the Shasta `activationTimestamp`; no longer used.
    uint48 private __deprecatedActivationTimestamp;

    /// @dev Slots 252–253: the Shasta core state, frozen; `activateEtna` reads its finalization.
    IInbox.CoreState private _coreState;

    /// @dev Slot 254: the Shasta proposal hash ring buffer; no longer used.
    mapping(uint256 proposalId => bytes32 proposalHash) private __deprecatedProposalHashes;

    /// @dev Slots 255–256: the Shasta forced inclusion queue; no longer used.
    LibForcedInclusion.Storage private __deprecatedForcedInclusions;

    /// @dev Slot 257: the Shasta bond balances, kept for the legacy bond exit.
    LibBonds.Storage private _bondStorage;

    /// @dev Slot 258: the migration state word, written by the Shasta `freeze()` and here.
    LibInboxMigration.State private _migration;

    /// @dev Slots 259–267: reserved (#22262 MIG-02).
    uint256[9] private __reservedSpec;

    /// @dev Slot 268: the recovery generation (bits 0–63; the rest is reserved for GOV-04).
    uint64 private _recoveryGeneration;

    /// @dev Slot 269: reserved (PARAM-04 config registry).
    uint256 private __reservedConfigRegistry;

    /// @dev Slots 270–271: the latest landed L2 block.
    LandedCheckpoint private _lastCheckpoint;

    /// @dev Slots 272–274: the activation record.
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
        require(_config.bondToken != address(0), ZERO_ADDRESS());
        require(_config.l2ChainId != 0, ZERO_VALUE());
        require(_config.maxBatchBlocks != 0, ZERO_VALUE());

        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _signalService = ISignalService(_config.signalService);
        _stakingRegistry = IEtnaStakingRegistry(_config.stakingRegistry);
        _bondToken = IERC20(_config.bondToken);
        _l2ChainId = _config.l2ChainId;
        _maxBatchBlocks = _config.maxBatchBlocks;
        _minBond = _config.minBond;
        _withdrawalDelay = _config.withdrawalDelay;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IEtnaInbox
    function activateEtna(ActivationParams calldata _params) external onlyOwner {
        LibInboxMigration.State memory migration = _migration;
        require(migration.migrationState == LibInboxMigration.FROZEN, NotFrozen());

        IInbox.CoreState memory coreState = _coreState;
        require(
            uint256(coreState.lastFinalizedProposalId) + 1 == coreState.nextProposalId, NotDrained()
        );

        ICheckpointStore.Checkpoint memory genesis =
            _genesisCheckpoint(_params.genesisHeight, coreState.lastFinalizedBlockHash);

        require(
            _params.epochLenL2 >= _MIN_EPOCH_LEN_L2 && _params.epochLenL1 != 0, InvalidEpochLength()
        );
        require(_isValidGenesisCutoff(_params.genesisCutoff), InvalidGenesisCutoff());
        require(_params.committeeRecordHash != 0, ZeroCommitteeRecord());

        uint64 l1Block = uint64(block.number);
        migration.migrationState = LibInboxMigration.ETNA_ACTIVE;
        migration.drainedAtL1Block = l1Block;
        _migration = migration;

        _activation = Activation({
            genesisHeight: _params.genesisHeight,
            l1Block: l1Block,
            epochLenL2: _params.epochLenL2,
            epochLenL1: _params.epochLenL1,
            genesisBlockHash: genesis.blockHash,
            genesisStateRoot: genesis.stateRoot
        });
        _genesisCutoff = _params.genesisCutoff;
        _committee[0] = _params.committeeRecordHash;
        _lastCheckpoint =
            LandedCheckpoint({ height: _params.genesisHeight, blockHash: genesis.blockHash });

        emit EtnaActivated(
            _params.genesisHeight,
            genesis.blockHash,
            genesis.stateRoot,
            l1Block,
            _params.epochLenL2,
            _params.epochLenL1,
            _params.genesisCutoff,
            _params.committeeRecordHash
        );
    }

    /// @inheritdoc IEtnaInbox
    function land(LandInput calldata _input, bytes calldata _proof) external nonReentrant {
        require(_migration.migrationState == LibInboxMigration.ETNA_ACTIVE, EtnaNotActive());

        LandedCheckpoint memory parent = _lastCheckpoint;
        uint64 lastHeight = _input.lastHeight;
        require(lastHeight > parent.height, NoProgress());
        require(lastHeight - parent.height <= _maxBatchBlocks, BatchTooLarge());
        require(lastHeight <= type(uint48).max, HeightOverflow());

        _recordCommittees(parent.height, lastHeight, _input.records);

        bytes32 statementHash = _hashLandStatement(
            _recoveryGeneration,
            parent.height,
            parent.blockHash,
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

    /// @notice Withdraws legacy Shasta bond of the caller to a recipient.
    /// @dev Same rules as the Shasta `Inbox.withdraw`: without a withdrawal request whose delay
    /// has passed, the remaining balance must stay at or above the minimum bond; a withdrawal of
    /// the whole balance clears the request. Emits `IBondManager.BondWithdrawn`.
    /// @param _to The recipient of the withdrawn tokens.
    /// @param _amount The amount to withdraw in gwei, capped at the balance.
    function withdraw(address _to, uint64 _amount) external nonReentrant {
        _bondStorage.withdraw(_bondToken, msg.sender, _to, _amount, _minBond, _withdrawalDelay);
    }

    /// @notice Requests the withdrawal of the caller's legacy Shasta bond.
    /// @dev The whole balance becomes withdrawable after the withdrawal delay. Emits
    /// `IBondManager.WithdrawalRequested`.
    function requestWithdrawal() external nonReentrant {
        _bondStorage.requestWithdrawal(msg.sender, _withdrawalDelay);
    }

    /// @notice Cancels the caller's pending legacy bond withdrawal request.
    /// @dev Emits `IBondManager.WithdrawalCancelled`.
    function cancelWithdrawal() external nonReentrant {
        _bondStorage.cancelWithdrawal(msg.sender);
    }

    /// @notice Returns the legacy Shasta bond of an address.
    /// @param _address The bond holder.
    /// @return bond_ The bond balance and withdrawal request timestamp.
    function getBond(address _address) external view returns (IBondManager.Bond memory bond_) {
        return _bondStorage.getBond(_address);
    }

    /// @inheritdoc IEtnaInbox
    function hashLandStatement(
        uint64 _generation,
        uint64 _parentHeight,
        bytes32 _parentHash,
        LandInput calldata _input,
        bytes32 _anchorHash,
        bytes32[] calldata _blobHashes
    )
        external
        view
        returns (bytes32)
    {
        return _hashLandStatement(
            _generation, _parentHeight, _parentHash, _input, _anchorHash, _blobHashes
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
        return _migration.migrationState;
    }

    /// @inheritdoc IEtnaInbox
    function recoveryGeneration() external view returns (uint64) {
        return _recoveryGeneration;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Computes the landing statement hash; the single encoding behind `land` and
    /// `hashLandStatement`. The guest and the lander reproduce it byte for byte.
    /// @param _generation The recovery generation.
    /// @param _parentHeight The height of the block the batch builds on.
    /// @param _parentHash The hash of the block the batch builds on.
    /// @param _input The batch.
    /// @param _anchorHash The L1 block hash of `_input.anchorNumber`.
    /// @param _blobHashes The versioned hashes of the batch's blobs.
    /// @return The landing statement hash.
    function _hashLandStatement(
        uint64 _generation,
        uint64 _parentHeight,
        bytes32 _parentHash,
        LandInput calldata _input,
        bytes32 _anchorHash,
        bytes32[] memory _blobHashes
    )
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                _LAND_STATEMENT_TAG,
                block.chainid,
                _l2ChainId,
                _generation,
                _parentHeight,
                _parentHash,
                _input.lastHeight,
                _input.lastBlockHash,
                _input.lastStateRoot,
                _input.anchorNumber,
                _anchorHash,
                keccak256(abi.encode(_input.records)),
                keccak256(abi.encodePacked(_blobHashes))
            )
        );
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Checks that `_records` holds exactly one non-zero record, keyed `e + 1` and in
    /// ascending order, for every epoch `e` whose first block lies in
    /// `(_parentHeight, _lastHeight]`, and stores each as `committee[e + 1]`.
    /// @param _parentHeight The height of the block the batch builds on, at least `B*`.
    /// @param _lastHeight The height of the batch's last block.
    /// @param _records The batch's committee records.
    function _recordCommittees(
        uint64 _parentHeight,
        uint64 _lastHeight,
        CommitteeRecord[] calldata _records
    )
        private
    {
        uint256 genesisHeight = _activation.genesisHeight;
        uint256 epochLen = _activation.epochLenL2;

        // The first epoch whose first block `genesisHeight + 1 + epoch * epochLen` lies above
        // `_parentHeight`: `ceil((_parentHeight - genesisHeight) / epochLen)`.
        uint256 epoch = (_parentHeight - genesisHeight + epochLen - 1) / epochLen;
        uint256 firstHeight = genesisHeight + 1 + epoch * epochLen;
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

    /// @dev Returns the signal service checkpoint of the Etna genesis and checks that it is the
    /// last finalized Shasta block.
    /// @param _genesisHeight `B*`.
    /// @param _lastFinalizedBlockHash The Shasta last finalized block hash.
    /// @return checkpoint_ The checkpoint at `B*`.
    function _genesisCheckpoint(
        uint64 _genesisHeight,
        bytes32 _lastFinalizedBlockHash
    )
        private
        view
        returns (ICheckpointStore.Checkpoint memory checkpoint_)
    {
        // Signal service checkpoints are keyed by uint48 heights.
        require(_genesisHeight <= type(uint48).max, GenesisMismatch());
        try _signalService.getCheckpoint(uint48(_genesisHeight)) returns (
            ICheckpointStore.Checkpoint memory checkpoint
        ) {
            checkpoint_ = checkpoint;
        } catch {
            revert GenesisMismatch();
        }
        require(checkpoint_.blockHash == _lastFinalizedBlockHash, GenesisMismatch());
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
    /// checkpoint, so the epoch-0 snapshot exists and is final.
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
    error GenesisMismatch();
    error HeightOverflow();
    error InvalidEpochLength();
    error InvalidGenesisCutoff();
    error NoProgress();
    error NotDrained();
    error NotFrozen();
    error ZeroCommitteeRecord();
}
