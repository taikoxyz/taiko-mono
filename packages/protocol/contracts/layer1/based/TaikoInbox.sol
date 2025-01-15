// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/signal/ISignalService.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./IFork.sol";
import "./ITaikoInbox.sol";

// import "forge-std/src/console2.sol";

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
abstract contract TaikoInbox is EssentialContract, ITaikoInbox, ITaiko, IFork {
    using LibMath for uint256;

    State public state; // storage layout much match Ontake fork

    // External functions ------------------------------------------------------------------------

    function init(
        address _owner,
        address _rollupResolver,
        bytes32 _genesisBlockHash
    )
        external
        initializer
    {
        __Taiko_init(_owner, _rollupResolver, _genesisBlockHash);
    }

    /// @notice Proposes multiple batches.
    /// @param _params ABI-encoded parameters consisting of:
    /// - proposer: The address of the proposer, which is set by the PreconfTaskManager if
    ///             enabled; otherwise, it must be address(0).
    /// - coinbase: The address that will receive the block rewards; defaults to the proposer's
    ///             address if set to address(0).
    /// - batchParams: Batch parameters.
    /// @param _txList      The transaction list in calldata.
    /// @return meta_       Batch metadata.
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        nonReentrant
        returns (BatchMetadata memory meta_)
    {
        Stats2 memory stats2 = state.stats2;
        require(!stats2.paused, ContractPaused());

        Config memory config = getConfig();
        require(stats2.numBatches >= config.forkHeights.pacaya, InvalidForkHeight());

        unchecked {
            require(
                stats2.numBatches < stats2.lastVerifiedBatchId + config.maxBatchProposals,
                TooManyBatches()
            );
        }

        BatchParams memory params = abi.decode(_params, (BatchParams));

        {
            address preconfRouter = resolve(LibStrings.B_PRECONF_ROUTER, true);
            if (preconfRouter == address(0)) {
                require(params.proposer == address(0), CustomProposerNotAllowed());
                params.proposer = msg.sender;
            } else {
                require(msg.sender == preconfRouter, NotPreconfRouter());
                require(params.proposer != address(0), CustomProposerMissing());
            }

            if (params.coinbase == address(0)) {
                params.coinbase = params.proposer;
            }
        }

        if (params.revertIfNotFirstProposal) {
            require(state.stats2.lastProposedIn != block.number, NotFirstProposal());
        }

        // Keep track of last batch's information.
        Batch storage lastBatch;
        unchecked {
            lastBatch = state.batches[(stats2.numBatches - 1) % config.batchRingBufferSize];
        }

        bool calldataUsed = _txList.length != 0;

        require(calldataUsed || params.numBlobs != 0, BlobNotSpecified());

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
        // Note that `difficulty` has been removed from the metadata. The client and prover must use
        // the following approach to calculate a block's difficulty:
        //  `keccak256(abi.encode("TAIKO_DIFFICULTY", block.number))`
        meta_ = BatchMetadata({
            txListHash: calldataUsed
                ? keccak256(_txList)
                : _calcTxListHash(params.firstBlobIndex, params.numBlobs),
            extraData: bytes32(uint256(config.baseFeeConfig.sharingPctg)),
            coinbase: params.coinbase,
            batchId: stats2.numBatches,
            gasLimit: config.blockMaxGasLimit,
            lastBlockTimestamp: lastBlockTimestamp,
            parentMetaHash: lastBatch.metaHash,
            proposer: params.proposer,
            livenessBond: config.livenessBondBase
                + config.livenessBondPerBlock * uint96(params.blocks.length),
            proposedAt: uint64(block.timestamp),
            proposedIn: uint64(block.number),
            txListOffset: params.txListOffset,
            txListSize: params.txListSize,
            numBlobs: calldataUsed ? 0 : params.numBlobs,
            anchorBlockId: anchorBlockId,
            anchorBlockHash: blockhash(anchorBlockId),
            signalSlots: params.signalSlots,
            blocks: params.blocks,
            anchorInput: params.anchorInput,
            baseFeeConfig: config.baseFeeConfig
        });

        require(meta_.anchorBlockHash != 0, ZeroAnchorBlockHash());
        require(meta_.txListHash != 0, BlobNotFound());
        bytes32 metaHash = keccak256(abi.encode(meta_));

        Batch storage batch = state.batches[stats2.numBatches % config.batchRingBufferSize];
        // SSTORE #1
        batch.metaHash = metaHash;

        // SSTORE #2 {{
        batch.batchId = stats2.numBatches;
        batch.lastBlockTimestamp = lastBlockTimestamp;
        batch.anchorBlockId = anchorBlockId;
        batch.nextTransitionId = 1;
        batch.verifiedTransitionId = 0;
        batch.reserved4 = 0;
        // SSTORE }}

        // SSTORE #3 {{
        if (stats2.numBatches == config.forkHeights.pacaya) {
            batch.lastBlockId = batch.batchId + uint8(params.blocks.length) - 1;
        } else {
            batch.lastBlockId = lastBatch.lastBlockId + uint8(params.blocks.length);
        }
        batch._reserved3 = 0;
        // SSTORE }}

        unchecked {
            stats2.numBatches += 1;
            stats2.lastProposedIn = uint56(block.number);
        }

        _debitBond(params.proposer, meta_.livenessBond);
        emit BatchProposed(meta_, calldataUsed, _txList);

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

        require(metas.length != 0, NoBlocksToProve());
        require(metas.length == trans.length, ArraySizesMismatch());

        Stats2 memory stats2 = state.stats2;
        require(stats2.paused == false, ContractPaused());

        Config memory config = getConfig();
        IVerifier.Context[] memory ctxs = new IVerifier.Context[](metas.length);

        bool hasConflictingOverwrite;
        for (uint256 i; i < metas.length; ++i) {
            BatchMetadata memory meta = metas[i];

            require(meta.batchId >= config.forkHeights.pacaya, InvalidForkHeight());
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
                // This batch has been proved at least once.
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

            bool isConflictingOverwrite;
            if (tid == 0) {
                // This transition is new, we need to use the next available ID.
                tid = batch.nextTransitionId++;
            } else {
                Transition memory oldTran = state.transitions[slot][tid];

                bool isSameTransition = oldTran.blockHash == tran.blockHash
                    && (oldTran.stateRoot == 0 || oldTran.stateRoot == tran.stateRoot);
                require(!isSameTransition, SameTransition());

                isConflictingOverwrite = true;
                emit TransitionOverwritten(meta.batchId, oldTran, tran);
            }

            Transition storage ts = state.transitions[slot][tid];
            if (tid == 1) {
                // Ensure that only the proposer can prove the first transition before the
                // proving deadline.
                unchecked {
                    uint256 deadline =
                        uint256(meta.proposedAt).max(stats2.lastUnpausedAt) + config.provingWindow;
                    if (block.timestamp <= deadline && !isConflictingOverwrite) {
                        _creditBond(meta.proposer, meta.livenessBond);
                    }

                    ts.parentHash = tran.parentHash;
                }
            } else {
                // No need to write parent hash to storage for transitions with id != 1 as the
                // parent hash is not used at all, instead, we need to update the parent hash to ID
                // mapping.
                state.transitionIds[meta.batchId][tran.parentHash] = tid;
            }

            if (meta.batchId % config.stateRootSyncInternal == 0) {
                // This batch is a "sync batch", we need to save the state root.
                ts.stateRoot = tran.stateRoot;
            } else {
                // This batch is not a "sync batch", we need to zero out the storage slot.
                ts.stateRoot = bytes32(0);
            }

            ts.blockHash = tran.blockHash;

            hasConflictingOverwrite = hasConflictingOverwrite || isConflictingOverwrite;
        }

        address verifier = resolve(LibStrings.B_PROOF_VERIFIER, false);
        IVerifier(verifier).verifyProof(ctxs, _proof);

        // Emit the event
        {
            uint64[] memory batchIds = new uint64[](metas.length);
            for (uint256 i; i < metas.length; ++i) {
                batchIds[i] = metas[i].batchId;
            }

            emit BatchesProved(verifier, batchIds, trans);
        }

        if (hasConflictingOverwrite) {
            _pause();
            emit Paused(verifier);
        } else {
            _verifyBatches(config, stats2, metas.length);
        }
    }

    /// @inheritdoc ITaikoInbox
    function depositBond(uint256 _amount) external payable whenNotPaused {
        state.bondBalance[msg.sender] += _amount;
        _handleDeposit(msg.sender, _amount);
    }

    /// @inheritdoc ITaikoInbox
    function withdrawBond(uint256 _amount) external whenNotPaused {
        uint256 balance = state.bondBalance[msg.sender];
        require(balance >= _amount, InsufficientBond());

        emit BondWithdrawn(msg.sender, _amount);

        state.bondBalance[msg.sender] -= _amount;

        address bond = bondToken();
        if (bond != address(0)) {
            IERC20(bond).transfer(msg.sender, _amount);
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
    function getTransition(
        uint64 _batchId,
        uint24 _tid
    )
        external
        view
        returns (Transition memory tran_)
    {
        Config memory config = getConfig();
        uint256 slot = _batchId % config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());
        require(_tid != 0 && _tid < batch.nextTransitionId, TransitionNotFound());
        return state.transitions[slot][_tid];
    }

    /// @inheritdoc ITaikoInbox
    function getLastVerifiedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, Transition memory tran_)
    {
        batchId_ = state.stats2.lastVerifiedBatchId;
        blockId_ = getBatch(batchId_).lastBlockId;
        tran_ = getBatchVerifyingTransition(batchId_);
    }

    /// @inheritdoc ITaikoInbox
    function getLastSyncedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, Transition memory tran_)
    {
        batchId_ = state.stats1.lastSyncedBatchId;
        blockId_ = getBatch(batchId_).lastBlockId;
        tran_ = getBatchVerifyingTransition(batchId_);
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

    // @inheritdoc IFork
    function isForkActive() external view override returns (bool) {
        return state.stats2.numBatches >= getConfig().forkHeights.pacaya;
    }

    // Public functions -------------------------------------------------------------------------

    /// @inheritdoc EssentialContract
    function paused() public view override returns (bool) {
        return state.stats2.paused;
    }

    /// @inheritdoc ITaikoInbox
    function bondToken() public view returns (address) {
        return resolve(LibStrings.B_BOND_TOKEN, true);
    }

    /// @inheritdoc ITaikoInbox
    function getBatch(uint64 _batchId) public view returns (Batch memory batch_) {
        Config memory config = getConfig();
        require(_batchId >= config.forkHeights.pacaya, InvalidForkHeight());

        batch_ = state.batches[_batchId % config.batchRingBufferSize];
        require(batch_.batchId == _batchId, BatchNotFound());
    }

    /// @inheritdoc ITaikoInbox
    function getBatchVerifyingTransition(uint64 _batchId)
        public
        view
        returns (Transition memory tran_)
    {
        Config memory config = getConfig();

        uint64 slot = _batchId % config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());

        if (batch.verifiedTransitionId != 0) {
            tran_ = state.transitions[slot][batch.verifiedTransitionId];
        }
    }

    /// @inheritdoc ITaikoInbox
    function getConfig() public view virtual returns (Config memory);

    // Internal functions ----------------------------------------------------------------------

    function __Taiko_init(
        address _owner,
        address _rollupResolver,
        bytes32 _genesisBlockHash
    )
        internal
    {
        __Essential_init(_owner, _rollupResolver);

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

    function _calcTxListHash(
        uint8 _firstBlobIndex,
        uint8 _numBlobs
    )
        internal
        view
        virtual
        returns (bytes32)
    {
        bytes32[] memory blobHashes = new bytes32[](_numBlobs);
        for (uint256 i; i < _numBlobs; ++i) {
            blobHashes[i] = blobhash(_firstBlobIndex + i);
            require(blobHashes[i] != 0, BlobNotFound());
        }
        return keccak256(abi.encode(blobHashes));
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
        uint256 slot = batchId % _config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        uint24 tid = batch.verifiedTransitionId;
        bytes32 blockHash = state.transitions[slot][tid].blockHash;

        SyncBlock memory synced;

        uint256 stopBatchId = (_config.maxBatchesToVerify * _length + _stats2.lastVerifiedBatchId)
            .min(_stats2.numBatches);

        for (++batchId; batchId < stopBatchId; ++batchId) {
            slot = batchId % _config.batchRingBufferSize;
            batch = state.batches[slot];

            // FIX
            Transition storage ts = state.transitions[slot][1];
            if (ts.parentHash == blockHash) {
                tid = 1;
            } else {
                uint24 _tid = state.transitionIds[batchId][blockHash];
                if (_tid == 0) break;
                tid = _tid;
                ts = state.transitions[slot][tid];
            }

            blockHash = ts.blockHash;

            if (batchId % _config.stateRootSyncInternal == 0) {
                synced.batchId = batchId;
                synced.blockId = batch.lastBlockId;
                synced.tid = tid;
                synced.stateRoot = ts.stateRoot;
            }

            for (uint24 i = 2; i < batch.nextTransitionId; ++i) {
                ts = state.transitions[slot][i];
                delete state.transitionIds[batchId][ts.parentHash];
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
                ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false)).syncChainData(
                    _config.chainId, LibStrings.H_STATE_ROOT, synced.blockId, synced.stateRoot
                );
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
            _handleDeposit(_user, _amount);
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

    function _handleDeposit(address _user, uint256 _amount) private {
        address bond = bondToken();

        if (bond != address(0)) {
            require(msg.value == 0, MsgValueNotZero());
            IERC20(bond).transferFrom(_user, address(this), _amount);
        } else {
            require(msg.value == _amount, EtherNotPaidAsBond());
        }
        emit BondDeposited(_user, _amount);
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
            for (uint256 i; i < _params.blocks.length; ++i) {
                totalShift += _params.blocks[i].timeShift;
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

        if (_params.signalSlots.length != 0) {
            require(_params.signalSlots.length <= _maxSignalsToReceive, TooManySignals());

            ISignalService signalService =
                ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false));

            for (uint256 i; i < _params.signalSlots.length; ++i) {
                require(signalService.isSignalSent(_params.signalSlots[i]), SignalNotSent());
            }
        }

        require(_params.blocks.length != 0, BlockNotFound());
        require(_params.blocks.length <= _maxBlocksPerBatch, TooManyBlocks());
    }

    // Memory-only structs ----------------------------------------------------------------------

    struct SyncBlock {
        uint64 batchId;
        uint64 blockId;
        uint24 tid;
        bytes32 stateRoot;
    }
}
