// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../libs/LibAddress.sol";
import "../../libs/LibNetwork.sol";
import "./LibUtils.sol";

/// @title LibProposing
/// @notice A library for handling block proposals in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
library LibProposing {
    using LibAddress for address;

    // = keccak256(abi.encode(new TaikoData.EthDeposit[](0)))
    bytes32 private constant _EMPTY_ETH_DEPOSIT_HASH =
        0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd;

    struct Local {
        TaikoData.SlotB b;
        TaikoData.BlockParams params;
        bytes32 parentMetaHash;
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
        TaikoData.EthDeposit[] depositsProcessed,
        uint64 blobTxListOffset,
        uint64 blobTxListLength,
        uint8 blobIndex
    );

    /// @notice Emitted when a block's txList is in the calldata.
    /// @param blockId The ID of the proposed block.
    /// @param txList The txList.
    event CalldataTxList(uint256 indexed blockId, bytes txList);

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_BLOB_NOT_AVAILABLE();
    error L1_BLOB_NOT_FOUND();
    error L1_INVALID_L1_STATE_BLOCK();
    error L1_INVALID_SIG();
    error L1_INVALID_TIMESTAMP();
    error L1_LIVENESS_BOND_NOT_RECEIVED();
    error L1_TOO_MANY_BLOCKS();
    error L1_UNEXPECTED_PARENT();

    /// @dev Proposes a Taiko L2 block.
    /// @param _state Current TaikoData.State.
    /// @param _tko The taiko token.
    /// @param _config Actual TaikoData.Config.
    /// @param _data Encoded data bytes containing the block params.
    /// @param _txList Transaction list bytes (if not blob).
    /// @return meta_ The constructed block's metadata.
    function proposeBlock(
        TaikoData.State storage _state,
        TaikoToken _tko,
        TaikoData.Config memory _config,
        IAddressResolver, /*_resolver*/
        bytes calldata _data,
        bytes calldata _txList,
        uint8 index
    )
        internal
        returns (TaikoData.BlockMetadata memory meta_, TaikoData.EthDeposit[] memory deposits_)
    {
        Local memory local;
        local.params = abi.decode(_data, (TaikoData.BlockParams));

        if (local.params.coinbase == address(0)) {
            local.params.coinbase = msg.sender;
        }

        // If no L1 state block is specified, fall back to the previous L1 block
        // (the most recent block that has its block hash available in the EVM through the blockhash
        // opcode).
        if (local.params.l1StateBlockNumber == 0) {
            local.params.l1StateBlockNumber = uint32(block.number) - 1;
        }

        // If no timestamp specified, use the current timestamp
        if (local.params.timestamp == 0) {
            local.params.timestamp = uint64(block.timestamp);
        }

        // Taiko, as a Based Rollup, enables permissionless block proposals.
        local.b = _state.slotB;

        // It's essential to ensure that the ring buffer for proposed blocks
        // still has space for at least one more block.
        if (local.b.numBlocks >= local.b.lastVerifiedBlockId + _config.blockMaxProposals + 1) {
            revert L1_TOO_MANY_BLOCKS();
        }

        TaikoData.Block storage parentBlock =
            _state.blocks[(local.b.numBlocks - 1) % _config.blockRingBufferSize];
        local.parentMetaHash = parentBlock.metaHash;

        // Check if parent block has the right meta hash. This is to allow the proposer to make sure
        // the block builds on the expected latest chain state.
        if (local.params.parentMetaHash != 0 && local.parentMetaHash != local.params.parentMetaHash)
        {
            revert L1_UNEXPECTED_PARENT();
        }

        // Verify the passed in L1 state block number.
        // We only allow the L1 block to be 4 epochs old.
        // The other constraint is that the L1 block number needs to be larger than or equal the one
        // in the previous L2 block.
        if (
            local.params.l1StateBlockNumber + 128 < block.number
                || local.params.l1StateBlockNumber >= block.number
                || local.params.l1StateBlockNumber < parentBlock.l1StateBlockNumber
        ) {
            revert L1_INVALID_L1_STATE_BLOCK();
        }

        // Verify the passed in timestamp.
        // We only allow the timestamp to be 4 epochs old.
        // The other constraint is that the timestamp needs to be larger than or equal the one
        // in the previous L2 block.
        if (
            local.params.timestamp + 128 * 12 < block.timestamp
                || local.params.timestamp > block.timestamp
                || local.params.timestamp < parentBlock.timestamp
        ) {
            revert L1_INVALID_TIMESTAMP();
        }

        // Initialize metadata to compute a metaHash, which forms a part of
        // the block data to be stored on-chain for future integrity checks.
        // If we choose to persist all data fields in the metadata, it will
        // require additional storage slots.
        unchecked {
            meta_ = TaikoData.BlockMetadata({
                l1Hash: blockhash(local.params.l1StateBlockNumber),
                difficulty: 0, // to be initialized below
                blobHash: 0, // to be initialized below
                extraData: local.params.extraData,
                depositsHash: _EMPTY_ETH_DEPOSIT_HASH,
                coinbase: local.params.coinbase,
                id: local.b.numBlocks,
                gasLimit: _config.blockMaxGasLimit,
                // Use the timestamp one block after the chosen L1 state block
                timestamp: local.params.timestamp,
                l1Height: local.params.l1StateBlockNumber,
                minTier: 0, // to be initialized below
                blobUsed: _txList.length == 0,
                parentMetaHash: local.parentMetaHash,
                sender: msg.sender,
                blobTxListOffset: local.params.blobTxListOffset,
                blobTxListLength: local.params.blobTxListLength,
                index: index
            });
        }

        // Update certain meta fields
        if (meta_.blobUsed) {
            //if (!LibNetwork.isDencunSupported(block.chainid)) revert L1_BLOB_NOT_AVAILABLE();

            meta_.blobHash = blobhash(local.params.blobIndex);
            if (meta_.blobHash == 0) revert L1_BLOB_NOT_FOUND();
        } else {
            meta_.blobHash = keccak256(_txList);

            // This function must be called as the outmost transaction (not an internal one) for
            // the node to extract the calldata easily.
            // We cannot rely on `msg.sender != tx.origin` for EOA check, as it will break after EIP
            // 7645: Alias ORIGIN to SENDER
            // if (
            //     _config.checkEOAForCalldataDA
            //         && ECDSA.recover(meta_.blobHash, local.params.signature) != msg.sender
            // ) {
            //     revert L1_INVALID_SIG();
            // }

            emit CalldataTxList(meta_.id, _txList);
        }

        // Generate a random value from the L1 state block hash and the L2 block ID
        meta_.difficulty = keccak256(
            abi.encodePacked(blockhash(local.params.l1StateBlockNumber), local.b.numBlocks)
        );

        {
            // ITierRouter tierRouter = ITierRouter(_resolver.resolve(LibStrings.B_TIER_ROUTER,
            // false));
            // ITierProvider tierProvider =
            // ITierProvider(tierRouter.getProvider(local.b.numBlocks));

            // Use the difficulty as a random number
            // meta_.minTier = tierProvider.getMinTier(uint256(meta_.difficulty));
            meta_.minTier = 100;
        }

        // Create the block that will be stored onchain
        TaikoData.Block memory blk = TaikoData.Block({
            metaHash: LibUtils.hashMetadata(meta_),
            // Safeguard the liveness bond to ensure its preservation,
            // particularly in scenarios where it might be altered after the
            // block's proposal but before it has been proven or verified.
            assignedProver: address(0),
            livenessBond: _config.livenessBond,
            blockId: local.b.numBlocks,
            proposedAt: meta_.timestamp,
            proposedIn: uint64(block.number),
            // For a new block, the next transition ID is always 1, not 0.
            nextTransitionId: 1,
            // For unverified block, its verifiedTransitionId is always 0.
            verifiedTransitionId: 0,
            l1StateBlockNumber: local.params.l1StateBlockNumber,
            timestamp: local.params.timestamp
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
        emit BlockProposed({
            blockId: meta_.id,
            assignedProver: msg.sender,
            livenessBond: _config.livenessBond,
            meta: meta_,
            depositsProcessed: deposits_,
            blobTxListOffset: local.params.blobTxListOffset,
            blobTxListLength: local.params.blobTxListLength,
            blobIndex: local.params.blobIndex
        });
    }
}
