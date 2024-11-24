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

        Stats2 memory stats2 = state.stats2;
        require(stats2.paused == false, "ContractPaused");

        ConfigV3 memory config = getConfigV3();
        require(stats2.numBlocks >= config.pacayaForkHeight, "InvalidForkHeight");
        require(
            stats2.numBlocks + _blockParams.length
                <= stats2.lastVerifiedBlockId + config.blockMaxProposals,
            "TooManyBlocks"
        );

        TransientParentBlock memory parent;
        {
            BlockV3 storage parentBlk =
                state.blocks[(stats2.numBlocks - 1) % config.blockRingBufferSize];
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
                _proposeBlock(config, stats2, params, _proposer, _coinbase);

            parent.timestamp = params.timestamp;
            parent.anchorBlockId = params.anchorBlockId;

            unchecked {
                stats2.numBlocks += 1;
                stats2.lastProposedIn = uint56(block.number);
            }
        } // end of for-loop

        _debitBond(_proposer, config.livenessBond * _blockParams.length);
        _verifyBlocks(config, stats2, _blockParams.length);
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

        Stats2 memory stats2 = state.stats2;
        require(stats2.paused == false, "ContractPaused");

        ConfigV3 memory config = getConfigV3();
        IVerifier.ContextV3[] memory ctxs = new IVerifier.ContextV3[](_metas.length);
        for (uint256 i; i < _metas.length; ++i) {
            ctxs[i] = _proveBlock(config, stats2, _metas[i], _transitions[i]);
        }

        IVerifier(resolve("TODO", false)).verifyProofV3(ctxs, proof);

        _verifyBlocks(config, stats2, _metas.length);
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

    function getLastVerifiedBlockV3()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_)
    {
        blockId_ = state.stats2.lastVerifiedBlockId;
        (blockHash_, stateRoot_) = _getBlockInfo(blockId_);
    }

    function getLastSyncedBlockV3()
        external
        view
        returns (uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_)
    {
        blockId_ = state.stats1.lastSyncedBlockId;
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
        return state.stats2.paused;
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
        state.stats1.genesisHeight = uint64(block.number);
        state.stats1.genesisTimestamp = uint64(block.timestamp);
        state.stats2.numBlocks = 1;

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
        state.stats2.lastUnpausedAt = uint64(block.timestamp);
        state.stats2.paused = false;
    }

    function _pause() internal override {
        state.stats2.paused = true;
    }

    // Private functions
    // ------------------------------------------------------------------------------------------

    function _proposeBlock(
        ConfigV3 memory _config,
        Stats2 memory _stats2,
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
            difficulty: keccak256(abi.encode("TAIKO_DIFFICULTY", _stats2.numBlocks)),
            blobHash: blobhash(_params.blobIndex),
            extraData: bytes32(uint256(_config.baseFeeConfig.sharingPctg)),
            coinbase: _coinbase,
            blockId: _stats2.numBlocks,
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
        BlockV3 storage blk = state.blocks[_stats2.numBlocks % _config.blockRingBufferSize];

        metaHash_ = keccak256(abi.encode(meta_));
        // SSTORE
        blk.metaHash = metaHash_;

        // SSTORE {{
        blk.blockId = _stats2.numBlocks;
        blk.timestamp = _params.timestamp;
        blk.anchorBlockId = _params.anchorBlockId;
        blk.nextTransitionId = 1;
        blk.verifiedTransitionId = 0;
        // SSTORE }}

        emit BlockProposedV3(meta_.blockId, meta_);
    }

    function _proveBlock(
        ConfigV3 memory _config,
        Stats2 memory _stats2,
        BlockMetadataV3 calldata _meta,
        TransitionV3 calldata _tran
    )
        private
        returns (IVerifier.ContextV3 memory ctx_)
    {
        require(_meta.blockId >= _config.pacayaForkHeight, "InvalidForkHeight");
        require(_meta.blockId < _stats2.lastVerifiedBlockId, "BlockVerified");
        require(_meta.blockId < _stats2.numBlocks, "BlockNotProposed");

        require(_tran.parentHash != 0, "InvalidTransitionParentHash");
        require(_tran.blockHash != 0, "InvalidTransitionBlockHash");
        require(_tran.stateRoot != 0, "InvalidTransitionStateRoot");

        ctx_.metaHash = keccak256(abi.encode(_meta));
        ctx_.difficulty = _meta.difficulty;
        ctx_.tran = _tran;

        uint256 slot = _meta.blockId % _config.blockRingBufferSize;
        BlockV3 storage blk = state.blocks[slot];
        require(ctx_.metaHash == blk.metaHash, "MataMismatch");

        TransitionV3 storage ts = state.transitions[slot][1];
        require(ts.parentHash != _tran.parentHash, "AlreadyProvenAsFirstTransition");
        require(state.transitionIds[_meta.blockId][_tran.parentHash] == 0, "AlreadyProven");

        uint24 tid = blk.nextTransitionId++;
        ts = state.transitions[slot][tid];

        // Checks if only the assigned prover is permissioned to prove the block. The assigned
        // prover is granted exclusive permission to prove only the first transition.
        if (tid == 1) {
            if (msg.sender == _meta.proposer) {
                _creditBond(_meta.proposer, _meta.livenessBond);
            } else {
                uint256 deadline = uint256(_meta.proposedAt).max(_stats2.lastUnpausedAt);
                deadline += _config.provingWindow;
                require(block.timestamp >= deadline, "ProvingWindowNotPassed");
            }
            ts.parentHash = _tran.parentHash;
        } else {
            state.transitionIds[_meta.blockId][_tran.parentHash] = tid;
        }

        ts.blockHash = _tran.blockHash;

        if (_meta.blockId % _config.stateRootSyncInternal == 0) {
            ts.stateRoot = _tran.stateRoot;
        }

        emit BlockProvedV3(_meta.blockId, _tran);
    }

    function _verifyBlocks(
        ConfigV3 memory _config,
        Stats2 memory _stats2,
        uint256 _length
    )
        private
    {
        uint64 blockId = _stats2.lastVerifiedBlockId;
        uint256 slot = blockId % _config.blockRingBufferSize;
        BlockV3 storage blk = state.blocks[slot];
        uint24 verifiedTransitionId = blk.verifiedTransitionId;
        bytes32 verifiedBlockHash = state.transitions[slot][verifiedTransitionId].blockHash;

        TransientSyncedBlock memory synced;

        uint256 stopBlockId = (_config.maxBlocksToVerify * _length + _stats2.lastVerifiedBlockId)
            .min(_stats2.numBlocks);

        for (++blockId; blockId <= stopBlockId; ++blockId) {
            slot = blockId % _config.blockRingBufferSize;
            blk = state.blocks[slot];
            // TODO(daniel): get Tid;
            uint24 tid;

            if (tid == 0) break;
            TransitionV3 storage ts = state.transitions[slot][tid];

            verifiedBlockHash = ts.blockHash;
            verifiedTransitionId = tid;

            if (blockId % _config.stateRootSyncInternal == 0) {
                synced.blockId = blockId;
                synced.tid = tid;
                synced.stateRoot = ts.stateRoot;
            }
        }

        unchecked {
            --blockId;
        }

        if (_stats2.lastVerifiedBlockId != blockId) {
            _stats2.lastVerifiedBlockId = blockId;

            blk = state.blocks[_stats2.lastVerifiedBlockId % _config.blockRingBufferSize];
            blk.verifiedTransitionId = verifiedTransitionId;
            emit BlockVerifiedV3(_stats2.lastVerifiedBlockId, verifiedBlockHash);
        }

        if (synced.blockId != 0) {
            Stats1 memory stats1 = state.stats1;
            stats1.lastSyncedBlockId = synced.blockId;
            stats1.lastSyncedAt = uint64(block.timestamp);
            state.stats1 = stats1;

            emit Stats1Updated(stats1);

            // We write the synced block's verifiedTransitionId to storage
            if (synced.blockId != _stats2.lastVerifiedBlockId) {
                blk = state.blocks[synced.blockId % _config.blockRingBufferSize];
                blk.verifiedTransitionId = synced.tid;
            }

            // Ask signal service to write cross chain signal
            ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false)).syncChainData(
                _config.chainId, LibStrings.H_STATE_ROOT, synced.blockId, synced.stateRoot
            );

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

    function _checkProposer(address _customProposer) private view returns (address) {
        if (_customProposer == address(0)) return msg.sender;

        address preconfTaskManager = resolve(LibStrings.B_PRECONF_TASK_MANAGER, true);
        require(preconfTaskManager != address(0), "CustomProposerNotAllowed");
        require(preconfTaskManager == msg.sender, "MsgSenderNotPreconfTaskManager");
        return _customProposer;
    }
}
