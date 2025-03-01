// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/signal/ISignalService.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./ITaikoInbox.sol";
import "./IProposeBatch.sol";

/// @title TaikoInbox
/// @notice Acts as the inbox for the Taiko Alethia protocol, a simplified version of the
/// original Taiko-Based Contestable Rollup (BCR). The tier-based proof system and
/// contestation mechanisms have been removed.
///
/// Key assumptions of this protocol:
/// - Block proposals and proofs are asynchronous. Proofs are not available at proposal time,
///   unlike Taiko Gwyneth, which assumes synchronous composability.
/// - Proofs are presumed error-free and thoroughly validated, with proof type management
///   delegated to IVerifier contracts.
///
/// @dev Registered in the address resolver as "taiko".
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoInbox is EssentialContract, ITaikoInbox, IProposeBatch, ITaiko {
    using LibMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable inboxWrapper;
    address public immutable verifier;
    address public immutable bondToken;
    ISignalService public immutable signalService;

    State public state; // storage layout much match Ontake fork
    uint256[50] private __gap;

    // External functions ------------------------------------------------------------------------

    constructor(
        address _inboxWrapper,
        address _verifier,
        address _bondToken,
        address _signalService
    )
        nonZeroAddr(_verifier)
        nonZeroAddr(_signalService)
        EssentialContract(address(0))
    {
        inboxWrapper = _inboxWrapper;
        verifier = _verifier;
        bondToken = _bondToken;
        signalService = ISignalService(_signalService);
    }

    function init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Taiko_init(_owner, _genesisBlockHash);
    }

    /// @notice Proposes a batch of blocks.
    /// @param _params ABI-encoded BlockParams.
    /// @param _txList The transaction list in calldata. If the txList is empty, blob will be used
    /// for data availability.
    /// @return info_ The info of the proposed batch.
    /// @return meta_ The metadata of the proposed batch.
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        public
        override(ITaikoInbox, IProposeBatch)
        nonReentrant
        returns (BatchInfo memory info_, BatchMetadata memory meta_)
    {
        Stats2 memory stats2 = state.stats2;
        require(stats2.numBatches >= pacayaConfig().forkHeights.pacaya, ForkNotActivated());

        Config memory config = pacayaConfig();

        unchecked {
            require(
                stats2.numBatches <= stats2.lastVerifiedBatchId + config.maxUnverifiedBatches,
                TooManyBatches()
            );

            BatchParams memory params = abi.decode(_params, (BatchParams));

            {
                if (inboxWrapper == address(0)) {
                    require(params.proposer == address(0), CustomProposerNotAllowed());
                    params.proposer = msg.sender;

                    // blob hashes are only accepted if the caller is trusted.
                    require(params.blobParams.blobHashes.length == 0, InvalidBlobParams());

                    require(params.blobParams.createdIn == 0, InvalidBlobCreatedIn());
                    params.blobParams.createdIn = uint64(block.number);
                } else {
                    require(msg.sender == inboxWrapper, NotInboxWrapper());
                    require(params.proposer != address(0), CustomProposerMissing());
                }

                if (params.coinbase == address(0)) {
                    params.coinbase = params.proposer;
                }

                if (params.revertIfNotFirstProposal) {
                    require(state.stats2.lastProposedIn != block.number, NotFirstProposal());
                }
            }

            bool calldataUsed = _txList.length != 0;

            if (!calldataUsed) {
                if (params.blobParams.blobHashes.length == 0) {
                    require(params.blobParams.numBlobs != 0, BlobNotSpecified());
                } else {
                    require(params.blobParams.numBlobs == 0, InvalidBlobParams());
                    require(params.blobParams.firstBlobIndex == 0, InvalidBlobParams());
                }
            } else {
                params.blobParams.createdIn = 0;
            }

            // Keep track of last batch's information.
            Batch storage lastBatch =
                state.batches[(stats2.numBatches - 1) % config.batchRingBufferSize];

            (uint64 anchorBlockId, uint64 lastBlockTimestamp) = _validateBatchParams(
                params,
                config.maxAnchorHeightOffset,
                config.maxSignalsToReceive,
                config.maxBlocksPerBatch,
                lastBatch
            );

            // This section constructs the metadata for the proposed batch, which is crucial for
            // nodes/clients to process the batch. The metadata itself is not stored on-chain;
            // instead, only its hash is kept.
            // The metadata must be supplied as calldata prior to proving the batch, enabling the
            // computation and verification of its integrity through the comparison of the metahash.
            //
            // Note that `difficulty` has been removed from the metadata. The client and prover must
            // use
            // the following approach to calculate a block's difficulty:
            //  `keccak256(abi.encode("TAIKO_DIFFICULTY", block.number))`
            info_ = BatchInfo({
                txsHash: bytes32(0), // to be initialised later
                //
                // Data to build L2 blocks
                blocks: params.blocks,
                blobHashes: new bytes32[](0), // to be initialised later
                extraData: bytes32(uint256(config.baseFeeConfig.sharingPctg)),
                coinbase: params.coinbase,
                proposedIn: uint64(block.number),
                blobCreatedIn: params.blobParams.createdIn,
                blobByteOffset: params.blobParams.byteOffset,
                blobByteSize: params.blobParams.byteSize,
                gasLimit: config.blockMaxGasLimit,
                lastBlockId: 0, // to be initialised later
                lastBlockTimestamp: lastBlockTimestamp,
                //
                // Data for the L2 anchor transaction, shared by all blocks in the batch
                anchorBlockId: anchorBlockId,
                anchorBlockHash: blockhash(anchorBlockId),
                baseFeeConfig: config.baseFeeConfig
            });

            require(info_.anchorBlockHash != 0, ZeroAnchorBlockHash());

            info_.lastBlockId = stats2.numBatches == config.forkHeights.pacaya
                ? stats2.numBatches + uint64(params.blocks.length) - 1
                : lastBatch.lastBlockId + uint64(params.blocks.length);

            (info_.txsHash, info_.blobHashes) =
                _calculateTxsHash(keccak256(_txList), params.blobParams);

            meta_ = BatchMetadata({
                infoHash: keccak256(abi.encode(info_)),
                proposer: params.proposer,
                batchId: stats2.numBatches,
                proposedAt: uint64(block.timestamp)
            });

            Batch storage batch = state.batches[stats2.numBatches % config.batchRingBufferSize];

            // SSTORE #1
            batch.metaHash = keccak256(abi.encode(meta_));

            // SSTORE #2 {{
            batch.batchId = stats2.numBatches;
            batch.lastBlockTimestamp = lastBlockTimestamp;
            batch.anchorBlockId = anchorBlockId;
            batch.nextTransitionId = 1;
            batch.verifiedTransitionId = 0;
            batch.reserved4 = 0;
            // SSTORE }}

            uint96 livenessBond =
                config.livenessBondBase + config.livenessBondPerBlock * uint96(params.blocks.length);
            _debitBond(params.proposer, livenessBond);

            // SSTORE #3 {{
            batch.lastBlockId = info_.lastBlockId;
            batch.reserved3 = 0;
            batch.livenessBond = livenessBond;
            // SSTORE }}

            stats2.numBatches += 1;
            stats2.lastProposedIn = uint56(block.number);

            emit BatchProposed(info_, meta_, _txList);
        } // end-of-unchecked

        _verifyBatches(config, stats2, 1);
    }

    /// @notice Proves multiple batches with a single aggregated proof.
    /// @param _params ABI-encoded parameter containing:
    /// - metas: Array of metadata for each batch being proved.
    /// - transitions: Array of batch transitions to be proved.
    /// @param _proof The aggregated cryptographic proof proving the batches transitions.
    function proveBatches(bytes calldata _params, bytes calldata _proof) external nonReentrant {
        (BatchMetadata[] memory metas, Transition[] memory trans) =
            abi.decode(_params, (BatchMetadata[], Transition[]));

        uint256 metasLength = metas.length;
        require(metasLength != 0, NoBlocksToProve());
        require(metasLength == trans.length, ArraySizesMismatch());

        Stats2 memory stats2 = state.stats2;
        require(!stats2.paused, ContractPaused());

        Config memory config = pacayaConfig();
        IVerifier.Context[] memory ctxs = new IVerifier.Context[](metasLength);

        bool hasConflictingProof;
        for (uint256 i; i < metasLength; ++i) {
            BatchMetadata memory meta = metas[i];

            require(meta.batchId >= pacayaConfig().forkHeights.pacaya, ForkNotActivated());

            require(meta.batchId > stats2.lastVerifiedBatchId, BatchNotFound());
            require(meta.batchId < stats2.numBatches, BatchNotFound());

            Transition memory tran = trans[i];
            require(tran.parentHash != 0, InvalidTransitionParentHash());
            require(tran.blockHash != 0, InvalidTransitionBlockHash());
            require(tran.stateRoot != 0, InvalidTransitionStateRoot());

            ctxs[i].batchId = meta.batchId;
            ctxs[i].metaHash = keccak256(abi.encode(meta));
            ctxs[i].transition = tran;

            // Verify the batch's metadata.
            uint256 slot = meta.batchId % config.batchRingBufferSize;
            Batch storage batch = state.batches[slot];
            require(ctxs[i].metaHash == batch.metaHash, MetaHashMismatch());

            // Finds out if this transition is overwriting an existing one (with the same parent
            // hash) or is a new one.
            uint24 tid;
            uint24 nextTransitionId = batch.nextTransitionId;
            if (nextTransitionId > 1) {
                // This batch has at least one transition.
                if (state.transitions[slot][1].parentHash == tran.parentHash) {
                    // Overwrite the first transition.
                    tid = 1;
                } else if (nextTransitionId > 2) {
                    // Retrieve the transition ID using the parent hash from the mapping. If the ID
                    // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                    // existing transition.
                    tid = state.transitionIds[meta.batchId][tran.parentHash];
                }
            }

            if (tid == 0) {
                // This transition is new, we need to use the next available ID.
                unchecked {
                    tid = batch.nextTransitionId++;
                }
            } else {
                TransitionState memory _ts = state.transitions[slot][tid];

                bool isSameTransition = _ts.blockHash == tran.blockHash
                    && (_ts.stateRoot == 0 || _ts.stateRoot == tran.stateRoot);
                require(!isSameTransition, SameTransition());

                hasConflictingProof = true;
                emit ConflictingProof(meta.batchId, _ts, tran);
            }

            TransitionState storage ts = state.transitions[slot][tid];

            ts.blockHash = tran.blockHash;
            ts.stateRoot =
                meta.batchId % config.stateRootSyncInternal == 0 ? tran.stateRoot : bytes32(0);

            bool inProvingWindow;
            unchecked {
                inProvingWindow = block.timestamp
                    <= uint256(meta.proposedAt).max(stats2.lastUnpausedAt) + config.provingWindow;
            }

            ts.inProvingWindow = inProvingWindow;
            ts.prover = inProvingWindow ? meta.proposer : msg.sender;
            ts.createdAt = uint48(block.timestamp);

            if (tid == 1) {
                ts.parentHash = tran.parentHash;
            } else {
                state.transitionIds[meta.batchId][tran.parentHash] = tid;
            }
        }

        IVerifier(verifier).verifyProof(ctxs, _proof);

        // Emit the event
        {
            uint64[] memory batchIds = new uint64[](metasLength);
            for (uint256 i; i < metasLength; ++i) {
                batchIds[i] = metas[i].batchId;
            }

            emit BatchesProved(verifier, batchIds, trans);
        }

        if (hasConflictingProof) {
            _pause();
            emit Paused(verifier);
        } else {
            _verifyBatches(config, stats2, metasLength);
        }
    }

    /// @notice Verify batches by providing the length of the batches to verify.
    /// @dev This function is necessary to upgrade from this fork to the next one.
    /// @param _length Specifis how many batches to verify. The max number of batches to verify is
    /// `pacayaConfig().maxBatchesToVerify * _length`.
    function verifyBatches(uint64 _length)
        external
        nonZeroValue(_length)
        nonReentrant
        whenNotPaused
    {
        _verifyBatches(pacayaConfig(), state.stats2, _length);
    }

    /// @notice Manually write a transition for a batch.
    /// @dev This function is supposed to be used by the owner to force prove a transition for a
    /// block that has not been verified.
    function writeTransition(
        uint64 _batchId,
        bytes32 _parentHash,
        bytes32 _blockHash,
        bytes32 _stateRoot,
        address _prover,
        bool _inProvingWindow
    )
        external
        onlyOwner
    {
        require(_blockHash != 0, InvalidParams());
        require(_parentHash != 0, InvalidParams());
        require(_stateRoot != 0, InvalidParams());
        require(_batchId > state.stats2.lastVerifiedBatchId, BatchVerified());

        Config memory config = pacayaConfig();
        uint256 slot = _batchId % config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());

        uint24 tid = state.transitionIds[_batchId][_parentHash];
        if (tid == 0) {
            tid = batch.nextTransitionId++;
        }

        TransitionState storage ts = state.transitions[slot][tid];
        ts.stateRoot = _batchId % config.stateRootSyncInternal == 0 ? _stateRoot : bytes32(0);
        ts.blockHash = _blockHash;
        ts.prover = _prover;
        ts.inProvingWindow = _inProvingWindow;
        ts.createdAt = uint48(block.timestamp);

        if (tid == 1) {
            ts.parentHash = _parentHash;
        } else {
            state.transitionIds[_batchId][_parentHash] = tid;
        }

        emit TransitionWritten(
            _batchId,
            tid,
            TransitionState(
                _parentHash,
                _blockHash,
                _stateRoot,
                _prover,
                _inProvingWindow,
                uint48(block.timestamp)
            )
        );
    }

    /// @inheritdoc ITaikoInbox
    function depositBond(uint256 _amount) external payable whenNotPaused {
        state.bondBalance[msg.sender] += _handleDeposit(msg.sender, _amount);
    }

    /// @inheritdoc ITaikoInbox
    function withdrawBond(uint256 _amount) external whenNotPaused {
        uint256 balance = state.bondBalance[msg.sender];
        require(balance >= _amount, InsufficientBond());

        emit BondWithdrawn(msg.sender, _amount);

        state.bondBalance[msg.sender] -= _amount;

        if (bondToken != address(0)) {
            IERC20(bondToken).safeTransfer(msg.sender, _amount);
        } else {
            LibAddress.sendEtherAndVerify(msg.sender, _amount);
        }
    }

    /// @inheritdoc ITaikoInbox
    function getStats1() external view returns (Stats1 memory) {
        return state.stats1;
    }

    /// @inheritdoc ITaikoInbox
    function getStats2() external view returns (Stats2 memory) {
        return state.stats2;
    }

    /// @inheritdoc ITaikoInbox
    function getTransitionById(
        uint64 _batchId,
        uint24 _tid
    )
        external
        view
        returns (TransitionState memory)
    {
        Config memory config = pacayaConfig();
        uint256 slot = _batchId % config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());
        require(_tid != 0, TransitionNotFound());
        require(_tid < batch.nextTransitionId, TransitionNotFound());
        return state.transitions[slot][_tid];
    }

    /// @inheritdoc ITaikoInbox
    function getTransitionByParentHash(
        uint64 _batchId,
        bytes32 _parentHash
    )
        external
        view
        returns (TransitionState memory)
    {
        Config memory config = pacayaConfig();
        uint256 slot = _batchId % config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());

        uint24 tid;
        if (batch.nextTransitionId > 1) {
            // This batch has at least one transition.
            if (state.transitions[slot][1].parentHash == _parentHash) {
                // Overwrite the first transition.
                tid = 1;
            } else if (batch.nextTransitionId > 2) {
                // Retrieve the transition ID using the parent hash from the mapping. If the ID
                // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                // existing transition.
                tid = state.transitionIds[_batchId][_parentHash];
            }
        }

        require(tid != 0 && tid < batch.nextTransitionId, TransitionNotFound());
        return state.transitions[slot][tid];
    }

    /// @inheritdoc ITaikoInbox
    function getLastVerifiedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory ts_)
    {
        batchId_ = state.stats2.lastVerifiedBatchId;
        require(batchId_ >= pacayaConfig().forkHeights.pacaya, BatchNotFound());
        blockId_ = getBatch(batchId_).lastBlockId;
        ts_ = getBatchVerifyingTransition(batchId_);
    }

    /// @inheritdoc ITaikoInbox
    function getLastSyncedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory ts_)
    {
        batchId_ = state.stats1.lastSyncedBatchId;
        blockId_ = getBatch(batchId_).lastBlockId;
        ts_ = getBatchVerifyingTransition(batchId_);
    }

    /// @inheritdoc ITaikoInbox
    function bondBalanceOf(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    /// @notice Determines the operational layer of the contract, whether it is on Layer 1 (L1) or
    /// Layer 2 (L2).
    /// @return True if the contract is operating on L1, false if on L2.
    function isOnL1() external pure override returns (bool) {
        return true;
    }

    // Public functions -------------------------------------------------------------------------

    /// @inheritdoc EssentialContract
    function paused() public view override returns (bool) {
        return state.stats2.paused;
    }

    /// @inheritdoc ITaikoInbox
    function getBatch(uint64 _batchId) public view returns (Batch memory batch_) {
        Config memory config = pacayaConfig();

        batch_ = state.batches[_batchId % config.batchRingBufferSize];
        require(batch_.batchId == _batchId, BatchNotFound());
    }

    /// @inheritdoc ITaikoInbox
    function getBatchVerifyingTransition(uint64 _batchId)
        public
        view
        returns (TransitionState memory ts_)
    {
        Config memory config = pacayaConfig();

        uint64 slot = _batchId % config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());

        if (batch.verifiedTransitionId != 0) {
            ts_ = state.transitions[slot][batch.verifiedTransitionId];
        }
    }

    /// @inheritdoc ITaikoInbox
    function pacayaConfig() public view virtual returns (Config memory);

    // Internal functions ----------------------------------------------------------------------

    function __Taiko_init(address _owner, bytes32 _genesisBlockHash) internal onlyInitializing {
        __Essential_init(_owner);

        require(_genesisBlockHash != 0, InvalidGenesisBlockHash());
        state.transitions[0][1].blockHash = _genesisBlockHash;

        Batch storage batch = state.batches[0];
        batch.metaHash = bytes32(uint256(1));
        batch.lastBlockTimestamp = uint64(block.timestamp);
        batch.anchorBlockId = uint64(block.number);
        batch.nextTransitionId = 2;
        batch.verifiedTransitionId = 1;

        state.stats1.genesisHeight = uint64(block.number);

        state.stats2.lastProposedIn = uint56(block.number);
        state.stats2.numBatches = 1;

        emit BatchesVerified(0, _genesisBlockHash);
    }

    function _unpause() internal override {
        state.stats2.lastUnpausedAt = uint64(block.timestamp);
        state.stats2.paused = false;
    }

    function _pause() internal override {
        state.stats2.paused = true;
    }

    function _calculateTxsHash(
        bytes32 _txListHash,
        BlobParams memory _blobParams
    )
        internal
        view
        virtual
        returns (bytes32 hash_, bytes32[] memory blobHashes_)
    {
        unchecked {
            if (_blobParams.blobHashes.length != 0) {
                blobHashes_ = _blobParams.blobHashes;
            } else {
                uint256 numBlobs = _blobParams.numBlobs;
                blobHashes_ = new bytes32[](numBlobs);
                for (uint256 i; i < numBlobs; ++i) {
                    blobHashes_[i] = blobhash(_blobParams.firstBlobIndex + i);
                }
            }

            uint256 bloblHashesLength = blobHashes_.length;
            for (uint256 i; i < bloblHashesLength; ++i) {
                require(blobHashes_[i] != 0, BlobNotFound());
            }
            hash_ = keccak256(abi.encode(_txListHash, blobHashes_));
        }
    }

    // Private functions -----------------------------------------------------------------------

    function _verifyBatches(
        Config memory _config,
        Stats2 memory _stats2,
        uint256 _length
    )
        private
    {
        uint64 batchId = _stats2.lastVerifiedBatchId;

        bool canVerifyBlocks;
        unchecked {
            uint64 pacayaForkHeight = pacayaConfig().forkHeights.pacaya;
            canVerifyBlocks = pacayaForkHeight == 0 || batchId >= pacayaForkHeight - 1;
        }

        if (canVerifyBlocks) {
            uint256 slot = batchId % _config.batchRingBufferSize;
            Batch storage batch = state.batches[slot];
            uint24 tid = batch.verifiedTransitionId;
            bytes32 blockHash = state.transitions[slot][tid].blockHash;

            SyncBlock memory synced;

            uint256 stopBatchId;
            unchecked {
                stopBatchId = (
                    _config.maxBatchesToVerify * _length + _stats2.lastVerifiedBatchId + 1
                ).min(_stats2.numBatches);
            }

            for (++batchId; batchId < stopBatchId; ++batchId) {
                slot = batchId % _config.batchRingBufferSize;
                batch = state.batches[slot];
                uint24 nextTransitionId = batch.nextTransitionId;

                if (paused()) break;
                if (nextTransitionId <= 1) break;

                TransitionState storage ts = state.transitions[slot][1];
                if (ts.parentHash == blockHash) {
                    tid = 1;
                } else if (nextTransitionId > 2) {
                    uint24 _tid = state.transitionIds[batchId][blockHash];
                    if (_tid == 0) break;
                    tid = _tid;
                    ts = state.transitions[slot][tid];
                } else {
                    break;
                }

                unchecked {
                    if (ts.createdAt + _config.cooldownWindow > block.timestamp) {
                        break;
                    }
                }

                blockHash = ts.blockHash;

                uint96 bondToReturn =
                    ts.inProvingWindow ? batch.livenessBond : batch.livenessBond / 2;
                _creditBond(ts.prover, bondToReturn);

                if (batchId % _config.stateRootSyncInternal == 0) {
                    synced.batchId = batchId;
                    synced.blockId = batch.lastBlockId;
                    synced.tid = tid;
                    synced.stateRoot = ts.stateRoot;
                }
            }

            unchecked {
                --batchId;
            }

            if (_stats2.lastVerifiedBatchId != batchId) {
                _stats2.lastVerifiedBatchId = batchId;

                batch = state.batches[_stats2.lastVerifiedBatchId % _config.batchRingBufferSize];
                batch.verifiedTransitionId = tid;
                emit BatchesVerified(_stats2.lastVerifiedBatchId, blockHash);

                if (synced.batchId != 0) {
                    if (synced.batchId != _stats2.lastVerifiedBatchId) {
                        // We write the synced batch's verifiedTransitionId to storage
                        batch = state.batches[synced.batchId % _config.batchRingBufferSize];
                        batch.verifiedTransitionId = synced.tid;
                    }

                    Stats1 memory stats1 = state.stats1;
                    stats1.lastSyncedBatchId = batch.batchId;
                    stats1.lastSyncedAt = uint64(block.timestamp);
                    state.stats1 = stats1;

                    emit Stats1Updated(stats1);

                    // Ask signal service to write cross chain signal
                    signalService.syncChainData(
                        _config.chainId, LibStrings.H_STATE_ROOT, synced.blockId, synced.stateRoot
                    );
                }
            }
        }

        state.stats2 = _stats2;
        emit Stats2Updated(_stats2);
    }

    function _debitBond(address _user, uint256 _amount) private {
        if (_amount == 0) return;

        uint256 balance = state.bondBalance[_user];
        if (balance >= _amount) {
            unchecked {
                state.bondBalance[_user] = balance - _amount;
            }
        } else {
            uint256 amountDeposited = _handleDeposit(_user, _amount);
            require(amountDeposited == _amount, InsufficientBond());
        }
        emit BondDebited(_user, _amount);
    }

    function _creditBond(address _user, uint256 _amount) private {
        if (_amount == 0) return;
        unchecked {
            state.bondBalance[_user] += _amount;
        }
        emit BondCredited(_user, _amount);
    }

    function _handleDeposit(
        address _user,
        uint256 _amount
    )
        private
        returns (uint256 amountDeposited_)
    {
        if (bondToken != address(0)) {
            require(msg.value == 0, MsgValueNotZero());

            uint256 balance = IERC20(bondToken).balanceOf(address(this));
            IERC20(bondToken).safeTransferFrom(_user, address(this), _amount);
            amountDeposited_ = IERC20(bondToken).balanceOf(address(this)) - balance;
        } else {
            require(msg.value == _amount, EtherNotPaidAsBond());
            amountDeposited_ = _amount;
        }
        emit BondDeposited(_user, amountDeposited_);
    }

    function _validateBatchParams(
        BatchParams memory _params,
        uint64 _maxAnchorHeightOffset,
        uint8 _maxSignalsToReceive,
        uint16 _maxBlocksPerBatch,
        Batch memory _lastBatch
    )
        private
        view
        returns (uint64 anchorBlockId_, uint64 lastBlockTimestamp_)
    {
        uint256 blocksLength = _params.blocks.length;
        unchecked {
            if (_params.anchorBlockId == 0) {
                anchorBlockId_ = uint64(block.number - 1);
            } else {
                require(
                    _params.anchorBlockId + _maxAnchorHeightOffset >= block.number,
                    AnchorBlockIdTooSmall()
                );
                require(_params.anchorBlockId < block.number, AnchorBlockIdTooLarge());
                require(
                    _params.anchorBlockId >= _lastBatch.anchorBlockId,
                    AnchorBlockIdSmallerThanParent()
                );
                anchorBlockId_ = _params.anchorBlockId;
            }

            lastBlockTimestamp_ = _params.lastBlockTimestamp == 0
                ? uint64(block.timestamp)
                : _params.lastBlockTimestamp;

            require(lastBlockTimestamp_ <= block.timestamp, TimestampTooLarge());

            uint64 totalShift;

            for (uint256 i; i < blocksLength; ++i) {
                totalShift += _params.blocks[i].timeShift;

                uint256 numSignals = _params.blocks[i].signalSlots.length;
                if (numSignals == 0) continue;

                require(numSignals <= _maxSignalsToReceive, TooManySignals());

                for (uint256 j; j < numSignals; ++j) {
                    require(
                        signalService.isSignalSent(_params.blocks[i].signalSlots[j]),
                        SignalNotSent()
                    );
                }
            }

            require(lastBlockTimestamp_ >= totalShift, TimestampTooSmall());

            uint64 firstBlockTimestamp = lastBlockTimestamp_ - totalShift;

            require(
                firstBlockTimestamp + _maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                    >= block.timestamp,
                TimestampTooSmall()
            );

            require(
                firstBlockTimestamp >= _lastBatch.lastBlockTimestamp, TimestampSmallerThanParent()
            );

            // make sure the batch builds on the expected latest chain state.
            require(
                _params.parentMetaHash == 0 || _params.parentMetaHash == _lastBatch.metaHash,
                ParentMetaHashMismatch()
            );
        }

        require(blocksLength != 0, BlockNotFound());
        require(blocksLength <= _maxBlocksPerBatch, TooManyBlocks());
    }

    // Memory-only structs ----------------------------------------------------------------------

    struct SyncBlock {
        uint64 batchId;
        uint64 blockId;
        uint24 tid;
        bytes32 stateRoot;
    }
}
