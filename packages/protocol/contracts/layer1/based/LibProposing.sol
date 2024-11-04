// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/LibAddress.sol";
import "src/shared/common/LibNetwork.sol";
import "./LibBonds.sol";
import "./LibData.sol";
import "./LibUtils.sol";
import "./LibVerifying.sol";

/// @title LibProposing
/// @notice A library that offers helper functions for block proposals.
/// @custom:security-contact security@taiko.xyz
library LibProposing {
    using LibAddress for address;

    uint256 internal constant SECONDS_PER_BLOCK = 12;

    struct Local {
        TaikoData.SlotB b;
        TaikoData.BlockParamsV2 params;
        ITierProvider tierProvider;
        bytes32 parentMetaHash;
        bool allowCustomProposer;
    }

    /// @dev Emitted when a block is proposed.
    /// @param blockId The ID of the proposed block.
    /// @param meta The metadata of the proposed block.
    event BlockProposedV2(uint256 indexed blockId, TaikoData.BlockMetadataV2 meta);

    /// @dev Emitted when a block's txList is in the calldata.
    /// @param blockId The ID of the proposed block.
    /// @param txList The txList.
    event CalldataTxList(uint256 indexed blockId, bytes txList);

    error L1_BLOB_NOT_AVAILABLE();
    error L1_BLOB_NOT_FOUND();
    error L1_FORK_HEIGHT_ERROR();
    error L1_INVALID_ANCHOR_BLOCK();
    error L1_INVALID_CUSTOM_PROPOSER();
    error L1_INVALID_PARAMS();
    error L1_INVALID_PROPOSER();
    error L1_INVALID_TIMESTAMP();
    error L1_TOO_MANY_BLOCKS();
    error L1_UNEXPECTED_PARENT();

    /// @dev Proposes multiple Taiko L2 blocks.
    /// @param _state The current state of the Taiko protocol.
    /// @param _config The configuration parameters for the Taiko protocol.
    /// @param _resolver The address resolver interface.
    /// @param _paramsArr An array of encoded data bytes containing the block parameters.
    /// @param _txListArr An array of transaction list bytes (if not blob).
    /// @return metas_ An array of metadata objects for the proposed L2 blocks (version 2).
    function proposeBlocks(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        internal
        returns (TaikoData.BlockMetadataV2[] memory metas_)
    {
        if (_paramsArr.length == 0 || _paramsArr.length != _txListArr.length) {
            revert L1_INVALID_PARAMS();
        }

        metas_ = new TaikoData.BlockMetadataV2[](_paramsArr.length);

        for (uint256 i; i < _paramsArr.length; ++i) {
            metas_[i] = _proposeBlock(_state, _config, _resolver, _paramsArr[i], _txListArr[i]);
        }

        if (!_state.slotB.provingPaused) {
            for (uint256 i; i < _paramsArr.length; ++i) {
                if (LibUtils.shouldVerifyBlocks(_config, metas_[i].id, false)) {
                    LibVerifying.verifyBlocks(_state, _config, _resolver, _config.maxBlocksToVerify);
                }
            }
        }
    }

    /// @dev Proposes a single Taiko L2 block.
    /// @param _state The current state of the Taiko protocol.
    /// @param _config The configuration parameters for the Taiko protocol.
    /// @param _resolver The address resolver interface.
    /// @param _params Encoded data bytes containing the block parameters.
    /// @param _txList Transaction list bytes (if not blob).
    /// @return meta_ The metadata of the proposed block (version 2).
    function proposeBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        bytes calldata _params,
        bytes calldata _txList
    )
        internal
        returns (TaikoData.BlockMetadataV2 memory meta_)
    {
        meta_ = _proposeBlock(_state, _config, _resolver, _params, _txList);

        if (!_state.slotB.provingPaused) {
            if (LibUtils.shouldVerifyBlocks(_config, meta_.id, false)) {
                LibVerifying.verifyBlocks(_state, _config, _resolver, _config.maxBlocksToVerify);
            }
        }
    }

    /// @dev Proposes a single Taiko L2 block.
    /// @param _state The current state of the Taiko protocol.
    /// @param _config The configuration parameters for the Taiko protocol.
    /// @param _resolver The address resolver interface.
    /// @param _params Encoded data bytes containing the block parameters.
    /// @param _txList Transaction list bytes (if not blob).
    /// @return meta_ The metadata of the proposed block (version 2).
    function _proposeBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        bytes calldata _params,
        bytes calldata _txList
    )
        private
        returns (TaikoData.BlockMetadataV2 memory meta_)
    {
        // Checks proposer access.
        Local memory local;
        local.b = _state.slotB;

        // It's essential to ensure that the ring buffer for proposed blocks still has space for at
        // least one more block.
        require(local.b.numBlocks >= _config.ontakeForkHeight, L1_FORK_HEIGHT_ERROR());

        unchecked {
            require(
                local.b.numBlocks < local.b.lastVerifiedBlockId + _config.blockMaxProposals + 1,
                L1_TOO_MANY_BLOCKS()
            );
        }

        address preconfTaskManager = _resolver.resolve(LibStrings.B_PRECONF_TASK_MANAGER, true);
        if (preconfTaskManager != address(0)) {
            require(preconfTaskManager == msg.sender, L1_INVALID_PROPOSER());
            local.allowCustomProposer = true;
        }

        if (_params.length != 0) {
            local.params = abi.decode(_params, (TaikoData.BlockParamsV2));
        }

        if (local.params.proposer == address(0)) {
            local.params.proposer = msg.sender;
        } else {
            require(
                local.params.proposer == msg.sender || local.allowCustomProposer,
                L1_INVALID_CUSTOM_PROPOSER()
            );
        }

        if (local.params.coinbase == address(0)) {
            local.params.coinbase = local.params.proposer;
        }

        if (local.params.anchorBlockId == 0) {
            unchecked {
                local.params.anchorBlockId = uint64(block.number - 1);
            }
        }

        if (local.params.timestamp == 0) {
            local.params.timestamp = uint64(block.timestamp);
        }

        // Verify params against the parent block.
        TaikoData.BlockV2 storage parentBlk;
        unchecked {
            parentBlk = _state.blocks[(local.b.numBlocks - 1) % _config.blockRingBufferSize];
        }

        // Verify the passed in L1 state block number to anchor.
        require(
            local.params.anchorBlockId + _config.maxAnchorHeightOffset >= block.number,
            L1_INVALID_ANCHOR_BLOCK()
        );
        require(local.params.anchorBlockId < block.number, L1_INVALID_ANCHOR_BLOCK());

        // parentBlk.proposedIn is actually parent's params.anchorBlockId
        require(local.params.anchorBlockId >= parentBlk.proposedIn, L1_INVALID_ANCHOR_BLOCK());

        // Verify the provided timestamp to anchor. Note that local.params.anchorBlockId and
        // local.params.timestamp may not correspond to the same L1 block.
        require(
            local.params.timestamp + _config.maxAnchorHeightOffset * SECONDS_PER_BLOCK
                >= block.timestamp,
            L1_INVALID_TIMESTAMP()
        );
        require(local.params.timestamp <= block.timestamp, L1_INVALID_TIMESTAMP());

        // parentBlk.proposedAt is actually parent's params.timestamp
        require(local.params.timestamp >= parentBlk.proposedAt, L1_INVALID_TIMESTAMP());

        // Check if parent block has the right meta hash. This is to allow the proposer to make sure
        // the block builds on the expected latest chain state.
        if (local.params.parentMetaHash == 0) {
            local.params.parentMetaHash = parentBlk.metaHash;
        } else {
            require(local.params.parentMetaHash == parentBlk.metaHash, L1_UNEXPECTED_PARENT());
        }

        // Initialize metadata to compute a metaHash, which forms a part of the block data to be
        // stored on-chain for future integrity checks. If we choose to persist all data fields in
        // the metadata, it will require additional storage slots.
        meta_ = TaikoData.BlockMetadataV2({
            anchorBlockHash: blockhash(local.params.anchorBlockId),
            difficulty: keccak256(abi.encode("TAIKO_DIFFICULTY", local.b.numBlocks)),
            blobHash: 0, // to be initialized below
            // Encode _config.baseFeeConfig into extraData to allow L2 block execution without
            // metadata. Metadata might be unavailable until the block is proposed on-chain. In
            // preconfirmation scenarios, multiple blocks may be built but not yet proposed, making
            // metadata unavailable.
            extraData: _encodeBaseFeeConfig(_config.baseFeeConfig),
            coinbase: local.params.coinbase,
            id: local.b.numBlocks,
            gasLimit: _config.blockMaxGasLimit,
            timestamp: local.params.timestamp,
            anchorBlockId: local.params.anchorBlockId,
            minTier: 0, // to be initialized below
            blobUsed: _txList.length == 0,
            parentMetaHash: local.params.parentMetaHash,
            proposer: local.params.proposer,
            livenessBond: _config.livenessBond,
            proposedAt: uint64(block.timestamp),
            proposedIn: uint64(block.number),
            blobTxListOffset: local.params.blobTxListOffset,
            blobTxListLength: local.params.blobTxListLength,
            blobIndex: local.params.blobIndex,
            baseFeeConfig: _config.baseFeeConfig
        });

        // Update certain meta fields
        if (meta_.blobUsed) {
            require(LibNetwork.isDencunSupported(block.chainid), L1_BLOB_NOT_AVAILABLE());
            meta_.blobHash = blobhash(local.params.blobIndex);
            require(meta_.blobHash != 0, L1_BLOB_NOT_FOUND());
        } else {
            meta_.blobHash = keccak256(_txList);
            emit CalldataTxList(meta_.id, _txList);
        }

        local.tierProvider = ITierProvider(
            ITierRouter(_resolver.resolve(LibStrings.B_TIER_ROUTER, false)).getProvider(
                local.b.numBlocks
            )
        );

        // Use the difficulty as a random number
        meta_.minTier = local.tierProvider.getMinTier(meta_.proposer, uint256(meta_.difficulty));

        // Create the block that will be stored onchain
        TaikoData.BlockV2 memory blk = TaikoData.BlockV2({
            metaHash: keccak256(abi.encode(meta_)),
            assignedProver: address(0),
            livenessBond: 0,
            blockId: local.b.numBlocks,
            proposedAt: local.params.timestamp, // = params.timestamp post Ontake
            proposedIn: local.params.anchorBlockId, // = params.anchorBlockId post Ontake
            nextTransitionId: 1, // For a new block, the next transition ID is always 1, not 0.
            livenessBondReturned: false,
            // For unverified block, its verifiedTransitionId is always 0.
            verifiedTransitionId: 0
        });

        // Store the block in the ring buffer
        _state.blocks[local.b.numBlocks % _config.blockRingBufferSize] = blk;

        // Increment the counter (cursor) by 1.
        unchecked {
            ++_state.slotB.numBlocks;
        }
        _state.slotB.lastProposedIn = uint56(block.number);

        LibBonds.debitBond(_state, _resolver, local.params.proposer, meta_.id, _config.livenessBond);

        emit BlockProposedV2(meta_.id, meta_);
    }

    /// @dev Encodes the base fee configuration into a bytes32.
    /// @param _baseFeeConfig The base fee configuration.
    /// @return The encoded base fee configuration.
    function _encodeBaseFeeConfig(LibSharedData.BaseFeeConfig memory _baseFeeConfig)
        private
        pure
        returns (bytes32)
    {
        return bytes32(uint256(_baseFeeConfig.sharingPctg));
    }
}
