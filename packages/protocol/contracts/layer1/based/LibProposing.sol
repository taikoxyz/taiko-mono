// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibNetwork.sol";
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
        TaikoData.BlockParamsV2 params;
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
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The configuration parameters for the Taiko protocol.
    /// @param _resolver The address resolver.
    /// @param _paramsArr An array of encoded data bytes containing the block parameters.
    /// @param _txListArr An array of transaction list bytes (if not blob).
    /// @return metas_ An array of metadata objects for the proposed L2 blocks (version 2).
    function proposeBlocks(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IResolver _resolver,
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
        TaikoData.SlotB memory slotB;

        for (uint256 i; i < _paramsArr.length; ++i) {
            (metas_[i], slotB) =
                _proposeBlock(_state, _config, _resolver, _paramsArr[i], _txListArr[i]);
        }

        if (!slotB.provingPaused) {
            for (uint256 i; i < _paramsArr.length; ++i) {
                if (LibUtils.shouldVerifyBlocks(_config, metas_[i].id, false)) {
                    LibVerifying.verifyBlocks(_state, _config, _resolver, _config.maxBlocksToVerify);
                }
            }
        }
    }

    /// @dev Proposes a single Taiko L2 block.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The configuration parameters for the Taiko protocol.
    /// @param _resolver The address resolver.
    /// @param _params Encoded data bytes containing the block parameters.
    /// @param _txList Transaction list bytes (if not blob).
    /// @return meta_ The metadata of the proposed block (version 2).
    function proposeBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IResolver _resolver,
        bytes calldata _params,
        bytes calldata _txList
    )
        internal
        returns (TaikoData.BlockMetadataV2 memory meta_)
    {
        TaikoData.SlotB memory slotB;
        (meta_, slotB) = _proposeBlock(_state, _config, _resolver, _params, _txList);

        if (!slotB.provingPaused) {
            if (LibUtils.shouldVerifyBlocks(_config, meta_.id, false)) {
                LibVerifying.verifyBlocks(_state, _config, _resolver, _config.maxBlocksToVerify);
            }
        }
    }

    /// @dev Proposes a single Taiko L2 block.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The configuration parameters for the Taiko protocol.
    /// @param _resolver The address resolver.
    /// @param _params Encoded data bytes containing the block parameters.
    /// @param _txList Transaction list bytes (if not blob).
    /// @return meta_ The metadata of the proposed block (version 2).
    function _proposeBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IResolver _resolver,
        bytes calldata _params,
        bytes calldata _txList
    )
        private
        returns (TaikoData.BlockMetadataV2 memory meta_, TaikoData.SlotB memory slotB)
    {
        // SLOAD #1 {{
        slotB = _state.slotB;
        // SLOAD #1 }}

        // It's essential to ensure that the ring buffer for proposed blocks still has space for at
        // least one more block.
        require(slotB.numBlocks >= _config.ontakeForkHeight, L1_FORK_HEIGHT_ERROR());

        unchecked {
            require(
                slotB.numBlocks < slotB.lastVerifiedBlockId + _config.blockMaxProposals + 1,
                L1_TOO_MANY_BLOCKS()
            );
        }

        address preconfTaskManager =
            _resolver.resolve(block.chainid, LibStrings.B_PRECONF_TASK_MANAGER, true);

        Local memory local;

        if (preconfTaskManager != address(0)) {
            require(preconfTaskManager == msg.sender, L1_INVALID_PROPOSER());
            local.allowCustomProposer = true;
        }

        if (_params.length != 0) {
            local.params = abi.decode(_params, (TaikoData.BlockParamsV2));
        }

        _validateParams(_state, _config, slotB, local);

        // Initialize metadata to compute a metaHash, which forms a part of the block data to be
        // stored on-chain for future integrity checks. If we choose to persist all data fields in
        // the metadata, it will require additional storage slots.
        meta_ = TaikoData.BlockMetadataV2({
            anchorBlockHash: blockhash(local.params.anchorBlockId),
            difficulty: keccak256(abi.encode("TAIKO_DIFFICULTY", slotB.numBlocks)),
            blobHash: 0, // to be initialized below
            // Encode _config.baseFeeConfig into extraData to allow L2 block execution without
            // metadata. Metadata might be unavailable until the block is proposed on-chain. In
            // preconfirmation scenarios, multiple blocks may be built but not yet proposed, making
            // metadata unavailable.
            extraData: _encodeBaseFeeConfig(_config.baseFeeConfig), // TODO(daniel):remove outside and compute only once.
            coinbase: local.params.coinbase,
            id: slotB.numBlocks,
            gasLimit: _config.blockMaxGasLimit,
            timestamp: local.params.timestamp,
            anchorBlockId: local.params.anchorBlockId,
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

        // Use a storage pointer for the block in the ring buffer
        TaikoData.BlockV2 storage blk = _state.blocks[slotB.numBlocks % _config.blockRingBufferSize];

        // Store each field of the block separately
        // SSTORE #1 {{
        blk.metaHash = keccak256(abi.encode(meta_));
        // SSTORE #1 }}

        // SSTORE #2 {{
        blk.blockId = slotB.numBlocks;
        blk.proposedAt = local.params.timestamp;
        blk.proposedIn = local.params.anchorBlockId;
        blk.nextTransitionId = 1;
        blk.livenessBondReturned = false;
        blk.verifiedTransitionId = 0;
        // SSTORE #2 }}

        unchecked {
            // Increment the counter (cursor) by 1.
            slotB.numBlocks += 1;
            slotB.lastProposedIn = uint56(block.number);

            // SSTORE #3 {{
            _state.slotB = slotB; // TODO(daniel): save this only once.
            // SSTORE #3 }}
        }

        // SSTORE #4 {{
        LibBonds.debitBond(_state, _resolver, local.params.proposer, meta_.id, _config.livenessBond);
        // SSTORE #4 }}

        emit BlockProposedV2(meta_.id, meta_);
    }

    /// @dev Validates the parameters for proposing a block.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The configuration parameters for the Taiko protocol.
    /// @param _slotB The SlotB struct.
    /// @param _local The local struct.
    function _validateParams(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        TaikoData.SlotB memory _slotB,
        Local memory _local
    )
        private
        view
    {
        unchecked {
            if (_local.params.proposer == address(0)) {
                _local.params.proposer = msg.sender;
            } else {
                require(
                    _local.params.proposer == msg.sender || _local.allowCustomProposer,
                    L1_INVALID_CUSTOM_PROPOSER()
                );
            }

            if (_local.params.coinbase == address(0)) {
                _local.params.coinbase = _local.params.proposer;
            }

            if (_local.params.anchorBlockId == 0) {
                _local.params.anchorBlockId = uint64(block.number - 1);
            }

            if (_local.params.timestamp == 0) {
                _local.params.timestamp = uint64(block.timestamp);
            }
        }

        // Verify params against the parent block.
        TaikoData.BlockV2 storage parentBlk;
        unchecked {
            parentBlk = _state.blocks[(_slotB.numBlocks - 1) % _config.blockRingBufferSize];
        }

        // Verify the passed in L1 state block number to anchor.
        require(
            _local.params.anchorBlockId + _config.maxAnchorHeightOffset >= block.number,
            L1_INVALID_ANCHOR_BLOCK()
        );
        require(_local.params.anchorBlockId < block.number, L1_INVALID_ANCHOR_BLOCK());

        // parentBlk.proposedIn is actually parent's params.anchorBlockId
        require(_local.params.anchorBlockId >= parentBlk.proposedIn, L1_INVALID_ANCHOR_BLOCK());

        // Verify the provided timestamp to anchor. Note that local.params.anchorBlockId and
        // local.params.timestamp may not correspond to the same L1 block.
        require(
            _local.params.timestamp + _config.maxAnchorHeightOffset * SECONDS_PER_BLOCK
                >= block.timestamp,
            L1_INVALID_TIMESTAMP()
        );
        require(_local.params.timestamp <= block.timestamp, L1_INVALID_TIMESTAMP());

        // parentBlk.proposedAt is actually parent's params.timestamp
        require(_local.params.timestamp >= parentBlk.proposedAt, L1_INVALID_TIMESTAMP());

        // Check if parent block has the right meta hash. This is to allow the proposer to make sure
        // the block builds on the expected latest chain state.
        require(
            _local.params.parentMetaHash == 0 || _local.params.parentMetaHash == parentBlk.metaHash,
            L1_UNEXPECTED_PARENT()
        );
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
