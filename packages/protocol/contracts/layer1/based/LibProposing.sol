// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../shared/common/LibAddress.sol";
import "../../shared/common/LibNetwork.sol";
import "./LibBonds.sol";
import "./LibData.sol";
import "./LibUtils.sol";
import "./LibVerifying.sol";

/// @title LibProposing
/// @notice A library for handling block proposals in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
library LibProposing {
    using LibAddress for address;

    struct Local {
        TaikoData.SlotB b;
        TaikoData.BlockParamsV2 params;
        ITierProvider tierProvider;
        bytes32 parentMetaHash;
        bool allowCustomProposer;
    }


    /// @notice Emitted when a block is proposed.
    /// @param blockId The ID of the proposed block.
    /// @param meta The metadata of the proposed block.
    event BlockProposedV2(uint256 indexed blockId, TaikoData.BlockMetadataV2 meta);

    /// @notice Emitted when a block's txList is in the calldata.
    /// @param blockId The ID of the proposed block.
    /// @param txList The txList.
    event CalldataTxList(uint256 indexed blockId, bytes txList);

    error L1_BLOB_NOT_AVAILABLE();
    error L1_BLOB_NOT_FOUND();
    error L1_INVALID_ANCHOR_BLOCK();
    error L1_INVALID_CUSTOM_PROPOSER();
    error L1_INVALID_PARAMS();
    error L1_INVALID_PROPOSER();
    error L1_INVALID_TIMESTAMP();
    error L1_TOO_MANY_BLOCKS();
    error L1_UNEXPECTED_PARENT();

    /// @notice Proposes multiple Taiko L2 blocks.
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
        public
returns (TaikoData.BlockMetadataV2[] memory metas_)
    {
        if (_paramsArr.length == 0 || _paramsArr.length != _txListArr.length) {
            revert L1_INVALID_PARAMS();
        }

        metas_ = new TaikoData.BlockMetadataV2[](_paramsArr.length);

        for (uint256 i; i < _paramsArr.length; ++i) {
            metas_[i] =
                _proposeBlock(_state, _config, _resolver, _paramsArr[i], _txListArr[i]);
        }

        if (!_state.slotB.provingPaused) {
            for (uint256 i; i < _paramsArr.length; ++i) {
                if (LibUtils.shouldVerifyBlocks(_config, metas_[i].id, false)) {
                    LibVerifying.verifyBlocks(_state, _config, _resolver, _config.maxBlocksToVerify);
                }
            }
        }
    }

    /// @notice Proposes a single Taiko L2 block.
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
        public
        returns (TaikoData.BlockMetadataV2 memory meta_)
    {
        meta_ = _proposeBlock(_state, _config, _resolver, _params, _txList);

        if (!_state.slotB.provingPaused) {
            if (LibUtils.shouldVerifyBlocks(_config, meta_.id, false)) {
                LibVerifying.verifyBlocks(_state, _config, _resolver, _config.maxBlocksToVerify);
            }
        }
    }

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

        // It's essential to ensure that the ring buffer for proposed blocks
        // still has space for at least one more block.
        if (local.b.numBlocks >= local.b.lastVerifiedBlockId + _config.blockMaxProposals + 1) {
            revert L1_TOO_MANY_BLOCKS();
        }

        address permittedProposer = _resolver.resolve(LibStrings.B_BLOCK_PROPOSER, true);
        if (permittedProposer != address(0)) {
            if (permittedProposer != msg.sender) revert L1_INVALID_PROPOSER();
            local.allowCustomProposer = true;
        }

            if (_params.length != 0) {
                local.params = abi.decode(_params, (TaikoData.BlockParamsV2));
            }
    

        if (local.params.proposer == address(0)) {
            local.params.proposer = msg.sender;
        } else {
            if (local.params.proposer != msg.sender && !local.allowCustomProposer) {
                revert L1_INVALID_CUSTOM_PROPOSER();
            }
        }

        if (local.params.coinbase == address(0)) {
            local.params.coinbase = local.params.proposer;
        }

        if ( local.params.anchorBlockId == 0) {
            local.params.anchorBlockId = uint64(block.number - 1);
        }

        if ( local.params.timestamp == 0) {
            local.params.timestamp = uint64(block.timestamp);
        }

        // Verify params against the parent block.
        TaikoData.BlockV2 storage parentBlk =
            _state.blocks[(local.b.numBlocks - 1) % _config.blockRingBufferSize];

            // Verify the passed in L1 state block number.
            // We only allow the L1 block to be 2 epochs old.
            // The other constraint is that the L1 block number needs to be larger than or equal
            // the one in the previous L2 block.
            if (
                local.params.anchorBlockId + _config.maxAnchorHeightOffset < block.number //
                    || local.params.anchorBlockId >= block.number
                    || local.params.anchorBlockId < parentBlk.proposedIn
            ) {
                revert L1_INVALID_ANCHOR_BLOCK();
            }

            // Verify the passed in timestamp.
            // We only allow the timestamp to be 2 epochs old.
            // The other constraint is that the timestamp needs to be larger than or equal the
            // one in the previous L2 block.
            if (
                local.params.timestamp + _config.maxAnchorHeightOffset * 12 < block.timestamp
                    || local.params.timestamp > block.timestamp
                    || local.params.timestamp < parentBlk.proposedAt
            ) {
                revert L1_INVALID_TIMESTAMP();
            }

        // Check if parent block has the right meta hash. This is to allow the proposer to make
        // sure the block builds on the expected latest chain state.
        if (local.params.parentMetaHash == 0) {
            local.params.parentMetaHash = parentBlk.metaHash;
        } else if (local.params.parentMetaHash != parentBlk.metaHash) {
            revert L1_UNEXPECTED_PARENT();
        }

        // Initialize metadata to compute a metaHash, which forms a part of
        // the block data to be stored on-chain for future integrity checks.
        // If we choose to persist all data fields in the metadata, it will
        // require additional storage slots.
        unchecked {
            meta_ = TaikoData.BlockMetadataV2({
                anchorBlockHash: blockhash(local.params.anchorBlockId),
                difficulty: keccak256(abi.encode("TAIKO_DIFFICULTY", local.b.numBlocks)),
                blobHash: 0, // to be initialized below
                // To make sure each L2 block can be exexucated deterministiclly by the client
                // without referering to its metadata on Ethereum, we need to encode
                // config.sharingPctg into the extraData.
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
        }

        // Update certain meta fields
        if (meta_.blobUsed) {
            if (!LibNetwork.isDencunSupported(block.chainid)) revert L1_BLOB_NOT_AVAILABLE();

            // Always use the first blob in this transaction. If the
            // proposeBlock functions are called more than once in the same
            // L1 transaction, these multiple L2 blocks will share the same
            // blob.
            meta_.blobHash = blobhash(local.params.blobIndex);
            if (meta_.blobHash == 0) revert L1_BLOB_NOT_FOUND();
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
            metaHash:  keccak256(abi.encode(meta_)) ,
            assignedProver: address(0),
            livenessBond:  0  ,
            blockId: local.b.numBlocks,
            proposedAt: local.params.timestamp ,
            proposedIn:  local.params.anchorBlockId ,
            // For a new block, the next transition ID is always 1, not 0.
            nextTransitionId: 1,
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

        LibBonds.debitBond(_state, _resolver, local.params.proposer, _config.livenessBond);

     

            emit BlockProposedV2(meta_.id, meta_);
   
    }

    function _encodeBaseFeeConfig(LibSharedData.BaseFeeConfig memory _baseFeeConfig)
        private
        pure
        returns (bytes32)
    {
        return bytes32(uint256(_baseFeeConfig.sharingPctg));
    }
}
