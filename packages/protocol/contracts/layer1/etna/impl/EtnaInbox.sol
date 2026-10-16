// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { IEtnaRewardPool } from "../iface/IEtnaRewardPool.sol";
import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { LibEtnaForcedInclusion } from "../libs/LibEtnaForcedInclusion.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
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
/// The calldata forced inclusion store preserves the existing fee rule; its queue lives
/// at slots 280–281 and its genesis delay and maximum anchor age at slot 282. Landing advances the
/// queue head, reports the batch's validator participation to the reward pool, and pays the
/// consumed entries' fees and a per-block landing reward to the recipient its statement binds.
/// The reward comes from the prover reward ledger at slot 283, which the node does not read; the
/// pool's proving shares and landings' `msg.value` fund it.
/// @custom:security-contact security@taiko.xyz
contract EtnaInbox is IEtnaInbox, EssentialContract {
    using LibAddress for address;
    using LibEtnaForcedInclusion for LibEtnaForcedInclusion.Storage;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev The V7 statement in wire order. All fields are static, so abi.encode of this
    /// memory-only struct is the same nineteen-word encoding as the flat field list. Building
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
        uint48 forcedInclusionHeadBefore;
        uint48 forcedInclusionHeadAfter;
        address feeRecipient;
        bytes32 participationHash;
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

    /// @dev The proposer score of a block whose last commit carries the whole committee's stake.
    uint256 private constant _MAX_BLOCK_SCORE = 10_000;

    /// @notice The maximum byte length of a submitted forced transaction.
    uint256 public constant MAX_FORCED_TX_BYTES = 8192;

    /// @dev One Ethereum epoch: the normal finalized-anchor update interval.
    uint64 private constant _L1_EPOCH_DURATION = 32 * 12 seconds;

    /// @dev Three Ethereum epochs budget the normal finality lag before an anchor is usable.
    uint64 private constant _MIN_MAX_ANCHOR_AGE = 3 * _L1_EPOCH_DURATION;

    /// @dev The domain tag of the landing statement.
    bytes32 private constant _LAND_STATEMENT_TAG = bytes32("TAIKO_ETNA_LAND_V7");

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

    /// @dev The reward pool that records each landing's participation and funds the ledger.
    address internal immutable _rewardPool;

    /// @dev The landing reward per landed L2 block, in wei.
    uint128 internal immutable _landingRewardPerBlock;

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
    LibEtnaForcedInclusion.Storage private _forcedInclusionStorage;

    /// @dev Slot 282: the forced inclusion delay (bits 0–63) and the maximum anchor age
    /// (bits 64–127), in seconds.
    ForcedInclusionConfig private _forcedInclusionConfig;

    /// @dev Slot 283: the prover reward ledger in wei, the part of the balance reserved for
    /// landing rewards; not read by the node.
    uint256 private _proverRewardLedger;

    uint256[17] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the implementation's immutable parameters.
    /// @param _config The configuration; addresses, `l2ChainId`, `maxBatchBlocks` and both
    /// forced inclusion fee parameters must be non-zero; the landing reward may be zero.
    constructor(Config memory _config) {
        require(_config.proofVerifier != address(0), ZERO_ADDRESS());
        require(_config.signalService != address(0), ZERO_ADDRESS());
        require(_config.stakingRegistry != address(0), ZERO_ADDRESS());
        require(_config.rewardPool != address(0), ZERO_ADDRESS());
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
        _rewardPool = _config.rewardPool;
        _landingRewardPerBlock = _config.landingRewardPerBlock;
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
        require(_params.forcedInclusionDelay != 0, InvalidForcedInclusionDelay());
        require(_params.maxAnchorAge >= _MIN_MAX_ANCHOR_AGE, InvalidMaxAnchorAge());

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

    /// @notice Credits Ether from the reward pool, a frozen epoch's proving share, to the prover
    /// reward ledger.
    /// @dev Reverts `UnauthorizedRewardSender` for any other sender. Not `nonReentrant`: the pool
    /// sends while `land` holds the lock.
    // solhint-disable-next-line no-complex-fallback
    receive() external payable {
        require(msg.sender == _rewardPool, UnauthorizedRewardSender());
        _proverRewardLedger += msg.value;
    }

    /// @inheritdoc IEtnaInbox
    function land(
        LandInput calldata _input,
        EpochParticipation[] calldata _participation,
        CommitteeMember[][] calldata _settlements,
        bytes calldata _proof
    )
        external
        payable
        nonReentrant
    {
        require(_status == _ETNA_ACTIVE, EtnaNotActive());

        LandedCheckpoint memory parent = _lastCheckpoint;
        uint64 lastHeight = _input.lastHeight;
        require(lastHeight > parent.height, NoProgress());
        require(lastHeight - parent.height <= _maxBatchBlocks, BatchTooLarge());
        require(lastHeight <= type(uint48).max, HeightOverflow());
        require(_input.feeRecipient != address(0), ZeroFeeRecipient());

        uint48 headBefore = _forcedInclusionStorage.head;
        uint48 headAfter = _input.forcedInclusionHead;
        // Each forced inclusion is its own block; short-circuiting keeps the subtraction safe.
        require(
            headBefore <= headAfter && headAfter <= _forcedInclusionStorage.tail
                && headAfter - headBefore <= lastHeight - parent.height,
            InvalidForcedInclusionHead()
        );
        _checkParticipation(parent.height, lastHeight, _activation.epochLenL2, _participation);

        bytes32 statementHash = _landStatementHash(parent, headBefore, _input, _participation);

        uint256 feesWei;
        if (headAfter != headBefore) {
            feesWei = _forcedInclusionStorage.consume(headAfter) * 1 gwei;
        }

        _saveCheckpoint(parent.height, _input, statementHash);

        _proofVerifier.verifyProof(0, statementHash, _proof);

        // Frozen epochs' proving shares arrive through `receive` before the reward is computed.
        IEtnaRewardPool(_rewardPool)
            .recordLanding(lastHeight, _activation.epochLenL2, _participation, _settlements);
        _payLander(_input.feeRecipient, lastHeight - parent.height, feesWei, headBefore, headAfter);
    }

    /// @inheritdoc IEtnaInbox
    function hashLandStatement(
        uint64 _generation,
        uint64 _parentHeight,
        bytes32 _parentHash,
        uint48 _forcedInclusionHeadBefore,
        LandInput calldata _input,
        EpochParticipation[] calldata _participation,
        bytes32 _l1ReferenceBlockHash,
        bytes32[] calldata _blobHashes
    )
        external
        view
        returns (bytes32 statementHash_)
    {
        return _hashLandStatement(
            _generation,
            _parentHeight,
            _parentHash,
            _forcedInclusionHeadBefore,
            _input,
            _participation,
            _l1ReferenceBlockHash,
            _blobHashes
        );
    }

    /// @inheritdoc IEtnaInbox
    function saveForcedInclusion(bytes calldata _tx) external payable nonReentrant {
        require(_status == _ETNA_ACTIVE, EtnaNotActive());
        require(_tx.length <= MAX_FORCED_TX_BYTES, ForcedTransactionTooLarge());
        uint64 fee = _forcedInclusionStorage.currentFee(
            _forcedInclusionFeeInGwei, _forcedInclusionFeeDoubleThreshold
        );
        uint256 requiredFee = uint256(fee) * 1 gwei;
        require(msg.value >= requiredFee, InsufficientFee());
        uint48 index = _forcedInclusionStorage.tail;
        _forcedInclusionStorage.queue[index] = IEtnaInbox.ForcedInclusion({
            txHash: keccak256(_tx),
            timestamp: uint48(block.timestamp),
            l1Block: uint64(block.number),
            feeInGwei: fee
        });
        _forcedInclusionStorage.tail = index + 1;
        emit ForcedInclusionSaved(index, _tx);
        msg.sender.sendEtherAndVerify(msg.value - requiredFee);
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

    /// @inheritdoc IEtnaInbox
    function proverRewardLedger() external view returns (uint256) {
        return _proverRewardLedger;
    }

    /// @inheritdoc IEtnaInbox
    function rewardPool() external view returns (address) {
        return _rewardPool;
    }

    /// @inheritdoc IEtnaInbox
    function landingRewardPerBlock() external view returns (uint128) {
        return _landingRewardPerBlock;
    }

    /// @inheritdoc IEtnaInbox
    function getCurrentForcedInclusionFee() external view returns (uint64 feeInGwei_) {
        return _forcedInclusionStorage.currentFee(
            _forcedInclusionFeeInGwei, _forcedInclusionFeeDoubleThreshold
        );
    }

    /// @inheritdoc IEtnaInbox
    function getForcedInclusions(
        uint48 _start,
        uint48 _maxCount
    )
        external
        view
        returns (ForcedInclusion[] memory inclusions_)
    {
        return _forcedInclusionStorage.getForcedInclusions(_start, _maxCount);
    }

    /// @inheritdoc IEtnaInbox
    function getForcedInclusionState() external view returns (uint48 head_, uint48 tail_) {
        return (_forcedInclusionStorage.head, _forcedInclusionStorage.tail);
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
    /// @param _forcedInclusionHeadBefore The forced inclusion queue head before the batch.
    /// @param _input The batch.
    /// @param _participation The validator participation per epoch of the batch's commit range.
    /// @param _l1ReferenceBlockHash The L1 block hash of `_input.l1ReferenceBlockNumber`.
    /// @param _blobHashes The versioned hashes of the batch's blobs.
    /// @return The landing statement hash.
    function _hashLandStatement(
        uint64 _generation,
        uint64 _parentHeight,
        bytes32 _parentHash,
        uint48 _forcedInclusionHeadBefore,
        LandInput calldata _input,
        EpochParticipation[] calldata _participation,
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
        statement.forcedInclusionHeadBefore = _forcedInclusionHeadBefore;
        statement.forcedInclusionHeadAfter = _input.forcedInclusionHead;
        statement.feeRecipient = _input.feeRecipient;
        statement.participationHash = keccak256(abi.encode(_participation));
        return keccak256(abi.encode(statement));
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Hashes the statement `land` verifies, from the stored generation, the parent
    /// checkpoint, the resolved reference block hash and the transaction's blob hashes. A
    /// separate frame keeps `land` within the non-IR compiler's stack limit.
    /// @param _parent The parent checkpoint.
    /// @param _headBefore The forced inclusion queue head before the batch.
    /// @param _input The batch.
    /// @param _participation The validator participation per epoch of the batch's commit range.
    /// @return The landing statement hash.
    function _landStatementHash(
        LandedCheckpoint memory _parent,
        uint48 _headBefore,
        LandInput calldata _input,
        EpochParticipation[] calldata _participation
    )
        private
        view
        returns (bytes32)
    {
        return _hashLandStatement(
            _recoveryGeneration,
            _parent.height,
            _parent.blockHash,
            _headBefore,
            _input,
            _participation,
            _readL1ReferenceBlockHash(_input.l1ReferenceBlockNumber),
            _readBlobHashes()
        );
    }

    /// @dev Saves the batch's last block as the checkpoint in the Inbox and the SignalService and
    /// emits BatchLanded.
    /// @param _parentHeight The height of the block the batch builds on.
    /// @param _input The batch.
    /// @param _statementHash The landing statement hash.
    function _saveCheckpoint(
        uint64 _parentHeight,
        LandInput calldata _input,
        bytes32 _statementHash
    )
        private
    {
        uint64 lastHeight = _input.lastHeight;
        _lastCheckpoint = LandedCheckpoint({ height: lastHeight, blockHash: _input.lastBlockHash });
        _signalService.saveCheckpoint(
            ICheckpointStore.Checkpoint({
                blockNumber: uint48(lastHeight),
                blockHash: _input.lastBlockHash,
                stateRoot: _input.lastStateRoot
            })
        );
        emit BatchLanded(
            _parentHeight + 1,
            lastHeight,
            _input.lastBlockHash,
            _input.lastStateRoot,
            _input.l1ReferenceBlockNumber,
            _statementHash,
            msg.sender
        );
    }

    /// @dev Adds `msg.value` to the prover reward ledger, debits the landing reward for
    /// `_blocks` blocks, capped at the ledger, and sends it with the consumed forced inclusions'
    /// fees to `_recipient` in one transfer when the sum is non-zero; a failed transfer reverts.
    /// @param _recipient The batch's fee recipient.
    /// @param _blocks The number of landed blocks.
    /// @param _feesWei The consumed forced inclusions' fees in wei.
    /// @param _headBefore The forced inclusion queue head before the batch.
    /// @param _headAfter The forced inclusion queue head after the batch.
    function _payLander(
        address _recipient,
        uint64 _blocks,
        uint256 _feesWei,
        uint48 _headBefore,
        uint48 _headAfter
    )
        private
    {
        uint256 ledger = _proverRewardLedger + msg.value;
        uint256 reward = Math.min(uint256(_landingRewardPerBlock) * _blocks, ledger);
        ledger -= reward;
        _proverRewardLedger = ledger;

        _recipient.sendEtherAndVerify(_feesWei + reward);
        if (_headAfter != _headBefore) {
            emit ForcedInclusionsConsumed(_headBefore, _headAfter, _feesWei, _recipient);
        }
        emit LandingRewardPaid(_recipient, reward, ledger);
    }

    /// @dev Requires `_participation` to have the shape of the batch `(_parentHeight,
    /// _lastHeight]`: block h + 1 carries the commit of height h and height 0 has none, so the
    /// commit range is `[max(_parentHeight, 1), _lastHeight - 1]`. An empty range takes no
    /// part; otherwise each epoch of the range takes one part, in ascending order, and no signed
    /// count may exceed the range's heights in its epoch. Each part has one proposer score per
    /// signed count, and its scores sum to at most `_MAX_BLOCK_SCORE` per height: each height's
    /// carrying block scores at most that much, for one proposer. The sum bound keeps every
    /// epoch's scores within what the pool's proposer bonus can pay. All arithmetic is in
    /// uint256.
    /// @param _parentHeight The height of the block the batch builds on.
    /// @param _lastHeight The height of the batch's last block, above `_parentHeight`.
    /// @param _epochLenL2 The epoch length in L2 blocks.
    /// @param _participation The participation to check.
    function _checkParticipation(
        uint64 _parentHeight,
        uint64 _lastHeight,
        uint64 _epochLenL2,
        EpochParticipation[] calldata _participation
    )
        private
        pure
    {
        uint256 first = Math.max(_parentHeight, 1);
        uint256 last = uint256(_lastHeight) - 1;
        if (first > last) {
            require(_participation.length == 0, InvalidParticipation());
            return;
        }

        uint256 epoch = (first - 1) / _epochLenL2;
        require(
            _participation.length == (last - 1) / _epochLenL2 - epoch + 1, InvalidParticipation()
        );
        for (uint256 k; k < _participation.length; ++k) {
            require(_participation[k].epoch == epoch, InvalidParticipation());
            // Epoch e holds heights [e * epochLenL2 + 1, (e + 1) * epochLenL2].
            uint256 heights = Math.min(last, (epoch + 1) * _epochLenL2)
                - Math.max(first, epoch * _epochLenL2 + 1) + 1;
            uint32[] calldata counts = _participation[k].signedCounts;
            for (uint256 i; i < counts.length; ++i) {
                require(counts[i] <= heights, InvalidParticipation());
            }
            uint32[] calldata scores = _participation[k].proposerScores;
            require(scores.length == counts.length, InvalidParticipation());
            uint256 scoreSum;
            for (uint256 i; i < scores.length; ++i) {
                scoreSum += scores[i];
            }
            require(scoreSum <= heights * _MAX_BLOCK_SCORE, InvalidParticipation());
            ++epoch;
        }
    }

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
    error ForcedTransactionTooLarge();
    error InsufficientFee();
    error InvalidGenesis();
    error HeightOverflow();
    error InvalidEpochLength();
    error InvalidForcedInclusionDelay();
    error InvalidForcedInclusionHead();
    error InvalidGenesisCutoff();
    error InvalidMaxAnchorAge();
    error InvalidParticipation();
    error NoProgress();
    error UnauthorizedRewardSender();
    error ZeroCommitteeRecord();
    error ZeroCommitteeConfigHash();
    error ZeroFeeRecipient();
}
