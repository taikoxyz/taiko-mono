// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "../../common/AddressResolver.sol";
import "../../4844/IBlobHashReader.sol";
import "../../libs/LibAddress.sol";
import "../tiers/ITierProvider.sol";
import "../TaikoData.sol";
import "./LibDepositing.sol";
import "./LibTaikoToken.sol";

/// @title LibProposing
/// @notice A library for handling block proposals in the Taiko protocol.
library LibProposing {
    using LibAddress for address;

    // According to EIP4844, each blob has up to 4096 field elements, and each
    // field element has 32 bytes.
    uint256 public constant MAX_BYTES_PER_BLOB = 4096 * 32;

    // Max gas paying the prover. This should be large enough to prevent the
    // worst cases, usually block proposer shall be aware the risks and only
    // choose provers that cannot consume too much gas when receiving Ether.
    uint256 public constant MAX_GAS_PAYING_PROVER = 200_000;

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint96 livenessBond,
        uint256 proverFee,
        TaikoData.BlockMetadata meta,
        TaikoData.EthDeposit[] depositsProcessed
    );

    event BlobCached(bytes32 blobHash);

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_ASSIGNMENT_EXPIRED();
    error L1_ASSIGNMENT_INVALID_SIG();
    error L1_ASSIGNMENT_INVALID_PARAMS();
    error L1_ASSIGNMENT_INSUFFICIENT_FEE();
    error L1_BLOB_FOR_DA_DISABLED();
    error L1_BLOB_NOT_FOUND();
    error L1_BLOB_NOT_REUSEABLE();
    error L1_INVALID_PARAM();
    error L1_PROPOSER_NOT_EOA();
    error L1_TIER_NOT_FOUND();
    error L1_TOO_MANY_BLOCKS();
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
        internal
        returns (
            TaikoData.BlockMetadata memory meta,
            TaikoData.EthDeposit[] memory depositsProcessed
        )
    {
        TaikoData.BlockParams memory params = abi.decode(data, (TaikoData.BlockParams));

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
        blk.assignedProver = params.assignment.prover;

        // The assigned prover burns Taiko tokens, referred to as the
        // "liveness bond." This bond remains non-refundable to the
        // assigned prover under two conditions: if the block's verification
        // transition is not the initial one or if it was generated and
        // validated by different provers. Instead, a portion of the assignment
        // bond serves as a reward for the actual prover.
        LibTaikoToken.debitTaikoToken(state, resolver, blk.assignedProver, config.livenessBond);

        // Increment the counter (cursor) by 1.
        unchecked {
            ++state.slotB.numBlocks;
        }

        // Validate the prover assignment, then charge Ether or ERC20 as the
        // prover fee based on the block's minTier.
        uint256 proverFee = _payProverFeeAndTip(
            meta.minTier, meta.blobHash, blk.blockId, blk.metaHash, params.assignment
        );

        emit BlockProposed({
            blockId: blk.blockId,
            assignedProver: blk.assignedProver,
            livenessBond: config.livenessBond,
            proverFee: proverFee,
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

    function hashAssignment(
        TaikoData.ProverAssignment memory assignment,
        address taikoAddress,
        bytes32 blobHash
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                "PROVER_ASSIGNMENT",
                taikoAddress,
                blobHash,
                assignment.feeToken,
                assignment.expiry,
                assignment.maxBlockId,
                assignment.maxProposedIn,
                assignment.tierFees
            )
        );
    }

    function _payProverFeeAndTip(
        uint16 minTier,
        bytes32 blobHash,
        uint64 blockId,
        bytes32 metaHash,
        TaikoData.ProverAssignment memory assignment
    )
        private
        returns (uint256 proverFee)
    {
        if (blobHash == 0 || assignment.prover == address(0)) {
            revert L1_ASSIGNMENT_INVALID_PARAMS();
        }

        // Check assignment validity
        if (
            block.timestamp > assignment.expiry
                || assignment.metaHash != 0 && metaHash != assignment.metaHash
                || assignment.maxBlockId != 0 && blockId > assignment.maxBlockId
                || assignment.maxProposedIn != 0 && block.number > assignment.maxProposedIn
        ) {
            revert L1_ASSIGNMENT_EXPIRED();
        }

        // Hash the assignment with the blobHash, this hash will be signed by
        // the prover, therefore, we add a string as a prefix.
        bytes32 hash = hashAssignment(assignment, address(this), blobHash);

        if (!assignment.prover.isValidSignature(hash, assignment.signature)) {
            revert L1_ASSIGNMENT_INVALID_SIG();
        }

        // Find the prover fee using the minimal tier
        proverFee = _getProverFee(assignment.tierFees, minTier);

        // The proposer irrevocably pays a fee to the assigned prover, either in
        // Ether or ERC20 tokens.
        uint256 tip;
        if (assignment.feeToken == address(0)) {
            if (msg.value < proverFee) revert L1_ASSIGNMENT_INSUFFICIENT_FEE();

            unchecked {
                tip = msg.value - proverFee;
            }

            // Paying Ether
            assignment.prover.sendEther(proverFee, MAX_GAS_PAYING_PROVER);
        } else {
            tip = msg.value;

            // Paying ERC20 tokens
            ERC20Upgradeable(assignment.feeToken).transferFrom(
                msg.sender, assignment.prover, proverFee
            );
        }

        // block.coinbase can be address(0) in tests
        if (tip != 0 && block.coinbase != address(0)) {
            address(block.coinbase).sendEther(tip);
        }
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

    function _getProverFee(
        TaikoData.TierFee[] memory tierFees,
        uint16 tierId
    )
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < tierFees.length; ++i) {
            if (tierFees[i].tier == tierId) return tierFees[i].fee;
        }
        revert L1_TIER_NOT_FOUND();
    }
}
