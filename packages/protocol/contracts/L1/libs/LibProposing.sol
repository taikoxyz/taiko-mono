// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { AddressResolver } from "../../common/AddressResolver.sol";
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
        uint16 minTier,
        TaikoData.BlockMetadata meta
    );

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_ASSIGNMENT_EXPIRED();
    error L1_ASSIGNMENT_INVALID_SIG();
    error L1_ASSIGNMENT_INVALID_PARAMS();
    error L1_ASSIGNMENT_INSUFFICIENT_FEE();
    error L1_TIER_NOT_FOUND();
    error L1_TOO_MANY_BLOCKS();
    error L1_TXLIST_MISMATCH();
    error L1_TXLIST_TOO_LARGE();
    error L1_UNAUTHORIZED();

    /// @dev Proposes a Taiko L2 block.
    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        bytes32 txListHash,
        bytes32 extraData,
        TaikoData.ProverAssignment memory assignment,
        bytes calldata txList
    )
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
        // Taiko, as a Based Rollup, enables permissionless block proposals.
        // However, if the "proposer" address is set to a non-zero value, we
        // ensure that only that specific address has the authority to propose
        // blocks.
        address proposer = resolver.resolve("proposer", true);
        if (proposer != address(0) && msg.sender != proposer) {
            revert L1_UNAUTHORIZED();
        }

        if (txList.length > config.blockMaxTxListBytes) {
            revert L1_TXLIST_TOO_LARGE();
        }

        // It's necessary to verify that the txHash matches the provided hash.
        // However, when we employ a blob for the txList, the verification
        // process will differ.
        if (txListHash != keccak256(txList)) {
            revert L1_TXLIST_MISMATCH();
        }

        // It's essential to ensure that the ring buffer for proposed blocks
        // still has space for at least one more block.
        TaikoData.SlotB memory b = state.slotB;
        if (b.numBlocks >= b.lastVerifiedBlockId + config.blockMaxProposals + 1)
        {
            revert L1_TOO_MANY_BLOCKS();
        }

        // Initialize metadata to compute a metaHash, which forms a part of
        // the block data to be stored on-chain for future integrity checks.
        // If we choose to persist all data fields in the metadata, it will
        // require additional storage slots.
        unchecked {
            meta = TaikoData.BlockMetadata({
                l1Hash: blockhash(block.number - 1),
                // Following the Merge, the L1 mixHash incorporates the
                // prevrandao value from the beacon chain. Given the possibility
                // of multiple Taiko blocks being proposed within a single
                // Ethereum block, we must introduce a salt to this random
                // number as the L2 mixHash.
                difficulty: bytes32(block.prevrandao * b.numBlocks),
                txListHash: txListHash,
                extraData: extraData,
                id: b.numBlocks,
                timestamp: uint64(block.timestamp),
                l1Height: uint64(block.number - 1),
                gasLimit: config.blockMaxGasLimit,
                coinbase: msg.sender,
                // Each transaction must handle a specific quantity of L1-to-L2
                // Ether deposits.
                depositsProcessed: LibDepositing.processDeposits(
                    state, config, msg.sender
                    )
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
        blk.metaHash = hashMetadata(meta);

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

        // The LibTiers play a crucial role in determining the minimum tier
        // required for the block's validity proof. It's imperative to
        // maintain a certain percentage of blocks for each tier to ensure
        // that provers are consistently available when needed.
        blk.minTier = ITierProvider(resolver.resolve("tier_provider", false))
            .getMinTier(uint256(blk.metaHash));

        // Verify assignment authorization; if prover's address is an IProver
        // contract, transfer Ether and call "validateAssignment" for
        // verification.
        // Prover can charge ERC20/NFT as fees; msg.value can be zero. Taiko
        // doesn't mandate Ether as the only proofing fee.
        blk.assignedProver = assignment.prover;

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
            _validateAssignment(blk.minTier, txListHash, assignment);

        emit BlockProposed({
            blockId: blk.blockId,
            assignedProver: blk.assignedProver,
            livenessBond: config.livenessBond,
            proverFee: proverFee,
            minTier: blk.minTier,
            meta: meta
        });
    }

    /// @dev Hashing the block metadata.
    function hashMetadata(TaikoData.BlockMetadata memory meta)
        internal
        pure
        returns (bytes32 hash)
    {
        uint256[7] memory inputs;
        inputs[0] = uint256(meta.l1Hash);
        inputs[1] = uint256(meta.difficulty);
        inputs[2] = uint256(meta.txListHash);
        inputs[3] = uint256(meta.extraData);
        inputs[4] = (uint256(meta.id)) | (uint256(meta.timestamp) << 64)
            | (uint256(meta.l1Height) << 128) | (uint256(meta.gasLimit) << 192);
        inputs[5] = uint256(uint160(meta.coinbase));
        inputs[6] = uint256(keccak256(abi.encode(meta.depositsProcessed)));

        assembly {
            hash := keccak256(inputs, 224 /*mul(7, 32)*/ )
        }
    }

    function hashAssignmentForTxList(
        TaikoData.ProverAssignment memory assignment,
        bytes32 txListHash
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                "PROVER_ASSIGNMENT",
                txListHash,
                assignment.feeToken,
                assignment.expiry,
                assignment.tierFees
            )
        );
    }

    function _validateAssignment(
        uint16 minTier,
        bytes32 txListHash,
        TaikoData.ProverAssignment memory assignment
    )
        private
        returns (uint256 proverFee)
    {
        // Check assignment not expired
        if (block.timestamp >= assignment.expiry) {
            revert L1_ASSIGNMENT_EXPIRED();
        }

        if (txListHash == 0 || assignment.prover == address(0)) {
            revert L1_ASSIGNMENT_INVALID_PARAMS();
        }

        // Hash the assignment with the txListHash, this hash will be signed by
        // the prover, therefore, we add a string as a prefix.
        bytes32 hash = hashAssignmentForTxList(assignment, txListHash);

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
