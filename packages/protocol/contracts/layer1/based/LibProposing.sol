// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibBonds.sol";
import "./LibUtils.sol";
import "./LibVerifying.sol";
import "./TaikoEvents.sol";

/// @title LibProposing
/// @notice A library that offers helper functions for block proposals.
/// @custom:security-contact security@taiko.xyz
library LibProposing {
    using LibAddress for address;

    uint256 internal constant SECONDS_PER_BLOCK = 12;

    struct Local {
        TaikoData.SlotB slotB;
        TaikoData.BlockParamsV3 params;
        ITierProvider tierProvider;
        bool allowCustomProposer;
        address preconfTaskManager;
        uint64 parentTimestamp;
        uint64 parentAnchorBlockId;
        bytes32 parentMetaHash;
    }

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
    /// @return metas_ An array of metadata objects for the proposed L2 blocks (version 2).
    function proposeBlocks(
        TaikoData.State storage _state,
        TaikoData.ConfigV3 memory _config,
        IResolver _resolver,
        bytes[] calldata _paramsArr
    )
        internal
        returns (TaikoData.BlockMetadataV3[] memory metas_)
    {
        Local memory local;
        local.slotB = _state.slotB;

        unchecked {
            local.preconfTaskManager =
                _resolver.resolve(block.chainid, LibStrings.B_PRECONF_TASK_MANAGER, true);

            if (local.preconfTaskManager != address(0)) {
                require(local.preconfTaskManager == msg.sender, L1_INVALID_PROPOSER());
                local.allowCustomProposer = true;
            }

            require(local.slotB.numBlocks >= _config.pacayaForkHeight, L1_FORK_HEIGHT_ERROR());

            require(
                local.slotB.numBlocks + _paramsArr.length
                    <= local.slotB.lastVerifiedBlockId + _config.blockMaxProposals,
                L1_TOO_MANY_BLOCKS()
            );

            // Verify params against the parent block.
            TaikoData.BlockV3 storage parentBlk =
                _state.blocks[(local.slotB.numBlocks - 1) % _config.blockRingBufferSize];

            local.parentTimestamp = parentBlk.timestamp;
            local.parentAnchorBlockId = parentBlk.anchorBlockId;
            local.parentMetaHash = parentBlk.metaHash;
        }

        metas_ = new TaikoData.BlockMetadataV3[](_paramsArr.length);
        for (uint256 i; i < _paramsArr.length; ++i) {
            if (_paramsArr[i].length != 0) {
                local.params = abi.decode(_paramsArr[i], (TaikoData.BlockParamsV3));
            }

            unchecked {
                if (local.params.proposer == address(0)) {
                    local.params.proposer = msg.sender;
                } else {
                    require(
                        local.params.proposer == msg.sender || local.allowCustomProposer,
                        L1_INVALID_CUSTOM_PROPOSER()
                    );
                }

                if (local.params.anchorBlockId == 0) {
                    local.params.anchorBlockId = uint64(block.number - 1);
                } else {
                    require(
                        local.params.anchorBlockId + _config.maxAnchorHeightOffset >= block.number
                            && local.params.anchorBlockId < block.number
                            && local.params.anchorBlockId >= local.parentAnchorBlockId,
                        L1_INVALID_ANCHOR_BLOCK()
                    );
                }

                if (local.params.timestamp == 0) {
                    local.params.timestamp = uint64(block.timestamp);
                } else {
                    // Verify the provided timestamp to anchor. Note that local.params.anchorBlockId
                    // and
                    // local.params.timestamp may not correspond to the same L1 block.
                    require(
                        local.params.timestamp + _config.maxAnchorHeightOffset * SECONDS_PER_BLOCK
                            >= block.timestamp && local.params.timestamp <= block.timestamp
                            && local.params.timestamp >= local.parentTimestamp,
                        L1_INVALID_TIMESTAMP()
                    );
                }

                // Check if parent block has the right meta hash. This is to allow the proposer to
                // make sure the block builds on the expected latest chain state.
                require(
                    local.params.parentMetaHash == 0
                        || local.params.parentMetaHash == local.parentMetaHash,
                    L1_UNEXPECTED_PARENT()
                );

                if (local.params.coinbase == address(0)) {
                    local.params.coinbase = local.params.proposer;
                }
            }

            // Initialize metadata to compute a metaHash, which forms a part of the block data to be
            // stored on-chain for future integrity checks. If we choose to persist all data fields
            // in
            // the metadata, it will require additional storage slots.
            metas_[i] = TaikoData.BlockMetadataV3({
                anchorBlockHash: blockhash(local.params.anchorBlockId),
                difficulty: keccak256(abi.encode("TAIKO_DIFFICULTY", local.slotB.numBlocks)),
                blobHash: 0, // to be initialized below
                // Encode _config.baseFeeConfig into extraData to allow L2 block execution without
                // metadata. Metadata might be unavailable until the block is proposed on-chain. In
                // preconfirmation scenarios, multiple blocks may be built but not yet proposed,
                // making
                // metadata unavailable.
                extraData: bytes32(uint256(_config.baseFeeConfig.sharingPctg)),
                // outside
                // and compute only once.
                coinbase: local.params.coinbase,
                id: local.slotB.numBlocks,
                gasLimit: _config.blockMaxGasLimit,
                timestamp: local.params.timestamp,
                anchorBlockId: local.params.anchorBlockId,
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
            require(LibNetwork.isDencunSupported(block.chainid), L1_BLOB_NOT_AVAILABLE());
            metas_[i].blobHash = blobhash(local.params.blobIndex);
            require(metas_[i].blobHash != 0, L1_BLOB_NOT_FOUND());

            local.tierProvider =
                ITierProvider(_resolver.resolve(block.chainid, LibStrings.B_TIER_PROVIDER, false));

            local.parentTimestamp = local.params.timestamp;
            local.parentAnchorBlockId = local.params.anchorBlockId;
            local.parentMetaHash = keccak256(abi.encode(metas_[i]));

            // Use a storage pointer for the block in the ring buffer
            TaikoData.BlockV3 storage blk =
                _state.blocks[local.slotB.numBlocks % _config.blockRingBufferSize];

            // Store each field of the block separately
            // SSTORE #1 {{
            blk.metaHash = local.parentMetaHash;
            // SSTORE #1 }}

            // SSTORE #2 {{
            blk.blockId = local.slotB.numBlocks;
            blk.timestamp = local.params.timestamp;
            blk.anchorBlockId = local.params.anchorBlockId;
            blk.nextTransitionId = 1;
            blk.livenessBondReturned = false;
            blk.verifiedTransitionId = 0;
            // SSTORE #2 }}

            unchecked {
                // Increment the counter (cursor) by 1.
                local.slotB.numBlocks += 1;
                local.slotB.lastProposedIn = uint56(block.number);
            }
            // SSTORE #3 {{
            _state.slotB = local.slotB;
            // SSTORE #3 }}

            // SSTORE #4 {{
            LibBonds.debitBond(
                _state, _resolver, local.params.proposer, metas_[i].id, _config.livenessBond
            );
            // SSTORE #4 }}

            emit TaikoEvents.BlockProposedV3(metas_[i].id, metas_[i]);
        }

        if (!local.slotB.provingPaused) {
            for (uint256 i; i < _paramsArr.length; ++i) {
                if (LibUtils.shouldVerifyBlocks(_config, metas_[i].id, false)) {
                    LibVerifying.verifyBlocks(_state, _config, _resolver, _config.maxBlocksToVerify);
                }
            }
        }
    }
}
