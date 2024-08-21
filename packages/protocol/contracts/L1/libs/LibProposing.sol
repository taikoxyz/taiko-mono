// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../libs/LibAddress.sol";
import "../../libs/LibNetwork.sol";
import "../access/IProposerAccess.sol";
import "./LibBonds.sol";
import "./LibUtils.sol";

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
    }

    /// @notice Emitted when a block is proposed.
    /// @param _blockId The ID of the proposed block.
    /// @param _meta The metadata of the proposed block.
    event BlockProposedV2(uint256 indexed _blockId, TaikoData.BlockMetadataV2 _meta);

    /// @notice Emitted when a block's txList is in the calldata.
    /// @param _blockId The ID of the proposed block.
    /// @param _txList The txList.
    event CalldataTxList(uint256 indexed _blockId, bytes _txList);

    error L1_BLOB_NOT_AVAILABLE();
    error L1_BLOB_NOT_FOUND();
    error L1_INVALID_ANCHOR_BLOCK();
    error L1_INVALID_PROPOSER();
    error L1_INVALID_TIMESTAMP();
    error L1_LIVENESS_BOND_NOT_RECEIVED();
    error L1_TOO_MANY_BLOCKS();
    error L1_UNEXPECTED_PARENT();

    /// @notice Proposes a Taiko L2 block.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _resolver Address resolver interface.
    /// @param _data Encoded data bytes containing the block params.
    /// @param _txList Transaction list bytes (if not blob).
    /// @return meta_ The constructed block's metadata v2.
    function proposeBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        bytes calldata _data,
        bytes calldata _txList
    )
        public
        returns (TaikoData.BlockMetadataV2 memory meta_)
    {
        // Checks proposer access.
        Local memory local;
        local.b = _state.slotB;

        // Ensure that the ring buffer for proposed blocks still has space for at least one more
        // block.
        if (local.b.numBlocks >= local.b.lastVerifiedBlockId + _config.blockMaxProposals + 1) {
            revert L1_TOO_MANY_BLOCKS();
        }

        if (_data.length != 0) {
            local.params = abi.decode(_data, (TaikoData.BlockParamsV2));
            // otherwise use a default BlockParamsV2 with 0 values
        }

        if (local.params.coinbase == address(0)) {
            local.params.coinbase = msg.sender;
        }

        if (local.params.anchorBlockId == 0) {
            local.params.anchorBlockId = uint64(block.number - 1);
        }

        if (local.params.timestamp == 0) {
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
                // To make sure each L2 block can be executed deterministically by the client
                // without referring to its metadata on Ethereum, we need to encode
                // _config.baseFeeConfig into the extraData.
                extraData: _encodeBaseFeeConfig(_config.baseFeeConfig),
                coinbase: local.params.coinbase,
                id: local.b.numBlocks,
                gasLimit: _config.blockMaxGasLimit,
                timestamp: local.params.timestamp,
                anchorBlockId: local.params.anchorBlockId,
                minTier: 0, // to be initialized below
                blobUsed: _txList.length == 0,
                parentMetaHash: local.params.parentMetaHash,
                proposer: msg.sender,
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
            // if (!LibNetwork.isDencunSupported(block.chainid)) revert L1_BLOB_NOT_AVAILABLE();

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
            metaHash: keccak256(abi.encode(meta_)),
            assignedProver: address(0),
            livenessBond: 0,
            blockId: local.b.numBlocks,
            proposedAt: local.params.timestamp,
            proposedIn: local.params.anchorBlockId,
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

        LibBonds.debitBond(_state, _resolver, msg.sender, _config.livenessBond);

        // Bribe the block builder. Unlike 1559-tips, this tip is only made
        // if this transaction succeeds.
        if (msg.value != 0 && block.coinbase != address(0)) {
            address(block.coinbase).sendEtherAndVerify(msg.value);
        }

        emit BlockProposedV2(meta_.id, meta_);
    }

    /// @dev Checks if the proposer has the necessary permissions.
    /// @param _resolver The address resolver interface.
    function checkProposerPermission(IAddressResolver _resolver) internal view {
        address proposerAccess = _resolver.resolve(LibStrings.B_PROPOSER_ACCESS, true);
        if (proposerAccess == address(0)) return;

        if (!IProposerAccess(proposerAccess).isProposerEligible(msg.sender)) {
            revert L1_INVALID_PROPOSER();
        }
    }

    /// @dev Encodes the base fee configuration.
    /// @param _baseFeeConfig The base fee configuration to encode.
    /// @return The encoded base fee configuration as a bytes32 value.
    function _encodeBaseFeeConfig(TaikoData.BaseFeeConfig memory _baseFeeConfig)
        private
        pure
        returns (bytes32)
    {
        return bytes32(uint256(_baseFeeConfig.sharingPctg));
    }
}
