// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../libs/LibAddress.sol";
import "../../libs/LibNetwork.sol";
import "./LibBonds.sol";
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

    /// @notice Emitted when a block's txList is in the calldata.
    /// @param blockId The ID of the proposed block.
    /// @param txList The txList.
    event CalldataTxList(uint256 indexed blockId, bytes txList);

    error L1_BLOB_NOT_AVAILABLE();
    error L1_BLOB_NOT_FOUND();
    error L1_INVALID_SIG();
    error L1_LIVENESS_BOND_NOT_RECEIVED();
    error L1_TOO_MANY_BLOCKS();
    error L1_UNEXPECTED_PARENT();

    /// @dev Proposes a Taiko L2 block.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _resolver Address resolver interface.
    /// @param _data Encoded data bytes containing the block params.
    /// @param _txList Transaction list bytes (if not blob).
    /// @return meta_ The constructed block's metadata.
    function proposeBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        bytes calldata _data,
        bytes calldata _txList
    )
        internal
        returns (TaikoData.BlockMetadata memory meta_, TaikoData.EthDeposit[] memory deposits_)
    {
        Local memory local;
        local.params = abi.decode(_data, (TaikoData.BlockParams));

        if (local.params.coinbase == address(0)) {
            local.params.coinbase = msg.sender;
        }

        // Taiko, as a Based Rollup, enables permissionless block proposals.
        local.b = _state.slotB;

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
            meta_ = TaikoData.BlockMetadata({
                l1Hash: blockhash(block.number - 1),
                difficulty: 0, // to be initialized below
                blobHash: 0, // to be initialized below
                extraData: local.params.extraData,
                depositsHash: _EMPTY_ETH_DEPOSIT_HASH,
                coinbase: local.params.coinbase,
                id: local.b.numBlocks,
                gasLimit: _config.blockMaxGasLimit,
                timestamp: uint64(block.timestamp),
                l1Height: uint64(block.number - 1),
                minTier: 0, // to be initialized below
                blobUsed: _txList.length == 0,
                parentMetaHash: local.parentMetaHash,
                sender: msg.sender
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

            // This function must be called as the outmost transaction (not an internal one) for
            // the node to extract the calldata easily.
            // We cannot rely on `msg.sender != tx.origin` for EOA check, as it will break after EIP
            // 7645: Alias ORIGIN to SENDER
            if (
                _config.checkEOAForCalldataDA
                    && ECDSA.recover(meta_.blobHash, local.params.signature) != msg.sender
            ) {
                revert L1_INVALID_SIG();
            }

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
            verifiedTransitionId: 0
        });

        // Store the block in the ring buffer
        _state.blocks[local.b.numBlocks % _config.blockRingBufferSize] = blk;

        // Increment the counter (cursor) by 1.
        unchecked {
            ++_state.slotB.numBlocks;
        }

        LibBonds.debitBond(_state, _resolver, msg.sender, _config.livenessBond);

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
            depositsProcessed: deposits_
        });
    }
}
