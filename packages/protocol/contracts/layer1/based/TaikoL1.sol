// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/signal/ISignalService.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./ITaikoL1.sol";

import "forge-std/src/console2.sol";

/// @title TaikoL1
/// @notice This contract acts as the inbox for a simplified version of the original Taiko Based
/// Contestable Rollup (BCR) protocol, specifically the tier-based proof system and proof
/// contestation
/// mechanisms have been removed.
///
/// The primary assumptions of this protocol are:
/// - Proofs are not available at the time of block proposal, leading to an asynchronous process
///   between block proposing and proving (unlike Taiko Gwyneth, which assumes availability of
/// proofs
///   at proposal time and supports synchronous composability).
/// - Proofs are presumed to be error-free and rigorously validated. The responsibility for managing
///   various proof types has been transferred to IVerifier contracts.
///
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoL1 is EssentialContract, ITaikoL1 {
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

    /// @notice Proposes multiple blocks.
    /// @param _proposer    The address of the proposer, which is set by the PreconfTaskManager if
    ///                     enabled; otherwise, it must be address(0).
    /// @param _coinbase    The address that will receive the block rewards; defaults to the
    ///                     proposer's address if set to address(0).
    /// @param _signals     Array of signals to be accessed by the proposed blocks.
    /// @param _paramsArray An array containing the parameters for each block being proposed.
    /// @return metas_      Array of block metadata for each block proposed.
    function proposeBlocksV3(
        address _proposer,
        address _coinbase,
        LibSharedData.Signal[] calldata _signals,
        BlockParamsV3[] calldata _paramsArray
    )
        external
        nonReentrant
        returns (BlockMetadataV3[] memory metas_)
    {
        require(_paramsArray.length != 0, NoBlocksToPropose());

        Stats2 memory stats2 = state.stats2;
        require(!stats2.paused, ContractPaused());

        ConfigV3 memory config = getConfigV3();
        require(stats2.numBlocks >= config.pacayaForkHeight, InvalidForkHeight());

        unchecked {
            require(
                stats2.numBlocks + _paramsArray.length
                    <= stats2.lastVerifiedBlockId + config.blockMaxProposals,
                TooManyBlocks()
            );
        }

        // Keep track of last block's information.
        BlockInfo memory lastBlock;
        unchecked {
            BlockV3 storage lastBlk =
                state.blocks[(stats2.numBlocks - 1) % config.blockRingBufferSize];

            lastBlock = BlockInfo(lastBlk.metaHash, lastBlk.timestamp, lastBlk.anchorBlockId);
        }

        if (_proposer == address(0)) {
            _proposer = msg.sender;
        } else {
            address preconfTaskManager = resolve(LibStrings.B_PRECONF_TASK_MANAGER, false);
            require(preconfTaskManager == msg.sender, NotPreconfTaskManager());
        }

        if (_coinbase == address(0)) {
            _coinbase = _proposer;
        }

        ISignalService signalService = ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false));
        for (uint256 i; i < _signals.length; ++i) {
            require(
                signalService.isSignalSent(_signals[i].sender, _signals[i].signal), InvalidSignal()
            );
        }

        bytes32 signalsHash = keccak256(abi.encode(_signals));

        metas_ = new BlockMetadataV3[](_paramsArray.length);

        for (uint256 i; i < _paramsArray.length; ++i) {
            UpdatedParams memory updatedParams =
                _validateBlockParams(_paramsArray[i], config.maxAnchorHeightOffset, lastBlock);

            // This section constructs the metadata for the proposed block, which is crucial for
            // nodes/clients
            // to process the block. The metadata itself is not stored on-chain; instead, only its
            // hash is kept.
            // The metadata must be supplied as calldata prior to proving the block, enabling the
            // computation
            // and verification of its integrity through the comparison of the metahash.
            metas_[i] = BlockMetadataV3({
                anchorBlockHash: blockhash(updatedParams.anchorBlockId),
                difficulty: keccak256(abi.encode("TAIKO_DIFFICULTY", stats2.numBlocks)),
                blobHash: _blobhash(_paramsArray[i].blobIndex),
                extraData: bytes32(uint256(config.baseFeeConfig.sharingPctg)),
                coinbase: _coinbase,
                blockId: stats2.numBlocks,
                gasLimit: config.blockMaxGasLimit,
                timestamp: updatedParams.timestamp,
                anchorBlockId: updatedParams.anchorBlockId,
                parentMetaHash: lastBlock.metaHash,
                signalsHash: signalsHash,
                proposer: _proposer,
                livenessBond: config.livenessBond,
                proposedAt: uint64(block.timestamp),
                proposedIn: uint64(block.number),
                blobTxListOffset: _paramsArray[i].blobTxListOffset,
                blobTxListLength: _paramsArray[i].blobTxListLength,
                blobIndex: _paramsArray[i].blobIndex,
                baseFeeConfig: config.baseFeeConfig
            });

            require(metas_[i].blobHash != 0, BlobNotFound());
            bytes32 metaHash = keccak256(abi.encode(metas_[i]));

            BlockV3 storage blk = state.blocks[stats2.numBlocks % config.blockRingBufferSize];
            // SSTORE #1
            blk.metaHash = metaHash;

            // SSTORE #2 {{
            blk.blockId = stats2.numBlocks;
            blk.timestamp = updatedParams.timestamp;
            blk.anchorBlockId = updatedParams.anchorBlockId;
            blk.nextTransitionId = 1;
            blk.verifiedTransitionId = 0;
            // SSTORE }}

            // Update lastBlock to reference the most recently proposed block.
            lastBlock = BlockInfo(metaHash, updatedParams.timestamp, updatedParams.anchorBlockId);

            unchecked {
                stats2.numBlocks += 1;
                stats2.lastProposedIn = uint56(block.number);
            }
        } // end of for-loop

        _debitBond(_proposer, config.livenessBond * _paramsArray.length);
        emit BlocksProposedV3(_signals, metas_);

        _verifyBlocks(signalService, config, stats2, _paramsArray.length);
    }

    /// @notice Proves multiple blocks with a single aggregated proof.
    /// @param _metas       Array of block metadata to be proven.
    /// @param _transitions Array of transitions corresponding to the block metadata.
    /// @param _proof       Cryptographic proof validating all the transitions.
    function proveBlocksV3(
        BlockMetadataV3[] calldata _metas,
        TransitionV3[] calldata _transitions,
        bytes calldata _proof
    )
        external
        nonReentrant
    {
        require(_metas.length != 0, NoBlocksToProve());
        require(_metas.length == _transitions.length, ArraySizesMismatch());
        require(_proof.length != 0, ProofNotFound());

        Stats2 memory stats2 = state.stats2;
        require(stats2.paused == false, ContractPaused());

        ConfigV3 memory config = getConfigV3();
        uint64[] memory blockIds = new uint64[](_metas.length);
        IVerifier.Context[] memory ctxs = new IVerifier.Context[](_metas.length);

        for (uint256 i; i < _metas.length; ++i) {
            BlockMetadataV3 calldata meta = _metas[i];

            blockIds[i] = meta.blockId;
            require(meta.blockId >= config.pacayaForkHeight, InvalidForkHeight());
            require(meta.blockId > stats2.lastVerifiedBlockId, BlockNotFound());
            require(meta.blockId < stats2.numBlocks, BlockNotFound());

            TransitionV3 calldata tran = _transitions[i];
            require(tran.parentHash != 0, InvalidTransitionParentHash());
            require(tran.blockHash != 0, InvalidTransitionBlockHash());
            require(tran.stateRoot != 0, InvalidTransitionStateRoot());

            ctxs[i].blockId = meta.blockId;
            ctxs[i].difficulty = meta.difficulty;
            ctxs[i].metaHash = keccak256(abi.encode(meta));
            ctxs[i].transition = tran;

            // Verify the block's metadata.
            uint256 slot = meta.blockId % config.blockRingBufferSize;
            BlockV3 storage blk = state.blocks[slot];
            require(ctxs[i].metaHash == blk.metaHash, MetaHashMismatch());

            // Finds out if this transition is overwriting an existing one (with the same parent
            // hash) or is a new one.
            uint24 tid;
            uint24 nextTransitionId = blk.nextTransitionId;
            if (nextTransitionId > 1) {
                // This block has been proved at least once.
                if (state.transitions[slot][1].parentHash == tran.parentHash) {
                    // Overwrite the first transition.
                    tid = 1;
                } else if (nextTransitionId > 2) {
                    // Retrieve the transition ID using the parent hash from the mapping. If the ID
                    // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                    // existing transition.
                    tid = state.transitionIds[meta.blockId][tran.parentHash];
                }
            }

            bool isOverwrite = (tid != 0);
            if (tid == 0) {
                // This transition is new, we need to use the next available ID.
                tid = blk.nextTransitionId++;
            }

            TransitionV3 storage ts = state.transitions[slot][tid];
            if (isOverwrite) {
                emit TransitionOverwrittenV3(meta.blockId, ts);
            } else if (tid == 1) {
                // Ensure that only the block proposer can prove the first transition before the
                // proving deadline.
                unchecked {
                    uint256 deadline =
                        uint256(meta.proposedAt).max(stats2.lastUnpausedAt) + config.provingWindow;
                    if (block.timestamp <= deadline) {
                        require(msg.sender == meta.proposer, ProverNotPermitted());
                        _creditBond(meta.proposer, meta.livenessBond);
                    }

                    ts.parentHash = tran.parentHash;
                }
            } else {
                // No need to write parent hash to storage for transitions with id != 1 as the
                // parent hash is not used at all, instead, we need to update the parent hash to ID
                // mapping.
                state.transitionIds[meta.blockId][tran.parentHash] = tid;
            }

            if (meta.blockId % config.stateRootSyncInternal == 0) {
                // This block is a "sync block", we need to save the state root.
                ts.stateRoot = tran.stateRoot;
            } else {
                // This block is not a "sync block", we need to zero out the storage slot.
                ts.stateRoot = bytes32(0);
            }

            ts.blockHash = tran.blockHash;
        }

        address verifier = resolve(LibStrings.B_PROOF_VERIFIER, false);
        IVerifier(verifier).verifyProof(ctxs, _proof);

        emit BlocksProvedV3(verifier, blockIds, _transitions);

        ISignalService signalService = ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false));
        _verifyBlocks(signalService, config, stats2, _metas.length);
    }

    function depositBond(uint256 _amount) external payable whenNotPaused {
        state.bondBalance[msg.sender] += _amount;
        _handleDeposit(msg.sender, _amount);
    }

    function withdrawBond(uint256 _amount) external whenNotPaused {
        emit BondWithdrawn(msg.sender, _amount);

        state.bondBalance[msg.sender] -= _amount;

        address bond = bondToken();
        if (bond != address(0)) {
            IERC20(bond).transfer(msg.sender, _amount);
        } else {
            LibAddress.sendEtherAndVerify(msg.sender, _amount);
        }
    }

    function getStats1() external view returns (Stats1 memory) {
        return state.stats1;
    }

    function getStats2() external view returns (Stats2 memory) {
        return state.stats2;
    }

    function getTransitionV3(
        uint64 _blockId,
        uint24 _tid
    )
        external
        view
        returns (TransitionV3 memory tran_)
    {
        ConfigV3 memory config = getConfigV3();
        uint256 slot = _blockId % config.blockRingBufferSize;
        BlockV3 storage blk = state.blocks[slot];
        require(blk.blockId == _blockId, BlockNotFound());
        require(_tid != 0 && _tid < blk.nextTransitionId, TransitionNotFound());
        return state.transitions[slot][_tid];
    }

    function getLastVerifiedTransitionV3()
        external
        view
        returns (uint64 blockId_, TransitionV3 memory tran_)
    {
        blockId_ = state.stats2.lastVerifiedBlockId;
        tran_ = getBlockVerifyingTransition(blockId_);
    }

    function getLastSyncedTransitionV3()
        external
        view
        returns (uint64 blockId_, TransitionV3 memory tran_)
    {
        blockId_ = state.stats1.lastSyncedBlockId;
        tran_ = getBlockVerifyingTransition(blockId_);
    }

    function bondBalanceOf(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    function getBlockV3(uint64 _blockId) external view returns (BlockV3 memory blk_) {
        ConfigV3 memory config = getConfigV3();
        require(_blockId >= config.pacayaForkHeight, InvalidForkHeight());

        blk_ = state.blocks[_blockId % config.blockRingBufferSize];
        require(blk_.blockId == _blockId, BlockNotFound());
    }

    // Public functions -------------------------------------------------------------------------

    function paused() public view override returns (bool) {
        return state.stats2.paused;
    }

    function bondToken() public view returns (address) {
        return resolve(LibStrings.B_BOND_TOKEN, true);
    }

    function getBlockVerifyingTransition(uint64 _blockId)
        public
        view
        returns (TransitionV3 memory tran_)
    {
        ConfigV3 memory config = getConfigV3();

        uint64 slot = _blockId % config.blockRingBufferSize;
        BlockV3 storage blk = state.blocks[slot];
        require(blk.blockId == _blockId, BlockNotFound());

        if (blk.verifiedTransitionId != 0) {
            tran_ = state.transitions[slot][blk.verifiedTransitionId];
        }
    }

    function getConfigV3() public view virtual returns (ConfigV3 memory);

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

        BlockV3 storage blk = state.blocks[0];
        blk.metaHash = bytes32(uint256(1));
        blk.timestamp = uint64(block.timestamp);
        blk.anchorBlockId = uint64(block.number);
        blk.nextTransitionId = 2;
        blk.verifiedTransitionId = 1;

        state.stats2.lastProposedIn = uint56(block.number);
        state.stats2.numBlocks = 1;
        emit BlockVerifiedV3(0, _genesisBlockHash);
    }

    function _unpause() internal override {
        state.stats2.lastUnpausedAt = uint64(block.timestamp);
        state.stats2.paused = false;
    }

    function _pause() internal override {
        state.stats2.paused = true;
    }

    function _blobhash(uint256 _blobIndex) internal view virtual returns (bytes32) {
        return blobhash(_blobIndex);
    }

    // Private functions -----------------------------------------------------------------------

    function _verifyBlocks(
        ISignalService _signalService,
        ConfigV3 memory _config,
        Stats2 memory _stats2,
        uint256 _length
    )
        private
    {
        uint64 blockId = _stats2.lastVerifiedBlockId;
        uint256 slot = blockId % _config.blockRingBufferSize;
        BlockV3 storage blk = state.blocks[slot];
        uint24 tid = blk.verifiedTransitionId;
        bytes32 blockHash = state.transitions[slot][tid].blockHash;

        SyncBlock memory synced;

        uint256 stopBlockId = (_config.maxBlocksToVerify * _length + _stats2.lastVerifiedBlockId)
            .min(_stats2.numBlocks);

        for (++blockId; blockId < stopBlockId; ++blockId) {
            slot = blockId % _config.blockRingBufferSize;
            blk = state.blocks[slot];

            // FIX
            TransitionV3 storage ts = state.transitions[slot][1];
            if (ts.parentHash == blockHash) {
                tid = 1;
            } else {
                uint24 _tid = state.transitionIds[blockId][blockHash];
                if (_tid == 0) break;
                tid = _tid;
                ts = state.transitions[slot][tid];
            }

            blockHash = ts.blockHash;

            if (blockId % _config.stateRootSyncInternal == 0) {
                synced.blockId = blockId;
                synced.tid = tid;
                synced.stateRoot = ts.stateRoot;
            }

            for (uint24 i = 2; i < blk.nextTransitionId; ++i) {
                ts = state.transitions[slot][i];
                delete state.transitionIds[blockId][ts.parentHash];
            }
        }

        unchecked {
            --blockId;
        }

        if (_stats2.lastVerifiedBlockId != blockId) {
            _stats2.lastVerifiedBlockId = blockId;

            blk = state.blocks[_stats2.lastVerifiedBlockId % _config.blockRingBufferSize];
            blk.verifiedTransitionId = tid;
            emit BlockVerifiedV3(_stats2.lastVerifiedBlockId, blockHash);

            if (synced.blockId != 0) {
                if (synced.blockId != _stats2.lastVerifiedBlockId) {
                    // We write the synced block's verifiedTransitionId to storage
                    blk = state.blocks[synced.blockId % _config.blockRingBufferSize];
                    blk.verifiedTransitionId = synced.tid;
                }

                Stats1 memory stats1 = state.stats1;
                stats1.lastSyncedBlockId = synced.blockId;
                stats1.lastSyncedAt = uint64(block.timestamp);
                state.stats1 = stats1;

                emit Stats1Updated(stats1);

                // Ask signal service to write cross chain signal
                _signalService.syncChainData(
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

    function _validateBlockParams(
        BlockParamsV3 calldata _params,
        uint64 _maxAnchorHeightOffset,
        BlockInfo memory _parent
    )
        private
        view
        returns (UpdatedParams memory updatedParams_)
    {
        unchecked {
            if (_params.anchorBlockId == 0) {
                updatedParams_.anchorBlockId = uint64(block.number - 1);
            } else {
                require(
                    _params.anchorBlockId + _maxAnchorHeightOffset >= block.number,
                    AnchorBlockIdTooSmall()
                );
                require(_params.anchorBlockId < block.number, AnchorBlockIdTooLarge());
                require(
                    _params.anchorBlockId >= _parent.anchorBlockId, AnchorBlockIdSmallerThanParent()
                );
                updatedParams_.anchorBlockId = _params.anchorBlockId;
            }

            if (_params.timestamp == 0) {
                updatedParams_.timestamp = uint64(block.timestamp);
            } else {
                // Verify the provided timestamp to anchor. Note that params_.anchorBlockId
                // and params_.timestamp may not correspond to the same L1 block.
                require(
                    _params.timestamp + _maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                        >= block.timestamp,
                    TimestampTooSmall()
                );
                require(_params.timestamp <= block.timestamp, TimestampTooLarge());
                require(_params.timestamp >= _parent.timestamp, TimestampSmallerThanParent());

                updatedParams_.timestamp = _params.timestamp;
            }

            // Check if parent block has the right meta hash. This is to allow the proposer to
            // make sure the block builds on the expected latest chain state.
            require(
                _params.parentMetaHash == 0 || _params.parentMetaHash == _parent.metaHash,
                ParentMetaHashMismatch()
            );
        }
    }

    // Memory-only structs ----------------------------------------------------------------------

    struct BlockInfo {
        bytes32 metaHash;
        uint64 anchorBlockId;
        uint64 timestamp;
    }

    struct UpdatedParams {
        uint64 anchorBlockId;
        uint64 timestamp;
    }

    struct SyncBlock {
        uint64 blockId;
        uint24 tid;
        bytes32 stateRoot;
    }
}
