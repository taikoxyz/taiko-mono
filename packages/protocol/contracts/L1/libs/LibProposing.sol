// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../libs/LibAddress.sol";
import "../../libs/LibNetwork.sol";
import "./LibData.sol";
import "./LibUtils.sol";

/// @title LibProposing
/// @notice A library for handling block proposals in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
library LibProposing {
    using LibAddress for address;

    struct Local {
        TaikoData.SlotB b;
        TaikoData.BlockParams2 params;
        bytes32 parentMetaHash;
        bool postFork;
    }

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    /// @notice Emitted when a block is proposed.
    /// @param blockId The ID of the proposed block.
    /// @param assignedProver The address of the assigned prover.
    /// @param livenessBond The liveness bond of the proposed block.
    /// @param meta The metadata of the proposed block.
    /// @param depositsProcessed The EthDeposit array about processed deposits in this proposed
    /// block.
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint96 livenessBond,
        TaikoData.BlockMetadata meta,
        TaikoData.EthDeposit[] depositsProcessed
    );

    event BlockProposed2(uint256 indexed blockId, TaikoData.BlockMetadata2 meta);

    /// @notice Emitted when a block's txList is in the calldata.
    /// @param blockId The ID of the proposed block.
    /// @param txList The txList.
    event CalldataTxList(uint256 indexed blockId, bytes txList);

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_BLOB_NOT_AVAILABLE();
    error L1_BLOB_NOT_FOUND();
    error L1_LIVENESS_BOND_NOT_RECEIVED();
    error L1_TOO_MANY_BLOCKS();
    error L1_UNEXPECTED_PARENT();

    /// @dev Proposes a Taiko L2 block.
    /// @param _state Current TaikoData.State.
    /// @param _tko The taiko token.
    /// @param _config Actual TaikoData.Config.
    /// @param _resolver Address resolver interface.
    /// @param _data Encoded data bytes containing the block params.
    /// @param _txList Transaction list bytes (if not blob).
    /// @return meta_ The constructed block's metadata.
    function proposeBlock(
        TaikoData.State storage _state,
        TaikoToken _tko,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        bytes calldata _data,
        bytes calldata _txList
    )
        internal
        returns (TaikoData.BlockMetadata2 memory meta_, TaikoData.EthDeposit[] memory deposits_)
    {
        // Taiko, as a Based Rollup, enables permissionless block proposals.
        Local memory local;
        local.b = _state.slotB;
        local.postFork = local.b.numBlocks >= _config.hardforkHeight;

        local.params = local.postFork
            ? abi.decode(_data, (TaikoData.BlockParams2))
            : LibData.paramV1toV2(abi.decode(_data, (TaikoData.BlockParams)));

        // if (local.params.timestamp == 0) {
        //     local.params.timestamp = uint64(block.timestamp);
        // }
        local.params.timestamp = uint64(block.timestamp);
        // if (local.params.l1StateBlockNumber == 0) {
        //     local.params.l1StateBlockNumber = uint64(block.number - 1);
        // }
        local.params.l1StateBlockNumber = uint64(block.number - 1);

        if (local.params.coinbase == address(0)) {
            local.params.coinbase = msg.sender;
        }

        // It's essential to ensure that the ring buffer for proposed blocks
        // still has space for at least one more block.
        if (local.b.numBlocks >= local.b.lastVerifiedBlockId + _config.blockMaxProposals + 1) {
            revert L1_TOO_MANY_BLOCKS();
        }

        local.parentMetaHash =
            _state.blocks[(local.b.numBlocks - 1) % _config.blockRingBufferSize].metaHash;
        // assert(parentMetaHash != 0);

        // Check if parent block has the right meta hash. This is to allow the proposer to make sure
        // the block builds on the expected latest chain state.
        if (local.params.parentMetaHash != 0 && local.parentMetaHash != local.params.parentMetaHash)
        {
            revert L1_UNEXPECTED_PARENT();
        }

        // Initialize metadata to compute a metaHash, which forms a part of
        // the block data to be stored on-chain for future integrity checks.
        // If we choose to persist all data fields in the metadata, it will
        // require additional storage slots.
        unchecked {
            meta_ = TaikoData.BlockMetadata2({
                l1Hash: blockhash(local.params.l1StateBlockNumber),
                difficulty: 0, // to be initialized below
                blobHash: 0, // to be initialized below
                extraData: local.params.extraData,
                coinbase: local.params.coinbase,
                id: local.b.numBlocks,
                gasLimit: _config.blockMaxGasLimit,
                timestamp: local.params.timestamp,
                l1Height: local.params.l1StateBlockNumber,
                minTier: 0, // to be initialized below
                blobUsed: _txList.length == 0,
                parentMetaHash: local.parentMetaHash,
                proposer: msg.sender,
                livenessBond: _config.livenessBond
            });
        }

        // Update certain meta fields
        if (meta_.blobUsed) {
            if (!LibNetwork.isDencunSupported(block.chainid)) revert L1_BLOB_NOT_AVAILABLE();

            // Always use the first blob in this transaction. If the
            // proposeBlock functions are called more than once in the same
            // L1 transaction, these multiple L2 blocks will share the same
            // blob.
            meta_.blobHash = blobhash(0);
            if (meta_.blobHash == 0) revert L1_BLOB_NOT_FOUND();
        } else {
            meta_.blobHash = keccak256(_txList);
            emit CalldataTxList(meta_.id, _txList);
        }

        // Following the Merge, the L1 mixHash incorporates the
        // prevrandao value from the beacon chain. Given the possibility
        // of multiple Taiko blocks being proposed within a single
        // Ethereum block, we choose to introduce a salt to this random
        // number as the L2 mixHash.
        meta_.difficulty =
            keccak256(abi.encodePacked(block.prevrandao, local.b.numBlocks, block.number));

        {
            ITierRouter tierRouter = ITierRouter(_resolver.resolve(LibStrings.B_TIER_ROUTER, false));
            ITierProvider tierProvider = ITierProvider(tierRouter.getProvider(local.b.numBlocks));

            // Use the difficulty as a random number
            meta_.minTier = tierProvider.getMinTier(uint256(meta_.difficulty));
        }

        // Create the block that will be stored onchain
        TaikoData.Block memory blk = TaikoData.Block({
            metaHash: LibData.hashMetadata(local.postFork, meta_),
            // Safeguard the liveness bond to ensure its preservation,
            // particularly in scenarios where it might be altered after the
            // block's proposal but before it has been proven or verified.
            assignedProver: address(0),
            livenessBond: local.postFork ? 0 : _config.livenessBond,
            blockId: local.b.numBlocks,
            proposedAt: meta_.timestamp,
            proposedIn: uint64(block.number),
            // For a new block, the next transition ID is always 1, not 0.
            nextTransitionId: 1,
            // For unverified block, its verifiedTransitionId is always 0.
            verifiedTransitionId: 0
        });

        // Store the block in the ring buffer
        _state.blocks[local.b.numBlocks % _config.blockRingBufferSize] = blk;

        // Increment the counter (cursor) by 1.
        unchecked {
            ++_state.slotB.numBlocks;
        }

        _tko.transferFrom(msg.sender, address(this), _config.livenessBond);

        // Bribe the block builder. Unlock 1559-tips, this tip is only made
        // if this transaction succeeds.
        if (msg.value != 0 && block.coinbase != address(0)) {
            address(block.coinbase).sendEtherAndVerify(msg.value);
        }

        deposits_ = new TaikoData.EthDeposit[](0);

        if (local.postFork) {
            emit BlockProposed2(meta_.id, meta_);
        } else {
            emit BlockProposed({
                blockId: meta_.id,
                assignedProver: msg.sender,
                livenessBond: _config.livenessBond,
                meta: LibData.metadataV2toV1(meta_),
                depositsProcessed: deposits_
            });
        }
    }
}
