// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../common/IAddressResolver.sol";
import "../../libs/LibAddress.sol";
import "../hooks/IHook.sol";
import "../tiers/ITierProvider.sol";
import "../TaikoData.sol";
import "./LibDepositing.sol";

/// @title LibProposing
/// @notice A library for handling block proposals in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
library LibProposing {
    using LibAddress for address;

    /// @notice The maximum number of bytes allowed per blob.
    /// @dev According to EIP4844, each blob has up to 4096 field elements, and each
    /// field element has 32 bytes.
    uint256 public constant MAX_BYTES_PER_BLOB = 4096 * 32;

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

    /// @notice Emitted when a blob is cached.
    /// @param blobHash The hash of the cached blob.
    event BlobCached(bytes32 blobHash);

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_BLOB_FOR_DA_DISABLED();
    error L1_BLOB_NOT_FOUND();
    error L1_BLOB_NOT_REUSEABLE();
    error L1_BLOB_REUSE_DISALBED();
    error L1_INVALID_HOOK();
    error L1_INVALID_PARAM();
    error L1_INVALID_PROVER();
    error L1_LIVENESS_BOND_NOT_RECEIVED();
    error L1_PROPOSER_NOT_EOA();
    error L1_TOO_MANY_BLOCKS();
    error L1_TXLIST_OFFSET();
    error L1_TXLIST_SIZE();
    error L1_UNAUTHORIZED();
    error L1_UNEXPECTED_PARENT();

    /// @dev Proposes a Taiko L2 block.
    /// @param state Current TaikoData.State.
    /// @param config Actual TaikoData.Config.
    /// @param resolver Address resolver interface.
    /// @param data Encoded data bytes containing the block params.
    /// @param txList Transaction list bytes (if not blob).
    /// @return meta The constructed block's metadata.
    /// @return depositsProcessed The EthDeposit array about processed deposits in this proposed
    /// block.
    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        IAddressResolver resolver,
        bytes calldata data,
        bytes calldata txList
    )
        internal
        returns (
            TaikoData.BlockMetadata memory meta,
            TaikoData.EthDeposit[] memory depositsProcessed
        )
    {
        TaikoData.BlockParams memory params = abi.decode(data, (TaikoData.BlockParams));

        // We need a prover that will submit proofs after the block has been submitted
        if (params.assignedProver == address(0)) {
            revert L1_INVALID_PROVER();
        }

        if (params.coinbase == address(0)) {
            params.coinbase = msg.sender;
        }

        // Taiko, as a Based Rollup, enables permissionless block proposals.
        // However, if the "proposer" address is set to a non-zero value, we
        // ensure that only that specific address has the authority to propose
        // blocks.
        TaikoData.SlotB memory b = state.slotB;
        if (!_isProposerPermitted(b, resolver)) revert L1_UNAUTHORIZED();

        // It's essential to ensure that the ring buffer for proposed blocks
        // still has space for at least one more block.

        if (b.numBlocks >= b.lastVerifiedBlockId + config.blockMaxProposals + 1) {
            revert L1_TOO_MANY_BLOCKS();
        }

        bytes32 parentMetaHash =
            state.blocks[(b.numBlocks - 1) % config.blockRingBufferSize].metaHash;

        // Check if parent block has the right meta hash
        // This is to allow the proposer to make sure the block builds on the expected latest chain
        // state
        if (params.parentMetaHash != 0 && parentMetaHash != params.parentMetaHash) {
            revert L1_UNEXPECTED_PARENT();
        }

        // Each transaction must handle a specific quantity of L1-to-L2
        // Ether deposits.
        depositsProcessed = LibDepositing.processDeposits(state, config, params.coinbase);

        // Initialize metadata to compute a metaHash, which forms a part of
        // the block data to be stored on-chain for future integrity checks.
        // If we choose to persist all data fields in the metadata, it will
        // require additional storage slots.
        unchecked {
            meta = TaikoData.BlockMetadata({
                l1Hash: blockhash(block.number - 1),
                difficulty: 0, // to be initialized below
                blobHash: 0, // to be initialized below
                extraData: params.extraData,
                depositsHash: keccak256(abi.encode(depositsProcessed)),
                coinbase: params.coinbase,
                id: b.numBlocks,
                gasLimit: config.blockMaxGasLimit,
                timestamp: uint64(block.timestamp),
                l1Height: uint64(block.number - 1),
                txListByteOffset: 0, // to be initialized below
                txListByteSize: 0, // to be initialized below
                minTier: 0, // to be initialized below
                blobUsed: txList.length == 0,
                parentMetaHash: parentMetaHash
            });
        }

        // Update certain meta fields
        if (meta.blobUsed) {
            if (!config.blobAllowedForDA) revert L1_BLOB_FOR_DA_DISABLED();

            if (params.blobHash != 0) {
                if (!config.blobReuseEnabled) revert L1_BLOB_REUSE_DISALBED();

                // We try to reuse an old blob
                if (!isBlobReusable(state, config, params.blobHash)) {
                    revert L1_BLOB_NOT_REUSEABLE();
                }
                meta.blobHash = params.blobHash;
            } else {
                // Always use the first blob in this transaction. If the
                // proposeBlock functions are called more than once in the same
                // L1 transaction, these multiple L2 blocks will share the same
                // blob.
                meta.blobHash = blobhash(0);

                if (meta.blobHash == 0) revert L1_BLOB_NOT_FOUND();

                // Depends on the blob data price, it may not make sense to
                // cache the blob which costs 20,000 (sstore) + 631 (event)
                // extra gas.
                if (config.blobReuseEnabled && params.cacheBlobForReuse) {
                    state.reusableBlobs[meta.blobHash] = block.timestamp;
                    emit BlobCached(meta.blobHash);
                }
            }

            // Check that the txList data range is within the max size of a blob
            if (uint256(params.txListByteOffset) + params.txListByteSize > MAX_BYTES_PER_BLOB) {
                revert L1_TXLIST_OFFSET();
            }

            meta.txListByteOffset = params.txListByteOffset;
            meta.txListByteSize = params.txListByteSize;
        } else {
            // The proposer must be an Externally Owned Account (EOA) for
            // calldata usage. This ensures that the transaction is not an
            // internal one, making calldata retrieval more straightforward for
            // Taiko node software.
            if (!LibAddress.isSenderEOA()) revert L1_PROPOSER_NOT_EOA();

            // The txList is the full byte array without any offset
            if (params.txListByteOffset != 0) {
                revert L1_INVALID_PARAM();
            }

            meta.blobHash = keccak256(txList);
            meta.txListByteOffset = 0;
            meta.txListByteSize = uint24(txList.length);
        }

        // Check that the tx length is non-zero and within the supported range
        if (meta.txListByteSize == 0 || meta.txListByteSize > config.blockMaxTxListBytes) {
            revert L1_TXLIST_SIZE();
        }

        // Following the Merge, the L1 mixHash incorporates the
        // prevrandao value from the beacon chain. Given the possibility
        // of multiple Taiko blocks being proposed within a single
        // Ethereum block, we choose to introduce a salt to this random
        // number as the L2 mixHash.
        meta.difficulty = keccak256(abi.encodePacked(block.prevrandao, b.numBlocks, block.number));

        // Use the difficulty as a random number
        meta.minTier = ITierProvider(resolver.resolve("tier_provider", false)).getMinTier(
            uint256(meta.difficulty)
        );

        // Create the block that will be stored onchain
        TaikoData.Block memory blk = TaikoData.Block({
            metaHash: keccak256(abi.encode(meta)),
            // Safeguard the liveness bond to ensure its preservation,
            // particularly in scenarios where it might be altered after the
            // block's proposal but before it has been proven or verified.
            livenessBond: config.livenessBond,
            blockId: b.numBlocks,
            proposedAt: meta.timestamp,
            proposedIn: uint64(block.number),
            // For a new block, the next transition ID is always 1, not 0.
            nextTransitionId: 1,
            // For unverified block, its verifiedTransitionId is always 0.
            verifiedTransitionId: 0,
            assignedProver: params.assignedProver
        });

        // Store the block in the ring buffer
        state.blocks[b.numBlocks % config.blockRingBufferSize] = blk;

        // Increment the counter (cursor) by 1.
        unchecked {
            ++state.slotB.numBlocks;
        }

        {
            IERC20 tko = IERC20(resolver.resolve("taiko_token", false));
            uint256 tkoBalance = tko.balanceOf(address(this));

            // Run all hooks.
            // Note that address(this).balance has been updated with msg.value,
            // prior to any code in this function has been executed.
            address prevHook;
            for (uint256 i; i < params.hookCalls.length; ++i) {
                if (uint160(prevHook) >= uint160(params.hookCalls[i].hook)) {
                    revert L1_INVALID_HOOK();
                }

                // When a hook is called, all ether in this contract will be send to the hook.
                // If the ether sent to the hook is not used entirely, the hook shall send the Ether
                // back to this contract for the next hook to use.
                // Proposers shall choose use extra hooks wisely.
                IHook(params.hookCalls[i].hook).onBlockProposed{ value: address(this).balance }(
                    blk, meta, params.hookCalls[i].data
                );

                prevHook = params.hookCalls[i].hook;
            }
            // Refund Ether
            if (address(this).balance != 0) {
                msg.sender.sendEther(address(this).balance);
            }

            // Check that after hooks, the Taiko Token balance of this contract
            // have increased by the same amount as config.livenessBond (to prevent)
            // multiple draining payments by a malicious proposer nesting the same
            // hook.
            if (tko.balanceOf(address(this)) != tkoBalance + config.livenessBond) {
                revert L1_LIVENESS_BOND_NOT_RECEIVED();
            }
        }

        emit BlockProposed({
            blockId: blk.blockId,
            assignedProver: blk.assignedProver,
            livenessBond: config.livenessBond,
            meta: meta,
            depositsProcessed: depositsProcessed
        });
    }

    /// @notice Checks if a blob is reusable.
    /// @param state Current TaikoData.State.
    /// @param config The TaikoData.Config.
    /// @param blobHash The blob hash
    /// @return True if the blob is reusable, false otherwise.
    function isBlobReusable(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 blobHash
    )
        internal
        view
        returns (bool)
    {
        return state.reusableBlobs[blobHash] + config.blobExpiry > block.timestamp;
    }

    function _isProposerPermitted(
        TaikoData.SlotB memory slotB,
        IAddressResolver resolver
    )
        private
        view
        returns (bool)
    {
        if (slotB.numBlocks == 1) {
            // Only proposer_one can propose the first block after genesis
            address proposerOne = resolver.resolve("proposer_one", true);
            if (proposerOne != address(0) && msg.sender != proposerOne) {
                return false;
            }
        }

        address proposer = resolver.resolve("proposer", true);
        return proposer == address(0) || msg.sender == proposer;
    }
}
