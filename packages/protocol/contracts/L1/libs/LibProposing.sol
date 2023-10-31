// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IBlobHashReader } from "../../4844/IBlobHashReader.sol";
import { LibAddress } from "../../libs/LibAddress.sol";

import { ITierProvider } from "../tiers/ITierProvider.sol";
import { TaikoData } from "../TaikoData.sol";

import { LibDepositing } from "./LibDepositing.sol";
import { LibTaikoToken } from "./LibTaikoToken.sol";

/// @title LibProposing
/// @notice A library for handling block proposals in the Taiko protocol.
library LibProposing {
    using LibAddress for address;

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint96 livenessBond,
        uint256 proverFee,
        TaikoData.BlockMetadata meta,
        TaikoData.EthDeposit[] depositsProcessed
    );

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_ASSIGNMENT_EXPIRED();
    error L1_ASSIGNMENT_INVALID_SIG();
    error L1_ASSIGNMENT_INVALID_PARAMS();
    error L1_ASSIGNMENT_INSUFFICIENT_FEE();
    error L1_BLOB_FOR_DA_DISABLED();
    error L1_NO_BLOB_FOUND();
    error L1_PROPOSER_NOT_EOA();
    error L1_TIER_NOT_FOUND();
    error L1_TOO_MANY_BLOCKS();
    error L1_TXLIST_TOO_LARGE();
    error L1_UNAUTHORIZED();

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
        TaikoData.BlockParams memory params =
            abi.decode(data, (TaikoData.BlockParams));

        if (!config.allowUsingBlobForDA && txList.length == 0) {
            revert L1_BLOB_FOR_DA_DISABLED();
        }

        // Taiko, as a Based Rollup, enables permissionless block proposals.
        // However, if the "proposer" address is set to a non-zero value, we
        // ensure that only that specific address has the authority to propose
        // blocks.
        TaikoData.SlotB memory b = state.slotB;
        if (!_isProposerPermitted(b, resolver)) revert L1_UNAUTHORIZED();

        // It's essential to ensure that the ring buffer for proposed blocks
        // still has space for at least one more block.

        if (b.numBlocks >= b.lastVerifiedBlockId + config.blockMaxProposals + 1)
        {
            revert L1_TOO_MANY_BLOCKS();
        }

        bytes32 blobHash; //or txListHash (if Blob not yet supported)
        if (txList.length == 0) {
            // Always use the first blob in this transaction.
            // If the proposeBlock functions are called more than once in the
            // same L1 transaction, these 2 L2 blocks will use the same blob as
            // DA.
            blobHash = IBlobHashReader(
                resolver.resolve("blob_hash_reader", false)
            ).getFirstBlobHash();

            if (blobHash == 0) revert L1_NO_BLOB_FOUND();
        } else {
            // The proposer must be an Externally Owned Account (EOA) for
            // calldata usage. This ensures that the transaction is not an
            // internal one, making calldata retrieval more straightforward.
            if (msg.sender != tx.origin) revert L1_PROPOSER_NOT_EOA();

            if (txList.length > config.blockMaxTxListBytes) {
                revert L1_TXLIST_TOO_LARGE();
            }

            blobHash = keccak256(txList);
        }

        // Each transaction must handle a specific quantity of L1-to-L2
        // Ether deposits.
        depositsProcessed =
            LibDepositing.processDeposits(state, config, msg.sender);

        // Initialize metadata to compute a metaHash, which forms a part of
        // the block data to be stored on-chain for future integrity checks.
        // If we choose to persist all data fields in the metadata, it will
        // require additional storage slots.
        unchecked {
            uint256 rand = uint256(blobHash)
                ^ (block.prevrandao * b.numBlocks * block.number);

            meta = TaikoData.BlockMetadata({
                l1Hash: blockhash(block.number - 1),
                // Following the Merge, the L1 mixHash incorporates the
                // prevrandao value from the beacon chain. Given the possibility
                // of multiple Taiko blocks being proposed within a single
                // Ethereum block, we must introduce a salt to this random
                // number as the L2 mixHash.
                difficulty: bytes32(rand),
                blobHash: blobHash,
                extraData: params.extraData,
                depositsHash: keccak256(abi.encode(depositsProcessed)),
                coinbase: msg.sender,
                id: b.numBlocks,
                gasLimit: config.blockMaxGasLimit,
                timestamp: uint64(block.timestamp),
                l1Height: uint64(block.number - 1),
                minTier: ITierProvider(resolver.resolve("tier_provider", false))
                    .getMinTier(rand),
                blobUsed: txList.length == 0
            });
        }
        // Now, it's essential to initialize the block that will be stored
        // on L1. We should aim to utilize as few storage slots as possible,
        // alghouth using a ring buffer can minimize storage writes once
        // the buffer reaches its capacity.
        TaikoData.Block storage blk =
            state.blocks[b.numBlocks % config.blockRingBufferSize];

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
        LibTaikoToken.debitTaikoToken(
            state, resolver, blk.assignedProver, config.livenessBond
        );

        // Increment the counter (cursor) by 1.
        unchecked {
            ++state.slotB.numBlocks;
        }

        // Validate the prover assignment, then charge Ether or ERC20 as the
        // prover fee based on the block's minTier.
        uint256 proverFee =
            _validateAssignment(meta.minTier, blobHash, params.assignment);

        emit BlockProposed({
            blockId: blk.blockId,
            assignedProver: blk.assignedProver,
            livenessBond: config.livenessBond,
            proverFee: proverFee,
            meta: meta,
            depositsProcessed: depositsProcessed
        });
    }

    function hashAssignment(
        TaikoData.ProverAssignment memory assignment,
        bytes32 blobHash
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                "PROVER_ASSIGNMENT",
                blobHash,
                assignment.feeToken,
                assignment.expiry,
                assignment.tierFees
            )
        );
    }

    function _validateAssignment(
        uint16 minTier,
        bytes32 blobHash,
        TaikoData.ProverAssignment memory assignment
    )
        private
        returns (uint256 proverFee)
    {
        // Check assignment not expired
        if (block.timestamp >= assignment.expiry) {
            revert L1_ASSIGNMENT_EXPIRED();
        }

        if (blobHash == 0 || assignment.prover == address(0)) {
            revert L1_ASSIGNMENT_INVALID_PARAMS();
        }

        // Hash the assignment with the blobHash, this hash will be signed by
        // the prover, therefore, we add a string as a prefix.
        bytes32 hash = hashAssignment(assignment, blobHash);

        if (!assignment.prover.isValidSignature(hash, assignment.signature)) {
            revert L1_ASSIGNMENT_INVALID_SIG();
        }

        // Find the prover fee using the minimal tier
        proverFee = _getProverFee(assignment.tierFees, minTier);

        // The proposer irrevocably pays a fee to the assigned prover, either in
        // Ether or ERC20 tokens.
        if (assignment.feeToken == address(0)) {
            // Paying Ether
            if (msg.value < proverFee) revert L1_ASSIGNMENT_INSUFFICIENT_FEE();
            assignment.prover.sendEther(proverFee);
            unchecked {
                // Return the extra Ether to the proposer
                uint256 refund = msg.value - proverFee;
                if (refund != 0) msg.sender.sendEther(refund);
            }
        } else {
            // Paying ERC20 tokens
            if (msg.value != 0) msg.sender.sendEther(msg.value);
            ERC20Upgradeable(assignment.feeToken).transferFrom(
                msg.sender, assignment.prover, proverFee
            );
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
