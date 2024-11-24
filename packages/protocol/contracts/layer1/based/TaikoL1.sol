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

/// @title TaikoL1
/// @notice This contract serves as the "base layer contract" of the Taiko protocol, providing
/// functionalities for proposing, proving, and verifying blocks. The term "base layer contract"
/// means that although this is usually deployed on L1, it can also be deployed on L2s to create
/// L3s. The contract also handles the deposit and withdrawal of Taiko tokens and Ether.
/// Additionally, this contract doesn't hold any Ether. Ether deposited to L2 are held by the Bridge
/// contract.
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract TaikoL1 is EssentialContract, ITaikoL1 {
    using LibMath for uint256;

    struct TransientParentBlock {
        bytes32 metaHash;
        uint64 anchorBlockId;
        uint64 timestamp;
    }

    struct TransientSyncedBlock {
        uint64 blockId;
        uint24 tid;
        bytes32 stateRoot;
    }

    State public state;
    uint256[50] private __gap;

    // External functions
    // ------------------------------------------------------------------------------------------

    function init(
        address _owner,
        address _rollupResolver,
        bytes32 _genesisBlockHash
    )
        external
        initializer
    {
        __TaikoL1_init(_owner, _rollupResolver, _genesisBlockHash);
    }

    function proposeBlocksV3(
        address _proposer,
        address _coinbase,
        bytes[] calldata _blockParams
    )
        external
        nonReentrant
        returns (BlockMetadataV3[] memory metas_)
    {
        require(_blockParams.length != 0, "NoBlocksToPropose");

        StatsB memory statsB = state.statsB;
        require(statsB.paused == false, "ContractPaused");

        ConfigV3 memory config = getConfigV3();
        require(statsB.numBlocks >= config.pacayaForkHeight, "InvalidForkHeight");
        require(
            statsB.numBlocks + _blockParams.length
                <= statsB.lastVerifiedBlockId + config.blockMaxProposals,
            "TooManyBlocks"
        );

        TransientParentBlock memory parent;
        {
            BlockV3 storage parentBlk =
                state.blocks[(statsB.numBlocks - 1) % config.blockRingBufferSize];
            parent = TransientParentBlock({
                metaHash: parentBlk.metaHash,
                timestamp: parentBlk.timestamp,
                anchorBlockId: parentBlk.anchorBlockId
            });
        }

        _proposer = _checkProposer(_proposer);
        if (_coinbase == address(0)) {
            _coinbase = _proposer;
        }

        metas_ = new BlockMetadataV3[](_blockParams.length);
        for (uint256 i; i < _blockParams.length; ++i) {
            BlockParamsV3 memory params =
                _validateBlockParams(_blockParams[i], config.maxAnchorHeightOffset, parent);

            (metas_[i], parent.metaHash) =
                _proposeBlock(config, statsB, params, _proposer, _coinbase);

            parent.timestamp = params.timestamp;
            parent.anchorBlockId = params.anchorBlockId;

            unchecked {
                statsB.numBlocks += 1;
                statsB.lastProposedIn = uint56(block.number);
            }
        } // end of for-loop

        _debitBond(_proposer, config.livenessBond * _blockParams.length);
        _verifyBlocks(config, statsB, _blockParams.length);
    }

    function proveBlocksV3(
        BlockMetadataV3[] calldata _metas,
        TransitionV3[] calldata _transitions,
        bytes calldata proof
    )
        external
        nonReentrant
    {
        require(_metas.length == _transitions.length, "InvalidParam");

        StatsB memory statsB = state.statsB;
        require(statsB.paused == false, "ContractPaused");

        ConfigV3 memory config = getConfigV3();
        IVerifier.ContextV3[] memory ctxs = new IVerifier.ContextV3[](_metas.length);
        for (uint256 i; i < _metas.length; ++i) {
            ctxs[i] = _proveBlock(config, statsB, _metas[i], _transitions[i]);
        }

        IVerifier(resolve("TODO", false)).verifyProofV3(ctxs, proof);

        _verifyBlocks(config, statsB, _metas.length);
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

    function getStatsA() external view returns (StatsA memory) {
        return state.statsA;
    }

    function getStatsB() external view returns (StatsB memory) {
        return state.statsB;
    }

    function getLastVerifiedBlockV3()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_)
    {
        blockId_ = state.statsB.lastVerifiedBlockId;
        (blockHash_, stateRoot_) = _getBlockInfo(blockId_);
    }

    function getLastSyncedBlockV3()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_)
    {
        blockId_ = state.statsA.lastSyncedBlockId;
        (blockHash_, stateRoot_) = _getBlockInfo(blockId_);
    }

    function bondBalanceOf(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    function getBlockV3(uint64 _blockId) external view returns (BlockV3 memory blk_) {
        ConfigV3 memory config = getConfigV3();
        require(_blockId >= config.pacayaForkHeight, "InvalidForkHeight");

        blk_ = state.blocks[_blockId % config.blockRingBufferSize];
        require(blk_.blockId == _blockId, "BlockNotFound");
    }

    // Public functions
    // ------------------------------------------------------------------------------------------

    function paused() public view override returns (bool) {
        return state.statsB.paused;
    }

    function bondToken() public view returns (address) {
        return resolve(LibStrings.B_BOND_TOKEN, true);
    }

    function getConfigV3() public view virtual returns (ConfigV3 memory) {
        return ConfigV3({
            chainId: LibNetwork.TAIKO_MAINNET,
            blockMaxProposals: 324_000, // = 7200 * 45
            blockRingBufferSize: 360_000, // = 7200 * 50
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
            stateRootSyncInternal: 16,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000,
                maxGasIssuancePerBlock: 600_000_000 // two minutes
             }),
            pacayaForkHeight: 0,
            provingWindow: 2 hours
        });
    }

    // Internal functions
    // ------------------------------------------------------------------------------------------

    function __TaikoL1_init(
        address _owner,
        address _rollupResolver,
        bytes32 _genesisBlockHash
    )
        internal
    {
        __Essential_init(_owner, _rollupResolver);

        require(_genesisBlockHash != 0, "InvalidGenesisBlockHash");
        // Init state
        state.statsA.genesisHeight = uint64(block.number);
        state.statsA.genesisTimestamp = uint64(block.timestamp);
        state.statsB.numBlocks = 1;

        // Init the genesis block
        BlockV3 storage blk = state.blocks[0];
        blk.nextTransitionId = 2;
        blk.timestamp = uint64(block.timestamp);
        blk.anchorBlockId = uint64(block.number);
        blk.verifiedTransitionId = 1;
        blk.metaHash = bytes32(uint256(1)); // Give the genesis metahash a non-zero value.

        // Init the first state transition
        TransitionV3 storage ts = state.transitions[0][1];
        ts.blockHash = _genesisBlockHash;

        emit BlockVerifiedV3({ blockId: 0, blockHash: _genesisBlockHash });
    }

    function _unpause() internal override {
        state.statsB.lastUnpausedAt = uint64(block.timestamp);
        state.statsB.paused = false;
    }

    function _pause() internal override {
        state.statsB.paused = true;
    }

    // Private functions
    // ------------------------------------------------------------------------------------------

    function _proposeBlock(
        ConfigV3 memory _config,
        StatsB memory _statsB,
        BlockParamsV3 memory _params,
        address _proposer,
        address _coinbase
    )
        internal
        returns (BlockMetadataV3 memory meta_, bytes32 metaHash_)
    {
        // Initialize metadata to compute a metaHash, which forms a part of the block data to be
        // stored on-chain for future integrity checks. If we choose to persist all data fields
        // in the metadata, it will require additional storage slots.
        meta_ = BlockMetadataV3({
            anchorBlockHash: blockhash(_params.anchorBlockId),
            difficulty: keccak256(abi.encode("TAIKO_DIFFICULTY", _statsB.numBlocks)),
            blobHash: blobhash(_params.blobIndex),
            extraData: bytes32(uint256(_config.baseFeeConfig.sharingPctg)),
            coinbase: _coinbase,
            id: _statsB.numBlocks,
            gasLimit: _config.blockMaxGasLimit,
            timestamp: _params.timestamp,
            anchorBlockId: _params.anchorBlockId,
            parentMetaHash: _params.parentMetaHash,
            proposer: _proposer,
            livenessBond: _config.livenessBond,
            proposedAt: uint64(block.timestamp),
            proposedIn: uint64(block.number),
            blobTxListOffset: _params.blobTxListOffset,
            blobTxListLength: _params.blobTxListLength,
            blobIndex: _params.blobIndex,
            baseFeeConfig: _config.baseFeeConfig
        });

        require(meta_.blobHash != 0, "BlobNotFound");

        // Use a storage pointer for the block in the ring buffer
        BlockV3 storage blk = state.blocks[_statsB.numBlocks % _config.blockRingBufferSize];

        metaHash_ = keccak256(abi.encode(meta_));
        // SSTORE
        blk.metaHash = metaHash_;

        // SSTORE {{
        blk.blockId = _statsB.numBlocks;
        blk.timestamp = _params.timestamp;
        blk.anchorBlockId = _params.anchorBlockId;
        blk.nextTransitionId = 1;
        blk.verifiedTransitionId = 0;
        // SSTORE }}

        emit BlockProposedV3(_statsB.numBlocks, meta_);
    }

    function _proveBlock(
        ConfigV3 memory _config,
        StatsB memory _statsB,
        BlockMetadataV3 calldata _meta,
        TransitionV3 calldata _tran
    )
        private
        returns (IVerifier.ContextV3 memory ctx_)
    {
        require(_meta.id >= _config.pacayaForkHeight, "InvalidForkHeight");
        require(_meta.id < _statsB.lastVerifiedBlockId, "BlockVerified");
        require(_meta.id < _statsB.numBlocks, "BlockNotProposed");

        require(_tran.parentHash != 0, "InvalidTransitionParentHash");
        require(_tran.blockHash != 0, "InvalidTransitionBlockHash");
        require(_tran.stateRoot != 0, "InvalidTransitionStateRoot");

        ctx_.metaHash = keccak256(abi.encode(_meta));
        ctx_.difficulty = _meta.difficulty;
        ctx_.tran = _tran;

        uint256 slot = _meta.id % _config.blockRingBufferSize;
        BlockV3 storage blk = state.blocks[slot];
        require(ctx_.metaHash == blk.metaHash, "MataMismatch");

        TransitionV3 storage ts = state.transitions[slot][1];
        require(ts.parentHash != _tran.parentHash, "AlreadyProvenAsFirstTransition");
        require(state.transitionIds[_meta.id][_tran.parentHash] == 0, "AlreadyProven");

        uint24 tid = blk.nextTransitionId++;
        ts = state.transitions[slot][tid];

        // Checks if only the assigned prover is permissioned to prove the block. The assigned
        // prover is granted exclusive permission to prove only the first transition.
        if (tid == 1) {
            if (msg.sender == _meta.proposer) {
                _creditBond(_meta.proposer, _meta.livenessBond);
            } else {
                uint256 deadline = uint256(_meta.proposedAt).max(_statsB.lastUnpausedAt);
                deadline += _config.provingWindow;
                require(block.timestamp >= deadline, "ProvingWindowNotPassed");
            }
            ts.parentHash = _tran.parentHash;
        } else {
            state.transitionIds[_meta.id][_tran.parentHash] = tid;
        }

        ts.blockHash = _tran.blockHash;

        if (_isSyncBlock(_config.stateRootSyncInternal, _meta.id)) {
            ts.stateRoot = _tran.stateRoot;
        }

        emit BlockProvedV3(_meta.id, _tran);
    }

    function _verifyBlocks(
        ConfigV3 memory _config,
        StatsB memory _statsB,
        uint256 _length
    )
        private
    {
        uint64 blockId = _statsB.lastVerifiedBlockId;
        uint256 slot = blockId % _config.blockRingBufferSize;
        BlockV3 storage blk = state.blocks[slot];
        uint24 verifiedTransitionId = blk.verifiedTransitionId;
        bytes32 verifiedBlockHash = state.transitions[slot][verifiedTransitionId].blockHash;

        TransientSyncedBlock memory synced;

        uint256 stopBlockId = (_config.maxBlocksToVerify * _length + _statsB.lastVerifiedBlockId)
            .min(_statsB.numBlocks);

        for (++blockId; blockId <= stopBlockId; ++blockId) {
            slot = blockId % _config.blockRingBufferSize;
            blk = state.blocks[slot];
            // TODO(daniel): get Tid;
            uint24 tid;

            if (tid == 0) break;
            TransitionV3 storage ts = state.transitions[slot][tid];

            verifiedBlockHash = ts.blockHash;
            verifiedTransitionId = tid;

            if (_isSyncBlock(_config.stateRootSyncInternal, blockId)) {
                synced.blockId = blockId;
                synced.tid = tid;
                synced.stateRoot = ts.stateRoot;
            }
        }

        unchecked {
            --blockId;
        }

        if (_statsB.lastVerifiedBlockId != blockId) {
            _statsB.lastVerifiedBlockId = blockId;

            blk = state.blocks[_statsB.lastVerifiedBlockId % _config.blockRingBufferSize];
            blk.verifiedTransitionId = verifiedTransitionId;
            emit BlockVerifiedV3(_statsB.lastVerifiedBlockId, verifiedBlockHash);
        }

        if (synced.blockId != 0) {
            state.statsA.lastSyncedBlockId = synced.blockId;
            state.statsA.lastSyncedAt = uint64(block.timestamp);

            // We write the synced block's verifiedTransitionId to storage
            if (synced.blockId != _statsB.lastVerifiedBlockId) {
                blk = state.blocks[synced.blockId % _config.blockRingBufferSize];
                blk.verifiedTransitionId = synced.tid;
            }

            // Ask signal service to write cross chain signal
            ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false)).syncChainData(
                _config.chainId, LibStrings.H_STATE_ROOT, synced.blockId, synced.stateRoot
            );

            emit BlockSyncedV3(synced.blockId, synced.stateRoot);
        }

        emit StateVariablesUpdated(_statsB);
        state.statsB = _statsB;
    }

    function _debitBond(address _user, uint256 _amount) private {
        if (_amount == 0) return;

        uint256 balance = state.bondBalance[_user];
        if (balance >= _amount) {
            unchecked {
                state.bondBalance[_user] = balance - _amount;
            }
        } else {
            // Note that the following function call will revert if bond asset is Ether.
            _handleDeposit(_user, _amount);
        }
        emit BondDebited(_user, 0, _amount);
    }

    function _creditBond(address _user, uint256 _amount) private {
        if (_amount == 0) return;
        unchecked {
            state.bondBalance[_user] += _amount;
        }
        emit BondCredited(_user, 0, _amount);
    }

    function _handleDeposit(address _user, uint256 _amount) private {
        address bond = bondToken();

        if (bond != address(0)) {
            require(msg.value == 0, "InvalidMsgValue");
            IERC20(bond).transferFrom(_user, address(this), _amount);
        } else {
            require(msg.value == _amount, "EtherNotPaidAsBond");
        }
        emit BondDeposited(_user, _amount);
    }

    function _validateBlockParams(
        bytes calldata _blockParam,
        uint64 _maxAnchorHeightOffset,
        TransientParentBlock memory _parent
    )
        private
        view
        returns (BlockParamsV3 memory params_)
    {
        if (_blockParam.length != 0) {
            params_ = abi.decode(_blockParam, (BlockParamsV3));
        }

        if (params_.anchorBlockId == 0) {
            params_.anchorBlockId = uint64(block.number - 1);
        } else {
            require(params_.anchorBlockId + _maxAnchorHeightOffset >= block.number, "AnchorBlockId");
            require(params_.anchorBlockId < block.number, "AnchorBlockId");
            require(params_.anchorBlockId >= _parent.anchorBlockId, "AnchorBlockId");
        }

        if (params_.timestamp == 0) {
            params_.timestamp = uint64(block.timestamp);
        } else {
            // Verify the provided timestamp to anchor. Note that params_.anchorBlockId
            // and params_.timestamp may not correspond to the same L1 block.
            require(
                params_.timestamp + _maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                    >= block.timestamp,
                "InvalidTimestamp"
            );
            require(params_.timestamp <= block.timestamp, "InvalidTimestamp");
            require(params_.timestamp >= _parent.timestamp, "InvalidTimestamp");
        }

        // Check if parent block has the right meta hash. This is to allow the proposer to
        // make sure the block builds on the expected latest chain state.
        require(
            params_.parentMetaHash == 0 || params_.parentMetaHash == _parent.metaHash,
            "ParentMetaHashMismatch"
        );
    }

    function _checkProposer(address _customProposer) private view returns (address) {
        if (_customProposer == address(0)) return msg.sender;

        address preconfTaskManager = resolve(LibStrings.B_PRECONF_TASK_MANAGER, true);
        require(preconfTaskManager != address(0), "CustomProposerNotAllowed");
        require(preconfTaskManager == msg.sender, "MsgSenderNotPreconfTaskManager");
        return _customProposer;
    }

    function _getBlockInfo(uint64 _blockId)
        private
        view
        returns (bytes32 blockHash_, bytes32 stateRoot_)
    {
        ConfigV3 memory config = getConfigV3();

        uint64 slot = _blockId % config.blockRingBufferSize;
        BlockV3 storage blk = state.blocks[slot];
        require(blk.blockId == _blockId, "BlockNotFound");

        if (blk.verifiedTransitionId != 0) {
            TransitionV3 storage ts = state.transitions[slot][blk.verifiedTransitionId];
            blockHash_ = ts.blockHash;
            stateRoot_ = ts.stateRoot;
        }
    }

    function _isSyncBlock(
        uint256 _stateRootSyncInternal,
        uint256 _blockId
    )
        private
        pure
        returns (bool)
    {
        return _stateRootSyncInternal == 0 || _blockId % _stateRootSyncInternal == 0;
    }
}
