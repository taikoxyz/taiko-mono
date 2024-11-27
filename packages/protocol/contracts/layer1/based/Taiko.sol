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
import "./ITaiko.sol";

/// @title Taiko
/// @notice This contract serves as the "base layer contract" of the Taiko protocol, providing
/// functionalities for proposing, proving, and verifying blocks. The term "base layer contract"
/// means that although this is usually deployed on L1, it can also be deployed on L2s to create
/// L3s. The contract also handles the deposit and withdrawal of Taiko tokens and Ether.
/// Additionally, this contract doesn't hold any Ether. Ether deposited to L2 are held by the Bridge
/// contract.
/// @dev Labeled in AddressResolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract Taiko is EssentialContract, ITaiko {
    using LibMath for uint256;

    State public state;

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

    function proposeBlocksV3(
        address _proposer,
        address _coinbase,
        BlockParamsV3[] calldata _paramss
    )
        external
        nonReentrant
        returns (BlockMetadataV3[] memory metas_)
    {
        require(_paramss.length != 0, "NoBlocksToPropose");

        Stats2 memory stats2 = state.stats2;
        require(stats2.paused == false, "ContractPaused");

        ConfigV3 memory config = getConfigV3();
        require(stats2.numBlocks >= config.pacayaForkHeight, "InvalidForkHeight");

        require(
            stats2.numBlocks + _paramss.length
                <= stats2.lastVerifiedBlockId + config.blockMaxProposals,
            "TooManyBlocks"
        );

        BlockV3 storage parentBlk =
            state.blocks[(stats2.numBlocks - 1) % config.blockRingBufferSize];

        ParentBlock memory parent = ParentBlock({
            metaHash: parentBlk.metaHash,
            timestamp: parentBlk.timestamp,
            anchorBlockId: parentBlk.anchorBlockId
        });

        if (_proposer == address(0)) {
            _proposer = msg.sender;
        } else {
            address preconfTaskManager = resolve(LibStrings.B_PRECONF_TASK_MANAGER, false);
            require(preconfTaskManager == msg.sender, "MsgSenderNotPreconfTaskManager");
        }

        if (_coinbase == address(0)) {
            _coinbase = _proposer;
        }

        metas_ = new BlockMetadataV3[](_paramss.length);

        for (uint256 i; i < _paramss.length; ++i) {
            UpdatedParams memory updatedParams =
                _validateBlockParams(_paramss[i], config.maxAnchorHeightOffset, parent);

            // Initialize metadata to compute a metaHash, which forms a part of the block data to be
            // stored on-chain for future integrity checks. If we choose to persist all data fields
            // in the metadata, it will require additional storage slots.
            metas_[i] = BlockMetadataV3({
                anchorBlockHash: blockhash(updatedParams.anchorBlockId),
                difficulty: keccak256(abi.encode("TAIKO_DIFFICULTY", stats2.numBlocks)),
                blobHash: blobhash(_paramss[i].blobIndex),
                extraData: bytes32(uint256(config.baseFeeConfig.sharingPctg)),
                coinbase: _coinbase,
                blockId: stats2.numBlocks,
                gasLimit: config.blockMaxGasLimit,
                timestamp: updatedParams.timestamp,
                anchorBlockId: updatedParams.anchorBlockId,
                parentMetaHash: parent.metaHash,
                proposer: _proposer,
                livenessBond: config.livenessBond,
                proposedAt: uint64(block.timestamp),
                proposedIn: uint64(block.number),
                blobTxListOffset: _paramss[i].blobTxListOffset,
                blobTxListLength: _paramss[i].blobTxListLength,
                blobIndex: _paramss[i].blobIndex,
                baseFeeConfig: config.baseFeeConfig
            });

            require(metas_[i].blobHash != 0, "BlobNotFound");
            bytes32 metaHash = keccak256(abi.encode(metas_[i]));

            BlockV3 storage blk = state.blocks[stats2.numBlocks % config.blockRingBufferSize];
            // SSTORE
            blk.metaHash = metaHash;

            // SSTORE {{
            blk.blockId = stats2.numBlocks;
            blk.timestamp = updatedParams.timestamp;
            blk.anchorBlockId = updatedParams.anchorBlockId;
            blk.nextTransitionId = 1;
            blk.verifiedTransitionId = 0;
            // SSTORE }}

            emit BlockProposedV3(metas_[i].blockId, metas_[i]);

            parent.metaHash = metaHash;
            parent.timestamp = updatedParams.timestamp;
            parent.anchorBlockId = updatedParams.anchorBlockId;

            unchecked {
                stats2.numBlocks += 1;
                stats2.lastProposedIn = uint56(block.number);
            }
        } // end of for-loop

        _debitBond(_proposer, config.livenessBond * _paramss.length);
        _verifyBlocks(config, stats2, _paramss.length);
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
        require(stats2.numBlocks >= config.pacayaForkHeight, "InvalidForkHeight");

        IVerifier.Context[] memory ctxs = new IVerifier.Context[](_metas.length);
        for (uint256 i; i < _metas.length; ++i) {
            BlockMetadataV3 calldata meta = _metas[i];

            require(meta.blockId >= config.pacayaForkHeight, "InvalidForkHeight");
            require(meta.blockId < stats2.lastVerifiedBlockId, "BlockVerified");
            require(meta.blockId < stats2.numBlocks, "BlockNotProposed");

            TransitionV3 calldata tran = _transitions[i];
            require(tran.parentHash != 0, "InvalidTransitionParentHash");
            require(tran.blockHash != 0, "InvalidTransitionBlockHash");
            require(tran.stateRoot != 0, "InvalidTransitionStateRoot");

            ctxs[i].blockId = meta.blockId;
            ctxs[i].difficulty = meta.difficulty;
            ctxs[i].metaHash = keccak256(abi.encode(meta));
            ctxs[i].tran = tran;

            uint256 slot = meta.blockId % config.blockRingBufferSize;
            BlockV3 storage blk = state.blocks[slot];
            require(ctxs[i].metaHash == blk.metaHash, "MataMismatch");

            uint24 tid;
            uint24 nextTransitionId = blk.nextTransitionId;
            if (nextTransitionId > 1) {
                if (state.transitions[slot][1].parentHash == tran.parentHash) {
                    tid = 1;
                } else if (nextTransitionId > 2) {
                    tid = state.transitionIds[meta.blockId][tran.parentHash];
                }
            }


            bool isOverwrite = (tid != 0);
            if (tid == 0) {
                tid = blk.nextTransitionId++;
            }

            TransitionV3 storage ts = state.transitions[slot][tid];
            if (isOverwrite) {
                emit TransitionOverwritten(meta.blockId, ts);
            } else if (tid == 1) {
                uint256 deadline =
                    uint256(meta.proposedAt).max(stats2.lastUnpausedAt) + config.provingWindow;
                if (block.timestamp <= deadline) {
                    require(msg.sender == meta.proposer, "ProverNotPermitted");
                    _creditBond(meta.proposer, meta.livenessBond);
                }

                ts.parentHash = tran.parentHash;
            } else {
                state.transitionIds[meta.blockId][tran.parentHash] = tid;
            }

            if (meta.blockId % config.stateRootSyncInternal == 0) {
                ts.stateRoot = tran.stateRoot;
            }

            ts.blockHash = tran.blockHash;
            emit TransitionProved(meta.blockId, tran);
        }

        if (_metas.length != 0) {
            IVerifier(resolve(LibStrings.B_PROOF_VERIFIER, false)).verifyProof(ctxs, proof);
        }

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
        require(_blockId >= config.pacayaForkHeight, "InvalidForkHeight");

        blk_ = state.blocks[_blockId % config.blockRingBufferSize];
        require(blk_.blockId == _blockId, "BlockNotFound");
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
        require(blk.blockId == _blockId, "BlockNotFound");

        if (blk.verifiedTransitionId != 0) {
            tran_ = state.transitions[slot][blk.verifiedTransitionId];
        }
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

    // Internal functions ----------------------------------------------------------------------

    function __Taiko_init(
        address _owner,
        address _rollupResolver,
        bytes32 _genesisBlockHash
    )
        internal
    {
        __Essential_init(_owner, _rollupResolver);

        require(_genesisBlockHash != 0, "InvalidGenesisBlockHash");
        state.transitions[0][1].blockHash = _genesisBlockHash;

        BlockV3 storage blk = state.blocks[0];
        blk.metaHash = bytes32(uint256(1));
        blk.timestamp = uint64(block.timestamp);
        blk.anchorBlockId = uint64(block.number);
        blk.verifiedTransitionId = 1;

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

    // Private functions -----------------------------------------------------------------------

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
                tid = state.transitionIds[blockId][blockHash];
                if (tid == 0) break;
                ts = state.transitions[slot][tid];
            }

            blockHash = ts.blockHash;

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
            blk.verifiedTransitionId = tid;
            emit BlockVerifiedV3(_stats2.lastVerifiedBlockId, blockHash);
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
        BlockParamsV3 calldata _params,
        uint64 _maxAnchorHeightOffset,
        ParentBlock memory _parent
    )
        private
        view
        returns (UpdatedParams memory updatedParams_)
    {
        if (_params.anchorBlockId == 0) {
            updatedParams_.anchorBlockId = uint64(block.number - 1);
        } else {
            require(_params.anchorBlockId + _maxAnchorHeightOffset >= block.number, "AnchorBlockId");
            require(_params.anchorBlockId < block.number, "AnchorBlockId");
            require(_params.anchorBlockId >= _parent.anchorBlockId, "AnchorBlockId");
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
                "TimestampTooSmall"
            );
            require(_params.timestamp <= block.timestamp, "TimestampTooLarge");
            require(_params.timestamp >= _parent.timestamp, "TimestampTooLarge");

            updatedParams_.timestamp = _params.timestamp;
        }

        // Check if parent block has the right meta hash. This is to allow the proposer to
        // make sure the block builds on the expected latest chain state.
        require(
            _params.parentMetaHash == 0 || _params.parentMetaHash == _parent.metaHash,
            "ParentMetaHashMismatch"
        );
    }

    // Memory-only structs ----------------------------------------------------------------------

    struct ParentBlock {
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
