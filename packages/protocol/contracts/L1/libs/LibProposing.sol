// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../4844/IBlobHashReader.sol";
import "../../common/AddressResolver.sol";
import "../../libs/LibAddress.sol";
import "../hooks/IHook.sol";
import "../tiers/ITierProvider.sol";
import "../TaikoData.sol";
import "./LibDepositing.sol";

/// @title LibProposing
/// @notice A library for handling block proposals in the Taiko protocol.
library LibProposing {
    using LibAddress for address;

    // According to EIP4844, each blob has up to 4096 field elements, and each
    // field element has 32 bytes.
    uint256 public constant MAX_BYTES_PER_BLOB = 4096 * 32;

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint96 livenessBond,
        TaikoData.BlockMetadata meta,
        TaikoData.EthDeposit[] depositsProcessed
    );

    event BlobCached(bytes32 blobHash);

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_BLOB_FOR_DA_DISABLED();
    error L1_BLOB_NOT_FOUND();
    error L1_BLOB_NOT_REUSEABLE();
    error L1_INVALID_PARAM();
    error L1_INVALID_PROVER();
    error L1_LIVENESS_BOND_NOT_RECEIVED();
    error L1_PROPOSER_NOT_EOA();
    error L1_TOO_MANY_BLOCKS();
    error L1_TOO_MANY_HOOKS();
    error L1_TXLIST_OFFSET();
    error L1_TXLIST_SIZE();
    error L1_UNAUTHORIZED();
    error L1_UNEXPECTED_PARENT();

    /// @dev Proposes a Taiko L2 block.
    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        bytes calldata data,
        bytes calldata txList
    )
        external
        returns (
            TaikoData.BlockMetadata memory meta,
            TaikoData.EthDeposit[] memory depositsProcessed
        )
    {
        TaikoData.BlockParams memory params = abi.decode(data, (TaikoData.BlockParams));

        if (params.assignedProver == address(0)) {
            revert L1_INVALID_PROVER();
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

        TaikoData.Block storage parent =
            state.blocks[(b.numBlocks - 1) % config.blockRingBufferSize];

        // Check if parent block has the right meta hash
        if (params.parentMetaHash != 0 && parent.metaHash != params.parentMetaHash) {
            revert L1_UNEXPECTED_PARENT();
        }

        // Each transaction must handle a specific quantity of L1-to-L2
        // Ether deposits.
        depositsProcessed = LibDepositing.processDeposits(state, config, msg.sender);

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
                coinbase: msg.sender,
                id: b.numBlocks,
                gasLimit: config.blockMaxGasLimit,
                timestamp: uint64(block.timestamp),
                l1Height: uint64(block.number - 1),
                txListByteOffset: 0, // to be initialized below
                txListByteSize: 0, // to be initialized below
                minTier: 0, // to be initialized below
                blobUsed: txList.length == 0,
                parentMetaHash: parent.metaHash
            });
        }

        // Update certain meta fields
        if (meta.blobUsed) {
            if (!config.blobAllowedForDA) revert L1_BLOB_FOR_DA_DISABLED();

            if (params.blobHash != 0) {
                // We try to reuse an old blob
                if (isBlobReusable(state, config, params.blobHash)) {
                    revert L1_BLOB_NOT_REUSEABLE();
                }
                meta.blobHash = params.blobHash;
            } else {
                // Always use the first blob in this transaction. If the
                // proposeBlock functions are called more than once in the same
                // L1 transaction, these multiple L2 blocks will share the same
                // blob.
                meta.blobHash =
                    IBlobHashReader(resolver.resolve("blob_hash_reader", false)).getFirstBlobHash();

                if (meta.blobHash == 0) revert L1_BLOB_NOT_FOUND();

                // Depends on the blob data price, it may not make sense to
                // cache the blob which costs 20,000 (sstore) + 631 (event)
                // extra gas.
                if (params.cacheBlobForReuse) {
                    state.reusableBlobs[meta.blobHash] = block.timestamp;
                    emit BlobCached(meta.blobHash);
                }
            }

            if (uint256(params.txListByteOffset) + params.txListByteSize > MAX_BYTES_PER_BLOB) {
                revert L1_TXLIST_OFFSET();
            }

            if (params.txListByteSize == 0 || params.txListByteSize > config.blockMaxTxListBytes) {
                revert L1_TXLIST_SIZE();
            }

            meta.txListByteOffset = params.txListByteOffset;
            meta.txListByteSize = params.txListByteSize;
        } else {
            // The proposer must be an Externally Owned Account (EOA) for
            // calldata usage. This ensures that the transaction is not an
            // internal one, making calldata retrieval more straightforward for
            // Taiko node software.
            if (!LibAddress.isSenderEOA()) revert L1_PROPOSER_NOT_EOA();

            if (params.txListByteOffset != 0 || params.txListByteSize != 0) {
                revert L1_INVALID_PARAM();
            }

            // blockMaxTxListBytes is a uint24
            if (txList.length > config.blockMaxTxListBytes) {
                revert L1_TXLIST_SIZE();
            }

            meta.blobHash = keccak256(txList);
            meta.txListByteOffset = 0;
            meta.txListByteSize = uint24(txList.length);
        }

        // Following the Merge, the L1 mixHash incorporates the
        // prevrandao value from the beacon chain. Given the possibility
        // of multiple Taiko blocks being proposed within a single
        // Ethereum block, we must introduce a salt to this random
        // number as the L2 mixHash.
        unchecked {
            meta.difficulty = meta.blobHash ^ bytes32(block.prevrandao * b.numBlocks * block.number);
        }

        // Use the difficulty as a random number
        meta.minTier = ITierProvider(resolver.resolve("tier_provider", false)).getMinTier(
            uint256(meta.difficulty)
        );

        // Now, it's essential to initialize the block that will be stored
        // on L1. We should aim to utilize as few storage slots as possible,
        // alghouth using a ring buffer can minimize storage writes once
        // the buffer reaches its capacity.
        TaikoData.Block storage blk = state.blocks[b.numBlocks % config.blockRingBufferSize];

        // Please note that all fields must be re-initialized since we are
        // utilizing an existing ring buffer slot, not creating a new storage
        // slot.
        blk.metaHash = keccak256(abi.encode(meta));

        // Safeguard the liveness bond to ensure its preservation,
        // particularly in scenarios where it might be altered after the
        // block's proposal but before it has been proven or verified.
        blk.livenessBond = config.livenessBond;
        blk.blockId = b.numBlocks;

        blk.proposedAt = meta.timestamp;
        blk.proposedIn = uint64(block.number);

        // For a new block, the next transition ID is always 1, not 0.
        blk.nextTransitionId = 1;

        // For unverified block, its verifiedTransitionId is always 0.
        blk.verifiedTransitionId = 0;

        // Verify assignment authorization; if prover's address is an IProver
        // contract, transfer Ether and call "validateAssignment" for
        // verification.
        // Prover can charge ERC20/NFT as fees; msg.value can be zero. Taiko
        // doesn't mandate Ether as the only proofing fee.
        blk.assignedProver = params.assignedProver;

        // Increment the counter (cursor) by 1.
        unchecked {
            ++state.slotB.numBlocks;
        }

        {
            IERC20 tko = IERC20(resolver.resolve("taiko_token", false));
            uint256 tkoBalance = tko.balanceOf(address(this));

            // Allow max one hook - for now - but keep the API for
            // possibility to have more in the future.
            if (params.hookCalls.length > 1) revert L1_TOO_MANY_HOOKS();

            // Run all hooks.
            // Note that address(this).balance has been updated with msg.value,
            // prior to any code in this function has been executed.
            for (uint256 i; i < params.hookCalls.length; ++i) {
                // When a hook is called, all ether in this contract will be send to the hook.
                // If the ether sent to the hook is not used entirely, the hook shall send the Ether
                // back to this contract for the next hook to use.
                // Proposers shall choose use extra hooks wisely.
                IHook(params.hookCalls[i].hook).onBlockProposed{ value: address(this).balance }(
                    blk, meta, params.hookCalls[i].data
                );
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
        AddressResolver resolver
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
